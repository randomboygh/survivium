extends RefCounted
## The eras of progress, read from `content/*/data/eras.yaml` (see Content): the steps from
## bare hands on (docs/specifications/BUNDLE_SYSTEM.md, section 9), each with its `order`
## and the `depth` of making its things are expected to keep within. An era locks nothing in
## play: an item that opens one names it (`era`), the content graph derives the era of the
## rest (ContentGraph.era) and checks them, the reports show them. Shared, so the server can
## tell the same.

const Content := preload("res://src/shared/content/content.gd")

## The eras loaded, by `order` (then id), and the place of each in it by id.
static var ERAS: Array = []
static var RANK := {}


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	ERAS = Content.records("eras").duplicate()
	ERAS.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.order < b.order or (a.order == b.order and a.id < b.id))
	RANK = {}
	for i in ERAS.size():
		RANK[ERAS[i].id] = i


## The place of era `id` in ERAS, from 0; 0 for "" or an era not loaded (the first).
static func rank(id: String) -> int:
	return RANK.get(id, 0)


## "1. Примитивные инструменты" for the era of rank `n`, "—" when there is none.
static func title(n: int) -> String:
	if n < 0 or n >= ERAS.size():
		return "—"
	return "%d. %s" % [ERAS[n].order, ERAS[n].title]


## What is wrong with the loaded eras for the engine: two of the same order.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	for i in range(1, ERAS.size()):
		if ERAS[i].order == ERAS[i - 1].order:
			out.append("eras: `%s` and `%s` have the same order %d" % [ERAS[i - 1].id, ERAS[i].id, ERAS[i].order])
	return out
