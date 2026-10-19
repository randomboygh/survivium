// Water: see-through over shallows and darker in the deep, foam that laps at the
// shore, drifting ripple lines and sparkles, rain rings, ice in winter.
// UV2.x: foam bits for the half edges that touch land (2 per edge N, S, W, E: the
// west or north half, then the other), then for the diagonals of corners NW, NE, SE,
// SW filled with land, then for those of cut-off corners of the land beside;
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

void vertex() {
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
			int sd = k == 0 ? t.x + t.y + 1 - mid : (k == 1 ? mid - t.x + t.y : (k == 2 ? 3 * mid - 1 - t.x - t.y : mid + t.x - t.y));
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
	col = mix(col, vec3(0.74, 0.85, 0.92) + 0.06 * hash12(tex), ice_amount);
	float fade = depth_fade(world_pos.y);
	ALBEDO = col * (1.0 - fade);
	EMISSION = depth_haze * fade;
	ALPHA = mix(alpha, 1.0, ice_amount);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(world_pos);
}

void light() {
	DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds);
}
