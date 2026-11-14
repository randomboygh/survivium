extends "res://tests/unit/test_case.gd"
## Teams and territory (plan/design/territory-pvp.md): who is in a team, how one joins,
## leaves and is put out, what the save keeps, and the requests of two players on one
## server.

const Teams := preload("res://src/shared/game/teams.gd")
const PlayerLink := preload("res://src/server/player_link.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Territory := preload("res://src/shared/game/territory.gd")
const CharacterScript := preload("res://src/shared/game/character.gd")
const Fights := preload("res://src/shared/game/fights.gd")
const Land := preload("res://src/client/game/land.gd")


func run() -> void:
	_test_teams()
	_test_team_requests()
	_test_land()
	_test_land_requests()
	_test_rights()
	_test_rights_on_server()
	_test_colors()
	_test_pvp()
	_test_respawn()
	_test_decay()
	_test_client_land()


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
	_check(t.view(2).lead == 1 and t.view(2).name == "Team Аня" and t.view(2).members == [[1, "Аня"], [2, "Боря"]],
		"the one who invited leads it, and it is named after them")
	_check(told.size() == 1 and told[0].has(1) and told[0].has(2), "both are told")
	_check(t.invite(2, "Боря", 3, 3.0) and t.accept(3, "Вова", 2, 3.5) and t.team_of(3) == team,
		"a member invites into the same team")
	_check(not t.invite(1, "Аня", 3, 4.0), "one in a team is not invited")
	_check(t.invite(1, "Аня", 4, 0.0) and t.invites_of(4, Teams.INVITE_TIME + 1.0).is_empty()
		and not t.accept(4, "Гена", 1, Teams.INVITE_TIME + 1.0), "an invitation left waiting too long is gone")
	_check(not t.kick(2, 3) and t.kick(1, 3) and t.team_of(3) == 0, "only the lead puts a member out")
	_check(not t.rename(2, "Forest") and t.rename(1, "  Лесные  ") and t.view(2).name == "Лесные", "only the lead names the team")
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
## told their team (the one asking first sees the invitation wait), each sees the other marked in PEOPLE; one far is not invited; a
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
	_check(out.has([Protocol.INVITES, [[[1, "Аня"]], []]]), "the invited is told who asks: %s" % [out])
	var sent: Array = _decoded(a.flush()).filter(func(e: Array) -> bool: return e[0] == Protocol.INVITES)
	_check(not sent.is_empty() and sent.back()[1][1].size() == 1 and sent.back()[1][1][0][0] == 2,
		"the one who asks is told the invitation waits: %s" % [sent])
	_check(_ask(b, 1, Protocol.TEAM_ACCEPT, [1]) == true and s.teams.together(1, 2), "and accepts")
	var to_a := _decoded(a.flush())
	var team: Array = to_a.filter(func(e: Array) -> bool: return e[0] == Protocol.TEAM)
	_check(team.size() == 1 and team[0][1][0].members == [[1, "Аня"], [2, "Боря"]], "the lead is told the team")
	var people: Array = to_a.filter(func(e: Array) -> bool: return e[0] == Protocol.PEOPLE)
	_check(not people.is_empty() and people.back()[1].any(func(p: Array) -> bool: return p[0] == 2 and p[14] == true),
		"and sees the other marked as one of theirs")
	var mates: Array = to_a.filter(func(e: Array) -> bool: return e[0] == Protocol.MATES)
	_check(not mates.is_empty() and mates.back()[1][0] == [[2, "Боря", Vector2i(floori(5.0 / WorldData.CELL), floori(4.0 / WorldData.CELL))]],
		"and where the other is, for the map: %s" % [mates])
	b.who.teleport(Vector3(900.0, 1.0, -700.0))
	mates = _decoded(a.flush()).filter(func(e: Array) -> bool: return e[0] == Protocol.MATES)
	_check(mates.size() == 1 and mates[0][1][0][0][2] == Vector2i(floori(900.0 / WorldData.CELL), floori(-700.0 / WorldData.CELL)),
		"however far they go: %s" % [mates])
	_check(_decoded(a.flush()).all(func(e: Array) -> bool: return e[0] != Protocol.MATES), "and only when they move")
	_check(_ask(a, 4, Protocol.TEAM_CHAT, ["привет"]) == true and said == ["привет"], "a member says a line to the team")
	_check(_ask(b, 2, Protocol.TEAM_KICK, [1]) == false and _ask(a, 5, Protocol.TEAM_KICK, [2]) == true
		and s.teams.team_of(2) == 0, "the lead puts the other out")
	mates = _decoded(a.flush()).filter(func(e: Array) -> bool: return e[0] == Protocol.MATES)
	_check(mates.size() == 1 and mates[0][1] == [[]], "and sees no one of theirs on the map: %s" % [mates])
	for l in links:
		l.leave()


## The squares of a claim: painted next to its own within the radius, not on another's,
## no more than the budget (a team's: the biggest and half of the others), cleared only
## where the rest stays joined; the centre taken away takes the claim; the save keeps it.
func _test_land() -> void:
	var t := Territory.new()
	t.rules = Rules.of({"territory_start": 4, "territory_per_level": 2, "territory_radius": 2, "territory_levels": 8})
	t.teams = Teams.new()
	var a := _Who.new(1)
	var b := _Who.new(2)
	_check(t.budget(1) == 4 and t.used(1) == 0, "a player starts with the squares of the rules")
	var post := t.add_claim(1, {"cell": Vector3i(10, 5, 10)}, "Аня")
	_check(t.squares.get(Vector2i(5, 5)) == post and t.used(1) == 1, "a post claims its own square")
	_check(t.claim_at(Vector3i(11, 13, 11)).id == post and t.claim_at(Vector3i(11, 14, 11)).is_empty(),
		"within the claim's levels of the centre only")
	_check(not t.paint(a, Vector2i(7, 5), true), "a square not touching the claim is not painted")
	_check(t.paint(a, Vector2i(6, 5), true) and t.paint(a, Vector2i(7, 5), true), "squares touching it are")
	_check(not t.paint(a, Vector2i(8, 5), true), "not farther than the radius")
	_check(not t.paint(b, Vector2i(5, 6), true), "nor by one of no team with the claim")
	_check(t.paint(a, Vector2i(5, 6), true) and t.used(1) == 4, "up to the budget")
	_check(not t.paint(a, Vector2i(4, 5), true) and a.nags.size() == 1, "and not over it, with a word")
	_check(not t.paint(a, Vector2i(6, 5), false), "a square that joins others to the centre is not cleared")
	_check(not t.paint(a, Vector2i(5, 5), false), "nor the centre's")
	_check(t.paint(a, Vector2i(7, 5), false) and t.used(1) == 3, "an end one is")
	_check(not t.can_claim(b, Vector3i(12, 5, 10)) and b.nags.size() == 1, "nobody else sets a post in the land")
	t.skilled[2] = 3
	_check(t.budget(2) == 10, "the levels of the skills add squares")
	t.teams.invite(1, "Аня", 2, 0.0)
	t.teams.accept(2, "Боря", 1, 0.0)
	_check(t.budget(1) == 12 and t.budget(2) == 12, "a team holds the biggest budget and half of the other")
	_check(t.paint(b, Vector2i(4, 5), true) and t.used(2) == 4, "a member paints the team's land")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(t.to_dict()))
	var back := Territory.new()
	back.from_dict(saved)
	_check(back.squares == t.squares and back.claims[post].count == 4 and back.skilled[2] == 3
		and back.next_claim == t.next_claim, "the save keeps the claims through JSON")
	var told: Array = []
	t.squares_changed.connect(func(list: Array) -> void: told.append_array(list))
	t.thing_gone(Vector3i(10, 5, 10))
	_check(t.claims.is_empty() and t.squares.is_empty() and told.size() == 4, "the post taken away takes its squares")
	back.teams = t.teams
	var copy := Territory.new()
	copy.take_claims(back.claims_view())
	copy.take_squares(back.squares_view(), true)
	_check(copy.squares == back.squares and copy.claims[post].count == 4 and copy.claims[post].name == "Team Аня",
		"a client's copy takes what the server tells, named by the team")
	_check(back.clear_painted() == 3 and back.squares.size() == 1 and back.squares.get(Vector2i(5, 5)) == post
		and back.claims[post].count == 1 and back.used(1) == 1, "the test page's clearing leaves each post its own square")


## A boundary post set down from the bag on a server makes a claim; its owner is told
## the land and paints a square by LAND_PAINT, another player is not let to.
func _test_land_requests() -> void:
	var w := WorldData.new(8, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
	var s := Session.new(w, null, Clock.new(), Rules.new(), Placed.new())
	var a := PlayerLink.new(s)
	a.who.id = 1
	a.who.player_name = "Аня"
	a.who.teleport(Vector3(8.5, 1.0, 8.5) * WorldData.CELL)
	var b := PlayerLink.new(s)
	b.who.id = 2
	b.who.player_name = "Боря"
	b.who.teleport(Vector3(20.5, 1.0, 20.5) * WorldData.CELL)
	a.flush()
	b.flush()
	var post := Items.with_prop("post")
	_check(post != "" and Items.get_item(post).claims, "a boundary post claims land")
	a.who.inventory.add(post, 1)
	_check(s.placed.put_from_bag(a.who, post, -1, 40) and s.territory.claims.size() == 1,
		"a post set down makes a claim")
	var claim: Dictionary = s.territory.claims.values()[0]
	var out := _decoded(a.flush())
	_check(out.any(func(e: Array) -> bool: return e[0] == Protocol.CLAIMS and e[1][0].size() == 1)
		and out.any(func(e: Array) -> bool: return e[0] == Protocol.LAND and e[1] == [1, 64]),
		"its owner is told the claim and the count: %s" % [out])
	var next: Vector2i = claim.sq + Vector2i(1, 0)
	_check(_ask(b, 1, Protocol.LAND_PAINT, [next, true]) == false, "another does not paint it")
	_check(_ask(a, 1, Protocol.LAND_PAINT, [next, true]) == true and s.territory.squares.get(next) == claim.id,
		"the owner does")
	out = _decoded(b.flush())
	_check(out.any(func(e: Array) -> bool: return e[0] == Protocol.SQUARES and e[1][0].has([next, claim.id])),
		"and everyone is told the square")
	# A game of one's own: the player joins before the save is read (Props.place), so
	# the land read later is told them too, or their post is nobody's on the screen.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.territory.to_dict()))
	var s2 := Session.new(w, null, Clock.new(), Rules.new(), Placed.new())
	var c := PlayerLink.new(s2)
	c.who.id = 1
	c.flush()
	s2.territory.from_dict(saved)
	out = _decoded(c.flush())
	var told_claims := out.any(func(e: Array) -> bool: return e[0] == Protocol.CLAIMS and e[1][0].size() == 1 and e[1][0][0][2] == 1)
	var told_squares := out.any(func(e: Array) -> bool: return e[0] == Protocol.SQUARES and e[1][0].has([next, claim.id]))
	var told_land := out.any(func(e: Array) -> bool: return e[0] == Protocol.LAND and e[1] == [2, 64])
	_check(told_claims and told_squares and told_land,
		"the land read from the save is told a player who joined before: %s" % [out])
	c.leave()
	_check(s.placed.take_up(a.who, s.placed.things[0]) and s.territory.claims.is_empty(), "the post taken up takes the claim")
	a.leave()
	b.leave()


## What others may do in one's land: by default the team everything, the others only
## walk; the owner sets it for each; the save and a client's copy keep it.
func _test_rights() -> void:
	var t := Territory.new()
	t.rules = Rules.new()
	t.teams = Teams.new()
	var claim := {"id": 1, "by": 1, "name": "Аня"}
	_check(t.allowed({}, 2, "build") and t.allowed(claim, 1, "build"), "out of every claim and in one's own all is allowed")
	_check(t.allowed(claim, 2, "walk") and not t.allowed(claim, 2, "build") and not t.allowed(claim, 2, "harvest"),
		"by default the others only walk")
	t.teams.invite(1, "Аня", 2, 0.0)
	t.teams.accept(2, "Боря", 1, 0.0)
	_check(t.allowed(claim, 2, "build") and t.allowed(claim, 2, "chests") and not t.allowed(claim, 3, "chests"),
		"the team may do everything")
	var harvest := 1 << Territory.ACTIONS.find("harvest")
	_check(t.set_rights(1, Territory.TEAM_DEFAULT & ~(1 << Territory.ACTIONS.find("chests")), 1 | harvest)
		and not t.set_rights(1, Territory.TEAM_DEFAULT & ~(1 << Territory.ACTIONS.find("chests")), 1 | harvest),
		"the owner sets the rights, once for the same")
	_check(t.allowed(claim, 3, "harvest") and not t.allowed(claim, 3, "build") and not t.allowed(claim, 2, "chests"),
		"and they hold for the others and the team")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(t.to_dict()))
	var back := Territory.new()
	back.from_dict(saved)
	_check(back.rights == t.rights, "the save keeps the rights through JSON")
	t.claims[1] = {"id": 1, "center": Vector3i(0, 0, 0), "sq": Vector2i.ZERO, "by": 1, "name": "Аня", "count": 0}
	var copy := Territory.new()
	copy.take_claims(t.claims_view())
	_check(copy.rights_of(1) == t.rights_of(1), "a client's copy is told them")


## A claim nobody of its team stands in decays after the rules' hours: the others may
## do more, its farther squares go, and at last it is gone; one of the team coming back
## gives it its protection again.
func _test_decay() -> void:
	var t := Territory.new()
	t.rules = Rules.of({"territory_start": 100, "territory_radius": 6, "territory_abandon_hours": 1.0,
		"territory_decay_hours": 1.0})
	t.teams = Teams.new()
	var a := _Who.new(1)
	var id := t.add_claim(1, {"cell": Vector3i(10, 5, 10)}, "Аня")
	for x in range(6, 12):
		t.paint(a, Vector2i(x, 5), true)
	_check(t.claims[id].count == 7, "a claim reaching six squares out")
	a.position = Vector3(200.5, 5.0, 200.5) * WorldData.CELL
	t.step(0.0, [a], 3599.0)
	var claim: Dictionary = t.claims[id]
	_check(claim.weak == 0 and claim.count == 7, "not before the hours of the rules")
	t.step(0.0, [a], 2.0)
	_check(claim.weak == 1 and t.allowed(claim, 2, "chests") and not t.allowed(claim, 2, "build"),
		"then the others may walk and open")
	_check(claim.count == 5 and not t.squares.has(Vector2i(10, 5)) and t.squares.has(Vector2i(9, 5)),
		"and the farther third of its reach is let go")
	var copy := Territory.new()
	copy.take_claims(t.claims_view())
	_check(copy.claims[id].weak == 1 and copy.allowed(copy.claims[id], 2, "chests"), "a client's copy is told")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(t.to_dict()))
	var back := Territory.new()
	back.from_dict(saved)
	_check(back.time == t.time and back.claims[id].weak == 1 and back.claims[id].seen == 0.0,
		"the save keeps the time and the neglect through JSON")
	a.position = Vector3(10.5, 5.0, 10.5) * WorldData.CELL
	t.step(0.0, [a], 1.0)
	_check(claim.weak == 0 and not t.allowed(claim, 2, "chests") and a.nags.size() == 1,
		"one of the team coming back protects it again, with a word")
	a.position = Vector3(200.5, 5.0, 200.5) * WorldData.CELL
	t.step(0.0, [a], 3601.0)
	t.step(0.0, [a], 3600.0)
	_check(claim.weak == 2 and t.allowed(claim, 2, "build") and not t.allowed(claim, 2, "hit_players")
		and claim.count == 2, "a stage more: the others may break, the claim keeps half its reach")
	t.step(0.0, [a], 3600.0)
	_check(t.claims.is_empty() and t.squares.is_empty(), "at last it is nobody's land")
	var r := Territory.new()
	r.rules = Rules.of({"territory_abandon_hours": 1.0, "territory_decay_hours": 1.0, "territory_decay": "rights"})
	id = r.add_claim(1, {"cell": Vector3i(10, 5, 10)}, "Аня")
	r.paint(a, Vector2i(6, 5), true)
	r.step(0.0, [a], 3601.0)
	_check(r.claims[id].weak == 1 and r.claims[id].count == 2, "by «rights» it keeps its squares")
	var g := Territory.new()
	g.rules = Rules.of({"territory_abandon_hours": 1.0, "territory_decay_hours": 1.0, "territory_decay": "radius"})
	id = g.add_claim(1, {"cell": Vector3i(10, 5, 10)}, "Аня")
	g.paint(a, Vector2i(6, 5), true)
	g.step(0.0, [a], 3601.0)
	_check(g.claims[id].weak == 0 and g.claims[id].count == 1, "by «radius» it only shrinks")


## On a server, in another's land: digging, cutting grass, taking up a thing, opening a
## chest and walking in are kept from one not allowed, and let when the owner allows.
func _test_rights_on_server() -> void:
	var w := WorldData.new(8, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var s := Session.new(w, null, Clock.new(), Rules.new(), Placed.new())
	var a := PlayerLink.new(s)
	a.who.id = 1
	a.who.player_name = "Аня"
	a.who.teleport(Vector3(10.5, 2.0, 10.5) * WorldData.CELL)
	var b := PlayerLink.new(s)
	b.who.id = 2
	b.who.player_name = "Боря"
	b.who.teleport(Vector3(30.5, 2.0, 30.5) * WorldData.CELL)
	var id := s.territory.add_claim(1, {"cell": Vector3i(10, 2, 10)}, "Аня")
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			s.territory._assign([Vector2i(5 + dx, 5 + dz)], id)
	var chest: Dictionary = s.placed.put("tools:chest", Vector3i(12, 2, 12))
	_check(not _step_back(s, b) and s.territory.claim_at(Territory._cell(b.who.position)).get("id", 0) == id, "by default one may walk in another's land")
	_check(s.territory.set_rights(1, Territory.TEAM_DEFAULT, 0) and _step_back(s, b), "with walking not allowed, one is put back out")
	s.territory.set_rights(1, Territory.TEAM_DEFAULT, 1)
	b.who.teleport(Vector3(13.5, 2.0, 13.5) * WorldData.CELL)
	s.step_players(0.1)
	_check(s.actions.dig(b.who, [Vector3i(13, 1, 12)] as Array[Vector3i], 0.5).is_empty() and w.get_cell(13, 1, 12) == Mat.DIRT,
		"one not allowed digs nothing in it")
	_check(s.actions.dig(a.who, [Vector3i(9, 1, 9)] as Array[Vector3i], 0.5).size() > 0 and w.get_cell(9, 1, 9) == Mat.AIR,
		"its owner digs")
	_check(_ask(b, 1, Protocol.BAG_ALL, [chest.cell, null, 0]) != true, "nor opens a chest")
	_check(not s.placed.take_up(b.who, chest), "nor takes up a thing")
	s.territory.set_rights(1, Territory.TEAM_DEFAULT, Territory.TEAM_DEFAULT)
	_check(s.actions.dig(b.who, [Vector3i(13, 1, 12)] as Array[Vector3i], 0.5).size() > 0, "allowed, they dig")
	_check(_ask(a, 2, Protocol.LAND_COLOR, [2]) == true and s.territory.color_of(1) == 2 and _ask(a, 3, Protocol.LAND_COLOR, ["red"]) != true,
		"one picks the colour of one's land by a request")
	a.leave()
	b.leave()


## The colour of one's land: picked by its owner, kept in the save and told to a client's copy.
func _test_colors() -> void:
	var t := Territory.new()
	t.rules = Rules.new()
	t.teams = Teams.new()
	_check(t.color_of(1) == 0, "no colour picked is the first")
	_check(t.set_color(1, 3) and not t.set_color(1, 3) and t.color_of(1) == 3, "the owner picks a colour, once for the same")
	_check(not t.set_color(1, Territory.COLORS) and not t.set_color(1, -1) and t.color_of(1) == 3, "a colour out of the list is refused")
	var back := Territory.new()
	back.from_dict(JSON.parse_string(JSON.stringify(t.to_dict())))
	_check(back.color_of(1) == 3, "the save keeps the colour through JSON")
	t.claims[1] = {"id": 1, "center": Vector3i(0, 0, 0), "sq": Vector2i.ZERO, "by": 1, "name": "Аня", "count": 0}
	var copy := Territory.new()
	copy.take_claims(t.claims_view())
	_check(copy.color_of(1) == 3, "a client's copy is told it")


## Players fighting players (Fights): a blow wounds and throws back, not one's team, not
## a newcomer, not where the server or the land's owner forbids it; a fight holds one out
## of land closed to fights; the save keeps the time played and who gave protection up.
func _test_pvp() -> void:
	var w := WorldData.new(8, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var rules := Rules.new()
	var s := Session.new(w, null, Clock.new(), rules, Placed.new())
	var a := PlayerLink.new(s)
	a.who.id = 1
	a.who.player_name = "Аня"
	var b := PlayerLink.new(s)
	b.who.id = 2
	b.who.player_name = "Боря"
	var face := func() -> void:
		a.who.teleport(Vector3(20.5, 2.0, 20.5) * WorldData.CELL)
		a.who.facing = Vector2i(1, 0)
		b.who.teleport(a.who.position + Vector3(0.6, 0.0, 0.0))
		a.who.vitals.stamina = a.who.vitals.MAX
	face.call()
	_check(s.fights.protection_left(2) > 0.0, "a newcomer is protected at first")
	var blow: Dictionary = s.actions.strike(a.who)
	_check(not blow.get("hit", false) and b.who.vitals.health == b.who.vitals.MAX, "a newcomer under protection is not hurt")
	rules.newcomer_minutes = 0
	face.call()
	blow = s.actions.strike(a.who)
	var hand: int = Tools.HAND.power
	_check(blow.get("hit", false) and is_equal_approx(b.who.vitals.health, b.who.vitals.MAX - hand * rules.pvp_damage),
		"a blow of the hand takes pvp_damage for each point of its power")
	_check(b.who.vitals.hurt_by == "player:Аня" and CharacterScript.cause_text(b.who.vitals.hurt_by)[1].contains("Аня"),
		"the one hit knows who hit them, also on death")
	_check(s.fights.tag_left(1) > 0.0 and s.fights.tag_left(2) > 0.0, "both who fought are tagged")
	var events := _decoded(b.flush()).map(func(e: Array) -> String: return str(e[0]))
	_check(Protocol.KNOCK in events and Protocol.FIGHT in events, "the one hit is thrown back and told of the fight")
	var health := b.who.vitals.health
	a.who.hands = ["tools:stone_axe", ""]
	face.call()
	_check(not s.actions.strike(a.who).get("hit", false) and b.who.vitals.health == health, "a work tool does not hit a player beside")
	a.who.hands = ["", ""]
	s.teams.of[1] = 7
	s.teams.of[2] = 7
	face.call()
	_check(not s.actions.strike(a.who).get("hit", false) and b.who.vitals.health == health, "one's team is not hurt")
	s.teams.of.clear()
	rules.pvp = "off"
	face.call()
	_check(not s.actions.strike(a.who).get("hit", false) and b.who.vitals.health == health, "with PvP off nobody is hurt")
	rules.pvp = "land"
	var id := s.territory.add_claim(3, {"cell": Vector3i(10, 2, 10)}, "Вера")
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			s.territory._assign([Vector2i(5 + dx, 5 + dz)], id)
	a.who.teleport(Vector3(12.5, 2.0, 12.5) * WorldData.CELL)
	b.who.teleport(a.who.position + Vector3(0.6, 0.0, 0.0))
	_check(not s.actions.strike(a.who).get("hit", false) and b.who.vitals.health == health, "in land whose owner forbids it nobody is hurt")
	rules.pvp = "all"
	a.who.vitals.stamina = a.who.vitals.MAX
	_check(s.actions.strike(a.who).get("hit", false) and b.who.vitals.health < health, "with PvP everywhere, also there")
	rules.pvp = "land"
	# A tagged player walking into land closed to fights is put back.
	b.who.teleport(Vector3(30.5, 2.0, 30.5) * WorldData.CELL)
	s.step_players(0.1)
	b.who.teleport(Vector3(14.5, 2.0, 14.5) * WorldData.CELL)
	s.step_players(0.1)
	_check(b.who.position.distance_to(Vector3(30.5, 2.0, 30.5) * WorldData.CELL) < 1.0, "a fight holds one out of land closed to fights")
	s.fights.tags.clear()
	b.who.teleport(Vector3(14.5, 2.0, 14.5) * WorldData.CELL)
	s.step_players(0.1)
	_check(b.who.position.distance_to(Vector3(14.5, 2.0, 14.5) * WorldData.CELL) < 1.0, "the fight over, one walks in")
	rules.newcomer_minutes = 120
	_check(s.fights.protection_left(1) == 0.0, "who hit someone lost their protection")
	_check(_ask(b, 1, Protocol.FIGHT_BRAVE, []) == true and s.fights.protection_left(2) == 0.0, "one gives one's protection up by a request")
	var back := Fights.new()
	back.rules = rules
	back.from_dict(JSON.parse_string(JSON.stringify(s.fights.to_dict())))
	_check(back.brave.has(1) and back.brave.has(2) and back.played.has(2), "the save keeps who gave protection up and the time played")
	a.leave()
	b.leave()


## Coming back at the team's fires: a fire put from the bag knows its maker (and the
## save keeps it); the dead are told their own last fire first and their team's, not
## another's; the server brings them back at one of those places only. Leaving in one's
## own land the character goes at once.
func _test_respawn() -> void:
	var w := WorldData.new(8, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
	var s := Session.new(w, null, Clock.new(), Rules.new(), Placed.new())
	var links: Array = []
	for i in 3:
		var link := PlayerLink.new(s)
		link.who.id = i + 1
		link.who.player_name = ["Аня", "Боря", "Вера"][i]
		s.teams.seen(i + 1, link.who.player_name)
		link.who.teleport(Vector3(10.5 + 12.0 * i, 1.0, 10.5) * WorldData.CELL)
		link.flush()
		links.append(link)
	var a: PlayerLink = links[0]
	var b: PlayerLink = links[1]
	var c: PlayerLink = links[2]
	s.teams.invite(1, "Аня", 2, 0.0)
	s.teams.accept(2, "Боря", 1, 0.0)
	var fire := Placed.CAMPFIRE
	a.who.inventory.add(fire, 1)
	_check(s.placed.put_from_bag(a.who, fire, -1, 40), "a fire is put from the bag")
	var e: Dictionary = s.placed.things[-1]
	_check(e.get("by") == 1 and Placed.record(e).get("by") == 1, "it knows who made it, and its record keeps it")
	var back := Placed.new()
	back.world = WorldData.new(8, Vector2i(48, 48))
	back.from_list(JSON.parse_string(JSON.stringify(s.placed.to_list())))
	_check(back.things.size() == 1 and back.things[0].get("by") == 1, "so does the save through JSON")
	var by: Vector3 = s.placed.stand_by(e)
	var cell := Vector3i((by / WorldData.CELL).floor())
	_check(cell.y == 1 and not w.blockers.has(cell) and absi(cell.x - e.cell.x) <= 2 and absi(cell.z - e.cell.z) <= 2,
		"one comes back beside it, on the ground (%s by %s)" % [cell, e.cell])
	for link: PlayerLink in links:
		link.who.die()
	var told := {}
	for link: PlayerLink in links:
		for m: Array in _decoded(link.flush()):
			if m[0] == Protocol.YOU:
				told[link.who.id] = m[1].respawns
	_check(told.get(1, []).size() == 1 and Lang.t(told[1][0][0]) == "At your campfire", "its maker is told their own fire: %s" % [told.get(1)])
	_check(told.get(2, []).size() == 1 and Lang.t(told[2][0][0]) == "At “Аня”'s campfire", "the team the maker's: %s" % [told.get(2)])
	_check(told.get(3, [null]).is_empty() and c.who.respawn_points().size() == 1, "another player none: %s" % [told.get(3)])
	_check(_ask(b, 1, Protocol.REVIVE, [by + Vector3(0.1, 0.0, 0.0)]) == true and not b.who.is_dead()
		and b.who.position.distance_to(by) < 0.01, "the team comes back at it")
	var far := Vector3(40.5, 1.0, 40.5) * WorldData.CELL
	_check(_ask(c, 1, Protocol.REVIVE, [by]) == true and c.who.position.distance_to(c.who.home) < 0.01,
		"another asking for it comes back at the start's fire")
	_check(_ask(a, 1, Protocol.REVIVE, [far]) == true and a.who.position.distance_to(far) > 1.0,
		"nobody comes back at a place of their own choosing")
	var id := s.territory.add_claim(1, {"cell": Vector3i(10, 1, 10)}, "Аня")
	s.territory._assign([Vector2i(5, 5), Vector2i(6, 5)], id)
	a.who.teleport(Vector3(11.5, 1.0, 10.5) * WorldData.CELL)
	b.who.teleport(Vector3(12.5, 1.0, 10.5) * WorldData.CELL)
	c.who.teleport(Vector3(30.5, 1.0, 10.5) * WorldData.CELL)
	_check(s.territory.at_home(a.who) and s.territory.at_home(b.who) and not s.territory.at_home(c.who),
		"the owner and the team stand at home in the land, another out of it does not")
	for link: PlayerLink in links:
		link.leave()


## Steps the session with `link`'s player standing in the land, a step back: whether
## they were put back where they stood before.
func _step_back(s, link) -> bool:
	link.who.teleport(Vector3(30.5, 2.0, 30.5) * WorldData.CELL)
	s.step_players(0.1)
	link.who.teleport(Vector3(14.5, 2.0, 14.5) * WorldData.CELL)
	s.step_players(0.1)
	return link.who.position.distance_to(Vector3(30.5, 2.0, 30.5) * WorldData.CELL) < 1.0


## The client's copy of the land: a post told on entering the game leaves the marking
## off, one the player has just asked to set down turns it on; a tap goes to the post
## anywhere in the column of its first square.
func _test_client_land() -> void:
	var land := Land.new()
	land.game = _Game.new()
	var post := [[1, Vector3i(10, 5, 10), 7, "Аня"]]
	land.take_claims([])
	land.take_claims(post)
	_check(not land.painting, "the post of a world just loaded does not start the marking")
	land.take_claims([])
	land.expect_post("tools:axe")
	land.take_claims(post)
	_check(not land.painting, "nor does a claim told after something else set down")
	land.take_claims([])
	land.expect_post("tools:boundary_post")
	land.take_claims(post)
	_check(land.painting, "a post the player has just set down starts it")
	var down := Vector3(0.0, -1.0, 0.0)
	_check(land.hits_post_square(Vector3(11.5, 20.0, 10.5), down, INF), "a tap from above onto the square is the post's")
	_check(land.hits_post_square(Vector3(10.5, 6.5, 0.0), Vector3(0.0, 0.0, 1.0), INF),
		"a tap on the post itself from the side is too")
	_check(not land.hits_post_square(Vector3(12.5, 20.0, 10.5), down, INF), "the next square is not")
	_check(not land.hits_post_square(Vector3(10.5, 6.5, 0.0), Vector3(0.0, 0.0, 1.0), 5.0),
		"nor a post hidden behind the world")
	land.game.link.welcome = {"id": 8}
	_check(not land.hits_post_square(Vector3(11.5, 20.0, 10.5), down, INF), "nor another's post")


class _Game:
	var link := {"welcome": {"id": 7}}
	var team := _Team.new()


class _Team:
	var view := {}


class _Who:
	var id := 0
	var nags: Array = []
	var position := Vector3.ZERO

	func _init(i: int) -> void:
		id = i

	func is_dead() -> bool:
		return false

	func nag(_key: String, text: String) -> void:
		nags.append(text)


func _ask(link, seq: int, kind: String, args: Array) -> Variant:
	var reply: Array = Protocol.decode(link.handle(Protocol.encode(Protocol.request(kind, seq, args))))
	return reply[1]


static func _decoded(list: Array) -> Array:
	return list.map(func(bytes: PackedByteArray) -> Array: return Protocol.decode(bytes))
