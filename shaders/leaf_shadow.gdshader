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
// 1 for a bush's disc, standing upright (see vertex).
varying flat float upright;
// The column of the world a bush stands in, which keeps or drops its leaves as a whole
// (leaves.gdshader).
varying flat vec2 bush_column;

void vertex() {
	world_pos = VERTEX;
	kind = INSTANCE_CUSTOM.x;
	// Discs of whole crowns are scaled up; their ragged edge stays as wide on the ground.
	scale = min(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
	upright = INSTANCE_CUSTOM.y;
	if (upright > 0.5) {
		// A bush's disc (as high as the middle of the bush) stands upright, turned to the
		// light the way a sprite's shadow is (sprite.gdshader): lying flat it cast its
		// shadow off the bush's foot when the sun was low, the bush seen hanging over
		// the ground. Upright, its shadow starts under the bush and stretches away from
		// the light as the evening comes, along the player's.
		vec3 center = MODEL_MATRIX[3].xyz;
		bush_column = floor(center.xz);
		vec2 o = (UV - 0.5) * length(MODEL_MATRIX[0].xyz) * DISC_SIZE;
		vec2 to = PROJECTION_MATRIX[3][3] > 0.5 ? INV_VIEW_MATRIX[2].xz
			: INV_VIEW_MATRIX[3].xz - shear(center).xz;
		vec2 side = dot(to, to) > 1e-6 ? normalize(vec2(to.y, -to.x)) : vec2(1.0, 0.0);
		VERTEX = shear(vec3(center.x + side.x * o.x, center.y - o.y, center.z + side.y * o.x));
		// Its ragged edge as the disc's lying flat would have it.
		world_pos = center + vec3(o.x, 0.0, o.y);
	} else {
		VERTEX = shear(VERTEX);
	}
}

void fragment() {
	float left = leaves_left(kind);
	float reach = 0.5 * (0.4 + 0.6 * left);
	// An upright disc shrinks onto its foot, not its middle: a bare bush's shadow still
	// starts at the ground.
	vec2 q = UV - vec2(0.5, upright > 0.5 ? 1.0 - reach : 0.5);
	vec2 texel = floor(world_pos.xz * TEXELS);
	// A ragged outline: a slow wobble of lumps and single leaves along it.
	float wobble = texture(cloud_noise, world_pos.xz * 0.21).r - 0.5;
	float r = length(q) + (hash12(texel) * 0.12 + wobble * 0.3) / scale;
	// As leaves fall the shadow shrinks (holes in it would show as squares when the sun
	// is low and stretches it), and a bare crown casts none.
	bool bare = upright > 0.5 && hash13(vec3(bush_column.x, 0.0, bush_column.y)) > left;
	if (r > reach || left < 0.01 || bare) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
