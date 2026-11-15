extends Node
## What the body and the world around it do that the phone lets be felt (Vibration, as
## the setting «Вибрация» allows): it watches the character each frame — a fish biting
## on the line (again while it bites), death, the heart while health is low, waking up —
## the season turning and an invitation to a team, and takes the copies' signals of a
## thing made, something picked up near, a fire catching near. The other buzzes are where
## what they answer happens (see Vibration). A child of the HUD; `game` is the Main node.

const Vibration := preload("res://src/client/ui/vibration.gd")
const Placed := preload("res://src/shared/game/placed.gd")

## Seconds between two tap-taps while a fish bites.
const BITE_AGAIN := 1.0
## Below this health the heart beats in the phone, a beat every HEART_EVERY seconds.
const LOW_HEALTH := 20.0
const HEART_EVERY := 1.2
## Something picked up, a fire lit, nearer than these (world units) is felt.
const PICKUP_NEAR := 3.0
const FIRE_NEAR := 4.0
## Seconds between two looks for copies to connect to (a new world makes new ones).
const HOOK_EVERY := 1.0

var game
## What the character was last frame; null before the first look.
var _bite := false
var _dead: Variant = null
var _asleep := false
var _season := -1
var _invites := -1
var _bite_clock := 0.0
var _heart_clock := 0.0
var _hook_clock := 0.0


func _init(g) -> void:
	game = g


func _process(delta: float) -> void:
	var c = game.character
	if c == null or game.settings == null:
		return
	_hook_clock -= delta
	if _hook_clock <= 0.0:
		_hook_clock = HOOK_EVERY
		_hook()
	var dead: bool = c.is_dead()
	if _dead != null and dead and not _dead:
		Vibration.play(game, "death")
	_dead = dead
	# А: the float goes under, and again while the fish holds on.
	var bite: bool = c.bite and not dead
	_bite_clock -= delta
	if bite and (not _bite or _bite_clock <= 0.0):
		_bite_clock = BITE_AGAIN
		Vibration.play(game, "bite")
	_bite = bite
	# З: the heart of a body near death.
	_heart_clock -= delta
	if not dead and c.vitals.health < LOW_HEALTH and _heart_clock <= 0.0:
		_heart_clock = HEART_EVERY
		Vibration.play(game, "heart")
	# Ф: woken.
	var asleep: bool = c.vitals.asleep
	if _asleep and not asleep and not dead:
		Vibration.play(game, "wake")
	_asleep = asleep
	# Х: the season turns.
	if game.clock != null:
		var season: int = game.clock.season
		if _season >= 0 and season != _season:
			Vibration.play(game, "season")
		_season = season
	# У: someone asks one into their team.
	if game.team != null:
		var n: int = game.team.invites.size()
		if _invites >= 0 and n > _invites:
			Vibration.play(game, "call")
		_invites = n


## Connects to the copies' signals, those of a world made since too.
func _hook() -> void:
	if game.workshop != null and not game.workshop.made.is_connected(_on_made):
		game.workshop.made.connect(_on_made)
	if game.actions != null and not game.actions.taken.is_connected(_on_taken):
		game.actions.taken.connect(_on_taken)
	if game.placed != null and not game.placed.lit_changed.is_connected(_on_lit):
		game.placed.lit_changed.connect(_on_lit)


func _near(at: Vector3, reach: float) -> bool:
	return game.player != null and at.is_finite() and at.distance_to(game.player.position) < reach


func _on_made(_recipe: Dictionary) -> void:
	Vibration.play(game, "made")


func _on_taken(_id: String, from: Vector3, _by: Object = null) -> void:
	if _near(from, PICKUP_NEAR):
		Vibration.play(game, "pickup")


func _on_lit(e: Dictionary) -> void:
	if e.lit and _near(Placed.center(e), FIRE_NEAR):
		Vibration.play(game, "fire")
