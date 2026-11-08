extends "res://src/client/ui/menu_backdrop.gd"
## The main menu, part two (main_menu.gd): the loading screen shown while a world is
## made or loaded: the map of the land drawn as it is made, the strip of the parts of the
## start with their times (StartTimes), the tips, the cancel button, and the wait for the
## first calm frames of the world before the menu goes.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const StartTimes := preload("res://src/client/ui/start_times.gd")
const Minimap := preload("res://src/client/ui/minimap.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const WIDTH := 216
const BUTTON_H := 30
## The loading screen's map: the sides tried in turn until the card fits the screen (as
## wide as the card, then smaller, then none: the tips and the strip alone), and UI px
## a map pixel. A new tip comes every TIP_TIME seconds.
const MAP_SIZES := [WIDTH - 2 * Minimap.FRAME, 128, 96, 64, 0]
const MAP_ZOOM := 2.0
const TIP_TIME := 6.0
## The strip keeps a caption this long at least, so a short part does not flash by
## unread (seconds).
const PHASE_HOLD := 1.2
## The progress strip at the bottom of the card: two lines, as tall as a button, with
## the cancel button (a cross, as square as a button) right of it, and UI px between its
## edges and its words.
const STRIP_PAD := 5
## After the world is ready the menu waits for the frames to settle before the world
## shows: no shaders being built ahead (see ShaderWarmup) and CALM_FRAMES frames in a
## row under CALM_FRAME seconds, SETTLE_MAX seconds at most.
const CALM_FRAME := 0.05
const CALM_FRAMES := 12
const SETTLE_MAX := 5.0
## The parts of the loading in order (Main.loading_part, then the first frames) and the
## captions of the last two.
const PARTS := ["setup", "build", "warm", "settle"]
const WARM_CAPTION := "Прогрев шейдеров"
const SETTLE_CAPTION := "Первые кадры мира"
## Tips on the loading screen, each shown once a load in a shuffled order (see _next_tip).
const TIPS := [
	"Волокно дают высокая трава, травы и тростник; из трёх волокон скручивают верёвку.",
	"Кремень попадается, когда копаешь землю, песок и осыпь.",
	"Костёр складывают из пяти веток и пяти волокон, на нём жарят грибы, мясо и рыбу.",
	"Рецепт становится известен, когда в сумке побывали все его материалы.",
	"Верстак из восьми веток и двух верёвок: у него делают каменные инструменты.",
	"Печь для обжига складывают из камня и глины, в ней обжигают кирпичи и пекут лепёшки.",
	"Колоски дают зерно, а из зерна мелют муку.",
	"Из мха и волокна делают бинты.",
	"Карта помнит всё, что вы видели, и на ней можно ставить метки.",
	"Кнопки уровня у миникарты срезают вид: так видно, что в пещере и под кронами.",
	"Против ветра идти тяжелее, а в прыжке он сносит в сторону.",
	"Факел из ветки и двух волокон светит в темноте, но со временем догорает.",
	"Доски делают у верстака из бревна, если в сумке есть топор.",
	"Медную руду бьют киркой в жилах камня, а слитки плавят в горне из руды и угля.",
	"Уголь выжигают из брёвен в печи для обжига.",
	"Сундук из шести досок хранит вещи, которые не помещаются в сумку.",
	"Прыжки, плавание и работа тратят силы, а в покое они возвращаются.",
	"Голодному не восстановить силы полностью: ешьте ягоды, грибы, мясо и лепёшки.",
	"С тяжёлой сумкой идёшь медленнее: лишнее можно оставить в сундуке.",
	"Без сил в воде начинаешь тонуть: далеко не заплывайте.",
	"Горящий костёр обжигает и отбрасывает, если подойти вплотную.",
	"После смерти вещи остаются в мешке на месте гибели, он отмечен на карте.",
	"Возвращаешься к жизни у своего костра: поставьте его рядом с домом.",
	"Жёлуди, шишки и семена можно посадить, и из них вырастут деревья и травы.",
	"Траву срезают руками, мечом или косой, и с неё падает волокно.",
	"Камеру можно повернуть кнопками у миникарты и наклонить, чтобы заглянуть за деревья.",
	"В настройках время суток, сезон и погоду можно сделать как в жизни.",
	"Удочку делают из двух веток, двух верёвок и кремня, а пойманную рыбу жарят на костре.",
	"Тушку зверька разделывают руками, а большую тушу — только ножом: с неё падают шкура, кости и жир.",
	"На сушилке из шкуры и жира выделывают кожу, там же вялят мясо.",
	"Лук и стрелы делают у верстака, а наконечник стрелы — из кремня или кости.",
	"Бронзу плавят в горне из меди и олова, и в сумке должен быть тигель.",
	"Железную руду плавят в крицу в сыродутной печи, а из крицы в горне получаются слитки.",
	"Железные и стальные инструменты куют на наковальне.",
	"Из стеблей льна прядут нить, а на ткацком станке ткут из неё ткань.",
	"Смолу выгоняют из брёвен в печи для обжига, и для этого нужен глиняный горшок.",
	"Серебро, золото и платину плавят в горне, а на наковальне из слитков собирают блоки.",
]
## The seed written over the map.
var _map_seed: Label
var _strip: Control
var _strip_fill: Control
## The words on the strip: what is being done on the first line, the seconds at the
## left and the per cent at the right of the second.
var _strip_top := ""
var _strip_left := ""
var _strip_right := ""
var _cancel: Button
## The loading card: the map, the tip and the strip (see MAP_SIZES).
var _loading: PanelContainer
var _map_ground: Minimap.Layer
var _map_top: Minimap.Layer
var _tip: Label
## The caption shown on the strip and for how long.
var _phase_shown := ""
var _phase_clock := 0.0
## The world is ready and its first frames are over (see CALM_FRAMES): the landscape
## fades, the menu goes in.
var settled := false
var _calm := 0
## When the world was ready and its shaders built (msec of the clock, -1 before): SETTLE_MAX goes by real
## time, not by the frames' delta, which the engine caps at 8 physics steps a frame
## (a slow device's second-long frames would stretch it to minutes).
var _ready_at := -1
## When the loading began and when each of its parts began (msec), and the share of
## the strip each part takes (see StartTimes.part_shares).
var _load_at := -1
var _part_at := {}
var _shares := {}
## The progress shown: it only goes forward, easing to the measured one.
var _progress := 0.0
## A shot holds the strip at this progress (0..1), -1 for the loading's own.
var shown_progress := -1.0
## The tips not shown yet, by index, in the order they come (see _next_tip).
var _tips_left: Array = []
var _tip_clock := 0.0
var _map_well: Control
var _map_side: int = MAP_SIZES[0]


## The loading card: the map around the start in a frame like the minimap's with the
## seed over it, the tip right under it (as tall as the longest tip, the words in its
## middle, so the card keeps its size as they change), and the strip with the cancel button at the bottom.
func _build_loading() -> void:
	_loading = PanelContainer.new()
	_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_loading)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_loading.add_child(box)
	_map_well = Control.new()
	_map_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_map_well.draw.connect(func() -> void:
		var inner := Rect2(Minimap.FRAME, Minimap.FRAME, _map_side, _map_side)
		Minimap.round_rect(_map_well, inner.grow(1), UiStyle.EDGE, Minimap.CORNER + 1)
		Minimap.round_rect(_map_well, inner, Minimap.UNSEEN, Minimap.CORNER))
	box.add_child(_map_well)
	_map_ground = Minimap.ground_layer(_draw_map, Minimap.CORNER)
	_map_well.add_child(_map_ground)
	_map_top = Minimap.Layer.new(_draw_map_top)
	_map_well.add_child(_map_top)
	_map_top.position = Vector2(Minimap.FRAME, Minimap.FRAME)
	_map_seed = UiStyle.label("", UiStyle.INK)
	_map_seed.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	_map_seed.add_theme_constant_override("outline_size", 4)
	_map_seed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_seed.position = Vector2(0, Minimap.FRAME + 5)
	_map_well.add_child(_map_seed)
	_set_map_side(MAP_SIZES[0])
	var well := PanelContainer.new()
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_theme_stylebox_override("panel", UiStyle.well())
	box.add_child(well)
	_tip = UiStyle.label("", UiStyle.MUTED)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# As tall as the longest tip at the width it is shown, so the card keeps its size as
	# they change.
	var width := WIDTH - 2 * UiStyle.WELL_PAD
	var tall := 0
	# Measured by a label in the tree, so it wraps in the theme's font.
	var probe := UiStyle.label("", UiStyle.MUTED)
	probe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(probe)
	probe.size = Vector2(width, 0)
	for tip: String in TIPS:
		probe.text = tip
		tall = maxi(tall, ceili(probe.get_minimum_size().y))
	probe.free()
	_tip.custom_minimum_size = Vector2(width, tall)
	well.add_child(_tip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	_build_strip(row)
	_cancel = Button.new()
	_cancel.icon = UiStyle.centred(UiStyle.icon("close"))
	_cancel.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cancel.tooltip_text = "Отменить загрузку (Esc)"
	_cancel.focus_mode = Control.FOCUS_NONE
	_cancel.custom_minimum_size = Vector2(BUTTON_H, BUTTON_H)
	_cancel.pressed.connect(cancel_loading)
	row.add_child(_cancel)
	_loading.visible = false


## The map's side in UI px: its well, the ground and what is drawn over it.
func _set_map_side(side: int) -> void:
	_map_side = side
	_map_well.visible = side > 0
	_map_well.custom_minimum_size = Vector2.ONE * (side + 2 * Minimap.FRAME)
	Minimap.place_ground(_map_ground, Rect2(Minimap.FRAME, Minimap.FRAME, side, side))
	_map_top.size = Vector2(side, side)
	_map_seed.size = Vector2(side + 2 * Minimap.FRAME, 0)
	_map_well.queue_redraw()


func _draw_map(l: Control) -> void:
	# Nothing to draw before the scene around the start is built.
	if game.player == null:
		return
	var centre: Vector2 = Vector2(game.player.position.x, game.player.position.z) / game.CELL
	game.hud.minimap.draw_ground(l, Rect2(Vector2.ZERO, l.size), centre, MAP_ZOOM)


## How far the loading has gone and its words in one strip as tall as a button: an
## amber fill in a sunken slot, the words light over the slot and dark over the fill,
## which a child clipped to the fill draws over the slot.
func _build_strip(row: Control) -> void:
	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.custom_minimum_size = Vector2(WIDTH - BUTTON_H - 6, BUTTON_H)
	_strip.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, _strip.size)
		_strip.draw_rect(r, UiStyle.EDGE)
		_strip.draw_rect(r.grow(-1), Minimap.UNSEEN)
		_strip.draw_rect(Rect2(1, 1, _strip.size.x - 2, 1), UiStyle.WELL_SHADE)
		_strip_words(_strip, UiStyle.INK))
	row.add_child(_strip)
	_strip_fill = Control.new()
	_strip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip_fill.clip_contents = true
	_strip_fill.position = Vector2(1, 1)
	_strip_fill.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, _strip_fill.size)
		_strip_fill.draw_rect(r, UiStyle.ACCENT)
		_strip_fill.draw_rect(Rect2(0, r.size.y - 1, r.size.x, 1), UiStyle.ACCENT_DARK)
		_strip_words(_strip_fill, UiStyle.DARK_INK, Vector2(-1, -1)))
	_strip.add_child(_strip_fill)


## The strip's words: what is being done on the top line, the seconds and the per cent
## at the ends of the bottom one; `shift` puts them where they are on the strip when
## drawn by the fill.
func _strip_words(on: Control, color: Color, shift := Vector2.ZERO) -> void:
	var f := UiStyle.font()
	var line := f.get_height(UiStyle.FONT_SIZE)
	var gap := 4.0
	var y := floorf((_strip.size.y - 2.0 * line - gap) * 0.5) + f.get_ascent(UiStyle.FONT_SIZE)
	var inside := _strip.size.x - 2 * STRIP_PAD
	on.draw_string(f, Vector2(STRIP_PAD, y) + shift, Lang.t(_strip_top), HORIZONTAL_ALIGNMENT_LEFT, inside,
		UiStyle.FONT_SIZE, color, TextServer.JUSTIFICATION_NONE)
	y += line + gap
	on.draw_string(f, Vector2(STRIP_PAD, y) + shift, _strip_left, HORIZONTAL_ALIGNMENT_LEFT, inside,
		UiStyle.FONT_SIZE, color)
	on.draw_string(f, Vector2(STRIP_PAD, y) + shift, _strip_right, HORIZONTAL_ALIGNMENT_RIGHT, inside,
		UiStyle.FONT_SIZE, color)


## The part of the loading going on: Main.loading_part, then the first frames.
func _part() -> String:
	if settled:
		return ""
	var part: String = game.loading_part()
	if part == "":
		return "settle"
	return part


## How far the part going on has gone, 0 to 1.
func _part_done(part: String) -> float:
	if part == "settle":
		if _ready_at < 0:
			return 0.0
		# By the calm frames, or by the time the first frames took the last load (the
		# longest they may take otherwise), whichever is further.
		var expect: float = StartTimes.last_part_ms("settle", SETTLE_MAX * 500.0)
		var by_time := (Time.get_ticks_msec() - _ready_at) / maxf(expect, 1.0)
		return minf(maxf(float(_calm) / CALM_FRAMES, by_time), 0.97)
	return clampf(game.loading_fraction(), 0.0, 1.0)


## How far the whole loading has gone, 0 to 1: the parts before the one going on at
## their full share, that one at the share of it done.
func _measured() -> float:
	if settled:
		return 1.0
	var part := _part()
	var done := 0.0
	for p: String in PARTS:
		if p == part:
			return done + _shares.get(p, 0.0) * _part_done(p)
		done += _shares.get(p, 0.0)
	return done


## The caption going on, each kept PHASE_HOLD at least; the seconds since the loading
## began and the per cent.
func _update_strip(delta: float) -> void:
	_phase_clock += delta
	var part := _part()
	if part != "" and not _part_at.has(part):
		_part_at[part] = Time.get_ticks_msec()
	var phase := "Мир готов"
	match part:
		"warm":
			phase = WARM_CAPTION
		"settle":
			phase = SETTLE_CAPTION
		"setup", "build":
			phase = game.loading_phase()
	if phase != _phase_shown and (_phase_clock >= PHASE_HOLD or _phase_shown == "" or settled):
		_phase_shown = phase
		_phase_clock = 0.0
	if shown_progress >= 0.0:
		_progress = shown_progress
	else:
		# Eases forward to the measured progress, never back.
		_progress = maxf(_progress, lerpf(_progress, _measured(), minf(1.0, delta * 6.0)))
		if settled:
			_progress = 1.0
	var seconds := (Time.get_ticks_msec() - _load_at) / 1000.0 if _load_at >= 0 else 0.0
	var top := _phase_shown
	var left := Lang.f("%d с", [floori(seconds)])
	var right := "%d%%" % floori(100.0 * _progress)
	var fill := Vector2(floorf((_strip.size.x - 2) * _progress), _strip.size.y - 2)
	if top == _strip_top and left == _strip_left and right == _strip_right and fill == _strip_fill.size:
		return
	_strip_top = top
	_strip_left = left
	_strip_right = right
	_strip_fill.size = fill
	_strip.queue_redraw()
	_strip_fill.queue_redraw()


## The player an amber dot outlined dark in the middle, the slot's shade along the top
## and left as on the minimap.
func _draw_map_top(l: Control) -> void:
	var p := (l.size * 0.5).floor()
	if game.player != null:
		l.draw_rect(Rect2(p - Vector2(3, 3), Vector2(7, 7)), UiStyle.DARK_INK)
		l.draw_rect(Rect2(p - Vector2(2, 2), Vector2(5, 5)), UiStyle.ACCENT)
	l.draw_rect(Rect2(Minimap.CORNER, 0, l.size.x - 2 * Minimap.CORNER, 1), UiStyle.WELL_SHADE)
	l.draw_rect(Rect2(0, Minimap.CORNER, 1, l.size.y - 2 * Minimap.CORNER), UiStyle.WELL_SHADE)


## While the loading screen is up: the map drawn again as the minimap paints chunks
## in, the strip, the tips.
func _update_loading(delta: float) -> void:
	if not loading:
		return
	if game.player != null and not game.hud.minimap.painted.is_connected(_on_painted):
		game.hud.minimap.painted.connect(_on_painted)
		_on_painted()
	_update_strip(delta)
	_tip_clock -= delta
	if _tip_clock <= 0.0:
		_tip_clock = TIP_TIME
		_next_tip()


func _on_painted() -> void:
	_map_ground.queue_redraw()
	_map_top.queue_redraw()


## Shows the next tip of the shuffled deck; once every tip has been shown the last one
## stays, so none comes twice in a load.
func _next_tip() -> void:
	if _tips_left.is_empty() and _tip.text == "":
		_tips_left = range(TIPS.size())
		_tips_left.shuffle()
	if not _tips_left.is_empty():
		_tip.text = TIPS[_tips_left.pop_back()]


## The cancel button (or Escape) on the loading screen: the scene starts again without a world
## (Main.cancel_loading), on the page the loading was asked from (go_back).
func cancel_loading() -> void:
	if not loading:
		return
	print("loading cancelled")
	game.cancel_loading()


## Counts the calm frames once the world is ready (see CALM_FRAMES).
func _settle() -> void:
	if settled or not game.ready_to_play or shown_progress >= 0.0:
		return
	# The first frames are counted from the end of the warm-up: until then the world is not
	# drawn, and the game must not show before its shaders are built.
	if game.warmup != null:
		return
	if _ready_at < 0:
		_ready_at = Time.get_ticks_msec()
		_part_at["settle"] = _ready_at
	var delta := get_process_delta_time()
	_calm = _calm + 1 if delta < CALM_FRAME else 0
	settled = _calm >= CALM_FRAMES or Time.get_ticks_msec() - _ready_at >= SETTLE_MAX * 1000.0
	if settled:
		StartTimes.mark("ready")


## The time each part of this loading took goes to StartTimes, for the shares of the
## next one.
func _keep_part_times() -> void:
	if not loading or _part_at.is_empty():
		return
	var now := Time.get_ticks_msec()
	var times := {}
	for i in PARTS.size():
		var p: String = PARTS[i]
		if not _part_at.has(p):
			continue
		var end := now
		for q in range(i + 1, PARTS.size()):
			if _part_at.has(PARTS[q]):
				end = _part_at[PARTS[q]]
				break
		times[p] = end - _part_at[p]
	StartTimes.keep_parts(times)
