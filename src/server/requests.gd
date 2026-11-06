extends RefCounted
## The requests of one player, done by the rules of the session on the server's side
## (plan/architecture/server.md, Protocol): a request `[kind, seq, args]` is answered
## `[seq, value]` with what the rule returned. A request already answered (its `seq` not
## above the last) is answered as before and not done again: a message sent twice does
## one thing. The args are checked for their types before the rule sees them; a request
## that does not fit is answered null. Chests are named by the cell of the thing that
## holds them (Placed.at); a chest or a placed thing out of the hand's reach
## (WorldActions.within_hand) is as none, so a player moves things only where they
## stand (С6). Each request is done whole before the next of anyone, so a thing taken
## by two players at once goes to one. A line of chat (CHAT) is told on (`chatted`) to
## the server, which hands it to those near, a line to the team (TEAM_CHAT,
## `team_chatted`) to its members; the requests of teams go to the session's Teams;
## lines come no faster than CHAT_LINES in
## CHAT_WINDOW seconds. Over a socket (`paced`) the work of the hands is paced as the
## client paces it: each request of PACED adds the seconds its swing takes, and one that
## comes while more than WORK_AHEAD seconds of them are still owed is refused (what a
## client claims or how fast it sends does not make work go faster). What looks wrong is
## told (`flagged`) for the server's log. The server makes one of these per player as
## they join; in single player LocalHost makes it.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const WorldActions := preload("res://src/shared/game/world_actions.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Plans := preload("res://src/shared/game/plans.gd")

## Letters a line of chat keeps at most; lines in a while at most.
const CHAT_MAX := 160
const CHAT_LINES := 5
const CHAT_WINDOW := 8.0

## How near another player must be to be invited to a team, in world units (as far as
## the chat is heard, Server.CHAT_RANGE).
const TEAM_REACH := 30.0
## How near (world units) to where they fell a dead one asking to come back there must ask.
const REVIVE_NEAR := 1.0
## The requests whose work takes the hands' time (see `paced`), and the seconds of it a
## player may be ahead of the clock (a quick finger along a stroke, a reply late).
const PACED := [Protocol.DIG, Protocol.PLACE, Protocol.FRONT, Protocol.GATHER, Protocol.PLANT,
	Protocol.PLANT_AT, Protocol.PROP_PUT, Protocol.PROP_PUT_AT, Protocol.LIGHT_PUT, Protocol.BUILD]
const WORK_AHEAD := 2.0
## The seconds a paced request that tells no swing costs (one set down, one sown).
const WORK_STEP := 0.25

## The player said `text` in the chat (trimmed and cut; "/…" a command).
signal chatted(text: String)
## The player said `text` to their team.
signal team_chatted(text: String)
## Something the player asked looked wrong (`what`: "pace", "malformed"), for the server's log.
signal flagged(what: String, detail: String)

var session
## The character playing (Character) and their workshop (Workshop).
var who
var workshop
## The last request answered and its reply, for a request sent twice.
var last_seq := -1
var last_reply: Array = []
## When the last lines of chat were said (seconds).
var _chat_times: Array[float] = []
## The bags and chests lying in the player's bag a request opened, by slot (see _bag).
var _opened := {}
## Whether the hands' work is paced (over a socket, see above), the seconds of it owed
## and when they were last counted.
var paced := false
var _owed := 0.0
var _owed_at := -1.0


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


## Does request `kind` with `args` by the rules; what the rule gave back. A bag or chest
## lying in the player's bag that the request opened (see _bag) gets its things back. A
## swing of the hands comes back shorter at the playtest pace of work (Character.haste).
func _do(kind: String, args: Array) -> Variant:
	_opened.clear()
	var timed := paced and kind in PACED
	if timed and _ahead() > WORK_AHEAD:
		flagged.emit("pace", "%s: %.1f с работы вперёд" % [kind, _owed])
		return {} if kind in [Protocol.DIG, Protocol.PLACE, Protocol.FRONT] else false
	var tool_swing: float = who.tool().get("swing", WORK_STEP) if kind == Protocol.GATHER else WORK_STEP
	var out: Variant = _rule(kind, args)
	if out == null:
		flagged.emit("malformed", kind)
	if out is Dictionary and out.has("swing") and who.haste != 1.0:
		out.swing /= who.haste
		if out.has("time"):
			out.time /= who.haste
	if timed:
		if out is Dictionary and out.has("swing"):
			_owed += maxf(0.0, float(out.swing))
		elif out is bool and out:
			_owed += tool_swing / maxf(1.0, who.haste)
	for k: int in _opened:
		who.inventory.close(k, _opened[k])
	_opened.clear()
	return out


## The seconds of the hands' work still owed now (see `paced`).
func _ahead() -> float:
	var now := _now()
	if _owed_at >= 0.0:
		_owed = maxf(0.0, _owed - (now - _owed_at))
	_owed_at = now
	return _owed


## Does request `kind` with `args` by the rules; what the rule gave back.
func _rule(kind: String, args: Array) -> Variant:
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
		Protocol.PROP_PUT_AT:
			if _fit(args, [TYPE_STRING, TYPE_VECTOR3I]):
				return placed.put_at(who, args[0], args[1], session.world.size_y)
		Protocol.LIGHT_PUT:
			if _fit(args, [TYPE_STRING, TYPE_INT]):
				return placed.put_light_from_bag(who, args[0], args[1])
		Protocol.PROP_TAKE:
			if _fit(args, [TYPE_VECTOR3I]):
				var e: Dictionary = _near(args[0])
				return not e.is_empty() and placed.take_up(who, e)
		Protocol.PROP_FIRE:
			if _fit(args, [TYPE_VECTOR3I, TYPE_BOOL]):
				var e: Dictionary = _near(args[0])
				if e.is_empty() or not placed.is_fire(e):
					return false
				if args[1]:
					return placed.feed(who, e)
				# Feeding helps anyone's fire; putting one out in a claim is the builders'.
				if not session.territory.may(who, e.cell, "build"):
					return false
				placed.put_out(e)
				return true
		Protocol.PROP_OPEN:
			if _fit(args, [TYPE_VECTOR3I]):
				var e: Dictionary = _near(args[0])
				return not e.is_empty() and placed.swing(who, e)
		Protocol.PLAN:
			if _fit(args, [TYPE_STRING, TYPE_VECTOR3I, TYPE_VECTOR3I, TYPE_INT, TYPE_INT, TYPE_BOOL]) and args[0] in Plans.KINDS:
				return session.plans.draw(actions, who, args[0], args[1], args[2], args[3], args[4], args[5])
		Protocol.BUILD:
			if _fit(args, []):
				return session.plans.build(actions, who)
		Protocol.PLAN_CLEAR:
			if _fit(args, []):
				return session.plans.clear(actions, who)
		Protocol.PROP_DESTROY:
			if _fit(args, [TYPE_VECTOR3I]):
				var e: Dictionary = _near(args[0])
				return not e.is_empty() and session.territory.may(who, e.cell, "build") and placed.destroy(e)
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
		Protocol.WEAR:
			if _fit(args, [TYPE_INT]) and _slot(who.inventory, args[0]):
				return who.wear(args[0])
		Protocol.TAKE_OFF:
			if _fit(args, [TYPE_STRING]):
				return who.take_off(args[0])
		Protocol.SLEEP:
			if _fit(args, [TYPE_BOOL]):
				return who.sleep(args[0])
		Protocol.LIE_IN:
			if _fit(args, [TYPE_VECTOR3I]):
				var e: Dictionary = _near(args[0])
				return not e.is_empty() and Placed.is_bed(e) and who.lie_in(e)
		Protocol.REPAIR:
			if _fit(args, [TYPE_INT]) and _slot(who.inventory, args[0]):
				return workshop.repair(args[0])
		Protocol.BAG_PUT:
			if args.size() == 4 and args[1] is int and args[3] is int:
				var from = _bag(args[0])
				var to = _bag(args[2])
				if from != null and to != null and _slot(from, args[1]) and _slot(to, args[3]):
					# A bag opened from the player's bag does not itself move.
					if from == who.inventory and _opened.has(args[1]) or to == who.inventory and _opened.has(args[3]):
						return false
					return from.put_into(args[1], to, args[3])
		Protocol.BAG_MOVE:
			if args.size() == 3 and args[1] is int:
				var from = _bag(args[0])
				var to = _bag(args[2])
				if from != null and to != null and _slot(from, args[1]):
					if from == who.inventory and _opened.has(args[1]):
						return 0
					return from.move_slot(args[1], to)
		Protocol.BAG_ALL:
			if args.size() == 3 and args[2] is int:
				var from = _bag(args[0])
				var to = _bag(args[1])
				if from != null and to != null and from != to:
					return from.move_all(to, args[2], args[1] if from == who.inventory and args[1] is int else -1)
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
		Protocol.CHAT:
			if _fit(args, [TYPE_STRING]):
				return _chat(args[0])
		Protocol.TEAM_INVITE:
			if _fit(args, [TYPE_INT]):
				var other = _player(args[0])
				if other == null or other.position.distance_to(who.position) > TEAM_REACH:
					return false
				if session.teams.team_of(other.id) != 0:
					who.nag("team", "%s уже в команде" % other.player_name)
					return false
				return session.teams.invite(who.id, who.player_name, other.id, _now())
		Protocol.TEAM_ACCEPT:
			if _fit(args, [TYPE_INT]):
				return session.teams.accept(who.id, who.player_name, args[0], _now())
		Protocol.TEAM_DECLINE:
			if _fit(args, [TYPE_INT]):
				return session.teams.decline(who.id, args[0])
		Protocol.TEAM_LEAVE:
			return session.teams.leave(who.id)
		Protocol.TEAM_KICK:
			if _fit(args, [TYPE_INT]):
				return session.teams.kick(who.id, args[0])
		Protocol.TEAM_NAME:
			if _fit(args, [TYPE_STRING]):
				return session.teams.rename(who.id, Protocol.clean_text(args[0], 24))
		Protocol.TEAM_CHAT:
			if _fit(args, [TYPE_STRING]) and session.teams.team_of(who.id) != 0:
				return _chat(args[0], true)
		Protocol.LAND_PAINT:
			if _fit(args, [TYPE_VECTOR2I, TYPE_BOOL]):
				return session.territory.paint(who, args[0], args[1])
		Protocol.LAND_RIGHTS:
			if _fit(args, [TYPE_INT, TYPE_INT]):
				return session.territory.set_rights(who.id, args[0], args[1])
		Protocol.LAND_COLOR:
			if _fit(args, [TYPE_INT]):
				return session.territory.set_color(who.id, args[0])
		Protocol.FIGHT_BRAVE:
			if _fit(args, []):
				return session.fights.give_up(who.id)
		Protocol.REVIVE:
			# Only the dead come back, at one of their places (the nearest to the one
			# asked for: the fires are looked at anew), or where they fell when the
			# test page lets them.
			if _fit(args, [TYPE_VECTOR3]) and who.is_dead():
				who.revive(_revive_at(args[0]))
				return true
	return null


## Where the dead `who` comes back when asking for `at`: the respawn point nearest to it,
## or `at` itself when it is where they fell (the test page's «и где упали»).
func _revive_at(at: Vector3) -> Vector3:
	who.find_respawns(session.placed, session.teams)
	var fell: Array = who.death.get("at", [])
	if fell.size() == 3 and at.distance_to(Vector3(fell[0], fell[1], fell[2])) < REVIVE_NEAR:
		return at
	var best: Vector3 = who.home
	for p: Array in who.respawn_points():
		if at.distance_to(p[1]) < at.distance_to(best):
			best = p[1]
	return best


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


## The player numbered `id` in the world, alive, other than this one; null for none.
func _player(id: int):
	for p in session.players:
		if p != who and p.get("id") == id and not p.is_dead():
			return p
	return null


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## The bag `where` names: the player's for null, a chest's for the cell of the thing
## that holds it, a bag or chest lying in the player's bag for its slot (opened, see
## Inventory.open; its things go back after the request); null for a cell with no such
## thing within reach, or a slot without one.
func _bag(where: Variant):
	if where == null:
		return who.inventory
	if where is int:
		if not _opened.has(where):
			var bag = who.inventory.open(where)
			if bag == null:
				return null
			_opened[where] = bag
		return _opened[where]
	if where is Vector3i:
		var e: Dictionary = _near(where)
		if e.is_empty() or not session.territory.may(who, e.cell, "chests"):
			return null
		return e.get("items")
	return null


## The thing placed at `cell` when it is within the hand's reach, else {}.
func _near(cell: Vector3i) -> Dictionary:
	var e: Dictionary = session.placed.at(cell)
	if e.is_empty() or not WorldActions.within_hand(who, session.placed.center(e)):
		return {}
	return e


## A line of chat: made safe and cut to CHAT_MAX (Protocol.clean_text), told to the server (to the team's
## members with `team`); false for an empty one or one too soon after CHAT_LINES others.
func _chat(text: String, team := false) -> bool:
	var line := Protocol.clean_text(text, CHAT_MAX)
	if line == "":
		return false
	var now := Time.get_ticks_msec() / 1000.0
	while not _chat_times.is_empty() and now - _chat_times[0] > CHAT_WINDOW:
		_chat_times.pop_front()
	if _chat_times.size() >= CHAT_LINES:
		who.nag("chat", "Не так часто: подождите немного")
		return false
	_chat_times.append(now)
	if team:
		team_chatted.emit(line)
	else:
		chatted.emit(line)
	return true
