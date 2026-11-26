// The shadows of the trees drawn as pictures (TreeSprites), on the ground and on the other
// trees' bark and leaves: the trees' own instances (the chunk's `trees` MultiMesh, shared)
// drawn into the sun's and the moon's shadow map only (PixelView.LAYER_SUN_CASTER). Each
// tree's picture stands at its foot turned across the way its shadow falls, the side of it
// the light looks at, so the shadow is the tree's own outline: the crown as it is drawn
// (thinning from its edge in autumn as the picture does), the trunk from the foot, the limbs
// and twigs of a bare or dead tree, the snow on it in winter. The shadow falls where every other one does (PixelView.light_dir:
// a unit of height to `w` over the ground, the same at every turn of the camera), so it
// lies still while the camera turns. A felled tree's own MultiMesh (TreeHits.fall) is drawn
// by it too, its picture turned over as the tree falls (`falls` below).
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, unshaded;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D frames : filter_nearest;
uniform sampler2D bare_frames : filter_nearest;
uniform sampler2D snow_frames : filter_nearest;
uniform ivec2 ramps_at;

#include "res://shaders/tree_pictures.gdshaderinc"

// How far the picture sinks along the light's ray (world units of height): its shadow on
// the ground stays where it is, but the tree's own picture as shown, standing across the
// camera's way and so partly behind this one on the side away from the light, no longer
// takes it (its shade is drawn in it: tree.gdshader takes the sun's shadow on the bark and
// the leaves, and the far half of its crown would be parted from the near one down the
// trunk). SINK over the farthest the picture shown reaches behind; at most SINK_SHARE of a
// point's height, so it stays over the ground.
const float SINK = 0.4;
const float SINK_SHARE = 0.75;
// A piece of wood lying in the woods casts its shadow from its picture laid flat this high
// over the ground (world units).
const float PIECE_HIGH = 0.2;
// Trees falling, felled (TreeHits.fall, the same uniforms as tree.gdshader's): the falling
// tree's own instances (FALL_MINE added to COLOR.b) cast the shadow of its picture turned over
// about the stump's top (FALL_CUT over the foot) as it falls, fading out as it does; only the
// first of them (the crown's modules cast none of their own), not the stump's rows (the stump
// casts its own). The chunk's standing copy at the same foot casts none meanwhile.
uniform vec4 falls[4];
uniform vec4 fall_ways[4];
uniform int fall_count = 0;
const float FALL_CUT = 0.5;
const float FALL_MINE = 512.0;

varying vec2 px;
varying flat vec4 cell;
varying flat float kind;
varying flat float ramp_row;
varying flat vec2 foot_xz;
// How far a falling tree has faded out (-1 for a tree standing), and the row its stump's begin.
varying flat vec2 fall_fade;

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	// world_vertex_coords: the quad's own corner (x 0..1 across, y -1, 0, 1, see
	// TreeSprites.quad_mesh) is what the instance's place leaves of it.
	vec2 q = (VERTEX - foot).xy;
	vec4 c = INSTANCE_CUSTOM;
	float ax = COLOR.r;
	float ay = COLOR.g;
	bool mine = COLOR.b > FALL_MINE - 0.5;
	float b = mine ? COLOR.b - FALL_MINE : COLOR.b;
	float row = floor(b / 8.0 + 0.01);
	float own = b - row * 8.0;
	int fall = -1;
	for (int i = 0; i < fall_count && COLOR.a > -0.5; i++) {
		if (length(falls[i].xyz - foot) < 0.1) {
			fall = i;
		}
	}
	fall_fade = vec2(fall >= 0 ? fall_ways[fall].w : -1.0, ay + 0.5 - FALL_CUT * TEXELS);
	kind = COLOR.a;
	ramp_row = row;
	foot_xz = foot.xz;
	// Where the shadow of a unit of height falls over the ground (PixelView.light_dir), from
	// the sun as it stands in the world (sun_view is it in the view's frame).
	vec2 right = vec2(-view_up.y, view_up.x);
	vec2 sun_xz = right * sun_view.x + view_up * sun_view.y;
	vec2 cast = vec2(0.0, -1.0) - sun_xz / max(sun_view.z, 0.05);
	vec2 along = normalize(cast);
	// The light looks at the tree as a camera looking `along` would: the side of that step
	// (as tree.gdshader picks the side shown), laid across the way the shadow falls.
	float step_at = round(atan(-along.x, -along.y) / (PI / 4.0));
	float side = mod(step_at + own + 16.0, 8.0);
	bool piece = kind < -2.5;
	if (piece) {
		// A piece of wood lying in the woods (TreeSprites.PIECE): the view the camera shows
		// (as tree.gdshader picks it), its cell and anchor from its table, its summer look.
		vec2 up = rest_view.xy;
		side = mod(round(atan(-up.x, -up.y) / (PI / 4.0)) + own + 16.0, 8.0);
		ivec2 tb = ivec2(int(round(c.x)), int(round(c.y))) + ivec2(2 * int(side), 0);
		ivec4 p0 = ivec4(round(texelFetch(frames, tb, 0) * 255.0));
		ivec4 p1 = ivec4(round(texelFetch(frames, tb + ivec2(1, 0), 0) * 255.0));
		c = vec4(float(p0.r | (p0.g << 8)), float(p0.b | (p0.a << 8)), float(p1.r), float(p1.g));
		ax = float(p1.b);
		ay = float(p1.a);
		cell = c;
	} else {
		cell = vec4(c.x + side * c.z, c.y, c.z, c.w);
	}
	vec2 across = vec2(-along.y, along.x);
	// The picture shown stands across view_up (tree.gdshader): how far behind this one, in
	// height along the light, its farthest texel is.
	float half_w = max(ax + 0.5, c.z - ax - 0.5) / TEXELS;
	float deep = SINK + half_w * abs(dot(right, along)) / max(length(cast), 0.05);
	// Only the upright part (the rows under the foot's lie on the ground: the roots in
	// front), in two: the quad's rows (TreeSprites.quad_mesh) -1, 0, 1 are its foot, its knee,
	// where the sink reaches `deep` (SINK_SHARE of the height), and its top.
	float top = ay + 0.5;
	float rise = q.y < -0.5 ? 0.0 : (q.y < 0.5 ? min(deep / SINK_SHARE * TEXELS, top) : top);
	float wide = q.x * c.z;
	px = vec2(wide, top - rise);
	float high = rise / TEXELS;
	vec3 p = foot + vec3(across.x, 0.0, across.y) * ((wide - ax - 0.5) / TEXELS);
	p.y += high;
	if (piece) {
		// A piece lies on the ground: its picture as the camera shows it laid flat where it
		// lies (a row up the picture a texel farther away, as the ground's rows are drawn), a
		// little over the ground, casting its outline's shadow by it.
		float r = q.y > 0.5 ? 0.0 : (q.y > -0.5 ? ay + 0.5 : c.w);
		px = vec2(wide, r);
		p = foot + vec3(right.x, 0.0, right.y) * ((wide - ax - 0.5) / TEXELS);
		p.xz += view_up * ((ay + 0.5 - r) / TEXELS);
		p.y += PIECE_HIGH;
		high = 0.0;
	}
	if (fall >= 0) {
		if (!mine || INSTANCE_ID > 0) {
			p = foot;
			high = 0.0;
		} else {
			// Turned over about the stump's top toward the way it falls (Rodrigues' turn about
			// up x way), kept over the ground.
			vec3 pivot = foot + vec3(0.0, FALL_CUT, 0.0);
			vec3 way = normalize(vec3(fall_ways[fall].x, 0.0, fall_ways[fall].y));
			vec3 axis = cross(vec3(0.0, 1.0, 0.0), way);
			float a = falls[fall].w;
			vec3 v = p - pivot;
			p = pivot + v * cos(a) + cross(axis, v) * sin(a) + axis * dot(axis, v) * (1.0 - cos(a));
			p.y = max(p.y, foot.y + 0.02);
			high = p.y - foot.y;
		}
	}
	VERTEX = shear(p);
	if (IN_SHADOW_PASS && !piece) {
		vec3 to_light = normalize(INV_VIEW_MATRIX[2].xyz);
		VERTEX -= to_light * (min(deep, SINK_SHARE * high) / max(to_light.y, 0.05));
	}
}

void fragment() {
	if (px.x < 0.0 || px.y < 0.0 || px.x >= cell.z || px.y >= cell.w) {
		discard;
	}
	// A falling tree: not its stump's rows; faded out as it is drawn (tree.gdshader).
	if (fall_fade.x >= 0.0 && (px.y > fall_fade.y || fall_fade.x > 0.0 && bayer4(floor(px)) < fall_fade.x)) {
		discard;
	}
	ivec2 t = ivec2(cell.xy + floor(px));
	vec4 g = texelFetch(frames, t, 0);
	int a = frame_code(g);
	// A stump (TreeSprites.STUMP) or a piece of wood (PIECE): what it shows.
	if (kind < -0.5 && a == 0) {
		discard;
	}
	// The leaves autumn and winter have taken, as tree.gdshader takes them.
	float amount = picture_leaves(kind);
	if (kind < -0.5) {
	} else if (a >= 128) {
		float rank = float((a >> 2) & 3);
		if ((rank + hash12(g.rg * 255.0 + foot_xz * 3.1)) / 4.0 > amount) {
			a = 0;
		}
	} else if (a == 1 && g.r > amount - 0.08) {
		a = 0;
	}
	// Where they are gone, the bare tree's wood; the snow on the tree.
	if (a == 0 && kind > -0.5 && snow_on(t, int(cell.w - floor(px.y)) - 1, int(ramp_row), kind, amount) < 16384) {
		vec4 b = texelFetch(bare_frames, t, 0);
		if (b.r > 0.998 && b.a > 0.998) {
			discard;
		}
	}
	ALBEDO = vec3(0.0);
	COMPAT_ALBEDO
}
