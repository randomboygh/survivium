extends "res://src/client/ui/build_bar.gd"
## The farming mode's bar (FarmMode), in the hotbar's place while the mode is on, made
## as the build mode's (BuildBar): on top the panel in one row, the work (till, sow,
## water, reap) and the shape of a stroke (a line, a filled square), the palette's
## filter (all, seeds, bushes), drawing or taking off the marks joined with taking all
## of them off near (a second tap to confirm), and leaving the mode; under it the
## palette of what the bag holds to sow and plant. `game` is the Main node.

const WORKS := {"till": ["farm_till", "Вскопать грядки (тяпкой из сумки)"],
	"sow": ["farm_sow", "Посеять или посадить выбранное"], "water": ["farm_water", "Полить грядки (лейкой с водой)"],
	"reap": ["farm_reap", "Собрать урожай (серпом или руками)"]}
const FARM_SHAPES := {"line": ["farm_line", "Линия"], "square": ["farm_square", "Квадрат: вся площадь"]}
const FILTER_ICONS := {"all": ["filter_all", "Все семена и кусты"], "seeds": ["filter_seeds", "Только семена"],
	"bushes": ["filter_bushes", "Только кусты"]}

var _work: Button
var _farm_shape: Button
var _filter: Button


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
	_filter = TabRow.icon_button(UiStyle.icon("filter_all"), "", func() -> void: mode.next_filter())
	panel.add_child(_filter)
	var marks := TabRow.split([
		[UiStyle.icon("build_draw"), "", func() -> void: mode.set_erasing(not mode.erasing)],
		[UiStyle.icon("trash"), "Убрать всю разметку рядом (нажать дважды)", _tap_clear],
	])
	_mode = marks.get_child(0)
	_clear = marks.get_child(1)
	panel.add_child(marks)
	var leave := TabRow.icon_button(UiStyle.icon("close"), "Выйти из режима земледелия (B)", func() -> void: mode.leave())
	panel.add_child(leave)
	for b: Button in [_work, _farm_shape, _filter, _mode, _clear, leave]:
		b.custom_minimum_size = Vector2(BUTTON, BUTTON)


func _wide_group() -> Control:
	return null


func _show_panel() -> void:
	var f = mode
	var w: Array = WORKS[f.work]
	_work.icon = UiStyle.centred(UiStyle.icon(w[0]))
	_work.tooltip_text = w[1] + " (нажать — следующая работа)"
	var s: Array = FARM_SHAPES[f.shape]
	_farm_shape.icon = UiStyle.centred(UiStyle.icon(s[0]))
	_farm_shape.tooltip_text = s[1] + " (нажать — другая фигура)"
	var k: Array = FILTER_ICONS[f.filter]
	_filter.icon = UiStyle.centred(UiStyle.icon(k[0]))
	_filter.tooltip_text = k[1] + " (нажать — следующий фильтр)"
	_mode.icon = UiStyle.centred(UiStyle.icon("build_erase" if f.erasing else "build_draw"))
	_mode.tooltip_text = "Стирать разметку (нажать — рисовать)" if f.erasing else "Рисовать разметку (нажать — стирать)"
	TabRow.light(_mode, f.erasing, f.erasing)
	var confirming := _clear_at > 0 and Time.get_ticks_msec() - _clear_at < CONFIRM_MS
	TabRow.light(_clear, confirming, confirming)


func _nothing() -> String:
	return "Нечего сажать: нет семян и кустов"


func _clear_ask() -> String:
	return "Нажмите ещё раз, чтобы убрать всю разметку рядом"
