extends RefCounted
## Players fighting players (plan/design/territory-pvp.md, «PvP»; decision 15, step Т5):
## a blow of the hand in use, or a shot, at another player takes their health
## (`pvp_damage` for each point of the weapon's power, Rules) and throws them back a
## little. Whether one may hit another (`why_not`): the server's mode (Rules.pvp: "off"
## nowhere, "land" by the owners' rights, "all" everywhere); never one of one's own team;
## not a newcomer under protection (the first `newcomer_minutes` of play, until they hit
## someone, set down a boundary post or give it up themselves); in someone's land only
## when its owner lets the hitter «бить игроков» (Territory.allowed), out of every claim
## always. Both who fought are tagged for `fight_tag` seconds: a tagged player may not
## walk into land where its owner lets nobody else hit (step puts them back), so a fight
## is not run away from into safe land. Players are named by their number (Player.id),
## as Teams and Territory name them. Kept in the world's save (to_dict, from_dict): how
## long each played and who gave the protection up; the tags are not kept.

const WorldData := preload("res://src/shared/world/world_data.gd")
const Territory := preload("res://src/shared/game/territory.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## The server's modes (Rules.pvp).
const MODES := ["off", "land", "all"]
## How far a blow reaches another player (world units, past their body), how near one
## counts as right by the body (hit whichever way one faces), and how wide the way a
## blow is aimed counts, as the cosine of the half angle; like Wildlife's strike.
const STRIKE_REACH := 1.4
const STRIKE_CLOSE := 0.4
const STRIKE_CONE := 0.35
## A player's body: its radius and height (world units), for blows and shots.
const RADIUS := 0.25
const HEIGHT := 1.5
## How a blow throws the one hit: speed and hop, as a burning fire does (Body.knock).
const KNOCK := 3.0
const HOP := 1.5

## A player hit another: `by` hit `to`, taking `damage` health.
signal hit(by, to, damage: float)

## The rules (Rules: pvp, pvp_damage, newcomer_minutes, fight_tag), the teams (Teams) and
## the land (Territory).
var rules
var teams
var territory
## Seconds each player has played in the world (alive).
var played := {}
## The players who gave their protection up (hit someone, or by their own choice).
var brave := {}
## Seconds left of each tagged player's fight.
var tags := {}
## Where each tagged player last stood out of land closed to fights (see step).
var _out := {}


## The server's mode: "off", "land" or "all".
func mode() -> String:
	var m: String = str(rules.pvp) if rules != null else "land"
	return m if m in MODES else "land"


## Seconds of protection player `id` has left: 0 when none (played long enough, gave it
## up, or holds land of their own).
func protection_left(id: int) -> float:
	if rules == null or brave.has(id) or _holds_land(id):
		return 0.0
	return maxf(0.0, float(rules.newcomer_minutes) * 60.0 - float(played.get(id, 0.0)))


## Player `id` gives their protection up (from the team window, or by hitting someone);
## true when they had it.
func give_up(id: int) -> bool:
	var had := protection_left(id) > 0.0
	brave[id] = true
	return had


## Seconds left of player `id`'s fight, 0 when they are not in one.
func tag_left(id: int) -> float:
	return float(tags.get(id, 0.0))


## Why `who` may not hit `other` now ("" when they may); `quiet` when it is not worth a
## word (one of their team: the blow just goes past).
func why_not(who, other) -> Dictionary:
	var a := _id(who)
	var b := _id(other)
	if a == b or other.is_dead():
		return {"why": "", "quiet": true, "no": true}
	if teams != null and teams.together(a, b):
		return {"why": "", "quiet": true, "no": true}
	var m := mode()
	if m == "off":
		return {"why": "На этом сервере PvP выключен", "no": true}
	if protection_left(b) > 0.0:
		return {"why": Lang.line("Игрок под защитой новичка ещё %d мин", [ceili(protection_left(b) / 60.0)]), "no": true}
	if m == "land" and territory != null:
		var claim: Dictionary = territory.claim_at(_cell(other.position))
		if not territory.allowed(claim, a, "hit_players"):
			return {"why": Lang.line("Территория «%s»: здесь нельзя — бить игроков", [territory.title_of(claim)]), "no": true}
	return {}


## The nearest other living player of `players` in front of `who`, within `reach` world
## units of their body along `dir` (within `cone`; any way when right by the body), or
## null.
func in_front(who, players: Array, dir: Vector2, reach := STRIKE_REACH, cone := STRIKE_CONE):
	var at: Vector3 = who.position
	var way := dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	var best = null
	var best_d := INF
	for p in players:
		if p == who or p.is_dead():
			continue
		var pos: Vector3 = p.position
		if pos.y + HEIGHT < at.y - 0.5 or pos.y > at.y + HEIGHT:
			continue
		var off := Vector2(pos.x - at.x, pos.z - at.z)
		var d := maxf(0.0, off.length() - RADIUS)
		if d > reach or d >= best_d:
			continue
		if d > STRIKE_CLOSE and off.normalized().dot(way) < cone:
			continue
		best = p
		best_d = d
	return best


## `who` hits `other` with `power` (the weapon's) from world point `from`: when they may
## (why_not; else a word to `who`), `other` loses `pvp_damage` × power health, is thrown
## back and hears who hit them; both are tagged; `who` loses their protection. Whether
## the blow landed.
func strike(who, other, power: int, from: Vector3) -> bool:
	var no := why_not(who, other)
	if not no.is_empty():
		if not no.get("quiet", false):
			who.nag("pvp", no.why)
		return false
	var a := _id(who)
	var b := _id(other)
	if give_up(a):
		who.nag("pvp_brave", "Вы напали: защита новичка снята")
	var damage := float(maxi(1, power)) * float(rules.pvp_damage if rules != null else 4)
	var name := str(who.get("player_name")) if who.get("player_name") != null else ""
	other.vitals.wound(damage, "player:" + name)
	var away := Vector2(other.position.x - from.x, other.position.z - from.z)
	if away.length() > 0.01:
		other.body.knock(away, KNOCK, HOP)
	other.nag("pvp_hit", Lang.line("Вас ударил игрок %s", [name]) if name != "" else "Вас ударили")
	for id in [a, b]:
		if tag_left(id) <= 0.0:
			var p = who if id == a else other
			p.nag("pvp_tag", Lang.line("Бой: %d с нельзя уйти на землю, где не дерутся", [ceili(_tag_time())]))
		tags[id] = _tag_time()
	hit.emit(who, other, damage)
	return true


## `delta` seconds of play: the living players' time played goes on, the fights' tags
## run out, and a tagged player stepping into land where its owner lets nobody else hit
## is put back where they last stood out of it.
func step(delta: float, players: Array) -> void:
	for p in players:
		var id := _id(p)
		if p.is_dead():
			tags.erase(id)
			continue
		played[id] = float(played.get(id, 0.0)) + delta
		if not tags.has(id):
			_out.erase(id)
			continue
		tags[id] = float(tags[id]) - delta
		if tags[id] <= 0.0:
			tags.erase(id)
			_out.erase(id)
			continue
		if territory == null or mode() != "land":
			continue
		var claim: Dictionary = territory.claim_at(_cell(p.position))
		if not closed(claim):
			_out[id] = p.position
			continue
		var back: Variant = _out.get(id)
		if back != null and not closed(territory.claim_at(_cell(back))):
			p.teleport(back)
			p.nag("pvp_flee", Lang.line("Бой ещё %d с: на землю «%s» сейчас нельзя", [ceili(tags[id]), territory.title_of(claim)]))


## Whether claim `claim` is closed to fights: its owner lets the others not hit players.
func closed(claim: Dictionary) -> bool:
	if claim.is_empty() or territory == null:
		return false
	return int(territory.rights_of(claim.by)[1]) & (1 << Territory.ACTIONS.find("hit_players")) == 0


## What a client is told of fighting: [mode, whole minutes of protection left, whole
## seconds of the fight left] (so it changes once a minute, and once a second in a fight).
func view(id: int) -> Array:
	return [mode(), ceili(protection_left(id) / 60.0), ceili(tag_left(id))]


func to_dict() -> Dictionary:
	var p := {}
	for id: int in played:
		p[str(id)] = snappedf(float(played[id]), 0.1)
	return {"played": p, "brave": brave.keys().map(func(id: int) -> int: return id)}


func from_dict(d: Dictionary) -> void:
	played.clear()
	brave.clear()
	var p: Variant = d.get("played", {})
	if p is Dictionary:
		for k in p:
			played[int(k)] = float(p[k])
	var b: Variant = d.get("brave", [])
	if b is Array:
		for id in b:
			brave[int(id)] = true


func _tag_time() -> float:
	return float(rules.fight_tag) if rules != null else 45.0


func _holds_land(id: int) -> bool:
	if territory == null:
		return false
	for c: Dictionary in territory.claims.values():
		if int(c.by) == id:
			return true
	return false


static func _id(who) -> int:
	var id: Variant = who.get("id")
	return id if id is int else 0


static func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / WorldData.CELL), floori(p.y / WorldData.CELL + 0.01), floori(p.z / WorldData.CELL))
