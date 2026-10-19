// Shadow-only discs under each leaf cell, so a crown casts a round, leafy shadow
// whatever the sun's angle. Thins out with the leaves in winter (INSTANCE_CUSTOM.x is
// what the tree does over the year, see leaves_left). Crowns above the
// cut still cast shadows, like cut terrain does.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, unshaded;

#include "res://shaders/common.gdshaderinc"

varying vec3 world_pos;
varying flat vec3 cell;
varying flat float kind;

void vertex() {
	world_pos = VERTEX;
	// The same per-cell choice as the leaf clumps, taken once for the whole disc.
	cell = floor(MODEL_MATRIX[3].xyz);
	kind = INSTANCE_CUSTOM.x;
	VERTEX = shear(VERTEX);
}

void fragment() {
	vec2 q = UV - 0.5;
	vec2 texel = floor(world_pos.xz * TEXELS);
	float r = length(q) + hash12(texel) * 0.12;
	if (r > 0.5 || hash13(cell) > leaves_left(kind)) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
