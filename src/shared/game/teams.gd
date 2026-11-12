extends RefCounted
## The teams of a world (plan/design/territory-pvp.md, decision 50): a player is in
## one team at most; one joins by an invitation of a member, and leaves when they wish.
## The one who made the team leads it (`lead`): only they put a member out; when the
## lead leaves, the member longest in the team leads. A team of one is no team: when
## the last but one leaves, it is gone. Players are named by their number on the server
## (Player.id) and their name as they had it when last seen (`names`), so a team lists
## the members who are not in the world too. An invitation waits INVITE_TIME seconds.
## Kept in the world's save (to_dict, from_dict). Changes are told by `changed`: the
## numbers of the players whose team (or lack of one) is now different.

## Seconds an invitation waits for an answer.
const INVITE_TIME := 120.0
## Letters a team's name keeps at most.
const NAME_MAX := 24

## The players whose team changed (they joined, left, were put out, a member came or
## went, the lead or the name changed).
signal changed(ids: Array)
## Player `to` was invited by player `from` named `from_name`.
signal invited(to: int, from: int, from_name: String)

## The teams by number: {"name", "lead": player, "members": [players, the first come
## first]}.
var teams := {}
## The team of each player in one, by player.
var of := {}
## The last name of each player in a team, by player.
var names := {}
## The invitations waiting, by the player invited: {from player: when (seconds)}.
var invites := {}
var next_team := 1


## The team of player `id`, 0 for none.
func team_of(id: int) -> int:
	return int(of.get(id, 0))


## True when players `a` and `b` are in one team (a player is with themselves).
func together(a: int, b: int) -> bool:
	if a == b:
		return true
	var t := team_of(a)
	return t != 0 and t == team_of(b)


## The members of team `t`, the lead first then by when they came; [] for none.
func members(t: int) -> Array:
	var team: Dictionary = teams.get(t, {})
	return team.get("members", []).duplicate()


## Player `from` (named `from_name`) invites player `to` (named `to_name`): false when
## `to` is in a team already, is `from`, or has this invitation waiting. A player in no
## team who invites makes a team when the other accepts.
func invite(from: int, from_name: String, to: int, now: float) -> bool:
	if from == to or team_of(to) != 0:
		return false
	_expire(now)
	var waiting: Dictionary = invites.get(to, {})
	if waiting.has(from):
		return false
	waiting[from] = now
	invites[to] = waiting
	names[from] = from_name
	invited.emit(to, from, from_name)
	return true


## The players who invited `id` and wait for an answer: [[player, name]…].
func invites_of(id: int, now: float) -> Array:
	_expire(now)
	var out := []
	for from: int in invites.get(id, {}):
		out.append([from, str(names.get(from, ""))])
	return out


## The players `id` invited who have not answered yet: [[player, seconds left]…].
func sent_of(id: int, now: float) -> Array:
	_expire(now)
	var out := []
	for to: int in invites:
		if invites[to].has(id):
			out.append([to, maxf(0.0, INVITE_TIME - (now - float(invites[to][id])))])
	return out


## Player `id` (named `name`) accepts the invitation of player `from`: joins their team
## (made now if `from` has none, named after them, `from` leading). False when there is
## no such invitation, `from` left the world's teams meanwhile into another, or `id` is
## in a team.
func accept(id: int, name: String, from: int, now: float) -> bool:
	_expire(now)
	var waiting: Dictionary = invites.get(id, {})
	if not waiting.has(from) or team_of(id) != 0:
		return false
	invites.erase(id)
	names[id] = name
	var t := team_of(from)
	var told := []
	if t == 0:
		t = next_team
		next_team += 1
		teams[t] = {"name": "Team %s" % str(names.get(from, "")), "lead": from, "members": [from]}
		of[from] = t
	told = members(t)
	teams[t].members.append(id)
	of[id] = t
	told.append(id)
	changed.emit(told)
	return true


## Player `id` turns down the invitation of `from` (all of them for `from` 0).
func decline(id: int, from: int) -> bool:
	var waiting: Dictionary = invites.get(id, {})
	# Those who invited learn it (their invitations sent, sent_of).
	var told: Array = waiting.keys() if from == 0 else ([from] if waiting.has(from) else [])
	var done: bool
	if from == 0:
		done = invites.erase(id)
	else:
		done = waiting.erase(from)
		if waiting.is_empty():
			invites.erase(id)
	if not told.is_empty():
		changed.emit(told)
	return done


## Player `id` leaves their team; false when in none.
func leave(id: int) -> bool:
	var t := team_of(id)
	if t == 0:
		return false
	_out(t, id)
	return true


## The lead `by` puts member `id` out of the team; false when `by` does not lead or
## `id` is not in their team.
func kick(by: int, id: int) -> bool:
	var t := team_of(by)
	if t == 0 or by == id or teams[t].lead != by or team_of(id) != t:
		return false
	_out(t, id)
	return true


## The lead `by` names their team `name` (trimmed, cut to NAME_MAX); false when `by`
## does not lead or the name is empty.
func rename(by: int, name: String) -> bool:
	var t := team_of(by)
	var line := name.strip_edges().replace("\n", " ").left(NAME_MAX)
	if t == 0 or teams[t].lead != by or line == "":
		return false
	teams[t].name = line
	changed.emit(members(t))
	return true


## Player `id` is now named `name` (they came in under it): the teams list it so.
func seen(id: int, name: String) -> void:
	if team_of(id) != 0 and names.get(id) != name:
		names[id] = name
		changed.emit(members(team_of(id)))


## What player `id` is told of their team: {"id": team, "name", "lead", "members":
## [[player, name]…]} or {} when in none.
func view(id: int) -> Dictionary:
	var t := team_of(id)
	if t == 0:
		return {}
	var out := []
	for m: int in teams[t].members:
		out.append([m, str(names.get(m, ""))])
	return {"id": t, "name": teams[t].name, "lead": teams[t].lead, "members": out}


func to_dict() -> Dictionary:
	var list := []
	for t: int in teams:
		list.append({"id": t, "name": teams[t].name, "lead": teams[t].lead, "members": teams[t].members.duplicate()})
	var named := {}
	for id: int in names:
		named[str(id)] = names[id]
	return {"teams": list, "names": named, "next": next_team}


func from_dict(d: Dictionary) -> void:
	teams.clear()
	of.clear()
	names.clear()
	invites.clear()
	next_team = int(d.get("next", 1))
	for e in d.get("teams", []):
		if not e is Dictionary:
			continue
		var t := int(e.get("id", 0))
		var list := []
		for m in e.get("members", []):
			if not of.has(int(m)):
				list.append(int(m))
		if t <= 0 or list.size() < 2:
			continue
		var lead := int(e.get("lead", list[0]))
		if not list.has(lead):
			lead = list[0]
		teams[t] = {"name": str(e.get("name", "")), "lead": lead, "members": list}
		for m: int in list:
			of[m] = t
		next_team = maxi(next_team, t + 1)
	var named: Dictionary = d.get("names", {})
	for k in named:
		names[int(k)] = str(named[k])


## Member `id` goes out of team `t`; the lead passes on, and a team left with one is gone.
func _out(t: int, id: int) -> void:
	var team: Dictionary = teams[t]
	var told: Array = team.members.duplicate()
	team.members.erase(id)
	of.erase(id)
	if team.members.size() < 2:
		for m: int in team.members:
			of.erase(m)
		teams.erase(t)
	elif team.lead == id:
		team.lead = team.members[0]
	changed.emit(told)


## Drops the invitations older than INVITE_TIME.
func _expire(now: float) -> void:
	for to: int in invites.keys():
		var waiting: Dictionary = invites[to]
		for from: int in waiting.keys():
			if now - float(waiting[from]) > INVITE_TIME:
				waiting.erase(from)
		if waiting.is_empty():
			invites.erase(to)
