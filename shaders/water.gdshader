// Water: see-through over shallows and darker in the deep, foam that laps at the
// shore, drifting ripple lines and sparkles, rain rings, ice in winter (footprints
// on the ice are tracks.gd's).
// UV2.x: foam bits for the half edges that touch land (2 per edge N, S, W, E: the
// west or north half, then the other), then for the diagonals of corners NW, NE, SE,
// SW filled with land, then for those of cut-off corners of the land beside, then
// the shape of each of those four corners' curves (2 bits each, see corner_distance);
// UV2.y: depth in cells (half a world unit each).
shader_type spatial;
render_mode world_vertex_coords, blend_mix, cull_back, depth_draw_opaque;

#include "res://shaders/common.gdshaderinc"

uniform float ice_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shallow : source_color = vec3(0.36, 0.62, 0.6);
uniform vec3 deep : source_color = vec3(0.13, 0.29, 0.42);
uniform vec3 foam_color : source_color = vec3(0.85, 0.93, 0.92);

varying vec3 world_pos;
varying vec3 world_normal;
varying flat vec2 data;
varying float clouds;
// 1 under the open sky, where nothing casts a shadow on the surface (see light()).
varying float open_sky;

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

void vertex() {
	// Ice fills its cell to the top, level with the ground beside it, where it is
	// walked on (see WorldData.water_frozen).
	if (ice_amount > 0.8 && abs(fract(VERTEX.y / CELL) - 0.5) < 0.01) {
		VERTEX.y += 0.5 * CELL;
	}
	world_pos = VERTEX;
	world_normal = NORMAL;
	data = UV2;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	vec2 tex = floor(world_pos.xz * TEXELS);
	int last = int(CELL_TEXELS) - 1;
	ivec2 t = clamp(ivec2(floor(UV * CELL_TEXELS)), ivec2(0), ivec2(last));
	int dist[4] = int[](t.y, last - t.y, t.x, last - t.x);
	float depth = clamp((data.y * CELL - 1.0) / 3.0, 0.0, 1.0);
	vec3 col = mix(shallow, deep, depth);
	float alpha = mix(0.45, 1.0, depth);
	if (world_normal.y < 0.5) {
		col *= 0.8;
		alpha = 0.9;
	} else {
		// Drifting ripple lines: thin bands of a slowly moving noise.
		float n = texture(cloud_noise, (tex / TEXELS + vec2(TIME * 0.05, TIME * 0.02)) / 6.0).r;
		float n2 = texture(cloud_noise, (tex / TEXELS - vec2(TIME * 0.03, -TIME * 0.04)) / 9.0 + 0.5).r;
		float line = step(abs(n - 0.55), 0.012) + step(abs(n2 - 0.45), 0.01);
		col = mix(col, col * 1.35 + 0.05, clamp(line, 0.0, 1.0) * 0.8);
		// Sparkles.
		float s = step(0.993, hash12(tex + floor(TIME * 3.0) * 17.0));
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
				col = foam_color;
				alpha = 0.95;
			} else if (float(dist[e]) < wash + 2.0) {
				col = mix(col, foam_color, 0.25);
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
				col = foam_color;
				alpha = 0.95;
			} else if (d < wash + 2.0) {
				col = mix(col, foam_color, 0.25);
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
	col = mix(col, ice_color(tex, depth, world_normal.y < 0.5), ice_amount);
	float fade = depth_fade(world_pos.y);
	ALBEDO = col * (1.0 - fade);
	EMISSION = depth_haze * fade;
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
	DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, shade, LIGHT_IS_DIRECTIONAL, clouds);
}
