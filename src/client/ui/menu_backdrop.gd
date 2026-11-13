extends Control
## The first part of the main menu (main_menu.gd): the painted landscape behind it,
## its sky coloured for the hour of the device's clock (the sun or the moon, the stars at
## night, a flock passing), and the sparrow on the menu's name that hops about, flies off,
## and after enough taps bursts into feathers that drift down.
##
## The menu is one script split by topic (decision 168, as decision 145): menu_backdrop.gd
## <- menu_loading.gd <- menu_pages.gd <- main_menu.gd; each part extends the one before and
## calls only what it or an earlier part defines, and callers know only main_menu.gd.

const Vibration := preload("res://src/client/ui/vibration.gd")
const Creatures := preload("res://src/client/game/creatures.gd")
const Content := preload("res://src/shared/content/content.gd")

## The two-line «Продолжить» of «Одиночная игра», as tall as a row of «Загрузить мир».
const PLAY_H := 42
const MARGIN := 24
const TITLE_SIZE := 32
## The painted sky over the day, by the hour of the device's clock: [hour, the bands
## from the top down to the horizon, the far and the near range of hills, how much the
## stars show, how much the birds fly]. Between two hours the colours blend.
const NIGHT := [["#0b1322", "#0e1829", "#121e31", "#16253a", "#1b2c42", "#22344a", "#2a3c51"],
	["#1a2822", "#101a15"], 1.0, 0.0]
const SKIES := [
	[0.0, NIGHT],
	[4.5, NIGHT],
	[6.0, [["#27355a", "#3d4466", "#5d506e", "#875c72", "#b06c72", "#d48a78", "#e9ad86"],
		["#3e4a48", "#2a3433"], 0.3, 0.5]],
	[8.5, [["#4f86b0", "#5a90b7", "#679abd", "#78a6c2", "#8cb2c6", "#a2bec7", "#bccbc4"],
		["#4c7148", "#365535"], 0.0, 1.0]],
	[12.0, [["#467fb1", "#5089b8", "#5c94be", "#6c9fc4", "#80abc8", "#97b8ca", "#b0c6ca"],
		["#4f7a47", "#385b35"], 0.0, 1.0]],
	[16.5, [["#4a78a3", "#5a82a6", "#6d8ca8", "#8496a6", "#9ea0a0", "#b9a996", "#cfb08c"],
		["#4d6842", "#364d31"], 0.0, 1.0]],
	[19.5, [["#2c3a63", "#46467a", "#6c4f7c", "#9a5a74", "#c46c64", "#e08c62", "#efb276"],
		["#46404a", "#2d2a35"], 0.2, 0.6]],
	[21.0, [["#17203a", "#1f2846", "#2c3050", "#3d3958", "#55435c", "#6f4f5e", "#87605f"],
		["#262a2e", "#181c1f"], 0.7, 0.0]],
	[22.5, NIGHT],
	[24.0, NIGHT],
]
## The hours the sun rises and sets over the painted sky; the moon has the rest.
const SUN_RISE := 5.5
const SUN_SET := 20.5
## Stars over the top of the sky (some of them two pixels across), the birds' colour,
## the size of a pixel of them, their speed (UI px a second, the same on any screen) and
## the seconds from one flight's start to the next (more on a screen too wide to cross
## by then: FLOCK_REST after they are gone).
const STARS := 40
const BIRD := Color("#14211b")
const FLOCK_PX := 2.0
const FLOCK_SPEED := 40.0
const FLOCK_EVERY := 14.0
const FLOCK_REST := 2.0
## Columns of the picture from which its head dips when it pecks.
const SPARROW_HEAD := 5
## Seconds a hop takes and how high it goes (UI px), and how far one carries it.
const HOP_TIME := 0.22
const HOP_HIGH := 12.0
const HOP_STEP := 16.0
## One pixel of the sparrow in UI px, so it stands a little lower than the capitals.
const BIRD_PX := 3
## The easter egg: taps on the sparrow in a row (each within TAP_GAP seconds) that blow
## it up, the feathers it bursts into, their colours (the vane's, a quill is the lightest)
## and the fluff of down among them, the seconds the sparrow is away and the seconds it
## takes to fly back in.
const TAPS_TO_BLOW := 10
const TAP_GAP := 2.5
const FEATHER_COUNT := 26
const DOWN_COUNT := 30
const FEATHERS := [Color("#6b4a2e"), Color("#8f6a44"), Color("#c9a77c"), Color("#3a2a1c"), Color("#a0784c")]
const QUILL := Color("#efe3c8")
const DOWN := [Color("#e8d8bc"), Color("#f4ecdc"), Color("#c9a77c")]
## Milliseconds of the light buzz of each tap on the sparrow, and of the strong one when
## it bursts (Vibration, as the setting «Вибрация» allows).
const TAP_BUZZ_MS := 14
const BLOW_BUZZ_MS := 260
const BIRD_AWAY := 12.0
const FLY_TIME := 1.8
## The hour the painted sky shows, -1 for the device's clock (a shot sets it).
static var hour_override := -1.0

var game
## The loading screen is up in place of the menu.
var loading := false
var _screen: Control
var _backdrop: Control
## What moves over the painted sky (see _draw_motion), and seconds it has been moving.
var _motion: Control
var _time := 0.0
## When (in _time) the flock set off on its flight across.
var _flock_from := 0.0
## The colours of the sky for the hour shown (see _sky_at) and that hour.
var _sky: Array = NIGHT
var _sky_hour := -100.0
var _title: Label
## The sparrow hopping along the top of the name: where it stands (UI px from the
## name's left), which way it faces, what it does ("sit", "peck", "hop") and for how
## much longer, and where a hop takes it.
var _sparrow: Control
var _sparrow_picture: Texture2D
var _sparrow_frames := 1
## Of its frames, how many beat its wings (after the first); rows of its picture (the
## side is the first).
var _sparrow_walk := 0
var _sparrow_views := 1
## The sparrow as the menu first found it: [picture, frames, walk frames, views]. The
## menu is built again with every return from a world (main.gd restart), and the creatures
## loaded then are that world's (Mods.activate, already at the start: the last world is
## chosen before the menu is built): one played without the sparrow's bundle, or on a
## server whose mods have none, left the name without its sparrow, and with it the way
## into the playtest switches. Kept for the run of the game; without it the record is
## read from the bundles on disk (_sparrow_on_disk).
static var _sparrow_kept: Array = []
var _bird_x := 40.0
var _bird_dir := 1.0
var _bird_do := "sit"
var _bird_left := 1.0
var _bird_from := 40.0
var _bird_to := 40.0
## The easter egg (see _explode): what takes the taps on the sparrow, the taps so far
## and the seconds left to the next, the layer the burst is drawn on, its feathers and
## specks of down, the flash where the sparrow was, the seconds the name shakes and where
## the name stands still.
var _sparrow_hit: Control
var _taps := 0
var _tap_clock := 0.0
var _fx: Control
var _feathers: Array = []
var _sparks: Array = []
var _flash := {}
var _shake := 0.0
var _title_at := Vector2.ZERO


## The hour the sky shows: the device's clock, or the one a shot set.
static func hour() -> float:
	if hour_override >= 0.0:
		return hour_override
	var t := Time.get_time_dict_from_system()
	return t.hour + t.minute / 60.0


## The sky's colours at `h` o'clock (see SKIES): [bands, hills, stars, birds], blended
## between the two hours around it.
static func sky_at(h: float) -> Array:
	h = fposmod(h, 24.0)
	for i in range(1, SKIES.size()):
		var b: Array = SKIES[i]
		if h > b[0]:
			continue
		var a: Array = SKIES[i - 1]
		var t: float = (h - a[0]) / maxf(b[0] - a[0], 0.001)
		var bands := []
		for k in a[1][0].size():
			bands.append(Color(a[1][0][k]).lerp(Color(b[1][0][k]), t))
		var hills := []
		for k in a[1][1].size():
			hills.append(Color(a[1][1][k]).lerp(Color(b[1][1][k]), t))
		return [bands, hills, lerpf(a[1][2], b[1][2], t), lerpf(a[1][3], b[1][3], t)]
	return sky_at(0.0)


## The sky follows the clock: drawn again when the hour shown moves (a minute or so).
func _update_sky() -> void:
	var h := hour()
	if absf(h - _sky_hour) < 0.02:
		return
	_sky_hour = h
	_sky = sky_at(h)
	_backdrop.queue_redraw()


## The painted landscape until the world is ready: bands down to the horizon with a row
## of dithered pixels between them, then two ranges of hills, in the colours of the hour
## (see sky_at). It covers the whole window, past the safe rect.
func _draw_sky() -> void:
	if _sky_hour < -50.0:
		_update_sky()
	var bands: Array = _sky[0]
	var hills: Array = _sky[1]
	var s: float = scale.x
	var full := Rect2(-position / s, get_viewport_rect().size / s).grow(2)
	var top := full.position.y
	var horizon := top + full.size.y * 0.62
	var band := (horizon - top) / bands.size()
	for i in bands.size():
		var y0 := floorf(top + i * band)
		_backdrop.draw_rect(Rect2(full.position.x, y0, full.size.x, ceilf(band) + 1), bands[i])
		if i > 0:
			# Every other pixel of the band above, along the seam.
			for x in range(int(full.position.x), int(full.end.x), 2):
				_backdrop.draw_rect(Rect2(x, y0, 1, 1), bands[i - 1])
	_backdrop.draw_rect(Rect2(full.position.x, horizon, full.size.x, full.end.y - horizon), bands[bands.size() - 1])
	_draw_light(full, horizon)
	for h in hills.size():
		var base := horizon + (h + 1) * full.size.y * 0.1
		var x := int(full.position.x)
		while x < int(full.end.x):
			var t := float(x) * (0.012 + h * 0.008) + h * 2.0
			var y := floorf(base - (sin(t) * 0.6 + sin(t * 2.3 + 1.0) * 0.3 + 1.0) * full.size.y * (0.06 - h * 0.015))
			_backdrop.draw_rect(Rect2(x, y, 2, full.end.y - y), hills[h])
			x += 2


## The sun from SUN_RISE to SUN_SET, the moon (a crescent) the rest of the
## night, each along an arc over the sky from the left to the right, setting behind the
## hills drawn after it.
func _draw_light(full: Rect2, horizon: float) -> void:
	var h := fposmod(_sky_hour, 24.0)
	var sun := h >= SUN_RISE and h <= SUN_SET
	var t := (h - SUN_RISE) / (SUN_SET - SUN_RISE) if sun else fposmod(h - SUN_SET, 24.0) / (24.0 - SUN_SET + SUN_RISE)
	var sky_h := horizon - full.position.y
	var at := Vector2(full.position.x + full.size.x * lerpf(0.12, 0.88, t),
		horizon + sky_h * 0.08 - sin(PI * t) * sky_h * 0.75).floor()
	var r := 9.0 if sun else 7.0
	var low := clampf(1.0 - sin(PI * t) * 2.5, 0.0, 1.0)
	var color := Color("#f8e7a8").lerp(Color("#f3a65e"), low) if sun else Color("#e8e3cc")
	_pixel_disc(at, r, color)
	if not sun:
		# The dark of the moon: a disc of the sky's colour over a side of it.
		var behind: Color = _sky[0][clampi(int((at.y - full.position.y) / sky_h * _sky[0].size()), 0, _sky[0].size() - 1)]
		_pixel_disc(at + Vector2(4, -2), r - 1.0, behind)


## A round disc of whole pixels of radius `r` UI px around `at`.
func _pixel_disc(at: Vector2, r: float, color: Color) -> void:
	for dy in range(-int(r), int(r) + 1):
		var w := floorf(sqrt(maxf(r * r - (dy + 0.5) * (dy + 0.5), 0.0)) + 0.5)
		if w > 0.0:
			_backdrop.draw_rect(Rect2(at.x - w, at.y + dy, 2.0 * w, 1.0), color)


## Takes the sparrow's picture from `spec` (a record of AiRules.SPECIES, empty when the
## creatures loaded have none), else the one kept from before (_sparrow_kept), else the
## record `id` as written in a bundle on disk, loaded or not.
func _take_sparrow(spec: Dictionary, id: String) -> void:
	if spec.is_empty() and _sparrow_kept.is_empty():
		spec = _sparrow_on_disk(id)
	var picture: Texture2D = Creatures.picture(spec) if not spec.is_empty() else null
	if picture != null:
		_sparrow_kept = [picture, spec.frames, Creatures.walk_frames(spec), spec.views]
	if _sparrow_kept.is_empty():
		return
	_sparrow_picture = _sparrow_kept[0]
	_sparrow_frames = _sparrow_kept[1]
	_sparrow_walk = _sparrow_kept[2]
	_sparrow_views = _sparrow_kept[3]


## Creature `id` as written in the bundle that owns it (Content.universe: every bundle
## on disk, not only the world's), with the fields the menu reads; empty when none has it.
static func _sparrow_on_disk(id: String) -> Dictionary:
	var all := Content.universe()
	for b: String in all:
		for r: Dictionary in all[b].records.get("creatures", []):
			if r.id != id or r.get("patch") == true or not r.get("sprite") is String:
				continue
			var spec := r.duplicate()
			spec.bundle = b
			spec.mod = all[b].mod
			spec.frames = int(r.get("frames", 1))
			spec.walk = int(r.get("walk", -1))
			spec.views = int(r.get("views", 1))
			return spec
	return {}


## The sparrow sits a while, pecks now and then, and hops along the name, turning
## back at its ends. Blown up (see _explode) it is gone for BIRD_AWAY seconds, then
## flies in from the left and sits down where it was.
func _move_sparrow(delta: float) -> void:
	_tap_clock -= delta
	if _tap_clock <= 0.0:
		_taps = 0
	_bird_left -= delta
	if _bird_do == "gone":
		if _bird_left <= 0.0:
			_bird_do = "fly"
			_bird_dir = 1.0
			_bird_left = FLY_TIME
		_sparrow.queue_redraw()
		return
	if _bird_do == "hop":
		var t := clampf(1.0 - _bird_left / HOP_TIME, 0.0, 1.0)
		_bird_x = lerpf(_bird_from, _bird_to, t)
	if _bird_left <= 0.0:
		_bird_x = _bird_to if _bird_do == "hop" else _bird_x
		var roll := randf()
		# Still while it is being tapped, so the taps keep finding it.
		if _bird_do not in ["hop", "fly"] and roll < 0.45 and _taps == 0:
			var room := _title.size.x - _sparrow_size().x - 6.0
			if _bird_x + _bird_dir * HOP_STEP < 6.0 or _bird_x + _bird_dir * HOP_STEP > room or randf() < 0.15:
				_bird_dir = -_bird_dir
			_bird_do = "hop"
			_bird_from = _bird_x
			_bird_to = clampf(_bird_x + _bird_dir * HOP_STEP, 6.0, room)
			_bird_left = HOP_TIME
		elif roll < 0.7:
			_bird_do = "peck"
			_bird_left = 0.35
		else:
			_bird_do = "sit"
			_bird_left = randf_range(0.5, 2.0)
	var r := _bird_rect()
	_sparrow_hit.position = r.position - Vector2(8, 8)
	_sparrow_hit.size = r.size + Vector2(16, 16)
	_sparrow.queue_redraw()


## The sparrow's picture size in UI px, one frame.
func _sparrow_size() -> Vector2:
	if _sparrow_picture == null:
		return Vector2.ZERO
	return Vector2(_sparrow_picture.get_width() / _sparrow_frames, _sparrow_picture.get_height() / _sparrow_views) * BIRD_PX


## Where the sparrow is drawn in the name's UI px (its frame's rect), and its frame:
## [rect, frame]. A hop lifts it, flying in it comes down an arc from the left.
func _bird_place() -> Array:
	# The top of the capitals of the 32 px font, under the label's own room above them.
	var top := floorf(_title.size.y * 0.5 - TITLE_SIZE * 0.34) - 3.0
	var size := _sparrow_size()
	var lift := 0.0
	var x := _bird_x
	var frame := 0
	if _bird_do == "hop":
		var t := clampf(1.0 - _bird_left / HOP_TIME, 0.0, 1.0)
		lift = floorf(HOP_HIGH * 4.0 * t * (1.0 - t))
		if _sparrow_walk > 0:
			frame = 1 + int(t * 3.0) % _sparrow_walk
	elif _bird_do == "fly":
		var t := clampf(1.0 - _bird_left / FLY_TIME, 0.0, 1.0)
		var ease := 1.0 - (1.0 - t) * (1.0 - t)
		x = lerpf(-_title.position.x - size.x - 10.0, _bird_x, ease)
		lift = floorf((1.0 - ease) * 90.0)
		if _sparrow_walk > 0 and t < 0.96:
			frame = 1 + int(_time * 14.0) % _sparrow_walk
	return [Rect2(Vector2(floorf(x), top - size.y - lift), size), frame]


## The least top of the name (UI px) that leaves the sparrow sitting on it in sight.
func _title_least_top() -> float:
	var sit := floorf(_title.size.y * 0.5 - TITLE_SIZE * 0.34) - 3.0 - _sparrow_size().y
	return maxf(12.0, 4.0 - sit)


func _bird_rect() -> Rect2:
	return _bird_place()[0]


## The sparrow on the top of the letters: raised in a hop beating its wings, its head
## down when it pecks; nothing while it is blown away.
func _draw_sparrow() -> void:
	if _sparrow_picture == null or _bird_do == "gone":
		return
	var place := _bird_place()
	var at: Vector2 = place[0].position
	var frame: int = place[1]
	var cell := _sparrow_size() / BIRD_PX
	# Facing left is the picture mirrored about its middle.
	if _bird_dir > 0.0:
		_sparrow.draw_set_transform(at, 0.0, Vector2(BIRD_PX, BIRD_PX))
	else:
		_sparrow.draw_set_transform(at + Vector2(cell.x * BIRD_PX, 0.0), 0.0, Vector2(-BIRD_PX, BIRD_PX))
	var x0 := frame * cell.x
	if _bird_do == "peck" and _sparrow_frames > 1 + _sparrow_walk:
		# Its first idle frame is the peck.
		x0 = (1 + _sparrow_walk) * cell.x
		_sparrow.draw_texture_rect_region(_sparrow_picture, Rect2(0, 0, cell.x, cell.y), Rect2(x0, 0, cell.x, cell.y))
	elif _bird_do == "peck":
		# The tail and the body stay, the head goes a pixel down.
		_sparrow.draw_texture_rect_region(_sparrow_picture, Rect2(0, 0, SPARROW_HEAD, cell.y),
			Rect2(x0, 0, SPARROW_HEAD, cell.y))
		_sparrow.draw_texture_rect_region(_sparrow_picture, Rect2(SPARROW_HEAD, 1, cell.x - SPARROW_HEAD, cell.y - 1),
			Rect2(x0 + SPARROW_HEAD, 0, cell.x - SPARROW_HEAD, cell.y - 1))
	else:
		_sparrow.draw_texture_rect_region(_sparrow_picture, Rect2(0, 0, cell.x, cell.y), Rect2(x0, 0, cell.x, cell.y))
	_sparrow.draw_set_transform(Vector2.ZERO)


## A tap on the sparrow: it jumps up, startled, with a click a little higher each time;
## the TAPS_TO_BLOW-th tap in a row (each within TAP_GAP of the last) blows it up.
func _on_sparrow_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _bird_do in ["gone", "fly"]:
		return
	_sparrow_hit.accept_event()
	_taps += 1
	_tap_clock = TAP_GAP
	game.sound.play("click", Vector3.INF, 0.7, 1.0 + 0.09 * _taps, "UI")
	if _taps >= TAPS_TO_BLOW:
		Vibration.buzz(game, BLOW_BUZZ_MS)
		_explode()
		return
	Vibration.buzz(game, TAP_BUZZ_MS)
	if _bird_do != "hop":
		_bird_do = "hop"
		_bird_from = _bird_x
		_bird_to = _bird_x
		_bird_left = HOP_TIME


## The easter egg: the sparrow bursts into feathers with a flash and the name shakes;
## the feathers fly apart, then drift down rocking side to side and turning, among
## specks of down, and fade out; the sparrow comes back later (see _move_sparrow).
func _explode() -> void:
	_taps = 0
	print("easter egg: the sparrow blew up")
	if not game.settings.testing_unlocked:
		game.settings.testing_unlocked = true
		game.hud.unlock_testing()
	var r := _bird_rect()
	var at := _title.position + r.get_center()
	_bird_do = "gone"
	_bird_left = BIRD_AWAY
	_shake = 0.6
	_flash = {"p": at, "t": 0.0}
	game.sound.play("thunder", Vector3.INF, 0.6, 2.6, "UI")
	for i in FEATHER_COUNT:
		var a := TAU * (i + randf() * 0.8) / FEATHER_COUNT
		var v := Vector2(cos(a), sin(a) * 0.8) * randf_range(70.0, 190.0) + Vector2(0, -50)
		_feathers.append({"p": at + Vector2(cos(a), sin(a)) * 4.0, "v": v, "t": 0.0, "life": randf_range(2.6, 4.2),
			"c": FEATHERS[randi() % FEATHERS.size()], "len": randi_range(3, 6), "wide": randf() < 0.6,
			"a": a + randf_range(-0.6, 0.6), "spin": randf_range(-9.0, 9.0), "fall": randf_range(16.0, 30.0),
			"rock": randf_range(5.0, 12.0), "beat": randf_range(2.2, 3.6), "ph": randf() * TAU, "x": 0.0})
	for i in DOWN_COUNT:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(20.0, 120.0) + Vector2(0, -30)
		_sparks.append({"p": at, "v": v, "t": 0.0, "life": randf_range(1.2, 2.6),
			"c": DOWN[randi() % DOWN.size()], "s": 2.0 if i % 4 == 0 else 1.0, "drag": 2.6, "fall": 14.0})


## Moves the feathers and the down (UI px, seconds) and draws them again.
func _update_fx(delta: float) -> void:
	if _sparks.is_empty() and _feathers.is_empty() and _shake <= 0.0 and _flash.is_empty():
		return
	_shake = maxf(_shake - delta, 0.0)
	if not _flash.is_empty():
		_flash.t += delta
		if _flash.t > 0.25:
			_flash = {}
	for k in range(_feathers.size() - 1, -1, -1):
		var f: Dictionary = _feathers[k]
		f.t += delta
		if f.t >= f.life:
			_feathers.remove_at(k)
			continue
		# Thrown out fast, the air soon holds a feather to a slow fall, rocking it side to
		# side and tilting it with each swing; its spin dies down.
		f.v.x *= maxf(0.0, 1.0 - 3.2 * delta)
		f.v.y = move_toward(f.v.y * maxf(0.0, 1.0 - 2.4 * delta), f.fall, 90.0 * delta)
		f.p += f.v * delta
		var settle := minf(f.t / 0.8, 1.0)
		var swing := sin(f.t * f.beat + f.ph)
		f.x = swing * f.rock * settle
		f.spin *= maxf(0.0, 1.0 - 2.5 * delta)
		f.a += (f.spin + cos(f.t * f.beat + f.ph) * 1.6 * settle) * delta
	for k in range(_sparks.size() - 1, -1, -1):
		var p: Dictionary = _sparks[k]
		p.t += delta
		if p.t >= p.life:
			_sparks.remove_at(k)
			continue
		p.v *= maxf(0.0, 1.0 - p.drag * delta)
		p.v.y += p.fall * delta
		p.p += p.v * delta
	var shake := Vector2.ZERO
	if _shake > 0.0:
		shake = Vector2(randi_range(-2, 2), randi_range(-1, 1)) * ceilf(_shake * 2.0)
	_title.position = _title_at + shake
	_fx.queue_redraw()


func _draw_fx() -> void:
	if not _flash.is_empty():
		var k: float = 1.0 - _flash.t / 0.25
		var r: float = 6.0 + 40.0 * _flash.t / 0.25
		_fx_ring(_flash.p, r, Color(1.0, 0.97, 0.85, k))
	for p: Dictionary in _sparks:
		var c: Color = p.c
		c.a = clampf((1.0 - p.t / p.life) * 1.5, 0.0, 1.0)
		_fx.draw_rect(Rect2(p.p.floor(), Vector2.ONE * p.s), c)
	for f: Dictionary in _feathers:
		_draw_feather(f)


## A feather in whole 2 px cells along its tilt: a light quill at its foot, the vane
## after it, a cell wider in the middle when it is a broad one; it fades at the end.
func _draw_feather(f: Dictionary) -> void:
	var fade: float = clampf((f.life - f.t) / 0.8, 0.0, 1.0)
	var along := Vector2(cos(f.a), sin(f.a))
	var side := Vector2(-along.y, along.x)
	var n: int = f.len
	var mid: Vector2 = f.p + Vector2(f.x, 0.0)
	for i in n:
		var at := mid + along * 2.0 * (i - (n - 1) * 0.5)
		var c: Color = QUILL if i == 0 else f.c
		c.a = fade
		_fx.draw_rect(Rect2(at.floor(), Vector2(2, 2)), c)
		if f.wide and i > 0 and i < n - 1:
			var v: Color = f.c.darkened(0.15)
			v.a = fade
			_fx.draw_rect(Rect2((at + side * 2.0).floor(), Vector2(2, 2)), v)


## A ring of whole pixels of radius `r` around `at`.
func _fx_ring(at: Vector2, r: float, color: Color) -> void:
	var n := maxi(12, int(r * 1.5))
	for i in n:
		var a := TAU * i / n
		_fx.draw_rect(Rect2((at + Vector2(cos(a), sin(a)) * r).floor(), Vector2(2, 2)), color)


## The sky's moving parts, over the painted sky: stars blinking at the top as far as
## the hour has them, and three birds flapping across now and then by day.
func _draw_motion() -> void:
	var s: float = scale.x
	var full := Rect2(-position / s, get_viewport_rect().size / s).grow(2)
	var top := full.position.y
	var sky_h := full.size.y * 0.62
	var stars: float = _sky[2]
	if stars > 0.0:
		for i in STARS:
			var h := absi(hash(i * 7919))
			var sx := full.position.x + float(h % 1000) / 1000.0 * full.size.x
			var sy := top + float((h >> 10) % 1000) / 1000.0 * sky_h * 0.55
			var blink := 0.5 + 0.5 * sin(_time * (1.0 + (h % 5) * 0.4) + i)
			var px := 2.0 if h % 3 == 0 else 1.0
			_motion.draw_rect(Rect2(floorf(sx), floorf(sy), px, px), Color(1.0, 0.96, 0.82, (0.45 + 0.55 * blink) * stars))
	if _sky[3] < 0.5:
		return
	# The birds cross at FLOCK_SPEED every FLOCK_EVERY s (or once gone), in a loose V.
	var way := full.size.x + 40.0
	var flown := (_time - _flock_from) * FLOCK_SPEED
	if _time < _flock_from or _time - _flock_from >= maxf(FLOCK_EVERY, way / FLOCK_SPEED + FLOCK_REST):
		_flock_from = _time
		flown = 0.0
	if flown < way:
		var bx := full.position.x - 20.0 + flown
		var by := top + sky_h * 0.35 - flown / way * sky_h * 0.1
		for k in 3:
			var p := Vector2(floorf(bx - k * 16.0), floorf(by + (k % 2) * 10.0 + k * 3.0))
			var up := int(_time * 6.0 + k) % 2 == 0
			var dy := -1.0 if up else 1.0
			for q in [Vector2(-2, dy), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(2, dy)]:
				_motion.draw_rect(Rect2(p + q * FLOCK_PX, Vector2.ONE * FLOCK_PX), BIRD)
