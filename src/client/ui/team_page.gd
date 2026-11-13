extends ScrollContainer
## The tab «Команда» of the inventory window (InventoryWindow; decision 50, plan/design/
## territory-pvp.md), shown only on a server, where teams are (Main.welcome; the user's
## ask 2026-11-02 moved it there from the pause menu): the team's members (the lead
## marked «старший», the player «вы»; the lead's tap on a member puts them out), the
## invitations waiting with «Принять» and «Отказаться», those the player sent still
## waiting for an answer, «Выйти из команды», how to
## call someone in, the server's rule of fighting players and the newcomer's protection
## with «Снять защиту». No title: the tab names it. It follows game.team as it changes,
## scrolls when the screen is lower than it (InventoryWindow sets its height), its rows
## inset as the settings' (UiStyle.inset). `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")
const DragScroll := preload("res://src/client/ui/drag_scroll.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## The least width of its buttons.
const WIDTH := 200

## The server's rule of fighting players, in words (Fights.MODES).
const PVP_TITLES := {"off": "[off_pvp]", "land": "[by_territory_rights]", "all": "[everywhere]"}

var game
var _box: VBoxContainer
## Called when what it shows changed, to lay the window out again.
var on_layout := Callable()


func _init(g) -> void:
	game = g
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The page ends at the window's frame: room under its last line too.
	add_child(UiStyle.inset(_box, UiStyle.BAR_GAP))
	DragScroll.attach(self)


func _ready() -> void:
	game.team.changed.connect(refresh)


## The height the page would take whole.
func full_height() -> float:
	return get_child(0).get_combined_minimum_size().y


## Builds the page again from game.team (when it is shown).
func refresh() -> void:
	if not is_visible_in_tree():
		return
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var team = game.team
	var me := int(game.welcome.get("id", -1))
	for e: Array in team.invites:
		_box.add_child(UiStyle.label(Lang.f("[invites_you_to_their_team]", [e[1]])))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_box.add_child(row)
		_button(row, "[accept]", team.accept.bind(e[0]), "", WIDTH / 2 - 2).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(row, "[decline]", team.decline.bind(e[0]), "", WIDTH / 2 - 2).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if team.has_team():
		for m: Array in team.view.members:
			var tags := []
			if m[0] == me:
				tags.append("[you]")
			if m[0] == team.view.lead:
				tags.append("[leader]")
			var kick := Callable()
			if team.leads() and m[0] != me:
				kick = team.kick.bind(m[0])
				tags.append("[remove]")
			var b := _button(_box, str(m[1]), kick, ", ".join(tags.map(Lang.t)))
			b.add_theme_color_override("font_color", UiStyle.TEAM)
			b.add_theme_color_override("font_disabled_color", UiStyle.TEAM)
		_button(_box, "[leave_the_team]", team.leave)
	elif team.invites.is_empty():
		_box.add_child(UiStyle.label("[you_are_not_in_a]", UiStyle.MUTED))
	for e: Array in team.sent_waiting():
		var who: String = game.others.people[e[0]].label.text if game.others != null and game.others.people.has(e[0]) \
			else Lang.f("[player_n3]", [e[0]])
		_box.add_child(UiStyle.label(Lang.f("[you_invited_waiting_for_an]", [who]), UiStyle.MUTED))
	var hint := UiStyle.label("[to_invite_someone_to_your]", UiStyle.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(hint)
	_box.add_child(UiStyle.label(Lang.line("[pvp_mode]", [PVP_TITLES.get(team.pvp, team.pvp)]), UiStyle.MUTED))
	if team.protected > 0 and team.pvp != "off":
		_box.add_child(UiStyle.label(Lang.f("[newcomer_protection_min_more]", [team.protected]), UiStyle.MUTED))
		_button(_box, "[drop_the_protection]", team.give_up_protection)
	if on_layout.is_valid():
		on_layout.call_deferred()


## A button of the page, `tag` at its right edge; one with no action is disabled.
func _button(parent: Node, text: String, action: Callable, tag := "", width := WIDTH) -> Button:
	var b := Kit.button(text, Callable(), width, 30)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if action.is_valid():
		b.pressed.connect(action)
	else:
		b.disabled = true
	if tag != "":
		var l := UiStyle.label(tag, Color(UiStyle.MUTED, 0.8))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.offset_right = -8
		l.offset_bottom = -2
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
	parent.add_child(b)
	return b
