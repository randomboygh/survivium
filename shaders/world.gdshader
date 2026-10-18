// Terrain and voxel props. One texture per material; snow, wetness and season tints
// are applied on top, so no extra textures are needed for weather and seasons.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_nearest;
uniform bool use_atlas = true;
// Everything above this height is cut away (level cutaway); 1000 means no cut.
uniform float cut_height = 1000.0;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform vec3 foliage_tint = vec3(1.0);
uniform vec3 grass_tint = vec3(1.0);
uniform float texels_per_unit = 16.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying float flag;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	flag = UV2.x;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	if (world_pos.y > cut_height + 0.01) {
		discard;
	}
	vec3 col = COLOR.rgb;
	if (use_atlas) {
		col *= texture(atlas, UV).rgb;
	}
	if (flag > 0.5 && flag < 1.5) {
		col *= foliage_tint;
	} else if (flag > 1.5) {
		col *= grass_tint;
	}
	// Snow covers whole texels on upward faces and a fringe on top of side faces.
	vec3 texel = floor(world_pos * texels_per_unit - world_normal * 0.5);
	float n = hash12(texel.xz + texel.y * 17.0);
	float snow = 0.0;
	if (world_normal.y > 0.5) {
		snow = step(n, snow_amount * 1.15 - 0.05);
	} else if (abs(world_normal.y) < 0.5) {
		float fringe = snow_amount * (0.12 + 0.12 * n);
		snow = step(1.0 - fringe, fract(world_pos.y)) * step(0.3, snow_amount);
	}
	col = mix(col, vec3(0.93, 0.95, 1.0), snow);
	float wet = wetness * (1.0 - snow);
	col *= 1.0 - 0.35 * wet;
	// Levels below the cut get darker, like looking down into a pit.
	if (cut_height < 999.0) {
		float depth = max(0.0, cut_height - 1.0 - world_pos.y);
		col *= 1.0 - clamp(depth * 0.12, 0.0, 0.6);
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.3, wet);
	SPECULAR = mix(0.2, 0.7, wet);
}
