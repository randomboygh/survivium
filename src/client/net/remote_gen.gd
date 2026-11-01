extends "res://src/shared/world/world_gen.gd"
## The client's copy of the world over a socket (plan/architecture/server.md, decision
## 153, 1А; С3.2): a generator that makes nothing, but lays the land out the same as
## the server's (the seed and settings of the welcome: the biomes, the map, where the
## animals may live) and takes the chunks the server sends ready (Protocol.CHUNK, the
## record WorldGen.pack gives) as the generator takes a saved chunk: `saved` is this,
## and a chunk's job restores the record, so the chunk is SHAPED at once. Nothing is
## generated: a chunk the server has not sent is not there, and the streamer waits for
## it. It stands in for the session where the client orders the world (Main.world_maker:
## make_chunk, make_chunks, forget_far, take_work); the server says what to forget
## (FORGET). A chunk sent again (its looks changed) is restored anew and `changed` tells
## the streamer to build its mesh again.

const Session := preload("res://src/shared/game/session.gd")

## The chunk's cells and records are in again (sent again by the server).
signal changed(key: Vector2i)

## The records of the chunks sent, by key, until restored.
var packs := {}
## Where the player is, in chunks: the chunks nearest it are restored first.
var home := Vector2i.ZERO
## The restore going on (make_chunks).
var _job: Job
## Microseconds spent restoring since the last call of take_work, by kind, and in all,
## as the session counts them.
var work_us := {}
var gen_us := 0


func _init(seed_value: int, sy := 48, options := {}) -> void:
	super(seed_value, sy, options)
	saved = self


# --- What the generator asks of a save (WorldGen.saved) -----------------------------

func has_chunk(key: Vector2i) -> bool:
	return packs.has(key)


func read_chunk(key: Vector2i) -> Dictionary:
	return packs.get(key, {})


# --- The server's chunks ------------------------------------------------------------

## Takes a chunk's record (CHUNK: `size` bytes before zstd); a chunk held already is
## put in again at once.
func take_chunk(key: Vector2i, size: int, bytes: PackedByteArray) -> bool:
	var v: Variant = bytes_to_var(bytes.decompress(size, FileAccess.COMPRESSION_ZSTD))
	if not v is Dictionary or not world.can_unpack(v):
		push_error("chunk %s from the server does not fit this world" % key)
		return false
	packs[key] = v
	if stages.get(key, 0) > 0:
		_drop(key)
		make_chunk(key)
		changed.emit(key)
	return true


## Drops a chunk (FORGET), held or not; nothing the player changed is kept here.
func forget(key: Vector2i) -> bool:
	packs.erase(key)
	_drop(key)
	return true


func _drop(key: Vector2i) -> void:
	if _job != null and _job.key == key:
		_job = null
	world.remove_chunk(key)
	stages.erase(key)
	layouts.erase(key)
	planted.erase(key)


## Only a chunk sent by the server has a job: its restore.
func start(key: Vector2i, stage: int) -> Job:
	if stage != TERRAIN or not packs.has(key):
		return null
	return super(key, stage)


## A chunk can be meshed once it and the chunks around it are in (the mesher reads
## their cells at the edges; the records hold the cells final).
func needed(key: Vector2i) -> Array:
	var m: Variant = missing(key, 1, SHAPED)
	if m != null:
		return [m, SHAPED]
	return []


# --- What the session does over the loop (Main.world_maker) -------------------------

## Restores chunk `key` and those around it that are in, at once (the loading screen).
func make_chunk(key: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := Vector2i(key.x + dx, key.y + dz)
			if packs.has(k) and stages.get(k, 0) == 0:
				_finish(k)
	gen_us += Time.get_ticks_usec() - t0


func _finish(key: Vector2i) -> void:
	var job := start(key, TERRAIN)
	while job != null and not step(job, 1 << 30):
		pass
	packs.erase(key)


## Restores the chunks in, nearest `home` first, a step at a time within `near_us`
## microseconds (`far_us` beyond Session.NEAR); the time spent.
func make_chunks(near_us: int, far_us: int, _reach := 0) -> int:
	var t0 := Time.get_ticks_usec()
	var worked := false
	while true:
		if _job == null:
			var key: Variant = _nearest()
			if key == null:
				break
			_job = start(key, TERRAIN)
			if _job == null:
				packs.erase(key)
				continue
		var budget := near_us if maxi(absi(_job.key.x - home.x), absi(_job.key.y - home.y)) <= Session.NEAR else far_us
		var done := false
		while not done and (Time.get_ticks_usec() - t0 < budget or not worked):
			done = step(_job, 1)
			worked = true
		if done:
			packs.erase(_job.key)
			_job = null
		if Time.get_ticks_usec() - t0 >= budget:
			break
	var spent := Time.get_ticks_usec() - t0
	gen_us += spent
	work_us["restore"] = work_us.get("restore", 0) + spent
	return spent


func _nearest() -> Variant:
	var best: Variant = null
	var best_d := 1 << 30
	for key: Vector2i in packs:
		if stages.get(key, 0) > 0:
			continue
		var d := maxi(absi(key.x - home.x), absi(key.y - home.y))
		if d < best_d:
			best_d = d
			best = key
	return best


## The server forgets for the client.
func forget_far(_n := 0) -> void:
	pass


## Chunks within `reach` of home not in yet (the loading screen's progress).
func stages_left(reach: int) -> int:
	var n := 0
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if stages.get(Vector2i(home.x + dx, home.y + dz), 0) < SHAPED:
				n += 1
	return n


func take_work() -> Dictionary:
	var spent := work_us
	work_us = {}
	return spent
