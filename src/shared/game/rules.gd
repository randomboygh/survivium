extends RefCounted
## The rules of play the server decides for everyone in the world
## (plan/architecture/server.md): the switches the rules read. In a game on this device
## the «Тестирование» page sets them (Settings.apply); a server will take them from its
## config. The rules read them as they stand, so a change holds at once.

## Building takes nothing from the bag and digging gives nothing (WorldActions).
var free_build := false
## Tools wear with use and crafting (Workshop, decision 105).
var tool_wear := false
## A crafting job takes no time (Workshop).
var instant_craft := false


## Rules set from `d` (the keys of to_dict); what it leaves out keeps its default.
static func of(d: Dictionary):
	var r = new()
	r.from_dict(d)
	return r


func to_dict() -> Dictionary:
	return {"free_build": free_build, "tool_wear": tool_wear, "instant_craft": instant_craft}


func from_dict(d: Dictionary) -> void:
	free_build = bool(d.get("free_build", free_build))
	tool_wear = bool(d.get("tool_wear", tool_wear))
	instant_craft = bool(d.get("instant_craft", instant_craft))
