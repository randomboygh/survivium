// Upright pixel-art sprites (people, animals). Lit like the ground under them, so
// they sit in shadows and torch light, and cast shadows themselves.
shader_type spatial;
// Sprites cast shadows but do not receive them: an upright quad would shade itself.
render_mode world_vertex_coords, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D sprite_texture : source_color, filter_nearest;

varying vec3 world_pos;
varying float clouds;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	vec4 c = texture(sprite_texture, UV);
	if (c.a < 0.5 || above_cut(world_pos)) {
		discard;
	}
	float fade = depth_fade(world_pos.y);
	ALBEDO = c.rgb * (1.0 - fade);
	EMISSION = depth_haze * fade;
	// Lit as if facing up and toward the viewer, on both sides (mirrored sprites
	// show their back face).
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.6, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(world_pos);
}

void light() {
	DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds);
}
