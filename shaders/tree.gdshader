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

// Trees falling, felled (TreeHits.fall: up to 4): the foot of the trunk (xyz) and how far
// the tree has turned over (w, radians), the way it falls (x, z) and how far it has faded
// out (w, 0..1, once it lies). It turns over about the stump's top, FALL_CUT over the
// foot; the rows under that are the stump's, which stays (TreeSprites).
uniform vec4 falls[4];
uniform vec4 fall_ways[4];
uniform int fall_count = 0;
const float FALL_CUT = 0.5;

varying vec2 px;
varying flat vec4 cell;
// How far a falling tree has faded out, -1 for a tree standing.
varying flat float fading;
varying flat vec2 info;
// How far this tree's top leans now (pixels), and its foot's row in the picture.
varying flat vec2 shake;
varying vec3 world_pos;
varying vec3 foot_pos;
varying vec2 light_xz;
varying float clouds;
varying vec3 lamp_gain;
// The albedo in the sun's shadow (a step darker: the bark's in_shade, the leaves'
// leaf_steps and frond_steps), as ALBEDO is written, for light() to show it where the
// shadow falls; negative where a shadow changes nothing.
varying vec3 shaded;

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	// world_vertex_coords: the quad's own corner (x 0..1 across, y -1, 0, 1) is what the
	// instance's place leaves of it.
	vec2 q = (VERTEX - foot).xy;
	vec4 c = INSTANCE_CUSTOM;
	float ax = COLOR.r;
	float ay = COLOR.g;
	float row = floor(COLOR.b / 8.0 + 0.01);
	float own = COLOR.b - row * 8.0;
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
	fading = fall >= 0 ? fall_ways[fall].w : -1.0;
	float room = lean != 0.0 ? SHAKE_ROOM : 0.0;
	// The foot on the middle of a pixel, so the picture's texels are the screen's.
	vec2 right = vec2(-view_up.y, view_up.x);
	vec2 sp = screen_plane(foot) * TEXELS;
	vec2 fix = (floor(sp) + 0.5 - sp) / TEXELS;
	foot.xz += right * fix.x - view_up * fix.y;
	foot_pos = foot;
	float wide = q.x * (c.z + 2.0 * room) - room;
	float across = wide - ax - 0.5;
	float rise = q.y >= 0.0 ? q.y * (ay + 0.5) : q.y * (c.w - ay - 0.5);
	px = vec2(wide, ay + 0.5 - rise);
	vec3 p = foot + vec3(right.x, 0.0, right.y) * (across / TEXELS);
	if (q.y > 0.0 || fall >= 0 && q.y > -0.5) {
		// Upright, kept its height in pixels at any tilt (a falling tree's foot row too,
		// turned with it).
		p.y += rise / TEXELS;
		if (fall >= 0) {
			// Turned over about the stump's top toward the way it falls (Rodrigues' turn
			// about the axis up x way, which takes up to the way).
			vec3 way = normalize(vec3(fall_ways[fall].x, 0.0, fall_ways[fall].y));
			vec3 axis = cross(vec3(0.0, 1.0, 0.0), way);
			vec3 pivot = foot + vec3(0.0, FALL_CUT, 0.0);
			vec3 v = p - pivot;
			float a = falls[fall].w;
			v = v * cos(a) + cross(axis, v) * sin(a) + axis * dot(axis, v) * (1.0 - cos(a));
			p = pivot + v;
		}
		world_pos = p;
		VERTEX = shear(stand_tall(p, foot));
	} else {
		// The rows under the ground's row lie on the ground toward the camera (the roots
		// in front of the trunk), a little over it.
		p.xz -= view_up * (-rise / TEXELS);
		p.y += 0.03;
		world_pos = p;
		VERTEX = shear(p);
	}
	light_xz = VERTEX.xz;
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

// Of two texels' bark steps (2 bits a sun), the lighter at each sun.
int lightest(int a, int b) {
	int r = 0;
	for (int k = 0; k < 8; k++) {
		r |= max((a >> (2 * k)) & 3, (b >> (2 * k)) & 3) << (2 * k);
	}
	return r;
}

ivec2 side(int i) {
	return i == 0 ? ivec2(1, 0) : i == 1 ? ivec2(-1, 0) : i == 2 ? ivec2(0, 1) : ivec2(0, -1);
}

// How the bark of texel `t` (its steps `bits`) is drawn beside its neighbours, 8 suns at a
// time (user 2026-11-26): x the suns it takes a halftone at (bit k: sun k), y its outline's
// step in halves (3 bits a sun, 7: none). A texel beside a darker step of the bark is drawn half a
// step darker, so each step steps down to the next through a halftone. A texel on the
// picture's edge is its outline: OUTLINE_DROP halves darker than the bark inside it (the texel across
// from the empty side, when that one is not an edge too), as the approved drawing's soft
// outline, kept wherever the drawing left it at the bark's own step.
const int OUTLINE_LOW = 0;
ivec2 bark_look(ivec2 t, bool bare, int bits, ivec2 lo, ivec2 hi) {
	int n[4];
	bool edge = false;
	for (int i = 0; i < 4; i++) {
		n[i] = bark_bits(t + side(i), bare, lo, hi);
		edge = edge || n[i] == -2;
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
	// The bark inside: across from an empty side, when that one is not an edge too (the
	// lightest of those).
	int inside = -1;
	for (int i = 0; i < 4; i++) {
		int m = n[i ^ 1];
		if (n[i] != -2 || m < 0) {
			continue;
		}
		ivec2 q = t + side(i ^ 1);
		bool inner_edge = false;
		for (int e = 0; e < 4; e++) {
			inner_edge = inner_edge || bark_bits(q + side(e), bare, lo, hi) == -2;
		}
		if (!inner_edge) {
			inside = inside < 0 ? m : lightest(inside, m);
		}
	}
	int outline = 0;
	for (int k = 0; k < 8; k++) {
		int c = 2 * ((bits >> (2 * k)) & 3);
		if (inside >= 0) {
			c = min(c, max(2 * ((inside >> (2 * k)) & 3) - 2, 0));
		}
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
	return vec2(max(lit, 0.0), max(lit - dark, o < 7 ? 0.5 * float(OUTLINE_LOW) : 0.0));
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
	if (shake.x != 0.0) {
		// A shaken tree leans in whole pixels, the more the higher (as leaves.gdshader's crowns).
		at.x -= round(shake.x * clamp((shake.y - px.y) / (SHAKE_RISE * TEXELS), 0.0, 1.0));
	}
	if (at.x < 0.0 || at.y < 0.0 || at.x >= cell.z || at.y >= cell.w) {
		discard;
	}
	// A falling tree leaves its stump's rows behind, and fades out once it lies.
	if (fading >= 0.0 && at.y > shake.y - FALL_CUT * TEXELS) {
		discard;
	}
	ivec2 t = ivec2(cell.xy + floor(at));
	vec4 g = texelFetch(frames, t, 0);
	int a = frame_code(g);
	vec2 texel = light_texel(light_xz);
	if (fading > 0.0 && bayer4(texel) < fading) {
		discard;
	}
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
		if (bayer4(texel) < trunk_through(texel, world_pos)) {
			discard;
		}
		if (a == 2 || a == 3) {
			int bits = int(round(g.r * 255.0)) | (int(round(g.g * 255.0)) << 8);
			ivec2 lo = ivec2(cell.xy);
			col = wood_colour(k, g, g, bark_look(t, false, bits, lo, lo + ivec2(cell.zw)), L, shade);
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
			col = wood_colour(k, g, open, bark_look(t, from_bare, bits, lo, lo + ivec2(cell.zw)), L, shade);
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
	vec4 veiled = veil(world_pos, depth_fade(world_pos.y));
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
