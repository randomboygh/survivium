// Drawn shadows of fires and the torch (FireShadows): a wedge on the ground from the foot of
// a caster away from the light, widening with the distance like a real one. It multiplies
// into what is drawn under it and takes back about as much as the light's ring there gives,
// leaving the night's own light, so it is as dark as the night around it.
// INSTANCE_CUSTOM: x = distance of the foot from the light, y = length of the wedge, z =
// height of the light over the foot, all as shares of the light's range; w = width of the
// foot as a share of the far end. COLOR.r = how strong the light is now.
shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

// The light of the night as a share of a fire's brightest ring: what is left in a shadow
// of the light that was there (set by FireShadows from the moon).
uniform float night = 0.14;
// The lights nearest to the player (FireShadows.MAX_LIGHTS): xyz where the light is
// (unsheared), w its range; and how strong each is now. Where other lights shine into a
// shadow it is lighter.
uniform vec4 lights[8];
uniform float strengths[8];
uniform int light_count = 0;
// How much of the other lights' light counts against a shadow: all of it would make
// shadows between close fires all but vanish, none would draw them as dark as under one
// fire, even over another fire.
const float OTHER_LIGHTS = 0.35;

varying vec3 world_pos;
varying flat vec4 shape;
varying flat float strength;

float ring(float d) {
	return d < LIGHT_RING_EDGES.x ? LIGHT_RING_LEVELS.x
		: (d < LIGHT_RING_EDGES.y ? LIGHT_RING_LEVELS.y
		: (d < LIGHT_RING_EDGES.z ? LIGHT_RING_LEVELS.z
		: (d < LIGHT_RING_EDGES.w ? LIGHT_RING_LEVELS.w : 0.0)));
}

void vertex() {
	world_pos = VERTEX;
	shape = INSTANCE_CUSTOM;
	strength = COLOR.r;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	// Narrow at the foot, the full width at the far end, the tip rounded off.
	float half_width = mix(shape.w, 1.0, UV.y) * 0.5;
	float side = abs(UV.x - 0.5);
	if (side > half_width || UV.y * UV.y + pow(side / half_width, 2.0) * 0.15 > 1.0) {
		discard;
	}
	float along = shape.x + UV.y * shape.y;
	float d = sqrt(along * along + shape.z * shape.z);
	float own = ring(d) * strength;
	float all = 0.0;
	for (int i = 0; i < light_count; i++) {
		all += ring(distance(world_pos, lights[i].xyz) / lights[i].w) * strengths[i];
	}
	all = own + OTHER_LIGHTS * max(all - own, 0.0);
	float left = (night + all - own) / (night + all);
	// What the warm light leaves is the cool light of the night.
	ALBEDO = vec3(left, mix(left, 1.0, 0.06), mix(left, 1.0, 0.2));
}
