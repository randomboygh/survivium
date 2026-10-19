// Shadow-only discs under crowns (one per level of a tree, see Foliage) and bushes,
// so a crown casts one round shadow with a ragged edge whatever the sun's angle. Thins out with the leaves in winter (INSTANCE_CUSTOM.x is
// what the tree does over the year, see leaves_left). Crowns above the
// cut still cast shadows, like cut terrain does.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, unshaded;

#include "res://shaders/common.gdshaderinc"

varying vec3 world_pos;
varying flat float kind;
varying flat float scale;

void vertex() {
	world_pos = VERTEX;
	kind = INSTANCE_CUSTOM.x;
	// Discs of whole crowns are scaled up; their ragged edge stays as wide on the ground.
	scale = min(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX = shear(VERTEX);
}

void fragment() {
	vec2 q = UV - 0.5;
	vec2 texel = floor(world_pos.xz * TEXELS);
	// A ragged outline: a slow wobble of lumps and single leaves along it.
	float wobble = texture(cloud_noise, world_pos.xz * 0.21).r - 0.5;
	float r = length(q) + (hash12(texel) * 0.12 + wobble * 0.3) / scale;
	// Leaves fall in specks of a couple of pixels.
	if (r > 0.5 || hash12(floor(world_pos.xz * TEXELS / 3.0) + floor(world_pos.y)) > leaves_left(kind)) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
