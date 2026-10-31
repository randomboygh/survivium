extends "res://src/shared/game/workshop.gd"
## The client's copy of the player's workshop (plan/architecture/server.md): the queue,
## the pause and the knowledge as the server's events give them (Protocol.SHOP, YOU).
## It learns nothing itself and makes nothing: the server does; the craft tab reads it
## as it read the workshop before (the stations near and what a recipe waits for are
## read off the copies of the bag and the things placed).


func _init(by, things, with_rules) -> void:
	super(by, things, with_rules)


## The bag changed: the tab refreshes; what is learned comes from the server.
func _on_bag_changed() -> void:
	changed.emit()


## Takes the queue and the pause from a SHOP event's `d` (the queue tells `changed`).
func take(d: Dictionary) -> void:
	var p := bool(d.get("paused", false))
	if p != paused:
		paused = p
	if d.get("queue") is Dictionary:
		queue.from_dict(d.queue)


## Takes the knowledge from a KNOWLEDGE event's `d` (what is known, not announced again).
func take_knowledge(d: Dictionary) -> void:
	knowledge.from_dict(d)
	changed.emit()
