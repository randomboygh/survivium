extends RefCounted
## The requests of one player, done by the rules of the session on the server's side
## (plan/architecture/server.md, Protocol): a request `[kind, seq, args]` is answered
## `[seq, value]` with what the rule returned. A request already answered (its `seq` not
## above the last) is answered as before and not done again: a message sent twice does
## one thing. The args are checked for their types before the rule sees them; a request
## that does not fit is answered null. Chests are named by the cell of the thing that
## holds them (Placed.at). The server will make one of these per player as they join;
## in single player LocalHost makes it.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")

var session
## The character playing (Character) and their workshop (Workshop).
var who
var workshop
## The last request answered and its reply, for a request sent twice.
var last_seq := -1
var last_reply: Array = []


func _init(s, w, shop) -> void:
	session = s
	who = w
	workshop = shop


## Answers request `msg`: the reply message.
func handle(msg: Array) -> Array:
	if msg.size() != 3 or not msg[0] is String or not msg[1] is int or not msg[2] is Array:
		return Protocol.reply(-1, null)
	var seq: int = msg[1]
	if seq <= last_seq:
		return last_reply if seq == last_seq else Protocol.reply(seq, null)
	last_seq = seq
	last_reply = Protocol.reply(seq, _do(msg[0], msg[2]))
	return last_reply


## Does request `kind` with `args` by the rules; what the rule gave back.
func _do(kind: String, args: Array) -> Variant:
	var actions = session.actions
	var placed = session.placed
	match kind:
		Protocol.DIG:
			if _fit(args, [TYPE_VECTOR3I, TYPE_VECTOR3I]):
				return actions.dig_at(who, args[0], args[1])
		Protocol.PLACE:
			if _fit(args, [TYPE_VECTOR3I, TYPE_VECTOR3I, TYPE_INT]):
				return actions.place_at(who, args[0], args[1], args[2])
		Protocol.FRONT:
			if _fit(args, [TYPE_INT]):
				return actions.act_in_front(who, args[0])
		Protocol.GATHER:
			if _fit(args, [TYPE_DICTIONARY]):
				return actions.gather(who, args[0])
		Protocol.PICKUP:
			if _fit(args, [TYPE_INT, TYPE_BOOL]):
				actions.pick_up_near(who, args[0], args[1])
				return true
		Protocol.PLANT:
			if _fit(args, [TYPE_STRING]):
				return actions.plant(who, args[0])
		Protocol.PLANT_AT:
			if _fit(args, [TYPE_STRING, TYPE_VECTOR3I]):
				return actions.plant_at(who, args[0], args[1])
		Protocol.EAT:
			if _fit(args, [TYPE_INT]) and _slot(who.inventory, args[0]):
				return who.eat(args[0])
		Protocol.THROW:
			if _fit(args, [TYPE_INT, TYPE_INT]) and _slot(who.inventory, args[0]):
				who.throw_away(args[0], args[1])
				return true
		Protocol.PROP_PUT:
			if _fit(args, [TYPE_STRING, TYPE_INT, TYPE_INT]):
				return placed.put_from_bag(who, args[0], args[1], args[2])
		Protocol.PROP_TAKE:
			if _fit(args, [TYPE_VECTOR3I]):
				var e: Dictionary = placed.at(args[0])
				return not e.is_empty() and placed.take_up(who, e)
		Protocol.PROP_FIRE:
			if _fit(args, [TYPE_VECTOR3I, TYPE_BOOL]):
				var e: Dictionary = placed.at(args[0])
				if e.is_empty() or not placed.is_fire(e):
					return false
				if args[1]:
					return placed.light(who, e)
				placed.put_out(e)
				return true
		Protocol.PROP_DESTROY:
			if _fit(args, [TYPE_VECTOR3I]):
				var e: Dictionary = placed.at(args[0])
				return not e.is_empty() and placed.destroy(e)
		Protocol.CRAFT:
			if _fit(args, [TYPE_STRING, TYPE_INT]) and Crafting.BY_ID.has(args[0]):
				return workshop.start(Crafting.get_recipe(args[0]), args[1])
		Protocol.CRAFT_CANCEL:
			if _fit(args, [TYPE_INT]):
				workshop.cancel(args[0])
				return true
		Protocol.CRAFT_CANCEL_ALL:
			workshop.cancel_all()
			return true
		Protocol.CRAFT_PAUSE:
			if _fit(args, [TYPE_BOOL]):
				workshop.paused = args[0]
				return workshop.paused
		Protocol.REPAIR:
			if _fit(args, [TYPE_INT]) and _slot(who.inventory, args[0]):
				return workshop.repair(args[0])
		Protocol.BAG_PUT:
			if args.size() == 4 and args[1] is int and args[3] is int:
				var from = _bag(args[0])
				var to = _bag(args[2])
				if from != null and to != null and _slot(from, args[1]) and _slot(to, args[3]):
					return from.put_into(args[1], to, args[3])
		Protocol.BAG_MOVE:
			if args.size() == 3 and args[1] is int:
				var from = _bag(args[0])
				var to = _bag(args[2])
				if from != null and to != null and _slot(from, args[1]):
					return from.move_slot(args[1], to)
		Protocol.BAG_ALL:
			if args.size() == 3 and args[2] is int:
				var from = _bag(args[0])
				var to = _bag(args[1])
				if from != null and to != null:
					return from.move_all(to, args[2])
		Protocol.SORT:
			if args.size() == 3 and args[1] is String and args[2] is int:
				var where = _bag(args[0])
				if where != null:
					where.sort(args[1], args[2])
					return true
		Protocol.BAG_DESTROY:
			if args.size() == 2 and args[1] is int:
				var where = _bag(args[0])
				if where != null and _slot(where, args[1]):
					return where.take_slot(args[1], 1 << 20)
		Protocol.REVIVE:
			if _fit(args, [TYPE_VECTOR3]):
				who.revive(args[0])
				return true
	return null


## True when `args` are of `types`, one each.
static func _fit(args: Array, types: Array) -> bool:
	if args.size() != types.size():
		return false
	for i in types.size():
		if typeof(args[i]) != types[i]:
			return false
	return true


static func _slot(inv, i: int) -> bool:
	return i >= 0 and i < inv.slots.size()


## The bag `where` names: the player's for null, a chest's for the cell of the thing
## that holds it; null for a cell with no such thing.
func _bag(where: Variant):
	if where == null:
		return who.inventory
	if where is Vector3i:
		var e: Dictionary = session.placed.at(where)
		return e.get("items") if not e.is_empty() else null
	return null
