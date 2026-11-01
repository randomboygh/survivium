extends Control
## The main menu (plan/design/ui.md, section 2; plan/architecture/server.md, «Меню и
## экраны»): the first screen, over a painted landscape coloured for the time of day of
## the device's clock (stars only at night). No world is made behind it: the world is
## loaded only once the player picks one. Its first page: «Одиночная игра»,
## «Мультиплеер», «Редактор», «Настройки», «Выход»; the first two open pages of their
## own in the same panel, with «Назад» at the bottom.
## «Одиночная игра»: "Играть" ("Продолжить" once the world has a save) loads the world
## played last, "Новый мир" opens WorldSetup over the menu and loads the world asked for,
## "Миры" lists the saved worlds to load one or delete it (WorldList); a world other than
## the one the scene was started for is loaded by a restart of the scene (Main.restart),
## which comes up on the loading screen at once. Joined to a server, each of them leaves
## it for a world of this device.
## «Мультиплеер»: «Присоединиться» opens JoinScreen (a link with `?server=` opens it
## at the start, its address filled in; a failed joining opens it again with why),
## «Создать сервер» opens HostScreen on a computer (on a phone or in the browser a tap
## says it is for a computer); joined, «Вернуться на сервер» and «Отключиться» come
## first. While a server made here runs, its button is «Сервер работает», and what
## would load other bundles under it (single player, joining another server,
## disconnecting) waits until it is stopped.
## «Настройки» opens the settings page. The editor is not there yet, so its button is
## disabled, and "Выход" is disabled in the browser.
## The loading screen takes the place of the menu while the world loads: the map around
## the start painted in as its chunks are made, the seed over it, a tip under it, and at
## the bottom how far the loading has gone, in two lines (what is being done, the seconds
## and the per cent), with the cancel button (a cross), which starts the scene again on the page the
## loading was asked from (see `back_to`). The progress goes evenly: each part of the
## loading (start_world's steps, the chunks, the shaders built ahead, the first frames)
## takes the share of the strip it took of the time the last load (StartTimes.part_shares).
## Once the world's first frames are calm the painted landscape fades out and the game
## shows. Reopened over a running world (the pause menu, the death screen) the menu has
## no landscape and «Продолжить» goes straight back in. The game's interface is hidden
## while the menu is open; the menu takes the scale and the safe rect the interface was
## fitted to. `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const StartTimes := preload("res://src/client/ui/start_times.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
## The menu's own screens are compiled when first opened, not at the game's start
## (StartTimes: compiling every script was most of the start).
const WORLD_SETUP := "res://src/client/ui/world_setup.gd"
const SETTINGS_MENU := "res://src/client/ui/settings_menu.gd"
const WORLD_LIST := "res://src/client/ui/world_list.gd"
const JOIN_SCREEN := "res://src/client/ui/join_screen.gd"
const HOST_SCREEN := "res://src/client/ui/host_screen.gd"
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Creatures := preload("res://src/client/game/creatures.gd")
const Minimap := preload("res://src/client/ui/minimap.gd")
const ShaderWarmup := preload("res://src/client/view/shader_warmup.gd")

const WIDTH := 200
const BUTTON_H := 30
const MARGIN := 24
const TITLE_SIZE := 32
## Seconds the painted landscape takes to fade once the world's first frames are calm.
const FADE := 1.2
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
## the size of a pixel of them and the seconds between their flights.
const STARS := 40
const BIRD := Color("#14211b")
const FLOCK_PX := 2.0
const FLOCK_EVERY := 14.0
## The sparrow on the name is the game's own (the animals mod's picture, facing right):
## sitting it is the first frame, in a hop it beats its wings with the others.
const SPARROW := "animals:sparrow"
## Columns of the picture from which its head dips when it pecks.
const SPARROW_HEAD := 5
## Seconds a hop takes and how high it goes (UI px), and how far one carries it.
const HOP_TIME := 0.22
const HOP_HIGH := 12.0
const HOP_STEP := 16.0
## One pixel of the sparrow in UI px, so it stands a little lower than the capitals.
const BIRD_PX := 3
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
## Seconds between two glints over the name.
const GLINT_EVERY := 4.0
const GLINT_SHADER := """
shader_type canvas_item;
uniform float glint = -1000.0;
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	// A slanted band of light over the letters, not over their dark outline.
	float d = local.x + local.y * 0.6 - glint;
	float band = step(0.0, d) * step(d, 6.0) + 0.5 * step(6.0, d) * step(d, 9.0);
	float lit = step(0.35, dot(COLOR.rgb, vec3(0.3, 0.5, 0.2)));
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.96, 0.84), 0.7 * band * lit);
}
"""

signal opened
signal closed

## Where the cancel button on the loading screen goes, kept over the restart it makes (and over
## the restart that loads another world): "single" (the page «Одиночная игра»),
## "worlds" (the list of worlds), "multi" (the page «Мультиплеер»), "" (the first page).
static var back_to := ""
## The hour the painted sky shows, -1 for the device's clock (a shot sets it).
static var hour_override := -1.0

var game
## True while the menu or the loading screen takes the screen (the landscape may still
## be fading after that).
var is_open := false
## The loading screen is up in place of the menu.
var loading := false
var _screen: Control
var _backdrop: Control
## What moves over the painted sky (see _draw_motion), and seconds it has been moving.
var _motion: Control
var _time := 0.0
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
var _bird_x := 40.0
var _bird_dir := 1.0
var _bird_do := "sit"
var _bird_left := 1.0
var _bird_from := 40.0
var _bird_to := 40.0
var _column: VBoxContainer
var _seed_label: Label
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
## The panel's buttons and the page they are of: "top", "single" or "multi".
var _box: VBoxContainer
var _page := "top"
## A server can be made here: a computer, not a phone or the browser (a shot sets it).
var host_here := OS.has_feature("pc")
## Frames until the page shown says where its buttons are (the browser test taps them).
var _announce := 0
## Under the buttons of «Мультиплеер»: why «Создать сервер» is not here.
var _note: Label
## Buttons by name, and the names in order of the keyboard focus.
var _buttons := {}
var _order := []
var _focus := 0
## The settings, made when first opened (settings_menu).
var _settings: Control = null
## The screen open over the menu: WorldSetup, WorldList or JoinScreen.
var _setup: Control
## A world was asked for: the menu goes in once it is ready.
var _want_play := false
## The player has been in the world: Escape goes back there.
var _entered := false
var _fading := false
var _shown := false
var _fit_for := Rect2()
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
## When the world was ready (msec of the clock, -1 before): SETTLE_MAX goes by real
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


func _init(g) -> void:
	game = g


func _ready() -> void:
	theme = UiStyle.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = Control.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_sky)
	add_child(_backdrop)
	_motion = Control.new()
	_motion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motion.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_motion.draw.connect(_draw_motion)
	_backdrop.add_child(_motion)
	_screen = Control.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.draw.connect(_draw_focus)
	add_child(_screen)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	_screen.add_child(_column)
	var title := UiStyle.label("SURVIVIUM", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var glint := ShaderMaterial.new()
	glint.shader = Shader.new()
	glint.shader.code = GLINT_SHADER
	title.material = glint
	_column.add_child(title)
	_title = title
	_sparrow = Control.new()
	_sparrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparrow.draw.connect(_draw_sparrow)
	if AiRules.SPECIES.has(SPARROW):
		_sparrow_picture = Creatures.picture(AiRules.SPECIES[SPARROW])
		_sparrow_frames = AiRules.SPECIES[SPARROW].frames
	title.add_child(_sparrow)
	_seed_label = UiStyle.label("", UiStyle.INK)
	_seed_label.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	_seed_label.add_theme_constant_override("outline_size", 4)
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_seed_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	_column.add_child(gap)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	panel.add_child(_box)
	_fill_page("top")

	_build_loading()
	visible = false
	_screen.visible = false


## The loading card: the map around the start in a frame like the minimap's with the
## seed over it, the tip right under it (as tall as the longest tip, the words from its
## top, so neither moves as they change), and the strip with the cancel button at the bottom.
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
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_TOP
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
	on.draw_string(f, Vector2(STRIP_PAD, y) + shift, _strip_top, HORIZONTAL_ALIGNMENT_LEFT, inside,
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
	var left := "%d с" % floori(seconds)
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


## The buttons of `page` in the panel, the one to press first lit (and the keyboard on
## it).
func _fill_page(page: String) -> void:
	_page = page
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_buttons.clear()
	_order.clear()
	_note = null
	var joined: bool = game.join_url != ""
	var on_server: bool = joined and not game.welcome.is_empty() and game.join_error == ""
	var lit := ""
	match page:
		"top":
			if game.hosted != null:
				# Its bundles are the server's while it runs.
				_add_button(_box, "single", "Одиночная игра", Callable(), "сервер")
			else:
				_add_button(_box, "single", "Одиночная игра", _fill_page.bind("single"))
			_add_button(_box, "multi", "Мультиплеер", _fill_page.bind("multi"))
			_add_button(_box, "editor", "Редактор", Callable(), "скоро")
			_add_button(_box, "settings", "Настройки", _open_settings)
			if OS.has_feature("web"):
				_add_button(_box, "quit", "Выход", Callable(), "вкладка")
				_buttons.quit.tooltip_text = "В браузере игра закрывается вместе с вкладкой"
			else:
				_add_button(_box, "quit", "Выход", func() -> void:
					game.save.flush()
					get_tree().quit())
			lit = "multi" if joined or game.hosted != null else "single"
		"single":
			_caption("Одиночная игра")
			_add_button(_box, "play", "Продолжить" if game.save.has_save else "Играть", _play_single)
			_add_button(_box, "new", "Новый мир", _new_world)
			_add_button(_box, "worlds", "Миры", _open_worlds)
			_add_button(_box, "back", "Назад", _fill_page.bind("top"))
			lit = "play"
		"multi":
			_caption("Мультиплеер")
			var hosting: bool = game.hosted != null
			if on_server:
				_add_button(_box, "server", "Вернуться на сервер", play.bind("multi"))
				if not hosting:
					_add_button(_box, "leave", "Отключиться", func() -> void:
						game.leave_server()
						game.restart.call_deferred(false))
			if hosting:
				_add_button(_box, "join", "Присоединиться", Callable(), "сервер")
			else:
				_add_button(_box, "join", "Присоединиться", open_join.bind(""))
			if host_here:
				_add_button(_box, "host", "Сервер работает" if hosting else "Создать сервер", open_host)
			else:
				# Not here, but it says where it is.
				_add_button(_box, "host", "Создать сервер", _host_elsewhere, "на ПК")
				_buttons.host.add_theme_color_override("font_color", Color(UiStyle.MUTED, 0.6))
				_buttons.host.add_theme_color_override("font_hover_color", Color(UiStyle.MUTED, 0.8))
			_add_button(_box, "back", "Назад", _fill_page.bind("top"))
			lit = "server" if on_server else ("host" if hosting else "join")
	UiStyle.accent(_buttons[lit])
	_buttons[lit].add_theme_color_override("font_focus_color", UiStyle.DARK_INK)
	_set_focus(_order.find(lit))
	if is_open:
		_fit()
		# Laid out in two frames: then the page says where its buttons are.
		_announce = 2


## The page's name over its buttons.
func _caption(text: String) -> void:
	var l := UiStyle.label(text, UiStyle.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(l)


## «Создать сервер» away from a computer: where it is, under the buttons.
func _host_elsewhere() -> void:
	if _note != null:
		return
	_note = UiStyle.label("Сервер запускают на компьютере: Survivium для Windows или Linux. "
		+ "С телефона и из браузера к нему присоединяются.", UiStyle.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(_note)
	_fit()


func _add_button(parent: Node, key: String, text: String, action: Callable, tag := "") -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(WIDTH, BUTTON_H)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if action.is_valid():
		b.pressed.connect(action)
		b.mouse_entered.connect(func() -> void: _set_focus(_order.find(key)))
		_order.append(key)
	else:
		b.disabled = true
	if tag != "":
		# What the disabled button waits for, at its right edge.
		var l := UiStyle.label(tag, Color(UiStyle.MUTED, 0.6))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.offset_right = -10
		l.offset_bottom = -2
		b.add_child(l)
	parent.add_child(b)
	_buttons[key] = b


## Shows the menu over the game and hides the game's interface.
func open() -> void:
	is_open = true
	visible = true
	_screen.visible = true
	_want_play = false
	_show_loading(false)
	var test: bool = game.world_seed == WorldStore.TEST_SEED
	_seed_label.text = "тестовый мир" if test else "мир · зерно %d" % game.world_seed
	var sky: Variant = game.save.meta.get("sky")
	if game.clock.gen != null:
		_seed_label.text += " · день %d" % game.clock.day
	elif game.save.has_save and sky is Dictionary and sky.has("day"):
		# Read from the save: the world is not loaded yet.
		_seed_label.text += " · день %d" % int(sky.day)
	_map_seed.text = "тестовый мир" if test else "зерно %d" % game.world_seed
	if game.join_url != "":
		_seed_label.text = "сетевая игра · " + load(JOIN_SCREEN)._short(game.join_url)
		_map_seed.text = load(JOIN_SCREEN)._short(game.join_url)
	game.hud.visible = false
	_fill_page("top")
	_fit()
	opened.emit()


func close() -> void:
	if is_open:
		# The browser test waits for this line before it looks at the game's screen.
		print("main menu closed")
		StartTimes.mark("play")
	is_open = false
	_want_play = false
	_entered = true
	back_to = ""
	_show_loading(false)
	_screen.visible = false
	if _setup != null:
		_setup.queue_free()
		_setup = null
	if _settings != null:
		_settings.visible = false
	game.hud.visible = true
	visible = _backdrop.visible
	closed.emit()


## The painted landscape covers the whole window (see _draw_sky): nothing of the world
## shows.
func hides_world() -> bool:
	return _backdrop.visible and not _fading


## «Играть» of «Одиночная игра»: the world of this scene, or, joined to a server, this
## device's world by a restart that loads it at once.
func _play_single() -> void:
	if game.join_url != "":
		back_to = "single"
		game.leave_server()
		game.restart.call_deferred()
	else:
		play("single")


## Into the world: at once when it is ready, else the loading screen until it is (the
## world loaded first if it was not asked for yet); cancelling goes back to the page
## `from` (see back_to).
func play(from := "single") -> void:
	if settled:
		close()
		return
	back_to = from
	_want_play = true
	_show_loading(true)
	game.begin_world()


## The loading screen in place of the menu (`on`), or the menu back.
func _show_loading(on: bool) -> void:
	if on and not loading:
		_load_at = Time.get_ticks_msec()
		_part_at.clear()
		_shares = StartTimes.part_shares(PARTS)
		_progress = 0.0
		_phase_shown = ""
		_tip_clock = 0.0
		_tip.text = ""
		_tips_left.clear()
		if _setup != null:
			_setup.queue_free()
			_setup = null
		if _settings != null:
			_settings.visible = false
	loading = on
	_loading.visible = on
	_column.visible = not on and _setup == null and (_settings == null or not _settings.visible)
	if on:
		_fit()


## The cancel button (or Escape) on the loading screen: the scene starts again without a world
## (Main.cancel_loading), on the page the loading was asked from (go_back).
func cancel_loading() -> void:
	if not loading:
		return
	print("loading cancelled")
	game.cancel_loading()


## Opens the page the last loading was asked from (see back_to), after a cancel.
func go_back() -> void:
	var page := back_to
	back_to = ""
	match page:
		"single", "multi":
			_fill_page(page)
		"worlds":
			_fill_page("single")
			_open_worlds()


## The menu opened on the new world's setup (from the death screen).
func new_world() -> void:
	open()
	_new_world()


func _new_world() -> void:
	_show_screen(WORLD_SETUP, [game])
	_setup.cancelled.connect(_close_setup)
	_setup.done.connect(func() -> void:
		_close_setup()
		_go_to(game.settings.values.world_seed, game.settings.world_options(), "single"))


## Into the world of `seed_value` and `options`: the one this scene was started for at
## once, any other by a restart that loads it (from its save if it has one); cancelling
## goes back to `from`.
func _go_to(seed_value: int, options: Dictionary, from: String) -> void:
	if seed_value == game.world_seed and options == game.world_options and game.join_url == "":
		play(from)
	else:
		back_to = from
		game.save.switch_world(seed_value, options)
		game.leave_server()
		game.restart.call_deferred()


func _open_worlds() -> void:
	_show_screen(WORLD_LIST, [game])
	_setup.cancelled.connect(_close_setup)
	_setup.chosen.connect(func(seed_value: int, options: Dictionary) -> void:
		_close_setup()
		_go_to(seed_value, options, "worlds"))


## «Присоединиться» over the menu, the address `url` in its field (the last server's
## when ""), `error` saying why joining failed.
func open_join(url: String, error := "") -> void:
	_page = "multi"
	_show_screen(JOIN_SCREEN, [game, url, error])
	_setup.cancelled.connect(func() -> void:
		_close_setup()
		_fill_page("multi"))
	_setup.chosen.connect(func(address: String, name: String, password: String) -> void:
		back_to = "multi"
		game.join_server(address, name, password))


## «Создать сервер» over the menu: its settings, or the server running.
func open_host() -> void:
	_page = "multi"
	_show_screen(HOST_SCREEN, [game])
	_setup.cancelled.connect(func() -> void:
		_close_setup()
		_fill_page("multi"))
	_setup.play.connect(func() -> void:
		_close_setup()
		play("multi"))


## Joining the server failed, or the connection to it was lost: the menu opens on
## «Присоединиться» saying why.
func join_failed(why: String) -> void:
	open()
	_fill_page("multi")
	open_join(game.join_url, why)


## Puts the screen of script `path`, made with `args`, over the menu in place of the
## column and of any screen up before it; the caller connects its signals to _setup.
func _show_screen(path: String, args: Array) -> void:
	if _setup != null:
		_setup.queue_free()
	_column.visible = false
	_setup = load(path).new.callv(args)
	_screen.add_child(_setup)


func _close_setup() -> void:
	if _setup != null:
		_setup.queue_free()
		_setup = null
	_column.visible = not loading
	_fit()


func _open_settings() -> void:
	_column.visible = false
	settings_menu().open("settings")
	_settings.fit(_screen.size)


## The settings over the menu, made the first time they are asked for.
func settings_menu() -> Control:
	if _settings == null:
		_settings = load(SETTINGS_MENU).new(game)
		_settings.closed.connect(func() -> void:
			_column.visible = not loading
			_fit())
		_screen.add_child(_settings)
	return _settings


func _process(delta: float) -> void:
	_settle()
	var hud: Control = game.hud
	var rect := Rect2(hud.position, hud.size * hud.scale)
	if rect != _fit_for or scale != hud.scale:
		_fit()
	if _backdrop.visible:
		_time += delta
		_update_sky()
		_motion.queue_redraw()
	if settled and _backdrop.visible and not _fading and (not is_open or _want_play):
		_fading = true
		var tw := _backdrop.create_tween()
		tw.tween_property(_backdrop, "modulate:a", 0.0, FADE)
		tw.tween_callback(func() -> void:
			_backdrop.visible = false
			visible = is_open)
	if not is_open:
		return
	_update_loading(delta)
	if _column.visible:
		_move_sparrow(delta)
		_title.material.set_shader_parameter("glint", fmod(_time, GLINT_EVERY) * 120.0 - 20.0)
	if settled and _want_play:
		_keep_part_times()
		close()
		return
	if _announce > 0:
		_announce -= 1
		if _announce == 0 and _page != "top" and _column.is_visible_in_tree():
			var rects := []
			for k: String in _order:
				rects.append("%s %s" % [k, _buttons[k].get_global_rect()])
			print("menu page %s: %s" % [_page, ", ".join(rects)])
	if not _shown and _column.is_visible_in_tree():
		# Laid out by now; the browser test taps the buttons from this line.
		_shown = true
		StartTimes.mark("menu")
		print("main menu shown: single %s, multi %s" % [_buttons.single.get_global_rect(), _buttons.multi.get_global_rect()])
	_screen.queue_redraw()


## Counts the calm frames once the world is ready (see CALM_FRAMES).
func _settle() -> void:
	if settled or not game.ready_to_play or shown_progress >= 0.0:
		return
	if _ready_at < 0:
		_ready_at = Time.get_ticks_msec()
	var delta := get_process_delta_time()
	_calm = _calm + 1 if game.warmup == null and delta < CALM_FRAME else 0
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


## The menu's column in the middle of the screen, a little below the centre on a tall
## one; the loading card in the middle, its map as large as fits (none on a very short
## screen).
func _fit() -> void:
	var hud: Control = game.hud
	_fit_for = Rect2(hud.position, hud.size * hud.scale)
	scale = hud.scale
	position = hud.position
	size = hud.size
	_screen.size = size
	_backdrop.size = size
	_backdrop.queue_redraw()
	_column.reset_size()
	var c := _column.size
	var low := 0.5 if size.x >= size.y * 1.2 else 0.55
	_column.position = Vector2((size.x - c.x) * 0.5, maxf(MARGIN, (size.y - c.y) * low)).floor()
	if loading:
		for side: int in MAP_SIZES:
			_set_map_side(side)
			_loading.reset_size()
			if _loading.get_combined_minimum_size().y <= size.y - 2 * MARGIN:
				break
		_loading.reset_size()
		_loading.position = ((size - _loading.size) * 0.5).floor()
	if _settings != null and _settings.visible:
		_settings.fit(size)
	_screen.queue_redraw()


func _set_focus(i: int) -> void:
	if i < 0:
		return
	_focus = posmod(i, _order.size())
	_screen.queue_redraw()


## A small accent arrow left of the button the keyboard is on (not with touch).
func _draw_focus() -> void:
	if game.controls.touch or not _column.visible:
		return
	var b: Button = _buttons[_order[_focus]]
	var at: Vector2 = _screen.get_global_transform().affine_inverse() * b.global_position
	var y := floorf(at.y + b.size.y * 0.5)
	var x := at.x - 10
	for i in 4:
		_screen.draw_rect(Rect2(x + i, y - 3 + i, 1, 7 - 2 * i), UiStyle.ACCENT)


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


## The sparrow sits a while, pecks now and then, and hops along the name, turning
## back at its ends.
func _move_sparrow(delta: float) -> void:
	_bird_left -= delta
	if _bird_do == "hop":
		var t := clampf(1.0 - _bird_left / HOP_TIME, 0.0, 1.0)
		_bird_x = lerpf(_bird_from, _bird_to, t)
	if _bird_left <= 0.0:
		_bird_x = _bird_to if _bird_do == "hop" else _bird_x
		var roll := randf()
		if _bird_do != "hop" and roll < 0.45:
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
	_sparrow.queue_redraw()


## The sparrow's picture size in UI px, one frame.
func _sparrow_size() -> Vector2:
	if _sparrow_picture == null:
		return Vector2.ZERO
	return Vector2(_sparrow_picture.get_width() / _sparrow_frames, _sparrow_picture.get_height()) * BIRD_PX


## The sparrow on the top of the letters: raised in a hop beating its wings, its head
## down when it pecks.
func _draw_sparrow() -> void:
	if _sparrow_picture == null:
		return
	# The top of the capitals of the 32 px font, under the label's own room above them.
	var top := floorf(_title.size.y * 0.5 - TITLE_SIZE * 0.34) - 3.0
	var lift := 0.0
	var frame := 0
	if _bird_do == "hop":
		var t := clampf(1.0 - _bird_left / HOP_TIME, 0.0, 1.0)
		lift = floorf(HOP_HIGH * 4.0 * t * (1.0 - t))
		if _sparrow_frames > 1:
			frame = 1 + int(t * 3.0) % (_sparrow_frames - 1)
	var cell := _sparrow_size() / BIRD_PX
	var at := Vector2(floorf(_bird_x), top - cell.y * BIRD_PX - lift)
	# Facing left is the picture mirrored about its middle.
	if _bird_dir > 0.0:
		_sparrow.draw_set_transform(at, 0.0, Vector2(BIRD_PX, BIRD_PX))
	else:
		_sparrow.draw_set_transform(at + Vector2(cell.x * BIRD_PX, 0.0), 0.0, Vector2(-BIRD_PX, BIRD_PX))
	var x0 := frame * cell.x
	if _bird_do == "peck":
		# The tail and the body stay, the head goes a pixel down.
		_sparrow.draw_texture_rect_region(_sparrow_picture, Rect2(0, 0, SPARROW_HEAD, cell.y),
			Rect2(x0, 0, SPARROW_HEAD, cell.y))
		_sparrow.draw_texture_rect_region(_sparrow_picture, Rect2(SPARROW_HEAD, 1, cell.x - SPARROW_HEAD, cell.y - 1),
			Rect2(x0 + SPARROW_HEAD, 0, cell.x - SPARROW_HEAD, cell.y - 1))
	else:
		_sparrow.draw_texture_rect_region(_sparrow_picture, Rect2(0, 0, cell.x, cell.y), Rect2(x0, 0, cell.x, cell.y))
	_sparrow.draw_set_transform(Vector2.ZERO)


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
	# The birds cross every FLOCK_EVERY s, in a loose V.
	var lap := fmod(_time, FLOCK_EVERY) / 12.0
	if lap < 1.0:
		var bx := full.position.x - 20.0 + lap * (full.size.x + 40.0)
		var by := top + sky_h * 0.35 - lap * sky_h * 0.1
		for k in 3:
			var p := Vector2(floorf(bx - k * 16.0), floorf(by + (k % 2) * 10.0 + k * 3.0))
			var up := int(_time * 6.0 + k) % 2 == 0
			var dy := -1.0 if up else 1.0
			for q in [Vector2(-2, dy), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(2, dy)]:
				_motion.draw_rect(Rect2(p + q * FLOCK_PX, Vector2.ONE * FLOCK_PX), BIRD)


## Up and down pick a button, Enter presses it, Escape goes back a page, from the first
## one back into the world; on the loading screen Escape cancels it. Every key stops
## here while the menu is open, so the game behind it gets none.
func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:
		return
	if loading:
		if event.physical_keycode == KEY_ESCAPE:
			cancel_loading()
		return
	if not _column.visible:
		return
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_set_focus(_focus - 1)
		KEY_DOWN, KEY_S:
			_set_focus(_focus + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_buttons[_order[_focus]].pressed.emit()
		KEY_ESCAPE:
			if _page != "top":
				_fill_page("top")
			elif _entered:
				play()
