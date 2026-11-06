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
## The host blocked the player, or lets in only the names on the server's list.
const WHY_BANNED := "banned"
const WHY_LIST := "list"
## Another player in the world goes by that name, or it is one only the server goes by.
const WHY_TAKEN := "taken"
## Too many tries in a short while (a wrong password, new players): come back later.
const WHY_WAIT := "wait"

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
## Sets a light (a torch, a candle) down from the bag in front, below the cut: [id, top]
## (Placed.put_light_from_bag).
const LIGHT_PUT := "light_put"
## Takes a thing placed, or a light set down, back into the bag: [cell] (Placed.take_up).
const PROP_TAKE := "prop_take"
## The build mode sets a thing from the bag down at the cell tapped: [item id, cell]
## (Placed.put_at; a door or a window cuts its opening into a wall).
const PROP_PUT_AT := "prop_put_at"
## Puts out a campfire, or lights it again or feeds it one piece of fuel: [cell, on]
## (Placed.put_out, Placed.feed).
const PROP_FIRE := "prop_fire"
## Opens a door or shuts it: [cell] (Placed.swing).
const PROP_OPEN := "prop_open"
## Draws a shape of the blueprint with the block held, or takes the ghost off the box
## round it: [kind, from, to, height, thickness, erase] (Plans.draw).
const PLAN := "plan"
## Takes the blueprint's ghost off every cell near the player: [] (Plans.clear).
const PLAN_CLEAR := "plan_clear"
## The build mode's action button: builds one ghost cell of the blueprint near the player,
## whatever the hand holds: [] (Plans.build).
const BUILD := "build"
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
## a bag or chest is null for the player's bag, the cell of the chest, or (an int) the slot of
## the player's bag a bag or chest with things lies in (Inventory.open); so for the requests below.
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
## Puts on what lies in a slot of the bag: [slot] (Character.wear); true when it went on.
const WEAR := "wear"
## Takes off what is worn in a slot of the body: [slot name] (Character.take_off).
const TAKE_OFF := "take_off"
## Lies down to sleep or wakes: [on] (Character.sleep); true when done.
const SLEEP := "sleep"
## Lies down in a bed set down (a mat, a bedroll) to sleep in it: [cell] (Character.lie_in);
## true when asleep there.
const LIE_IN := "lie_in"
## Comes back to life at a point: [at] (Character.revive).
const REVIVE := "revive"
## Says a line in the chat: [text]; true when it was said (the server hands it to the
## players within the chat's reach, HEARD; a line that begins with "/" is a command,
## done for the server's hosts only, its answer coming back as HEARD from the server).
const CHAT := "chat"
## Teams (Teams, decision 50): invites the player numbered [id] (one in the world near
## enough to hear the chat); accepts the invitation of [id]; turns down that of [id] (0:
## all); leaves the team []; the lead puts out member [id]; the lead names the team
## [name]; says a line to the team wherever its members are [text]. Each true when done.
const TEAM_INVITE := "team_invite"
const TEAM_ACCEPT := "team_accept"
const TEAM_DECLINE := "team_decline"
const TEAM_LEAVE := "team_leave"
const TEAM_KICK := "team_kick"
const TEAM_NAME := "team_name"
const TEAM_CHAT := "team_chat"
## Territory (Territory, decision 15): paints a square of land for a claim of the
## player's or their team's [square (Vector2i), on] or clears it (on false); true when done.
const LAND_PAINT := "land_paint"
## What others may do in the player's land [team mask, others mask] (Territory.ACTIONS
## bits); true when it changed.
const LAND_RIGHTS := "land_rights"
## The colour the player picks for their land [number, 0..Territory.COLORS - 1]; true
## when it changed.
const LAND_COLOR := "land_color"
## The player gives up their protection as a newcomer (Fights.give_up) []; true when
## they had it.
const FIGHT_BRAVE := "fight_brave"

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
## How many fields an INPUT has (above); the server leaves out one of another size.
const INPUT_SIZE := 18
## The player's own state changed: {"inventory", "vitals", "state", "home",
## "held_back"} (each as to_dict gives it; vitals as VITALS).
const YOU := "you"
## What the player knows how to make changed: [Knowledge.to_dict()].
const KNOWLEDGE := "knowledge"
## The points of the player's skills changed: [SkillSet.to_dict()] (at most every
## PlayerLink.SKILLS_EVERY seconds, at once when a level rose).
const SKILLS := "skills"
## The body's state, every tick it changes: [health, satiety, stamina, hunger, hurt_by, warmth,
## wet, water, energy, asleep].
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
## The player's fishing line, when it changed: [where its float lies (INF: none in the
## water), a fish bites at it] (Character.line, bite; Fishing).
const LINE := "line"
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
## A door was opened or shut: [cell, open] (Placed.opened).
const PROP_OPENED := "prop_opened"
## What a campfire has left to burn: [cell, seconds] (Placed.fuel_changed).
const PROP_FUEL := "prop_fuel"
## Every ghost cell of the blueprint, on joining: [list] (as Plans.to_list gives it).
const PLANS := "plans"
## Ghost cells of the blueprint came with a block, or went: [cells, item] ("" gone).
const PLAN_CELLS := "plan_cells"
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
## swimming, on the ground, work kind, work length, work count, work at, what is worn
## (Inventory.gear), in the player's team, where the float of their fishing line lies (INF
## none)], …].
const PEOPLE := "people"
## Another player went out of the zone or the world: [id].
const PERSON_GONE := "person_gone"
## A line of chat heard: [id of who said it (0 the server), their name, the text, said
## to the team].
const HEARD := "heard"
## The player's team (Teams.view): [{"id", "name", "lead", "members": [[id, name]…]}],
## {} for none; on joining and when it changes.
const TEAM := "team"
## The invitations to a team waiting for the player: [[[id, name]…]]; when they change.
const INVITES := "invites"
## The claims of land (Territory.claims_view): [[[id, centre cell, by, name, the owner's
## rights [team mask, others mask], the owner's colour]…]], all of them, on joining and
## when one is made or gone, a team changes or an owner sets their rights or colour.
const CLAIMS := "claims"
## Squares of land changed: [[[square, claim (0 none)]…], all] (all: these are every
## square there is, on joining).
const SQUARES := "squares"
## The squares the player and their team hold and may hold: [used, budget]; when changed.
const LAND := "land"
## Fighting (Fights.view): [the server's mode "off" | "land" | "all", whole minutes of the
## player's protection as a newcomer left, whole seconds of their fight left]; when changed.
const FIGHT := "fight"
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


## Text a player typed (a name, a line of chat, a team's name), made safe to show and to
## log: control characters (a new line too) become spaces, the marks that turn text
## around or hide it go, runs of spaces are one, the ends trimmed, at most `most` letters.
static func clean_text(text: String, most: int) -> String:
	var src := text.left(most * 4)
	var out := ""
	var space := false
	for i in src.length():
		var c := src.unicode_at(i)
		if c < 32 or c == 127 or c == 0x2028 or c == 0x2029 or (c >= 0x80 and c < 0xA0) or c == 0x3000:
			c = 32
		elif c == 0xAD or c == 0x180E or (c >= 0x200B and c <= 0x200F) or (c >= 0x202A and c <= 0x202E) \
				or (c >= 0x2060 and c <= 0x206F) or c == 0xFEFF or (c >= 0xFFF9 and c <= 0xFFFB):
			continue
		if c == 32:
			space = true
			continue
		if space and out != "":
			out += " "
		space = false
		out += char(c)
	return out.left(most)


## A message as bytes for the wire.
static func encode(msg: Array) -> PackedByteArray:
	return var_to_bytes(msg)


## The version of this build ("0.2.253": the stage and the last PR merged, "0.2.253+pr7"
## a pull request's build, "dev" a run from the editor or a test): a client and a
## server of different builds do not play, since their content may differ (decision
## 153, 5А: the mods are built in).
static func build_version() -> String:
	var data := build_info()
	if data.get("version") is String and data.version != "":
		return data.version
	return "dev"


## BUILD_INFO as written by CI ({} without one), read once: the file does not change
## while the game runs. Callers must not change it.
static func build_info() -> Dictionary:
	if _build_info == null:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO)) \
			if FileAccess.file_exists(BUILD_INFO) else null
		_build_info = data if data is Dictionary else {}
	return _build_info


static var _build_info: Variant = null


## The message in `bytes`, or an empty Array when it is not one.
static func decode(bytes: PackedByteArray) -> Array:
	var v: Variant = bytes_to_var(bytes)
	return v if v is Array else []
