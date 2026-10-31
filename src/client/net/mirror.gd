extends RefCounted
## The client's copies of what the server holds (plan/architecture/server.md): the
## player's character (the bag, the body's state, death) and workshop, the things placed
## on cells, the clock and the animals, fed by the server's events (Protocol.YOU, VITALS,
## KNOWLEDGE, SHOP, SAY, MADE, DROPS, TELEPORT, KNOCK, PUSH; PROPS, PROP, PROP_GONE,
## PROP_LIT, CHEST; CLOCK; ANIMAL, ANIMAL_GONE, SNAP, STEP; PEOPLE, PERSON_GONE (the other
## players, `game.others`); HEARD (the chat, `game.hud.chat`, and the line over the
## speaker's head); over a socket the world too:
## CHUNK, FORGET, CELLS, DROPS with the list, TAKEN, into `game.world_maker` (RemoteGen),
## the world and `game.actions`' signals), and the client's own event each frame: where
## its body is and what the hands do (INPUT), which the rules on the server act from.
## `game` is the Main node; the copies are `game.character`, `game.workshop`,
## `game.placed`, `game.clock` and `game.wildlife`.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")

const CELL := WorldData.CELL

var game
## The last INPUT sent: the next goes only when something changed.
var _last: Array = []
## World units past the screen's edge an animal still counts as looked at (it moves
## every frame, so one walking in is already on its way; see Wildlife.look_from).
const SEEN_MARGIN := 4.0


func _init(g) -> void:
	game = g


## Listens to connection `net` (Connection): its events, and sends the body before each
## request, so the rules act from where the body is now.
func watch(net) -> void:
	net.event.connect(_on_event)
	net.sending.connect(send_input)


## Gives the copies the events that came before the world was made.
func replay() -> void:
	var events := _pending
	_pending = []
	for e: Array in events:
		_on_event(e[0], e[1])


## Tells the server where the body is and what the hands hold (INPUT) when any of it
## changed since the last time.
func send_input() -> void:
	var p = game.player
	var c = game.controls
	# The hands are copied: an Array made of the controls' shares their data, so the
	# last input sent would change with them and never differ.
	# The screen: half its size in world units (the tops keep their pixels a cell at any
	# tilt, PixelView.squash 1), along the camera's right and across it.
	var half: Vector2 = Vector2(game.view.viewport.size) / PixelView.PIXELS_PER_UNIT * 0.5 + Vector2.ONE * SEEN_MARGIN
	var now: Array = [p.position, c.feet(), c.step(), [c.hands[0], c.hands[1]], c.active, c.brush,
		p.body.move_input.length() > 0.1, p.body.swimming, p.body.jumped, p.body.air_jumps, p.body.bumped,
		PixelView.right, half, p.body.on_ground, p.work_kind, p.work_length, p.work_n, p.work_at]
	if now == _last:
		return
	_last = now
	game.net.send(Protocol.INPUT, now)


## Events that came before the world was made (over a socket the server speaks right
## after the welcome), replayed by `replay` once it is.
var _pending: Array = []


func _on_event(kind: String, args: Variant) -> void:
	if game.world == null:
		_pending.append([kind, args])
		return
	var who = game.character
	match kind:
		Protocol.YOU:
			if args is Dictionary:
				who.take(args)
		Protocol.KNOWLEDGE:
			if args is Array and args.size() == 1 and args[0] is Dictionary:
				game.workshop.take_knowledge(args[0])
		Protocol.VITALS:
			if args is Array:
				who.take_vitals(args)
		Protocol.SHOP:
			if args is Dictionary:
				game.workshop.take(args)
		Protocol.SAY:
			if args is Array and args.size() == 1:
				who.say(str(args[0]))
		Protocol.MADE:
			if args is Array and args.size() == 1:
				var r := Crafting.get_recipe(str(args[0]))
				if not r.is_empty():
					game.workshop.made.emit(r)
		Protocol.DROPS:
			if args is Array and args.size() >= 1 and args[0] is Vector2i:
				if args.size() == 2 and args[1] is Array and game.host == null:
					game.world.drops[args[0]] = args[1]
				game.props.show_drops(args[0])
		Protocol.CHUNK:
			if args is Array and args.size() == 3 and args[0] is Vector2i and args[1] is int and args[2] is PackedByteArray \
					and game.host == null:
				game.world_maker.take_chunk(args[0], args[1], args[2])
		Protocol.FORGET:
			if args is Array and args.size() == 1 and args[0] is Vector2i and game.host == null:
				game.world_maker.forget(args[0])
				game.chunks.unload_chunk(args[0])
		Protocol.CELLS:
			if args is Array and game.host == null:
				for c in args:
					if c is Array and c.size() == 2 and c[0] is Vector3i and c[1] is int:
						var cell: Vector3i = c[0]
						if game.world.has_chunk(WorldData.chunk_key(cell.x, cell.z)):
							game.world.set_cell(cell.x, cell.y, cell.z, c[1])
							game.actions.cell_changed.emit(cell)
		Protocol.TAKEN:
			if args is Array and args.size() == 2 and args[0] is String and args[1] is Vector3 and game.host == null:
				game.actions.taken.emit(args[0], args[1])
		Protocol.TELEPORT:
			if args is Array and args.size() == 1 and args[0] is Vector3:
				who.teleport(args[0])
				game.player.visible = not who.is_dead()
		Protocol.KNOCK:
			if args is Array and args.size() == 3 and args[0] is Vector2:
				game.player.body.knock(args[0], float(args[1]), float(args[2]))
		Protocol.PUSH:
			if args is Array and args.size() == 1 and args[0] is Vector3:
				var push: Vector3 = args[0]
				game.player.body.nudge += Vector2(push.x, push.z) / CELL
		Protocol.PROPS:
			if args is Array and args.size() == 1 and args[0] is Array:
				game.placed.take_all(args[0])
		Protocol.PROP:
			if args is Array and args.size() == 1 and args[0] is Dictionary:
				game.placed.take_prop(args[0])
		Protocol.PROP_GONE:
			if args is Array and args.size() == 1 and args[0] is Vector3i:
				game.placed.take_gone(args[0])
		Protocol.PROP_LIT:
			if args is Array and args.size() == 2 and args[0] is Vector3i:
				game.placed.take_lit(args[0], bool(args[1]))
		Protocol.CHEST:
			if args is Array and args.size() == 2 and args[0] is Vector3i and args[1] is Dictionary:
				game.placed.take_chest(args[0], args[1])
		Protocol.CLOCK:
			if args is Array and args.size() == 1 and args[0] is Array:
				game.clock.from_snapshot(args[0])
		Protocol.ANIMAL:
			if args is Array:
				game.wildlife.take_born(args)
		Protocol.ANIMAL_GONE:
			if args is Array:
				game.wildlife.take_gone(args)
		Protocol.SNAP:
			if args is Array:
				game.wildlife.take_snap(args)
		Protocol.STEP:
			if args is Array:
				game.wildlife.take_step(args)
		Protocol.PEOPLE:
			if args is Array:
				game.others.take_people(args)
		Protocol.PERSON_GONE:
			if args is Array and args.size() == 1 and args[0] is int:
				game.others.take_gone(args[0])
		Protocol.HEARD:
			if args is Array and args.size() == 3 and args[0] is int:
				game.hud.chat.hear(args[0], str(args[1]), str(args[2]))
				game.others.speak(args[0], str(args[2]))
