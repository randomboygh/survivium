// Water: see-through over shallows and darker in the deep, foam that laps at the
// shore, drifting ripple lines and sparkles, rain rings, the sun's path at sunrise and
// sunset, ice in winter (footprints
// on the ice are tracks.gd's).
// UV2.x: foam bits for the half edges that touch land (2 per edge N, S, W, E: the
// west or north half, then the other), then for the diagonals of corners NW, NE, SE,
// SW filled with land, then for those of cut-off corners of the land beside, then
// the shape of each of those four corners' curves (2 bits each, see corner_distance);
// UV2.y: depth of the water column in cells (half a world unit each).
// COLOR.r: depth of the water over the ground at the vertex, in cells / 8, blended
// across a top so the water darkens smoothly over a sloping bed; COLOR.g: on water
// lying over the slope of a shore, how far under the surface the ground is there in
// cells (foam where it comes up to it), 1 elsewhere; COLOR.b: 0.5 and over for water
// over a shore (ice does not lift it), plus how murky the water is times 0.45 (0 clear,
// 0.5 a swamp's, 1 a bog's), blended across the cells (ChunkMesher._kind).
// Waterfalls (WaterMesher.fall_faces): vertex alpha FALL_SHEET marks the sheet of water
// falling over a step of a river, whose UV2 is then the levels of its lip and its foot;
// FALL_FOAM the foam on the water where it lands (UV: cells along the fall from its step
// and across it; UV2.x where the patch ends along it, UV2.y which sides spill over open
// water, 1 left, 2 right); FALL_SPRAY the spray and mist over its foot, an upright quad
// turned to the camera (its corners at its root, UV their offsets in cells, UV2 its
// height in cells and a number of its own); SEA_ALPHA the sea's water
// (WorldData.SEA_WATER), the only water the plankton glows in, SURF_ALPHA the sea's
// water in its top level, where the surf is its shore's outline; SWASH_ALPHA the surf
// washing over the land level with the sea (WaterMesher.swash: COLOR.r is how far from
// the waterline, in cells + 0.5, / 8).
shader_type spatial;
render_mode world_vertex_coords, blend_mix, cull_back, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"
#include "res://shaders/ice.gdshaderinc"

uniform float ice_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shallow SRGB = vec3(0.36, 0.62, 0.6);
uniform vec3 deep SRGB = vec3(0.13, 0.29, 0.42);
uniform vec3 foam_color SRGB = vec3(0.85, 0.93, 0.92);
// The murky water of a swamp, shallow and deep, and the murkier water of a bog.
uniform vec3 swamp_shallow SRGB = vec3(0.37, 0.43, 0.25);
uniform vec3 swamp_deep SRGB = vec3(0.2, 0.26, 0.16);
uniform vec3 bog_color SRGB = vec3(0.33, 0.31, 0.19);
uniform vec3 swamp_foam SRGB = vec3(0.62, 0.65, 0.5);
// 0 by day, up to 1 on the rare warm nights it glows (sky.gd glowing_night): how much the
// surf and a swimmer's wake glow blue where the plankton is (bays of it, by a slow noise).
global uniform float sea_glow;
// The way the player swam (WaterEffects): points left behind, newest first (x, y along
// the ground, z how bright the plankton still glows there, 0..1, w the water's height);
// the wake glows along the path from the player through them and fades where it is old.
uniform vec4 wake_trail[8];
uniform float wake_now = 0.0;
const vec3 PLANKTON = vec3(0.2, 0.62, 1.0);
// The sun's path on the water while the sun is low (AirEffects): xy the way to the sun
// along the ground, z how strong (0 none), w how steeply the light comes down (rise per
// unit along the ground); glints thick on a band from the player towards it, widening
// as it goes, in sun_path_color, only where the light reaches the water (sun_reaches).
uniform vec4 sun_path = vec4(0.0);
uniform vec3 sun_path_color SRGB = vec3(1.0, 0.8, 0.5);
// Fires, torches and lamps glittering on the water (WaterEffects): each x, z, height and
// how strongly (0 none); the glitter runs from under the light towards the viewer
// (glint_toward, along the ground), flickering.
uniform vec4 fire_glints[4];
uniform vec2 glint_toward = vec2(0.0, 1.0);
const vec3 FIRE_GLINT = vec3(1.0, 0.62, 0.28);

// The waves the wind raises on open water (WaterEffects._waves): x the way they ran
// before, y the way they run now (one of 8, 0 to the east, 2 to the south), z how far
// they have turned from the one to the other (0..1, dithered texel by texel), w 0 when
// they are hidden. The ways are fixed so the crests never swing round the world's
// origin as the wind turns; how rough they are is the wind's own (wind_rough).
uniform vec4 waves = vec4(0.0, 0.0, 1.0, 1.0);

// Half the width of a fall's spray and how far its foam spills to each side, in cells
// (MeshFaces.SPRAY_HALF, WaterMesher.FOAM_SIDE).
const float SPRAY_HALF = 0.75;
const float FOAM_SIDE = 0.5;
// Steps of the depth's shading, and the 4x4 ordered dither between them.
const float DEPTH_STEPS = 6.0;
const int BAYER[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

varying vec3 world_pos;
varying vec3 world_normal;
varying flat vec2 data;
// Depth over the ground and of the ground of a shore, in cells (see COLOR above).
varying float depth_here;
varying float shore_under;
varying flat int kind;
varying float murk_here;
varying float clouds;
// How much brighter a torch or a fire lights this than sea_bright left its colour (sea_undo).
varying vec3 lamp_gain;
// 1 under the open sky, where nothing casts a shadow on the surface (see light()).
varying float open_sky;
// 2 on a waterfall's sheet, 3 on its spray, 1 on the foam where it lands, 0 elsewhere.
varying flat float falls;
// 1 on the sea's water, blended to 0 on other water (see SEA_ALPHA above).
varying float sea_here;
// 1 on the surf's sheet (SWASH_ALPHA above), 2 on the sea's water where the surf runs
// on over the shore (MeshFaces.SURF_ALPHA: it draws no foam along the shore, the surf's
// front is its outline), 0 elsewhere. One varying for both: phone GPUs have few (the
// water stayed grey on Android with a varying more).
varying flat float swash;

// Ice: clear blue-green over the shallows and darker over the deep, milky frost
// patches, straight white cracks and glints that do not move, and a dusting of snow
// in the hollows of the patch noise while snow lies. Clear ice (ice_clear: its patches,
// thawed round a fire) is the ice a little darker, the fish under it seen whole, no frost or snow on it, a
// few white bubbles in it; the crust over a hole is thin and grey, its rim broken white
// (`hole` of ice_hole).
vec3 ice_color(vec2 tex, float depth, bool side, float clear, float hole) {
	vec2 xz = tex / TEXELS;
	vec3 c = mix(vec3(0.46, 0.64, 0.72), vec3(0.28, 0.43, 0.58), depth);
	if (side) {
		return c * 0.85;
	}
	if (hole > 0.4) {
		// The crust over a hole: thin, grey, a few bubbles.
		return mix(vec3(0.36, 0.48, 0.56), vec3(0.62, 0.7, 0.74), step(0.97, hash12(tex + 5.0)));
	}
	if (hole > 0.1) {
		// The rim of broken ice round a hole.
		return mix(vec3(0.82, 0.9, 0.94), vec3(0.6, 0.72, 0.8), step(0.6, hash12(tex + 9.0)));
	}
	if (clear > 0.5) {
		// Nearly the ice's own colour, a little darker: no frost or snow on it.
		c *= vec3(0.88, 0.91, 0.94);
		return mix(c, vec3(0.7, 0.8, 0.86), step(0.99, hash12(tex + 23.0)));
	}
	float frost = ground_patch(xz, 17.0);
	c = frost > 0.6 ? mix(c, vec3(0.68, 0.78, 0.84), 0.55) : (frost < 0.36 ? c * vec3(0.92, 0.96, 1.0) : c);
	// Cracks: thin bands of two still noises, on a texel grid.
	float n = texture(cloud_noise, xz / 5.0 + 0.3).r;
	float n2 = texture(cloud_noise, xz / 3.0 + 0.7).r;
	float crack = step(abs(n - 0.5), 0.008) + step(abs(n2 - 0.52), 0.006) * step(0.55, frost);
	c = mix(c, vec3(0.8, 0.88, 0.93), clamp(crack, 0.0, 1.0) * 0.85);
	float h = hash12(tex + 61.0);
	if (h > 0.994) {
		c = vec3(0.95, 0.98, 1.0);
	}
	if (ground_patch(xz, 9.0) + (h - 0.5) * 0.08 < snow_amount * 0.4 - 0.1) {
		c = mix(c, vec3(0.73, 0.76, 0.82), 0.9);
	}
	return c;
}

// Murky water, `murk` from 0.5 (a swamp's) to 1 (a bog's): green-brown, darker in
// the deep; a bog's in patches of scum and darker mud and a few bubbles.
vec3 murky_color(vec2 tex, float depth, float murk) {
	vec3 c = mix(swamp_shallow, swamp_deep, depth);
	float b = clamp(murk * 2.0 - 1.0, 0.0, 1.0);
	if (b > 0.0) {
		float p = ground_patch(tex / TEXELS, 23.0);
		vec3 m = p > 0.62 ? mix(bog_color, swamp_shallow, 0.5) : (p < 0.3 ? bog_color * 0.85 : bog_color);
		if (hash12(tex + 13.0) > 0.988) {
			m = swamp_foam;
		}
		c = mix(c, m, b);
	}
	return c;
}

// The wind on open water at world texel `tex`, `rough` 0..1 (wind_rough), `sea` true on
// the sea, `bayer` the texel's dither. A breeze ruffles patches of it into fine ripples,
// short lines across the wind sweeping along with the gusts (`ripple`); a stronger wind
// raises rows of waves across it running with the wind, each crest broken into short
// bows of a texel or two of light, their middles ahead of their ends, with a darker
// trough behind, more of them the stronger it blows (`lit`, `dark`); a gale breaks the
// middles of the bows white now and then, the foam left behind each cap fizzing away
// (`cap`); a storm draws streaks of foam along the wind (`streak`). Longer, faster waves
// on the sea than on a lake. The bows, the caps and the streaks go with the waves.
void wind_waves(vec2 tex, float rough, bool sea, float bayer, out float ripple, out float lit, out float dark, out float cap, out float streak) {
	float way = bayer < waves.z ? waves.y : waves.x;
	vec2 d = round(vec2(cos(way * PI / 4.0), sin(way * PI / 4.0)));
	float dl = length(d);
	// Texels along the wind and across it.
	float u = dot(tex, d) / dl;
	float v = dot(tex, vec2(-d.y, d.x)) / dl;
	float len = sea ? 16.0 : 10.0;
	float speed = sea ? 12.0 : 8.0;
	// Ripples: patches of the gusts' noise sweeping downwind, lines a texel thin and a
	// few long in them.
	float paw = texture(cloud_noise, tex / TEXELS / 8.0 - d / dl * TIME * 0.12).r;
	float ruffled = step(0.6 - 0.35 * rough, paw) * min(rough * 5.0, 1.0);
	float ru = u - TIME * speed * 0.5;
	ripple = ruffled * step(mod(ru, 2.0), 1.0) * step(0.78, hash12(vec2(floor(v / 3.0), floor(ru / 2.0))));
	// The rows of waves, bent a little along their length by a slow noise.
	float bend = texture(cloud_noise, vec2(v / 400.0, u / 800.0) + 0.31).r;
	float ph = (u - TIME * speed) / len + bend * 1.5;
	float k = floor(ph);
	float f = fract(ph) * len;
	// Each crest cut into stretches of `run` texels, shifted row by row; a stretch holds
	// one bow or none, more of them the stronger the wind. `n` is 1 at a bow's middle and
	// 0 at its ends, which lie `back` texels behind it.
	float run = sea ? 10.0 : 7.0;
	float sv = v / run + k * 0.37;
	float which = hash12(vec2(floor(sv), k));
	float t = fract(sv) / mix(0.55, 0.9, hash12(vec2(floor(sv), k + 0.5)));
	float on = step(which, min(rough * 1.4, 1.0) * 0.7) * step(t, 1.0);
	float n = 1.0 - (2.0 * t - 1.0) * (2.0 * t - 1.0);
	float back = floor((1.0 - n) * (sea ? 2.5 : 1.5) + 0.5);
	// Two texels thick in the middle of a bow in a stronger wind, one at its ends.
	float front = 1.0 + step(0.5, n) * step(0.35, rough);
	lit = on * step(len - front - back, f) * step(f, len - back);
	float trough = len * 0.4 - back;
	dark = on * step(trough, f) * step(f, trough + 1.0 + rough);
	// The whitecaps, in the middles of some bows: each breaks at once on a clock of its
	// own, white along the crest's front, and thins away to the next, the foam it leaves
	// behind fizzing out.
	float caps = clamp((rough - (sea ? 0.45 : 0.65)) * 2.5, 0.0, 1.0);
	cap = 0.0;
	if (on > 0.0 && which < caps * 0.45 && n > 0.25) {
		float life = fract(TIME * 0.3 + which * 7.0);
		float fizz = hash12(tex + k * 7.0);
		float edge = step(len - front - 1.0 - back, f) * step(f, len - back);
		cap = edge * step(fizz, (n + 0.3) * (1.0 - life) * 1.6)
			+ (1.0 - edge) * step(len - 7.0 - back, f) * step(f, len - back) * step(fizz, 0.35 * caps * n * (1.0 - life * 0.6));
	}
	// Foam blown into streaks along the wind in a storm: thin broken lines of a noise
	// stretched far downwind, running with the waves.
	streak = 0.0;
	float storm = clamp((rough - 0.75) * 4.0, 0.0, 1.0);
	if (storm > 0.0) {
		float sn = texture(cloud_noise, vec2(v / 70.0, (u - TIME * speed) / 1400.0) + 0.7).r;
		streak = step(abs(sn - 0.5), 0.005 + 0.003 * storm) * step(hash12(vec2(floor(v), floor((u - TIME * speed) / 3.0))), 0.2 + 0.3 * storm);
	}
}

// Where the point is in the picture, for the dither of the light rings (light_texel).
varying vec2 light_xz;

// The colour of the water at xz as a factor of its own: its biome's tint, its body's
// (the sea, a river, a lake) and the slow shading of the place, kept a texel per few
// columns in ground_low's g, b, a by RoofMap and filtered between them, so two waters
// run into each other over a few cells. Looked up from the pixel's texel nudged a random
// way by up to half a cell, so the blend keeps to the pixel grid and is dithered a little.
vec3 water_tint(vec2 xz) {
	vec2 t = floor(xz * TEXELS);
	vec2 off = vec2(hash12(t + 5.3), hash12(t + 11.7)) - 0.5;
	vec3 f = texture(ground_low, ((t + 0.5) / TEXELS + off * CELL) / wrap_size).gba;
	// Nothing filled there yet (a texture not set reads black): the colour as it is.
	return f.r + f.g + f.b > 0.0 ? f * 2.0 : vec3(1.0);
}

void vertex() {
	// Ice lies where the water stood, so it is never above the shore it is walked on
	// from (see WorldData.ice_top).
	kind = COLOR.b > 0.48 ? 2 : 0;
	murk_here = (COLOR.b - (kind == 2 ? 0.5 : 0.0)) / 0.45;
	world_pos = VERTEX;
	world_normal = NORMAL;
	data = UV2;
	falls = COLOR.a < 0.15 ? 2.0 : (COLOR.a < 0.4 ? 3.0 : (COLOR.a < 0.6 ? 1.0 : 0.0));
	swash = COLOR.a > 0.6 && COLOR.a < 0.75 ? 1.0 : (COLOR.a > 0.875 && COLOR.a < 0.95 ? 2.0 : 0.0);
	sea_here = COLOR.a > 0.6 && COLOR.a < 0.95 ? 1.0 : 0.0;
	depth_here = COLOR.r * 8.0;
	shore_under = COLOR.g;
	if (falls > 2.5) {
		// The spray stands up from its root facing the camera, as the plants do.
		vec3 root = VERTEX;
		world_pos = face_view(root + vec3(UV.x, UV.y, 0.0) * CELL, root);
		VERTEX = stand_tall(world_pos, root);
		NORMAL = vec3(0.0, 1.0, 0.0);
		world_normal = NORMAL;
	}
	VERTEX = shear(VERTEX);
	light_xz = VERTEX.xz;
}

// Whether the low sun (or moon) reaches the water at `p`: no cloud's shadow on it, and
// nothing standing in the way toward the light for SUN_LOOK steps along the ground: the
// ground rising over the line or a tree's crown it passes under (the roof map's columns;
// a crown taken as CROWN_HIGH tall over its ground). 0 hidden, 1 in the light.
const int SUN_LOOK = 8;
const float CROWN_HIGH = 4.0;
float sun_reaches(vec3 p) {
	float lit = clamp((cloud_light(p) - 0.6) / 0.4, 0.0, 1.0);
	if (lit <= 0.0) {
		return 0.0;
	}
	for (int i = 1; i <= SUN_LOOK; i++) {
		float d = float(i) * CELL * 2.0;
		vec2 xz = p.xz + sun_path.xy * d;
		float y = p.y + d * sun_path.w;
		vec4 col = column(floor(xz / CELL));
		float ground = floor(col.b * 255.0 + 0.5) * CELL;
		if (ground > y + 0.05 || (col.g > 0.5 && ground + CROWN_HIGH > y)) {
			return 0.0;
		}
	}
	return lit;
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	vec2 tex = floor(world_pos.xz * TEXELS);
	// The sea trembles in the heat (heat_wobble).
	if (heat_ground > 0.0 && sea_here > 0.5 && world_normal.y > 0.5) {
		tex.x += heat_wobble(tex, TIME);
	}
	int last = int(CELL_TEXELS) - 1;
	ivec2 t = clamp(ivec2(floor(UV * CELL_TEXELS)), ivec2(0), ivec2(last));
	int dist[4] = int[](t.y, last - t.y, t.x, last - t.x);
	// The depth in steps, dithered between them on the texel grid so the shading
	// follows the bed smoothly and stays pixel art.
	float depth = clamp(((depth_here + 0.5) * CELL - 1.0) / 3.0, 0.0, 1.0);
	ivec2 bt = ivec2(mod(tex, 4.0));
	float bayer = float(BAYER[bt.y * 4 + bt.x]) / 16.0;
	depth = clamp(floor(depth * DEPTH_STEPS + bayer) / DEPTH_STEPS, 0.0, 1.0);
	vec3 tint = water_tint(world_pos.xz);
	vec3 col = mix(shallow, deep, depth) * tint;
	float alpha = mix(0.45, 1.0, depth);
	// The ice here (none in an open hole), what of a hole is here, and whether it is clear.
	float ice = ice_amount;
	float hole = 0.0;
	float clear_ice = 0.0;
	if (ice_amount > 0.0) {
		hole = ice_hole(world_pos.xz);
		ice = hole >= 1.0 ? 0.0 : ice_amount;
		clear_ice = ice_clear(world_pos.xz);
	}
	// Murky water: the murk blended over the cells, broken up by a still patch noise
	// between its levels (clear, swamp, bog) and dithered in steps, so a swamp runs
	// into a bog (or clear water) unevenly.
	float between = abs(murk_here * 2.0 - round(murk_here * 2.0)) * 2.0;
	float murk = murk_here + (ground_patch(tex / TEXELS, 31.0) - 0.5) * between;
	murk = clamp(floor(murk * 4.0 + bayer) / 4.0, 0.0, 1.0);
	if (murk > 0.0) {
		vec3 m = murky_color(tex, depth, max(murk, 0.5));
		col = mix(col, m, min(murk * 2.0, 1.0));
		alpha = mix(alpha, mix(0.75, 1.0, depth) + 0.2 * clamp(murk * 2.0 - 1.0, 0.0, 1.0), min(murk * 2.0, 1.0));
	}
	vec3 foam_c = mix(foam_color, swamp_foam, min(murk * 2.0, 1.0));
	// How much of the surf is on this texel, for the plankton's glow.
	float surf = 0.0;
	// The sun's path and the lights glittering on the surface: light of their own.
	vec3 shine = vec3(0.0);
	// The surf's sheet over a beach's slope under the sea (WaterMesher._swash_under, green
	// SWASH_UNDER_G): behind the waterline it is the sea's water, drawn as the water.
	float sw = swash;
	if (swash > 0.5 && swash < 1.5 && shore_under < 0.75 && depth_here < 0.5) {
		sw = 2.0;
	}
	if (sw > 0.5 && sw < 1.5) {
		// The surf: the sea itself running on up over the level sand. Each wave goes on
		// from the water's edge in a thin sheet of the shallows' colour, clearer towards
		// its front, outlined by the same line of foam the water has along every other
		// shore (that water leaves it out here, see ChunkMesher), so the line runs up and
		// back with the waves and lies at the waterline while the sea is still. Going back
		// slower, the wave leaves its foam behind: a white line where it reached and lace
		// between, dissolving over the rest of its time; and the sand dark and wet behind
		// it. Along the shore the waves come in at their own times and reach as far as a
		// slow noise says, on the texel grid. None under ice.
		if (ice > 0.0) {
			discard;
		}
		// A texel of slack at the waterline, so no gap a pixel wide shows between the
		// water and the sheet.
		float far = floor((depth_here - 0.5) * CELL_TEXELS) / CELL_TEXELS;
		if (far < -1.0 / CELL_TEXELS) {
			discard;
		}
		far = max(far, 0.0);
		float front, peak, p, left, lace, fizz, wave;
		surf_wave(tex, TIME, front, peak, p, left, lace, fizz, wave);
		float edge = front - far;
		if (edge >= 0.0) {
			// The sheet: the shallows' colour at the waterline, thinning to clear water.
			float on = clamp(far / max(front, 0.1), 0.0, 1.0);
			col = mix(shallow, mix(shallow, foam_color, 0.2), on) * tint;
			alpha = mix(0.45, 0.25, on);
			if (edge < (3.5 + 2.5 * wind_rough()) / CELL_TEXELS) {
				// The foam line round the water's edge (a few texels wide, user 2026-11-18).
				col = foam_c;
				alpha = 0.95;
				surf = 1.0;
			} else if (edge < 7.0 / CELL_TEXELS && hash12(tex + wave * 7.0) > 0.35 + 0.08 * (edge * CELL_TEXELS - 3.5)) {
				col = mix(col, foam_c, 0.6);
				alpha = 0.8;
				surf = 0.5;
			} else if (left > 0.0 && abs(lace - 0.5) < 0.09 * left * smoothstep(0.5, SWASH_BASE + 0.5, far)) {
				// The left foam the water slides back over, thinning out toward the
				// sea's own water (none along the waterline itself).
				col = mix(col, foam_c, 0.8);
				alpha = 0.85;
				surf = 0.6 * left;
			}
			// Sparkles.
			col += vec3(0.3) * step(0.992, hash12(tex + floor(TIME * 3.0) * 17.0));
		} else if (far < peak && left > 0.0) {
			// The sand the wave ran over: wet and dark, and the foam it left there, a line
			// along where it reached and lace between, breaking up into fewer and fewer
			// bubbles as it dissolves.
			if (surf_left_foam(far, peak, left, lace, fizz)) {
				col = foam_c;
				alpha = 0.6 + 0.35 * left;
				surf = 0.7 * left;
			} else {
				col = vec3(0.12, 0.09, 0.05);
				alpha = 0.22 * (1.0 - smoothstep(0.4, 1.0, p));
				if (alpha < 0.02) {
					discard;
				}
			}
		} else {
			discard;
		}
	} else if (falls > 2.5) {
		// Spray and mist over a fall's foot, on the texels of the quad (x across from its
		// middle, y up from the water): drops thrown up and falling back, three to a column
		// each on a clock of its own; a churning white crown where the water lands; mist
		// rising and thinning, dithered, drifting up through a slow noise. None under ice.
		if (ice > 0.0) {
			discard;
		}
		vec2 q = floor(UV * CELL_TEXELS);
		float tall = data.x * CELL_TEXELS;
		float up = q.y / tall;
		float half_w = SPRAY_HALF * CELL_TEXELS;
		float side = 1.0 - smoothstep(0.4, 1.0, abs(q.x + 0.5) / half_w);
		bool drop = false;
		for (int j = 0; j < 3; j++) {
			float seed = hash12(vec2(q.x + data.y * 13.0, float(j) * 7.0));
			float t = TIME * (0.8 + 0.7 * seed) + seed * 5.0;
			float ph = fract(t);
			float top = tall * side * (0.25 + 0.35 * hash12(vec2(q.x + data.y, floor(t))));
			drop = drop || q.y == floor(top * 4.0 * ph * (1.0 - ph));
		}
		float bayer_s = float(BAYER[int(mod(q.y, 4.0)) * 4 + int(mod(q.x, 4.0))]) / 16.0;
		float n = texture(cloud_noise, vec2(q.x / 20.0 + data.y * 0.37, q.y / 20.0 - TIME * 0.18)).r;
		float mist = (1.0 - up) * side * smoothstep(0.3, 0.75, n);
		if (drop && up < 0.85) {
			col = foam_color;
			alpha = 0.9;
		} else if (q.y < 3.0 && hash12(q + data.y + floor(TIME * 7.0) * 5.0) < side * (0.9 - q.y / 3.0)) {
			col = foam_color;
			alpha = 0.85;
		} else if (bayer_s < mist * 0.45) {
			col = mix(foam_color, shallow, 0.15);
			alpha = 0.3;
		} else {
			discard;
		}
	} else if (falls > 1.5) {
		// The falling sheet: the water's own colour and clearness, streaks a texel wide
		// running down at their own speeds, now and then a white one, a pale lip and
		// white water at the foot.
		vec3 across = abs(world_normal.x) > 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		float tx = floor(dot(world_pos, across) * TEXELS);
		float ty = floor(world_pos.y * TEXELS);
		float speed = 10.0 + 6.0 * hash12(vec2(tx, 3.0));
		float run = hash12(vec2(tx, floor((ty + TIME * speed) / 3.0)));
		float above_foot = world_pos.y / CELL - data.y;
		float below_lip = data.x - world_pos.y / CELL;
		col = mix(shallow, deep, 0.15) * tint;
		alpha = 0.5;
		if (run > 0.93) {
			col = mix(col, foam_color, 0.5);
			alpha = 0.75;
		} else if (run > 0.7) {
			col = col * 1.2 + 0.04;
			alpha = 0.6;
		}
		if (below_lip < 1.5 / CELL_TEXELS) {
			col = mix(col, foam_color, 0.6);
			alpha = 0.8;
		}
		if (above_foot < 0.2 + 0.15 * hash12(vec2(tx, floor(TIME * 6.0)))) {
			col = foam_color;
			alpha = 0.92;
		}
	} else if (falls > 0.5) {
		// Foam where the fall lands: thick and boiling at the foot, thinning out along the
		// fall and over the open water beside into a ragged edge that tears and mends,
		// with torn bubbles beyond it (UV and data: see the top).
		vec2 q = (floor(UV * CELL_TEXELS) + 0.5) / CELL_TEXELS;
		int spill = int(data.y + 0.5);
		float edge = data.x - q.x;
		if ((spill & 1) != 0) {
			edge = min(edge, q.y + FOAM_SIDE);
		}
		if ((spill & 2) != 0) {
			edge = min(edge, 1.0 + FOAM_SIDE - q.y);
		}
		float churn = texture(cloud_noise, tex / TEXELS / 1.5 + vec2(TIME * 0.06, -TIME * 0.045)).r;
		float boil = hash12(tex + floor(TIME * 5.0) * 13.0);
		float f = clamp(edge / 0.7, 0.0, 1.0) + (churn - 0.5) * 1.4 + (hash12(tex + 71.0) - 0.5) * 0.3;
		if (f > 0.32) {
			// Bubbles in it: a few texels a shade darker, and the water showing through
			// where it is thinnest.
			col = foam_color * (boil < 0.25 ? 0.86 : 1.0);
			alpha = 0.95;
			if (f < 0.5 && boil > 0.8) {
				col = mix(col, shallow, 0.4);
				alpha = 0.7;
			}
		} else if (f > 0.12 && boil > 0.72) {
			col = mix(col, foam_color, 0.75);
			alpha = 0.8;
		} else {
			discard;
		}
	} else if (world_normal.y < 0.5) {
		// A side of water open to the air (under a fall's lip, or cut by the layers): as
		// clear as the surface over shallows, a little darker than it.
		col = mix(col, shallow * tint, 0.7 * (1.0 - min(murk * 2.0, 1.0))) * 0.92;
		alpha = 0.55;
	} else {
		// Drifting ripple lines: thin bands of a slowly moving noise.
		float n = texture(cloud_noise, (tex / TEXELS + vec2(TIME * 0.05, TIME * 0.02)) / 6.0).r;
		float n2 = texture(cloud_noise, (tex / TEXELS - vec2(TIME * 0.03, -TIME * 0.04)) / 9.0 + 0.5).r;
		// The wind's ripples and waves take their place as it gets up (wind_waves; none
		// under ice, few on a bog), the crests catching the sun's path like the lines.
		float rough = waves.w > 0.5 && ice <= 0.0 && murk < 0.9 ? wind_rough() : 0.0;
		float line = (step(abs(n - 0.55), 0.012) + step(abs(n2 - 0.45), 0.01)) * step(bayer, 1.0 - rough * 1.5);
		col = mix(col, col * 1.35 + 0.05, clamp(line, 0.0, 1.0) * 0.8 * (1.0 - 0.6 * murk));
		if (rough > 0.03) {
			float ripple, lit, dark, cap, streak;
			wind_waves(tex, rough, sea_here > 0.5, bayer, ripple, lit, dark, cap, streak);
			float amp = (0.6 + 0.4 * rough) * (0.6 + 0.4 * depth) * (1.0 - 0.6 * murk);
			col = mix(col, col * 0.82, dark * amp);
			col = mix(col, col * 1.4 + 0.07, max(lit, ripple * 0.8) * amp);
			line = max(line, lit);
			if (cap > 0.0 && murk < 0.5) {
				col = foam_c;
				alpha = max(alpha, 0.9);
			} else if (streak > 0.0 && murk < 0.5) {
				col = mix(col, foam_c, 0.5);
				alpha = max(alpha, 0.8);
			}
		}
		// Sparkles, none on a bog.
		float s = step(0.993, hash12(tex + floor(TIME * 3.0) * 17.0)) * step(murk, 0.75);
		col += vec3(0.35) * s * (1.0 - ice);
		if (sun_path.z > 0.0 && murk < 0.75) {
			vec2 off = world_pos.xz - player_pos.xz;
			float along = dot(off, sun_path.xy);
			float across = abs(dot(off, vec2(-sun_path.y, sun_path.x)));
			float width = 0.5 + max(along, 0.0) * 0.2;
			float path = step(-0.5, along) * (1.0 - smoothstep(width * 0.3, width, across))
				* (1.0 - smoothstep(6.0, 18.0, along)) * sun_path.z;
			if (path > 0.0) {
				path *= sun_reaches(world_pos);
			}
			if (path > 0.0) {
				// Glints flaring and fading a texel at a time, each on a clock of its own
				// so they come and go smoothly rather than all at once, thickest down the
				// middle, and the ripple lines catching the light.
				float t = TIME * 1.6 + hash12(tex + 41.0) * 9.0;
				float on = step(1.0 - 0.2 * path, hash12(tex + floor(t) * 23.0));
				float g = on * sin(fract(t) * 3.14159);
				shine += sun_path_color * (g * 0.9 + (line * 0.4 + 0.06) * path);
				alpha = max(alpha, 0.85 * g);
			}
		}
		for (int i = 0; i < 4; i++) {
			vec4 f = fire_glints[i];
			if (f.w <= 0.0 || abs(world_pos.y - f.z) > 1.6) {
				continue;
			}
			vec2 off = world_pos.xz - f.xy;
			float along = dot(off, glint_toward);
			float across = abs(dot(off, vec2(-glint_toward.y, glint_toward.x)));
			if (along < -0.3 || along > 5.0 || across > 0.2 + along * 0.08) {
				continue;
			}
			// Thicker near the light and down the middle, broken into texels that flicker.
			float k = f.w * (1.0 - along / 5.0) * (1.0 - across / (0.2 + along * 0.08));
			float g = step(1.0 - 0.6 * k, hash12(tex + floor(TIME * 7.0 + float(i) * 0.37) * 19.0));
			shine += FIRE_GLINT * (g * 0.9 + line * 0.5 * k);
			alpha = max(alpha, 0.9 * g);
		}
		// The shore's foam; on the sea's water where the surf runs on over the shore only
		// along walls (ChunkMesher keeps only their sides' bits there).
		{
			// Foam along the shore, washing in and out by a texel or two, a couple more in a
			// strong wind.
			float shore_wind = floor(wind_rough() * 2.5 + bayer * 0.99);
			// An exact whole number in a flat varying: its corner fills reach bit 23, where
			// `+ 0.5` would round an odd word to even.
			int foam = int(data.x);
			int mid = int(CELL_TEXELS) / 2;
			for (int e = 0; e < 4; e++) {
				int half = (e < 2 ? t.x : t.y) / mid;
				if (((foam >> (2 * e + half)) & 1) == 0) {
					continue;
				}
				float along = e < 2 ? tex.x : tex.y;
				float wash = 1.0 + shore_wind + step(0.0, sin(TIME * 1.7 + along * 0.6)) + step(0.75, hash12(vec2(along, floor(TIME * 1.5))));
				if (float(dist[e]) < wash) {
					col = foam_c;
					alpha = 0.95;
					surf = 1.0;
				} else if (float(dist[e]) < wash + 2.0) {
					col = mix(col, foam_c, 0.25);
					surf = max(surf, 0.3);
				}
			}
			// Over the slope of a shore: foam where the ground comes up to the surface, a
			// texel of shore for each eighth of a cell it lies under it.
			if (shore_under < 1.0 && sw < 1.5) {
				float wash = 1.0 + shore_wind + step(0.0, sin(TIME * 1.7 + (tex.x + tex.y) * 0.6))
					+ step(0.75, hash12(vec2(tex.x + tex.y, floor(TIME * 1.5))));
				float d = shore_under * CELL_TEXELS;
				if (d < wash) {
					col = foam_c;
					alpha = 0.95;
					surf = 1.0;
				} else if (d < wash + 2.0) {
					col = mix(col, foam_c, 0.25);
					surf = max(surf, 0.3);
				}
			}
			// Along diagonals: the water lies away from a filled corner and on the corner's
			// side of a cut one.
			for (int k = 0; k < 4 && sw < 1.5; k++) {
				bool filled = ((foam >> (8 + k)) & 1) != 0;
				if (!filled && ((foam >> (12 + k)) & 1) == 0) {
					continue;
				}
				int sd = corner_distance(t, k, (foam >> (16 + 2 * k)) & 3);
				float d = float(filled ? sd : -sd);
				float wash = 1.0 + shore_wind + step(0.0, sin(TIME * 1.7 + tex.x * 0.6)) + step(0.75, hash12(vec2(tex.x, floor(TIME * 1.5))));
				if (d < wash) {
					col = foam_c;
					alpha = 0.95;
					surf = 1.0;
				} else if (d < wash + 2.0) {
					col = mix(col, foam_c, 0.25);
					surf = max(surf, 0.3);
				}
			}
		}
		// Rain rings: each square of two by two cells gets a ring now and then while it
		// rains.
		if (wetness > 0.05) {
			vec2 cell = floor(world_pos.xz);
			float phase = fract(TIME * 0.8 + hash12(cell) * 7.0);
			vec2 c = vec2(hash12(cell + 3.0), hash12(cell + 5.0)) * 10.0 + 3.0;
			float r = length(floor(fract(world_pos.xz) * TEXELS) + 0.5 - c);
			float ring = step(abs(r - phase * 3.0), 0.5) * step(phase, 0.7) * step(hash12(cell + floor(TIME * 0.8 + hash12(cell) * 7.0)), wetness * 0.45);
			col = mix(col, col * 1.4 + 0.08, ring);
		}
	}
	float plankton = 0.0;
	// Only in the sea (not lakes, ponds or rivers).
	if (sea_glow > 0.0 && world_normal.y > 0.5 && murk < 0.5 && sea_here > 0.5) {
		// Plankton lights up blue where the surf breaks and round one swimming, flickering
		// texel by texel, in bays of it here and there.
		float bay = smoothstep(0.42, 0.6, ground_patch(world_pos.xz / 5.0, 47.0));
		// Along the way the player swam: a band glowing on the path left behind, widening
		// and fading as it ages (wake_trail).
		float wake = 0.0;
		if (wake_trail[0].z > 0.0 || wake_now > 0.0) {
			vec2 a = player_pos.xz;
			float ka = wake_now;
			for (int i = 0; i < 8; i++) {
				vec4 b = wake_trail[i];
				if (ka <= 0.0 && b.z <= 0.0) {
					break;
				}
				if (abs(world_pos.y - b.w) < 0.8) {
					vec2 ab = b.xy - a;
					float t = clamp(dot(world_pos.xz - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
					float d = length(world_pos.xz - a - ab * t);
					float k = mix(ka, b.z, t);
					// Close to the swimmer the band is narrow and parts round them.
					float half_w = 0.45 + (1.0 - k) * 0.68;
					float near = length(world_pos.xz - player_pos.xz);
					// Dimming fast just behind the swimmer and ever slower towards the end (k squared).
					wake = max(wake, smoothstep(half_w, half_w * 0.3, d) * k * k * smoothstep(0.15, 0.45, near));
				}
				a = b.xy;
				ka = b.z;
			}
		}
		float twinkle = 0.45 + 0.55 * step(0.55, hash12(tex + floor(TIME * 4.0) * 7.0));
		plankton = max(surf * bay, min(wake * 1.6, 1.0) * (0.75 + 0.25 * step(0.3, hash12(tex + floor(TIME * 6.0) * 3.0)))) * twinkle * sea_glow;
	}
	col = mix(col, ice_color(tex, depth, world_normal.y < 0.5, clear_ice, hole) * mix(vec3(1.0), vec3(0.8, 0.78, 0.7), murk), ice);
	if (ice > 0.0 && world_normal.y > 0.5) {
		// Scuffs of frost on the ice, under the fog like the ground's footprints.
		col *= mix(vec3(1.0), footprint(world_pos), ice);
	}
	vec4 veiled = veil(world_pos, depth_fade(world_pos.y));
	// The share of the sun's and the sky's light that comes down this deep; light()
	// undoes it for torches and fires (lamp_gain).
	float sun_part = sea_bright(world_pos.y);
	vec3 lit_col = col * (1.0 - veiled.a);
	ALBEDO = lit_col * sun_part;
	lamp_gain = sea_undo(lit_col, sun_part);
	EMISSION = veiled.rgb + (PLANKTON * plankton * 1.6 + shine * (1.0 - ice)) * (1.0 - veiled.a);
	// The plankton's light is not thinned by clear water: it glows as bright in the open
	// sea as in the surf.
	ALPHA = mix(mix(alpha, 1.0, min(plankton, 1.0)), 1.0, ice);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(world_pos);
	open_sky = roofed(world_pos.xz, world_pos.y) ? 0.0 : 1.0;
	COMPAT_COLORS
}

void light() {
	// Trees, cliffs and the player cast no shadow on the surface under the open sky:
	// it falls on the bed and shows through the water. Water under a roof or in a
	// cave stays in the dark of what covers it; clouds shade it anyway.
	float shade = LIGHT_IS_DIRECTIONAL && open_sky > 0.5 ? 1.0 : ATTENUATION;
	vec3 lit = toon_light(NORMAL, LIGHT, LIGHT_COLOR, shade, LIGHT_IS_DIRECTIONAL, clouds, light_texel(light_xz),
		light_stretch(INV_VIEW_MATRIX, LIGHT));
	DIFFUSE_LIGHT += LIGHT_IS_DIRECTIONAL ? compat_sun(lit, ALBEDO) : lit * lamp_gain;
}
