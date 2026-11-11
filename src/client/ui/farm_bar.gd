extends "res://src/client/ui/build_bar.gd"
## The farming mode's bar (FarmMode), in the hotbar's place while the mode is on, made
## as the build mode's (BuildBar): on top the panel in one row, the work (till, sow,
## water, reap) and the shape of a stroke (a line, a filled square), drawing or taking
## off the marks joined with taking all of them off near (a second tap to confirm), on a
## PC the action button's work (F), and leaving the mode; under it the palette of what the bag holds to sow and plant, as the
## hotbar (no filters for now). `game` is the Main node.

const WORKS := {"till": ["farm_till", "[till_beds_with_a_hoe]"],
	"sow": ["farm_sow", "[sow_or_plant_the_selected]"], "water": ["farm_water", "[water_the_beds_with_a]"],
	"reap": ["farm_reap", "[harvest_with_a_sickle_or]"]}
const FARM_SHAPES := {"line": ["farm_line", "[line_n2]"], "square": ["farm_square", "[square_the_whole_area]"]}

var _work: Button
var _farm_shape: Button


func _init(g) -> void:
	super(g, g.farm)


func _make_panel(panel: HBoxContainer) -> void:
	var works := TabRow.split([
		[UiStyle.icon("farm_sow"), "", func() -> void: mode.next_work()],
		[UiStyle.icon("farm_line"), "", func() -> void: mode.next_shape()],
	])
	_work = works.get_child(0)
	_farm_shape = works.get_child(1)
	panel.add_child(works)
	var marks := TabRow.split([
		[UiStyle.icon("build_draw"), "", func() -> void: mode.set_erasing(not mode.erasing)],
		[UiStyle.icon("trash"), "[remove_all_marking_nearby_press]", _tap_clear],
	])
	_mode = marks.get_child(0)
	_clear = marks.get_child(1)
	panel.add_child(marks)
	_add_go(panel)
	var leave := TabRow.icon_button(UiStyle.icon("close"), "[leave_farming_mode_b]", func() -> void: mode.leave())
	panel.add_child(leave)
	for b: Button in [_work, _farm_shape, _mode, _clear, leave]:
		b.custom_minimum_size = Vector2(BUTTON, BUTTON)


func _wide_group() -> Control:
	return null


func _show_panel() -> void:
	var f = mode
	var w: Array = WORKS[f.work]
	_work.icon = UiStyle.centred(UiStyle.icon(w[0]))
	_work.tooltip_text = Lang.f("[press_for_the_next_job]", [w[1]])
	var s: Array = FARM_SHAPES[f.shape]
	_farm_shape.icon = UiStyle.centred(UiStyle.icon(s[0]))
	_farm_shape.tooltip_text = Lang.f("[press_for_another_shape]", [s[1]])
	_mode.icon = UiStyle.centred(UiStyle.icon("build_erase" if f.erasing else "build_draw"))
	_mode.tooltip_text = "[erasing_the_marking_press_to]" if f.erasing else "[drawing_the_marking_press_to]"
	TabRow.light(_mode, f.erasing, f.erasing)
	var confirming := _clear_at > 0 and Time.get_ticks_msec() - _clear_at < CONFIRM_MS
	TabRow.light(_clear, confirming, confirming)
	_show_go()


func _go_tip() -> String:
	return "[do_all_the_marked_work]"


func _nothing() -> String:
	return "[nothing_to_plant_no_seeds]"


func _clear_ask() -> String:
	return "[press_again_to_remove_all_n2]"
