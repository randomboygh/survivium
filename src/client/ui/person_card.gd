extends PanelContainer
## A small card for teams (decision 50; plan/design/territory-pvp.md): a tap on another
## player opens it by them with their name and what can be done (call them into the
## team, put them out of it when the player leads, or that they are in it already);
## an invitation that comes opens it at the top of the screen with «Принять» and
## «Отказаться». It closes by itself after SHOW_TIME seconds, or by its buttons. `game`
## is the Main node (game.team asks the server); the HUD holds it.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## Seconds the card shows for a tap on a player, and for an invitation.
const SHOW_TIME := 6.0
const INVITE_TIME := 30.0

var game
var _box: VBoxContainer
var _until := 0.0
## The invitations already shown, by who sent them.
var _shown := {}


func _init(g) -> void:
	game = g


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel(Vector4(6, 4, 6, 4)))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 3)
	add_child(_box)
	game.team.changed.connect(_on_team)
	set_process(false)


## Opens the card for player `id` named `name`, by `screen_pos` (screen pixels).
func show_person(id: int, name: String, screen_pos: Vector2) -> void:
	_clear()
	var team = game.team
	var mine := false
	for m: Array in team.view.get("members", []):
		mine = mine or m[0] == id
	_box.add_child(UiStyle.label(name, UiStyle.TEAM if mine else UiStyle.INK))
	if mine and team.leads():
		_button("Исключить из команды", func() -> void: team.kick(id))
	elif mine:
		_box.add_child(UiStyle.label("В вашей команде", UiStyle.MUTED))
	else:
		_button("Позвать в команду", func() -> void:
			team.invite(id)
			game.hud.toast("%s: приглашение отправлено" % name))
	_open(screen_pos, SHOW_TIME)


## An invitation from player `id` named `name`: the card at the top of the screen.
func show_invite(id: int, name: String) -> void:
	_clear()
	_box.add_child(UiStyle.label("%s зовёт вас в команду" % name))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_box.add_child(row)
	_button("Принять", func() -> void: game.team.accept(id), row)
	_button("Отказаться", func() -> void: game.team.decline(id), row)
	var hud: Control = get_parent()
	reset_size()
	_open(Vector2.INF, INVITE_TIME)
	position = Vector2(floorf((hud.size.x - size.x) * 0.5), 34.0)


func _open(screen_pos: Vector2, seconds: float) -> void:
	visible = true
	reset_size()
	if screen_pos.is_finite():
		var hud: Control = get_parent()
		var p := ((screen_pos - hud.position) / hud.scale.x + Vector2(10, -10)).floor()
		position = Vector2(clampf(p.x, 2.0, hud.size.x - size.x - 2.0), clampf(p.y, 2.0, hud.size.y - size.y - 2.0))
	_until = Time.get_ticks_msec() / 1000.0 + seconds
	set_process(true)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() / 1000.0 >= _until:
		close()


func close() -> void:
	visible = false
	set_process(false)


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _button(text: String, action: Callable, parent: Node = null) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 26)
	b.pressed.connect(func() -> void:
		action.call()
		close())
	(parent if parent != null else _box).add_child(b)


## A new invitation opens the card; one gone is forgotten.
func _on_team() -> void:
	var now := {}
	for e: Array in game.team.invites:
		now[e[0]] = true
		if not _shown.has(e[0]):
			show_invite(e[0], str(e[1]))
	_shown = now
