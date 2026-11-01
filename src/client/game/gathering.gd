extends RefCounted
## Gathering on the screen: a tap or a click finds the nearest thing to gather within a
## finger's reach of the point on the screen (plan/design/ui.md: cells are too small to
## hit), within reach of the player: a thing lying on the ground, a bush, a placed thing.
## A placed thing opens its window; the rest goes to the rules (WorldActions: picking
## up, berries and branches, felling and digging out bushes). The hint under the pointer
## says what a tap would do. Things lying close to the player fly into the bag by
## themselves unless the setting is off. `game` is the Main node.

const Items := preload("res://src/shared/content/items.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const WorldActions := preload("res://src/shared/game/world_actions.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")

const CELL := WorldData.CELL
## How far from the player a thing on the ground or a placed thing can be taken or used,
## in world units (the rules' own, which the server checks with a slack).
const REACH := WorldActions.HAND_REACH
## How near the point on the screen a thing must be, in pixels of the world image: a
## finger is wider than a mouse pointer.
const FINGER := 14.0
const POINTER := 7.0
## How often the things lying near the player are taken by themselves, in seconds.
const PICKUP_INTERVAL := 0.15

var game
var _pickup_clock := 0.0


func _init(g) -> void:
	game = g


## The thing to gather nearest the screen point, or {}: {"drop": [chunk key, index]},
## {"bush": cell} or {"prop": a record of Props.placed}, with "at" its position in world
## units. Bushes are within the reach of the tool in hand, things on the ground and
## placed things within REACH.
func target_at(screen_pos: Vector2) -> Dictionary:
	if not game.ready_to_play:
		return {}
	var view = game.view
	var vp_pos: Vector2 = (screen_pos - view.container.global_position) / view.view_scale
	var radius: float = FINGER if game.controls.touch else POINTER
	var best := {}
	var best_d := radius
	var player_pos: Vector3 = game.player.position + Vector3(0.0, 0.5, 0.0)
	var world = game.world
	var bush_reach: float = game.controls.tool_record().reach * CELL
	# A placed thing is big: it is hit 6 px farther than the radius, and the nearest wins.
	var prop_d := radius + 6.0
	for e: Dictionary in game.placed.things:
		var at: Vector3 = game.placed.center(e)
		if at.distance_to(player_pos) <= REACH:
			var d := _screen_distance(at, vp_pos)
			if d < prop_d:
				prop_d = d
				best_d = d
				best = {"prop": e, "at": at}
	var home := WorldData.chunk_key(floori(player_pos.x / CELL), floori(player_pos.z / CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := home + Vector2i(dx, dz)
			var list: Array = world.drops.get(key, [])
			for i in list.size():
				var at: Vector3 = list[i][1]
				var d := _screen_distance(at + Vector3(0.0, 0.1, 0.0), vp_pos)
				if d < best_d and at.distance_to(player_pos) <= REACH:
					best_d = d
					best = {"drop": [key, i], "at": at}
			var x0: int = key.x << WorldData.SHIFT
			var z0: int = key.y << WorldData.SHIFT
			for cell in world.bushes_in(x0, z0):
				var at := (Vector3(cell) + Vector3(0.5, 0.4, 0.5)) * CELL
				var d := _screen_distance(at, vp_pos)
				if d < best_d and at.distance_to(player_pos) <= bush_reach:
					best_d = d
					best = {"bush": cell, "at": at}
	return best


## Distance on the world image between world point `p` and image point `vp_pos`.
func _screen_distance(p: Vector3, vp_pos: Vector2) -> float:
	var view = game.view
	var center := PixelView.plane_of(Vector2(view.camera.global_position.x, view.camera.global_position.z))
	var on_image := (PixelView.screen_plane(p) - center) * PixelView.PIXELS_PER_UNIT + Vector2(view.image_size) * 0.5
	return on_image.distance_to(vp_pos)


## What a tap on `target` would do, for the hint under the pointer.
func describe(target: Dictionary) -> String:
	if target.has("prop"):
		var e: Dictionary = target.prop
		var title := Items.title(e.item)
		if e.items != null:
			return "%s\nЛКМ открыть" % title
		return "%s\nЛКМ крафт" % title
	if target.has("drop"):
		var d: Array = game.world.drops[target.drop[0]][target.drop[1]]
		if d[0] == Items.SACK:
			return "Мешок с вещами\nЛКМ забрать"
		var n: int = WorldActions.count(d)
		return "%s%s\nЛКМ подобрать" % [Items.title(d[0]), " ×%d" % n if n > 1 else ""]
	var cell: Vector3i = target.bush
	var b: Dictionary = Bushes.TYPES[game.world.bushes[cell]]
	var tool: String = game.controls.tool_record().tool
	if tool == "shovel":
		return "%s\nЛКМ выкопать" % b.title
	if tool == "axe":
		return "%s\nЛКМ срубить" % b.title
	if game.actions.ripe(cell, b):
		return "%s, ягоды\nЛКМ %s" % [b.title, "сбить" if tool == "sword" else "собрать"]
	if game.actions.twigs_left(cell, b) > 0 and tool == "hand":
		return "%s\nЛКМ наломать веток" % b.title
	return "%s\nпусто до весны" % b.title


## Gathers `target` (see target_at) with what is in the hand in use: a placed thing
## opens, the rest is WorldActions.gather through the server. True if anything was done
## (over the loop the reply is in at once; over a socket it is false until then).
func gather(target: Dictionary) -> bool:
	if target.has("prop"):
		game.hud.open_prop(target.prop)
		return true
	var r = game.net.request(Protocol.GATHER, [target])
	return r.done and r.value is bool and r.value


## Takes by themselves the things lying near the player's feet, unless the setting is
## off; called every frame.
func update(delta: float) -> void:
	_pickup_clock += delta
	if _pickup_clock < PICKUP_INTERVAL:
		return
	_pickup_clock = 0.0
	var v: Dictionary = game.settings.values
	game.net.request(Protocol.PICKUP, [int(v.pickup), bool(v.pickup_heavy)])
