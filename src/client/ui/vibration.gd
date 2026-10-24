extends RefCounted
## The phone's vibration, when the setting «Вибрация» is on: a buzz the longer the
## bigger a hurt (BodyFeedback), and a short tick when a swing strikes something
## (Controls._did). In the browser it goes through the Vibration API, which Android's
## browsers have and Safari has not (there nothing happens); in an Android build through
## Input.vibrate_handheld. Browsers buzz only after the first tap on the page, which the
## game has by then.

## Milliseconds of a strike's tick, and of a hurt: HURT_MS and HURT_PER_POINT more for
## each point, up to HURT_MOST.
const HIT_MS := 18
const HURT_MS := 40
const HURT_PER_POINT := 8
const HURT_MOST := 220


## True where the device can buzz at all.
static func supported() -> bool:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("typeof navigator.vibrate === 'function'", true) == true
	return OS.has_feature("android")


## Buzzes for `ms` milliseconds after `delay` seconds, if the setting allows it.
static func buzz(game: Node, ms: int, delay := 0.0) -> void:
	if not game.settings.values.vibrate:
		return
	if delay > 0.0:
		game.get_tree().create_timer(delay).timeout.connect(_buzz.bind(ms))
	else:
		_buzz(ms)


static func _buzz(ms: int) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(%d)" % ms, true)
	elif OS.has_feature("android"):
		Input.vibrate_handheld(ms)


## The buzz of a hurt of `points`.
static func hurt(game: Node, points: int) -> void:
	buzz(game, mini(HURT_MS + HURT_PER_POINT * points, HURT_MOST))


## The tick of a swing that strikes, `delay` seconds from now.
static func hit(game: Node, delay: float) -> void:
	buzz(game, HIT_MS, delay)
