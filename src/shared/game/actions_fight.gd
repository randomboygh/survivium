extends "res://src/shared/game/actions_gather.gd"
## The rules of the hands, part three (world_actions.gd): a swing at the air, a blow at
## a player or an animal in front, and a shot of the weapon in hand.

const AiRules := preload("res://src/shared/content/ai_rules.gd")
## The wait after the action button found nothing to do, in seconds.
const IDLE_SWING := 0.3
## The animals (Wildlife) blows land on; null where there are none (a client's copy of
## the rules), and then no blow lands.
var wildlife
## Players fighting players (Fights) and the players in the world (Session.players), for
## blows and shots at them; none in a copy.
var fights
var people: Array = []


## Nothing to work: the hand in use swings at the air (toward `at`, if finite), without
## a word and for less stamina.
func swing_air(who, at: Vector3) -> Dictionary:
	var blow := strike(who)
	if not blow.is_empty():
		return blow
	if who.act("swing"):
		return _work(who.tool().swing, "", at)
	return {"swing": IDLE_SWING}


## A blow of the hand in use, a weapon or the bare hand, at another player in front of
## `who` whom they may hit (Fights), else at the animal in front (Wildlife.in_front; only one right by the body
## unless `far`), with the hand's power: the player is wounded (Fights.strike); the animal
## flees, or dies and leaves its carcass (its species' `carcass`) on the ground where it
## fell. {} with no one there.
func strike(who, far := true) -> Dictionary:
	var s: Vector2i = who.facing_step()
	var at: Vector3 = who.position
	# Only a weapon or a fist hits a player: one working with a tool beside another does not.
	var weapon := Tools.weapon(who.held())
	var fist: bool = weapon.is_empty() and who.tool().tool == "hand"
	var other = _foe(who, Vector2(s), fights.STRIKE_REACH if far else STRIKE_CLOSE, fights.STRIKE_CONE) \
		if fights != null and (fist or not weapon.is_empty()) else null
	if other != null:
		if not who.act("swing"):
			return {}
		var tool: Dictionary = weapon if not weapon.is_empty() else who.tool()
		var landed: bool = fights.strike(who, other, tool.power, at)
		if tool.tool != "hand":
			who.use_tool()
		var blow := _work(tool.swing, "", other.position + Vector3(0.0, 0.6, 0.0))
		blow.hit = landed
		return blow
	if wildlife == null:
		return {}
	var a = wildlife.in_front(at, Vector2(s), wildlife.STRIKE_REACH if far else wildlife.STRIKE_CLOSE)
	if a == null or not who.act("swing", "hunt"):
		return {}
	var arm := Tools.weapon(who.held())
	var t: Dictionary = arm if not arm.is_empty() else who.tool()
	var where: Vector3 = a.pos
	# The weapon decides the blow; the skill of hunting adds its `might` to it (SkillSet.blow),
	# paces the swing and spares the stamina. A blow at a player (strike above) is the
	# weapon's alone: Fights.strike.
	_wound(who, a, _blow(who, "hunt", t.power))
	if t.tool != "hand":
		who.use_tool()
	var done := _work(skilled(who, "hunt", t.swing), "", where + Vector3(0.0, 0.3, 0.0))
	done.hit = true
	return done


## Animal `a` takes a blow of `power` from `who`; if it dies, its carcass (its species'
## `carcass`) is left on the ground where it fell.
func _wound(who, a, power: int) -> void:
	var where: Vector3 = a.pos
	if not _may(who, _cell_at(where), "hit_animals"):
		return
	if a.owner >= 0 and a.owner != (int(who.get("id")) if "id" in who else 0):
		# Another's tame animal (ActionsTame).
		return
	var spec: Dictionary = AiRules.SPECIES[a.kind]
	if wildlife.hurt(a, power, who.position, who) and spec.carcass != "" and Items.has(spec.carcass):
		var cell := _cell_at(where)
		world.heap_drop(spec.carcass, floor_under(cell), 1, randf() * TAU, _got(who, "hunt"))
		drops_changed.emit(WorldData.chunk_key(cell.x, cell.z))
		who.note("hunted")
		_learn_each(who, "hunt")


## How near another player counts as right by the body for a blow of a hand that does not
## hunt (world units past their body).
const STRIKE_CLOSE := 0.5


## The other player in front of `who` (Fights.in_front along `dir`) whom `who` may hit; a
## word to `who` (Fights.why_not) when the one there may not be hit; null for none.
func _foe(who, dir: Vector2, reach: float, cone: float):
	if fights == null or people.size() < 2:
		return null
	var other = fights.in_front(who, people, dir, reach, cone)
	if other == null:
		return null
	var no: Dictionary = fights.why_not(who, other)
	if no.is_empty():
		return other
	if not no.get("quiet", false):
		who.nag("pvp", no.why)
	return null


static func _cell_at(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.y / CELL + 0.01), floori(p.z / CELL))


## How fast a shot flies, in world units a second (for the flight drawn: the shot itself
## lands at once), and how wide the way it is aimed counts, as the cosine of the half angle.
const SHOT_SPEED := 14.0
const AIM_CONE := 0.9


## A shot of the weapon in hand (a spear thrown, a stone from a sling, an arrow from a
## bow) toward `aim` (world units; the way `who` faces when not finite), as far as the
## weapon's `range`: it hits the first animal along that way (Wildlife.in_front within
## AIM_CONE) unless a solid cell stops it first, and what was shot lies where it ended up,
## to be picked up again. Nothing to shoot (no `ammo` in the bag): a word and an idle swing.
func shoot(who, aim := Vector3.INF) -> Dictionary:
	var item := Tools.weapon(who.held())
	if not Tools.shoots(item):
		return {}
	var ammo: String = item.ammo if item.ammo != "" else item.id
	if who.inventory.count(ammo) == 0:
		who.nag("ammo", "Нечем стрелять: нужно «%s»" % Items.title(ammo))
		return {"swing": IDLE_SWING}
	if not who.act("swing", "hunt"):
		return {}
	var at: Vector3 = who.position
	var from := at + Vector3(0.0, 0.6, 0.0)
	var s: Vector2i = who.facing_step()
	var dir := Vector2(s).normalized()
	if aim.is_finite() and Vector2(aim.x - at.x, aim.z - at.z).length() > 0.05:
		dir = Vector2(aim.x - at.x, aim.z - at.z).normalized()
	var reach: float = item.range * CELL
	var a = wildlife.in_front(at, dir, reach, AIM_CONE) if wildlife != null else null
	# Another player whom one may hit, nearer than the animal, takes the shot.
	var foe = _foe(who, dir, reach, AIM_CONE)
	if foe != null and a != null and Vector2(a.pos.x - at.x, a.pos.z - at.z).length() < Vector2(foe.position.x - at.x, foe.position.z - at.z).length():
		foe = null
	if foe != null:
		a = null
	var to: Vector3 = a.pos + Vector3(0.0, 0.3, 0.0) if a != null else from + Vector3(dir.x, 0.0, dir.y) * reach
	if foe != null:
		to = foe.position + Vector3(0.0, 0.6, 0.0)
	# Along the way, the first solid cell stops it.
	var steps := maxi(1, ceili(from.distance_to(to) / (CELL * 0.5)))
	var end := to
	for i in range(1, steps + 1):
		var c := _cell_at(from.lerp(to, float(i) / steps))
		if world.is_solid(c.x, c.y, c.z):
			end = from.lerp(to, float(i - 1) / steps)
			a = null
			foe = null
			break
	# One out of the bag: a thrown weapon keeps its wear.
	var data: Variant = 1
	if ammo == item.id:
		for i in who.inventory.slots.size():
			var slot = who.inventory.slots[i]
			if slot != null and slot[0] == ammo:
				var taken = who.inventory.take_slot(i, 1)
				data = Inventory.drop_data(taken)
				break
	else:
		who.inventory.remove(ammo, 1)
		who.use_tool()
	if a != null:
		_wound(who, a, _blow(who, "hunt", item.power))
	var struck: bool = foe != null and fights.strike(who, foe, item.power, at)
	var land := floor_under(_cell_at(end))
	world.add_drop(ammo, land, randf() * TAU, data)
	drops_changed.emit(WorldData.chunk_key(floori(land.x / CELL), floori(land.z / CELL)))
	var done := _work(item.swing, "", end)
	done.hit = a != null or struck
	done.shot = [ammo, from, land, from.distance_to(land) / SHOT_SPEED]
	return done


# --- Drinking --------------------------------------------------------------------------
