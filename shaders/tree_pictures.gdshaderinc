// The trees drawn as pictures (TreeSprites): what a frames texel is (frame_code), their
// ramps (a row a species in the frames atlas from `ramps_at`, TreeSprites.RAMP_W), the snow
// lying on them in winter and the leaves a tree keeps. For tree.gdshader and
// tree_shadow.gdshader, after common.gdshaderinc; they declare `frames`, `ramps_at` and
// `snow_frames`.
//
// A snow texel (snow_frames: two bytes, red the low, alpha the high; export_pr4.py in
// survivium-builds/trees-redraw/integration/pr4/src) is the approved winter drawing's
// (round 23, sheets 95 and 96): the high byte's top two bits its kind, 0 none (but a texel 1
// marks a leaf or frond under the snow's lower edge, a step darker), 1 snow, 2 its soft
// outline (half way to the darkest step), 3 the seam where it lies over other snow (half way
// to the next step); the low byte's top bit its rule:
//   0, lit by a normal (a ball of snow, a patch of them, a cap on a crown): the normal on the
//     half of the sphere facing the camera, octahedral, 5 bits in each byte, in the frame of
//     the picture (x right, y up the picture, z toward the camera, the drawing's camera
//     looking down at 45 degrees); the low byte's bits 5..6 how many steps its own shade
//     takes (the low or far balls), the high byte's bit 5 a cap (its light lifted 0.2, not
//     0.25, its normal as long as SNOW_CAP_LONG says);
//   1, a conifer's frond: its step when the sun is on the side the frond's upper edge faces
//     (bits 0..2) and when not (3..5), the high byte's bit 5 that side (right).
const int SNOW_AT = 26;
const int DRY_AT = 12;
const int BLOSSOM_AT = 19;
const int SNOW_NONE = 32768;
// The snow's 6 steps (the user's reference, references/user-palms-snow.jpg), darkest first.
const vec3 SNOW_STEPS[6] = vec3[](vec3(0.251, 0.329, 0.361), vec3(0.455, 0.533, 0.596),
	vec3(0.533, 0.627, 0.659), vec3(0.659, 0.737, 0.769), vec3(0.816, 0.894, 0.894),
	vec3(0.941, 0.988, 0.988));
// A cap's normal (0.6 x, y, z: winter23.cap2) is as long as 1 / sqrt(1 - SNOW_CAP_LONG y^2)
// of its direction's y.
const float SNOW_CAP_LONG = 0.4;
// The snow on a tree comes as the snow cover grows (snow_amount, from SNOW_FIRST, all of it
// at SNOW_FULL): a ball or a cap grows from its middle out, a frond's snow from the frond up
// (FROND_DEEP texels at most).
const float SNOW_FIRST = 0.05;
const float SNOW_FULL = 0.6;
const int FROND_DEEP = 4;

// What a frames texel `g` is, by its alpha: 0 nothing, 1 the crown's dark mass, 2 bark, 3 a
// palm trunk's soft outline, 128 and over a leaf, a frond or a strand (their bits). The codes
// under 128 are stored 64 higher (65, 66, 67): the engine's import (fix_alpha_border, on
// for every picture) gives a texel under alpha 20 the colour of a leaf near it, and their
// colour is the bark's steps.
int frame_code(vec4 g) {
	int a = int(round(g.a * 255.0));
	return a < 128 ? a & 63 : a;
}

vec4 ramp_texel(int k, int i) {
	return texelFetch(frames, ramps_at + ivec2(i, k), 0);
}

// Where the snow pictures of ramp row `k` lie in the snow atlas from its frames (`which`:
// 0 the winter look's, 1 the dry crown's); false when it has none.
bool snow_place(int k, int which, out ivec2 delta) {
	ivec4 b = ivec4(round(ramp_texel(k, SNOW_AT + which) * 255.0));
	int dx = b.r | (b.g << 8);
	int dy = b.b | (b.a << 8);
	delta = ivec2(dx >= 32768 ? dx - 65536 : dx, dy >= 32768 ? dy - 65536 : dy);
	return dx != SNOW_NONE;
}

int snow_code(ivec2 t, ivec2 delta) {
	vec4 s = texelFetch(snow_frames, t + delta, 0);
	return int(round(s.r * 255.0)) | (int(round(s.a * 255.0)) << 8);
}

// The direction of the normal of a snow texel's `code` lit by a normal (rule 0), in the
// frame of the picture.
vec3 snow_normal(int code) {
	vec2 e = vec2(float(code & 31), float((code >> 8) & 31)) / 31.0 * 2.0 - 1.0;
	return normalize(vec3(e, max(0.0, 1.0 - abs(e.x) - abs(e.y))));
}

// Whether the snow has come to texel `t` (its `code`, `below` rows of its picture under it),
// the snow on the trees `grown` of the way (0..1): a ball's or a cap's texels as far from its
// middle as `grown` of its radius (by the normal), a frond's while the snow under them on
// the frond is less than `grown` of FROND_DEEP texels deep.
bool snow_fallen(int code, ivec2 t, ivec2 delta, int below, float grown) {
	if (grown >= 1.0) {
		return true;
	}
	if ((code & 128) == 0) {
		return snow_normal(code).z >= sqrt(1.0 - grown * grown);
	}
	float deep = grown * float(FROND_DEEP);
	int d = 0;
	while (float(d) < deep && d < below && snow_code(t + ivec2(0, d + 1), delta) != 0) {
		d++;
	}
	return float(d) < deep;
}

// The snow's step (1..5) of a texel's `code` (kind > 0) under the light L (in the frame of
// the drawing, as tree.gdshader's).
float snow_step(int code, vec3 L) {
	int r = code & 255;
	int g = code >> 8;
	if ((r & 128) != 0) {
		bool upper = (L.x >= 0.0) == (((g >> 5) & 1) != 0);
		return float(upper ? r & 7 : (r >> 3) & 7);
	}
	vec3 n = snow_normal(code);
	bool cap = ((g >> 5) & 1) != 0;
	float long_n = cap ? inversesqrt(max(1e-4, 1.0 - SNOW_CAP_LONG * n.y * n.y)) : 1.0;
	// The sun in the picture's frame: x, up the picture, toward the camera.
	vec3 l = vec3(L.x, (L.y - L.z) * 0.70710678, (L.y + L.z) * 0.70710678);
	float d = long_n * dot(n, l) + (cap ? 0.2 : 0.25);
	float b = d > 0.78 ? 5.0 : (d > 0.5 ? 4.0 : (d > 0.2 ? 3.0 : (d > -0.1 ? 2.0 : 1.0)));
	return max(b - float((r >> 5) & 3), 1.0);
}

// The snow's colour at step `s` of a texel's `code` (its kind: snow, outline or seam).
vec3 snow_colour(int code, float s) {
	int kind = code >> 14;
	vec3 c = SNOW_STEPS[int(s)];
	return kind == 2 ? mix(c, SNOW_STEPS[0], 0.5) : (kind == 3 ? mix(c, SNOW_STEPS[1], 0.5) : c);
}

// The share of its leaves a pictured tree still has (leaves_left), but one that keeps its
// dry leaves keeps its whole crown, as the approved winter drawing has it (the dry leaves
// under the snow caps).
float picture_leaves(float kind) {
	return kind > 0.95 ? 1.0 : leaves_left(kind);
}

// The snow code of texel `t` (`below` rows of its picture under it) of the tree of ramp row
// `k`, what it does over the year `kind` (Foliage's) and leaves left `amount`: 0 none or not
// fallen yet. The winter look's snow shows once its leaves are gone, the dry crown's on a
// tree keeping them, an evergreen's and a dead tree's always.
int snow_on(ivec2 t, int below, int k, float kind, float amount) {
	float grown = clamp((snow_amount - SNOW_FIRST) / (SNOW_FULL - SNOW_FIRST), 0.0, 1.0);
	if (grown <= 0.0) {
		return 0;
	}
	int which = kind > 0.95 ? 1 : 0;
	ivec2 delta;
	if (which == 0 && kind > 0.7 && kind < 0.85 && amount > 0.1 || !snow_place(k, which, delta)) {
		return 0;
	}
	int code = snow_code(t, delta);
	return code != 0 && snow_fallen(code, t, delta, below, grown) ? code : 0;
}
