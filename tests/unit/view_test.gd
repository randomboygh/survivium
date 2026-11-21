extends "res://tests/unit/test_case.gd"
## The client view: the pixel view, sprite sheets, tracks, the level cut, sound and the
## camera's smooth turn.

const CameraRig := preload("res://src/client/view/camera_rig.gd")
const MeshFaces := preload("res://src/client/world/mesh_faces.gd")
const CaveLayers := preload("res://src/client/view/cave_layers.gd")
const FireShadows := preload("res://src/client/view/fire_shadows.gd")
const EdgeHaze := preload("res://src/client/world/edge_haze.gd")
const AutoQuality := preload("res://src/client/view/auto_quality.gd")
const AirEffects := preload("res://src/client/view/air_effects.gd")
const WaterEffects := preload("res://src/client/view/water_effects.gd")
const NatureEffects := preload("res://src/client/view/nature_effects.gd")
const SettingsScript := preload("res://src/client/settings.gd")
const Others := preload("res://src/client/view/others.gd")
const Effects := preload("res://src/client/view/effects.gd")
const GlowLights := preload("res://src/client/view/glow_lights.gd")
const WindowGlow := preload("res://src/client/view/window_glow.gd")
const SunRays := preload("res://src/client/view/sun_rays.gd")
const Trample := preload("res://src/client/world/trample.gd")
const Looks := preload("res://src/shared/content/looks.gd")
const CreaturesView := preload("res://src/client/game/creatures.gd")
const RemoteWildlife := preload("res://src/client/net/remote_wildlife.gd")


## Ground all of one material (or all sea), for AirEffects.hot_ground.
class FakeGround:
	var sea_level := 10
	var top := 0
	var water := false

	func surface_y(_x: int, _z: int) -> int:
		return -1 if water else 11

	func get_cell(_x: int, _y: int, _z: int) -> int:
		return top

	func sea(_x: int, _y: int, _z: int) -> bool:
		return water


## Settings that keep values alone, for AutoQuality.
class FakeSettings:
	var values := {}
	var applied := 0

	func apply() -> void:
		applied += 1

	func save() -> void:
		pass


## The link and the game's parts the others' view asks of, for the own balloon.
class FakeLink:
	var welcome := {"id": 5}


class FakeGame:
	var link := FakeLink.new()
	var hud = null
	var player = null
	var view = null


func run() -> void:
	_test_pixel_view()
	_test_sprite_sheet()
	_test_eat()
	_test_reach()
	_test_gestures()
	_test_tracks()
	_test_hidden()
	_test_cave_layers()
	_test_sound()
	_test_camera_spin()
	_test_camera_drift()
	_test_other_bundles()
	_test_light_maps()
	_test_edge_haze()
	_test_auto_quality()
	_test_own_balloon()
	_test_global_textures()
	_test_fire_shadows_blank()
	_test_glow_lights()
	_test_window_glow()
	_test_small_effects()
	_test_hot_ground()
	_test_rays_dissolve()
	_test_animal_flinch()
	_test_boar_states()
	_test_fox_states()
	_test_grouse_states()


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
	# On a computer each pixel size is a scale of its own on a common window (it was not:
	# a fraction of the height rounded two sizes to the same scale).
	for height in [960, 1009, 1080, 1440]:
		var scales := []
		for k in [0.75, 0.875, 1.0, 1.25, 1.5]:
			scales.append(PixelView.layout(Vector2(1920, height), PixelView.TARGET_HEIGHT / k)[0])
		var apart := true
		for i in range(1, scales.size()):
			apart = apart and scales[i] > scales[i - 1]
		_check(apart, "every pixel size differs on a %d px window: %s" % [height, scales])
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
	_check(cols == 60 and fw == 32 and fh == 32, "player sheet: standing, six of walking, jumping, swimming, seven works of four, asleep, sitting, rowing, twelve of gestures; 32 by 32 frames")
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
	_check(Figure.sheet(["body"]).texture.get_image().get_pixel(fw / 2 + 1, fh - 1) != img.get_pixel(fw / 2 + 1, fh - 1), "without boots the feet are bare")
	# The row of the west: lying on its side, the head to the west (in a bed its rows lie
	# its head the bed's way, Figure._lay_down).
	var sleep := s.frame_at("w", "sleep", 0.0)
	var lain: Rect2i = img.get_region(Rect2i(sleep.x * fw, sleep.y * fh, fw, fh)).get_used_rect()
	var standing: Rect2i = img.get_region(Rect2i(0, 0, fw, fh)).get_used_rect()
	# Standing, the feet have no outline under them; lying, the soles get theirs.
	_check(lain.size == Vector2i(standing.size.y + 1, standing.size.x) and lain.end.y == standing.end.y,
		"asleep the figure lies on its side on the frame's bottom: %s, %s" % [lain, standing])
	var head_up := s.frame_at("n", "sleep", 0.0)
	var head_down := s.frame_at("s", "sleep", 0.0)
	var up: Image = img.get_region(Rect2i(head_up.x * fw, head_up.y * fh, fw, fh))
	var down: Image = img.get_region(Rect2i(head_down.x * fw, head_down.y * fh, fw, fh))
	down.flip_y()
	_check(up.get_used_rect().size == Vector2i(standing.size.x, standing.size.y + 1)
		and down.get_used_rect().size == up.get_used_rect().size,
		"in a bed along the screen it lies head up (north) or upside down (south): %s, %s" % [up.get_used_rect(), down.get_used_rect()])
	var whites := [0, 0]
	for y in fh:
		for x in fw:
			for i in 2:
				if img.get_pixel([0, sleep.x][i] * fw + x, y).is_equal_approx(Color.WHITE):
					whites[i] += 1
	_check(whites[0] > 0 and whites[1] == 0 and s.frame_at("n", "sleep", 0.0).x == sleep.x, "asleep its eyes are closed, whichever way it faced")
	# The soles stay open only in the walk, where a foot is off the ground: off it whatever
	# hangs low in a frame (a hand by the hips, a foot tucked up) has its outline under it.
	var mark := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	mark.fill(SpriteSheet.OUTLINE)
	var dark := mark.get_pixel(0, 0)
	var walking := {}
	for f: Variant in Figure.data().animations.walk.frames:
		walking[int(f)] = true
	var unlined := 0
	var open_soles := 0
	for r in 8:
		for col in cols:
			if col == sleep.x:
				continue
			for y in range(fh - 3, fh - 1):
				for x in fw:
					var p := img.get_pixel(col * fw + x, r * fh + y)
					if p.a > 0.5 and p != dark and img.get_pixel(col * fw + x, r * fh + y + 1).a < 0.5:
						if walking.has(col):
							open_soles += 1
						else:
							unlined += 1
	_check(unlined == 0 and open_soles > 0, "off the walk all that hangs low is outlined under it, a foot lifted in the walk is not: %d, %d" % [unlined, open_soles])
	# Asleep the legs lie pressed together (the user's note of 2026-11-20): across the soles,
	# the frame's last column of the body, a single pixel of outline parts the feet.
	var parted := 0
	var gap := 0
	var seen := false
	for y in fh:
		var p := img.get_pixel(sleep.x * fw + lain.end.x - 2, sleep.y * fh + y)
		if p.a < 0.5:
			continue
		if p == dark:
			gap += 1 if seen else 0
		else:
			if gap > 0:
				parted = gap
			seen = true
			gap = 0
	_check(parted == 1, "asleep the legs lie together, a pixel of outline between the soles: %d" % parted)
	# Naked in a loincloth; clothes worn show between the naked layers, a bag does not.
	var naked := Figure.dressed({})
	_check(naked == ["body", "loincloth", "hair"], "the figure is naked in a loincloth with nothing worn")
	var furs := Figure.dressed({"head": "tools:fur_hat", "body": "tools:fur_coat", "back": "tools:wicker_bag"})
	_check(furs.size() == 5 and furs[2].ends_with("worn/fur_coat.png") and furs[3] == "hair" and furs[4].ends_with("worn/fur_hat.png"),
		"a coat goes under the hair, a hat over it, a bag is not drawn: %s" % [furs])
	var coat := Figure.sheet(furs).texture.get_image()
	var bare := Figure.sheet(naked).texture.get_image()
	_check(coat.get_pixel(fw / 2, fh - 5) != bare.get_pixel(fw / 2, fh - 5), "the coat shows on the body")
	_test_looks()
	# The bare figure knows where its hands are; the one in use moves in the works.
	var anchors: Array = Figure.anchors()
	var works: Dictionary = Figure.data().works
	var chop: Array = works.chop.columns
	_check(anchors[0][chop[0]].right.at != anchors[0][chop[1]].right.at, "the hand in use winds up and strikes")
	# The torso turns a pixel toward the swing (ChopArt), the other hand with it.
	var still: Vector2i = anchors[0][chop[0]].left.at - anchors[0][0].left.at
	_check(absi(still.x) <= 1 and still.y == 0, "the other hand stays put but for the torso's turn: %s" % [still])
	_check(anchors[2][0].right.front and not anchors[2][0].left.front, "facing east the right hand is near, the left far")
	_check(not anchors[4][0].right.front, "with the back turned a hand is behind the body")
	# Rowing (RowArt) the body sits as in the sit, its feet where they were, so the two follow
	# each other without a jump; its fists are up on the oars' handles, the stroke moving them.
	var seated := s.frame_at("s", "sit", 0.0).x
	var rowed: Array = Figure.data().animations.row.frames
	var boots := Figure.layer("boots")
	var moved := 0
	var raised := 0
	for r in 8:
		var sat := boots.get_region(Rect2i(seated * fw, r * fh, fw, fh)).get_data()
		for f: Variant in rowed:
			if boots.get_region(Rect2i(int(f) * fw, r * fh, fw, fh)).get_data() != sat:
				moved += 1
			for hand in ["right", "left"]:
				if r in [0, 4] and anchors[r][int(f)][hand].at.y < anchors[r][seated][hand].at.y:
					raised += 1
	_check(moved == 0, "rowing, the feet stay where they sit: %d frames moved them" % moved)
	_check(raised == 4 * rowed.size(), "rowing, from the front and from behind both fists are up on the oars: %d of %d" % [raised, 4 * rowed.size()])
	_check(img.get_region(Rect2i(int(rowed[0]) * fw, 0, fw, fh)).get_data() != img.get_region(Rect2i(int(rowed[1]) * fw, 0, fw, fh)).get_data(),
		"the stroke moves the rower")
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
	# A blade leaves a trail in its work's frames: over the figure and its outline where the
	# blade is in front of the body, behind them (only where the frame is empty) where the
	# blade is behind it, as seen from behind.
	var sword := {"sprite": "res://content/tools/sword/sprites/held/sword.png", "anim": "slash", "trail": true}
	var trailed := Figure.sheet(look, {"right": sword, "active": "right"}).texture.get_image()
	var untrailed := Figure.sheet(look, {"right": {"sprite": sword.sprite, "anim": "slash"}, "active": "right"}).texture.get_image()
	var trail := Figure.layer(Figure.data().trail)
	var streaked := 0
	var behind := 0
	var wrong := 0
	for row in 8:
		var marks: Array = Figure.anchors()[row]
		for c: int in works.slash.columns:
			var back: bool = not marks[c].right.is_empty() and not marks[c].right.front
			for y in range(row * fh, row * fh + fh):
				for x in range(c * fw, c * fw + fw):
					if trail.get_pixel(x, y).a < 0.5:
						continue
					streaked += 1
					var shows: bool = trailed.get_pixel(x, y) == trail.get_pixel(x, y)
					var empty: bool = untrailed.get_pixel(x, y).a == 0.0
					if back:
						behind += 0 if empty else 1
						wrong += 1 if shows != empty else 0
					else:
						wrong += 0 if shows else 1
	_check(streaked > 0 and behind > 0 and wrong == 0,
		"a blade's trail shows over the figure, or behind it as seen from behind: %d of %d pixels wrong" % [wrong, streaked])
	_check(trailed.get_region(Rect2i(0, 0, fw, fh)).get_data() == untrailed.get_region(Rect2i(0, 0, fw, fh)).get_data()
		and trailed.get_data() != untrailed.get_data(), "a trail shows only in the work, only of a thing that leaves one")
	# A scythe is drawn as each frame of the mow draws it (MowArt `scythe`), in both hands:
	# its blade hangs from the snath's end down to the ground, whole in every frame (the
	# frame's edge cuts nothing off it, with a wider body too: its place does not follow that
	# body's hands).
	var scythe := {"sprite": "res://content/tools/scythe/sprites/held/scythe.png", "anim": "mow", "trail": true}
	var mow: Array = works.mow.columns
	var mowing := Figure.sheet(look, {"right": scythe, "active": "right"}).texture.get_image()
	var wide := Figure.sheet(Figure.dressed({}, {"build": "stocky"}), {"right": scythe, "active": "right"}).texture.get_image()
	var steel := Color("c3c8cc").to_rgba32()
	var blades := {}
	var hung := 0
	var both := 0
	for row in 8:
		for c: int in mow:
			both += 1 if anchors[row][c].left.is_empty() else 0
			var top := fh
			var low := -1
			var whole := [0, 0]
			for y in fh:
				for x in fw:
					if mowing.get_pixel(c * fw + x, row * fh + y).to_rgba32() == steel:
						top = mini(top, y)
						low = maxi(low, y)
						whole[0] += 1
					if wide.get_pixel(c * fw + x, row * fh + y).to_rgba32() == steel:
						whole[1] += 1
			blades[whole[0]] = true
			blades[whole[1]] = true
			hung += 1 if top >= fh - 7 and low >= fh - 3 else 0
	_check(hung == 8 * mow.size(), "a scythe's blade hangs down to the ground all through the mow: in %d frames of %d" % [hung, 8 * mow.size()])
	_check(blades.size() == 1 and not blades.has(0), "a scythe's blade is whole in every frame, with a wider body too: %s of its pixels show" % [blades.keys()])
	_check(both == 8 * mow.size(), "mowing, both hands hold the scythe: in %d frames of %d" % [both, 8 * mow.size()])
	# The hands hold the snath at its middle, not at its end: seen from the side its wood
	# (ToolArt.INK `w`) shows on both sides of the hand, toward the blade and past the fists.
	var wood := Color("84593a").to_rgba32()
	var middle := 0
	for c: int in mow:
		var hand: Vector2i = anchors[2][c].right.at
		var before := false
		var past := false
		for y in fh:
			for x in fw:
				if mowing.get_pixel(c * fw + x, 2 * fh + y).to_rgba32() == wood and img.get_pixel(c * fw + x, 2 * fh + y).to_rgba32() != wood:
					before = before or x < hand.x
					past = past or x > hand.x
		middle += 1 if before and past else 0
	_check(middle == mow.size(), "a scythe is held at the middle of its snath: from the side in %d frames of %d" % [middle, mow.size()])
	# Its trail shows on the strike alone (the mow's third frame): from the front and the
	# side over the figure (the blade passes in front of the feet), behind it as seen from
	# behind.
	var unswept := Figure.sheet(look, {"right": {"sprite": scythe.sprite, "anim": "mow"}, "active": "right"}).texture.get_image()
	var swept := 0
	var early := 0
	var over_feet := 0
	var amiss := 0
	for row in 8:
		for i in mow.size():
			var c: int = mow[i]
			var back: bool = not anchors[row][c].right.is_empty() and not anchors[row][c].right.front
			for y in range(row * fh, row * fh + fh):
				for x in range(c * fw, c * fw + fw):
					if trail.get_pixel(x, y).a < 0.5:
						continue
					if i != 2:
						early += 1
						continue
					swept += 1
					var shows: bool = mowing.get_pixel(x, y) == trail.get_pixel(x, y)
					var empty: bool = unswept.get_pixel(x, y).a == 0.0
					if back:
						amiss += 1 if shows != empty else 0
					else:
						amiss += 0 if shows else 1
						over_feet += 0 if empty else 1
	_check(swept > 0 and early == 0, "a scythe leaves its trail on the strike alone: %d of its pixels in other frames" % early)
	_check(over_feet > 0 and amiss == 0,
		"a scythe's trail passes in front of the figure, or behind it as seen from behind: %d of %d pixels wrong, %d over the figure" % [amiss, swept, over_feet])
	# A bow is drawn as each frame of its shot draws it (AimArt `bow`: nocked, drawn back,
	# loosed), and the other hand, which draws the string, shows nothing of its own.
	var bow := {"sprite": "res://content/tools/bow/sprites/held/wooden_bow.png", "anim": "aim"}
	var aim: Array = works.aim.columns
	_check(anchors[0][aim[1]].left.is_empty() and not anchors[0][0].left.is_empty(), "shooting a bow, the other hand draws the string")
	var shooting := Figure.sheet(look, {"right": bow, "active": "right"}).texture.get_image()
	_check(shooting.get_region(Rect2i(aim[0] * fw, 2 * fh, fw, fh)).get_data() != shooting.get_region(Rect2i(aim[1] * fw, 2 * fh, fw, fh)).get_data()
		and shooting.get_region(Rect2i(aim[1] * fw, 2 * fh, fw, fh)).get_data() != shooting.get_region(Rect2i(aim[2] * fw, 2 * fh, fw, fh)).get_data(),
		"a bow is drawn back, then loosed")
	var two := Figure.sheet(look, {"left": axe, "right": bow, "active": "right"}).texture.get_image()
	var shown := 0
	for row in 8:
		for c: int in aim:
			var r := Rect2i(c * fw, row * fh, fw, fh)
			shown += 0 if two.get_region(r).get_data() == shooting.get_region(r).get_data() else 1
	_check(shown == 0 and two.get_region(Rect2i(0, 0, fw, fh)).get_data() != shooting.get_region(Rect2i(0, 0, fw, fh)).get_data(),
		"shooting a bow, the other hand's thing is put away: in %d frames it shows" % shown)
	# A bow has no dark edge of its own where the figure's outline goes, which made a line two
	# pixels thick: shooting, a block of two by two dark pixels is only where the figure has
	# one without the bow.
	var lined := Image.create_empty(3, 2, false, Image.FORMAT_RGBA8)
	lined.fill_rect(Rect2i(0, 0, 2, 2), dark)
	var thick := 0
	for row in 8:
		for c: int in aim:
			for y in range(row * fh, row * fh + fh - 1):
				for x in range(c * fw, c * fw + fw - 1):
					if _dark_block(shooting, x, y) and not _dark_block(img, x, y):
						thick += 1
	_check(thick == 0 and _dark_block(lined, 0, 0) and not _dark_block(lined, 1, 0),
		"a bow's own edge does not double the figure's outline: %d places two pixels thick" % thick)
	# The bow's string (ToolArt.INK `s`) never runs over the legs, the frame's last two rows:
	# turned, the bow's lower end is under the frame's edge and the string ends at the limb.
	var string := Color("e2dfc8").to_rgba32()
	var strung := 0
	var on_legs := 0
	for row in 8:
		for c: int in aim:
			for y in range(row * fh, row * fh + fh):
				for x in range(c * fw, c * fw + fw):
					var under := img.get_pixel(x, y)
					if shooting.get_pixel(x, y).to_rgba32() != string or under.to_rgba32() == string:
						continue
					strung += 1
					if y >= row * fh + fh - 2 and under.a > 0.5 and under != dark:
						on_legs += 1
	_check(strung > 0 and on_legs == 0, "a bow's string never runs over the legs: %d of its %d pixels do" % [on_legs, strung])
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
	p.held.right = bow
	_check(p.work_kind_for("") == "aim" and p.work_kind_for("dig") == "dig", "a bow shoots (its arrow leaves on the third frame, Controls)")
	p.held.right = axe
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
	# The walk goes as fast as the body really goes: half the pace, half the frames; a
	# body held by a wall still marches in place, slowly; a jolt of the position is eased.
	p.body.swimming = false
	p.body.on_ground = true
	var walked := []
	for pace in [Body.SPEED, Body.SPEED * 0.5, 0.0]:
		p.anim = "idle"
		p._animate(Vector2(1.0, 0.0), pace, 0.05)
		var t0: float = p.anim_time
		for i in 10:
			p._animate(Vector2(1.0, 0.0), pace, 0.05)
		walked.append(p.anim_time - t0)
	_check(p.anim == "walk" and is_equal_approx(walked[1] * 2.0, walked[0]), "the walk plays at the pace the body goes")
	_check(walked[2] > 0.0 and walked[2] < walked[1], "pushing against a wall the legs march slowly")
	var before: float = p.gait
	p._animate(Vector2(1.0, 0.0), Body.SPEED * 50.0, 0.016)
	_check(p.gait < before + Body.SPEED, "a jump of the position does not spin the legs")
	p.free()


# Whether the four pixels from (x, y) right and down are all as dark as the outline or the
# darkest ink of a held thing: a line two pixels thick.
func _dark_block(img: Image, x: int, y: int) -> bool:
	for at: Vector2i in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]:
		var p := img.get_pixelv(at)
		if p.a < 0.5 or p.v > 0.25:
			return false
	return true


## The gestures' frames (GestureArt): waving, one hand is up by the head in every
## direction and goes a pixel out and back, the other stays where it is standing, so what
## it holds does not move; nodding, the head goes a pixel down over the collar and the body
## stands.
func _test_gestures() -> void:
	var s := Figure.sheet(["body", "hair"])
	var img := s.texture.get_image()
	var fw := s.frame_size.x
	var fh := s.frame_size.y
	var wave: Array = Figure.data().animations.wave.frames
	var anchors: Array = Figure.anchors()
	var bad := []
	for row in 8:
		var stand: Dictionary = anchors[row][0]
		var frames := [anchors[row][int(wave[0])], anchors[row][int(wave[1])]]
		var up := ""
		for hand: String in ["right", "left"]:
			if stand[hand].at.y - frames[0][hand].at.y >= 3 and stand[hand].at.y - frames[1][hand].at.y >= 3:
				up = hand
		var other := "left" if up == "right" else "right"
		var swung: bool = up != "" and frames[0][up].at != frames[1][up].at
		var kept: bool = up != "" and frames[0][other].at == stand[other].at and frames[1][other].at == stand[other].at
		var drawn := img.get_region(Rect2i(int(wave[0]) * fw, row * fh, fw, fh)).get_data() != img.get_region(Rect2i(int(wave[1]) * fw, row * fh, fw, fh)).get_data()
		if not (swung and kept and drawn):
			bad.append(row)
	_check(bad.is_empty(), "waving, a hand is up by the head and moves, the other stays put, in every direction: wrong in rows %s" % [bad])
	var nod := int(Figure.data().animations.nod.frames[1])
	var moved := []
	for row in 8:
		var standing := img.get_region(Rect2i(0, row * fh, fw, fh))
		var nodding := img.get_region(Rect2i(nod * fw, row * fh, fw, fh))
		var lower := nodding.get_used_rect().position.y == standing.get_used_rect().position.y + 1
		var legs := Rect2i(0, fh - 3, fw, 3)
		var still: bool = standing.get_region(legs).get_data() == nodding.get_region(legs).get_data() \
			and anchors[row][nod] == anchors[row][0]
		if not (lower and still):
			moved.append(row)
	_check(moved.is_empty(), "nodding, the head goes a pixel down and the body stands, in every direction: wrong in rows %s" % [moved])
	# What the body wears does not show over the head: the chin, a pixel down, over the collar.
	var shirt := Figure.layer("shirt")
	var body := Figure.layer("body")
	var covered := []
	for row in 8:
		var collar := row * fh + shirt.get_region(Rect2i(0, row * fh, fw, fh)).get_used_rect().position.y
		for x in fw:
			if body.get_pixel(x, collar - 1).a > 0.5 and shirt.get_pixel(nod * fw + x, collar).a > 0.5:
				covered.append(row)
				break
	_check(covered.is_empty(), "nodding, no shirt shows over the chin: wrong in rows %s" % [covered])
	# Shaking the head: the body stands (the legs and the hands' marks as standing), the head
	# turns one way and the other and goes at most a pixel aside between the two frames.
	var shake: Array = Figure.data().animations.shake.frames
	var shaken := []
	for row in 8:
		var standing := img.get_region(Rect2i(0, row * fh, fw, fh))
		var a := img.get_region(Rect2i(int(shake[0]) * fw, row * fh, fw, fh))
		var b := img.get_region(Rect2i(int(shake[1]) * fw, row * fh, fw, fh))
		var legs := Rect2i(0, fh - 3, fw, 3)
		var still: bool = a.get_region(legs).get_data() == standing.get_region(legs).get_data() \
			and b.get_region(legs).get_data() == standing.get_region(legs).get_data() \
			and anchors[row][int(shake[0])] == anchors[row][0] and anchors[row][int(shake[1])] == anchors[row][0]
		var turned := a.get_data() != b.get_data()
		var aside := absi(a.get_used_rect().position.x - b.get_used_rect().position.x) + absi(a.get_used_rect().end.x - b.get_used_rect().end.x)
		if not (still and turned and aside <= 2):
			shaken.append(row)
	_check(shaken.is_empty(), "shaking the head, the body stands and the head turns, a pixel aside at most, in every direction: wrong in rows %s" % [shaken])
	# Pointing: one hand out from the body and up from where it hangs, the other where it stands,
	# the legs as standing.
	var point := int(Figure.data().animations.point.frames[0])
	var pointing := []
	for row in 8:
		var stand: Dictionary = anchors[row][0]
		var at: Dictionary = anchors[row][point]
		var out := ""
		for hand: String in ["right", "left"]:
			if at[hand].at.y < stand[hand].at.y and at[hand].at != stand[hand].at:
				out = hand
		var other := "left" if out == "right" else "right"
		# The feet's row: a hand hanging reaches the rows over it.
		var legs := Rect2i(0, fh - 1, fw, 1)
		var still: bool = img.get_region(Rect2i(point * fw, row * fh, fw, fh)).get_region(legs).get_data() \
			== img.get_region(Rect2i(0, row * fh, fw, fh)).get_region(legs).get_data()
		if out == "" or at[other].at != stand[other].at or not still:
			pointing.append(row)
	_check(pointing.is_empty(), "pointing, one hand is up and out, the other and the legs as standing, in every direction: wrong in rows %s" % [pointing])
	# Beckoning: the same hand out in both frames and a pixel higher in the second, the other where
	# it stands.
	var beckon: Array = Figure.data().animations.beckon.frames
	var beckoning := []
	for row in 8:
		var stand: Dictionary = anchors[row][0]
		var a: Dictionary = anchors[row][int(beckon[0])]
		var b: Dictionary = anchors[row][int(beckon[1])]
		var out := ""
		for hand: String in ["right", "left"]:
			if a[hand].at.y < stand[hand].at.y and b[hand].at == a[hand].at + Vector2i.UP:
				out = hand
		var other := "left" if out == "right" else "right"
		if out == "" or a[other].at != stand[other].at or b[other].at != stand[other].at:
			beckoning.append(row)
	_check(beckoning.is_empty(), "beckoning, one hand is out and lifts a pixel, the other stays, in every direction: wrong in rows %s" % [beckoning])
	# Bowing: the head lower halfway and lower again at the bottom, the feet as standing.
	var bow: Array = Figure.data().animations.bow.frames
	var bowed := []
	for row in 8:
		var top := []
		for col: int in [0, int(bow[0]), int(bow[1])]:
			top.append(img.get_region(Rect2i(col * fw, row * fh, fw, fh)).get_used_rect().position.y)
		var feet := Rect2i(0, fh - 1, fw, 1)
		var still: bool = img.get_region(Rect2i(int(bow[1]) * fw, row * fh, fw, fh)).get_region(feet).get_data() \
			== img.get_region(Rect2i(0, row * fh, fw, fh)).get_region(feet).get_data()
		if not (top[1] == top[0] + 1 and top[2] == top[0] + 2 and still):
			bowed.append(row)
	_check(bowed.is_empty(), "bowing, the head goes a pixel and two down, the feet stay, in every direction: wrong in rows %s" % [bowed])
	# Clapping: the hands out apart, then no farther apart (from the front met in the middle,
	# three pixels nearer each), the feet as standing.
	var clap: Array = Figure.data().animations.clap.frames
	var clapped := []
	for row in 8:
		var apart: Dictionary = anchors[row][int(clap[0])]
		var met: Dictionary = anchors[row][int(clap[1])]
		var wide := absi(apart.right.at.x - apart.left.at.x)
		var near := absi(met.right.at.x - met.left.at.x)
		var feet := Rect2i(0, fh - 1, fw, 1)
		var still := true
		for col: int in [int(clap[0]), int(clap[1])]:
			still = still and img.get_region(Rect2i(col * fw, row * fh, fw, fh)).get_region(feet).get_data() \
				== img.get_region(Rect2i(0, row * fh, fw, fh)).get_region(feet).get_data()
		if near > wide or not still or (row == 0 and wide - near != 6):
			clapped.append(row)
	_check(clapped.is_empty(), "clapping, the hands come together, from the front three pixels each, the feet stay, in every direction: wrong in rows %s" % [clapped])


## The looks picked (Looks): their layers in the hair slot, their colours swapped by the
## shader (Figure.swaps), never found in the clothes or the things held.
func _test_looks() -> void:
	var looks := {"skin": 7, "hair": "mohawk", "hair_colour": 9, "eyes": 3, "face": "beard", "on_face": "glasses"}
	_check(Figure.dressed({}, looks) == ["body", "loincloth", "face/beard", "hair/mohawk", "face/glasses"]
		and Figure.dressed({"head": "tools:fur_hat"}, {"hair": "bald"})[-1].ends_with("worn/fur_hat.png")
		and not Figure.dressed({}, {"hair": "bald"}).any(func(l: String) -> bool: return l.begins_with("hair")),
		"the looks' layers go in the hair slot, the face under and over the hair, a hat over all; bald has none")
	_check(Figure.swaps({})[0].is_empty() and Figure.swaps(Looks.default_look())[0].is_empty(), "the default look swaps nothing")
	_test_forms()
	var s := Figure.swaps(looks)
	_check(s[0].size() == s[1].size() and s[0].size() >= 7 and s[0].size() <= Figure.SWAPS_MAX, "a look swaps its colours: %d" % s[0].size())
	# Every colour swapped is in the looks' pictures (the face's made ones too), and in no
	# other: the clothes and the tools' sheets keep theirs.
	var keys := {}
	for c: Vector3 in Figure._colours(Looks.default_look()):
		keys[Color8(int(c.x), int(c.y), int(c.z))] = true
	var found := {}
	var paths: Array = ["body"]
	for id in Looks.ids("hair") + Looks.ids("face").slice(1) + Looks.ids("on_face").slice(1):
		paths.append(("hair/" if Looks.data().hair.has(id) else "face/") + id)
	for name: String in paths:
		var path := "%s/player/%s.png" % [Figure.SPRITES, name]
		if Content.exists(path):
			_colours_in(Content.picture(path), keys, found)
	_check(found.size() == keys.size(), "each colour swapped is drawn somewhere: %d of %d" % [found.size(), keys.size()])
	var stray := {}
	var others: Array = []
	for name in ["loincloth", "shirt", "trousers", "boots"]:
		others.append("%s/player/%s.png" % [Figure.SPRITES, name])
		for form: String in ["stocky_straight", "thin_bust", "normal_curvy"]:
			others.append("%s/player/forms/%s/%s.png" % [Figure.SPRITES, form, name])
	for item in Items.BY_ID.values():
		if item.get("look", "") != "":
			others.append(Content.asset(item, "sprites/worn/%s.png" % item.look))
		if item.get("sprite", "") != "":
			others.append(Content.asset(item, "sprites/held/%s.png" % item.sprite))
	for path: String in others:
		if Content.exists(path):
			var before := stray.size()
			_colours_in(Content.picture(path), keys, stray)
			if stray.size() > before:
				_check(false, "%s has a colour of the looks, which the shader would swap" % path)
	_test_dye_keys(paths.map(func(n: String) -> String: return "%s/player/%s.png" % [Figure.SPRITES, n]) + others)


## The key colours of the clothes that can be dyed (Figure.dye_key): each such picture
## is drawn in its own slot's, every other picture in none; the colours shown for them
## are the cloth's, or the dye's.
func _test_dye_keys(paths: Array) -> void:
	var keys := {}
	for on: String in Figure.DYE_SLOTS:
		for i in 3:
			keys[Figure.dye_key(on, i)] = on
	var mine := {}
	for item in Items.BY_ID.values():
		if Items.dyeable(item.id):
			mine[Content.asset(item, "sprites/worn/%s.png" % item.look)] = item.wear_on
	_check(mine.size() >= 15, "clothes and beads can be dyed: %d" % mine.size())
	for path: String in paths:
		if not Content.exists(path):
			continue
		var found := {}
		_colours_in(Content.picture(path), keys, found)
		var slots := {}
		for c: Color in found:
			slots[keys[c]] = true
		if mine.has(path):
			_check(slots.keys() == [mine[path]], "%s is drawn in the key colours of its slot %s: %s" % [path, mine[path], slots.keys()])
		elif not found.is_empty():
			_check(false, "%s has key colours of clothes dyed, which the shader would swap" % path)
	var plain := Figure.dye_colours({"body": "tools:linen_shirt"})
	var black := Figure.dye_colours({"body": "tools:linen_shirt"}, {"body": "plants:dye_black"})
	var ring := Figure.dye_colours({"wrists": "tools:copper_ring"}, {"wrists": "plants:dye_black"})
	var at := Figure.DYE_SLOTS.find("body") * 3
	_check(plain.size() == 21 and plain[at] == Vector3(0xe8, 0xe0, 0xcc) and black[at + 2] == Vector3(0x20, 0x1c, 0x20)
		and ring[Figure.DYE_SLOTS.find("wrists") * 3] == Vector3.ZERO,
		"a shirt shows its own linen, dyed the dye's shades; a ring is not dyed")


## The body's forms (Looks build, figure): their own pictures where drawn, else the
## build straight's, else the plain ones; the hands of a wider build hang further out.
func _test_forms() -> void:
	_check(Figure.dressed({}, Looks.default_look())[0] == "body" and Figure.form_for({"build": "thin", "figure": "bust"}) == "thin_bust",
		"the plain form draws the plain layers")
	var stocky := Figure.dressed({"body": "tools:fur_coat", "feet": "tools:fur_boots"}, {"build": "stocky"})
	_check(stocky[0] == "forms/stocky_straight/body" and stocky.any(func(l: String) -> bool: return l.ends_with("worn/fur_coat/stocky_straight.png"))
		and stocky.any(func(l: String) -> bool: return l.ends_with("worn/fur_boots.png")),
		"a form's clothes are drawn for it, else the plain ones: %s" % [stocky])
	_check(Figure.form_of(stocky) == "stocky_straight" and Figure.form_of(["body"]) == "", "a look knows its form")
	var size := Figure.layer("body").get_size()
	for name: String in ["forms/thin_bust/body", "forms/thin_bust/fists", "forms/normal_bust/hands", "forms/stocky_curvy/hands"]:
		_check(Figure.layer(name) != null and Figure.layer(name).get_size() == size, "a form's layer is found: " + name)
	_check(Figure.layer("forms/thin_bust/fists").get_data() == Figure.layer("forms/thin_straight/fists").get_data()
		and Figure.layer("forms/thin_bust/body").get_data() != Figure.layer("forms/thin_straight/body").get_data(),
		"a figure draws its own body, its build's arms")
	var plain: Array = Figure.anchors()
	var wide: Array = Figure.anchors("stocky_straight")
	_check(wide[0][0].right.at.x == plain[0][0].right.at.x - 1 and wide[0][0].left.at.x == plain[0][0].left.at.x + 1,
		"a stocky build's hands hang a pixel further out")
	var bust := Figure.sheet(Figure.dressed({}, {"figure": "bust"})).texture.get_image()
	_check(bust.get_data() != Figure.sheet(Figure.dressed({})).texture.get_image().get_data(), "a bust shows")


## The eat (EatArt): the food goes up to the chin and stays there while the head nods
## onto it with the eyes shut, the legs still; seen from the back the body hides it.
func _test_eat() -> void:
	var look := Figure.dressed({}, Looks.default_look())
	var eat: Array = Figure.data().works.eat.columns
	var marks: Array = Figure.anchors()
	_check(marks[0][eat[1]].right.at.y < marks[0][eat[0]].right.at.y and marks[0][eat[2]].right.at == marks[0][eat[1]].right.at
		and marks[0][eat[3]].right.at == marks[0][eat[0]].right.at, "eating, the food goes up to the chin, stays for the bite and comes down")
	_check(marks[0][eat[1]].right.front and not marks[4][eat[1]].right.front, "the food is before the face, behind the body seen from the back")
	var s := Figure.sheet(look)
	var fw := s.frame_size.x
	var fh := s.frame_size.y
	var bare := s.texture.get_image()
	var tops := []
	var whites := []
	var feet := []
	for c: int in eat:
		var frame := bare.get_region(Rect2i(c * fw, 0, fw, fh))
		tops.append(frame.get_used_rect().position.y)
		var white := 0
		for y in fh:
			for x in fw:
				white += 1 if frame.get_pixel(x, y).is_equal_approx(Color.WHITE) else 0
		whites.append(white)
		feet.append(frame.get_region(Rect2i(0, fh - 3, fw, 3)).get_data())
	_check(tops[1] == tops[0] and tops[2] == tops[0] + 1 and tops[3] == tops[0], "the bite is a nod, the head a row down and up again: %s" % [tops])
	_check(whites[0] > 0 and whites[1] > 0 and whites[2] == 0 and whites[3] == 0, "the eyes shut on the bite and while chewing: %s" % [whites])
	_check(feet[1] == feet[0] and feet[2] == feet[0] and feet[3] == feet[0], "eating, the legs do not move")
	var food := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	food.fill(Color(0, 0, 0, 0))
	food.fill_rect(Rect2i(1, 1, 10, 10), Color.RED)
	var fed := Figure.sheet(look, {"right": {"icon": "test:food", "picture": food, "anim": "eat"}, "active": "right"}).texture.get_image()
	var shown := 0
	var hidden := 0
	for c: int in eat:
		for row in 8:
			var r := Rect2i(c * fw, row * fh, fw, fh)
			var same: bool = fed.get_region(r).get_data() == bare.get_region(r).get_data()
			if row == 4:
				hidden += 1 if same else 0
			elif row < 3 or row > 5:
				shown += 0 if same else 1
	_check(shown == 5 * eat.size() and hidden == eat.size(), "food shows from the front and the sides, the back hides it: %d shown, %d hidden" % [shown, hidden])


## Adds to `found` the colours of `keys` that `img` has in its first COLOURS_SEEN
## pixels across (the stand, the walk: every part of the figure shows there; the whole
## of a sheet is too slow to read here).
const COLOURS_SEEN := 160
func _colours_in(img: Image, keys: Dictionary, found: Dictionary) -> void:
	img = img.get_region(Rect2i(0, 0, mini(img.get_width(), COLOURS_SEEN), img.get_height()))
	img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	for i in range(0, data.size(), 4):
		if data[i + 3] > 0:
			var c := Color8(data[i], data[i + 1], data[i + 2])
			if keys.has(c):
				found[c] = true


## Bare hands reach (ReachArt): the body crouches in the two middle frames and the hand goes
## down with it, to a row over the ground; still crouched the arm is short again, and
## standing the hand comes up to the shoulder. The arm lies against the body all the way,
## with no outline between them, and the legs stand as they stood.
func _test_reach() -> void:
	var s := Figure.sheet(["body"])
	var img := s.texture.get_image()
	var fw := s.frame_size.x
	var fh := s.frame_size.y
	var reach: Array = Figure.data().works.reach.columns
	var anchors: Array = Figure.anchors()
	var trousers := Figure.layer("trousers")
	var mark := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	mark.fill(SpriteSheet.OUTLINE)
	var dark := mark.get_pixel(0, 0)
	var crouched := 0
	var reached := 0
	var apart := 0
	var stepped := 0
	for row in 8:
		var stand := Rect2i(0, row * fh, fw, fh)
		var top := img.get_region(stand).get_used_rect().position.y
		# Seen from the side the near hand hides a part of the hips when it hangs.
		var side: bool = s.directions[row] in ["e", "w"]
		var tops := []
		var hands := []
		for c: int in reach:
			var r := Rect2i(c * fw, row * fh, fw, fh)
			tops.append(img.get_region(r).get_used_rect().position.y)
			hands.append(anchors[row][c].right.at.y)
			apart += absi(_gaps(img, r, dark) - _gaps(img, stand, dark))
			if not side and trousers.get_region(r).get_data() != trousers.get_region(stand).get_data():
				stepped += 1
		crouched += 1 if tops == [top, top + 1, top + 1, top] else 0
		reached += 1 if hands[1] == fh - 2 and hands[2] == hands[1] - 1 and hands[0] < hands[2] and hands[3] < hands[0] else 0
	_check(crouched == 8, "reaching, the body crouches in the two middle frames: in %d directions of 8" % crouched)
	_check(reached == 8, "the hand goes down with the crouch to a row over the ground, back up short, then to the shoulder: in %d directions of 8" % reached)
	_check(apart == 0, "the reaching arm lies against the body, the legs alone stand apart: %d gaps more or fewer than standing" % apart)
	_check(stepped == 0, "the legs stand as they stood while a hand reaches: they differ in %d frames" % stepped)


# How many times the rows of frame `r` of `img` are broken: empty pixels or ones of the
# outline, `dark`, with the figure's own on both sides of them (standing, only between the
# legs).
func _gaps(img: Image, r: Rect2i, dark: Color) -> int:
	var found := 0
	for y in range(r.position.y, r.end.y):
		var last := -1
		for x in range(r.position.x, r.end.x):
			var p := img.get_pixel(x, y)
			if p.a < 0.5 or p == dark:
				continue
			if last >= 0 and x - last > 1:
				found += 1
			last = x
	return found


## Footprints: stone takes them only under a roof (the dust of a cave floor); a print is
## a kind, a level and a time in the map of the ground, cleared when its time is over and
## when the player has gone so far that its place comes back as other ground.
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
	_check(t._living.is_empty(), "no prints on stone in the open")
	w.set_cell(1, 3, 1, Mat.STONE)
	t.leave(feet, Vector2(0, 1), true, true, 1.0)
	_check(t._living.size() == 1, "prints on the stone floor of a cave")
	var texels: PackedInt32Array = t._living[0][2] if t._living.size() == 1 else PackedInt32Array()
	_check(texels.size() == 5, "a boot is five texels (%d)" % texels.size())
	var first := texels[0] if not texels.is_empty() else 0
	var mark := t.image.get_pixel(first % Tracks.MAP, first / Tracks.MAP)
	var r := roundi(mark.r * 255.0)
	_check(r >> 5 == Tracks.DUST and r & 31 == 1, "the print names its kind and level (%d)" % r)
	t.elapsed += Tracks.LIFE[Tracks.DUST] + 1.0
	t._expire()
	_check(t._living.is_empty() and t.image.get_pixel(first % Tracks.MAP, first / Tracks.MAP).r == 0.0,
		"a print is cleared when its time is over")
	t.leave(feet, Vector2(1, 0), false, false, 1.0)
	_check(t._living.size() == 1, "a paw print on the cave floor")
	t.focus = Vector3(Tracks.REACH * 3.0, 0.0, 0.0)
	t._follow()
	var any := false
	for packed: int in t._living[0][2]:
		any = any or t.image.get_pixel(packed % Tracks.MAP, packed / Tracks.MAP).r > 0.0
	_check(not any, "the map is cleared where the player has gone far from")
	# Grass is trodden down by the same strides, on any ground (trample.gd).
	var tr = t.trample
	tr.focus = Vector3.ZERO
	tr._follow()
	w.set_cell(1, 3, 1, Mat.AIR)
	t.focus = Vector3.ZERO
	t._follow()
	var trodden: int = tr._living.size()
	var printed: int = t._living.size()
	t.leave(feet, Vector2(1, 0), true, true, 1.0)
	_check(tr._living.size() == trodden + 1 and t._living.size() == printed,
		"a stride treads the grass, though the stone takes no print")
	var trod: PackedInt32Array = tr._living[-1][2] if not tr._living.is_empty() else PackedInt32Array()
	_check(trod.size() >= 8, "a person treads a disc of grass (%d texels)" % trod.size())
	var centre := Vector2i(posmod(floori(feet.x * Trample.TEXELS), Trample.MAP), posmod(floori(feet.z * Trample.TEXELS), Trample.MAP))
	var push: Color = tr.image.get_pixelv(centre)
	var g := roundi(push.g * 255.0)
	_check(push.a > 0.5 and g / Trample.DIRS >= 2 and g % Trample.DIRS in [0, 1, Trample.DIRS - 1],
		"the middle of the path is laid hard the way it was walked, east (%d)" % g)
	tr.elapsed += Trample.LIFE + 2.0
	tr._expire()
	_check(tr._living.is_empty() and tr.image.get_pixelv(centre).a == 0.0, "trodden grass stands up again")
	# A new print and its trodden grass go to the renderer within SOON, not with the next
	# FLUSH: the print shows the moment the foot comes down.
	w.set_cell(1, 3, 1, Mat.STONE)
	t._process(Tracks.FLUSH)
	tr.step(Trample.FLUSH)
	t.leave(feet, Vector2(1, 0), true, true, 1.0)
	t._process(Tracks.SOON * 0.5)
	tr.step(Trample.SOON * 0.5)
	_check(t._dirty and tr._dirty, "maps just sent wait a moment for the next print")
	t._process(Tracks.SOON * 0.5)
	tr.step(Trample.SOON * 0.5)
	_check(not t._dirty and not tr._dirty, "a new print and its grass are sent within SOON (%s, %s)" % [t._dirty, tr._dirty])
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
	# Slopes lay their tiles by the step the camera is nearest to, which holds still
	# while it turns or tilts between steps (rest_view in common.gdshaderinc).
	var rest := PixelView.rest_of(0.3, 0.1)
	var turned := PixelView.rest_of(0.5, -0.2)
	_check(rest.is_equal_approx(Vector3(0.0, -1.0, 1.0)), "a slight turn keeps the slopes' rest view")
	_check(turned.is_equal_approx(Vector3(-sqrt(0.5), -sqrt(0.5), 1.25)), "past halfway the slopes take the next step's view")


## The sounds load (loops looping), nothing sounds before the browser lets it, the
## hands' work sounds by what it strikes, and a piece of music stays in its range.
## The view in layers: behind the player and below their feet all stays; in front the
## first slices keep the density, then fade out over the stretch; the levels over the
## head the same; on a diagonal view a step along either axis is a slice.
func _test_cave_layers() -> void:
	var up := PixelView.up
	PixelView.up = Vector2(0.0, -1.0)
	var base := Vector3i(10, 20, 10)
	var fade := Vector4i(1, 2, 1, 4)
	var at := func(dx: int, dy: int, dz: int) -> float: return CaveLayers.share(base + Vector3i(dx, dy, dz), base, fade, 0.5)
	_check(at.call(0, 0, -3) == 1.0 and at.call(0, 1, -1) == 1.0 and at.call(3, 0, 0) == 1.0,
		"layers: behind and beside the player all stays")
	_check(at.call(0, -1, 5) == 1.0, "layers: the floor in front stays (the line at the feet)")
	_check(at.call(0, 0, 1) == 0.5 and at.call(0, 1, 2) == 0.25 and at.call(0, 0, 3) == 0.0,
		"layers: slices in front fade out past the first")
	_check(at.call(0, 2, -2) == 1.0 and at.call(0, 9, 0) == 1.0, "layers: over the player and behind all stays")
	_check(at.call(0, 0, 1) == 0.5 and at.call(0, 2, 1) == 0.25 and at.call(0, 4, 1) == 0.0,
		"layers: levels in front fade out up from the line past the first")
	_check(CaveLayers.share(base + Vector3i(0, 1, 1), base, fade, 0.5, 2) == 1.0
		and CaveLayers.share(base + Vector3i(0, 2, 1), base, fade, 0.5, 2) == 0.5,
		"layers: the line at the head keeps the legs whole")
	_check(at.call(0, 2, 2) == 0.25, "layers: the less of the two")
	_check(is_equal_approx(CaveLayers.layer_share(1, -2, 4, 0.5), 0.125) and CaveLayers.layer_share(2, -2, 4, 0.5) == 0.0,
		"layers: first layers below 0 start the fade before the first")
	PixelView.up = Vector2(-1.0, -1.0).normalized()
	_check(at.call(1, 0, 0) == 0.5 and at.call(1, 0, 1) == 0.25, "layers: a diagonal view slices diagonally")
	PixelView.up = up


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
	# The main menu's buttons click before the world is built (Sound.build): on a PC the
	# sound is on from the start, and the release build crashed on a click from no voice.
	s.unlocked = true
	s.play("click")
	s.play("plants:chop", Vector3.ZERO)
	_check(s._ui_voices.size() == SoundScript.UI_VOICES and s._ui_voices[0].stream != null,
		"a button clicks before the world is built")
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


class _FakeCharacter:
	var vitals := Vitals.new()
	var vessel := 0
	var riding := ""


class _FakeGame:
	var settings := _FakeSettings.new()
	var player := Node3D.new()
	var chunks = null
	var effects = null
	var character := _FakeCharacter.new()


## Left alone a minute the view drifts round the player by itself; any input stops it
## and it settles on a step. Short of sleep it does not turn: the picture swims instead.
func _test_camera_drift() -> void:
	var game := _FakeGame.new()
	var rig = CameraRig.new(game)
	rig.look_at_player()
	game.character.vitals.energy = 0.0
	for i in 90:
		rig._tire(1.0 / 30.0)
		rig._glide(1.0 / 30.0)
	_check(rig.turn == 0.0, "short of sleep the view stays as it was set")
	_check(rig.sway > 0.0 and rig.drowsiness() == 1.0, "and the picture swims: %.3f" % rig.sway)
	game.character.vitals.energy = Vitals.MAX
	for i in 300:
		rig._tire(1.0 / 30.0)
	_check(rig.sway == 0.0, "rested, the picture is still again")
	rig.idle = CameraRig.IDLE_TIME - 1.0
	for i in 30:
		rig._tire(1.0 / 30.0)
		rig._glide(1.0 / 30.0)
	_check(rig.turn == 0.0, "a second short of a minute alone, the view still stays")
	for i in 150:
		rig._tire(1.0 / 30.0)
		rig._glide(1.0 / 30.0)
	_check(rig.turn > 0.05 and rig.turn < CameraRig.DRIFT_RATE * 5.1, "left alone a minute it drifts round, slowly: %.3f" % rig.turn)
	var first: Vector2 = PixelView.box_views[0][0]
	var last: Vector2 = PixelView.box_views[-1][0]
	_check(PixelView.box_views.size() > 1 and absf(first.angle_to(last)) >= CameraRig.SPIN_AHEAD - 0.001
		and absf(first.angle_to(last)) <= CameraRig.SPIN_AHEAD + 0.001, "drifting, the culling boxes hold the views a way ahead")
	game.player.position.x += 1.0
	rig._tire(1.0 / 30.0)
	_check(rig.idle == 0.0, "the player walking is not being left alone")
	rig.idle = CameraRig.IDLE_TIME + 10.0
	rig._glide(1.0 / 30.0)
	rig.wake()
	for i in 120:
		rig._glide(1.0 / 30.0)
	_check(rig.turn == posmod(rig.turn_steps, CameraRig.TURNS) * CameraRig.TURN_STEP, "on any input it settles on a step: %.3f" % rig.turn)
	# Stopped, it starts again after the next minute alone, though the body bobs a hair
	# at a time and the mouse twitches a pixel.
	var settled: float = rig.turn
	var twitch := InputEventMouseMotion.new()
	twitch.relative = Vector2(1.0, 0.0)
	var t := 0.0
	while t < CameraRig.IDLE_TIME + 3.0:
		rig._tire(1.0 / 30.0)
		rig._glide(1.0 / 30.0)
		game.player.position += Vector3(0.002 * sin(t * 7.0), 0.01 * sin(t * 3.0), 0.0)
		rig.wake(twitch)
		t += 1.0 / 30.0
	_check(rig.is_drifting() and rig.turn != settled, "after the next minute alone it drifts again: idle %.1f" % rig.idle)
	var shove := InputEventMouseMotion.new()
	shove.relative = Vector2(20.0, 0.0)
	rig.wake(shove)
	rig._glide(1.0 / 30.0)
	_check(not rig.is_drifting(), "a real move of the mouse stops it again")
	game.player.free()


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
	# Turning on, the culling boxes hold the views from here SPIN_AHEAD on, not all round
	# (that drew twice the chunks), and are fitted again as the view gets past them.
	var ahead := func() -> bool:
		var first: Vector2 = PixelView.box_views[0][0]
		var last: Vector2 = PixelView.box_views[-1][0]
		var now: Vector2 = PixelView.view_of(rig.turn, rig.tilt)[0]
		var ends := now.angle_to(first) >= -0.001 and now.angle_to(last) <= 0.001
		return PixelView.box_views.size() <= ceili(CameraRig.SPIN_AHEAD / CameraRig.BOX_STEP) + 1 and ends \
			and absf(first.angle_to(last)) <= CameraRig.SPIN_AHEAD + 0.001
	_check(ahead.call(), "turning on, the culling boxes hold the views a little way ahead")
	var boxes: Array = PixelView.box_views
	while t < 3.0:
		rig._glide(1.0 / 30.0)
		t += 1.0 / 30.0
	_check(not is_same(boxes, PixelView.box_views) and ahead.call(), "turning on past them, the boxes are fitted again ahead")
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


## A world of other bundles after this one (the scene started again: static vars stay):
## once forgotten, the atlas's colours and the meshers' materials are the new numbering's,
## so the biomes' tints of sand stay sand's and do not turn it purple (2026-11-02).
func _test_other_bundles() -> void:
	var before := Content.BUNDLES.duplicate()
	var full: Array = Mods.resolve(Mods.all()).order
	Mods.activate(full)
	PixelTextures.forget()
	var sand := Mat.index("resources:sand")
	var own := PixelTextures.tint(sand)
	# A set without one mod that comes before sand, so sand's number moves, when there is one.
	var fewer: Array = full
	for mod: String in Mods.available():
		if mod == "core" or mod == "resources":
			continue
		var without: Array = Mods.resolve(full.filter(func(b: String) -> bool: return Mods.mod_of(b) != mod)).order
		Mods.activate(without)
		if Mat.index("resources:sand") >= 0 and Mat.index("resources:sand") != sand:
			fewer = without
			break
	Mods.activate(fewer)
	var moved := Mat.index("resources:sand")
	PixelTextures.forget()
	MeshFaces.forget()
	_check(moved >= 0 and PixelTextures.tint(moved).is_equal_approx(own) and MeshFaces.LEAVES == Mat.LEAVES
		and MeshFaces.WATER == Mat.WATER and MeshFaces.covers_table()[Mat.AIR] == 0,
		"after other bundles sand keeps its colour at its new number (%d -> %d) and the meshers their materials" % [sand, moved])
	Mods.activate(before)
	PixelTextures.forget()
	MeshFaces.forget()


## The maps the drawn fire shadows look up (FireShadows._map_blockers): a shut door keeps
## the light out up its whole height, a window lets it through, an open door too.
func _test_light_maps() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	var placed := Placed.new()
	placed.world = w
	placed.read_footprints()
	var door: Dictionary = placed.put("tools:door", Vector3i(10, 4, 10))
	placed.put("tools:window_1x2", Vector3i(14, 5, 10))
	_check(not Placed.lets_light(door) and Placed.lets_light(placed.things[-1]), "a window lets the light through, a door not")
	var shadows = FireShadows.new()
	shadows.game = {"placed": placed}
	var m := {"origin": Vector2i(0, 0), "level": 4, "data": PackedByteArray()}
	m.data.resize(FireShadows.MAP * FireShadows.MAP_ROWS_TALL)
	shadows._map_blockers(w, m)
	var solid := func(c: Vector3i) -> bool:
		var y: int = c.y - (m.level - FireShadows.BELOW)
		return m.data[(y >> 3) * FireShadows.MAP * FireShadows.MAP + c.z * FireShadows.MAP + c.x] & (1 << (y & 7)) != 0
	_check(solid.call(Vector3i(10, 4, 10)) and solid.call(Vector3i(10, 5, 10)) and not solid.call(Vector3i(10, 6, 10)),
		"a shut door two cells tall keeps the light out of both")
	_check(not solid.call(Vector3i(14, 5, 10)) and not solid.call(Vector3i(14, 6, 10)), "a window lets it through")
	placed.swing(null, door)
	m.data.fill(0)
	shadows._map_blockers(w, m)
	_check(door.open and not solid.call(Vector3i(10, 4, 10)), "an open door lets it through")
	shadows.free()


## The fog over the chunks not built (EdgeHaze): a missing chunk's fog is whole at once,
## a built one's dissolves over DISSOLVE and is dropped; the quad covers the fog and a
## chunk round it, on the plane of the ground.
func _test_edge_haze() -> void:
	var amounts := {}
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	_check(EdgeHaze.step(amounts, [a, b] as Array[Vector2i], 0.0) and amounts == {a: 1.0, b: 1.0},
		"the chunks missing are covered whole at once")
	EdgeHaze.step(amounts, [a] as Array[Vector2i], EdgeHaze.DISSOLVE * 0.5)
	_check(amounts[a] == 1.0 and is_equal_approx(amounts[b], 0.5), "a chunk built dissolves: %s" % [amounts])
	EdgeHaze.step(amounts, [a] as Array[Vector2i], EdgeHaze.DISSOLVE)
	_check(amounts == {a: 1.0}, "and is dropped once clear")
	_check(EdgeHaze.cover([a, b]) == Rect2i(-1, -1, 4, 3), "the quad covers the fog and a chunk round it")
	var mesh := EdgeHaze.build_mesh(Rect2i(0, 0, 1, 1), 1.0)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ok := verts.size() == 6
	for v in verts:
		ok = ok and v.y == 1.0 and v.x >= 0.0 and v.x <= 8.0 and v.z >= 0.0 and v.z <= 8.0
	_check(ok, "one quad over the chunks, on the plane of the ground")


## The graphics quality the game picks itself: the steps run from «высокое» through
## «среднее» to «низкое»; slow windows step down, a minute of fast ones tries a step up,
## a try that slows the game is taken back and becomes the ceiling.
func _test_auto_quality() -> void:
	var high: Dictionary = SettingsScript.QUALITIES[2]
	_check(AutoQuality.step_values(0, high) == high, "the first step is the high preset")
	_check(AutoQuality.step_values(3, high) == SettingsScript.QUALITIES[1], "a step on the way is the medium preset")
	_check(AutoQuality.step_values(AutoQuality.STEPS.size() - 1, high) == SettingsScript.QUALITIES[0],
		"the last step is the low preset")
	for st in AutoQuality.STEPS:
		for k in st:
			_check(high.has(k), "a step changes graphics settings alone: %s" % k)
	var s := FakeSettings.new()
	s.values = SettingsScript.DEFAULTS.duplicate()
	s.values.merge(high, true)
	var auto := AutoQuality.new({"settings": s, "hud": null})
	_check(auto.step() == 0, "the defaults are the first step")
	var slow := auto.down_fps() - 5.0
	var fast := auto.up_fps() + 1.0
	auto.window(slow)
	_check(auto.step() == 0, "one slow window is not enough")
	auto.window(slow)
	_check(auto.step() == 1, "two slow windows step down: %d" % auto.step())
	for i in AutoQuality.DOWN_WINDOWS * 3:
		auto.window(slow)
	_check(auto.step() == 4, "and on: %d" % auto.step())
	var ok := (auto.down_fps() + auto.up_fps()) / 2.0
	for i in AutoQuality.UP_WINDOWS * 2:
		auto.window(ok)
	_check(auto.step() == 4, "between the two it stays")
	for i in AutoQuality.UP_WINDOWS - 1:
		auto.window(fast)
	_check(auto.step() == 4, "not up before a minute")
	auto.window(fast)
	_check(auto.step() == 3, "a minute fast tries a step up")
	auto.window(slow)
	_check(auto.step() == 4 and s.values.auto_ceiling == 4, "a slow window in the try takes it back: %d, ceiling %d" % [auto.step(), s.values.auto_ceiling])
	for i in AutoQuality.UP_WINDOWS * 3:
		auto.window(fast)
	_check(auto.step() == 4, "and it does not go over the ceiling again")
	s.values.pixel_scale = 0
	_check(auto.step() == -1, "a mix of the player's own is no step")
	for i in AutoQuality.DOWN_WINDOWS * 2:
		auto.window(slow)
	_check(s.values.pixel_scale == 0, "and is left alone")
	auto.turn_on()
	_check(auto.step() == 0 and s.values.auto_ceiling == 0 and s.values.auto_quality, "«Авто» picked starts from the top")


## A line the player says (their own id from the server, -1 in single player) hangs in a
## balloon over their own head; one of nobody known shows none.
func _test_own_balloon() -> void:
	var others = Others.new()
	others.game = FakeGame.new()
	others.speak(7, "who?")
	_check(others._own.is_empty(), "a line of one not seen makes no balloon")
	others.speak(5, "hello")
	_check(not others._own.is_empty() and others._own.line.visible and others._own.said.text == "hello",
		"the player's own line on a server shows over their head")
	others._own.line.visible = false
	others.speak(-1, "alone")
	_check(others._own.line.visible and others._own.said.text == "alone", "and in single player")
	others.free()


## A global texture replaced lives on a while (Vulkan can still draw with it), and the
## fires' heat map is drawn again in its own texture rather than a new one each time.
func _test_global_textures() -> void:
	var e = Effects.new()
	var first: ImageTexture = e.heat_map(16)
	e.fires.append({"unit": Vector3i(3, 2, 3)})
	var second: ImageTexture = e.heat_map(16)
	_check(first == second,
		"the heat map is drawn again in the same texture")
	e.free()
	var a := ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_R8))
	var b := ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_R8))
	var c := ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_R8))
	var held := PixelTextures._replaced.size()
	PixelTextures.set_global("heat_map", a)
	PixelTextures.set_global("heat_map", b)
	PixelTextures.set_global("heat_map", c)
	var kept := PixelTextures._replaced.slice(held).map(func(r: Array) -> Texture2D: return r[0])
	_check(kept.has(a) and kept.has(b), "a global texture replaced twice in a row is still held")
	PixelTextures.forget()
	_check(PixelTextures._replaced.any(func(r: Array) -> bool: return r[0] == a),
		"a texture replaced lives on through the next scene")
	for i in PixelTextures.HOLD_SCENES:
		PixelTextures.forget()
	_check(not PixelTextures._replaced.any(func(r: Array) -> bool: return r[0] == a),
		"and goes %d scenes later" % (PixelTextures.HOLD_SCENES + 1))


## Night and snow for GlowLights.
class FakeSky:
	var daylight := 0.0


class FakeClock:
	var snow := 0.0


## The glowing mushrooms nearest the view get a light at night, one a group; none by
## day or under snow, and none once their chunk is gone.
func _test_glow_lights() -> void:
	var g = GlowLights.new()
	g._ready()
	var sky := FakeSky.new()
	var clock := FakeClock.new()
	# A group of three mushrooms close together, two lone ones, one far off.
	g.set_spots(Vector2i(0, 0), PackedVector3Array([Vector3(1.0, 0.0, 1.0), Vector3(1.5, 0.0, 1.2),
		Vector3(1.2, 0.0, 1.8), Vector3(5.0, 0.0, 1.0), Vector3(1.0, 0.0, 6.0)]))
	g.set_spots(Vector2i(5, 0), PackedVector3Array([Vector3(45.0, 0.0, 1.0)]))
	g.update(0.1, PixelView.screen_plane(Vector3(2.0, 0.0, 2.0)), sky, clock)
	var lit: Array = g.lights.filter(func(l: OmniLight3D) -> bool: return l.visible)
	_check(lit.size() == 3 and lit.all(func(l: OmniLight3D) -> bool: return l.light_energy > 0.0),
		"three groups of glowing mushrooms near the view are lit at night, the far one not (%d)" % lit.size())
	sky.daylight = 1.0
	g.update(0.1, PixelView.screen_plane(Vector3(2.0, 0.0, 2.0)), sky, clock)
	_check(g.lights.all(func(l: OmniLight3D) -> bool: return not l.visible), "no mushroom lights by day")
	sky.daylight = 0.0
	clock.snow = 1.0
	g.update(0.1, PixelView.screen_plane(Vector3(2.0, 0.0, 2.0)), sky, clock)
	_check(g.lights.all(func(l: OmniLight3D) -> bool: return not l.visible), "no mushroom lights under snow")
	clock.snow = 0.0
	g.set_spots(Vector2i(0, 0), PackedVector3Array())
	g.update(0.1, PixelView.screen_plane(Vector3(2.0, 0.0, 2.0)), sky, clock)
	_check(g.lights.all(func(l: OmniLight3D) -> bool: return not l.visible), "no lights once the chunk is gone")
	g.free()


## A new scene's fire shadows draw nothing until there are shadows: hidden, every
## instance zeroed (a phone drew an unwritten buffer as long coloured wedges).
func _test_fire_shadows_blank() -> void:
	var f = FireShadows.new()
	f._ready()
	var b: PackedFloat32Array = f.multimesh.buffer
	_check(not f.visible and b.size() == FireShadows.MAX_SHADOWS * 20 and b.count(0.0) == b.size(),
		"fire shadows start hidden with every instance zeroed")
	f.free()


## How light it is round a window, for WindowGlow.
class WindowSky:
	var sky_light := 0.0

	func charge_gain(_left: float) -> float:
		return 1.0


## A window glows at night with a light lit under the roof of its room, from the side
## away from the light; not by day, not for a light out in the open, not for one far off,
## and not once it is taken away; its glass alone (not the frame) is drawn.
func _test_window_glow() -> void:
	var g = WindowGlow.new()
	var model = VoxelProps.prop("window_1x2")
	var node := MeshInstance3D.new()
	node.mesh = model.build_mesh()
	node.scale = Vector3.ONE / 16.0
	var cell := Vector3i(10, 4, 10)
	g.add(cell, node, model)
	var sky := WindowSky.new()
	var mid: Vector3 = g.windows[cell].mid
	var inside := mid + Vector3(0.0, -0.3, -2.0)
	var lamps: Array = [{"at": inside, "placed": {}, "reach": 7.0}]
	var roofed := func(p: Vector3) -> bool: return p.z < mid.z
	for i in 20:
		g.update(0.1, sky, [], lamps, roofed)
	var w: Dictionary = g.windows[cell]
	_check(w.amount > 0.3 and w.glow != null and w.glow.visible, "a window glows at night with a lamp in its room (%.2f)" % w.amount)
	var mat: ShaderMaterial = w.glow.material_override
	_check((mat.get_shader_parameter("source") as Vector3).is_equal_approx(inside), "its glass glows away from the lamp")
	var glass: ArrayMesh = w.glow.mesh
	_check(glass.get_aabb().size.z < 4.0 and glass.get_aabb().size.x < node.mesh.get_aabb().size.x,
		"only the glass glows, not the frame")
	sky.sky_light = 1.0
	g._wait = 0.0
	for i in 40:
		g.update(0.1, sky, [], lamps, roofed)
	_check(w.amount == 0.0 and not w.glow.visible, "no glow by day")
	sky.sky_light = 0.0
	lamps[0].at = mid + Vector3(0.0, -0.3, 2.0)
	g._wait = 0.0
	g.update(0.1, sky, [], lamps, roofed)
	_check(w.target == 0.0, "a lamp out in the open does not light the glass")
	lamps[0].at = mid + Vector3(0.0, -0.3, -9.0)
	g._wait = 0.0
	g.update(0.1, sky, [], lamps, roofed)
	_check(w.target == 0.0, "a lamp beyond its reach does not either")
	g.remove(cell)
	_check(g.windows.is_empty(), "a window taken away is forgotten")
	node.free()


## The rainbow (AirEffects._rainbow): it comes after rain with the sun out by day, and
## not in the rain, under thick clouds, at night, under a roof or long after the rain.
func _test_rainbow() -> void:
	var air = AirEffects.new({"view": null}, null)
	var sky := {"sun_height": 0.2, "to_sun": Vector3(0.6, 0.4, 0.5), "after_rain": 1.0}
	var clock := {"rain": 0.0, "hail": 0.0, "snowing": 0.0, "clouds": 0.3, "fog": 0.0}
	var after := func(changes: Dictionary, indoor := false) -> float:
		var s := sky.duplicate()
		var c := clock.duplicate()
		for k: String in changes:
			if s.has(k):
				s[k] = changes[k]
			else:
				c[k] = changes[k]
		air.rainbow = 0.0
		for i in 100:
			air._rainbow(1.0, true, s, c, indoor)
		return air.rainbow
	_check(after.call({}) > 0.9, "rainbow: after rain with the sun out")
	_check(after.call({"rain": 0.5}) == 0.0, "rainbow: none in the rain")
	_check(after.call({"clouds": 0.8}) == 0.0, "rainbow: none under thick clouds")
	_check(after.call({"sun_height": -0.3}) == 0.0, "rainbow: none at night")
	_check(after.call({"after_rain": 0.0}) == 0.0, "rainbow: none long after the rain")
	_check(after.call({}, true) == 0.0, "rainbow: none under a roof")
	_check(after.call({"sun_height": 1.0}) < after.call({"sun_height": 0.2}), "rainbow: fainter at noon")
	air.free()


## A game with only the water's material and a player, and a sky with only its wind, for
## WaterEffects._waves.
class WaveGame:
	var water_mat := ShaderMaterial.new()
	var player = 1


class WindSky:
	var wind_now := Vector2.ZERO


## The wind's waves run the nearest of 8 ways to the wind at once at first; later they
## turn only once it is well off their way (not back and forth for a wind between two),
## dithered over WAVE_TURN seconds; hidden with their part.
func _test_wave_ways() -> void:
	var water = WaterEffects.new(WaveGame.new(), null)
	var sky := WindSky.new()
	sky.wind_now = Vector2(0.0, 2.0)
	water._waves(0.1, sky)
	var v: Vector4 = water.game.water_mat.get_shader_parameter("waves")
	_check(v == Vector4(2.0, 2.0, 1.0, 1.0), "a wind to the south runs the waves south at once (%s)" % v)
	sky.wind_now = Vector2(1.0, 1.4)
	water._waves(0.1, sky)
	v = water.game.water_mat.get_shader_parameter("waves")
	_check(v.x == 2.0 and v.y == 1.0 and v.z < 0.1, "a wind turned well to the south-east starts turning them (%s)" % v)
	for i in 40:
		water._waves(0.1, sky)
	v = water.game.water_mat.get_shader_parameter("waves")
	_check(v.y == 1.0 and v.z == 1.0, "and they have turned after WAVE_TURN seconds (%s)" % v)
	sky.wind_now = Vector2(cos(deg_to_rad(70.0)), sin(deg_to_rad(70.0))) * 2.0
	water._waves(0.1, sky)
	v = water.game.water_mat.get_shader_parameter("waves")
	_check(v.y == 1.0 and v.z == 1.0, "a wind nearer south but not well off keeps them (%s)" % v)
	water.hidden[WaterEffects.WAVES_PART] = true
	water._waves(0.1, sky)
	v = water.game.water_mat.get_shader_parameter("waves")
	_check(v.w == 0.0, "hidden, the shader is told so (%s)" % v)
	water.free()


## The small effects (AirEffects, WaterEffects, NatureEffects): each part can be hidden
## in «Что рисуется» on its own by a name of its own, the low preset turns them all off
## and the medium one the costliest (the mirroring and the heat), and a dragonfly's
## picture is its pixels.
func _test_small_effects() -> void:
	var names := {}
	var all := []
	for script in [AirEffects, WaterEffects, NatureEffects]:
		var part = script.new(null, null)
		for p: Array in part.parts():
			all.append(p[0])
			names[p[0]] = part
			p[1].call(true)
		_check(part.hidden.size() == part.parts().size(), "%s: each part hides" % script.resource_path.get_file())
		for p: Array in part.parts():
			p[1].call(false)
		_check(part.hidden.is_empty(), "%s: and shows again" % script.resource_path.get_file())
		if part is Node:
			part.free()
	_check(names.size() == all.size() and all.size() == 16, "sixteen parts, each named once: %s" % [all])
	_test_rainbow()
	_test_wave_ways()
	var low: Dictionary = SettingsScript.QUALITIES[0]
	var medium: Dictionary = SettingsScript.QUALITIES[1]
	_check(low.water_fx == 0 and not low.nature_fx and not low.body_fx and not low.heat_fx and not low.drops_fx,
		"the low preset draws none of the small effects")
	_check(medium.water_fx == 1 and not medium.heat_fx and medium.drops_fx, "the medium one leaves out the mirroring and the heat")
	var fly: ImageTexture = NatureEffects._shape(NatureEffects.FLY_UP)
	_check(fly.get_width() == 5 and fly.get_height() == 3 and fly.get_image().get_pixel(0, 0).a > 0.5,
		"a dragonfly is five pixels long with its wings up")


## The air trembles over the ground only over sand and the sea.
func _test_hot_ground() -> void:
	var sand := -1
	for i in Mat.RECORDS.size():
		if Mat.RECORDS[i].get("ground", "") == "sand":
			sand = i
			break
	var w := FakeGround.new()
	w.top = Mat.GRASS
	_check(AirEffects.hot_ground(w, Vector3.ZERO) == 0.0, "no heat haze over grass")
	w.top = sand
	_check(sand < 0 or AirEffects.hot_ground(w, Vector3.ZERO) == 1.0, "heat haze over sand")
	w.water = true
	_check(AirEffects.hot_ground(w, Vector3.ZERO) == 1.0, "heat haze over the sea")


## New sun light dissolves in while the old dissolves out, one change at a time; the
## same light again changes nothing; a screenshot's light is shown at once.
func _test_rays_dissolve() -> void:
	var r = SunRays.new()
	r._ready()
	var one := PackedFloat32Array()
	SunRays._put(one, Vector3(1, 2, 3), Color(0.5, 4.0, 0.1, 1.0))
	var two := PackedFloat32Array()
	SunRays._put(two, Vector3(5, 2, 3), Color(0.5, 4.0, 0.1, 1.0))
	r._show(one, PackedFloat32Array())
	var front: int = r._front
	_check(r._fade == 0.0 and r.shafts[front].multimesh.visible_instance_count == 1,
		"new light starts dissolving in")
	_check(r._mats[(1 - front) * 2].get_shader_parameter("fade_out") == true, "and the old dissolving out")
	r._show(two, PackedFloat32Array())
	_check(r._front == front and r._waiting.size() == 2, "the next change waits for this one")
	r._dissolve(1.0)
	_check(r._front != front and r._fade == 0.0 and r.shafts[r._front].multimesh.visible_instance_count == 1,
		"then dissolves in in its turn")
	r._dissolve(1.0)
	_check(r.shafts[front].multimesh.visible_instance_count == 0, "the old light is gone when done")
	var now: int = r._front
	r._show(two, PackedFloat32Array())
	_check(r._front == now and r._fade == 1.0, "the same light again changes nothing")
	r._show(one, PackedFloat32Array(), true)
	_check(r._front == now and r._fade == 1.0 and r.shafts[now].multimesh.visible_instance_count == 1,
		"a screenshot's light is shown at once")
	r.free()


## An animal struck flinches as the blow lands, not before: its picture jerks up and away
## from the one who struck, flashes red, shakes back and stands where it was again; another player's
## blow is found by its point, only on an animal there within the striker's reach.
func _test_animal_flinch() -> void:
	var c := CreaturesView.new()
	c._build_looks()
	var w := RemoteWildlife.new()
	c.wildlife = w
	var a := RemoteWildlife.Animal.new()
	a.kind = "animals:deer"
	a.pos = Vector3(10.0, 3.0, 10.0)
	w.animals.append(a)
	c._on_born(a)
	var sprite := c.sprite_of(a)
	var rest := PixelView.snap(a.pos)
	var west := a.pos - Vector3(1.0, 0.0, 0.0)
	c.flinch(a, 0.1, west)
	c._process(0.05)
	_check(sprite != null and sprite.position == rest, "a struck animal stands still till the blow lands")
	c._process(0.051)
	var off := (sprite.position - rest) * PixelView.PIXELS_PER_UNIT
	var away := signf(PixelView.screen_dir(Vector2(1.0, 0.0)).x)
	var along := Vector2(off.x, off.z).dot(PixelView.right) * away
	_check(roundf(off.y) == CreaturesView.FLINCH_UP and roundf(along) == CreaturesView.FLINCH_PX,
		"as the blow lands it jerks up and away from the blow (%s)" % off)
	_check(PixelView.sprite_flash(sprite) == PixelView.FLASH_STEPS, "and flashes wholly red")
	# A fire's shadow on it meanwhile keeps the flash, and the flash the shade.
	PixelView.shade_sprite(sprite, 0.3)
	_check(PixelView.sprite_flash(sprite) == PixelView.FLASH_STEPS and absf(PixelView.sprite_shade(sprite) - 0.3) < 1e-4,
		"a fire's shadow on a flashing animal keeps the flash")
	c._process(0.15)
	var fading := PixelView.sprite_flash(sprite)
	_check(fading > 0 and fading < PixelView.FLASH_STEPS, "the red fades (%d)" % fading)
	for i in 10:
		c._process(0.05)
	_check(sprite.position == rest and c._flinching.is_empty(), "the flinch is over: it stands where it was")
	_check(PixelView.sprite_flash(sprite) == 0 and absf(PixelView.sprite_shade(sprite) - 0.3) < 1e-4, "red no more, the shade kept (%s)" % sprite.scale.z)
	PixelView.shade_sprite(sprite, 1.0)
	_check(sprite.scale.z == 1.0, "a sprite out of shadow and flash has its scale along z 1 (%s)" % sprite.scale.z)
	var cull := sprite.custom_aabb
	_check(cull.position.z <= 0.0 and is_equal_approx(cull.end.z, -cull.position.z),
		"its culling box is even about z, so a shade or a flash only grows it (%s)" % cull)
	# Another player's blow, by its point.
	var other := a.pos + Vector3(0.6, 0.0, 0.0)
	c.struck_at(a.pos + Vector3(0.0, CreaturesView.BLOW_HEIGHT, 0.0), 0.0, other)
	c.struck_at(a.pos + Vector3(2.0, CreaturesView.BLOW_HEIGHT, 0.0), 0.0, other)
	c.struck_at(a.pos + Vector3(0.0, CreaturesView.BLOW_HEIGHT, 0.0), 0.0, a.pos + Vector3(6.0, 0.0, 0.0))
	_check(c._blows.size() == 1, "another's blow lands on the animal at its point, within their reach (%d)" % c._blows.size())
	c._process(0.01)
	_check(c._flinching.size() == 1, "and it flinches")
	c._on_gone(a)
	c._process(0.05)
	_check(c._flinching.is_empty(), "one gone flinches no more")
	c.free()


## The boar (tools/art/boar_art.gd, from the user's reference): a row of 24 frames, the
## walk, attack, run, hurt and death four each; it gallops as it flees, walks about,
## plays its hurt frames as a blow lands and its idle as one animation. Killed, its carcass
## comes before its going and waits for it, takes its sprite and falls as the blow lands,
## then lies on its last frame of death till taken; one in a chunk coming in view lies dead
## at once.
func _test_boar_states() -> void:
	var c := CreaturesView.new()
	c._build_looks()
	var kind := "animals:boar"
	var k: Array = c.looks.get(kind, [])
	_check(k.size() > 12 and k[3] == 24 and k[4] == 4 and k[7] == 4 and k[9] == 4 and k[10] == 4 and k[11] == 4 and k[12],
		"the boar's row: 24 frames, the walk, attack, run, hurt and death four each, the idle one animation")
	if k.size() <= 12:
		c.free()
		return
	var w := RemoteWildlife.new()
	c.wildlife = w
	var a := RemoteWildlife.Animal.new()
	a.kind = kind
	a.pos = Vector3(10.0, 3.0, 10.0)
	w.animals.append(a)
	c._on_born(a)
	var look = c._looks[a]
	var now := Time.get_ticks_msec() * 0.001
	var seen := {}
	a.moving = true
	a.state = "flee"
	for i in 12:
		look.walked = i * 0.25
		seen[c._frame(a, look, 0.0, now)] = true
	_check(seen.size() == 4 and seen.keys().all(func(f: int) -> bool: return f >= 12 and f < 16),
		"it gallops through its run frames as it flees (%s)" % [seen.keys()])
	seen.clear()
	a.state = "wander"
	for i in 12:
		look.walked = i * 0.15
		seen[c._frame(a, look, 0.0, now)] = true
	_check(seen.size() == 4 and seen.keys().all(func(f: int) -> bool: return f >= 1 and f < 5),
		"it walks about in its walk frames (%s)" % [seen.keys()])
	a.moving = false
	a.state = "bite"
	var bite: Array[int] = []
	look.bite_at = now
	for i in 4:
		bite.append(c._frame(a, look, 0.0, now + (i + 0.5) * Wildlife.BITE_TIME / 4.0))
	_check(bite == [8, 9, 10, 11], "it leaps to bite through its four attack frames (%s)" % [bite])
	a.state = "warn"
	_check(c._frame(a, look, 0.0, now) == 8, "warning one off, it shows the first")
	a.state = "wander"
	look.hurt_at = now
	_check(c._frame(a, look, 0.0, now) == 16 and c._frame(a, look, 0.0, now + CreaturesView.HURT_FRAME * 2.5) == 18,
		"a blow landed: its hurt frames one after another")
	_check(c._frame(a, look, 0.0, now + CreaturesView.HURT_FRAME * 4.5) == 0 and look.hurt_at < 0.0, "then it stands again")
	var idle: Array[int] = []
	var t: float = look.change_at
	for i in 4:
		idle.append(c._frame(a, look, 0.0, t + i * (CreaturesView.IDLE_FRAME + 0.01) + 0.01))
	_check(idle == [5, 6, 7, 0], "its idle plays through and it stands again (%s)" % [idle])
	# Killed: the carcass, naming it, comes first (with the things on the ground).
	var key := Vector2i(0, 0)
	var drop := ["animals:carcass", a.pos + Vector3(0.2, 0.0, 0.0), 0.0, {"n": 1, "body": kind}]
	c._lay_bodies(key, [drop], false, now)
	var lying: Array = c._bodies.get(key, {}).values()
	_check(lying.size() == 1 and lying[0].dies_at == INF and lying[0].sprite == null and look.body == lying[0],
		"its body waits for the beast drawn there to go")
	var waits_falling := c.falling(key, drop)
	var b = lying[0]
	c.flinch(a, 0.3, a.pos - Vector3(1.0, 0.0, 0.0))
	var sprite: MeshInstance3D = look.sprite
	c._on_gone(a)
	_check(b.sprite == sprite and b.dies_at > now + 0.2 and c._dying.has(b), "it takes the beast's sprite, to fall as the blow lands")
	var was_falling := waits_falling and c.falling(key, drop)
	c._bodies_step(b.dies_at + CreaturesView.FLASH_HOLD * 0.5)
	_check(b.frame == 0 and PixelView.sprite_flash(sprite) == PixelView.FLASH_STEPS,
		"it flashes red as the blow that kills it lands, as a flinch does")
	c._bodies_step(b.dies_at + CreaturesView.DEATH_FRAME * 1.5)
	_check(b.frame == 1 and c._dying.has(b) and PixelView.sprite_flash(sprite) == 0, "it falls through its frames of death, the red gone")
	c._bodies_step(b.dies_at + CreaturesView.DEATH_FRAME * 10.0)
	_check(b.frame == 3 and c._dying.is_empty() and sprite.material_override == c.looks[kind][1][0][b.view * 24 + 23],
		"and lies on its last")
	_check(was_falling and not c.falling(key, drop) and not c.falling(key, ["animals:carcass", drop[1], 0.0, 1]),
		"the action button waits while it is to fall or falls, and takes it lying (Controls._front_body)")
	c._lay_bodies(key, [drop], false, now + 5.0)
	_check(c._bodies[key].values()[0] == b, "it lies on while the carcass does")
	c._lay_bodies(key, [], false, now + 6.0)
	_check(not c._bodies.has(key) and b.sprite == null, "taken up, it is gone")
	c._lay_bodies(key, [drop], true, now + 7.0)
	var old = c._bodies[key].values()[0]
	_check(old.frame == 3 and old.sprite != null and c._dying.is_empty(), "one that lay there before its chunk came in view lies dead at once")
	c.hide_bodies(key)
	_check(not c._bodies.has(key), "out of view, it is put away")
	# Killed by one's own blow, the beast goes before the reply naming the blow comes
	# (Controls._did): its body waits a moment, then falls as the reply says the blade lands.
	var other := RemoteWildlife.Animal.new()
	other.kind = kind
	other.id = 7
	other.pos = Vector3(20.0, 3.0, 10.0)
	w.animals.append(other)
	c._on_born(other)
	var there := Vector2i(1, 0)
	c._lay_bodies(there, [["animals:carcass", other.pos, 0.0, {"n": 1, "body": kind}]], false, now)
	var felled = c._bodies[there].values()[0]
	var gone_at := Time.get_ticks_msec() * 0.001
	c._on_gone(other)
	_check(felled.beast == 7 and felled.dies_at >= gone_at and felled.dies_at <= Time.get_ticks_msec() * 0.001 + CreaturesView.BLOW_WAIT,
		"gone with no blow on it known, its body waits a moment for the reply")
	c.felled(7, 0.25)
	_check(felled.dies_at >= Time.get_ticks_msec() * 0.001 + 0.2, "the reply tells when the blade meets it, and it falls then")
	c.hide_bodies(there)
	_check(c._dying.is_empty(), "put away, it dies no more")
	c.free()


## The fox (tools/art/fox_art.gd, from the user's reference): a row of 20 frames, the walk,
## run, hurt and death four each and no attack (so the run follows the idle); it gallops as
## it flees, walks about, plays its hurt frames as a blow lands and its idle as one
## animation; killed, it falls through its frames of death and lies on the last.
func _test_fox_states() -> void:
	var c := CreaturesView.new()
	c._build_looks()
	var kind := "animals:fox"
	var k: Array = c.looks.get(kind, [])
	_check(k.size() > 12 and k[3] == 20 and k[4] == 4 and k[7] == 0 and k[9] == 4 and k[10] == 4 and k[11] == 4 and k[12],
		"the fox's row: 20 frames, the walk, run, hurt and death four each, no attack, the idle one animation")
	if k.size() <= 12:
		c.free()
		return
	var w := RemoteWildlife.new()
	c.wildlife = w
	var a := RemoteWildlife.Animal.new()
	a.kind = kind
	a.pos = Vector3(10.0, 3.0, 10.0)
	w.animals.append(a)
	c._on_born(a)
	var look = c._looks[a]
	var now := Time.get_ticks_msec() * 0.001
	var seen := {}
	a.moving = true
	a.state = "flee"
	for i in 12:
		look.walked = i * 0.25
		seen[c._frame(a, look, 0.0, now)] = true
	_check(seen.size() == 4 and seen.keys().all(func(f: int) -> bool: return f >= 8 and f < 12),
		"the fox gallops through its run frames as it flees (%s)" % [seen.keys()])
	seen.clear()
	a.state = "wander"
	for i in 12:
		look.walked = i * 0.15
		seen[c._frame(a, look, 0.0, now)] = true
	_check(seen.size() == 4 and seen.keys().all(func(f: int) -> bool: return f >= 1 and f < 5),
		"the fox walks about in its walk frames (%s)" % [seen.keys()])
	a.moving = false
	look.hurt_at = now
	_check(c._frame(a, look, 0.0, now) == 12 and c._frame(a, look, 0.0, now + CreaturesView.HURT_FRAME * 2.5) == 14,
		"a blow landed: the fox's hurt frames one after another")
	_check(c._frame(a, look, 0.0, now + CreaturesView.HURT_FRAME * 4.5) == 0 and look.hurt_at < 0.0, "then the fox stands again")
	var idle: Array[int] = []
	var t: float = look.change_at
	for i in 4:
		idle.append(c._frame(a, look, 0.0, t + i * (CreaturesView.IDLE_FRAME + 0.01) + 0.01))
	_check(idle == [5, 6, 7, 0], "the fox's idle plays through and it stands again (%s)" % [idle])
	var key := Vector2i(0, 0)
	var drop := ["animals:small_carcass", a.pos + Vector3(0.2, 0.0, 0.0), 0.0, {"n": 1, "body": kind}]
	c._lay_bodies(key, [drop], false, now)
	var lying: Array = c._bodies.get(key, {}).values()
	_check(lying.size() == 1 and look.body == lying[0], "the fox's body waits for it to go")
	if lying.size() != 1:
		c.free()
		return
	var b = lying[0]
	c.flinch(a, 0.3, a.pos - Vector3(1.0, 0.0, 0.0))
	var sprite: MeshInstance3D = look.sprite
	c._on_gone(a)
	c._bodies_step(b.dies_at + CreaturesView.DEATH_FRAME * 1.5)
	_check(b.sprite == sprite and b.frame == 1 and c._dying.has(b), "killed, the fox falls through its frames of death")
	c._bodies_step(b.dies_at + CreaturesView.DEATH_FRAME * 10.0)
	_check(b.frame == 3 and c._dying.is_empty() and sprite.material_override == c.looks[kind][1][0][b.view * 20 + 19],
		"and lies on its last")
	c.hide_bodies(key)
	c.free()


## The black grouse (tools/art/grouse_art.gd): a flyer whose wing beats are its walk frames and
## whose steps on the ground are its hop frames (`walks`), played by the path as a walker's.
func _test_grouse_states() -> void:
	var c := CreaturesView.new()
	c._build_looks()
	var kind := "animals:grouse"
	var k: Array = c.looks.get(kind, [])
	_check(k.size() > 12 and k[3] == 20 and k[4] == 4 and k[6] == 4 and k[7] == 0 and k[9] == 0 and k[10] == 4 and k[11] == 4 and k[12],
		"the grouse's row: 20 frames, the wing beat, the steps, hurt and death four each, the idle one animation")
	if k.size() <= 12:
		c.free()
		return
	var w := RemoteWildlife.new()
	c.wildlife = w
	var a := RemoteWildlife.Animal.new()
	a.kind = kind
	a.pos = Vector3(10.0, 3.0, 10.0)
	w.animals.append(a)
	c._on_born(a)
	var look = c._looks[a]
	var now := Time.get_ticks_msec() * 0.001
	var seen := {}
	a.flying = true
	for i in 8:
		seen[c._frame(a, look, float(i), now)] = true
	_check(seen.size() == 4 and seen.keys().all(func(f: int) -> bool: return f >= 1 and f < 5),
		"the grouse beats its wings in the air (%s)" % [seen.keys()])
	seen.clear()
	a.flying = false
	a.moving = true
	for i in 12:
		look.walked = i * 0.12
		seen[c._frame(a, look, 0.0, now)] = true
	_check(seen.size() == 4 and seen.keys().all(func(f: int) -> bool: return f >= 8 and f < 12),
		"the grouse walks on the ground in its steps, never sitting between them (%s)" % [seen.keys()])
	a.moving = false
	look.hurt_at = now
	_check(c._frame(a, look, 0.0, now) == 12, "a blow landed: the grouse flinches")
	c.free()
