// Trees drawn as pictures (TreeSprites): one upright picture a tree, at its trunk, the
// approved drawing of the side the camera looks at, lit by the sun here. A texel of the
// frames keeps what the light needs, not a colour (survivium-builds/trees-redraw,
// integration/pr1/src/export_pr1.py):
//   leaf (alpha 128 and up): red, green the leaf bundle's normal (octahedral, in the frame
//     of the drawing: x right, y up, z toward the camera), blue the leaf's angle on the
//     picture, alpha's bits: body (else rim), heart (no leaf, the bundle's disc, when
//     without body), the bundle's edge rank 0..3 (bits 2..3: how far out in the crown it
//     shows), bits 4..6 the leaf's light share in 7ths (1, 4..7), 0 a leaf on top (share
//     whole), 2 / 3 a maple leaf's outline, half a step darker (3: on top);
//   core (alpha 1): the dark mass inside the crown, the leaves' ramp step 1, red how far
//     out in the crown it is (0..1, as the bundles' rank);
//   wood (alpha 2): the bark's ramp step under each of 8 suns of the day path, 2 bits a
//     sun (red the first four, green the last).
// A conifer's frames (its ramp row's rule FRONDS, TreeLooks; export_pr2.py) hold fronds
// instead of leaf bundles: red, green the crown's normal where the frond lies (a pine
// cap's texel: its own on the cap's ball), blue the angle of the frond's side axis in the
// ground's plane (the axis across the frond, turned from its direction), alpha's bits: the
// texel on the axis's side (else the other half), stroke (outline, needles), the edge
// rank 0..3 (bits 2..3), root (its root third under the tier above), tip (its tip's body),
// deep (a frond of an inner ring).
// A willow's frames (rule HANGING; export_pr3.py) hold the leaves of its hanging modules:
// red, green the module's normal, alpha's bits: body, heart (no body: the module's dark
// backing), the edge rank, bits 4..6 what the leaf is: 0 a leaf of the cap over the
// module's anchor (blue its way, as a bundle's leaf on top), 1 a leaf of a strand (blue:
// its strand's place across the module, + 32, in bits 0..5, and how far down the strand it
// hangs, 0..3, in bits 6..7), 2 a strand of the far curtain seen through the gaps low in
// the crown (in the crown's shade whatever way it faces).
// A palm's frames (rule PALMS) hold their leaves' light as the bark's is held: the step
// drawn at each of the 8 suns in half steps, 4 bits a sun (red suns 0 and 1, low nibble
// first, green 2 and 3, blue 4 and 5, the bare frames' grey 6 and 7: a palm keeps its
// leaves, so nothing shows under them); alpha 128, + 1 on the soft outline (the leaf's own
// step drawn half way to the ramp's darkest). Alpha 3: a palm's trunk's soft outline (its
// spikes and nubs too), the bark's steps as wood's, drawn half way to the darkest.
// A stump's frames (its instance's colour alpha TreeSprites.STUMP, STUMP_SNOW: a row of the
// 8 turns of summer, then the 8 of winter; export_pr5.py) hold its bark as wood (alpha 2,
// 3 a palm's soft outline) and, 3 bits a sun in red, green, blue (sun k in bits 3k), the
// step of its cut wood (alpha 4: the ramp row's WOOD_AT steps, 6 the resin), of the snow
// on the cut (5: SNOW_STEPS) and of the snow's soft outline (6: half way to the darkest).
// The pieces of wood lying in the woods are drawn as stumps (alpha TreeSprites.PIECE), each
// view of its own size (its table of views, see the vertex), a sprout's leaves alpha 7 (the
// step of the leaves' ramp; export_pieces.py).
// bare_frames: the tree without its crown in the same places (grey and alpha the bark's
// steps as wood's red and green, both 1 where no wood), shown where autumn and winter have
// taken its leaves.
// Lit as the sprites are, as a whole; the steps of light inside are drawn by the rules of
// the approved drawing (bundles by their normal, leaves by their facing, bark by sun) under
// the sun where it stands in the world, seen from the side shown: looking toward it, the
// crown and the bark are in their shade. The bark and the leaves take the sun's shadow (the
// ground's: of the other trees, of hills) a step darker; where the drawing has them in shade
// already, nothing more.
// Two shaders are made of this code. As it is, it draws the trees standing, the stumps and
// the pieces of wood (the chunks', ChunkStreamer). With FALLING defined (TreeSprites.falling
// makes that copy in the game) it draws the trees falling, felled (TreeHits): the felling's
// code (FALL_*, its crown's modules) is in that copy alone. While it was in the one shader
// every tree drew, the Adreno 840 (Android, Vulkan) drew no tree at all, standing or
// falling, though their shadows (tree_shadow.gdshader) were there (v0.5.912 to v0.5.919,
// 2026-11-27): the module search alone is a loop of 24 x 24 texels a vertex.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
// Like a crown's for the player's silhouette (sprite_xray).
stencil_mode write, compare_always, 3;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D frames : filter_nearest;
uniform sampler2D bare_frames : filter_nearest;
uniform sampler2D snow_frames : filter_nearest;
// Where the ramps lie in the frames atlas: a row a species, the leaves' 7 steps, then the
// bark's 4, as drawn (sRGB), then the rule its leaves are lit by in red, a third a rule (0
// bundles, 1 fronds, 2 hanging, 3 palms: TreeLooks), the dry leaves' 7 steps (DRY_AT) and
// the blossom's (BLOSSOM_AT), where its snow lies (SNOW_AT): TreeSprites.RAMP_W.
uniform ivec2 ramps_at;
// How much of the trees' blossom is out (Sky): all of it in spring.
global uniform float blossom_amount;

#include "res://shaders/tree_pictures.gdshaderinc"

const int MODULES = 0;
const int FRONDS = 1;
const int HANGING = 2;
const int PALMS = 3;

// The rules of the approved drawing (render7.Tree, trees22.tree): a bundle is light
// (step 4) facing the sun over D1, half (3) over D2, else shade (2); the palest step only
// over DP.
const float D1 = 0.64;
const float D2 = 0.36;
const float DP = 0.8;
// A conifer's frond (conifer21.Conifer): its step by its crown normal against the sun,
// 5 / 4 / 3 / 2 over these, else 1; the palest only over FRONDS_PALE; its halves parted
// only when the sun is off its side axis by more than FRONDS_SIDE.
const vec4 FRONDS_BANDS = vec4(0.8, 0.5, 0.2, -0.15);
const float FRONDS_PALE = 0.92;
const float FRONDS_SIDE = 0.12;
const float TONE = 0.8;
// Where a ramp row's stump wood lies (TreeSprites.WOOD_AT); a stump shows its winter look
// (snow on its cut) from this much snow cover on (snow_amount: the trees' snow comes from
// SNOW_FIRST, all of it at SNOW_FULL).
const int WOOD_AT = 28;
const float STUMP_WINTER = 0.3;
// The 8 suns the bark was drawn under, in the drawing's frame (to the sun: x east, y up,
// z south): Sky's day path at t = 0.22 + k * 0.08.
const vec3 SUNS[8] = vec3[](
	vec3(0.9618, 0.1100, 0.2505), vec3(0.7816, 0.4488, 0.4332), vec3(0.5236, 0.6932, 0.4952),
	vec3(0.3154, 0.8061, 0.5008), vec3(0.1809, 0.8061, 0.5635), vec3(0.0427, 0.6932, 0.7194),
	vec3(-0.1705, 0.4488, 0.8772), vec3(-0.4263, 0.1100, 0.8978));

// Trees shaken by a blow of the axe (TreeHits, as leaves.gdshader's): the foot of the
// trunk (xyz) and how far the top of its crown leans along the screen now, in pixels (w).
uniform vec4 shakes[4];
uniform int shake_count = 0;
// Over what height above its foot a shaken tree leans in full (world units), and the
// pixels the picture is widened by while it shakes, so the crown may lean past its cell.
const float SHAKE_RISE = 4.0;
const float SHAKE_ROOM = 4.0;
// The wind sways a standing tree's crown module by module (the user's ask, 2026-11-26: the
// crown swayed whole, row by row, looked like ripples on water): its leaves are cut into the
// modules a falling crown is cut into (fall_owner: clumps of FALL_MODULE), and each moves its
// leaves as they are by whole pixels, on its own clock (SWAY_APART radians of phase apart, the
// swing running up the crown by SWAY_WAVE a unit of height): to and fro by SWAY_PX plus
// SWAY_WIND a unit of wind (the global `wind`), up and down by SWAY_BOB of that, and all of
// them leaning SWAY_LEAN a unit of the wind across the screen. A module whose middle is under
// SWAY_FROM over the foot stays, one from SWAY_FROM + SWAY_RISE up (world units) moves in
// full. The bark never moves (the limbs and the trunk stay whole). The picture is widened by
// SWAY_ROOM pixels each side for it.
const float SWAY_PX = 0.5;
const float SWAY_WIND = 1.2;
const float SWAY_BOB = 0.35;
const float SWAY_LEAN = 0.6;
const float SWAY_FROM = 1.0;
const float SWAY_RISE = 5.0;
const float SWAY_WAVE = 0.25;
const float SWAY_APART = 2.0;
const float SWAY_SPEED = 1.3;
const float SWAY_ROOM = 4.0;
// Two trees whose feet are as far from the camera (in one row across the screen) draw at
// one depth where they overlap: the depth test then takes rows of either crown in turn
// (stripes). Each tree is drawn up to DEPTH_TIE world units nearer the camera by its foot's
// hash, so one crown is wholly over the other; much less than the depth between rows of
// cells.
const float DEPTH_TIE = 0.04;
// The bark's outline is left off a picture's lower edge (where the trunk and the roots meet
// the ground) up to BASE_RISE pixels over the foot's row: such a texel takes the bark over it.
const float BASE_RISE = 16.0;

// Trees falling, felled (TreeHits.fall: up to 4): the foot of the trunk (xyz) and how far
// the tree has turned over (w, radians), the way it falls (x, y), the seconds since it began
// to fall (z) and how far it has faded out (w, 0..1, once it lies). It turns over about the stump's top, FALL_CUT over the
// foot; the rows under that are the stump's, which stays (TreeSprites).
uniform vec4 falls[4];
uniform vec4 fall_ways[4];
uniform int fall_count = 0;
const float FALL_CUT = 0.5;
// A falling tree is not drawn as its picture turned and squashed, but pixel by pixel (the
// user's ask, 2026-11-26): each pixel of the screen takes one texel of the picture, found by
// undoing the fall's turn on the screen with three shears of whole pixels (Paeth; a turn of
// whole quarters exactly), so the picture's pixels move about the stump as they are, none
// stretched, lost or doubled; what the fall squashes (a tree falling toward the camera or
// away) drops whole rows. Its quad is FALL_ROOM pixels wider all round, for the pixels the
// shears move past it.
const float FALL_ROOM = 4.0;
// Its crown falls as modules of leaves (the user's ask, 2026-11-26): the leaves are cut into
// pieces FALL_MODULE pixels apart (FALL_SHAPE: 0 squares, 1 bricks, rows half a module
// apart, 2 clumps round centres shaken FALL_SPREAD of a module off the grid), two instances
// each after the first (which draws the trunk and limbs as above): the module, and its ring.
// A module is a billboard: never turned nor resized; it hangs on at the middle of its own
// leaves, which alone moves with the falling tree, so falling toward the camera the top ones
// come far down past the foot and the low ones a little. Its ring draws FALL_OVERLAP pixels
// of its neighbours' leaves round it, behind the modules (the same texels where they stand
// together), so modules moving apart leave no gaps. The user picked clumps of 24 (2026-11-26).
const int FALL_SHAPE = 2;
const float FALL_MODULE = 24.0;
const float FALL_SPREAD = 0.6;
const float FALL_OVERLAP = 6.0;
// How far a module's edge wanders off its square (texels), so it is not cut straight.
const float FALL_JAG = 8.0;
// How far a module's leaves reach from its home (texels).
const float FALL_REACH = FALL_MODULE * 0.5 + FALL_JAG * 0.5 + (FALL_SHAPE == 2 ? FALL_MODULE * FALL_SPREAD * 0.5 : 0.0);
// Depth a module gains per pixel lower on the screen.
const float FALL_ORDER = 0.001;
// How far behind the modules' squares their rings are drawn: they only fill the gaps.
const float FALL_RING_BACK = 0.3;
// Modules come to rest on the ground (their lowest leaves at the foot's level): in each row of
// modules the first down stays there, the next fall onto it and rest on it, the pile pressed
// to FALL_PILE of how far they would have sunk in.
const float FALL_PILE = 0.6;
// The fall's turn over time, as TreeHits.fall_at (keep the two alike): faster and faster to
// FALL_ANGLE in FALL_TIME seconds, then a bounce of FALL_BOUNCE back up and down in BOUNCE_TIME.
const float FALL_TIME = 1.0;
const float FALL_ANGLE = PI / 2.0;
const float FALL_BOUNCE = 0.06;
const float BOUNCE_TIME = 0.25;
// How far past the stump's side the leaves of a crown lying on the ground begin, at least
// (pixels on the screen, the way it fell; each module up to FALL_JAG further, so their edge
// there is not straight).
const float FALL_CLEAR = 2.0;
// Each module falls on its own clock, up to half of FALL_LAG seconds before or after the trunk
// (the user's ask, 2026-11-27: not all at once), so the crown comes down a little ragged.
const float FALL_LAG = 0.24;
// Added to COLOR.b of a falling tree's own instances (TreeHits.FALL_MINE): the standing tree
// its chunk still draws at the same foot until rebuilt is left out instead.
const float FALL_MINE = 512.0;

varying vec2 px;
varying flat vec4 cell;
#ifdef FALLING
// How far a falling tree has faded out, -1 for a tree standing.
varying flat float fading;
// A falling tree's turn on the screen (fall_screen): the shears' tan and sin of the turn
// left after whole quarters, the quarters, and how the turned picture's rows are squashed
// (fall_turn), the shear of its columns along them and its columns' stretch, and the
// stump's top on the screen (pixels). For a module of its crown, the way it falls on the
// screen (xy) and how far back of the texel it hangs on its ring draws (z).
varying flat vec4 fall_turn;
varying flat vec4 fall_shear;
// A falling crown's module (FALL_MODULE): the texel it hangs on, -1 for the rest.
varying flat vec2 tile_mid;
// 1 for a module's ring round its square (FALL_OVERLAP), drawn behind the modules' squares.
varying flat float tile_ring;
#endif
varying flat vec2 info;
// How far this tree's top leans now (pixels; a falling tree's: the column of its axis), and
// its foot's row in the picture.
varying flat vec2 shake;
// The phase of this tree's sway (radians), -1 for one not swaying (a stump, a falling tree).
varying flat float sway_phase;
varying vec3 world_pos;
varying vec3 foot_pos;
varying vec2 light_xz;
varying float clouds;
varying vec3 lamp_gain;
// The albedo in the sun's shadow (a step darker: the bark's in_shade, the leaves'
// leaf_steps and frond_steps), as ALBEDO is written, for light() to show it where the
// shadow falls; negative where a shadow changes nothing.
varying vec3 shaded;

#ifdef FALLING
// Where a drawn (sheared) point is on the screen, in pixels (x right, y down).
vec2 screen_px(vec3 v) {
	return vec2(dot(v.xz, vec2(-view_up.y, view_up.x)), -dot(v.xz, view_up)) * TEXELS;
}

// A way `v` (world units) from a falling tree's pivot turned over by `a` (radians) the way
// fall `i` goes (Rodrigues' turn about the axis up x way, which takes up to the way).
vec3 fall_turned(vec3 v, int i, float a) {
	vec3 way = normalize(vec3(fall_ways[i].x, 0.0, fall_ways[i].y));
	vec3 axis = cross(vec3(0.0, 1.0, 0.0), way);
	return v * cos(a) + cross(axis, v) * sin(a) + axis * dot(axis, v) * (1.0 - cos(a));
}

// How far a falling tree has turned over `t` seconds after it began (TreeHits.fall_at).
float fall_angle(float t) {
	if (t < FALL_TIME) {
		float k = max(t, 0.0) / FALL_TIME;
		return FALL_ANGLE * k * k;
	}
	return FALL_ANGLE - FALL_BOUNCE * sin(PI * min(t - FALL_TIME, BOUNCE_TIME) / BOUNCE_TIME);
}

// The screen's pixels a way `v` from a tree's foot is drawn at, standing tall as the trees.
vec2 fall_px(vec3 v) {
	return screen_px(shear(vec3(v.x, v.y / (view_slope > 0.01 ? view_slope : 1.0), v.z)));
}
#endif

// How far a falling crown's module edge is moved at texel `t` (FALL_JAG; by blocks of 4).
vec2 fall_jag(vec2 t) {
	vec2 block = floor(t / 4.0);
	return (vec2(hash12(block), hash12(block + 17.0)) - 0.5) * FALL_JAG;
}

// Where module `m` (its column and row) is at home in the picture (texels; FALL_SHAPE).
vec2 fall_home(vec2 m) {
	if (FALL_SHAPE == 2) {
		vec2 shaken = vec2(hash12(m + 41.3), hash12(m * 1.7 + 9.1)) - 0.5;
		return (m + 0.5 + shaken * FALL_SPREAD) * FALL_MODULE;
	}
	float half_back = FALL_SHAPE == 1 && mod(m.y, 2.0) > 0.5 ? 0.5 : 0.0;
	return (m + vec2(0.5 - half_back, 0.5)) * FALL_MODULE;
}

// The module (column, row) the picture's point `t` (texels) belongs to.
vec2 fall_owner(vec2 t) {
	vec2 j = t + fall_jag(t);
	if (FALL_SHAPE == 2) {
		vec2 g = floor(j / FALL_MODULE);
		vec2 who = g;
		float best = 1e9;
		for (int i = 0; i < 9; i++) {
			vec2 m = g + vec2(float(i % 3) - 1.0, float(i / 3) - 1.0);
			vec2 d = j - fall_home(m);
			if (dot(d, d) < best) {
				best = dot(d, d);
				who = m;
			}
		}
		return who;
	}
	float row = floor(j.y / FALL_MODULE);
	float half_back = FALL_SHAPE == 1 && mod(row, 2.0) > 0.5 ? 0.5 : 0.0;
	return vec2(floor(j.x / FALL_MODULE + half_back), row);
}

// Whether texel `i` of the picture in `at_cell` is a leaf of a falling crown (over the row
// `cut`, where the stump's rows begin).
bool fall_leaf(vec4 at_cell, float cut, vec2 i) {
	if (i.x < 0.0 || i.y < 0.0 || i.x >= at_cell.z || i.y >= at_cell.w || i.y + 0.5 > cut) {
		return false;
	}
	int a = frame_code(texelFetch(frames, ivec2(at_cell.xy + i), 0));
	return a != 0 && a != 2 && a != 3;
}

// The texel of the picture a standing tree shows at its pixel `at` in the wind (SWAY_*):
// the pixel's module's leaves come from as far back as the module has moved; a pixel of bark
// or of nothing keeps its own texel unless a leaf has come over it; a leaf's pixel left by
// its leaves shows what has come there (nothing, or the bark next to it).
vec2 sway_texel(vec2 at, vec4 at_cell, float foot_row, float phase, float time) {
	vec2 me = fall_owner(at);
	float h = (foot_row - fall_home(me).y) / TEXELS;
	float bend = clamp((h - SWAY_FROM) / SWAY_RISE, 0.0, 1.0);
	if (bend <= 0.0) {
		return at;
	}
	float gust = SWAY_PX + length(wind) * SWAY_WIND;
	float ph = time * SWAY_SPEED + phase - h * SWAY_WAVE + hash12(me * 2.3 + phase) * SWAY_APART;
	vec2 across = vec2(-view_up.y, view_up.x);
	vec2 d = vec2(sin(ph) * gust + dot(wind, across) * SWAY_LEAN, sin(ph * 1.7 + 1.3) * gust * SWAY_BOB);
	d = round(clamp(d * bend * bend, -SWAY_ROOM, SWAY_ROOM));
	if (d.x == 0.0 && d.y == 0.0) {
		return at;
	}
	vec2 from = at - d;
	if (fall_leaf(at_cell, 1e9, floor(from)) || fall_leaf(at_cell, 1e9, floor(at))) {
		return from;
	}
	return at;
}

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	// world_vertex_coords: the quad's own corner (x 0..1 across, y -1, 0, 1) is what the
	// instance's place leaves of it.
	vec2 q = (VERTEX - foot).xy;
	vec4 c = INSTANCE_CUSTOM;
	float ax = COLOR.r;
	float ay = COLOR.g;
	bool mine = COLOR.b > FALL_MINE - 0.5;
	float b = mine ? COLOR.b - FALL_MINE : COLOR.b;
	float row = floor(b / 8.0 + 0.01);
	float own = b - row * 8.0;
	// The side shown: the step the camera rests at, plus the tree's own turn.
	vec2 up = rest_view.xy;
	float step_at = round(atan(-up.x, -up.y) / (PI / 4.0));
	float side = mod(step_at + own + 16.0, 8.0);
	// A stump of a snowy place shows its winter row in the snow (so does a piece of wood).
	float winter = COLOR.a < -1.5 && snow_amount >= STUMP_WINTER ? 8.0 : 0.0;
	if (COLOR.a < -2.5) {
		// A piece of wood lying in the woods (TreeSprites.PIECE): each view its own cell
		// and anchor, from its table of views.
		ivec2 tb = ivec2(int(round(c.x)), int(round(c.y))) + ivec2(2 * int(side + winter), 0);
		ivec4 p0 = ivec4(round(texelFetch(frames, tb, 0) * 255.0));
		ivec4 p1 = ivec4(round(texelFetch(frames, tb + ivec2(1, 0), 0) * 255.0));
		c = vec4(float(p0.r | (p0.g << 8)), float(p0.b | (p0.a << 8)), float(p1.r), float(p1.g));
		ax = float(p1.b);
		ay = float(p1.a);
		cell = c;
	} else {
		cell = vec4(c.x + (side + winter) * c.z, c.y, c.z, c.w);
	}
	info = vec2(row, COLOR.a);
	float lean = 0.0;
	for (int i = 0; i < shake_count && COLOR.a > -0.5; i++) {
		if (length(shakes[i].xz - foot.xz) < 0.1) {
			lean += shakes[i].w;
		}
	}
	shake = vec2(lean, ay + 0.5);
	int fall = -1;
	for (int i = 0; i < fall_count && COLOR.a > -0.5; i++) {
		if (length(falls[i].xyz - foot) < 0.1) {
			fall = i;
		}
	}
#ifdef FALLING
	fading = fall >= 0 ? fall_ways[fall].w : -1.0;
#endif
	bool sways = COLOR.a > -0.5 && fall < 0;
	sway_phase = sways ? hash12(foot.xz * 1.7) * 6.2832 : -1.0;
	float room = (lean != 0.0 ? SHAKE_ROOM : 0.0) + (sways ? SWAY_ROOM : 0.0) + (fall >= 0 ? FALL_ROOM : 0.0);
	// The foot on the middle of a pixel, so the picture's texels are the screen's.
	vec2 right = vec2(-view_up.y, view_up.x);
	vec2 sp = screen_plane(foot) * TEXELS;
	vec2 fix = (floor(sp) + 0.5 - sp) / TEXELS;
	foot.xz += right * fix.x - view_up * fix.y;
	foot_pos = foot;
	float wide = q.x * (c.z + 2.0 * room) - room;
	float across = wide - ax - 0.5;
	float rise = q.y >= 0.0 ? q.y * (ay + 0.5 + room) : q.y * (c.w - ay - 0.5);
	px = vec2(wide, ay + 0.5 - rise);
	vec3 p = foot + vec3(right.x, 0.0, right.y) * (across / TEXELS);
#ifdef FALLING
	int tile = fall >= 0 ? (INSTANCE_ID - 1) / 2 : -1;
	tile_ring = fall >= 0 ? float((INSTANCE_ID - 1) % 2) : 0.0;
	tile_mid = vec2(-1.0);
	fall_shear = vec4(0.0);
	fall_turn = vec4(0.0);
	if (fall >= 0) {
		// How a texel's step across (mu) and down (mv) the picture goes on the screen now: a
		// turn of the screen by `th` times rows squashed and sheared (mu turned back lies
		// along x); the stump's top on the middle of a pixel.
		vec2 mu = fall_px(fall_turned(vec3(right.x, 0.0, right.y) / TEXELS, fall, falls[fall].w));
		vec2 mv = fall_px(fall_turned(vec3(0.0, -1.0 / TEXELS, 0.0), fall, falls[fall].w));
		float th = atan(mu.y, mu.x);
		float k = round(th / (PI / 2.0));
		float f = th - k * PI / 2.0;
		vec2 back = vec2(cos(th) * mv.x + sin(th) * mv.y, -sin(th) * mv.x + cos(th) * mv.y);
		vec2 o = floor(fall_px(vec3(0.0, FALL_CUT, 0.0)) + screen_px(shear(foot))) + 0.5;
		fall_turn = vec4(-tan(f * 0.5), sin(f), mod(k + 4.0, 4.0), back.y);
		fall_shear = vec4(length(mu), back.x, o);
		shake.x = ax + 0.5;
	}
	if (fall >= 0 && !mine) {
		VERTEX = foot;
	} else if (tile >= 0) {
		// A module of the crown (FALL_MODULE; the grid one module wider all round, for the
		// leaves the jagged edges and the shapes take over the picture's edge). Its leaves
		// (every other texel of its reach): where they hang on, the middle of them, how far
		// under it they reach, and how far back against the way the tree falls on the screen.
		float cols = ceil(c.z / FALL_MODULE) + 2.0;
		vec2 me = vec2(mod(float(tile), cols), floor(float(tile) / cols)) - 1.0;
		vec2 home = fall_home(me);
		float cut = shake.y - FALL_CUT * TEXELS;
		vec3 way3 = normalize(vec3(fall_ways[fall].x, 0.0, fall_ways[fall].y));
		vec2 way_px = screen_px(shear(way3));
		vec2 ahead = normalize(way_px);
		vec3 sum = vec3(0.0);
		float low = 0.0;
		float back = 0.0;
		for (float y = -FALL_REACH; y < FALL_REACH; y += 2.0) {
			for (float x = -FALL_REACH; x < FALL_REACH; x += 2.0) {
				vec2 i = floor(home + vec2(x, y));
				if (fall_leaf(cell, cut, i) && all(equal(fall_owner(i + 0.5), me))) {
					back = sum.z < 0.5 ? dot(home - i - 0.5, ahead) : max(back, dot(home - i - 0.5, ahead));
					sum += vec3(i + 0.5, 1.0);
					low = max(low, i.y + 1.0);
				}
			}
		}
		if (sum.z < 0.5) {
			VERTEX = foot;
		} else {
			tile_mid = floor(sum.xy / sum.z);
			// Its own moment of the fall (FALL_LAG), the same for its ring.
			float turn = fall_angle(fall_ways[fall].z - (hash12(me * 1.37 + falls[fall].xz) - 0.5) * FALL_LAG);
			vec3 pivot = foot + vec3(0.0, FALL_CUT, 0.0);
			vec3 across3 = vec3(right.x, 0.0, right.y);
			vec3 hung = foot + across3 * ((tile_mid.x - ax) / TEXELS) + vec3(0.0, (ay - tile_mid.y) / TEXELS, 0.0);
			vec3 m = pivot + fall_turned(hung - pivot, fall, turn);
			// Kept over the ground: its lowest leaves `rest` under it; sunk in by `d`, it rests
			// on the pile of its row, as deep as the row's leaf that went deepest (`deep`: the
			// row's leaves furthest the way it falls, looked for along lines 4 texels apart).
			float rest = (low - tile_mid.y - 0.5) / TEXELS;
			float d = m.y - foot.y - rest;
			float deep = min(d, 0.0);
			float side = dot(across3, way3) * sin(turn);
			if (abs(side) > 0.001) {
				for (float y = me.y * FALL_MODULE + 1.0; y < (me.y + 1.0) * FALL_MODULE; y += 4.0) {
					for (float k = 0.0; k < c.z; k += 2.0) {
						vec2 i = vec2(side > 0.0 ? c.z - 1.0 - k : k, y);
						if (fall_leaf(cell, cut, i)) {
							float up = (ay - i.y) / TEXELS - FALL_CUT;
							deep = min(deep, FALL_CUT + up * cos(turn) - (i.x - ax) / TEXELS * side);
							break;
						}
					}
				}
			}
			m.y = foot.y + rest + max(d, FALL_PILE * (d - deep));
			// Lying, its leaves reach back toward the stump no further than its lowest leaves came
			// down along their arc (the user's ask, 2026-11-27: the crown lies only the way it
			// fell, from where its bottom comes down; FALL_CLEAR off the trunk's axis at least). A
			// billboard stands up, so its upper leaves would lie back over the stump and past it:
			// it is carried on the way it falls by as much (`push`), more as it comes down.
			// The stump: as wide as the picture's foot row.
			float stump = 0.0;
			for (float k = 0.0; k < c.z; k += 1.0) {
				if (frame_code(texelFetch(frames, ivec2(cell.xy + vec2(k, ay)), 0)) != 0) {
					stump = max(stump, abs(k + 0.5 - ax));
				}
			}
			vec2 foot_px = screen_px(shear(foot));
			vec3 lying = pivot + fall_turned(hung - pivot, fall, FALL_ANGLE);
			lying.y = max(lying.y, foot.y + rest);
			vec3 under = pivot + fall_turned(hung - vec3(0.0, rest, 0.0) - pivot, fall, FALL_ANGLE);
			float reach = max(dot(screen_px(shear(vec3(under.x, foot.y, under.z))) - foot_px, ahead), stump + FALL_CLEAR + hash12(me * 2.3 + 5.1) * FALL_JAG);
			back -= dot(home - tile_mid - 0.5, ahead);
			float push = max(reach + back - dot(screen_px(shear(stand_tall(lying, foot))) - foot_px, ahead), 0.0);
			float down = 1.0 - cos(turn);
			m += way3 * (push / length(way_px) * down);
			// Its ring then draws no leaves further back than its own reach (jagged), lying.
			fall_turn = vec4(ahead, back - FALL_JAG * 0.5 + (1.0 - down) * 4.0 * FALL_REACH, 0.0);
			vec3 drawn = shear(stand_tall(m, foot));
			// Its leaves as they are about the texel it hangs on (the screen's pixel there).
			vec2 at_px = floor(screen_px(drawn)) + 0.5;
			vec2 box = at_px + home - (tile_mid + 0.5);
			float half_side = FALL_REACH + FALL_OVERLAP;
			px = box + vec2((q.x * 2.0 - 1.0) * half_side, -q.y * half_side);
			vec2 xz = (px.x * vec2(-view_up.y, view_up.x) - px.y * view_up) / TEXELS;
			world_pos = m;
			// The modules lower on the screen in front (the camera looks straight down on the
			// sheared world, so modules at one height would tie), the rings behind.
			float depth = drawn.y + (at_px.y - foot_px.y) * FALL_ORDER - tile_ring * FALL_RING_BACK;
			VERTEX = vec3(xz.x, depth, xz.y);
			fall_shear = vec4(me, at_px);
		}
	} else if (q.y > 0.0 || fall >= 0 && q.y > -0.5) {
#else
	if (fall >= 0) {
		// A tree falling: its chunk draws it standing until rebuilt, while the falling trees'
		// copy of this shader draws it falling (TreeHits): left out here.
		VERTEX = foot;
	} else if (q.y > 0.0) {
#endif
		// Upright, kept its height in pixels at any tilt (a falling tree's foot row too,
		// turned with it).
		p.y += rise / TEXELS;
#ifdef FALLING
		if (fall >= 0) {
			// Turned over about the stump's top toward the way it falls: the quad covers
			// where it lies now, and the fragment finds each pixel's texel (FALL_ROOM).
			vec3 pivot = foot + vec3(0.0, FALL_CUT, 0.0);
			p = pivot + fall_turned(p - pivot, fall, falls[fall].w);
		}
#endif
		world_pos = p;
		VERTEX = shear(stand_tall(p, foot));
#ifdef FALLING
		if (fall >= 0) {
			// Kept over the ground in depth only (the view looks straight down on the
			// sheared world): the crown turning down past the stump's foot is drawn, not cut
			// off flat by the ground it would sink into as a picture.
			VERTEX.y = max(VERTEX.y, foot.y + 0.05);
		}
#endif
	} else {
		// The rows under the ground's row lie on the ground toward the camera (the roots
		// in front of the trunk), a little over it.
		p.xz -= view_up * (-rise / TEXELS);
		p.y += 0.03;
		world_pos = p;
		VERTEX = shear(p);
	}
#ifdef FALLING
	if (fall >= 0 && tile < 0) {
		px = screen_px(VERTEX);
	}
#endif
	light_xz = VERTEX.xz;
	vec4 seen = VIEW_MATRIX * vec4(VERTEX, 1.0);
	seen.z += DEPTH_TIE * (0.1 + 0.9 * hash12(foot.xz * 3.7 + 11.0));
	POSITION = PROJECTION_MATRIX * seen;
}

vec3 unocta(vec2 e) {
	e = e * 2.0 - 1.0;
	vec3 n = vec3(e, 1.0 - abs(e.x) - abs(e.y));
	if (n.z < 0.0) {
		n.xy = (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
	}
	return normalize(n);
}

vec3 ramp(float k, float i) {
	return ramp_texel(int(k), int(i)).rgb;
}

// The colour of ramp row `k` at step `c` (0..6, quarters between two steps mixed), of the
// leaves' steps from texel `at` of the row (0; DRY_AT the dry leaves', BLOSSOM_AT the
// blossom's).
vec3 steps_colour(float k, float c, int at) {
	float lo = floor(c);
	return mix(ramp(k, float(at) + lo), ramp(k, float(at) + min(lo + 1.0, 6.0)), c - lo);
}

vec3 leaf_colour(float k, float c) {
	return steps_colour(k, c, 0);
}

// The leaves' steps (0..6) of a leaf texel `g` (alpha bits `a`) under the light L: x in
// the sun, y in a shadow: a step darker, but no darker than on the crown's shaded side (its
// bundle in shade whatever way it faces), one shade, not two, as the bark's.
vec2 leaf_steps(vec4 g, int a, vec3 L) {
	float d = dot(unocta(g.rg), L);
	float base = d > D1 ? 4.0 : (d > D2 ? 3.0 : 2.0);
	vec2 c;
	if ((a & 3) == 2) {
		c = vec2(base, 2.0) - 1.0;
	} else {
		vec2 light2 = normalize(vec2(L.x, L.z - L.y) + vec2(1e-5, 0.0));
		int code = (a >> 4) & 7;
		float t0 = (a & 1) != 0 ? 0.0 : (code == 2 || code == 3 ? -1.5 : -1.0);
		float ang = g.b * 255.0 / 256.0 * TAU;
		float f = (cos(ang) * light2.x + sin(ang) * light2.y) * (code == 1 || code > 3 ? float(code) / 7.0 : 1.0);
		if (code == 0 || code == 3) {
			f = max(f, 0.5);
		}
		float s = f > 0.2 ? 1.0 : (f > -0.5 ? 0.0 : -1.0);
		float t = t0 + s + ((s > 0.5 && (a & 2) != 0 && f > 0.45) ? 1.0 : 0.0);
		// In the shade the leaves turned away keep a quarter of a step of their light.
		float t_shade = t < t0 ? t0 + 0.75 * (t - t0) : t;
		c = vec2(base + (base < 2.5 ? t_shade : t), 2.0 + t_shade);
	}
	c = clamp(min(c, vec2(d < DP ? 5.0 : 6.0, 5.0)), 0.0, 6.0);
	return vec2(c.x, max(c.x - 1.0, c.y));
}

// The leaves' steps (0..6) of a conifer's frond texel `g` (alpha bits `a`) under the light
// L: the band of its crown normal (an inner ring's a step darker), the half of the frond
// turned from the sun, its strokes and its root third a step darker each, a lit tip a
// step lighter where the band is light. x in the sun, y in a shadow: a step darker, but no
// darker than with the band of the crown's side away from the sun.
vec2 frond_steps(vec4 g, int a, vec3 L) {
	float d = dot(unocta(g.rg), L);
	float b = d > FRONDS_BANDS.x ? 5.0 : (d > FRONDS_BANDS.y ? 4.0 : (d > FRONDS_BANDS.z ? 3.0
		: (d > FRONDS_BANDS.w ? 2.0 : 1.0)));
	vec2 bands = vec2(b, min(b, 2.0)) - float((a >> 6) & 1);
	float ang = g.b * 255.0 / 256.0 * TAU;
	float side = cos(ang) * L.x + sin(ang) * L.z;
	bool lit = abs(side) <= FRONDS_SIDE || (side > 0.0) == ((a & 1) != 0);
	vec2 t = (lit ? bands : bands - 1.0) - float((a >> 1) & 1) - float((a >> 4) & 1);
	if ((a & 32) != 0 && lit && bands.x > 3.5) {
		t.x += 1.0;
	}
	t = clamp(min(t, vec2(d < FRONDS_PALE ? 5.0 : 6.0)), 0.0, 6.0);
	return vec2(t.x, max(t.x - 1.0, t.y));
}

// The leaves' steps (0..6) of a willow's texel `g` (alpha bits `a`) under the light L
// (willow22 / hangmod22 of the mockup): the module's band of its normal (a strand of the
// far curtain: the shade's), the backing a step under it, a leaf of the cap lit as one on
// top, a strand's leaf lit by where it hangs: across the module toward the sun's side (left
// or right of the picture) and high on its strand toward the light, low on the far side
// away. x in the sun, y in a shadow, as leaf_steps.
vec2 hanging_steps(vec4 g, int a, vec3 L) {
	int code = (a >> 4) & 7;
	float d = code == 2 ? -1.0 : dot(unocta(g.rg), L);
	float base = d > D1 ? 4.0 : (d > D2 ? 3.0 : 2.0);
	vec2 c;
	if ((a & 3) == 2) {
		c = vec2(base, 2.0) - 1.0;
	} else {
		bool heart = (a & 2) != 0;
		float t0 = (a & 1) != 0 ? 0.0 : -1.0;
		float t;
		float t_shade;
		if (code == 0) {
			vec2 light2 = normalize(vec2(L.x, L.z - L.y) + vec2(1e-5, 0.0));
			float ang = g.b * 255.0 / 256.0 * TAU;
			float f = cos(ang) * light2.x + sin(ang) * light2.y;
			t = t0 + 1.0 + (heart && f > 0.45 ? 1.0 : 0.0);
			t_shade = t;
		} else {
			int b = int(round(g.b * 255.0));
			int place = b >> 6;
			float along = place == 0 ? 0.45 : (place == 1 ? 0.2 : (place == 2 ? -0.15 : -0.35));
			float f = float((b & 63) - 32) / 12.0 * (L.x >= 0.0 ? 0.9 : -0.9) + along;
			float s = f > 0.3 ? 1.0 : (f > -0.4 ? 0.0 : -1.0);
			t = t0 + (s > 0.5 ? 1.0 + (heart && f > 0.55 ? 1.0 : 0.0) : s);
			// In the shade the leaves turned away keep a quarter of a step of their light.
			t_shade = s < -0.5 ? t0 - 0.75 : t;
		}
		c = vec2(base + (base < 2.5 ? t_shade : t), 2.0 + t_shade);
	}
	c = clamp(min(c, vec2(d < DP ? 5.0 : 6.0, 5.0)), 0.0, 6.0);
	return vec2(c.x, max(c.x - 1.0, c.y));
}

// Blossom (spring, blossom_amount) on the leaves of a species that has it (its ramp row's
// blossom steps), as spring23.py drew it: most leaves (BLOSSOM_SHARE at full bloom), each by
// its own number (its bundle's normal and its angle), in the blossom's steps; little
// crosses of flowers on the lit blossom: in each block of CROSS_BLOCK x CROSS_BLOCK texels of
// the picture one place by the tree, its middle the palest step where the blossom there is
// lit (steps 3 and 4), its 4 neighbours in blossom the next.
const float BLOSSOM_SHARE = 0.8;
const float CROSS_BLOCK = 5.0;

bool in_blossom(vec4 g, int a, vec2 foot) {
	return a >= 128 && (a & 3) != 2
		&& hash12(g.rg * 255.0 + vec2(g.b * 97.0, g.b * 13.0) + foot * 1.3) < blossom_amount * BLOSSOM_SHARE;
}

bool cross_middle(ivec2 p, vec2 foot) {
	vec2 block = floor(vec2(p) / CROSS_BLOCK);
	vec2 at = block * CROSS_BLOCK + floor(vec2(hash12(block + foot * 0.7 + 3.0), hash12(block + foot * 0.7 + 7.0)) * CROSS_BLOCK);
	return ivec2(at) == p;
}

// The blossom's step of texel `p` of the picture (`size`; frames texel `t`) at step `c`: a cross's
// middle or arm takes the palest steps.
float blossom_step(float c, ivec2 p, ivec2 size, ivec2 t, vec3 L, vec2 foot, float amount) {
	if (cross_middle(p, foot)) {
		return floor(c) >= 3.0 && floor(c) <= 4.0 ? 6.0 : c;
	}
	if (floor(c) < 2.0) {
		return c;
	}
	ivec2 sides[4] = ivec2[](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
	for (int i = 0; i < 4; i++) {
		ivec2 q = p + sides[i];
		if (q.x < 0 || q.y < 0 || q.x >= size.x || q.y >= size.y || !cross_middle(q, foot)) {
			continue;
		}
		vec4 g = texelFetch(frames, t + sides[i], 0);
		int a = frame_code(g);
		if (!in_blossom(g, a, foot) || (float((a >> 2) & 3) + hash12(g.rg * 255.0 + foot * 3.1)) / 4.0 > amount) {
			continue;
		}
		float cq = floor(leaf_steps(g, a, L).x);
		if (cq >= 3.0 && cq <= 4.0) {
			return 5.0;
		}
	}
	return c;
}

// How far the sun is behind the side shown (0 in front of it .. 1 behind it), round the
// edge of the picture's plane: SIDE_BLEND of L.z on either side.
const float SIDE_BLEND = 0.08;

// Of the 8 drawn suns (SUNS), the two nearest L (L.z >= 0) and how far to crossfade from
// the first to the second: only round the middle between them.
ivec2 nearest_suns(vec3 L, out float f) {
	int best = 0;
	float bd = -2.0;
	for (int i = 0; i < 8; i++) {
		float d = dot(SUNS[i], L);
		if (d > bd) {
			bd = d;
			best = i;
		}
	}
	int next = best == 0 ? 1 : (best == 7 ? 6 : (dot(SUNS[best - 1], L) > dot(SUNS[best + 1], L) ? best - 1 : best + 1));
	float a0 = acos(clamp(bd, -1.0, 1.0));
	float a1 = acos(clamp(dot(SUNS[next], L), -1.0, 1.0));
	f = 0.5 * smoothstep(0.3, 0.5, a0 / max(a0 + a1, 1e-4));
	return ivec2(best, next);
}

// A palm leaf's step (0..6, halves) at drawn sun `i`, from its texel `g` and the bare
// frames' texel `b` under it (see the top).
float palm_step(vec4 g, vec4 b, int i) {
	float v = i < 2 ? g.r : (i < 4 ? g.g : (i < 6 ? g.b : b.r));
	int byte = int(round(v * 255.0));
	return float((byte >> (4 * (i & 1))) & 15) * 0.5;
}

// A palm leaf's colour of texel `g` under the light L: its steps at the two drawn suns
// nearest it, crossfaded as the bark's (a sun behind the tree as its mirror image in front,
// the leaf then in its shade). `shade`: a step darker, but no darker than the darkest the
// leaf is drawn at any sun (one shade, not two). The soft outline: half way to the darkest.
vec3 palm_colour(float k, vec4 g, vec4 b, int a, vec3 L, out vec3 shade) {
	float back = smoothstep(SIDE_BLEND, -SIDE_BLEND, L.z);
	L.z = abs(L.z);
	float f;
	ivec2 i = nearest_suns(L, f);
	float s0 = palm_step(g, b, i.x);
	float s1 = palm_step(g, b, i.y);
	float low = 6.0;
	for (int j = 0; j < 8; j++) {
		low = min(low, palm_step(g, b, j));
	}
	vec3 lit = mix(leaf_colour(k, s0), leaf_colour(k, s1), f);
	shade = mix(leaf_colour(k, max(s0 - 1.0, low)), leaf_colour(k, max(s1 - 1.0, low)), f);
	if ((a & 1) != 0) {
		lit = mix(lit, ramp(k, 0.0), 0.5);
		shade = mix(shade, ramp(k, 0.0), 0.5);
	}
	return mix(lit, shade, back);
}

// The bark's step in shade: a step under its step where no crown shades it (`open`, the
// bare tree's), but no lower than a step under the step drawn (`s`): where the drawing has
// it in its own crown's shade already, a shadow takes nothing more (one shade, not two).
int in_shade(int s, int open) {
	return clamp(open - 1, max(s - 1, 0), s);
}


// The bark's steps of texel `t` (2 bits a sun, as wood_colour's), of the bare frames or the
// frames: -1 where no bark (a leaf, a stump's cut), -2 where the picture is empty (or out of
// its cell, `lo`..`hi`).
int bark_bits(ivec2 t, bool bare, ivec2 lo, ivec2 hi) {
	if (t.x < lo.x || t.y < lo.y || t.x >= hi.x || t.y >= hi.y) {
		return -2;
	}
	if (bare) {
		vec4 b = texelFetch(bare_frames, t, 0);
		if (b.r > 0.998 && b.a > 0.998) {
			return -2;
		}
		return int(round(b.r * 255.0)) | (int(round(b.a * 255.0)) << 8);
	}
	vec4 g = texelFetch(frames, t, 0);
	int a = frame_code(g);
	if (a == 2 || a == 3) {
		return int(round(g.r * 255.0)) | (int(round(g.g * 255.0)) << 8);
	}
	return a == 0 ? -2 : -1;
}

ivec2 side(int i) {
	return i == 0 ? ivec2(1, 0) : i == 1 ? ivec2(-1, 0) : i == 2 ? ivec2(0, 1) : ivec2(0, -1);
}

// How the bark of texel `t` (its steps `bits`) is drawn beside its neighbours, 8 suns at a
// time (user 2026-11-26): x the suns it takes a halftone at (bit k: sun k), y its outline's
// step in halves (3 bits a sun, 7: none). A texel beside a darker step of the bark is drawn
// half a step darker, so each step steps down to the next through a halftone. A texel on the
// picture's edge with bark inside it (across from the empty side, not an edge itself) is its
// outline: one tone all round, OUTLINE_LOW halves up from the darkest step, whatever the
// light (a twig all outline keeps its drawn steps). `base`: the texel is low on the picture
// (BASE_RISE): its lower edge takes no outline (the user's ask, 2026-11-26: none where the
// tree meets the ground): the drawn outline there, empty under it, is not drawn (`bits` -1).
const int OUTLINE_LOW = 1;
ivec2 bark_look(ivec2 t, bool bare, inout int bits, ivec2 lo, ivec2 hi, bool base) {
	int n[4];
	bool edge = false;
	for (int i = 0; i < 4; i++) {
		n[i] = bark_bits(t + side(i), bare, lo, hi);
		edge = edge || n[i] == -2;
	}
	if (base && n[2] == -2 && n[3] >= 0) {
		// Empty under it: the drawn outline of the bottom edge, left out (bits -1).
		bits = -1;
		return ivec2(0);
	}
	if (!edge) {
		int halves = 0;
		for (int i = 0; i < 4; i++) {
			if (n[i] >= 0) {
				for (int k = 0; k < 8; k++) {
					if (((n[i] >> (2 * k)) & 3) < ((bits >> (2 * k)) & 3)) {
						halves |= 1 << k;
					}
				}
			}
		}
		return ivec2(halves, 16777215);
	}
	// Bark inside: across from an empty side, a texel that is not an edge too.
	bool inside = false;
	for (int i = 0; i < 4; i++) {
		if (n[i] != -2 || n[i ^ 1] < 0) {
			continue;
		}
		ivec2 q = t + side(i ^ 1);
		bool inner_edge = false;
		for (int e = 0; e < 4; e++) {
			inner_edge = inner_edge || bark_bits(q + side(e), bare, lo, hi) == -2;
		}
		inside = inside || !inner_edge;
	}
	int outline = 0;
	for (int k = 0; k < 8; k++) {
		int c = inside ? OUTLINE_LOW : 2 * ((bits >> (2 * k)) & 3);
		outline |= max(c, OUTLINE_LOW) << (3 * k);
	}
	return ivec2(0, outline);
}

// The bark's colour at step `s` (0..3, halves mixed), of ramp row `k`.
vec3 bark_step(float k, float s) {
	float lo = floor(s);
	return mix(ramp(k, 7.0 + lo), ramp(k, 7.0 + min(lo + 1.0, 3.0)), s - lo);
}

// The bark's step at sun `j` (x; halves as bark_step takes them) and in a shadow (y), of
// steps `bits`, `opens` (see wood_colour) drawn as `look` has it (bark_look).
vec2 bark_at(int bits, int opens, ivec2 look, int j) {
	int s = (bits >> (2 * j)) & 3;
	float dark = float(s - in_shade(s, (opens >> (2 * j)) & 3));
	int o = (look.y >> (3 * j)) & 7;
	float lit = o < 7 ? 0.5 * float(o) : float(s) - 0.5 * float((look.x >> j) & 1);
	return o < 7 ? vec2(lit) : vec2(max(lit, 0.0), max(lit - dark, 0.0));
}

// The bark's colour of wood texel `g` (red, green: 2 bits a sun) under the light L: the
// two drawn suns nearest it, crossfaded only round the middle between them. The suns were
// drawn on the viewer's side of the tree: a sun behind it is taken as its mirror image in
// front, and the bark is then in its shade. `open`: the bark's steps where no crown shades
// it (the bare tree's, see in_shade). `look`: its halftones and outline (bark_look).
// `shade`: its colour a step darker, in a shadow.
vec3 wood_colour(float k, vec4 g, vec4 open, ivec2 look, vec3 L, out vec3 shade) {
	float back = smoothstep(SIDE_BLEND, -SIDE_BLEND, L.z);
	L.z = abs(L.z);
	int bits = int(round(g.r * 255.0)) | (int(round(g.g * 255.0)) << 8);
	int opens = int(round(open.r * 255.0)) | (int(round(open.g * 255.0)) << 8);
	float f;
	ivec2 near = nearest_suns(L, f);
	int best = near.x;
	int next = near.y;
	vec2 lit0 = bark_at(bits, opens, look, best);
	vec2 lit1 = bark_at(bits, opens, look, next);
	shade = mix(bark_step(k, lit0.y), bark_step(k, lit1.y), f);
	return mix(mix(bark_step(k, lit0.x), bark_step(k, lit1.x), f), shade, back);
}

// A stump's step `s` of its frames' code `a` (4 cut wood, 5 snow, 6 the snow's outline; 7 a
// leaf of a broken trunk's sprout: the leaves' steps) as a colour, of ramp row `k`.
vec3 stump_step(float k, int a, int s) {
	if (a == 7) {
		return ramp(k, float(min(s, 6)));
	}
	if (a == 4) {
		return ramp(k, float(WOOD_AT + s));
	}
	vec3 c = SNOW_STEPS[min(s, 5)];
	return a == 6 ? mix(c, SNOW_STEPS[0], 0.5) : c;
}

// A stump's colour of texel `g` (code `a`: 4..6) under the light L, as wood_colour's: the
// two drawn suns nearest it crossfaded, a sun behind it its mirror image in front, the cut
// then in its shade. `shade`: a step darker (the resin stays as it is).
vec3 stump_colour(float k, vec4 g, int a, vec3 L, out vec3 shade) {
	float back = smoothstep(SIDE_BLEND, -SIDE_BLEND, L.z);
	L.z = abs(L.z);
	int bits = int(round(g.r * 255.0)) | (int(round(g.g * 255.0)) << 8) | (int(round(g.b * 255.0)) << 16);
	float f;
	ivec2 near = nearest_suns(L, f);
	int s0 = (bits >> (3 * near.x)) & 7;
	int s1 = (bits >> (3 * near.y)) & 7;
	int d0 = s0 == 6 && a == 4 ? 6 : max(s0 - 1, 0);
	int d1 = s1 == 6 && a == 4 ? 6 : max(s1 - 1, 0);
	shade = mix(stump_step(k, a, d0), stump_step(k, a, d1), f);
	return mix(mix(stump_step(k, a, s0), stump_step(k, a, s1), f), shade, back);
}

// What the sun's light must be for the albedo `albedo` (linear, as light() has it) to show
// as `shade` (as ALBEDO is written) would under the light `lit`: the base pass has drawn
// albedo * ambient_light already. Compatibility adds the sun's pass to it in sRGB (see
// compat_sun), Mobile in linear light.
vec3 sun_as(vec3 lit, vec3 albedo, vec3 shade) {
	vec3 s = shade * (shade * (shade * 0.305306011 + 0.682171111) + 0.012522878);
	vec3 base = albedo * ambient_light;
	vec3 sum = max(1.055 * pow(s * ambient_light, vec3(0.416666667)) - 0.055, vec3(0.0))
		+ max(1.055 * pow(s * lit, vec3(0.416666667)) - 0.055, vec3(0.0));
	vec3 inv = 1.0 / max(albedo, vec3(1e-4));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 add = max(sum - max(1.055 * pow(base, vec3(0.416666667)) - 0.055, vec3(0.0)), vec3(0.0));
	return pow((add + 0.055) / 1.055, vec3(2.4)) * inv;
#else
	if (sun_shadowed < 0.5) {
		return max(s * (ambient_light + lit) - base, vec3(0.0)) * inv;
	}
	sum = min(sum, vec3(1.0));
	return max(sum * (sum * (sum * 0.305306011 + 0.682171111) + 0.012522878) - base, vec3(0.0)) * inv;
#endif
}

void fragment() {
	vec2 at = px;
#ifdef FALLING
	bool tile = tile_mid.x >= 0.0;
	if (tile) {
		// A module of a falling crown: its texels as they are about the one it hangs on; its
		// own leaves, or round them its ring's (FALL_OVERLAP).
		at = tile_mid + 0.5 + floor(px) + 0.5 - fall_shear.zw;
		bool own = all(equal(fall_owner(at), fall_shear.xy));
		vec2 from_home = abs(at + fall_jag(at) - fall_home(fall_shear.xy));
		bool behind = tile_ring > 0.5 && dot(tile_mid + 0.5 - at - fall_jag(at), fall_turn.xy) > fall_turn.z;
		if (max(from_home.x, from_home.y) > FALL_REACH + FALL_OVERLAP || own == (tile_ring > 0.5) || behind) {
			discard;
		}
	} else if (fading >= 0.0) {
		// Falling (FALL_ROOM): the pixel's way from the stump's top on the screen, the turn
		// left after whole quarters undone by three shears of whole pixels, the quarters
		// undone, then the rows' squash and shear: the texel it shows.
		vec2 d = floor(px) + 0.5 - fall_shear.zw;
		float x1 = d.x - round(fall_turn.x * d.y);
		float y0 = d.y - round(fall_turn.y * x1);
		vec2 e = vec2(x1 - round(fall_turn.x * y0), y0);
		for (int i = 0; i < int(fall_turn.z + 0.5); i++) {
			e = vec2(e.y, -e.x);
		}
		if (abs(fall_turn.w) < 0.05) {
			discard;
		}
		float ty = round(e.y / fall_turn.w);
		float tx = round((e.x - fall_shear.y * ty) / max(fall_shear.x, 0.05));
		at = vec2(shake.x + tx, shake.y - FALL_CUT * TEXELS + ty);
	} else
#endif
	if (shake.x != 0.0) {
		// A shaken tree leans in whole pixels, the more the higher (as leaves.gdshader's crowns).
		at.x -= round(shake.x * clamp((shake.y - px.y) / (SHAKE_RISE * TEXELS), 0.0, 1.0));
	}
	if (sway_phase >= 0.0) {
		// Swayed by the wind module by module (SWAY_*): the pixel's module moves its leaves by
		// whole pixels; what is not a leaf stays where it is drawn.
		at = sway_texel(at, cell, shake.y, sway_phase, TIME);
	}
	if (at.x < 0.0 || at.y < 0.0 || at.x >= cell.z || at.y >= cell.w) {
		discard;
	}
#ifdef FALLING
	// A falling tree leaves its stump's rows behind, and fades out once it lies.
	if (fading >= 0.0 && at.y > shake.y - FALL_CUT * TEXELS) {
		discard;
	}
#endif
	ivec2 t = ivec2(cell.xy + floor(at));
	vec4 g = texelFetch(frames, t, 0);
	int a = frame_code(g);
#ifdef FALLING
	// A falling tree: the leaves in its modules (FALL_MODULE), the rest turned whole.
	if (fading >= 0.0 && (a != 0 && a != 2 && a != 3) != tile) {
		discard;
	}
#endif
	vec2 texel = light_texel(light_xz);
#ifdef FALLING
	if (fading > 0.0 && bayer4(texel) < fading) {
		discard;
	}
#endif
	if (cut_hides(world_pos, texel)) {
		discard;
	}
	float k = info.x;
	// The sun (or the moon) where it stands in the world, in the frame of the drawing shown
	// (x right, y up, z toward the camera, of the step the camera rests at): turning the
	// camera, a tree shows the side the sun lights or the one in its shade, as the shadows
	// on the ground stay where they fall. sun_view is the sun in the view's frame (x right,
	// y up the screen, z up in the world).
	vec2 right = vec2(-view_up.y, view_up.x);
	vec2 sun_xz = right * sun_view.x + view_up * sun_view.y;
	vec2 rest_up = rest_view.xy;
	vec3 L = normalize(vec3(dot(sun_xz, vec2(-rest_up.y, rest_up.x)), sun_view.z, -dot(sun_xz, rest_up)));
	// Autumn and winter take the leaves bundle by bundle from the crown's edge in, the outer
	// ranks first and each rank's bundles in their own order: the bare tree shows through
	// where they are gone; the dark mass inside goes a little ahead of the bundles over it.
	// A tree keeping its dry leaves keeps them all (picture_leaves).
	float amount = picture_leaves(info.y);
	if (a >= 128) {
		float rank = float((a >> 2) & 3);
		if ((rank + hash12(g.rg * 255.0 + foot_pos.xz * 3.1)) / 4.0 > amount) {
			a = 0;
		}
	} else if (a == 1 && g.r > amount - 0.08) {
		a = 0;
	}
	vec3 col;
	vec3 shade = vec3(-1.0);
	// Snow in winter on what the tree shows then: over all else where it lies; a leaf under
	// its lower edge a step darker.
	int snow = info.y < -0.5 ? 0 : snow_on(t, int(cell.w - floor(at.y)) - 1, int(k), info.y, amount);
	if (info.y < -0.5) {
		// A stump (TreeSprites.STUMP): its bark as the trees' (no crown over it), its cut, the
		// snow on it.
		if (a == 0) {
			discard;
		}
		// A stump is low: it never clears for the player behind it or on it (the user's ask,
		// 2026-11-26); a piece of wood lying long does.
		if (info.y < -2.5 && bayer4(texel) < trunk_through(texel, world_pos)) {
			discard;
		}
		if (a == 2 || a == 3) {
			int bits = int(round(g.r * 255.0)) | (int(round(g.g * 255.0)) << 8);
			ivec2 lo = ivec2(cell.xy);
			ivec2 look = bark_look(t, false, bits, lo, lo + ivec2(cell.zw), info.y > -2.5 && at.y > shake.y - BASE_RISE);
			if (bits < 0) {
				discard;
			}
			col = wood_colour(k, g, g, look, L, shade);
			if (a == 3) {
				col = mix(col, ramp(k, 7.0), 0.5);
				shade = mix(shade, ramp(k, 7.0), 0.5);
			}
		} else {
			col = stump_colour(k, g, a, L, shade);
		}
		if (info.y < -2.5) {
			// A piece of wood lying in the woods takes no sun's shadow: its own, cast from its
			// picture laid over the ground (tree_shadow.gdshader), would fall on it.
			shade = vec3(-1.0);
		}
	} else if (snow >= 16384) {
		if (bayer4(texel) < see_through(texel, world_pos)) {
			discard;
		}
		float s = snow_step(snow, L);
		col = snow_colour(snow, s);
		shade = snow_colour(snow, max(s - 1.0, 1.0));
	} else {
		float under_snow = snow == 1 ? 1.0 : 0.0;
		// A palm trunk's soft outline is wood drawn half way to the bark's darkest.
		bool soft = a == 3;
		if (soft) {
			a = 2;
		}
		// Once most leaves are gone the bark shows as the bare tree has it, without the
		// crown's shade over the trunk. The bare tree's steps are the bark's where no crown
		// shades it (`open`, see wood_colour).
		vec4 open = g;
		bool from_bare = false;
		if (a == 0 || a == 2 && amount < 0.5) {
			vec4 b = texelFetch(bare_frames, t, 0);
			if (b.r > 0.998 && b.a > 0.998) {
				if (a == 0) {
					discard;
				}
			} else {
				g = vec4(b.r, b.a, 0.0, 1.0);
				from_bare = true;
			}
			open = g;
			a = 2;
		} else if (a == 2) {
			vec4 b = texelFetch(bare_frames, t, 0);
			if (b.r < 0.998 || b.a < 0.998) {
				open = vec4(b.r, b.a, 0.0, 1.0);
			}
		}
		if (a == 2) {
			if (bayer4(texel) < trunk_through(texel, world_pos)) {
				discard;
			}
			int bits = int(round(g.r * 255.0)) | (int(round(g.g * 255.0)) << 8);
			ivec2 lo = ivec2(cell.xy);
			ivec2 look = bark_look(t, from_bare, bits, lo, lo + ivec2(cell.zw), at.y > shake.y - BASE_RISE);
			if (bits < 0) {
				discard;
			}
			col = wood_colour(k, g, open, look, L, shade);
			if (soft) {
				col = mix(col, ramp(k, 7.0), 0.5);
				shade = mix(shade, ramp(k, 7.0), 0.5);
			}
		} else {
			if (bayer4(texel) < see_through(texel, world_pos)) {
				discard;
			}
			int rule = int(round(ramp(k, 11.0).r * 3.0));
			// Autumn colours differ from tree to tree; evergreens hardly change (as
			// leaves.gdshader's).
			vec3 season = foliage_tint * (1.0 + (hash12(floor(foot_pos.xz / 3.0) + 5.0) - 0.5) * (foliage_tint - 1.0) * vec3(0.5, 0.8, 1.0));
			season = info.y > 0.5 && info.y < 0.7 ? mix(vec3(1.0), season, 0.15) : season;
			vec3 tint = season * (1.0 - 0.25 * wetness);
			vec2 steps = vec2(-1.0);
			if (a == 1) {
				steps = vec2(1.0);
				col = ramp(k, 1.0);
			} else if (rule == FRONDS) {
				steps = frond_steps(g, a, L);
				col = ramp(k, steps.x);
				shade = ramp(k, steps.y);
			} else if (rule == PALMS) {
				col = palm_colour(k, g, texelFetch(bare_frames, t, 0), a, L, shade);
			} else if (rule == HANGING) {
				steps = hanging_steps(g, a, L);
			} else {
				steps = leaf_steps(g, a, L);
			}
			if (under_snow > 0.5 && steps.x >= 0.0) {
				steps = max(steps - 1.0, 0.0);
				if (rule == FRONDS) {
					col = ramp(k, steps.x);
					shade = ramp(k, steps.y);
				}
			}
			if (rule == MODULES && a >= 128 && ramp_texel(int(k), BLOSSOM_AT).a > 0.5 && blossom_amount > 0.0
					&& in_blossom(g, a, foot_pos.xz)) {
				// In blossom: the blossom's own steps, not tinted by the season.
				float c = blossom_step(steps.x, ivec2(floor(at)), ivec2(cell.zw), t, L, foot_pos.xz, amount);
				col = steps_colour(k, c, BLOSSOM_AT) * (1.0 - 0.25 * wetness);
				shade = steps_colour(k, steps.y, BLOSSOM_AT) * (1.0 - 0.25 * wetness);
			} else {
				if (rule == MODULES || rule == HANGING) {
					col = leaf_colour(k, steps.x);
					shade = leaf_colour(k, steps.y);
				}
				col *= tint;
				shade = shade.r >= 0.0 ? shade * tint : shade;
				// The dry leaves of a tree keeping them come as the others fall (leaf_amount from
				// autumn's to winter's), in their own steps.
				float dry = info.y > 0.95 ? clamp((0.8 - leaf_amount) / 0.25, 0.0, 1.0) : 0.0;
				if (dry > 0.0 && steps.x >= 0.0 && ramp_texel(int(k), DRY_AT).a > 0.5) {
					col = mix(col, steps_colour(k, steps.x, DRY_AT) * (1.0 - 0.25 * wetness), dry);
					shade = shade.r >= 0.0 ? mix(shade, steps_colour(k, steps.y, DRY_AT) * (1.0 - 0.25 * wetness), dry) : shade;
				}
			}
		}
	}
	// The fog as at a point FOG_AHEAD in front of the picture: on its own plane, the
	// trunk's columns (whose tops the fog takes for ground, see fog_at) lay a thin band
	// of thicker fog up the middle of the trunk and the crown.
	vec3 fog_pos = world_pos - vec3(view_up.x, 0.0, view_up.y) * FOG_AHEAD;
	vec4 veiled = veil(fog_pos, depth_fade(world_pos.y));
	float sun_part = sea_bright(world_pos.y);
	// The drawings' colours are the ground's at noon: lit as a sprite the picture comes
	// out brighter than the grass beside it by this much (measured on the oak, 2026-11-25).
	vec3 lit_col = col * TONE * (1.0 - veiled.a);
	ALBEDO = lit_col * sun_part;
	lamp_gain = sea_undo(lit_col, sun_part);
	shaded = shade.r >= 0.0 && shade != col ? shade * TONE * (1.0 - veiled.a) * sun_part : vec3(-1.0);
	EMISSION = veiled.rgb;
	// Lit as a sprite: as if facing up and toward the viewer.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.6, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(world_pos);
	COMPAT_COLORS
}

void light() {
	float stretch = light_reach;
	vec3 lit = toon_light(LIGHT_IS_DIRECTIONAL ? NORMAL : LIGHT, LIGHT, LIGHT_COLOR,
		LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds, light_texel(light_xz), stretch);
	if (!LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += lit * lamp_gain;
	} else if (shaded.r >= 0.0 && ATTENUATION < 0.5) {
		// Bark and leaves in the sun's shadow (as the ground takes it: of another tree, a
		// hill, the tree's own crown over its bark where the drawing has it lit) show their
		// shade's colour under the same light.
		DIFFUSE_LIGHT += sun_as(lit, ALBEDO, shaded);
	} else {
		DIFFUSE_LIGHT += compat_sun(lit, ALBEDO);
	}
}
