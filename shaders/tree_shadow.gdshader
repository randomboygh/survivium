// The ground shadows of the trees drawn as pictures (TreeSprites): the trees' own instances
// (the chunk's `trees` MultiMesh, shared) drawn into the sun's and the moon's shadow map
// only (PixelView.LAYER_SUN_CASTER). Each tree's picture stands at its foot turned across
// the way its shadow falls, the side of it the light looks at, so the shadow is the tree's
// own outline: the crown as it is drawn (thinning from its edge in autumn as the picture
// does), the trunk from the foot, the limbs of a bare or dead tree. The shadow falls where
// every other one does (PixelView.light_dir: a unit of height to `w` over the ground, the
// same at every turn of the camera), so it lies still while the camera turns.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, unshaded;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D frames : filter_nearest;
uniform sampler2D bare_frames : filter_nearest;

// How far the picture sinks along the light's ray (world units of height, at most a share
// of its own height, so it stays over the ground): its shadow on the ground stays where it
// is, but the tree's own picture, which stands a little behind it on the side away from the
// light (the far half of the trunk), no longer takes it. Its shade is drawn in the picture
// (tree.gdshader takes the sun's shadow on the bark a step darker: twice it would be two).
const float SINK = 0.4;
const float SINK_SHARE = 0.75;

varying vec2 px;
varying flat vec4 cell;
varying flat float kind;
varying flat vec2 foot_xz;

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	// world_vertex_coords: the quad's own corner (x 0..1 across, y -1, 0, 1, see
	// TreeSprites.quad_mesh) is what the instance's place leaves of it.
	vec2 q = (VERTEX - foot).xy;
	vec4 c = INSTANCE_CUSTOM;
	float ax = COLOR.r;
	float ay = COLOR.g;
	float row = floor(COLOR.b / 8.0 + 0.01);
	float own = COLOR.b - row * 8.0;
	kind = COLOR.a;
	foot_xz = foot.xz;
	// Where the shadow of a unit of height falls over the ground (PixelView.light_dir), from
	// the sun as it stands in the world (sun_view is it in the view's frame).
	vec2 right = vec2(-view_up.y, view_up.x);
	vec2 sun_xz = right * sun_view.x + view_up * sun_view.y;
	vec2 falls = vec2(0.0, -1.0) - sun_xz / max(sun_view.z, 0.05);
	vec2 along = normalize(falls);
	// The light looks at the tree as a camera looking `along` would: the side of that step
	// (as tree.gdshader picks the side shown), laid across the way the shadow falls.
	float step_at = round(atan(-along.x, -along.y) / (PI / 4.0));
	float side = mod(step_at + own + 16.0, 8.0);
	cell = vec4(c.x + side * c.z, c.y, c.z, c.w);
	vec2 across = vec2(-along.y, along.x);
	// Only the upright part: the rows under the foot's lie on the ground (the roots in front).
	float wide = q.x * c.z;
	float rise = max(q.y, 0.0) * (ay + 0.5);
	px = vec2(wide, ay + 0.5 - rise);
	float high = rise / TEXELS;
	vec3 p = foot + vec3(across.x, 0.0, across.y) * ((wide - ax - 0.5) / TEXELS);
	p.y += high;
	VERTEX = shear(p);
	if (IN_SHADOW_PASS) {
		vec3 to_light = normalize(INV_VIEW_MATRIX[2].xyz);
		VERTEX -= to_light * (min(SINK, SINK_SHARE * high) / max(to_light.y, 0.05));
	}
}

void fragment() {
	if (px.x < 0.0 || px.y < 0.0 || px.x >= cell.z || px.y >= cell.w) {
		discard;
	}
	ivec2 t = ivec2(cell.xy + floor(px));
	vec4 g = texelFetch(frames, t, 0);
	int a = int(round(g.a * 255.0));
	// The leaves autumn and winter have taken, as tree.gdshader takes them.
	float amount = leaves_left(kind);
	if (a >= 128) {
		float rank = float((a >> 2) & 3);
		if ((rank + hash12(g.rg * 255.0 + foot_xz * 3.1)) / 4.0 > amount) {
			a = 0;
		}
	} else if (a == 1 && g.r > amount - 0.08) {
		a = 0;
	}
	// Where they are gone, the bare tree's wood.
	if (a == 0) {
		vec4 b = texelFetch(bare_frames, t, 0);
		if (b.r > 0.998 && b.a > 0.998) {
			discard;
		}
	}
	ALBEDO = vec3(0.0);
	COMPAT_ALBEDO
}
