extends "res://src/shared/game/placed.gd"
## The client's copy of the things placed on cells (Placed), fed by the server's events
## (Protocol.PROPS, PROP, PROP_GONE, PROP_LIT, PROP_FUEL, CHEST; Mirror): the same records and the
## same signals, so what draws the things (Props), looks for them (Gathering, the
## inventory window, the craft panel, the map) and listens to them (sounds, the freeze
## log) sees no difference. It changes nothing in the world by itself: a thing is
## placed, taken, lit or filled only on the server, and the request goes there
## (Protocol.PROP_PUT…); it only takes the cells of the things it is told of
## (WorldData.blockers), so the body goes round them here as there.


## Takes every thing placed, as the server has them on joining (see to_list): what it
## held is gone first.
func take_all(list: Array) -> void:
	for e in things + lights:
		_forget(e)
	from_list(list)


## A thing was placed (`d` as to_list gives it).
func take_prop(d: Dictionary) -> void:
	from_list([d])


## The thing with its north-west cell at `cell` left the world.
func take_gone(cell: Vector3i) -> void:
	var e := at(cell)
	if not e.is_empty():
		_forget(e)


## The campfire at `cell` was put out or lit (`lit`).
func take_lit(cell: Vector3i, lit: bool) -> void:
	var e := at(cell)
	if not e.is_empty() and e.lit != lit:
		e.lit = lit
		lit_changed.emit(e)


## The campfire at `cell` has `fuel` seconds left to burn. Between the server's word
## the copy does not burn it down itself (it is not stepped): what is shown is at most
## Placed.FUEL_TELL seconds behind.
func take_fuel(cell: Vector3i, fuel: float) -> void:
	var e := at(cell)
	if not e.is_empty() and e.has("fuel"):
		e.fuel = fuel
		fuel_changed.emit(e)


## What the thing at `cell` holds is now `items` (Inventory.to_dict); the window that
## shows it listens to the inventory (Inventory.changed).
func take_chest(cell: Vector3i, items: Dictionary) -> void:
	var e := at(cell)
	if not e.is_empty() and e.items != null:
		e.items.from_dict(items)
