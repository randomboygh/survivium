// Upright pixel-art sprites (people, animals). Lit like the ground under them, so
// they sit in shadows and torch light, and cast shadows themselves.
shader_type spatial;
// Sprites receive real shadows too (the player's from a fire on an animal, a crown's
// on the player); the normal offset of the shadow lookup keeps an upright quad from
// shading itself.
render_mode world_vertex_coords, cull_disabled;
// Solid for the player's silhouette (see sprite_xray): it shows behind an animal.
stencil_mode write, compare_always, 1;

#include "res://shaders/common.gdshaderinc"
#include "res://shaders/looks.gdshaderinc"

uniform sampler2D sprite_texture : filter_nearest SRGB_HINT;
// The frame of a sprite sheet to show, as a UV offset and size; a negative width
// mirrors the frame. The whole texture by default.
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
// Height of the water surface around a wading or swimming sprite, in world units:
// below it the body is hidden, along it a line of ripples.
uniform float water_line = -1000.0;
// Colour of that line: foam on water, darker on the mud of a bog.
uniform vec3 ripple = vec3(0.85, 0.93, 0.92);
// 1 while the sprite swims: the ripple splashes wider.
uniform float splash = 0.0;
// 1 for a wing beat of a flyer in the air: its shadow is cast by the frame of the
// front row (wings spread) laid flat at the middle of its height, as a bird seen from
// above, not by the upright picture turned to the light, which stretched the profile
// with a wing up into a long blot far bigger than the bird. 2 when the picture shown
// is its side: the frame then lies across, the wings across the way it flies.
uniform float flat_shadow = 0.0;
// The frame the flat shadow is cast by (frame_uv's row of the front view).
uniform vec4 shadow_uv = vec4(0.0, 0.0, 1.0, 1.0);
// A colour the picture is multiplied by: one of a species' tints (butterflies of many
// colours), white for none.
uniform vec3 tint = vec3(1.0);
// 1 for a fish: this picture only casts the shadow, the fish is drawn over it after
// the water (sprite_water.gdshader `whole`, its material_overlay), and the sprite's
// scale along y past 1 is how deep it swims, undone here.
uniform float shadow_only = 0.0;
// 1 for a thing standing still (Props._add_sprite, a snowman): the sun's and the moon's
// shadows do not fall on it. A wide picture lit from behind threw its own leaning shadow
// (lean_shadow) over its face as a dither; its shading is drawn into the picture.
uniform float sun_shadow_free = 0.0;
// What a drawn shadow of a fire or the torch leaves of the light where the sprite
// stands (FireShadows): 1 out of them. It comes as the sprite's scale along z past 1
// (2 minus it, before the flash), which the flat quad does not use: an instance uniform
// read as 0 in the web build, and the animals were drawn black (PixelView.shade_sprite).
varying float shade;
// How red an animal flashes at a blow (Creatures, the user's ask 2026-11-21: the red is
// not drawn into its frames): 0 to 1, from the whole part of half that scale past 1
// (PixelView.flash_sprite, FLASH_STEPS).
varying float flash;
const float FLASH_STEPS = 4.0;
// The red of the flash, how much of the picture's colour it takes at most, and how
// much it glows of itself so it shows at night too.
const vec3 FLASH_RED = vec3(1.0, 0.12, 0.08);
const float FLASH_MIX = 0.6;
const float FLASH_GLOW = 0.15;

varying vec3 world_pos;
varying float clouds;
// How much brighter a torch or a fire lights this than sea_bright left its colour (sea_undo).
varying vec3 lamp_gain;

// Where the point is in the picture, for the dither of the light rings (light_texel).
varying vec2 light_xz;
// Where the point is drawn (sheared), to tell which light shines on it (light_spot).
varying vec3 drawn;

// How far a row `high` above the foot of a picture `tall` high leans, along view_up,
// in the shadow pass of the sun or the moon (`to_light`, the light's way, sheared),
// so the shadow on the ground is never thinner across the view than LEAN_DEPTH of the
// height: lit along its width (the sun east or west of a picture facing south) the
// card would throw a line. The body is as deep: the band lies behind the feet while
// the shadow falls away from the camera, and slides in front of them as it turns
// towards the camera, the feet's shadow under the feet again once it falls LEAN_DEPTH
// of the height that way.
const float LEAN_DEPTH = 0.4;

float lean_shadow(float high, float tall, vec3 to_light) {
	if (to_light.y < 0.01) {
		return 0.0;
	}
	// How far the shadow of a unit of height falls along view_up, the shear's own
	// lean of the height in.
	float falls = view_slope - dot(to_light.xz, view_up) / to_light.y;
	if (falls >= 0.0) {
		return (max(falls, LEAN_DEPTH) - falls) * high;
	}
	float front = max(LEAN_DEPTH + falls, 0.0);
	return front * (tall - high);
}

void vertex() {
	if (shadow_only > 0.5) {
		VERTEX.y = MODEL_MATRIX[3].y + (VERTEX.y - MODEL_MATRIX[3].y) / length(MODEL_MATRIX[1].xyz);
	}
	if (IN_SHADOW_PASS) {
		vec3 foot = MODEL_MATRIX[3].xyz;
		if (flat_shadow > 0.5) {
			// Laid flat at the middle of its height, the picture's up along the way
			// away from the camera, or for the side, along the way it flies (the side
			// is mirrored for left, scale.x < 0) with the wings across it.
			float mid = float(textureSize(sprite_texture, 0).y) * shadow_uv.w / TEXELS * 0.5;
			float across = VERTEX.x - foot.x;
			float along = VERTEX.y - foot.y - mid;
			vec2 right = vec2(-view_up.y, view_up.x);
			vec2 off = flat_shadow > 1.5 ? view_up * across + right * sign(MODEL_MATRIX[0].x) * along
				: right * across + view_up * along;
			VERTEX = vec3(foot.x + off.x, foot.y + mid, foot.z + off.y);
		} else if (PROJECTION_MATRIX[3][3] > 0.5) {
			// Under the sun or the moon the picture casts its shadow as it is drawn,
			// turned to the camera, so the light lays it on the ground skewed: each row
			// shifted away from the light by its height, the body lying or standing as
			// it is seen (a lying bear turned to the light threw a strip across itself),
			// and the shadow falls on slopes and walls as any other (lean_shadow).
			VERTEX = face_view(VERTEX, foot);
		} else {
			// A fire's or the torch's light: the picture turns about its middle to face
			// it, as if the body were as wide every way (seen from the side, a flat
			// sprite threw a strip). In the sheared space the shadow is cast in.
			vec2 to = INV_VIEW_MATRIX[3].xz - shear(foot + vec3(0.0, 0.5, 0.0)).xz;
			if (dot(to, to) > 1e-6) {
				vec2 side = normalize(vec2(to.y, -to.x));
				VERTEX.xz = foot.xz + side * (VERTEX.x - foot.x);
			}
		}
	} else {
		// Upright: turned to the camera about its origin.
		VERTEX = face_view(VERTEX, MODEL_MATRIX[3].xyz);
	}
	float marks = length(MODEL_MATRIX[2].xyz);
	float steps = max(floor((marks - 1.0) * 0.5 + 0.001), 0.0);
	shade = clamp(2.0 - (marks - 2.0 * steps), 0.0, 1.0);
	flash = min(steps / FLASH_STEPS, 1.0);
	world_pos = VERTEX;
	VERTEX = shear(IN_SHADOW_PASS ? VERTEX : stand_tall(VERTEX, MODEL_MATRIX[3].xyz));
	if (IN_SHADOW_PASS && flat_shadow < 0.5 && PROJECTION_MATRIX[3][3] > 0.5) {
		float tall = float(textureSize(sprite_texture, 0).y) * frame_uv.w / TEXELS;
		VERTEX.xz += view_up * lean_shadow(world_pos.y - MODEL_MATRIX[3].y, tall, INV_VIEW_MATRIX[2].xyz);
	}
	light_xz = VERTEX.xz;
	drawn = VERTEX;
}

void fragment() {
	vec4 shown = IN_SHADOW_PASS && flat_shadow > 0.5 ? shadow_uv : frame_uv;
	vec2 at = UV;
	// In the heat over sand and the sea the body's rows sway aside with the air (heat_sway).
	if (heat_ground > 0.0 && !IN_SHADOW_PASS) {
		vec3 foot = MODEL_MATRIX[3].xyz;
		float wide = abs(shown.z) * float(textureSize(sprite_texture, 0).x);
		at.x -= heat_sway(world_pos, foot, world_pos.y - foot.y, TIME) / max(wide, 1.0);
		if (at.x < 0.0 || at.x > 1.0) {
			discard;
		}
	}
	vec2 uv = shown.xy + at * shown.zw;
	vec4 c = texture(sprite_texture, uv);
	c.rgb = mix(looks_swap(c.rgb) * tint, FLASH_RED, flash * FLASH_MIX);
	// The player stays whole whatever level is cut; everyone else goes with their level.
	bool me = length(world_pos.xz - player_pos.xz) < 0.7 && abs(world_pos.y - player_pos.y) < 1.5;
	// The whole body casts its shadow, under the water too, so the shadow on the bed
	// has the body's full shape; only the drawn sprite stops at the surface.
	if (((world_pos.y < water_line || shadow_only > 0.5) && !IN_SHADOW_PASS) || (!me && above_cut(world_pos))) {
		discard;
	}
	if (world_pos.y < water_line + 1.0 / TEXELS && !IN_SHADOW_PASS) {
		// The ripple reaches a pixel past the body on each side; round a swimmer it
		// splashes two more, in bits that come and go.
		vec2 px = 1.0 / vec2(textureSize(sprite_texture, 0));
		float a = max(c.a, max(texture(sprite_texture, uv + vec2(px.x, 0.0)).a, texture(sprite_texture, uv - vec2(px.x, 0.0)).a));
		for (int k = 2; k <= 3; k++) {
			if (splash > 0.5) {
				float near = max(texture(sprite_texture, uv + vec2(px.x * float(k), 0.0)).a,
					texture(sprite_texture, uv - vec2(px.x * float(k), 0.0)).a);
				a = max(a, near * step(0.4, hash12(vec2(floor(uv.x / px.x), floor(TIME * 6.0) + float(k)))));
			}
		}
		if (a < 0.5) {
			discard;
		}
		c.rgb = ripple;
	} else if (c.a < 0.5) {
		discard;
	}
	vec4 veiled = veil(world_pos, depth_fade(world_pos.y));
	// The cool light of the night is what a drawn shadow leaves (fire_shadow.gdshader).
	// The share of the sun's and the sky's light that comes down this deep; light()
	// undoes it for torches and fires (lamp_gain).
	float sun_part = sea_bright(world_pos.y);
	vec3 lit_col = c.rgb * vec3(shade, mix(shade, 1.0, 0.06), mix(shade, 1.0, 0.2)) * (1.0 - veiled.a);
	ALBEDO = lit_col * sun_part;
	lamp_gain = sea_undo(lit_col, sun_part);
	EMISSION = veiled.rgb + FLASH_RED * (flash * FLASH_GLOW * (1.0 - veiled.a));
	// Lit as if facing up and toward the viewer, on both sides (mirrored sprites
	// show their back face).
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.6, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(world_pos);
	COMPAT_COLORS
}

void light() {
	// A sprite stands up in the drawn world, not in the world (stand_tall), where a
	// torch or a fire may seem behind it or far off at a tilt: it takes their light
	// facing them, its rings by the way to the light in the world where that light is
	// known (light_spots), else by the drawn way, the range undone (light_reach).
	float stretch = light_reach;
	if (!LIGHT_IS_DIRECTIONAL) {
		int spot = light_spot(drawn, normalize((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz));
		if (spot >= 0) {
			vec4 s = texelFetch(light_spots, ivec2(spot, 0), 0);
			stretch = distance(world_pos, s.xyz) / s.w / max(light_share(ATTENUATION), 1e-4);
		}
	}
	float att = LIGHT_IS_DIRECTIONAL && sun_shadow_free > 0.5 ? 1.0 : ATTENUATION;
	vec3 lit = toon_light(LIGHT_IS_DIRECTIONAL ? NORMAL : LIGHT, LIGHT, LIGHT_COLOR, att,
		LIGHT_IS_DIRECTIONAL, clouds, light_texel(light_xz), stretch);
	DIFFUSE_LIGHT += LIGHT_IS_DIRECTIONAL ? compat_sun(lit, ALBEDO) : lit * lamp_gain;
}
