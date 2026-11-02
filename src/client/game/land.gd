extends RefCounted
## The land claimed, as the server tells it (Protocol.CLAIMS, SQUARES, LAND; the rules
## are src/shared/game/territory.gd): a copy of the claims and squares (`copy`, a
## Territory with no rules), how many squares the player and their team hold and may
## hold, and the painting mode (`painting`: taps on the ground paint squares or clear
## them, LAND_PAINT). Tells whose land the player stands on as they walk
## (`entered`, from `update`). `game` is the Main node.

const Territory := preload("res://src/shared/game/territory.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

## Something changed: the claims, the squares, the count, the mode.
signal changed
## The player walked into claim `claim` ({} out of every claim); `own` it is theirs or
## their team's.
signal entered(claim: Dictionary, own: bool)

var game
var copy := Territory.new()
var used := 0
var budget := 0
var painting := false
## The claim the player stood in last frame (its id, 0 for none).
var _in := -1


func _init() -> void:
	copy.claims_changed.connect(_changed)
	copy.squares_changed.connect(_on_squares)


func take_claims(list: Array) -> void:
	copy.take_claims(list)


func take_squares(list: Array, all: bool) -> void:
	copy.take_squares(list, all)


func take_land(args: Array) -> void:
	used = int(args[0])
	budget = int(args[1])
	changed.emit()


## True when claim `claim` is the player's or their team's.
func own(claim: Dictionary) -> bool:
	if claim.is_empty():
		return false
	var me := int(game.welcome.get("id", 0))
	if claim.by == me:
		return true
	for m: Array in game.team.view.get("members", []):
		if m[0] == claim.by:
			return true
	return false


## True when the player or their team has a claim (painting makes sense).
func has_own() -> bool:
	for claim: Dictionary in copy.claims.values():
		if own(claim):
			return true
	return false


## The claim at square `sq` ({} for none).
func claim_of(sq: Vector2i) -> Dictionary:
	var id: int = copy.squares.get(sq, 0)
	return copy.claims.get(id, {}) if id != 0 else {}


func set_painting(on: bool) -> void:
	if painting != on:
		painting = on
		changed.emit()


## Paints square `sq` (`on`) or clears it, through the server.
func paint(sq: Vector2i, on: bool) -> void:
	game.net.request(Protocol.LAND_PAINT, [sq, on])


## Each frame: tells when the player's feet go into another claim.
func update() -> void:
	var p: Vector3 = game.player.position
	var cell := Vector3i(floori(p.x / WorldData.CELL), game.player.level(), floori(p.z / WorldData.CELL))
	var claim := copy.claim_at(cell)
	var id: int = claim.get("id", 0)
	if id != _in:
		var first := _in == -1
		_in = id
		if not first or id != 0:
			entered.emit(claim, own(claim))


func _changed() -> void:
	changed.emit()


func _on_squares(_list: Array) -> void:
	changed.emit()
