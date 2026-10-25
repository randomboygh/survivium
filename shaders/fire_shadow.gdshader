// Drawn shadows of fires and the torch (FireShadows), multiplied into what is drawn
// under them and taking back about as much as the light's ring there gives, leaving the
// night's own light, so they are as dark as the night around them: a wedge on the
// ground from the foot of a caster away from the light, widening with the distance like
// a real one and thinning out by a dither towards its far end. (The blocks hide the
// light themselves, see light_hidden.)
// INSTANCE_CUSTOM: x = distance of the foot from the light, y = length of the
// wedge, z = height of the light over the foot, all as shares of the light's range;
// w = width of the foot as a share of the far end. COLOR.r = how strong the light is
// now, g = which of `lights` it is ((i + 0.5) / 8), b = 1 when the wedge goes on to the
// edge of the light (a caster taller than the light): it does not fade out before it.
shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

// The light of the night as a share of a fire's brightest ring: what is left in a shadow
// of the light that was there (set by FireShadows from the moon).
uniform float night = 0.14;
// The lights nearest to the player (FireShadows.MAX_LIGHTS): xyz where the light is
// (unsheared), w its range; and how strong each is now. Where other lights shine into a
// shadow it is only as dark as the light it lacks, so between close fires it all but
// vanishes, as a real one would.
uniform vec4 lights[8];
uniform float strengths[8];
uniform int light_count = 0;
// The share of the wedge's length, at its far end, over which it fades out.
const float FADE = 0.5;

varying vec3 world_pos;
varying flat vec4 shape;
varying flat float strength;
varying flat int light;
varying flat float to_edge;

// True when a block stands between the ground at `p` and light `i` (see light_blocked):
// the light does not get there, so there is nothing to take back.
bool blocked(int i, vec3 p) {
	return texelFetch(light_spots, ivec2(i, 1), 0).w > 1.5 && light_blocked(i, p + vec3(0.0, 0.025, 0.0));
}

void vertex() {
	world_pos = VERTEX;
	shape = INSTANCE_CUSTOM;
	strength = COLOR.r;
	light = int(COLOR.g * 8.0);
	to_edge = COLOR.b;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	// The rings are dithered on the same texels as the light they take back (toon_light).
	vec2 texel = floor(screen_plane(world_pos) * TEXELS);
	// Narrow at the foot, the full width at the far end, the tip rounded off.
	float half_width = mix(shape.w, 1.0, UV.y) * 0.5;
	float side = abs(UV.x - 0.5);
	if (side > half_width || UV.y * UV.y + pow(side / half_width, 2.0) * 0.15 > 1.0) {
		discard;
	}
	// Over its far part a short caster's wedge thins out to nothing by an ordered dither, in whole
	// texels of the ground.
	float fade = clamp((1.0 - UV.y) / FADE, 0.0, 1.0);
	if (to_edge < 0.5 && bayer4(texel) > fade) {
		discard;
	}
	// Where a block already hides the light, the ground is dark without it.
	if (blocked(light, world_pos)) {
		discard;
	}
	float along = shape.x + UV.y * shape.y;
	float d = sqrt(along * along + shape.z * shape.z);
	float own = light_ring(d, texel) * strength;
	float all = 0.0;
	for (int i = 0; i < light_count; i++) {
		if (i == light || !blocked(i, world_pos)) {
			all += light_ring(distance(world_pos, lights[i].xyz) / lights[i].w, texel) * strengths[i];
		}
	}
	all = max(all, own);
	float left = (night + all - own) / (night + all);
	// What the warm light leaves is the cool light of the night.
	ALBEDO = vec3(left, mix(left, 1.0, 0.06), mix(left, 1.0, 0.2));
}
