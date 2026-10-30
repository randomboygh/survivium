extends RefCounted
## What a character is making, in order (plan/design/crafting.md, "Время и износ"):
## each job is a recipe whose materials were taken from the bag when it was queued, so
## a cancel gives them back. Only the first job is worked on, and only while the
## caller says it can be (the station is near). Each job has a serial of its own, which
## decides its by-products (Crafting.outputs), the same on the server. Saved with the
## player.

const Crafting := preload("res://src/shared/content/crafting.gd")

## Jobs can be queued up to this many at a time.
const MAX_JOBS := 20

signal changed

## Each job: {"recipe": id, "left": seconds of work left, "n": its serial}.
var jobs: Array = []
## The serial of the next job queued.
var serial := 0


## Queues recipe `r`, taking its materials from bag `inv`; false when they are missing
## or the queue is full.
func add(r: Dictionary, inv) -> bool:
	if jobs.size() >= MAX_JOBS or not Crafting.take(r, inv):
		return false
	jobs.append({"recipe": r.id, "left": float(r.time), "n": serial})
	serial += 1
	changed.emit()
	return true


## Cancels job `i`; returns its materials ([id, count] stacks) for the caller to put
## back into the bag.
func cancel(i: int) -> Array:
	if i < 0 or i >= jobs.size():
		return []
	var r := Crafting.get_recipe(jobs[i].recipe)
	jobs.remove_at(i)
	changed.emit()
	var out := []
	for id in r.get("needs", {}):
		out.append([id, r.needs[id]])
	return out


## Works `delta` seconds on the first job if `can_work` (a Callable taking the recipe)
## allows; returns the jobs finished, {"recipe": the recipe, "n": the job's serial} each
## (usually none, at most one a call).
func step(delta: float, can_work: Callable) -> Array:
	if jobs.is_empty():
		return []
	var r := Crafting.get_recipe(jobs[0].recipe)
	if r.is_empty():
		jobs.pop_front()
		changed.emit()
		return []
	if not can_work.call(r):
		return []
	jobs[0].left -= delta
	if jobs[0].left > 0.0:
		return []
	var job: Dictionary = jobs.pop_front()
	changed.emit()
	return [{"recipe": r, "n": job.n}]


## How far the first job has come, 0..1.
func progress() -> float:
	if jobs.is_empty():
		return 0.0
	var r := Crafting.get_recipe(jobs[0].recipe)
	var t: float = r.get("time", 0.0)
	return 1.0 if t <= 0.0 else clampf(1.0 - jobs[0].left / t, 0.0, 1.0)


func to_dict() -> Dictionary:
	return {"jobs": jobs.duplicate(true), "serial": serial}


## Fills the queue from to_dict() data; jobs of recipes that are gone are left out, and a
## job saved before jobs had serials gets the next one.
func from_dict(d: Dictionary) -> void:
	jobs = []
	serial = int(d.get("serial", 0))
	for j in d.get("jobs", []):
		if j is Dictionary and j.get("recipe") is String and not Crafting.get_recipe(Crafting.canon(j.recipe)).is_empty():
			var n := int(j.get("n", -1))
			if n < 0:
				n = serial
				serial += 1
			jobs.append({"recipe": Crafting.canon(j.recipe), "left": float(j.get("left", 0.0)), "n": n})
	changed.emit()
