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
// bare_frames: the tree without its crown in the same places (grey and alpha the bark's
// steps as wood's red and green, both 1 where no wood), shown where autumn and winter have
// taken its leaves.
// Lit as the sprites are, as a whole; the steps of light inside are drawn by the rules of
// the approved drawing (bundles by their normal, leaves by their facing, bark by sun).
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, shadows_disabled;
// Like a crown's for the player's silhouette (sprite_xray).
stencil_mode write, compare_always, 3;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D frames : filter_nearest;
uniform sampler2D bare_frames : filter_nearest;
// A row a species: the leaves' 7 steps, then the bark's 4, as drawn (sRGB).
uniform sampler2D ramps : filter_nearest;

// The rules of the approved drawing (render7.Tree, trees22.tree): a bundle is light
// (step 4) facing the sun over D1, half (3) over D2, else shade (2); the palest step only
// over DP.
const float D1 = 0.64;
const float D2 = 0.36;
const float DP = 0.8;
const float TONE = 0.8;
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

varying vec2 px;
varying flat vec4 cell;
varying flat vec2 info;
// How far this tree's top leans now (pixels), and its foot's row in the picture.
varying flat vec2 shake;
varying vec3 world_pos;
varying vec3 foot_pos;
varying vec2 light_xz;
varying float clouds;
varying vec3 lamp_gain;

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
	cell = vec4(c.x + side * c.z, c.y, c.z, c.w);
	info = vec2(row, COLOR.a);
	float lean = 0.0;
	for (int i = 0; i < shake_count; i++) {
		if (length(shakes[i].xz - foot.xz) < 0.1) {
			lean += shakes[i].w;
		}
	}
	shake = vec2(lean, ay + 0.5);
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
	if (q.y > 0.0) {
		// Upright, kept its height in pixels at any tilt.
		p.y += rise / TEXELS;
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
	return texelFetch(ramps, ivec2(int(i), int(k)), 0).rgb;
}

// The colour of ramp row `k` at step `c` (0..6, quarters between two steps mixed).
vec3 leaf_colour(float k, float c) {
	float lo = floor(c);
	return mix(ramp(k, lo), ramp(k, min(lo + 1.0, 6.0)), c - lo);
}

// The leaves' step (0..6) of a leaf texel `g` (alpha bits `a`) under the light L.
float leaf_step(vec4 g, int a, vec3 L) {
	vec3 n = unocta(g.rg);
	float d = dot(n, L);
	float base = d > D1 ? 4.0 : (d > D2 ? 3.0 : 2.0);
	float c;
	if ((a & 3) == 2) {
		c = base - 1.0;
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
		if (base < 2.5 && t < t0) {
			t = t0 + 0.75 * (t - t0);
		}
		c = base + t;
	}
	if (d < DP) {
		c = min(c, 5.0);
	}
	return clamp(c, 0.0, 6.0);
}

// The bark's colour of wood texel `g` (red, green: 2 bits a sun) under the light L: the
// two drawn suns nearest it, crossfaded only round the middle between them.
vec3 wood_colour(float k, vec4 g, vec3 L) {
	int bits = int(round(g.r * 255.0)) | (int(round(g.g * 255.0)) << 8);
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
	float f = 0.5 * smoothstep(0.3, 0.5, a0 / max(a0 + a1, 1e-4));
	vec3 c0 = ramp(k, 7.0 + float((bits >> (2 * best)) & 3));
	vec3 c1 = ramp(k, 7.0 + float((bits >> (2 * next)) & 3));
	return mix(c0, c1, f);
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
	ivec2 t = ivec2(cell.xy + floor(at));
	vec4 g = texelFetch(frames, t, 0);
	int a = int(round(g.a * 255.0));
	vec2 texel = light_texel(light_xz);
	if (cut_hides(world_pos, texel)) {
		discard;
	}
	float k = info.x;
	// The sun (or the moon) as in the default view, in the drawing's frame (x right, y
	// up, z toward the camera): the light turns with the view as the shadows do (Sky), so
	// a tree's lit side and its shadow stay where they are on the screen at every turn, as
	// the approved drawings have it. sun_view is the sun in the view's frame (x right,
	// y up the screen, z up in the world), turned back to the world's.
	vec2 right = vec2(-view_up.y, view_up.x);
	vec2 sxz = right * sun_view.x + view_up * sun_view.y;
	vec3 L = normalize(vec3(sxz.x, sun_view.z, sxz.y));
	// Autumn and winter take the leaves bundle by bundle from the crown's edge in, the outer
	// ranks first and each rank's bundles in their own order: the bare tree shows through
	// where they are gone; the dark mass inside goes a little ahead of the bundles over it.
	float amount = leaves_left(info.y);
	if (a >= 128) {
		float rank = float((a >> 2) & 3);
		if ((rank + hash12(g.rg * 255.0 + foot_pos.xz * 3.1)) / 4.0 > amount) {
			a = 0;
		}
	} else if (a == 1 && g.r > amount - 0.08) {
		a = 0;
	}
	vec3 col;
	// Once most leaves are gone the bark shows as the bare tree has it, without the
	// crown's shade over the trunk.
	if (a == 0 || a == 2 && amount < 0.5) {
		vec4 b = texelFetch(bare_frames, t, 0);
		if (b.r > 0.998 && b.a > 0.998) {
			if (a == 0) {
				discard;
			}
		} else {
			g = vec4(b.r, b.a, 0.0, 1.0);
		}
		a = 2;
	}
	if (a == 2) {
		if (bayer4(texel) < trunk_through(texel, world_pos)) {
			discard;
		}
		col = wood_colour(k, g, L);
	} else {
		if (bayer4(texel) < see_through(texel, world_pos)) {
			discard;
		}
		col = a == 1 ? ramp(k, 1.0) : leaf_colour(k, leaf_step(g, a, L));
		// Autumn colours differ from tree to tree (as leaves.gdshader's).
		vec3 season = foliage_tint * (1.0 + (hash12(floor(foot_pos.xz / 3.0) + 5.0) - 0.5) * (foliage_tint - 1.0) * vec3(0.5, 0.8, 1.0));
		col *= season * (1.0 - 0.25 * wetness);
	}
	vec4 veiled = veil(world_pos, depth_fade(world_pos.y));
	float sun_part = sea_bright(world_pos.y);
	// The drawings' colours are the ground's at noon: lit as a sprite the picture comes
	// out brighter than the grass beside it by this much (measured on the oak, 2026-11-25).
	vec3 lit_col = col * TONE * (1.0 - veiled.a);
	ALBEDO = lit_col * sun_part;
	lamp_gain = sea_undo(lit_col, sun_part);
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
	DIFFUSE_LIGHT += LIGHT_IS_DIRECTIONAL ? compat_sun(lit, ALBEDO) : lit * lamp_gain;
}
