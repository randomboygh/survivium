// Upright pixel-art sprites (people, animals). Lit like the ground under them, so
// they sit in shadows and torch light, and cast shadows themselves.
shader_type spatial;
// Sprites cast shadows but do not receive them: an upright quad would shade itself.
render_mode world_vertex_coords, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D sprite_texture : source_color, filter_nearest;
// Height of the water surface around a wading or swimming sprite, in world units:
// below it the body is hidden, along it a line of ripples.
uniform float water_line = -1000.0;

varying vec3 world_pos;
varying float clouds;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	vec4 c = texture(sprite_texture, UV);
	// The player stays whole whatever level is cut; everyone else goes with their level.
	bool me = length(world_pos.xz - player_pos.xz) < 0.7 && abs(world_pos.y - player_pos.y) < 1.5;
	if (world_pos.y < water_line || (!me && above_cut(world_pos))) {
		discard;
	}
	if (world_pos.y < water_line + 1.0 / TEXELS) {
		// The ripple reaches a pixel past the body on each side.
		vec2 px = 1.0 / vec2(textureSize(sprite_texture, 0));
		float a = max(c.a, max(texture(sprite_texture, UV + vec2(px.x, 0.0)).a, texture(sprite_texture, UV - vec2(px.x, 0.0)).a));
		if (a < 0.5) {
			discard;
		}
		c.rgb = vec3(0.85, 0.93, 0.92);
	} else if (c.a < 0.5) {
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
