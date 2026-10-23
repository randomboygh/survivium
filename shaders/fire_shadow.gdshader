// Drawn shadows of fires and the torch (FireShadows), multiplied into what is drawn
// under them and taking back about as much as the light's ring there gives, leaving the
// night's own light, so they are as dark as the night around them. Two kinds:
// - a wedge on the ground from the foot of a caster away from the light, widening with
//   the distance like a real one and thinning out by a dither towards its far end;
// - a square over the ground around a light, dark where the way from the ground to the
//   light passes over a block or a thing placed (the light's map) higher than the way
//   is there.
// INSTANCE_CUSTOM (wedges): x = distance of the foot from the light, y = length of the
// wedge, z = height of the light over the foot, all as shares of the light's range;
// w = width of the foot as a share of the far end. COLOR.r = how strong the light is
// now, g = which of `lights` it is ((i + 0.5) / 8), b = 1 for a square.
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
// The maps of what stands around each light (FireShadows._maps), side by side in the
// order of `lights`: MAP_SIZE by MAP_SIZE columns, each how high the block or thing
// on it rises over the light's ground, MAP_SCALE steps a world unit. maps[i]: xy the
// column of its north-west corner, z the height of the light's ground, w 1 if it has one.
uniform sampler2D block_map : filter_nearest;
uniform vec4 maps[8];
const int MAP_SIZE = 32;
const float MAP_SCALE = 32.0;
// The share of the wedge's length, at its far end, over which it fades out.
const float FADE = 0.5;

varying vec3 world_pos;
varying flat vec4 shape;
varying flat float strength;
varying flat int light;
varying flat float square;

// True when the way from the ground at `p` to light `i` passes over a column of its
// map higher than the way is there: column by column from `p` to the light (not the
// columns of either end), the way rising from the ground to the light's height.
bool blocked(int i, vec3 p) {
	if (i >= light_count || maps[i].w < 0.5) {
		return false;
	}
	vec2 a = p.xz / CELL;
	vec2 b = lights[i].xz / CELL;
	float lh = lights[i].y - maps[i].z;
	vec2 d = b - a;
	ivec2 cell = ivec2(floor(a));
	ivec2 last = ivec2(floor(b));
	ivec2 dir = ivec2(sign(d));
	vec2 inv = 1.0 / max(abs(d), vec2(1e-6));
	// Where the way crosses the next line between columns, each way, as a share of it.
	vec2 next = vec2(
		d.x > 0.0 ? (float(cell.x) + 1.0 - a.x) * inv.x : (d.x < 0.0 ? (a.x - float(cell.x)) * inv.x : 2.0),
		d.y > 0.0 ? (float(cell.y) + 1.0 - a.y) * inv.y : (d.y < 0.0 ? (a.y - float(cell.y)) * inv.y : 2.0));
	ivec2 origin = ivec2(maps[i].xy);
	for (int k = 0; k < MAP_SIZE * 2; k++) {
		float t;
		if (next.x < next.y) {
			t = next.x;
			next.x += inv.x;
			cell.x += dir.x;
		} else {
			t = next.y;
			next.y += inv.y;
			cell.y += dir.y;
		}
		if (t >= 1.0 || cell == last) {
			return false;
		}
		ivec2 o = cell - origin;
		if (o.x >= 0 && o.y >= 0 && o.x < MAP_SIZE && o.y < MAP_SIZE) {
			float h = texelFetch(block_map, ivec2(i * MAP_SIZE + o.x, o.y), 0).r * 255.0 / MAP_SCALE;
			if (h > lh * t) {
				return true;
			}
		}
	}
	return false;
}

void vertex() {
	world_pos = VERTEX;
	shape = INSTANCE_CUSTOM;
	strength = COLOR.r;
	light = int(COLOR.g * 8.0);
	square = COLOR.b;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	// The rings are dithered on the same texels as the light they take back (toon_light).
	vec2 texel = floor(screen_plane(world_pos) * TEXELS);
	float d;
	if (square > 0.5) {
		d = distance(world_pos, lights[light].xyz) / lights[light].w;
		if (d >= LIGHT_RING_EDGES.w || !blocked(light, world_pos)) {
			discard;
		}
	} else {
		// Narrow at the foot, the full width at the far end, the tip rounded off.
		float half_width = mix(shape.w, 1.0, UV.y) * 0.5;
		float side = abs(UV.x - 0.5);
		if (side > half_width || UV.y * UV.y + pow(side / half_width, 2.0) * 0.15 > 1.0) {
			discard;
		}
		// Over its far part the wedge thins out to nothing by an ordered dither, in whole
		// texels of the ground.
		float fade = clamp((1.0 - UV.y) / FADE, 0.0, 1.0);
		if (bayer4(texel) > fade) {
			discard;
		}
		// Where a block already hides the light, the square over it is dark there.
		if (blocked(light, world_pos)) {
			discard;
		}
		float along = shape.x + UV.y * shape.y;
		d = sqrt(along * along + shape.z * shape.z);
	}
	float own = light_ring(d, texel) * strength;
	float all = 0.0;
	for (int i = 0; i < light_count; i++) {
		all += light_ring(distance(world_pos, lights[i].xyz) / lights[i].w, texel) * strengths[i];
	}
	all = max(all, own);
	float left = (night + all - own) / (night + all);
	// What the warm light leaves is the cool light of the night.
	ALBEDO = vec3(left, mix(left, 1.0, 0.06), mix(left, 1.0, 0.2));
}
