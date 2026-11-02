extends RefCounted
## The player's team as the server tells it (Protocol.TEAM, INVITES; the rules are
## src/shared/game/teams.gd): the team ({} for none: "id", "name", "lead", "members"
## [[id, name]…]) and the invitations waiting ([[id, name]…]). Asks the server to
## invite, accept, decline, leave, put out and rename through `game.net`.

const Protocol := preload("res://src/shared/net/protocol.gd")

## The team or the invitations changed.
signal changed

var game
var view := {}
var invites: Array = []


func take_team(v: Dictionary) -> void:
	view = v
	changed.emit()


func take_invites(list: Array) -> void:
	invites = list.filter(func(e: Variant) -> bool: return e is Array and e.size() == 2 and e[0] is int)
	changed.emit()


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
