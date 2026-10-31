extends RefCounted
## What the client and the server say to each other (plan/architecture/server.md): the
## kinds of request the client makes of the rules and the shape of a message on the
## wire. A message is an Array, never an object, so the same bytes go through a loop in
## the game's own process (single player, LocalHost) and through a socket (a server
## far away): `[kind, seq, args]` for a request, `[seq, value]` for its reply. `seq`
## grows by one with each request of a player, so a request sent twice is answered
## twice the same way and done once (Requests). An event `[kind, args]` has no reply:
## the client's body each frame, the server's state for the client's copies. The bytes
## are var_to_bytes of the Array: Vector3i, Dictionary and String go through as they are.

## The protocol's version: a client and a server of different versions do not play.
const VERSION := 1

## The requests, each with its args. The rules they reach are in src/shared/game/; what
## each gives back is what that rule returns (Requests._do).
## Works at a cell tapped on a face with the hand in use: [cell, normal] (WorldActions.dig_at).
const DIG := "dig"
## Places the block held with the brush around a cell, below the cut: [center, normal, top] (place_at).
const PLACE := "place"
## The action button: works in front of the player below the cut: [top] (act_in_front).
const FRONT := "front"
## Gathers what was tapped: [target] (gather), the target as WorldActions reads it.
const GATHER := "gather"
## Takes the things lying near the feet: [mode, past_limit] (pick_up_near).
const PICKUP := "pickup"
## Plants or sows the item held in front: [id] (plant).
const PLANT := "plant"
## Plants or sows at the cell tapped: [id, cell] (plant_at).
const PLANT_AT := "plant_at"
## Eats from a slot of the bag, or puts on a bandage: [slot] (Character.eat).
const EAT := "eat"
## Throws out of a slot of the bag: [slot, n] (Character.throw_away).
const THROW := "throw"
## Sets a thing down from the bag in front, below the cut: [id, slot, top] (Placed.put_from_bag).
const PROP_PUT := "prop_put"
## Takes a thing placed back into the bag: [cell] (Placed.take_up).
const PROP_TAKE := "prop_take"
## Puts out a campfire or lights it again: [cell, on] (Placed.put_out, Placed.light).
const PROP_FIRE := "prop_fire"
## Destroys a campfire put out: [cell] (Placed.destroy).
const PROP_DESTROY := "prop_destroy"
## Starts a recipe some times at the workshop: [recipe id, n] (Workshop.start).
const CRAFT := "craft"
## Cancels a job of the queue: [i] (Workshop.cancel).
const CRAFT_CANCEL := "craft_cancel"
## Cancels every job (Workshop.cancel_all).
const CRAFT_CANCEL_ALL := "craft_cancel_all"
## Pauses the queue or lets it go on: [on] (Workshop.paused).
const CRAFT_PAUSE := "craft_pause"
## Mends the tool in a slot of the bag: [slot] (Workshop.repair).
const REPAIR := "repair"
## Puts a stack into a slot of the bag or a chest: [from, i, to, j] (Inventory.put_into);
## a bag or chest is null for the player's bag or the cell of the chest.
const BAG_PUT := "bag_put"
## Moves a stack from a bag or a chest into another: [from, i, to] (Inventory.move_slot).
const BAG_MOVE := "bag_move"
## Moves every stack from a slot on into another bag or chest: [from, to, first] (Inventory.move_all).
const BAG_ALL := "bag_all"
## Sorts a bag or a chest from a slot on: [where, by, first] (Inventory.sort).
const SORT := "sort"
## Destroys the stack in a slot of a bag or a chest, the bin: [where, i]
## (Inventory.take_slot); the stack taken.
const BAG_DESTROY := "bag_destroy"
## Comes back to life at a point: [at] (Character.revive).
const REVIVE := "revive"

## The events: `[kind, args]`, with no reply. From the client, each frame: where its
## body is and what it does. From the server: what the player's state became, for the
## client's copies (Mirror).
## The client's body and hands: [position, feet cell, facing step, hands, active hand,
## brush, moving, swimming, jumped, air jumps, bumped].
const INPUT := "input"
## The player's own state changed: {"inventory", "vitals", "state", "home",
## "held_back"} (each as to_dict gives it; vitals as VITALS).
const YOU := "you"
## What the player knows how to make changed: [Knowledge.to_dict()].
const KNOWLEDGE := "knowledge"
## The body's state, every tick it changes: [health, satiety, stamina, hunger, hurt_by].
const VITALS := "vitals"
## The workshop: {"queue", "paused"}.
const SHOP := "shop"
## A line for the player: [text].
const SAY := "say"
## A recipe was made: [recipe id].
const MADE := "made"
## Things lying on the ground changed in a chunk: [key].
const DROPS := "drops"
## The body is put at a point (coming back to life, the playtest page): [at].
const TELEPORT := "teleport"
## The body is thrown (a burning campfire): [dir, speed, hop] (Body.knock).
const KNOCK := "knock"


## An event message.
static func event(kind: String, args: Variant) -> Array:
	return [kind, args]


## A request message.
static func request(kind: String, seq: int, args: Array) -> Array:
	return [kind, seq, args]


## The reply to request `seq`.
static func reply(seq: int, value: Variant) -> Array:
	return [seq, value]


## A message as bytes for the wire.
static func encode(msg: Array) -> PackedByteArray:
	return var_to_bytes(msg)


## The message in `bytes`, or an empty Array when it is not one.
static func decode(bytes: PackedByteArray) -> Array:
	var v: Variant = bytes_to_var(bytes)
	return v if v is Array else []
