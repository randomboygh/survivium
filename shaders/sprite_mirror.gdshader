// A figure mirrored in the water it stands by (WaterEffects): its sprite turned upside
// down under the surface, as pale as a reflection, rippling a pixel sideways row by
// row, fading with the depth. Drawn after the water and over the body's part under it
// (render priority 2), with no depth test: a pixel shows only where the surface that
// this pixel of the picture falls on mirrors at the mirror's level (mirrors()): open
// water, the wet edge of the bank beside it, the sea's surf running up the sand and the
// wet sand it leaves, a puddle after rain (the roof map's columns), so the banks and the
// land in front keep it off; and not over grass, low plants or crowns (the stencil, as
// sprite_xray.gdshader). Unshaded: it takes the sky's light (`light`).
shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;
stencil_mode read, compare_greater, 2;

#include "res://shaders/common.gdshaderinc"
#include "res://shaders/looks.gdshaderinc"

uniform sampler2D sprite_texture : filter_nearest SRGB_HINT;
// The frame of a sprite sheet to show, as in sprite.gdshader, and the animal's tint.
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 tint = vec3(1.0);
// The water's surface the figure is mirrored in, world units.
uniform float level = -1000.0;
// 1 when the water the figure is mirrored in is the sea's (WaterEffects): only then does
// the sand its surf runs up mirror. A lake as high as the sea has no surf.
uniform float sea = 0.0;
uniform float light = 1.0;
uniform vec3 water SRGB = vec3(0.3, 0.52, 0.58);

// How far into a shore's cell from the water the mirror shows, in cells.
const float SHORE_WET = 0.45;
// How clearly the surf's thin sheet and the wet sand behind a wave mirror, against open
// water's 1.
const float SURF_SHEET = 1.0;
const float SURF_WET = 0.35;
// The roof map's g bits for a top no puddle stands on and for a sloping top
// (RoofMap.NO_PUDDLE, SLOPED).
const int NO_PUDDLE = 1;
const int SLOPED = 2;

varying vec3 world_pos;
// The point as it is drawn (stand_tall), not sheared.
varying vec3 tall;

void vertex() {
	VERTEX = face_view(VERTEX, MODEL_MATRIX[3].xyz);
	world_pos = VERTEX;
	tall = stand_tall(VERTEX, MODEL_MATRIX[3].xyz);
	VERTEX = shear(tall);
}

// How far in cells from `xz` the nearest of the sea's water is (the box of a column
// whose top is water at the sea's level), up to SWASH_REACH + 1: the distance from the
// waterline the surf's sheet is drawn by (WaterMesher.swash_map, near enough). Looked
// for ring by ring, done once no farther ring can be nearer.
float sea_distance(vec2 xz) {
	vec2 f = xz / CELL;
	vec2 c = floor(f);
	float best = 1000.0;
	for (int r = 1; r <= int(SWASH_REACH) + 1; r++) {
		if (best <= float(r - 1)) {
			break;
		}
		for (int k = 0; k <= 2 * r; k++) {
			for (int side = 0; side < 4; side++) {
				float a = float(k - r);
				float b = float(side % 2 == 0 ? -r : r);
				vec2 o = c + (side < 2 ? vec2(a, b) : vec2(b, a));
				vec4 w = column(o);
				if (w.a > 0.5 && abs(floor(w.b * 255.0 + 0.5) * CELL - sea_top) < 0.1) {
					best = min(best, length(max(abs(f - o - 0.5) - 0.5, 0.0)));
				}
			}
		}
	}
	return best;
}

// How clearly the sand level with the sea at `xz` mirrors now, 0..1: under the surf's
// sheet behind its foam, and, fainter and drying, where the wave ran back from (the
// same waves as water.gdshader, surf_wave); not under the foam.
float surf_mirror(vec2 xz) {
	float d = sea_distance(xz);
	if (d > SWASH_REACH) {
		return 0.0;
	}
	float far = floor(d * CELL_TEXELS) / CELL_TEXELS;
	float front, peak, p, left, lace, fizz, wave;
	surf_wave(floor(xz * TEXELS), TIME, front, peak, p, left, lace, fizz, wave);
	float edge = front - far;
	// Past the foam line and its broken edge (water.gdshader, 7 texels).
	if (edge >= 7.0 / CELL_TEXELS) {
		return SURF_SHEET;
	}
	if (edge < 0.0 && far < peak && left > 0.0 && !surf_left_foam(far, peak, left, lace, fizz)) {
		return SURF_WET * (1.0 - smoothstep(0.4, 1.0, p));
	}
	return 0.0;
}

// Whether a puddle after rain stands at `xz` on the top `top` of column `col`: the same
// patches as world.gdshader draws (on open level ground that keeps water, not by a
// fire, not in snow), but their dark rim.
bool puddle(vec2 xz, float top, vec4 col) {
	if (puddles.x <= 0.0 || snow_amount > 0.0 || (int(col.g * 255.0 + 0.5) & NO_PUDDLE) != 0 || roofed(xz, top)) {
		return false;
	}
	vec3 tp = vec3(xz.x, top, xz.y) + vec3(1.0 / (32.0 * TEXELS));
	vec2 wt = floor(tp.xz * TEXELS);
	if (warm_spot(vec3(xz.x, top, xz.y), hash12(wt + 41.0)) >= 0.5) {
		return false;
	}
	float h = hash12(wt + floor(tp.y * TEXELS - 0.5) * 17.0);
	float n = ground_patch(xz * 2.2, 17.0) + (h - 0.5) * 0.02;
	float around = (ground_top(xz, vec2(1.0, 0.0)) + ground_top(xz, vec2(-1.0, 0.0))
		+ ground_top(xz, vec2(0.0, 1.0)) + ground_top(xz, vec2(0.0, -1.0))) * 0.25;
	n += clamp((around - top) / CELL, 0.0, 1.0) * 0.1;
	return n >= 1.0 - 0.24 * sqrt(puddles.x) + 0.01;
}

// Whether the water lies over the point `f` (0..1 each way) of column `c`, sloping
// ground whose top is level with the water it stands by (a lake or a river at the sea's
// level, which fills its cells): over the whole slope of a shore up to the land's top
// (WaterMesher.shore_water), but on an inner corner on the diagonal, the one kind of
// shore with a single corner by the water, only on that corner's side of the diagonal
// through the two corners beside it, past which its ground lies level with the water
// (WorldData.PATCH_DIAG). Not where open ground lower lies beside: the water does not
// go up such a slope (WaterMesher.shore).
bool flush_shore(vec2 c, vec2 f) {
	// The corners NW, NE, SE, SW (bits 0..3) that water at the level beside touches.
	int wet = 0;
	for (int dz = -1; dz <= 1; dz++) {
		for (int dx = -1; dx <= 1; dx++) {
			if (dx == 0 && dz == 0) {
				continue;
			}
			vec4 n = column(c + vec2(float(dx), float(dz)));
			float top = floor(n.b * 255.0 + 0.5) * CELL;
			if (n.a > 0.5 && abs(top - level) < 0.1) {
				wet |= (dx <= 0 && dz <= 0 ? 1 : 0) | (dx >= 0 && dz <= 0 ? 2 : 0)
					| (dx >= 0 && dz >= 0 ? 4 : 0) | (dx <= 0 && dz >= 0 ? 8 : 0);
			} else if (top < level - 0.1) {
				return false;
			}
		}
	}
	if (wet == 1 || wet == 2 || wet == 4 || wet == 8) {
		vec2 corner = vec2(wet == 2 || wet == 4 ? 1.0 : 0.0, wet >= 4 ? 1.0 : 0.0);
		return abs(f.x - corner.x) + abs(f.y - corner.y) < 1.0;
	}
	return wet != 0;
}

// How clearly the surface at `xz` shows the mirror, 0..1: open water at the level; the
// ground at the water's edge level with it (the foam on the sand, a bank half under
// water) with water beside it; the water over a shore flush with the land
// (flush_shore) when the mirror is not the sea's; the sand the sea's surf runs up
// (surf_mirror) when it is (`sea`); a puddle on the ground at the level (a figure
// standing on dry land is mirrored at its feet, see WaterEffects).
float mirrors(vec2 xz) {
	vec2 c = floor(xz / CELL);
	vec4 col = column(c);
	float top = floor(col.b * 255.0 + 0.5) * CELL;
	if (col.a > 0.5) {
		return abs(top - level) <= 0.6 ? 1.0 : 0.0;
	}
	if (abs(top - CELL * 0.5 - level) <= 0.1) {
		// The water covers the slope of a shore up to about its middle: only the part of
		// the cell nearer to a side (or a corner) with water beyond it shows the mirror.
		vec2 f = xz / CELL - c;
		float near = 1.0;
		if (column(c + vec2(1.0, 0.0)).a > 0.5) near = min(near, 1.0 - f.x);
		if (column(c - vec2(1.0, 0.0)).a > 0.5) near = min(near, f.x);
		if (column(c + vec2(0.0, 1.0)).a > 0.5) near = min(near, 1.0 - f.y);
		if (column(c - vec2(0.0, 1.0)).a > 0.5) near = min(near, f.y);
		if (near > SHORE_WET) {
			for (int k = 0; k < 4; k++) {
				vec2 o = vec2(k % 2 == 0 ? 1.0 : -1.0, k < 2 ? 1.0 : -1.0);
				if (column(c + o).a > 0.5) {
					near = min(near, length(f - (o * 0.5 + 0.5)) * 0.8);
				}
			}
		}
		if (near <= SHORE_WET) {
			return 1.0;
		}
	}
	// The surf outlines the sea's own shores (below); a lake as high as the sea has none.
	// Only over a sloping top: a bank that keeps a sheer wall, or an islet, is dry ground
	// level with that water (RoofMap.SLOPED).
	if (sea < 0.5 && abs(top - level) < 0.1 && (int(col.g * 255.0 + 0.5) & SLOPED) != 0
			&& flush_shore(c, xz / CELL - c)) {
		return 1.0;
	}
	if (sea > 0.5 && abs(top - sea_top) < 0.1 && abs(level - sea_top) < 0.3) {
		float k = surf_mirror(xz);
		if (k > 0.0) {
			return k;
		}
	}
	if (abs(top - level) < 0.1 && puddle(xz, top, col)) {
		return 1.0;
	}
	return 0.0;
}

void fragment() {
	if (world_pos.y > level) {
		discard;
	}
	float depth = level - world_pos.y;
	// Rows of two texels wave a texel sideways, slowly.
	float row = floor(depth * TEXELS / 2.0);
	vec2 px = 1.0 / vec2(textureSize(sprite_texture, 0));
	float wave = floor(sin(row * 1.7 + TIME * 2.2) * 0.9 + 0.5);
	vec2 uv = frame_uv.xy + UV * frame_uv.zw + vec2(wave * px.x, 0.0);
	vec4 c = texture(sprite_texture, uv);
	if (c.a < 0.5) {
		discard;
	}
	// The surface this pixel of the picture falls on: along the way to the camera from
	// the drawn point, up to the level.
	vec3 to = toward_camera();
	vec3 surface = tall + to * ((level - tall.y) / max(to.y, 0.05));
	if (gone_above(surface)) {
		discard;
	}
	float clear = mirrors(surface.xz);
	if (clear <= 0.0) {
		discard;
	}
	// A reflection is never brighter than what it reflects: the water only gives the
	// figure its hue (the tint is scaled to at most 1), it never adds light, so a dark
	// pixel (hair, an outline, the night) stays as dark as it is.
	vec3 source = looks_swap(c.rgb) * tint * 0.9;
	vec3 rgb = source * mix(vec3(1.0), water / max(max(water.r, water.g), water.b), 0.4) * light;
	ALBEDO = rgb;
	// Fainter the deeper, dithered in steps so it stays pixel art.
	float a = 0.45 * clear * (1.0 - smoothstep(0.3, 1.6, depth));
	ALPHA = a < bayer4(floor(surface.xz * TEXELS)) * 0.3 ? 0.0 : a;
	COMPAT_ALBEDO
}
