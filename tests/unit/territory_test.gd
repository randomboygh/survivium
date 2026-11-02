extends "res://tests/unit/test_case.gd"
## Teams and territory (plan/design/territory-pvp.md): who is in a team, how one joins,
## leaves and is put out, what the save keeps, and the requests of two players on one
## server.

const Teams := preload("res://src/shared/game/teams.gd")
const PlayerLink := preload("res://src/server/player_link.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")


func run() -> void:
	_test_teams()
	_test_team_requests()


func _test_teams() -> void:
	var t := Teams.new()
	var told: Array = []
	t.changed.connect(func(ids: Array) -> void: told.append(ids))
	_check(t.team_of(1) == 0 and t.together(1, 1) and not t.together(1, 2), "nobody is in a team at first; a player is with themselves")
	_check(not t.invite(1, "Аня", 1, 0.0), "one does not invite oneself")
	_check(t.invite(1, "Аня", 2, 0.0) and not t.invite(1, "Аня", 2, 1.0), "an invitation is made once while it waits")
	_check(t.invites_of(2, 1.0) == [[1, "Аня"]], "the invited sees who asked")
	_check(not t.accept(3, "Вова", 1, 1.0), "one not invited cannot accept")
	_check(t.accept(2, "Боря", 1, 2.0) and t.together(1, 2) and t.team_of(1) != 0, "accepting makes a team of the two")
	var team := t.team_of(1)
	_check(t.view(2).lead == 1 and t.view(2).name == "Команда Аня" and t.view(2).members == [[1, "Аня"], [2, "Боря"]],
		"the one who invited leads it, and it is named after them")
	_check(told.size() == 1 and told[0].has(1) and told[0].has(2), "both are told")
	_check(t.invite(2, "Боря", 3, 3.0) and t.accept(3, "Вова", 2, 3.5) and t.team_of(3) == team,
		"a member invites into the same team")
	_check(not t.invite(1, "Аня", 3, 4.0), "one in a team is not invited")
	_check(t.invite(1, "Аня", 4, 0.0) and t.invites_of(4, Teams.INVITE_TIME + 1.0).is_empty()
		and not t.accept(4, "Гена", 1, Teams.INVITE_TIME + 1.0), "an invitation left waiting too long is gone")
	_check(not t.kick(2, 3) and t.kick(1, 3) and t.team_of(3) == 0, "only the lead puts a member out")
	_check(not t.rename(2, "Лес") and t.rename(1, "  Лесные  ") and t.view(2).name == "Лесные", "only the lead names the team")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(t.to_dict()))
	var back := Teams.new()
	back.from_dict(saved)
	_check(back.view(1) == t.view(1) and back.together(1, 2) and back.next_team == t.next_team,
		"the save keeps the teams through JSON")
	_check(t.leave(1) and t.team_of(2) == 0 and t.team_of(1) == 0 and t.teams.is_empty(),
		"a team left with one member is gone")
	_check(t.invite(5, "Дима", 6, 10.0) and t.accept(6, "Ева", 5, 10.0) and t.invite(5, "Дима", 7, 10.0)
		and t.accept(7, "Жора", 5, 10.0) and t.leave(5) and t.view(6).lead == 6 and t.view(7).members.size() == 2,
		"when the lead leaves, the member longest there leads")
	_check(t.invite(6, "Ева", 8, 11.0) and t.decline(8, 6) and not t.accept(8, "Зоя", 6, 11.0), "an invitation turned down is gone")


## Two players on one server: one invites the other near them, who accepts; both are
## told their team, each sees the other marked in PEOPLE; one far is not invited; a
## line to the team is said only by one in a team.
func _test_team_requests() -> void:
	var w := WorldData.new(8, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
	var s := Session.new(w, null, Clock.new(), Rules.new(), Placed.new())
	var links: Array = []
	for i in 3:
		var link := PlayerLink.new(s)
		link.who.id = i + 1
		link.who.player_name = ["Аня", "Боря", "Вова"][i]
		link.who.teleport(Vector3(4.0 + i, 1.0, 4.0) if i < 2 else Vector3(200.0, 1.0, 200.0))
		links.append(link)
	var a: PlayerLink = links[0]
	var b: PlayerLink = links[1]
	var c: PlayerLink = links[2]
	for l in links:
		l.flush()
	var said: Array = []
	a.requests.team_chatted.connect(func(text: String) -> void: said.append(text))
	_check(_ask(a, 1, Protocol.TEAM_CHAT, ["привет"]) == null and said.is_empty(), "one in no team says nothing to a team")
	_check(_ask(a, 2, Protocol.TEAM_INVITE, [3]) == false, "a player far away is not invited")
	_check(_ask(a, 3, Protocol.TEAM_INVITE, [2]) == true, "a player near is invited")
	var out := _decoded(b.flush())
	_check(out.has([Protocol.INVITES, [[[1, "Аня"]]]]), "the invited is told who asks: %s" % [out])
	_check(_ask(b, 1, Protocol.TEAM_ACCEPT, [1]) == true and s.teams.together(1, 2), "and accepts")
	var to_a := _decoded(a.flush())
	var team: Array = to_a.filter(func(e: Array) -> bool: return e[0] == Protocol.TEAM)
	_check(team.size() == 1 and team[0][1][0].members == [[1, "Аня"], [2, "Боря"]], "the lead is told the team")
	var people: Array = to_a.filter(func(e: Array) -> bool: return e[0] == Protocol.PEOPLE)
	_check(not people.is_empty() and people.back()[1].any(func(p: Array) -> bool: return p[0] == 2 and p[14] == true),
		"and sees the other marked as one of theirs")
	_check(_ask(a, 4, Protocol.TEAM_CHAT, ["привет"]) == true and said == ["привет"], "a member says a line to the team")
	_check(_ask(b, 2, Protocol.TEAM_KICK, [1]) == false and _ask(a, 5, Protocol.TEAM_KICK, [2]) == true
		and s.teams.team_of(2) == 0, "the lead puts the other out")
	for l in links:
		l.leave()


func _ask(link, seq: int, kind: String, args: Array) -> Variant:
	var reply: Array = Protocol.decode(link.handle(Protocol.encode(Protocol.request(kind, seq, args))))
	return reply[1]


static func _decoded(list: Array) -> Array:
	return list.map(func(bytes: PackedByteArray) -> Array: return Protocol.decode(bytes))
