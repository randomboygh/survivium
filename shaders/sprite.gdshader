// Upright pixel-art sprites (people, animals). Lit like the ground under them, so
// they sit in shadows and torch light, and cast shadows themselves.
shader_type spatial;
// Sprites receive real shadows too (the player's from a fire on an animal, a crown's
// on the player); the normal offset of the shadow lookup keeps an upright quad from
// shading itself.
render_mode world_vertex_coords, cull_disabled;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D sprite_texture : source_color, filter_nearest;
// The frame of a sprite sheet to show, as a UV offset and size; a negative width
// mirrors the frame. The whole texture by default.
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
// Height of the water surface around a wading or swimming sprite, in world units:
// below it the body is hidden, along it a line of ripples.
uniform float water_line = -1000.0;
// Colour of that line: foam on water, darker on the mud of a bog.
uniform vec3 ripple = vec3(0.85, 0.93, 0.92);
// What a drawn shadow of a fire or the torch leaves of the light where the sprite
// stands (FireShadows): 1 out of them. It comes as the sprite's scale along z, which
// the flat quad does not use: an instance uniform read as 0 in the web build, and the
// animals were drawn black.
varying float shade;

varying vec3 world_pos;
varying float clouds;

// Where the point is in the picture, for the dither of the light rings (light_texel).
varying vec2 light_xz;

void vertex() {
	if (IN_SHADOW_PASS) {
		// A flat sprite seen from the side throws a strip of a shadow: for the shadow
		// it turns about its middle to face the light (the light's camera), as if the
		// body were as wide every way. In the sheared space the shadow is cast in.
		vec3 foot = MODEL_MATRIX[3].xyz;
		vec2 to = PROJECTION_MATRIX[3][3] > 0.5 ? INV_VIEW_MATRIX[2].xz
			: INV_VIEW_MATRIX[3].xz - shear(foot + vec3(0.0, 0.5, 0.0)).xz;
		if (dot(to, to) > 1e-6) {
			vec2 side = normalize(vec2(to.y, -to.x));
			VERTEX.xz = foot.xz + side * (VERTEX.x - foot.x);
		}
	} else {
		// Upright: turned to the camera about its origin.
		VERTEX = face_view(VERTEX, MODEL_MATRIX[3].xyz);
	}
	shade = length(MODEL_MATRIX[2].xyz);
	world_pos = VERTEX;
	VERTEX = shear(IN_SHADOW_PASS ? VERTEX : stand_tall(VERTEX, MODEL_MATRIX[3].xyz));
	light_xz = VERTEX.xz;
}

void fragment() {
	vec2 uv = frame_uv.xy + UV * frame_uv.zw;
	vec4 c = texture(sprite_texture, uv);
	// The player stays whole whatever level is cut; everyone else goes with their level.
	bool me = length(world_pos.xz - player_pos.xz) < 0.7 && abs(world_pos.y - player_pos.y) < 1.5;
	// The whole body casts its shadow, under the water too, so the shadow on the bed
	// has the body's full shape; only the drawn sprite stops at the surface.
	if ((world_pos.y < water_line && !IN_SHADOW_PASS) || (!me && above_cut(world_pos))) {
		discard;
	}
	if (world_pos.y < water_line + 1.0 / TEXELS && !IN_SHADOW_PASS) {
		// The ripple reaches a pixel past the body on each side.
		vec2 px = 1.0 / vec2(textureSize(sprite_texture, 0));
		float a = max(c.a, max(texture(sprite_texture, uv + vec2(px.x, 0.0)).a, texture(sprite_texture, uv - vec2(px.x, 0.0)).a));
		if (a < 0.5) {
			discard;
		}
		c.rgb = ripple;
	} else if (c.a < 0.5) {
		discard;
	}
	vec4 veiled = veil(world_pos, depth_fade(world_pos.y));
	// The cool light of the night is what a drawn shadow leaves (fire_shadow.gdshader).
	ALBEDO = c.rgb * vec3(shade, mix(shade, 1.0, 0.06), mix(shade, 1.0, 0.2)) * (1.0 - veiled.a);
	EMISSION = veiled.rgb;
	// Lit as if facing up and toward the viewer, on both sides (mirrored sprites
	// show their back face).
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.6, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(world_pos);
}

void light() {
	DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds, light_texel(light_xz));
}
