extends RefCounted
## A world being played (plan/architecture/server.md): the world, the rules of play over
## it and the characters in it, run by a tick. It takes what the rules need (the world,
## its generator, the clock, the rules, the things placed) and makes the rest: what the
## hands do to the world (WorldActions), the wind (Storms) and the animals (Wildlife). A
## tick runs the clock, every character with their workshop, the animals around all
## the players and the wind around each of them in turn. The server will call `tick`
## at 20 Hz; the client calls the steps one by one between its own work (Main._process),
## so the frame's statistics tell them apart. It knows nothing of the network or the
## screen: tests run it alone.

const Clock := preload("res://src/shared/game/clock.gd")
const WorldActions := preload("res://src/shared/game/world_actions.gd")
const Storms := preload("res://src/shared/game/storms.gd")
const Wildlife := preload("res://src/shared/game/wildlife.gd")

## Seconds a step of a character or a workshop covers at most: a long frame does not
## starve or craft for all of it.
const STEP_MAX := 0.05

var world
## The layout of the land (WorldGen), for the biomes; null when any ground will do.
var gen
var clock: Clock
## The rules of play (Rules).
var rules
## The things placed on cells (Placed).
var placed
var actions: WorldActions
var storms: Storms
var wildlife: Wildlife
## The characters playing (Character) and the workshop of each (Workshop), in one
## order; the animals see the characters as people.
var players: Array = []
var workshops: Array = []
var _wild := false


func _init(w, g, c: Clock, r, p) -> void:
	world = w
	gen = g
	clock = c
	rules = r
	placed = p
	clock.world = world
	clock.gen = gen
	placed.world = world
	actions = WorldActions.new(world, clock, rules)
	storms = Storms.new(world, clock, actions)
	wildlife = Wildlife.new()
	wildlife.world = world
	wildlife.gen = gen
	wildlife.clock = clock
	wildlife.people = players


## Brings `who` (Character) into the world with their `workshop` (Workshop).
func add_player(who, workshop) -> void:
	who.world = world
	who.clock = clock
	who.placed = placed
	players.append(who)
	workshops.append(workshop)


func remove_player(who) -> void:
	var i := players.find(who)
	if i >= 0:
		players.remove_at(i)
		workshops.remove_at(i)


## Lets the animals come into the world around the players (Wildlife.start); they step
## from then on.
func start_wildlife(seed_value: int) -> void:
	wildlife.start(seed_value)
	_wild = true


## One tick of the world, `delta` seconds, every step in order.
func tick(delta: float) -> void:
	step_clock(delta)
	step_players(delta)
	step_wildlife(delta)
	step_storms(delta)


## Time and weather; the weather felt (a desert's sand storms) is the first player's,
## until the weather goes by districts of climate.
func step_clock(delta: float) -> void:
	clock.step(delta, players[0].position if not players.is_empty() else Vector3.INF)


## Every character's state and their workshop's queue.
func step_players(delta: float) -> void:
	var d := minf(delta, STEP_MAX)
	for i in players.size():
		players[i].update(d)
		workshops[i].update(d)


## The animals: those near a player move every step, the rest now and then
## (Wildlife.look_from).
func step_wildlife(delta: float) -> void:
	if _wild:
		var around: Array = []
		for who in players:
			around.append(who.position)
		wildlife.look_from(around)
		wildlife.update(delta)


## The wind around the players, one of them a tick (Storms.step_around).
func step_storms(delta: float) -> void:
	var around: Array = []
	for who in players:
		around.append(who.position)
	storms.step_around(delta, around)


## What the animals pushed `who` by since the last call (Wildlife.pushes), in world
## units; nothing for one who is not playing. Taken once: the next call gives nothing
## until the animals step again.
func push_on(who) -> Vector3:
	var i := players.find(who)
	if i < 0 or i >= wildlife.pushes.size():
		return Vector3.ZERO
	var push: Vector3 = wildlife.pushes[i]
	wildlife.pushes[i] = Vector3.ZERO
	return push
