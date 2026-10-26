// Water: see-through over shallows and darker in the deep, foam that laps at the
// shore, drifting ripple lines and sparkles, rain rings, ice in winter (footprints
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
// Waterfalls (ChunkMesher._falls): vertex alpha FALL_SHEET marks the sheet of water
// falling over a step of a river, whose UV2.y is then the level of its foot, and
// FALL_FOAM the churning foam on the water where it lands.
shader_type spatial;
render_mode world_vertex_coords, blend_mix, cull_back, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"

uniform float ice_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shallow : source_color = vec3(0.36, 0.62, 0.6);
uniform vec3 deep : source_color = vec3(0.13, 0.29, 0.42);
uniform vec3 foam_color : source_color = vec3(0.85, 0.93, 0.92);
// The murky water of a swamp, shallow and deep, and the murkier water of a bog.
uniform vec3 swamp_shallow : source_color = vec3(0.37, 0.43, 0.25);
uniform vec3 swamp_deep : source_color = vec3(0.2, 0.26, 0.16);
uniform vec3 bog_color : source_color = vec3(0.33, 0.31, 0.19);
uniform vec3 swamp_foam : source_color = vec3(0.62, 0.65, 0.5);

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
// 1 under the open sky, where nothing casts a shadow on the surface (see light()).
varying float open_sky;
// 2 on a waterfall's sheet, 1 on the foam where it lands, 0 elsewhere.
varying flat float falls;

// Ice: clear blue-green over the shallows and darker over the deep, milky frost
// patches, straight white cracks and glints that do not move, and a dusting of snow
// in the hollows of the patch noise while snow lies.
vec3 ice_color(vec2 tex, float depth, bool side) {
	vec2 xz = tex / TEXELS;
	vec3 c = mix(vec3(0.46, 0.64, 0.72), vec3(0.28, 0.43, 0.58), depth);
	if (side) {
		return c * 0.85;
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

// Where the point is in the picture, for the dither of the light rings (light_texel).
varying vec2 light_xz;

void vertex() {
	// Ice lies where the water stood, so it is never above the shore it is walked on
	// from (see WorldData.ice_top).
	kind = COLOR.b > 0.48 ? 2 : 0;
	murk_here = (COLOR.b - (kind == 2 ? 0.5 : 0.0)) / 0.45;
	world_pos = VERTEX;
	world_normal = NORMAL;
	data = UV2;
	falls = COLOR.a < 0.25 ? 2.0 : (COLOR.a < 0.75 ? 1.0 : 0.0);
	depth_here = COLOR.r * 8.0;
	shore_under = COLOR.g;
	VERTEX = shear(VERTEX);
	light_xz = VERTEX.xz;
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	vec2 tex = floor(world_pos.xz * TEXELS);
	int last = int(CELL_TEXELS) - 1;
	ivec2 t = clamp(ivec2(floor(UV * CELL_TEXELS)), ivec2(0), ivec2(last));
	int dist[4] = int[](t.y, last - t.y, t.x, last - t.x);
	// The depth in steps, dithered between them on the texel grid so the shading
	// follows the bed smoothly and stays pixel art.
	float depth = clamp(((depth_here + 0.5) * CELL - 1.0) / 3.0, 0.0, 1.0);
	ivec2 bt = ivec2(mod(tex, 4.0));
	float bayer = float(BAYER[bt.y * 4 + bt.x]) / 16.0;
	depth = clamp(floor(depth * DEPTH_STEPS + bayer) / DEPTH_STEPS, 0.0, 1.0);
	vec3 col = mix(shallow, deep, depth);
	float alpha = mix(0.45, 1.0, depth);
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
	if (falls > 1.5) {
		// The falling sheet: streaks a texel wide running down at their own speeds,
		// white water at the lip and in a band of spray at the foot.
		vec3 across = abs(world_normal.x) > 0.5 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		float tx = floor(dot(world_pos, across) * TEXELS);
		float ty = floor(world_pos.y * TEXELS);
		float speed = 10.0 + 6.0 * hash12(vec2(tx, 3.0));
		float run = hash12(vec2(tx, floor((ty + TIME * speed) / 3.0)));
		float above_foot = world_pos.y / CELL - data.y;
		col = mix(shallow * 1.15, deep * 1.2, 0.35);
		col = mix(col, foam_color, step(0.62, run) * 0.85);
		if (above_foot < 0.35 + 0.15 * hash12(vec2(tx, floor(TIME * 6.0)))) {
			col = foam_color;
		}
		alpha = 0.93;
	} else if (falls > 0.5) {
		// Foam where the fall lands, boiling up in texels that come and go.
		float b = hash12(tex + floor(TIME * 5.0) * 13.0);
		col = mix(col, foam_color, b < 0.55 ? 0.9 : 0.4);
		alpha = 0.9;
	} else if (world_normal.y < 0.5) {
		col *= 0.8;
		alpha = 0.9;
	} else {
		// Drifting ripple lines: thin bands of a slowly moving noise.
		float n = texture(cloud_noise, (tex / TEXELS + vec2(TIME * 0.05, TIME * 0.02)) / 6.0).r;
		float n2 = texture(cloud_noise, (tex / TEXELS - vec2(TIME * 0.03, -TIME * 0.04)) / 9.0 + 0.5).r;
		float line = step(abs(n - 0.55), 0.012) + step(abs(n2 - 0.45), 0.01);
		col = mix(col, col * 1.35 + 0.05, clamp(line, 0.0, 1.0) * 0.8 * (1.0 - 0.6 * murk));
		// Sparkles, none on a bog.
		float s = step(0.993, hash12(tex + floor(TIME * 3.0) * 17.0)) * step(murk, 0.75);
		col += vec3(0.35) * s * (1.0 - ice_amount);
		// Foam along the shore, washing in and out by a texel or two.
		int foam = int(data.x + 0.5);
		int mid = int(CELL_TEXELS) / 2;
		for (int e = 0; e < 4; e++) {
			int half = (e < 2 ? t.x : t.y) / mid;
			if (((foam >> (2 * e + half)) & 1) == 0) {
				continue;
			}
			float along = e < 2 ? tex.x : tex.y;
			float wash = 1.0 + step(0.0, sin(TIME * 1.7 + along * 0.6)) + step(0.75, hash12(vec2(along, floor(TIME * 1.5))));
			if (float(dist[e]) < wash) {
				col = foam_c;
				alpha = 0.95;
			} else if (float(dist[e]) < wash + 2.0) {
				col = mix(col, foam_c, 0.25);
			}
		}
		// Over the slope of a shore: foam where the ground comes up to the surface, a
		// texel of shore for each eighth of a cell it lies under it.
		if (shore_under < 1.0) {
			float wash = 1.0 + step(0.0, sin(TIME * 1.7 + (tex.x + tex.y) * 0.6))
				+ step(0.75, hash12(vec2(tex.x + tex.y, floor(TIME * 1.5))));
			float d = shore_under * CELL_TEXELS;
			if (d < wash) {
				col = foam_c;
				alpha = 0.95;
			} else if (d < wash + 2.0) {
				col = mix(col, foam_c, 0.25);
			}
		}
		// Along diagonals: the water lies away from a filled corner and on the corner's
		// side of a cut one.
		for (int k = 0; k < 4; k++) {
			bool filled = ((foam >> (8 + k)) & 1) != 0;
			if (!filled && ((foam >> (12 + k)) & 1) == 0) {
				continue;
			}
			int sd = corner_distance(t, k, (foam >> (16 + 2 * k)) & 3);
			float d = float(filled ? sd : -sd);
			float wash = 1.0 + step(0.0, sin(TIME * 1.7 + tex.x * 0.6)) + step(0.75, hash12(vec2(tex.x, floor(TIME * 1.5))));
			if (d < wash) {
				col = foam_c;
				alpha = 0.95;
			} else if (d < wash + 2.0) {
				col = mix(col, foam_c, 0.25);
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
	col = mix(col, ice_color(tex, depth, world_normal.y < 0.5) * mix(vec3(1.0), vec3(0.8, 0.78, 0.7), murk), ice_amount);
	vec4 veiled = veil(world_pos, depth_fade(world_pos.y));
	ALBEDO = col * (1.0 - veiled.a);
	EMISSION = veiled.rgb;
	ALPHA = mix(alpha, 1.0, ice_amount);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(world_pos);
	open_sky = roofed(world_pos.xz, world_pos.y) ? 0.0 : 1.0;
}

void light() {
	// Trees, cliffs and the player cast no shadow on the surface under the open sky:
	// it falls on the bed and shows through the water. Water under a roof or in a
	// cave stays in the dark of what covers it; clouds shade it anyway.
	float shade = LIGHT_IS_DIRECTIONAL && open_sky > 0.5 ? 1.0 : ATTENUATION;
	DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, shade, LIGHT_IS_DIRECTIONAL, clouds, light_texel(light_xz),
		light_stretch(INV_VIEW_MATRIX, LIGHT));
}
