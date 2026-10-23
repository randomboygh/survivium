// Silhouette of the player where something in front hides them (rock, a wall, a
// crown): drawn only where the depth test fails, that is behind what is already drawn,
// and not where the nearest thing is low (grass, bushes, a chest), which marks its
// pixels 1 in the stencil buffer.
shader_type spatial;
render_mode world_vertex_coords, unshaded, depth_test_inverted, depth_draw_never, cull_disabled, blend_mix;
stencil_mode read, compare_not_equal, 1;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D sprite_texture : source_color, filter_nearest;
// The frame of a sprite sheet to show, as a UV offset and size; a negative width
// mirrors the frame. The whole texture by default.
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 silhouette : source_color = vec4(0.55, 0.75, 1.0, 0.55);
uniform float water_line = -1000.0;

varying vec3 world_pos;

void vertex() {
	// Upright: turned to the camera about its origin.
	VERTEX = face_view(VERTEX, MODEL_MATRIX[3].xyz);
	world_pos = VERTEX;
	VERTEX = shear(stand_tall(VERTEX, MODEL_MATRIX[3].xyz));
}

void fragment() {
	vec2 uv = frame_uv.xy + UV * frame_uv.zw;
	vec4 c = texture(sprite_texture, uv);
	if (c.a < 0.5 || world_pos.y < water_line) {
		discard;
	}
	ALBEDO = silhouette.rgb;
	ALPHA = silhouette.a;
}
