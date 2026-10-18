// Water surface: translucent with stepped sparkles; turns to ice in winter.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_nearest;
uniform float cut_height = 1000.0;
uniform float ice_amount : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (world_pos.y > cut_height + 0.01) {
		discard;
	}
	vec3 col = texture(atlas, UV).rgb;
	vec2 texel = floor(world_pos.xz * 16.0) + floor(TIME * 2.0);
	float sparkle = step(0.985, fract(sin(dot(texel, vec2(12.9898, 78.233))) * 43758.5453));
	col += vec3(0.25) * sparkle * (1.0 - ice_amount);
	ALBEDO = mix(col, vec3(0.78, 0.88, 0.95), ice_amount);
	ALPHA = mix(0.72, 1.0, ice_amount);
	ROUGHNESS = mix(0.15, 0.6, ice_amount);
	SPECULAR = 0.6;
}
