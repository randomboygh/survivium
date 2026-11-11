extends RefCounted
## The player's team as the server tells it (Protocol.TEAM, INVITES; the rules are
## src/shared/game/teams.gd): the team ({} for none: "id", "name", "lead", "members"
## [[id, name]…]), the invitations waiting ([[id, name]…]) and those the player sent
## waiting for an answer (`sent`: [[id, until (Time seconds)]…]). Asks the server to
## invite, accept, decline, leave, put out and rename through `game.net`.

const Protocol := preload("res://src/shared/net/protocol.gd")

## The team or the invitations changed.
signal changed

var game
var view := {}
var invites: Array = []
var sent: Array = []
## Fighting, as the server tells it (Protocol.FIGHT; the rules are src/shared/game/
## fights.gd): the server's mode ("off", "land", "all"), whole minutes of the player's
## protection as a newcomer left, whole seconds of their fight left.
var pvp := "land"
var protected := 0
var fight := 0


func take_team(v: Dictionary) -> void:
	view = v
	changed.emit()


func take_invites(list: Array, out: Array = []) -> void:
	invites = list.filter(func(e: Variant) -> bool: return e is Array and e.size() == 2 and e[0] is int)
	var now := Time.get_ticks_msec() / 1000.0
	sent = []
	for e: Variant in out:
		if e is Array and e.size() == 2 and e[0] is int and (e[1] is float or e[1] is int):
			sent.append([e[0], now + float(e[1])])
	changed.emit()


## The invitations sent still waiting: [[id, seconds left]…].
func sent_waiting() -> Array:
	var now := Time.get_ticks_msec() / 1000.0
	return sent.filter(func(e: Array) -> bool: return e[1] > now).map(func(e: Array) -> Array: return [e[0], e[1] - now])


func take_fight(f: Array) -> void:
	var was := [pvp, protected]
	pvp = str(f[0])
	protected = int(f[1])
	fight = int(f[2])
	if [pvp, protected] != was:
		changed.emit()


## Gives the protection as a newcomer up (Fights.give_up).
func give_up_protection() -> void:
	game.net.request(Protocol.FIGHT_BRAVE, [])


## True in a team.
func has_team() -> bool:
	return not view.is_empty()


## True when the player leads their team.
func leads() -> bool:
	return has_team() and int(view.get("lead", -1)) == int(game.welcome.get("id", -2))


func invite(id: int) -> void:
	game.net.request(Protocol.TEAM_INVITE, [id])


func accept(id: int) -> void:
	game.net.request(Protocol.TEAM_ACCEPT, [id])


func decline(id: int) -> void:
	game.net.request(Protocol.TEAM_DECLINE, [id])


func leave() -> void:
	game.net.request(Protocol.TEAM_LEAVE, [])


func kick(id: int) -> void:
	game.net.request(Protocol.TEAM_KICK, [id])


func rename(name: String) -> void:
	game.net.request(Protocol.TEAM_NAME, [name])


func say(text: String) -> void:
	game.net.request(Protocol.TEAM_CHAT, [text])
