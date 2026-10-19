// Silhouette of the player where something in front hides them (rock, a wall, a
// crown): drawn only where the depth test fails, that is behind what is already drawn.
shader_type spatial;
render_mode world_vertex_coords, unshaded, depth_test_inverted, depth_draw_never, cull_disabled, blend_mix;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform vec4 silhouette : source_color = vec4(0.55, 0.75, 1.0, 0.55);
uniform float water_line = -1000.0;

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	vec4 c = texture(sprite_texture, UV);
	if (c.a < 0.5 || world_pos.y < water_line) {
		discard;
	}
	ALBEDO = silhouette.rgb;
	ALPHA = silhouette.a;
}
