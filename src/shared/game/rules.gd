extends RefCounted
## The rules of play the server decides for everyone in the world
## (plan/architecture/server.md): the switches the rules read. In a game on this device
## the «Тестирование» page sets them (Settings.apply); a server will take them from its
## config. The rules read them as they stand, so a change holds at once.

## Building takes nothing from the bag (WorldActions, Plans); digging, mowing and reaping
## still give what they give, as without it.
var free_build := false
## Tools wear with use and crafting (Workshop, decision 105; on by default since the balance
## pass of 2026-11-07, docs/balance/GAME_BALANCE_DESIGN.md: a stone axe lasts about 30 trees).
var tool_wear := true
## A crafting job takes no time (Workshop).
var instant_craft := false
## Any recipe's thing is given for nothing (Workshop.give_free): the craft tab shows
## every recipe with a «получить» button (playtest switch «Бесплатные предметы»).
var free_items := false
## Territory (decision 15, 39): the squares a player may hold at first and more for each
## game day lived, how far from its centre a claim reaches (squares), and on how many
## levels above and below the centre it holds.
var territory_start := 64
var territory_per_level := 8
var territory_radius := 24
var territory_levels := 8
## Players fighting players (decision 15, Fights): where it is allowed ("off" nowhere,
## "land" by the owners' rights, "all" everywhere), the health a blow takes for each
## point of the weapon's power, how long a newcomer is protected (minutes played), and
## how long a fight holds one out of land closed to fights (seconds).
var pvp := "land"
var pvp_damage := 4
var newcomer_minutes := 120
var fight_tag := 45.0
## Abandoned land (plan/design/territory-pvp.md): hours of the world's running time with
## nobody of the owner's team in a claim before it starts to decay, hours for each stage
## more, and how it decays: "rights" (others may do more), "radius" (it shrinks) or "both".
var territory_abandon_hours := 72.0
var territory_decay_hours := 24.0
var territory_decay := "both"
## The animals that bite (a kind's `bite`) go for the people: keep their ground, fight
## back, hunt them when hungry in a strong flock (Wildlife._fights).
var animal_attacks := true


## Rules set from `d` (the keys of to_dict); what it leaves out keeps its default.
static func of(d: Dictionary):
	var r = new()
	r.from_dict(d)
	return r


func to_dict() -> Dictionary:
	return {"free_build": free_build, "tool_wear": tool_wear, "instant_craft": instant_craft,
		"free_items": free_items,
		"territory_start": territory_start, "territory_per_level": territory_per_level,
		"territory_radius": territory_radius, "territory_levels": territory_levels,
		"pvp": pvp, "pvp_damage": pvp_damage, "newcomer_minutes": newcomer_minutes, "fight_tag": fight_tag,
		"territory_abandon_hours": territory_abandon_hours, "territory_decay_hours": territory_decay_hours,
		"territory_decay": territory_decay, "animal_attacks": animal_attacks}


func from_dict(d: Dictionary) -> void:
	free_build = bool(d.get("free_build", free_build))
	tool_wear = bool(d.get("tool_wear", tool_wear))
	instant_craft = bool(d.get("instant_craft", instant_craft))
	free_items = bool(d.get("free_items", free_items))
	animal_attacks = bool(d.get("animal_attacks", animal_attacks))
	territory_start = int(d.get("territory_start", territory_start))
	territory_per_level = int(d.get("territory_per_level", territory_per_level))
	territory_radius = int(d.get("territory_radius", territory_radius))
	territory_levels = int(d.get("territory_levels", territory_levels))
	pvp = str(d.get("pvp", pvp))
	pvp_damage = int(d.get("pvp_damage", pvp_damage))
	newcomer_minutes = int(d.get("newcomer_minutes", newcomer_minutes))
	fight_tag = float(d.get("fight_tag", fight_tag))
	territory_abandon_hours = float(d.get("territory_abandon_hours", territory_abandon_hours))
	territory_decay_hours = float(d.get("territory_decay_hours", territory_decay_hours))
	var how := str(d.get("territory_decay", territory_decay))
	territory_decay = how if how in ["rights", "radius", "both"] else territory_decay
