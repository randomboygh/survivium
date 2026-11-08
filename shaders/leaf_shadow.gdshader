// Shadow-only discs under crowns (one per level of a tree, see Foliage) and bushes,
// so a crown casts one round shadow with a ragged edge whatever the sun's angle. Shrinks as the
// leaves fall (INSTANCE_CUSTOM.x is what the tree does over the year, see leaves_left). Crowns above the
// cut still cast shadows, like cut terrain does.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, unshaded;

#include "res://shaders/common.gdshaderinc"

// The disc mesh's side (Foliage.SHADOW_DISC).
const float DISC_SIZE = 1.6;

varying vec3 world_pos;
varying flat float kind;
varying flat float scale;

void vertex() {
	world_pos = VERTEX;
	kind = INSTANCE_CUSTOM.x;
	// Discs of whole crowns are scaled up; their ragged edge stays as wide on the ground.
	scale = min(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
	if (kind < 0.5) {
		// A bush's disc (low, as high as the middle of the bush) faces the light: lying
		// flat it would cast its shadow off its foot when the sun is low, the bush seen
		// hanging over the ground. Upright to the light, its shadow starts under the bush
		// and stretches away with the evening as a bush's does. The shadow pass sees the
		// world from the light, so the view's axes are the light's.
		vec3 center = MODEL_MATRIX[3].xyz;
		vec2 o = (UV - 0.5) * length(MODEL_MATRIX[0].xyz) * DISC_SIZE;
		VERTEX = shear(center) + INV_VIEW_MATRIX[0].xyz * o.x - INV_VIEW_MATRIX[1].xyz * o.y;
		world_pos = center + vec3(o.x, 0.0, o.y);
	} else {
		VERTEX = shear(VERTEX);
	}
}

void fragment() {
	vec2 q = UV - 0.5;
	vec2 texel = floor(world_pos.xz * TEXELS);
	// A ragged outline: a slow wobble of lumps and single leaves along it.
	float wobble = texture(cloud_noise, world_pos.xz * 0.21).r - 0.5;
	float r = length(q) + (hash12(texel) * 0.12 + wobble * 0.3) / scale;
	// As leaves fall the shadow shrinks (holes in it would show as squares when the sun
	// is low and stretches it), and a bare crown casts none.
	float left = leaves_left(kind);
	if (r > 0.5 * (0.4 + 0.6 * left) || left < 0.01) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
