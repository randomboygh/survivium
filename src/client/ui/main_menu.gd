extends Control
## The main menu (plan/design/ui.md, section 2; plan/architecture/server.md, «Меню и
## экраны»): the first screen, over the live world played last (see SaveGame), which is
## built behind it meanwhile. Its first page: «Одиночная игра», «Мультиплеер»,
## «Редактор», «Настройки», «Выход»; the first two open pages of their own in the same
## panel, with «Назад» at the bottom.
## «Одиночная игра»: "Играть" goes into that world (as soon as it is built),
## "Продолжить" once it has a save; "Новый мир" opens WorldSetup over the menu and
## restarts the game when the world asked for is another one (a world made before comes
## back from its save), "Миры" lists the saved worlds to go back to one or delete it
## (WorldList). Joined to a server, each of them leaves it for a world of this device.
## «Мультиплеер»: «Присоединиться» opens JoinScreen (a link with `?server=` opens it
## at the start, its address filled in; a failed joining opens it again with why),
## «Создать сервер» opens HostScreen on a computer (on a phone or in the browser a tap
## says it is for a computer); joined, «Вернуться на сервер» and «Отключиться» come
## first. While a server made here runs, its button is «Сервер работает», and what
## would load other bundles under it (single player, joining another server,
## disconnecting) waits until it is stopped.
## «Настройки» opens the settings page. The editor is not there yet, so its button is
## disabled, and "Выход" is disabled in the browser. Until the world is built a painted sky
## stands in for it, with clouds drifting, stars blinking, a few birds crossing and a
## glint running over the name, and then fades out. The game's interface is hidden while the menu
## is open; the menu takes the scale and the safe rect the interface was fitted to.
## `game` is the Main node.

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

const WIDTH := 200
const BUTTON_H := 30
const MARGIN := 24
const TITLE_SIZE := 32
## Seconds the painted sky takes to fade once the world is built.
const FADE := 1.2
## The painted sky from the top down to the horizon, and the two ranges of hills.
const SKY := [Color("#22384a"), Color("#2c4a5a"), Color("#3a5d68"), Color("#4f7273"), Color("#6c857a"),
	Color("#93977f"), Color("#b8a383")]
const HILLS := [Color("#35503f"), Color("#263b2f")]
## Cumulus clouds over the painted sky, drawn by tools/make_clouds.py: a row of
## cells CLOUD_CELL pixels, each a cloud on the bottom of its cell, a pixel CLOUD_PX UI
## px as the birds' are. Each one drifting right: the height of its base (share of the
## sky), its cell, UI px a second, where it starts. The far ones high and slow, the near
## ones lower and faster. When the world is built they part to the sides in PART
## seconds, faster and faster, as the painted sky fades behind them.
const CLOUD_SHEET := preload("res://assets/menu_clouds.png")
const CLOUD_CELL := Vector2(80, 40)
const CLOUD_PX := 2.0
const CLOUDS := [[0.10, 5, 1.0, 0.15], [0.14, 9, 1.2, 0.62], [0.20, 3, 1.5, 0.38], [0.26, 7, 1.8, 0.85],
	[0.33, 2, 2.2, 0.05], [0.40, 8, 2.6, 0.5], [0.48, 1, 3.0, 0.28], [0.55, 6, 3.5, 0.72],
	[0.63, 4, 4.0, 0.95], [0.72, 0, 4.6, 0.42], [0.82, 9, 5.2, 0.12], [0.92, 3, 6.0, 0.6],
	[1.02, 8, 7.0, 0.33], [1.12, 0, 8.0, 0.8]]
const PART := FADE
## Stars over the top of the sky (some of them two pixels across), the birds' colour,
## the size of a pixel of them and the seconds between their flights.
const STARS := 24
const BIRD := Color("#14211b")
const FLOCK_PX := CLOUD_PX
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
## While the world is built: the map around the start painted in as its chunks are
## made (the minimap's regions), its side in UI px and UI px a map pixel, and tips
## under it, a new one every TIP_TIME seconds. On a short screen the map is made
## smaller, down the MAP_SIZES, and at 0 the tips are shown alone.
## The sides of the map tried in turn until the card fits: as wide as the menu, then
## smaller, then none (the tips alone).
const MAP_SIZES := [WIDTH - 2 * Minimap.FRAME, 128, 96, 64, 0]
const MAP_ZOOM := 2.0
const TIP_TIME := 6.0
## UI px between the card and the name over it and the menu under it on a tall screen.
const GAP := 16
## The strip keeps a part of the loading this long at least, so a short part does not
## flash by unread (seconds).
const PHASE_HOLD := 1.2
## The progress strip under the map: its height in UI px.
const STRIP_H := 16
## UI px between the strip's edges and its words.
const STRIP_PAD := 5
## After the world is ready the menu waits for the frames to settle before the clouds
## part and the world shows: no shaders being built ahead (see ShaderWarmup) and
## CALM_FRAMES frames in a row under CALM_FRAME seconds, SETTLE_MAX seconds at most.
const CALM_FRAME := 0.05
const CALM_FRAMES := 12
const SETTLE_MAX := 5.0
## Tips under the map while the world is built, each shown once a load in a shuffled
## order (see _next_tip).
const TIPS := [
	"Волокно дают высокая трава, травы и тростник; из трёх волокон скручивают верёвку.",
	"Кремень попадается, когда копаешь землю, песок и осыпь.",
	"Костёр складывают из пяти веток и пяти волокон, на нём жарят грибы.",
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
	"Изношенный инструмент чинят у верстака: каменный — кремнём и верёвкой.",
	"Прыжки, плавание и работа тратят силы, а в покое они возвращаются.",
	"Голодному не восстановить силы полностью: ешьте ягоды, грибы и лепёшки.",
	"С тяжёлой сумкой идёшь медленнее: лишнее можно оставить в сундуке.",
	"Без сил в воде начинаешь тонуть: далеко не заплывайте.",
	"Горящий костёр обжигает и отбрасывает, если подойти вплотную.",
	"После смерти вещи остаются в мешке на месте гибели, он отмечен на карте.",
	"Возвращаешься к жизни у своего костра: поставьте его рядом с домом.",
	"Жёлуди, шишки и семена можно посадить, и из них вырастут деревья и травы.",
	"Траву срезают руками, мечом или косой, и с неё падает волокно.",
	"Камеру можно повернуть кнопками у миникарты и наклонить, чтобы заглянуть за деревья.",
	"В настройках время суток, сезон и погоду можно сделать как в жизни.",
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

var game
## True while the menu takes the screen (the sky may still be fading after that).
var is_open := false
var _screen: Control
var _backdrop: Control
## What moves over the painted sky (see _draw_motion), and seconds it has been moving.
var _motion: Control
## The clouds over the sky and how far (0..1) they have parted, -1 before.
var _clouds: Control
var _part := -1.0
var _time := 0.0
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
## Room left in the column between the name and the menu for the card on a tall screen.
var _card_room: Control
## The seed written over the map.
var _map_seed: Label
var _strip: Control
var _strip_fill: Control
## The words on the strip: the part of the loading at the left, how far at the right.
var _strip_left := ""
var _strip_right := ""
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
## "Играть" was pressed before the world was built: go in once it is.
var _want_play := false
## The player has been in the world: Escape goes back there.
var _entered := false
var _fading := false
var _shown := false
var _fit_for := Rect2()
## The map and the tips while the world is built (see MAP_SIZES), and the tip shown.
var _loading: PanelContainer
var _map_ground: Minimap.Layer
var _map_top: Minimap.Layer
var _tip: Label
## The part of the loading shown on the strip (Main.loading_phase) and for how long.
var _phase_shown := ""
var _phase_clock := 0.0
## The world is ready and its first frames are over (see CALM_FRAMES): the clouds may
## part, «Играть» goes in.
var settled := false
var _calm := 0
var _ready_clock := 0.0
## The tips not shown yet, by index, in the order they come (see _next_tip).
var _tips_left: Array = []
var _tip_clock := 0.0
var _map_room := false
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
	_clouds = Control.new()
	_clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clouds.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clouds.draw.connect(_draw_clouds)
	add_child(_clouds)
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
	_card_room = Control.new()
	_card_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_card_room)
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


## The map around the start in a frame like the minimap's with the seed over it, how
## far the loading has gone under it, a tip in a well at the bottom; as wide as the menu.
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
	_build_strip(box)
	var well := PanelContainer.new()
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiStyle.slot()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, UiStyle.WELL_PAD)
	well.add_theme_stylebox_override("panel", style)
	box.add_child(well)
	_tip = UiStyle.label("", UiStyle.MUTED)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# As tall as the longest tip, so the card keeps its size as they change.
	var width := WIDTH - 2 * UiStyle.WELL_PAD
	var tall := 0.0
	for tip in TIPS:
		var lines := UiStyle.font().get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_CENTER, width,
			UiStyle.FONT_SIZE, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
		tall = maxf(tall, lines.y)
	_tip.custom_minimum_size = Vector2(width, tall)
	well.add_child(_tip)
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


## The column at the middle of the map: where the player starts.
func _map_centre() -> Vector2:
	return Vector2(game.player.position.x, game.player.position.z) / 0.5


func _draw_map(l: Control) -> void:
	game.hud.minimap.draw_ground(l, Rect2(Vector2.ZERO, l.size), _map_centre(), MAP_ZOOM)


## How far the loading has gone (Main.loading_progress) and its words in one strip: an
## amber fill in a sunken slot, the words light over the slot and dark over the fill,
## which a child clipped to the fill draws over the slot.
func _build_strip(box: Control) -> void:
	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.custom_minimum_size = Vector2(WIDTH, STRIP_H)
	_strip.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, _strip.size)
		_strip.draw_rect(r, UiStyle.EDGE)
		_strip.draw_rect(r.grow(-1), Minimap.UNSEEN)
		_strip.draw_rect(Rect2(1, 1, _strip.size.x - 2, 1), UiStyle.WELL_SHADE)
		_strip_words(_strip, UiStyle.INK))
	box.add_child(_strip)
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


## The strip's words, the part at the left and how far at the right; `shift` puts them
## where they are on the strip when drawn by the fill.
func _strip_words(on: Control, color: Color, shift := Vector2.ZERO) -> void:
	var f := UiStyle.font()
	var y := floorf((STRIP_H - f.get_height(UiStyle.FONT_SIZE)) * 0.5) + f.get_ascent(UiStyle.FONT_SIZE)
	var inside := _strip.size.x - 2 * STRIP_PAD
	on.draw_string(f, Vector2(STRIP_PAD, y) + shift, _strip_left, HORIZONTAL_ALIGNMENT_LEFT, inside,
		UiStyle.FONT_SIZE, color)
	on.draw_string(f, Vector2(STRIP_PAD, y) + shift, _strip_right, HORIZONTAL_ALIGNMENT_RIGHT, inside,
		UiStyle.FONT_SIZE, color)


## The part of the loading going on, each kept PHASE_HOLD at least, and how far it has
## gone; the world ready once it has settled.
func _update_strip(delta: float) -> void:
	_phase_clock += delta
	var phase: String = "Мир готов" if settled else game.loading_phase()
	if phase != _phase_shown and (_phase_clock >= PHASE_HOLD or _phase_shown == "" or settled):
		_phase_shown = phase
		_phase_clock = 0.0
	var done := 1.0 if settled else float(game.loading_progress())
	var right := "%d%%" % roundi(100.0 * done)
	var fill := Vector2(floorf((_strip.size.x - 2) * done), _strip.size.y - 2)
	if _phase_shown == _strip_left and right == _strip_right and fill == _strip_fill.size:
		return
	_strip_left = _phase_shown
	_strip_right = right
	_strip_fill.size = fill
	_strip.queue_redraw()
	_strip_fill.queue_redraw()


## The player an amber dot outlined dark in the middle, the slot's shade along the top
## and left as on the minimap.
func _draw_map_top(l: Control) -> void:
	var p := (l.size * 0.5).floor()
	l.draw_rect(Rect2(p - Vector2(3, 3), Vector2(7, 7)), UiStyle.DARK_INK)
	l.draw_rect(Rect2(p - Vector2(2, 2), Vector2(5, 5)), UiStyle.ACCENT)
	l.draw_rect(Rect2(Minimap.CORNER, 0, l.size.x - 2 * Minimap.CORNER, 1), UiStyle.WELL_SHADE)
	l.draw_rect(Rect2(0, Minimap.CORNER, 1, l.size.y - 2 * Minimap.CORNER), UiStyle.WELL_SHADE)


## Shows the card while the menu's column is there (the strip only before the player
## has been in the world), on a tall screen in the room left for it in the column; the
## map is drawn again as the minimap paints chunks in.
func _update_loading(delta: float) -> void:
	var show: bool = _map_room and _column.visible and game.player != null
	if _loading.visible != show:
		_loading.visible = show
		if show:
			_map_ground.queue_redraw()
			if not game.hud.minimap.painted.is_connected(_map_ground.queue_redraw):
				game.hud.minimap.painted.connect(_map_ground.queue_redraw)
	if not show:
		return
	if _card_room.custom_minimum_size.y > 0.0:
		_loading.position = (_column.position + _card_room.position
			+ Vector2((_card_room.size.x - _loading.size.x) * 0.5, 0)).floor()
	_strip.visible = not _entered
	if _strip.visible:
		_update_strip(delta)
	_tip_clock -= delta
	if _tip_clock <= 0.0:
		_tip_clock = TIP_TIME
		_next_tip()


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
				_add_button(_box, "server", "Вернуться на сервер", play)
				if not hosting:
					_add_button(_box, "leave", "Отключиться", func() -> void:
						game.leave_server()
						game.restart.call_deferred())
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
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		_buttons[lit].add_theme_stylebox_override(state, UiStyle.button(state, true))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_buttons[lit].add_theme_color_override(c, UiStyle.DARK_INK)
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
	_column.visible = true
	_want_play = false
	_seed_label.text = "тестовый мир" if game.world_seed == WorldStore.TEST_SEED else "мир · зерно %d" % game.world_seed
	if game.save.has_save:
		_seed_label.text += " · день %d" % game.clock.day
	_map_seed.text = "тестовый мир" if game.world_seed == WorldStore.TEST_SEED else "зерно %d" % game.world_seed
	if game.join_url != "":
		_seed_label.text = "сетевая игра · " + load(JOIN_SCREEN)._short(game.join_url)
		_map_seed.text = load(JOIN_SCREEN)._short(game.join_url)
	_strip.visible = not _entered
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
	_screen.visible = false
	if _setup != null:
		_setup.queue_free()
		_setup = null
	if _settings != null:
		_settings.visible = false
	game.hud.visible = true
	visible = _backdrop.visible
	closed.emit()


## The painted sky covers the whole window (see _draw_sky): nothing of the world shows.
func hides_world() -> bool:
	return _backdrop.visible and not _fading


## «Играть» of «Одиночная игра»: into the world behind the menu, or, joined to a
## server, back to this device's world by a restart.
func _play_single() -> void:
	if game.join_url != "":
		game.leave_server()
		game.restart.call_deferred()
	else:
		play()


## "Играть": into the world now, or as soon as it is built.
func play() -> void:
	if settled:
		close()
	else:
		_want_play = true


## The menu opened on the new world's setup (from the death screen).
func new_world() -> void:
	open()
	_new_world()


func _new_world() -> void:
	_column.visible = false
	_setup = load(WORLD_SETUP).new(game)
	_screen.add_child(_setup)
	_setup.cancelled.connect(_close_setup)
	_setup.done.connect(func() -> void:
		_close_setup()
		# The world behind the menu is the one asked for: just go in.
		_go_to(game.settings.values.world_seed, game.settings.world_options()))


## Into the world of `seed_value` and `options`: the one behind the menu at once, any
## other by a restart (from its save if it has one).
func _go_to(seed_value: int, options: Dictionary) -> void:
	if seed_value == game.world_seed and options == game.world_options and game.join_url == "":
		play()
	else:
		game.save.switch_world(seed_value, options)
		game.leave_server()
		game.restart.call_deferred()


func _open_worlds() -> void:
	_column.visible = false
	_setup = load(WORLD_LIST).new(game)
	_screen.add_child(_setup)
	_setup.cancelled.connect(_close_setup)
	_setup.chosen.connect(func(seed_value: int, options: Dictionary) -> void:
		_close_setup()
		_go_to(seed_value, options))


## «Присоединиться» over the menu, the address `url` in its field (the last server's
## when ""), `error` saying why joining failed.
func open_join(url: String, error := "") -> void:
	if _setup != null:
		_setup.queue_free()
	_page = "multi"
	_column.visible = false
	_setup = load(JOIN_SCREEN).new(game, url, error)
	_screen.add_child(_setup)
	_setup.cancelled.connect(func() -> void:
		_close_setup()
		_fill_page("multi"))
	_setup.chosen.connect(func(address: String, name: String, password: String) -> void:
		game.join_server(address, name, password))


## «Создать сервер» over the menu: its settings, or the server running.
func open_host() -> void:
	if _setup != null:
		_setup.queue_free()
	_page = "multi"
	_column.visible = false
	_setup = load(HOST_SCREEN).new(game)
	_screen.add_child(_setup)
	_setup.cancelled.connect(func() -> void:
		_close_setup()
		_fill_page("multi"))
	_setup.play.connect(func() -> void:
		_close_setup()
		play())


## Joining the server failed, or the connection to it was lost: the menu opens on
## «Присоединиться» saying why.
func join_failed(why: String) -> void:
	if not is_open:
		open()
	_fill_page("multi")
	open_join(game.join_url, why)


func _close_setup() -> void:
	if _setup != null:
		_setup.queue_free()
		_setup = null
	_column.visible = true
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
			_column.visible = true
			_fit())
		_screen.add_child(_settings)
	return _settings


func _process(delta: float) -> void:
	_settle(delta)
	var hud: Control = game.hud
	var rect := Rect2(hud.position, hud.size * hud.scale)
	if rect != _fit_for or scale != hud.scale:
		_fit()
	if _backdrop.visible or _clouds.visible:
		_time += delta
		_motion.queue_redraw()
		_clouds.queue_redraw()
	if _part >= 0.0 and _clouds.visible:
		_part = minf(_part + delta / PART, 1.0)
		if _part >= 1.0:
			_clouds.visible = false
		# The glint runs while the world is being built.
		var at := fmod(_time, GLINT_EVERY) * 120.0 - 20.0
		_title.material.set_shader_parameter("glint", at if not settled else -1000.0)
	if settled and _backdrop.visible and not _fading:
		_fading = true
		_part = 0.0
		var tw := _backdrop.create_tween()
		tw.tween_property(_backdrop, "modulate:a", 0.0, FADE)
		tw.tween_callback(func() -> void:
			_backdrop.visible = false
			visible = is_open)
	if not is_open:
		_loading.visible = false
		return
	_update_loading(delta)
	_move_sparrow(delta)
	if settled and _want_play:
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
func _settle(delta: float) -> void:
	if settled or not game.ready_to_play:
		return
	_ready_clock += delta
	_calm = _calm + 1 if game.warmup == null and delta < CALM_FRAME else 0
	settled = _calm >= CALM_FRAMES or _ready_clock >= SETTLE_MAX


## The card's map as large as fits: on a wide screen in the room right of the column,
## on a tall one in the column between the name and the menu (the seed then goes from
## under the name onto the map); smaller where it does not fit, then the tips alone,
## and left out where even they do not fit.
func _place_loading() -> void:
	var wide := size.x >= size.y * 1.2
	_map_room = false
	for side in MAP_SIZES:
		_set_map_side(side)
		_seed_label.visible = side == 0
		_card_room.custom_minimum_size.y = 0.0
		_loading.reset_size()
		var card := _loading.get_combined_minimum_size()
		var col := _column.get_combined_minimum_size()
		if wide:
			_map_room = size.x - MARGIN - col.x >= card.x + 2 * MARGIN and card.y <= size.y - 2 * MARGIN
		elif col.y + card.y + 2 * GAP - 12 <= size.y - 2 * MARGIN:
			# The column's separations (6 each side) make up a part of the gaps.
			_map_room = true
			_card_room.custom_minimum_size.y = card.y + GAP - 6
		if _map_room:
			break
	if not _map_room:
		_seed_label.visible = true
		_loading.visible = false
	_loading.reset_size()


## The interface's scale and rect: the column on the left of a wide screen, in the
## middle of a tall one, below the centre.
func _fit() -> void:
	var hud: Control = game.hud
	_fit_for = Rect2(hud.position, hud.size * hud.scale)
	scale = hud.scale
	position = hud.position
	size = hud.size
	_screen.size = size
	_backdrop.size = size
	_backdrop.queue_redraw()
	_place_loading()
	_column.reset_size()
	var c := _column.size
	if size.x >= size.y * 1.2:
		_column.position = Vector2(MARGIN, (size.y - c.y) * 0.5).floor()
		var room := size.x - _column.position.x - c.x
		_loading.position = Vector2(_column.position.x + c.x + (room - _loading.size.x) * 0.5,
			(size.y - _loading.size.y) * 0.5).floor()
	else:
		var low := 0.5 if _map_room else 0.55
		_column.position = Vector2((size.x - c.x) * 0.5, maxf(MARGIN, (size.y - c.y) * low)).floor()
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


## The painted sky until the world is built: bands down to the horizon with a row of
## dithered pixels between them, then two ranges of hills. It covers the whole window,
## past the safe rect.
func _draw_sky() -> void:
	var s: float = scale.x
	var full := Rect2(-position / s, get_viewport_rect().size / s).grow(2)
	var top := full.position.y
	var horizon := top + full.size.y * 0.62
	var band := (horizon - top) / SKY.size()
	for i in SKY.size():
		var y0 := floorf(top + i * band)
		_backdrop.draw_rect(Rect2(full.position.x, y0, full.size.x, ceilf(band) + 1), SKY[i])
		if i > 0:
			# Every other pixel of the band above, along the seam.
			for x in range(int(full.position.x), int(full.end.x), 2):
				_backdrop.draw_rect(Rect2(x, y0, 1, 1), SKY[i - 1])
	_backdrop.draw_rect(Rect2(full.position.x, horizon, full.size.x, full.end.y - horizon), SKY[SKY.size() - 1])
	for h in HILLS.size():
		var base := horizon + (h + 1) * full.size.y * 0.1
		var x := int(full.position.x)
		while x < int(full.end.x):
			var t := float(x) * (0.012 + h * 0.008) + h * 2.0
			var y := floorf(base - (sin(t) * 0.6 + sin(t * 2.3 + 1.0) * 0.3 + 1.0) * full.size.y * (0.06 - h * 0.015))
			_backdrop.draw_rect(Rect2(x, y, 2, full.end.y - y), HILLS[h])
			x += 2


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


## The clouds drifting right at their own pace, each to its side of the screen as
## they part (see PART).
func _draw_clouds() -> void:
	var s: float = scale.x
	var full := Rect2(-position / s, get_viewport_rect().size / s).grow(2)
	var sky_h := full.size.y * 0.62
	var size := CLOUD_CELL * CLOUD_PX
	var span := full.size.x + size.x
	var away := maxf(_part, 0.0)
	away = away * away * away * (full.size.x * 0.5 + size.x)
	for i in CLOUDS.size():
		var c: Array = CLOUDS[i]
		var x := full.position.x + fposmod(c[3] * span + _time * c[2], span) - size.x
		var side := signf(x + size.x * 0.5 - full.get_center().x)
		if side == 0.0:
			side = 1.0 if i % 2 == 0 else -1.0
		var at := Vector2(x + side * away, full.position.y + sky_h * c[0] - size.y).floor()
		var cell := Rect2(Vector2(c[1] * CLOUD_CELL.x, 0.0), CLOUD_CELL)
		_clouds.draw_texture_rect_region(CLOUD_SHEET, Rect2(at, size), cell)


## The sky's moving parts, over the painted sky: stars blinking at the top and three
## birds flapping across now and then.
func _draw_motion() -> void:
	var s: float = scale.x
	var full := Rect2(-position / s, get_viewport_rect().size / s).grow(2)
	var top := full.position.y
	var sky_h := full.size.y * 0.62
	for i in STARS:
		var h := absi(hash(i * 7919))
		var sx := full.position.x + float(h % 1000) / 1000.0 * full.size.x
		var sy := top + float((h >> 10) % 1000) / 1000.0 * sky_h * 0.3
		var blink := 0.5 + 0.5 * sin(_time * (1.0 + (h % 5) * 0.4) + i)
		var px := 2.0 if h % 3 == 0 else 1.0
		_motion.draw_rect(Rect2(floorf(sx), floorf(sy), px, px), Color(1.0, 0.96, 0.82, 0.45 + 0.55 * blink))
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
## one back into the world. Every
## key stops here while the menu is open, so the game behind it gets none.
func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo or not _column.visible:
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
