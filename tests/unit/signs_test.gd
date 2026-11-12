extends "res://tests/unit/test_case.gd"
## Signs (decision 183): set down, written, turned and saved; the text cut to the sign's
## lines and letters and made safe; a board hangs only on a wall, its back to it; taken
## up, a sign keeps its words in the bag, on the ground and in a save, and says them set down again.


func run() -> void:
	_test_text()
	_test_write_and_turn()
	_test_wall()
	_test_taken_up()


func _flat() -> WorldData:
	var w := WorldData.new(40, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
	return w


func _placed(w: WorldData) -> Placed:
	var placed := Placed.new()
	placed.world = w
	placed.read_footprints()
	return placed


func _test_text() -> void:
	_check(Placed.sign_text("tools:sign", "раз\nдва\nтри\nчетыре") == "раз\nдва\nтри", "a sign keeps its three lines, no more")
	_check(Placed.sign_text("tools:sign", "x".repeat(50)) == "x".repeat(20), "a line is cut to the sign's width")
	_check(Placed.sign_text("tools:sign", "a\u202eb\tc\n\n\n") == "ab c", "marks that turn text around go, a tab is a space, empty lines at the end go")
	_check(Placed.sign_text("tools:notice_board", "1\n2\n3\n4\n5\n6\n7").split("\n").size() == 6, "a board keeps six")
	_check(Placed.sign_text("tools:sign", "\n\nниз") == "\n\nниз", "empty lines before text stay")


func _test_write_and_turn() -> void:
	var w := _flat()
	var placed := _placed(w)
	var who := Who.new()
	who.position = Vector3(10.5, 1.0, 12.5) * WorldData.CELL
	who.inventory.add("tools:signpost", 1)
	_check(placed.put_at(who, "tools:signpost", Vector3i(10, 1, 10), 40), "a signpost is set down")
	var e: Dictionary = placed.things[-1]
	_check(Placed.is_sign(e) and Placed.is_part(e) and e.get("text", "x") == "", "a sign, a part of a house, blank")
	var heard := []
	placed.added.connect(func(x: Dictionary) -> void: heard.append(x))
	_check(placed.write(who, e, "К озеру\nидти долго\nи ещё"), "written")
	e = placed.at(e.cell)
	_check(e.text == "К озеру\nидти долго" and heard.size() == 1, "two lines kept, the copies hear of it as a thing set down: %s" % [e.text])
	var turn: int = e.turn
	_check(placed.turn_sign(who, e), "turned")
	e = placed.at(e.cell)
	_check(e.turn == (turn + 1) % 4 and e.text == "К озеру\nидти долго", "a quarter on, the text kept")
	var again := _placed(w)
	again.from_list(placed.to_list())
	_check(again.things.size() == 1 and again.things[0].text == e.text and again.things[0].turn == e.turn, "saved and loaded with its text")


func _test_wall() -> void:
	var w := _flat()
	for x in range(8, 13):
		for y in range(1, 4):
			w.set_cell(x, y, 9, Mat.STONE)
	var placed := _placed(w)
	var who := Who.new()
	who.position = Vector3(20.5, 1.0, 22.5) * WorldData.CELL
	who.inventory.add("tools:notice_board", 2)
	_check(not placed.put_at(who, "tools:notice_board", Vector3i(20, 1, 20), 40), "a board is not set down on open ground")
	who.position = Vector3(10.5, 1.0, 12.5) * WorldData.CELL
	_check(placed.put_at(who, "tools:notice_board", Vector3i(10, 1, 10), 40), "a board hangs on a wall")
	var e: Dictionary = placed.things[-1]
	_check(e.cell.z == 10 and e.turn == 0, "in front of it, its back to the wall to the north: %s %d" % [e.cell, e.turn])
	_check(not placed.turn_sign(who, e), "a board on a wall is not turned")


func _test_taken_up() -> void:
	var w := _flat()
	var placed := _placed(w)
	var who := Who.new()
	who.position = Vector3(10.5, 1.0, 12.5) * WorldData.CELL
	who.inventory.add("tools:sign", 2)
	_check(placed.put_at(who, "tools:sign", Vector3i(10, 1, 10), 40), "a sign is set down")
	var e: Dictionary = placed.things[-1]
	placed.write(who, e, "Дом\nрыбака")
	e = placed.at(e.cell)
	_check(placed.take_up(who, e) and placed.things.is_empty(), "taken up")
	var inv: Inventory = who.inventory
	var written := -1
	for i in inv.slots.size():
		if inv.slots[i] != null and Inventory.text_of(inv.slots[i]) != "":
			written = i
	_check(written >= 0 and Inventory.text_of(inv.slots[written]) == "Дом\nрыбака" and inv.slots[written][1] == 1,
		"the written one lies apart from the blank one, with its words: %s" % [inv.slots])
	_check(inv.count("tools:sign") == 2, "both in the bag")
	var copy := Inventory.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	_check(Inventory.text_of(copy.slots[written]) == "Дом\nрыбака", "the words are saved with the bag")
	var data: Variant = Inventory.drop_data(inv.slots[written])
	_check(data is Dictionary and data.get("text", "") == "Дом\nрыбака", "and lie on the ground with it")
	var chest := Inventory.new(4)
	_check(inv.move_slot(written, chest) == 1 and Inventory.text_of(chest.slots[0]) == "Дом\nрыбака", "and go into a chest with it")
	chest.move_slot(0, inv)
	inv.sort("kind")
	_check(inv.count("tools:sign") == 2 and inv.slots.any(func(s) -> bool: return Inventory.text_of(s) == "Дом\nрыбака"),
		"sorting keeps the written one whole")
	var slot := -1
	for i in inv.slots.size():
		if Inventory.text_of(inv.slots[i]) != "":
			slot = i
	_check(placed.put_from_bag(who, "tools:sign", slot, 40), "set down again from its slot")
	_check(placed.things[-1].get("text", "") == "Дом\nрыбака", "it says what it said: %s" % [placed.things[-1].get("text", "")])
