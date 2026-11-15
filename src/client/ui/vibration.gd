extends RefCounted
## The phone's vibration, as the setting «Вибрация» allows: «выкл», «только важное»
## (IMPORTANT: a hurt, death, a bite on the line, a full bag, a tool broken), «обычно»
## (USUAL: what happens now and then and is felt without the sound too) or «всё» (ALL:
## the frequent and the faint as well). Each pattern is a few short pulses with
## pauses between them, and a strength the Android build gives (Input.vibrate_handheld's
## amplitude); in the browser it goes through the Vibration API, which Android's browsers
## have and Safari has not (there nothing happens), with no strength. Browsers buzz only
## after the first tap on the page, which the game has by then. Who buzzes what: Haptics
## (what the body and the world do), BodyFeedback (a hurt), Controls._did (a strike, a tree
## felled, a shot that hits, a fish caught), Props (a thing set down lands), Steps (a
## landing, water), Nature (thunder), LevelUp, Voices (a beast warns), Sound (buttons).

## The setting's steps (`vibration`).
const ThunderShape := preload("res://src/client/audio/thunder_shape.gd")

const OFF := 0
const IMPORTANT := 1
const USUAL := 2
const ALL := 3

## Milliseconds of a strike's tick, and of a hurt: HURT_MS and HURT_PER_POINT more for
## each point, up to HURT_MOST.
const HIT_MS := 18
const HURT_MS := 40
const HURT_PER_POINT := 8
const HURT_MOST := 220

## Each pattern: its pulses and pauses in milliseconds (on, off, on…), the strength of
## each pulse 0..1 (one for all, or one a pulse) and the step of the setting it needs.
const PATTERNS := {
	# А: a fish bites, tap-tap, as the float goes under.
	"bite": [[25, 80, 25], 0.5, IMPORTANT],
	# Б: a felled tree hits the ground.
	"tree": [[110], 0.6, USUAL],
	# В: thunder near, a rumble (its strength scaled by how near); the thunder heard is
	# followed by its own long shape instead (rumble), this when its shape is unknown.
	"thunder": [[60, 40, 90, 60, 40], [0.5, 0.8, 0.4], USUAL],
	# Г: a skill's new level, a trill.
	"level": [[30, 60, 30, 60, 80], [0.5, 0.5, 0.8], USUAL],
	# Д: a thing made at the workshop.
	"made": [[20, 50, 20], 0.4, ALL],
	# Е: a beast near growls, warning one off.
	"warn": [[15, 120, 15, 120, 15], 0.3, ALL],
	# Ж: death, a long blow that fades.
	"death": [[200, 100, 120, 100, 60], [1.0, 0.6, 0.3], IMPORTANT],
	# З: low health, the heart (Haptics beats it).
	"heart": [[30, 120, 20], [0.5, 0.3], ALL],
	# И: a thing set down lands with its thud.
	"thud": [[25], 0.4, USUAL],
	# К: something picked up off the ground.
	"pickup": [[10], 0.3, ALL],
	# Л: the bag is full, «no».
	"full": [[40, 60, 40], 0.6, IMPORTANT],
	# М: a landing that does not hurt (Steps scales it by the fall).
	"land": [[8], 0.12, ALL],
	# Н: a button of the interface.
	"click": [[8], 0.3, ALL],
	# П: a tool broke, a sharp snap.
	"broke": [[50], 0.9, IMPORTANT],
	# Р: a fire caught near, two soft pushes.
	"fire": [[15, 70, 30], 0.4, USUAL],
	# С: into the water.
	"splash": [[40], 0.4, USUAL],
	# Т: a shot hits what it was aimed at.
	"shot": [[15], 0.5, USUAL],
	# У: an invitation to a team, a line in the chat.
	"call": [[20, 100, 20], 0.4, USUAL],
	# Ф: woken from sleep.
	"wake": [[80], 0.3, USUAL],
	# Х: the season turns, a soft wave.
	"season": [[30, 60, 50, 60, 30], [0.2, 0.35, 0.2], ALL],
	# Ц: lightning strikes close.
	"strike": [[150], 1.0, ALL],
	# Ч: a fish pulled out, a crop reaped.
	"catch": [[25, 60, 40], [0.4, 0.6], ALL],
}


## True where the device can buzz at all.
static func supported() -> bool:
	if OS.has_feature("web"):
		# The browser hands a JS boolean back as an int; int == bool is a runtime error.
		return int(JavaScriptBridge.eval("typeof navigator.vibrate === 'function' ? 1 : 0", true)) == 1
	return OS.has_feature("android")


## Whether the setting lets buzzes of `level` through.
static func allows(game, level: int) -> bool:
	# A test's stand-in for Main (a Dictionary) buzzes nothing.
	return game is Node and game.settings != null and int(game.settings.values.vibration) >= level


## Buzzes for `ms` milliseconds after `delay` seconds at `strength` (0..1, -1 the
## device's own), if the setting lets `level` through.
static func buzz(game, ms: int, delay := 0.0, strength := -1.0, level := USUAL) -> void:
	if allows(game, level):
		_later(game, [ms], [strength], delay)


## Plays pattern `id` of PATTERNS after `delay` seconds, its strength times `scale`.
static func play(game, id: String, delay := 0.0, scale := 1.0) -> void:
	var p: Array = PATTERNS[id]
	if not allows(game, p[2]):
		return
	var strengths: Array = p[1] if p[1] is Array else [p[1]]
	if scale != 1.0:
		strengths = strengths.map(func(s: float) -> float: return clampf(s * scale, 0.05, 1.0))
	_later(game, p[0], strengths, delay)


## A thunder's «ту»: each hit's pulse (ms, the first sharp with the crack); its «дууух»
## at most and at least this long, in BOOM_PARTS pulses fading by BOOM_FADE; and no
## thunder is felt sooner than THUNDER_AGAIN seconds after the last one (a storm
## flashes every few seconds).
const HIT_PULSE := 60
const BOOM_MS := Vector2i(400, 1000)
const BOOM_FADE := [1.0, 0.75, 0.5, 0.3]
const THUNDER_AGAIN := 8.0
## The most pulses a browser takes in one pattern (Chrome refuses a longer one).
const WEB_MOST := 99

## When a thunder was last felt (Time ms).
static var _thunder_at := -100000


## The thunder heard (Sound.play_later's `then`: variant `played.variant` at speed
## `played.pitch`) felt as «ту-дууух» (ThunderShape: its hits, then its boom), its
## strength times `scale`. A thunder of a mod with other variants than the made ones
## buzzes the short pattern.
static func rumble(game, played: Dictionary, scale: float) -> void:
	var p: Array = PATTERNS.thunder
	if not allows(game, p[2]):
		return
	var now := Time.get_ticks_msec()
	if now - _thunder_at < THUNDER_AGAIN * 1000.0:
		return
	_thunder_at = now
	var v: int = played.get("variant", -1)
	var count: int = game.sound.streams("thunder").size() if game.get("sound") != null else 0
	if v < 0 or count != ThunderShape.KINDS.size():
		play(game, "thunder", 0.0, scale)
		return
	var steps := rumble_steps(ThunderShape.of(v), float(played.get("pitch", 1.0)), scale)
	_pulses(game, steps[0], steps[1])


## The pulses (on, off… ms) and their strengths of thunder shape `s` played at speed
## `pitch`, as strong as `scale` (see rumble): a pulse a hit, a pause, the boom.
static func rumble_steps(s: Dictionary, pitch: float, scale: float) -> Array:
	var steps := []
	var strengths := []
	var end := 0
	for h: Array in s.hits:
		var at := roundi(float(h[0]) * 1000.0 / pitch)
		if not steps.is_empty():
			steps.append(maxi(at - end, 40))
		steps.append(HIT_PULSE)
		strengths.append(clampf(float(h[1]) * scale, 0.1, 1.0))
		end = maxi(at, end) + HIT_PULSE
	var boom_at := roundi(float(s.hold[0]) * 1000.0 / pitch)
	if not steps.is_empty():
		steps.append(maxi(boom_at - end, 60))
	var boom := clampi(roundi(float(s.hold[1]) * 1000.0 / pitch * 0.6), BOOM_MS.x, BOOM_MS.y)
	for i in BOOM_FADE.size():
		if i > 0:
			steps.append(0)
		steps.append(boom / BOOM_FADE.size())
		strengths.append(clampf(BOOM_FADE[i] * scale, 0.05, 1.0))
	return [steps, strengths]


## The buzz of a hurt of `points`.
static func hurt(game, points: int) -> void:
	buzz(game, mini(HURT_MS + HURT_PER_POINT * points, HURT_MOST), 0.0, -1.0, IMPORTANT)


## The tick of a swing that strikes, `delay` seconds from now.
static func hit(game, delay: float) -> void:
	buzz(game, HIT_MS, delay)


static func _later(game, steps: Array, strengths: Array, delay: float) -> void:
	if delay > 0.0:
		game.get_tree().create_timer(delay).timeout.connect(_pulses.bind(game, steps, strengths))
	else:
		_pulses(game, steps, strengths)


## Pulses `steps` (on, off, on… ms): the browser takes the whole pattern at once; the
## Android build buzzes each pulse in its turn at its strength (the last strength
## for the pulses past the list).
static func _pulses(game, steps: Array, strengths: Array) -> void:
	if OS.has_feature("web"):
		var ms := PackedStringArray()
		for s in steps.slice(0, WEB_MOST):
			ms.append(str(int(s)))
		JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate([%s])" % ",".join(ms), true)
	elif OS.has_feature("android"):
		var at := 0
		for i in range(0, steps.size(), 2):
			var strength: float = strengths[mini(i / 2, strengths.size() - 1)]
			if at == 0:
				Input.vibrate_handheld(int(steps[i]), strength)
			else:
				game.get_tree().create_timer(at / 1000.0).timeout.connect(
					Input.vibrate_handheld.bind(int(steps[i]), strength))
			at += int(steps[i]) + (int(steps[i + 1]) if i + 1 < steps.size() else 0)
