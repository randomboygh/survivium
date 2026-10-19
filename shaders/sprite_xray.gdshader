// Silhouette of the player where something in front hides them: drawn over
// everything, but only on pixels where the scene depth is nearer than the sprite.
shader_type spatial;
render_mode world_vertex_coords, unshaded, depth_test_disabled, cull_disabled, blend_mix;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 silhouette : source_color = vec4(0.55, 0.75, 1.0, 0.55);

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	vec4 c = texture(sprite_texture, UV);
	if (c.a < 0.5 || world_pos.y > cut_height + 0.01) {
		discard;
	}
	float scene = texture(depth_texture, SCREEN_UV).r;
	// Compatibility renders with standard depth (0 near, 1 far).
	if (scene >= FRAGCOORD.z - 0.0005) {
		discard;
	}
	ALBEDO = silhouette.rgb;
	ALPHA = silhouette.a;
}
