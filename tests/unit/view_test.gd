extends "res://tests/unit/test_case.gd"
## The client view: the pixel view, sprite sheets, tracks, the level cut, sound and the
## camera's smooth turn.

const CameraRig := preload("res://src/client/view/camera_rig.gd")


func run() -> void:
	_test_pixel_view()
	_test_sprite_sheet()
	_test_tracks()
	_test_hidden()
	_test_sound()
	_test_camera_spin()


func _test_pixel_view() -> void:
	var screens := [Vector2(1280, 720), Vector2(1366, 768), Vector2(1920, 1080), Vector2(2532, 1170),
		Vector2(1170, 2532), Vector2(2400, 1008), Vector2(375, 667), Vector2(3840, 2160)]
	var whole := true
	for screen in screens:
		var view: Array = PixelView.layout(screen)
		var scale: float = view[0]
		var image: Vector2i = view[1]
		var covered := Vector2(image * scale)
		whole = whole and image.x % 2 == 0 and image.y % 2 == 0 \
			and covered.x >= screen.x and covered.y >= screen.y \
			and covered.x - screen.x < 2 * scale and covered.y - screen.y < 2 * scale \
			and absf(image.y - PixelView.TARGET_HEIGHT) <= PixelView.TARGET_HEIGHT * 0.25
	_check(whole, "low-res image is scaled by a whole number and covers the screen")
	_check(PixelView.layout(Vector2(1200, 2608), PixelView.TARGET_HEIGHT, true)[0]
		== PixelView.layout(Vector2(2608, 1200), PixelView.TARGET_HEIGHT, true)[0],
		"a phone shows the world as large held either way")
	# Any phone shows as many cells across as the reference one, by a fraction of a scale.
	var phones := [Vector2(1200, 2608), Vector2(1080, 2400), Vector2(720, 1600), Vector2(1440, 3200)]
	var across := true
	for screen in phones:
		var view: Array = PixelView.layout(screen, PixelView.TARGET_HEIGHT, true)
		var image: Vector2i = view[1]
		var covered: Vector2 = Vector2(image) * float(view[0])
		across = across and absi(image.x - 172) <= 2 and covered.x >= screen.x and covered.y >= screen.y
	_check(across, "every phone shows as many cells across as the reference one")
	_check(is_equal_approx(PixelView.camera_size(360), 22.5), "16 pixels per world unit")
	# A cell's top and its south wall both cover 16 x 16 pixels on screen.
	var top := PixelView.screen_plane(Vector3(3, 2, 5)) - PixelView.screen_plane(Vector3(3, 2, 4))
	var wall := PixelView.screen_plane(Vector3(3, 1, 5)) - PixelView.screen_plane(Vector3(3, 2, 5))
	_check(top == Vector2(0, 1) and wall == Vector2(0, 1), "top and wall of a cell are equally tall on screen")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var on_grid := true
	for i in 50:
		var p := Vector3(rng.randf_range(-100, 100), rng.randf_range(0, 20), rng.randf_range(-100, 100))
		var c := PixelView.screen_plane(PixelView.snap(p)) * PixelView.PIXELS_PER_UNIT
		on_grid = on_grid and absf(c.x - roundf(c.x)) < 0.001 and absf(c.y - roundf(c.y)) < 0.001
		on_grid = on_grid and PixelView.snap(p).distance_to(p) < 0.06
	_check(on_grid, "snapped points land on whole pixels")
	# A view ray through a pixel passes every point drawn on that pixel.
	var cell := Vector3(10.5, 4.0, 20.25)
	var ray: Array = PixelView.view_ray(PixelView.screen_plane(cell), Vector2.ZERO, 30.0)
	var t: float = (ray[0].y - cell.y) / -ray[1].y
	_check((ray[0] + ray[1] * t).distance_to(cell) < 0.001, "view ray hits the point under the pixel")
	var sun := Vector3(-0.3, 0.7, 0.5).normalized()
	_check(PixelView.light_dir(sun).is_equal_approx(sun), "the default view keeps the sun where it is")
	# A turned and tilted camera: rays still hit what is drawn under them, boxes hold
	# what their meshes draw, shadows fall where they fall in the default view, and
	# the camera shows the point it is put over in the middle.
	var turned := true
	var box := AABB(Vector3(-3, 1, 7), Vector3(4, 6, 2))
	for view: Vector2 in [Vector2(PI / 12.0, 0.0), Vector2(PI * 0.75, 0.25), Vector2(-PI / 3.0, -0.5)]:
		PixelView.set_view(view.x, view.y)
		PixelView.box_views = [PixelView.view_of(view.x, view.y)]
		ray = PixelView.view_ray(PixelView.screen_plane(cell), Vector2.ZERO, 30.0)
		t = (ray[0].y - cell.y) / -ray[1].y
		turned = turned and (ray[0] + ray[1] * t).distance_to(cell) < 0.001
		var drawn := PixelView.sheared_box(box, 0.0).grow(0.001)
		for i in 8:
			turned = turned and drawn.has_point(PixelView.shear(box.get_endpoint(i)))
		var foot := Vector3(4, 2, 9)
		var tip := foot + Vector3(0, 3, 0)
		var lit := PixelView.light_dir(sun)
		var hit := PixelView.shear(tip) - lit * (3.0 / lit.y)
		# In the default view the shadow of the tip lands 3 units of height north too.
		var fall := Vector3(tip.x - sun.x * 3.0 / sun.y, foot.y, tip.z - sun.z * 3.0 / sun.y - 3.0)
		turned = turned and hit.is_equal_approx(PixelView.shear(fall))
		var middle := PixelView.camera_transform(Vector2(5, -2)).origin
		turned = turned and PixelView.plane_of(Vector2(middle.x, middle.z)).is_equal_approx(Vector2(5, -2))
		turned = turned and PixelView.screen_dir(PixelView.world_dir(Vector2(0.3, -1))).is_equal_approx(Vector2(0.3, -1))
	PixelView.set_view(0.0, 0.0)
	PixelView.box_views = [PixelView.view_of(0.0, 0.0)]
	_check(turned, "a turned and tilted view draws, picks, culls and shades consistently")
	# The lit edges keep their side of the sky until the light is well past its border.
	var sky = SkyScript.new(null)
	var sides := []
	for azimuth: float in [-20.0, -29.0, -31.0, -20.0, -15.0, 60.0, -115.0]:
		sky._light_side(azimuth)
		sides.append(sky.light_side)
	_check(sides == [0, 0, 7, 7, 0, 1, 5], "the lit edges of the cells turn with the light without flicker")


func _test_sprite_sheet() -> void:
	_check(SpriteSheet.direction_of(Vector2(0, 1)) == "s", "pushing south faces south")
	_check(SpriteSheet.direction_of(Vector2(1, 0)) == "e", "pushing east faces east")
	_check(SpriteSheet.direction_of(Vector2(-1, -1)) == "nw", "pushing north-west faces north-west")
	_check(SpriteSheet.direction_of(Vector2(0.3, -1)) == "n", "a push mostly north faces north")
	var look := ["body", "hair", "shirt", "trousers", "boots"]
	var s := Figure.sheet(look)
	var cols := s.columns
	var fw := s.frame_size.x
	var fh := s.frame_size.y
	_check(cols == 40 and fw == 32 and fh == 32, "player sheet: standing, walking, jumping, swimming, seven works of four; 32 by 32 frames")
	_check(s.texture.get_width() == cols * fw and s.texture.get_height() == 8 * fh, "player sheet has eight directions")
	var img := s.texture.get_image()
	var drawn := 0
	for y in fh:
		for x in fw:
			if img.get_pixel(x, y).a > 0.5:
				drawn += 1
	_check(drawn > 80 and drawn < fw * fh / 2, "the standing frame is drawn with room around it")
	_check(img.get_pixel(fw / 2, fh - 1).a > 0.5, "the feet stand on the bottom row of the frame")
	var uv := s.frame_uv("s", "idle", 0.0)
	_check(uv == Vector4(0.0, 0.0, 1.0 / cols, 1.0 / 8.0), "the first frame is the top-left one")
	_check(s.frame_uv("s", "walk", 0.25) != s.frame_uv("s", "walk", 0.0), "walking changes frames in time")
	var w := s.frame_uv("w", "idle", 0.0)
	_check(w.z > 0.0 and is_equal_approx(w.y, 6.0 / 8.0), "west has a row of its own")
	var east := img.get_region(Rect2i(0, 2 * fh, fw, fh))
	east.flip_x()
	_check(east.get_data() == img.get_region(Rect2i(0, 6 * fh, fw, fh)).get_data(), "west is east mirrored when the hands are empty")
	_check(Figure.sheet(["body"]).texture.get_image().get_pixel(fw / 2, fh - 2) != img.get_pixel(fw / 2, fh - 2), "without boots the feet are bare")
	# The bare figure knows where its hands are; the one in use moves in the works.
	var anchors: Array = Figure.anchors()
	var works: Dictionary = Figure.data().works
	var chop: Array = works.chop.columns
	_check(anchors[0][chop[0]].right.at != anchors[0][chop[1]].right.at, "the hand in use winds up and strikes")
	_check(anchors[0][chop[0]].left.at == anchors[0][0].left.at, "the other hand stays put")
	_check(anchors[2][0].right.front and not anchors[2][0].left.front, "facing east the right hand is near, the left far")
	_check(not anchors[4][0].right.front, "with the back turned a hand is behind the body")
	_check(anchors[0][works.mow.columns[1]].left.is_empty(), "in a two-handed work the left hand holds the same thing")
	_check(Figure.opposite("se") == "sw" and Figure.opposite("w") == "e" and Figure.opposite("n") == "n", "opposite directions")
	# Things held have sheets of their own, put at the hands.
	var axe := {"sprite": "res://content/tools/axe/sprites/held/axe.png", "anim": "chop"}
	var cell := Vector2i(Figure.data().held.cell[0], Figure.data().held.cell[1])
	_check(Figure.held_sheet(axe.sprite).get_size() == Vector2i(5, 8) * cell, "a tool's sheet: carried and its four frames, in eight directions")
	var armed := Figure.sheet(look, {"right": axe, "active": "right"})
	var with_axe := armed.texture.get_image()
	_check(with_axe.get_region(Rect2i(0, 0, fw, fh)).get_data() != img.get_region(Rect2i(0, 0, fw, fh)).get_data(), "a held tool shows")
	_check(with_axe.get_region(Rect2i(chop[0] * fw, 0, fw, fh)).get_data() != with_axe.get_region(Rect2i(chop[1] * fw, 0, fw, fh)).get_data(), "a chop winds up and strikes")
	var slash: Array = works.slash.columns
	_check(with_axe.get_region(Rect2i(slash[0] * fw, 0, fw, fh)).get_data() != img.get_region(Rect2i(slash[0] * fw, 0, fw, fh)).get_data(), "in another work a tool is carried")
	var west := with_axe.get_region(Rect2i(0, 6 * fh, fw, fh))
	west.flip_x()
	_check(west.get_data() != with_axe.get_region(Rect2i(0, 2 * fh, fw, fh)).get_data(), "a tool stays in its hand when the body turns west")
	# The left hand in use: each direction is the opposite one, mirrored, hands swapped.
	var lefty := Figure.sheet(look, {"left": axe, "active": "left"}).texture.get_image()
	var mirrored := with_axe.get_region(Rect2i(chop[1] * fw, 6 * fh, fw, fh))
	mirrored.flip_x()
	_check(lefty.get_region(Rect2i(chop[1] * fw, 2 * fh, fw, fh)).get_data() == mirrored.get_data(), "an axe in the left hand chops as the right one mirrored")
	var lump := {"icon": "test:nothing", "picture": null, "anim": "reach"}
	var steps = Figure.new(look, {"left": axe, "right": lump, "active": "left"})
	var count := 0
	while not steps.step():
		count += 1
	_check(count == 8 * ceili(cols / float(Figure.PART)) and steps.target.texture.get_image().get_data() == Figure.sheet(look, steps.held).texture.get_image().get_data(),
		"a sheet built a part of a row a step is the one built at once")
	_check(Figure.icon_turns("test:nothing", null)[0].get_used_rect().has_area(), "a thing without a picture is a lump")
	# A thing without a sheet is its icon, made small and turned with the hand.
	var icon := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	icon.fill(Color(0, 0, 0, 0))
	icon.fill_rect(Rect2i(5, 1, 2, 10), Color.RED)
	var turns: Array = Figure.icon_turns("test:stick", icon)
	var small: Image = turns[0]
	_check(small.get_width() <= Figure.data().held.icon and small.get_height() <= Figure.data().held.icon, "an icon in a hand is made small")
	var lying: Rect2i = turns[2].get_used_rect()
	_check(lying.size.x > lying.size.y and small.get_used_rect().size.y > small.get_used_rect().size.x, "an icon turns a quarter on its side")
	var stick := {"icon": "test:stick", "picture": icon, "anim": "chop"}
	var swung := Figure.sheet(look, {"right": stick, "active": "right"}).texture.get_image()
	_check(swung.get_region(Rect2i(chop[0] * fw, 2 * fh, fw, fh)).get_data() != swung.get_region(Rect2i(chop[2] * fw, 2 * fh, fw, fh)).get_data(),
		"an icon swings with the hand in its work")
	# Nothing spills over a frame's edge: what is on it is outline next to the figure.
	var spilled := 0
	for row in 8:
		for c in cols:
			var r := Rect2i(c * fw, row * fh, fw, fh)
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var edge := x == r.position.x or x == r.end.x - 1 or y == r.position.y or y == r.end.y - 1
					if not edge or with_axe.get_pixel(x, y).a < 0.5:
						continue
					var inside := false
					for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var n := Vector2i(x, y) + d
						inside = inside or (r.has_point(n) and with_axe.get_pixelv(n).a > 0.5 and with_axe.get_pixelv(n) != SpriteSheet.OUTLINE)
					if not inside:
						spilled += 1
	_check(spilled == 0, "the outline keeps within each frame")
	# The player plays the work of the thing in the hand in use once, then stands again.
	var p = PlayerScript.new()
	p.sheet = s
	p.body.on_ground = true
	p.held = {"left": {"sprite": "res://content/tools/shovel/sprites/held/shovel.png", "anim": "dig"}, "right": axe, "active": "left"}
	p.work("", 0.4, Vector3(-5.0, 0.0, 0.0))
	_check(p.work_kind == "dig" and p.facing == "w", "a shovel digs, turned towards the cell")
	p._animate(Vector2.ZERO, 0.0, 0.1)
	_check(p.anim == "dig", "the work plays")
	p._animate(Vector2.ZERO, 0.0, 0.5)
	_check(p.anim == "idle" and p.work_kind == "", "after the swing the body stands again")
	p.held.active = "right"
	p.work("", 0.4)
	_check(p.work_kind == "chop", "an axe chops")
	p.held.active = "left"
	p.held.left = {}
	p.work_kind = ""
	p.work("", 0.4)
	_check(p.work_kind == "reach", "bare hands reach")
	p.work_kind = ""
	p.body.on_ground = false
	p.body.velocity_y = 1.0
	p._animate(Vector2.ZERO, 0.0, 0.1)
	var rising := s.frame_uv(p.facing, p.anim, p.anim_time)
	p.body.velocity_y = -1.0
	p._animate(Vector2.ZERO, 0.0, 0.1)
	_check(p.anim == "jump" and rising != s.frame_uv(p.facing, p.anim, p.anim_time), "a jump goes up, then comes down")
	p.body.swimming = true
	p._animate(Vector2.ZERO, 0.0, 0.1)
	_check(p.anim == "swim", "in deep water the body swims")
	p.free()


## Footprints: stone takes them only under a roof (the dust of a cave floor).
func _test_tracks() -> void:
	var w := WorldData.new(8, Vector2i(4, 4))
	for z in 4:
		for x in 4:
			w.set_cell(x, 0, z, Mat.STONE)
	var t := Tracks.new()
	t.world = w
	t._ready()
	var feet := Vector3(0.75, WorldData.CELL, 0.75)
	t.leave(feet, Vector2(0, 1), true, true, 1.0)
	_check(t.next == 0, "no prints on stone in the open")
	w.set_cell(1, 3, 1, Mat.STONE)
	t.leave(feet, Vector2(0, 1), true, true, 1.0)
	_check(t.next == 1, "prints on the stone floor of a cave")
	t.free()


## The cut finds earth that hides the player from the camera: the near wall of a
## ravine running diagonally across the view, not a wall the head looks over.
func _test_hidden() -> void:
	var cs := ChunkStreamer.new(null)
	cs.world = WorldData.new(12, Vector2i(32, 32))
	# Ground up to level 7 except a ravine one cell wide along x == z, floor level 1.
	for z in 32:
		for x in 32:
			for y in (1 if x == z else 7):
				cs.world.set_cell(x, y, z, Mat.STONE)
	_check(cs._hiding_level(16, 1, 16) == 3, "the near wall of a diagonal ravine hides the player")
	# Two levels deep: the head shows over the wall.
	cs.world = WorldData.new(12, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			for y in (1 if x == z else 3):
				cs.world.set_cell(x, y, z, Mat.STONE)
	_check(cs._hiding_level(16, 1, 16) == -1, "a wall the head looks over does not cut the view")
	# A trench running north to south: open toward the camera in the default view, its
	# side wall in front of the player once the camera is turned a quarter.
	cs.world = WorldData.new(12, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			for y in (1 if x == 16 else 7):
				cs.world.set_cell(x, y, z, Mat.STONE)
	var along := cs._hiding_level(16, 1, 16)
	PixelView.set_view(PI / 2.0, 0.0)
	var across := cs._hiding_level(16, 1, 16)
	PixelView.set_view(0.0, 0.0)
	_check(along == -1 and across == 3, "the cut finds what hides the player in a turned view")


## The sounds load (loops looping), nothing sounds before the browser lets it, the
## hands' work sounds by what it strikes, and a piece of music stays in its range.
func _test_sound() -> void:
	for b: Array in SoundScript.BUSES:
		var i := AudioServer.get_bus_index(b[0])
		_check(i >= 0 and AudioServer.get_bus_send(i) == b[1],
			"bus %s is in default_bus_layout.tres, sending to %s (buses added later are silent in the browser)" % b)
	var s := SoundScript.new(null)
	var missing := []
	for id in s.records:
		var list := s.streams(id)
		if list.is_empty() or s.records[id].loop and list[0].loop_mode != AudioStreamWAV.LOOP_FORWARD:
			missing.append(id)
	_check(missing.is_empty(), "every sound loads, the loops looping: %s" % [missing])
	for id in ["sounds:wind", "sounds:step_grass", "sounds:click", "animals:sparrow", "music:note_pluck", "animals:wolf_howl"]:
		_check(s.records.has(id), "sound %s is there" % id)
	_check(s.resolve("click") == "sounds:click" and s.resolve("sounds:click") == "sounds:click" and s.resolve("sparrow") == "animals:sparrow"
		and s.resolve("nothing") == "" and s.streams("nothing").is_empty(), "a sound is asked for by its bare name, from whichever mod gives it")
	for m in Mat.COUNT:
		var r: Dictionary = Mat.RECORDS[m]
		_check(m == Mat.AIR or r.step != "", "%s has a step sound" % r.id)
	s.unlocked = false
	s.play_later(0.5, "plants:chop", Vector3.ZERO)
	_check(s._later.is_empty(), "nothing waits to sound before the first tap")
	s.unlocked = true
	var at := Vector3(1.0, 0.0, 1.0)
	var cases := [
		[{"at": at, "time": 0.4, "stuff": Mat.LOG}, "chop", "plants:chop"],
		[{"at": at, "time": 0.4, "stuff": Mat.STONE}, "chop", "sounds:hit_stone"],
		[{"at": at, "time": 0.4, "stuff": Mat.GRASS}, "mow", "tools:mow"],
		[{"at": at, "time": 0.4, "stuff": Mat.DIRT}, "dig", "sounds:dig"],
		[{"at": at, "time": 0.4, "stuff": -1}, "slash", "tools:swish"],
		[{"at": at, "time": 0.4, "stuff": Mat.DIRT, "placed": 1}, "reach", "sounds:place"],
	]
	for c: Array in cases:
		s._later.clear()
		s.work(c[0], c[1], 0.5)
		_check(s._later.size() == 1 and s._later[0][1] == c[2] and is_equal_approx(s._later[0][0], 0.2),
			"%s on %d sounds %s at the strike" % [c[1], c[0].stuff, c[2]])
	s._later.clear()
	s.work({"at": at, "time": 0.4, "stuff": -1}, "reach", 0.5)
	_check(s._later.is_empty(), "reaching for nothing is silent")
	var music := Music.new({"sound": s})
	for mood in Music.MOODS:
		music.start(mood)
		var lo := INF
		var hi := -INF
		var ordered := true
		for i in music._notes.size():
			var n: Array = music._notes[i]
			lo = minf(lo, n[2])
			hi = maxf(hi, n[2])
			ordered = ordered and (i == 0 or music._notes[i - 1][0] <= n[0])
		_check(music._notes.size() >= 16 and ordered, "a %s piece has its notes in order" % mood)
		_check(lo >= -18 and hi <= 15, "a %s piece stays within the notes' range (%d..%d)" % [mood, lo, hi])
	s.free()


class _FakeSettings:
	var values := {"camera_turn": 0, "camera_tilt": 0}
	func save() -> void:
		pass


class _FakeGame:
	var settings := _FakeSettings.new()
	var player := Node3D.new()
	var chunks = null
	var effects = null


## A turn button held turns the camera on smoothly; let go, it settles on the nearest step.
func _test_camera_spin() -> void:
	var game := _FakeGame.new()
	var rig = CameraRig.new(game)
	rig.look_at_player()
	rig.hold_turn(1)
	_check(rig.turn_steps == 1 and not rig.is_spinning(), "a tap turns the camera a step")
	rig.release_turn(1)
	for i in 60:
		rig._glide(1.0 / 30.0)
	_check(rig.turn == CameraRig.TURN_STEP, "a tap glides to the step and stops there")
	rig.hold_turn(1)
	var t := 0.0
	while t < 1.5:
		rig._glide(1.0 / 30.0)
		t += 1.0 / 30.0
	_check(rig.is_spinning() and rig.turn > 2.0 * CameraRig.TURN_STEP + 0.3, "held, the camera turns on past the step")
	_check(PixelView.box_views.size() >= ceili(TAU / CameraRig.BOX_STEP), "turning on, the culling boxes hold the views all round")
	var nearest := roundi(rig.turn / CameraRig.TURN_STEP)
	rig.release_turn(1)
	for i in 90:
		rig._glide(1.0 / 30.0)
	_check(not rig.is_spinning() and rig.turn == posmod(nearest, CameraRig.TURNS) * CameraRig.TURN_STEP
		and PixelView.box_views.size() == 1, "let go, the camera settles on the nearest step")
	_check(game.settings.values.camera_turn == posmod(nearest, CameraRig.TURNS), "the step settled on is kept")
	game.player.free()
	PixelView.set_view(0.0, 0.0)
	PixelView.box_views = [PixelView.view_of(0.0, 0.0)]
