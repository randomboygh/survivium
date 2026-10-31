extends RefCounted
## What the client and the server say to each other (plan/architecture/server.md): the
## kinds of request the client makes of the rules and the shape of a message on the
## wire. A message is an Array, never an object, so the same bytes go through a loop in
## the game's own process (single player, LocalHost) and through a socket (a server
## far away): `[kind, seq, args]` for a request, `[seq, value]` for its reply. `seq`
## grows by one with each request of a player, so a request sent twice is answered
## twice the same way and done once (Requests). An event `[kind, args]` has no reply:
## the client's body each frame, the server's state for the client's copies (the
## player's own, the things placed, the clock, the animals). The bytes
## are var_to_bytes of the Array: Vector3i, Dictionary and String go through as they are.
## Over a socket (С3) each message is one binary WebSocket frame; the first request on
## it is HELLO, and nothing else is read until the server has welcomed the player.

## The protocol's version: a client and a server of different versions do not play.
const VERSION := 1
## The port a server listens on when it is not told another (the address a player
## types without one goes there).
const PORT := 7777
## The file CI writes the build's version into (tools/build_info.py); "dev" without it.
const BUILD_INFO := "res://build_info.json"

## The first request over a socket: [VERSION, the build's version (build_version), the
## player's name, the key the server gave the player before ("" the first time), the
## server's password ("" when it asks none)]. The reply is the welcome: {"ok": true,
## "id", "key" (keep it for this server), "name" (as the server took it), "title" (the
## server's name), "seed",
## "settings", "mods" (the bundles of the world, in order), "materials" (the ids in the
## order the cells are numbered), "spawn", "at" (where the character is)}; or the
## refusal {"ok": false, "why": one of the reasons below}, after which the server closes.
const HELLO := "hello"
## Why a server refuses a player (HELLO): the protocol or the build is another, the
## password is wrong, the server is full, the name is empty.
const WHY_VERSION := "version"
const WHY_PASSWORD := "password"
const WHY_FULL := "full"
const WHY_NAME := "name"

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
## The client's body, hands and screen: [position, feet cell, facing step, hands, active
## hand, brush, moving, swimming, jumped, air jumps, bumped, the way the screen's width
## lies over the ground (Vector2), half its width and height in world units (Vector2),
## on the ground, the work the hands do: its kind, its length in seconds, its count (one
## more at each swing) and the point it is turned to (INF for none)]. Over a socket the
## server runs its own body towards the position told and puts the client where that
## got when the two part (С3.3, decision 153 3А: TELEPORT).
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
## Things lying on the ground changed in a chunk: [key] over the loop (the world is one
## object), [key, list] over a socket (the things as WorldData.drops keeps them).
const DROPS := "drops"
## The body is put at a point (coming back to life, the playtest page): [at].
const TELEPORT := "teleport"
## The body is thrown (a burning campfire): [dir, speed, hop] (Body.knock).
const KNOCK := "knock"
## The animals the player ran into pushed the body, this tick: [by] (world units, Body.nudge).
const PUSH := "push"
## Every thing placed on cells, on joining: [list] (each as Placed.to_list gives it).
const PROPS := "props"
## A thing was placed: [thing] (as Placed.to_list gives it).
const PROP := "prop"
## A thing placed was taken out of the world: [cell].
const PROP_GONE := "prop_gone"
## A campfire was put out or lit: [cell, lit].
const PROP_LIT := "prop_lit"
## What a thing that stores holds changed: [cell, Inventory.to_dict()].
const CHEST := "chest"
## The time, the season and the weather: [Clock.snapshot()], on joining and then a few
## times a second (the client's copy runs the time of day between them).
const CLOCK := "clock"
## An animal came into the world: [id, kind, tint, position].
const ANIMAL := "animal"
## An animal left the world: [id].
const ANIMAL_GONE := "animal_gone"
## Where the animals that moved are, every tick: [[id, position, lift, facing, flying,
## perched, moving, hop, left, near, state], …] (the fields of Wildlife.Animal).
const SNAP := "snap"
## A paw of an animal came down: [id, at, dir, left, size] (Wildlife.stepped).
const STEP := "step"
## The other players in the zone, those that changed since last told (С3.3; 20 a second
## over a socket): [[id, name, position, facing step, hands, active hand, moving,
## swimming, on the ground, work kind, work length, work count, work at], …].
const PEOPLE := "people"
## Another player went out of the zone or the world: [id].
const PERSON_GONE := "person_gone"
## A chunk of the world made, for the client's copy (С3.2; over a socket): [key, size,
## bytes], the record WorldGen.pack gives as var_to_bytes, zstd (`size` its length
## before); sent again when what the chunk shows changed (a bush picked, grass mown).
const CHUNK := "chunk"
## The client may drop a chunk far from its body: [key].
const FORGET := "forget"
## Cells of the world changed (dug, built, cut): [[cell, material], …].
const CELLS := "cells"
## Something was taken from the world by anyone, for the picture of it flying to the
## bag: [id, from] (WorldActions.taken).
const TAKEN := "taken"
## The client leaves on purpose: [] (the server lets the character linger a while less).
const BYE := "bye"
## The server puts the player out: [why] (words for the player); then it closes.
const KICK := "kick"


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


## The version of this build ("0.2.253": the stage and the last PR merged, "0.2.253+pr7"
## a pull request's build, "dev" a run from the editor or a test): a client and a
## server of different builds do not play, since their content may differ (decision
## 153, 5А: the mods are built in).
static func build_version() -> String:
	if not FileAccess.file_exists(BUILD_INFO):
		return "dev"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO))
	if data is Dictionary and data.get("version") is String and data.version != "":
		return data.version
	return "dev"


## The message in `bytes`, or an empty Array when it is not one.
static func decode(bytes: PackedByteArray) -> Array:
	var v: Variant = bytes_to_var(bytes)
	return v if v is Array else []
