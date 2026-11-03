extends Node
## What the screen does when a skill rises to a new level (decision 164, the user's pick
## 7А with a notice in the corner): the edges of the screen glow gold for a moment
## (BodyFeedback.glow), gold stars rise round the player (Effects.level_sparks), a short
## chime sounds, and a notice with the skill and its level comes into the list of notices
## in the corner (Hud.notice). It listens to the skills of the client's copy of the
## character (SkillSet.leveled, told by the server). `game` is the Main node.

const Skills := preload("res://src/shared/content/skills.gd")

## The gold of the glow and how long it fades, seconds.
const GOLD := Color("#f2c75c")
const GLOW_FADE := 1.4
## Two rises told together (points of a whole thing) glow once and say each.
const AGAIN := 0.5

var game
var _last := -1000.0


func _init(g) -> void:
	game = g


func _ready() -> void:
	game.character.skills.leveled.connect(_on_leveled)


func _on_leveled(id: String, level: int) -> void:
	var s: Dictionary = Skills.BY_ID.get(id, {})
	if s.is_empty():
		return
	var line := "Уровень %d из %d" % [level, s.levels]
	var faster := roundi(s.speed * level * 100.0 / s.levels)
	if faster > 0:
		line += ", %s на %d%%" % ["плывёт быстрее" if s.role == "swim" else "работа быстрее", faster]
	game.hud.notice("%s: новый уровень" % s.title, line)
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last < AGAIN:
		return
	_last = now
	game.hud.feedback.glow(GOLD, GLOW_FADE)
	if game.effects != null and game.player != null:
		game.effects.level_sparks(game.player.position)
	game.sound.play("level_up", Vector3.INF, 0.8, 1.0, "UI")
