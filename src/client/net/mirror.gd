extends RefCounted
## The client's copies of what the server holds (plan/architecture/server.md): the
## player's character (the bag, the body's state, death) and workshop, the things placed
## on cells, the clock and the animals, fed by the server's events (Protocol.YOU, VITALS,
## KNOWLEDGE, SHOP, SAY, MADE, DROPS, TELEPORT, KNOCK, PUSH; PROPS, PROP, PROP_GONE,
## PROP_LIT, CHEST; CLOCK; ANIMAL, ANIMAL_GONE, SNAP, STEP), and the client's own event
## each frame: where its body is and what the hands do (INPUT), which the rules on the
## server act from. `game` is the Main node; the copies are `game.character`,
## `game.workshop`, `game.placed`, `game.clock` and `game.wildlife`.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL

var game
## The last INPUT sent: the next goes only when something changed.
var _last: Array = []


func _init(g) -> void:
	game = g


## Listens to connection `net` (Connection): its events, and sends the body before each
## request, so the rules act from where the body is now.
func watch(net) -> void:
	net.event.connect(_on_event)
	net.sending.connect(send_input)


## Tells the server where the body is and what the hands hold (INPUT) when any of it
## changed since the last time.
func send_input() -> void:
	var p = game.player
	var c = game.controls
	# The hands are copied: an Array made of the controls' shares their data, so the
	# last input sent would change with them and never differ.
	var now: Array = [p.position, c.feet(), c.step(), [c.hands[0], c.hands[1]], c.active, c.brush,
		p.body.move_input.length() > 0.1, p.body.swimming, p.body.jumped, p.body.air_jumps, p.body.bumped]
	if now == _last:
		return
	_last = now
	game.net.send(Protocol.INPUT, now)


func _on_event(kind: String, args: Variant) -> void:
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
			if args is Array and args.size() == 1 and args[0] is Vector2i:
				game.props.show_drops(args[0])
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
