// Silhouette of the player where something solid in front hides them (rock, a wall,
// an animal, the foot of a trunk): drawn only where the depth test fails, that is
// behind what is already drawn, and only where the nearest thing marked its pixels
// solid (1) in the stencil buffer or marked none (0); not where it is low (2: grass,
// bushes, a chest) nor a crown (3), which clears round the player instead (the
// stencil test passes where 2 is greater than the mark).
shader_type spatial;
render_mode world_vertex_coords, unshaded, depth_test_inverted, depth_draw_never, cull_disabled, blend_mix;
stencil_mode read, compare_greater, 2;

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
