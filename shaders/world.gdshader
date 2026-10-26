// Terrain and voxel props. One 16x16 texture per material side; edges, material
// transitions, snow, wetness and season tints are drawn on top, so weather and
// seasons need no extra textures.
//
// Vertex data (see chunk_mesher.gd):
//   UV   = position on the cell's face, 0..1 (v = 0 at the north edge of a top face
//          and at the top of a wall), for edges; merged plain tops run past 1. The
//          texture itself is laid by world position, a 16x16 tile over two cells.
//   UV2.x = tile + 64 * edges + 16384 * flag; tile 63 means "colour from COLOR only"
//          (voxels); edges hold 2 bits per edge N, S, W, E: 1 light rim, 2 dark
//          outline, 3 contact shadow (on tops 1 and 2 both mean open ground lower
//          beside, drawn as a rim toward the sun or the moon, else an outline); flag bits: 1 = season-tinted foliage voxel,
//          2 = wall with open sky above (gets a snow fringe), 4 = sloping top or
//          diagonal wall (textured in screen texels so it is not stretched), 8 = an
//          edge along the diagonal of corner k (bits 16..32: NW, NE, SE, SW), the face
//          lying on the corner's side of it if bit 64, with the edge code in bits
//          128..256
//   UV2.y = top tiles of the 4 neighbours N, S, W, E, 6 bits each (63 = none), for
//          material transitions on top faces
//   COLOR.r = shade (dark caps of the cut); COLOR.a = half the relief shade of a
//          snowdrift (tile 63; 8-bit vertex alpha cannot hold a shade above 1); below
//          1 on a stone top whose moss was picked, 16ths naming which tops beside,
//          bits N, S, W, E, were picked too; on a tree's trunk which cell of it this
//          is, in eighths (1 the foot, 2 the next, up to 5)
//   A snowdrift has tile 63 and UV = 4 + the vertex's place on the mound's round
//          base, -0.5..0.5 (see drifts.gd)
shader_type spatial;
render_mode world_vertex_coords, cull_back;
// Marks the pixels it wins as solid for the player's silhouette (1, see sprite_xray);
// low props and snow drifts use a copy that marks them low (see main.low_variant).
stencil_mode write, compare_always, 1;

#include "res://shaders/common.gdshaderinc"

global uniform sampler2D terrain_atlas : source_color, filter_nearest;
// Corner shape of each material (Mat.corner_shape): 0 a straight cut, 1 a little
// rounded, 2 a quarter circle; the exponent p of the curve is 1, 1.5 or 2.
uniform int corner_shapes[21];
// A word per material from its data (Mat.shader_bits): bits 0..3 the priority (which
// material grows over which at a boundary, 0 never blends), bit 4 DRAINS (no puddles),
// bits 5..6 the kind of patches on open ground (GROUND_*), bit 7 TRUNK (a log or a
// bark: a tree's trunk clears round the player). One entry for every material, filled
// by main.gd: reading past the end draws garbage on some GPUs.
uniform int material_bits[21];

const int NONE = 63;
// The core's materials come first in a fixed order; the rest are known by their bits.
const int GRASS = 1;
const int DIRT = 2;
const int STONE = 3;
const int PRIORITY_MASK = 15;
const int DRAINS = 16;
const int GROUND_SHIFT = 5;
const int TRUNK = 128;
// Cells of a trunk over its foot it takes to clear in full round the player.
const float TRUNK_RISE = 3.0;
const int GROUND_SOIL = 1;
const int GROUND_SAND = 2;
const int GROUND_ROCK = 3;
// Outward directions of the N, S, W, E edges of a face, and of the diagonals of
// corners NW, NE, SE, SW (seen from the rest of the cell).
const vec2 EDGE_OUT[4] = vec2[](vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(1.0, 0.0));
const vec2 CORNER_OUT[4] = vec2[](vec2(-0.7071, -0.7071), vec2(0.7071, -0.7071), vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071));

varying vec3 world_pos;
varying vec3 world_normal;
varying flat vec2 packed;
varying float clouds;

// How big the snowdrifts are: full in deep snow, sinking and shrinking to nothing as
// the snow cover thins, so they melt away in spring instead of vanishing at once.
float drift_size() {
	return clamp((snow_amount - 0.3) / 0.5, 0.0, 1.0);
}

bool is_drift(float packed_tile, vec2 uv) {
	return int(packed_tile + 0.5) % 64 == NONE && uv.x > 2.5;
}

// Where the point is in the picture, for the dither of the light rings (light_texel).
varying vec2 light_xz;

void vertex() {
	if (is_drift(UV2.x, UV)) {
		// The mound stands on the top of its cell and is lower than a cell.
		float base = floor(VERTEX.y / CELL + 0.01) * CELL;
		VERTEX.y = base + (VERTEX.y - base) * drift_size();
	}
	world_pos = VERTEX;
	world_normal = NORMAL;
	packed = UV2;
	VERTEX = shear(VERTEX);
	light_xz = VERTEX.xz;
}

vec3 tile_texel(int tile, ivec2 t) {
	vec2 origin = vec2(float(tile % 8), float(tile / 8)) * TEXELS;
	return texture(terrain_atlas, (origin + vec2(t) + 0.5) / (8.0 * TEXELS)).rgb;
}

// Patches on bare ground by the material's `ground` kind: damp and dry soil with
// pebbles, dunes on sand, moss and lichen on rock. Multiplies the tile colour.
vec3 ground_variety(int mat, vec2 xz, vec2 wt) {
	int ground = (material_bits[mat] >> GROUND_SHIFT) & 3;
	float p = ground_patch(xz, float(mat));
	float q = ground_patch(xz, float(mat) + 7.0);
	float speck = hash12(wt + 13.0);
	vec3 k = vec3(1.0);
	if (ground == GROUND_SOIL) {
		k *= p > 0.66 ? vec3(0.84, 0.82, 0.8) : (p < 0.3 ? vec3(1.08, 1.06, 1.02) : vec3(1.0));
		if (speck > 1.0 - 0.05 * q) {
			k *= vec3(1.3, 1.3, 1.36);
		}
	} else if (ground == GROUND_SAND) {
		k *= p > 0.64 ? vec3(1.05, 1.04, 1.02) : (p < 0.34 ? vec3(0.93, 0.92, 0.9) : vec3(1.0));
		if (speck > 0.992) {
			k *= vec3(0.78, 0.76, 0.74);
		}
	} else if (ground == GROUND_ROCK) {
		k *= p > 0.65 ? vec3(0.9, 1.0, 0.82) : (p < 0.3 ? vec3(1.06) : vec3(1.0));
		if (q > 0.72 && speck > 0.55) {
			k *= vec3(0.84, 0.98, 0.72);
		}
	}
	return k;
}

// Snow is not flat white: drifts in three soft tones, none of them pure white so the
// noon sun does not wash the field out, wind ripples a shade apart stretched along
// the wind, bluish hollows and a few glints.
vec3 snow_color(vec2 xz, vec2 wt) {
	float drift = ground_patch(xz, 9.0);
	// Kept under 1 because the noon light adds up to more than 1 and the screen
	// encoding lifts bright tones further: 0.73 here is a near white on screen, the
	// hollows stay a light blue grey.
	vec3 c = drift > 0.62 ? vec3(0.73, 0.76, 0.82) : (drift < 0.36 ? vec3(0.64, 0.68, 0.77) : vec3(0.69, 0.72, 0.8));
	float ripple = ground_patch(vec2(xz.x * 1.5, xz.y * 6.0) + 50.0, 13.0);
	if (ripple > 0.6) {
		c *= vec3(1.06, 1.05, 1.03);
	} else if (ripple < 0.4) {
		c *= vec3(0.94, 0.95, 0.98);
	}
	float n = hash12(wt + 29.0);
	if (n > 0.985) {
		c = vec3(0.86, 0.9, 0.96);
	} else if (n < 0.05) {
		c *= vec3(0.9, 0.92, 0.97);
	}
	return c;
}

// A wall the camera looks at from behind the player, of the space they are in, stays
// whole above the automatic cut: in a cave or a room the far walls stand up to the
// ceiling, out in a ravine or behind a hill the slope beyond stands up to its top, and
// only what lies between the camera and the player (the rock above, the near walls,
// whose faces turn their backs to the camera) goes. Under a roof only the walls of
// covered space count, so the hill's own face over a cave does not hide the cave; out
// in the open only open ones, and none under a crown, so trunks go with their crowns.
bool back_wall(vec3 p, vec3 n) {
	if (cut_ghost < 0.5 || p.y <= cut_height + 0.01 || abs(n.y) > 0.5 || dot(n.xz, view_up) > -0.3
			|| dot(p.xz - player_pos.xz, view_up) <= 0.0) {
		return false;
	}
	vec2 front = p.xz + n.xz * CELL * 0.5;
	if (roofed(player_pos.xz, player_pos.y + 2.0 * CELL)) {
		return roofed(front, p.y);
	}
	return !roofed(front, p.y) && !under_crown(front);
}

void fragment() {
	bool kept = back_wall(world_pos, world_normal);
	// Cut levels still cast their shadows, so caves and rooms stay in the dark.
	if (!IN_SHADOW_PASS && !kept && above_cut(world_pos)) {
		discard;
	}
	if (is_drift(packed.x, UV)) {
		// The shrinking footprint of a melting drift, with a dithered rim.
		float r = length(UV - 4.0) * 2.0;
		if (r > drift_size() + (bayer4(floor(world_pos.xz * TEXELS)) - 0.5) * 0.15) {
			discard;
		}
	}
	int a = int(packed.x + 0.5);
	int tile = a % 64;
	// The trunk of a tree nearer the viewer than the player clears round them (see
	// trunk_through), but for its foot: its first cell stays whole and the
	// TRUNK_RISE cells above it clear more and more from the bottom up. The vertex
	// alpha of a trunk's faces says which cell of it they are, in eighths (see
	// TrunkMesher.trunk_faces): 1 the foot, 2 the next, up to 5.
	if (!IN_SHADOW_PASS && tile != NONE && COLOR.a < 0.9 && (material_bits[tile / 3] & TRUNK) != 0) {
		float level = floor(COLOR.a * 8.0 + 0.5) - 1.0;
		float rise = clamp((level - 1.0 + fract(world_pos.y / CELL)) / TRUNK_RISE, 0.0, 1.0);
		vec2 lt = light_texel(light_xz);
		if (bayer4(lt) < trunk_through(lt, world_pos) * rise) {
			discard;
		}
	}
	int edges = (a / 64) % 256;
	int flag = a / 16384;
	int last = int(CELL_TEXELS) - 1;
	ivec2 t = clamp(ivec2(floor(UV * CELL_TEXELS)), ivec2(0), ivec2(last));
	// Texel distance to the N, S, W, E edges of the face.
	int dist[4] = int[](t.y, last - t.y, t.x, last - t.x);
	vec3 col = COLOR.rgb;
	// The steep middle of a curved slope still counts as its top.
	bool top = world_normal.y > 0.5 || (flag == 4 && tile != NONE && tile % 3 == 0);
	// The dark caps of the cut (see ChunkMesher.build_cap) are cross-sections, not
	// ground: nothing grows on them.
	bool cap = tile != NONE && COLOR.r < 0.5;
	// Texels are looked up a 32nd of a texel off the world position: on a diagonal wall
	// the middles of the pixels fall right on the texels' edges, and the least rounding
	// error (a phone's GPU) flips them from one texel to the next as the view moves.
	vec3 tp = world_pos + vec3(1.0 / (32.0 * TEXELS));
	vec2 wt = floor(tp.xz * TEXELS);
	float warm = warm_spot(world_pos, hash12(wt + 41.0));
	// The tile drawn here: this face's, or a neighbour's spilling over the edge.
	int pick = tile;
	if (tile != NONE) {
		if (top) {
			// The neighbour with the higher priority spills 1..3 texels over the edge.
			int n = int(packed.y + 0.5);
			int best = material_bits[tile / 3] & PRIORITY_MASK;
			// On a slope the edges with the same neighbour add up, so it grows over the
			// slope as a whole: round a corner between two edges along the diagonal,
			// fill a slope between two edges or three, instead of running a band round
			// the cell as if it were a block.
			bool slope = (flag & 4) != 0;
			int own = best;
			for (int e = 0; e < 4; e++) {
				int nt = (n >> (6 * e)) & 63;
				if (nt == NONE || own == 0) {
					continue;
				}
				int p = material_bits[nt / 3] & PRIORITY_MASK;
				if (p <= best) {
					continue;
				}
				float along = e < 2 ? wt.x : wt.y;
				float reach = 1.0 + floor(hash12(vec2(along, float(e))) * 2.0) + floor(hash12(vec2(floor(along / 3.0), 9.0)) * 2.0);
				float near = CELL_TEXELS - float(dist[e]);
				if (slope) {
					for (int f = 0; f < 4; f++) {
						if (f != e && ((n >> (6 * f)) & 63) == nt) {
							near += CELL_TEXELS - float(dist[f]);
						}
					}
				}
				if (near > CELL_TEXELS - reach) {
					best = p;
					pick = nt;
				}
			}
		}
		// The tile's texel at this spot of the world: x and z on tops, across and down
		// on walls.
		vec2 across = abs(world_normal.y) > 0.5 ? tp.xz
			: vec2(abs(world_normal.x) > 0.5 ? tp.z : tp.x, -tp.y);
		ivec2 tm = ivec2(mod(floor(across * TEXELS), TEXELS));
		if (top) {
			tm = tile_mirror(tm, floor(world_pos.xz));
		}
		if (flag == 4) {
			// A slope covers more or fewer screen rows than a flat top: take texels
			// where they show on screen, one texel per pixel.
			tm = ivec2(mod(floor(screen_plane(world_pos) * TEXELS), TEXELS));
		}
		// A cap of the cut shows the inside of the cells it cuts: soil, not turf.
		if (top && pick == GRASS * 3 && (cap || bare_ground(world_pos.xz) > 0.5)) {
			pick = DIRT * 3;
		}
		col *= tile_texel(pick, tm);
		if (pick == GRASS * 3) {
			col *= grass_tint * grass_variation(world_pos.xz);
		} else if (top && pick % 3 == 0 && !cap) {
			col *= ground_variety(pick / 3, world_pos.xz, wt);
		}
	} else if ((flag & 1) != 0) {
		col *= foliage_tint;
	}
	// Edge shading: a light rim on convex edges, a dark outline where the face meets
	// something farther away, a soft contact shadow in inner corners. On tops the
	// outline gets a lit bevel inside it, so the far edge of a raised block reads
	// clearly against the same ground behind it.
	// An open edge of a top (1 or 2) is a light rim where it faces the sun or the moon
	// (light_side) and a dark outline where it faces away or aside. A side of a wall
	// shows its line only where the face beyond that side turns away from the camera
	// (the side wall of the cell, or on a trunk's cut corner the side of the trunk
	// beyond), light or dark the same way.
	// Texture x runs east on north and south walls, south on east and west ones, and to
	// the right seen from outside on slanted ones (ChunkMesher._bark).
	vec2 nh = world_normal.xz;
	bool square = abs(nh.x) > 0.9 || abs(nh.y) > 0.9;
	vec2 east = square ? (abs(nh.y) > 0.9 ? vec2(1.0, 0.0) : vec2(0.0, 1.0)) : vec2(nh.y, -nh.x);
	float ao = 1.0;
	for (int e = 0; e < 4; e++) {
		int code = (edges >> (2 * e)) & 3;
		if (top && (code == 1 || code == 2)) {
			code = dot(EDGE_OUT[e], light_side) > 0.1 ? 1 : 2;
		} else if (!top && code == 2 && e >= 2) {
			vec2 side = e == 3 ? east : -east;
			vec2 beyond = square ? side : normalize(nh + side);
			code = dot(beyond, view_up) > -0.05 ? (dot(beyond, light_side) > 0.1 ? 1 : 2) : 0;
		}
		if (code == 1 && dist[e] == 0) {
			col = col * vec3(1.22, 1.2, 1.1) + vec3(0.025);
		} else if (code == 2 && dist[e] == 0) {
			col *= top ? 0.45 : 0.6;
		} else if (code == 2 && top && dist[e] == 1) {
			col = col * vec3(1.16, 1.14, 1.06) + vec3(0.02);
		} else if (code == 3 && dist[e] <= 1) {
			ao = min(ao, dist[e] == 0 ? 0.6 : 0.8);
		}
	}
	if ((flag & 8) != 0) {
		// Texel distance to the curve of corner k (the diagonal half a cell from the
		// corner, or a rounder curve, see ChunkMesher.corner_curve), counted on the
		// face, positive toward the middle of the cell.
		int k = (flag >> 4) & 3;
		int dd = corner_distance(t, k, corner_shapes[tile / 3]);
		dd = (flag & 64) != 0 ? -dd : dd;
		int code = (flag >> 7) & 3;
		if (top && (code == 1 || code == 2)) {
			vec2 across = CORNER_OUT[k] * ((flag & 64) != 0 ? -1.0 : 1.0);
			code = dot(across, light_side) > 0.1 ? 1 : 2;
		}
		if (code == 1 && dd == 0) {
			col = col * vec3(1.22, 1.2, 1.1) + vec3(0.025);
		} else if (code == 2 && dd == 0) {
			col *= 0.45;
		} else if (code == 2 && dd == 1) {
			col = col * vec3(1.16, 1.14, 1.06) + vec3(0.02);
		} else if (code == 3 && dd <= 1) {
			ao = min(ao, dd == 0 ? 0.6 : 0.8);
		}
	}
	// Snow covers whole texels on upward faces and a fringe on top of walls, all year
	// on the high mountains (two levels to thicken above the snow line). The wind
	// leaves a few spots bare, it melts away around fires, and none falls on the faces
	// of a cell under a roof, an overhang or a cave ceiling.
	// A slope's top may go down into the cell below its own (a deep corner): that is
	// still its own open surface, not ground under it.
	bool roof = roofed(world_pos.xz, world_pos.y + ((flag & 4) != 0 && top ? CELL : 0.0));
	// Ground in a cut corner of a wall lies in the wall's column, under it on the roof
	// map, but open to the sky like the column beyond the corner.
	if (roof && top && (flag & 72) == 72) {
		int k = (flag >> 4) & 3;
		vec2 out_dir = vec2(k == 1 || k == 2 ? 1.0 : -1.0, k >= 2 ? 1.0 : -1.0);
		roof = roofed((floor(world_pos.xz / CELL) + 0.5 + out_dir) * CELL, world_pos.y);
	}
	float peak = clamp((world_pos.y - snow_line) / (2.0 * CELL), 0.0, 1.0);
	// No snow on the top of a trunk inside its crown (a dark cap, see TrunkMesher).
	bool crowned = cap && (material_bits[tile / 3] & TRUNK) != 0;
	float snow_here = roof || crowned ? 0.0 : max(snow_amount, peak) * (1.0 - warm);
	vec3 texel = floor(tp * TEXELS - world_normal * 0.5);
	float h = hash12(texel.xz + texel.y * 17.0);
	// Moss on the tops of stone in damp patches, not by a fire nor where it was
	// picked (see Grass.stone_moss); a picked top keeps a ragged edge of it, 0..2
	// texels, along the tops beside that were not picked, so a picked patch is not cut
	// out in squares.
	bool moss = COLOR.a > 0.97;
	if (!moss && top && tile == 3 * 3) {
		int around = int(COLOR.a * 16.0 + 0.5);
		ivec2 lt = ivec2(mod(wt, CELL_TEXELS));
		int in_cell[4] = int[](lt.y, last - lt.y, lt.x, last - lt.x);
		for (int e = 0; e < 4; e++) {
			float along = e < 2 ? wt.x : wt.y;
			float reach = floor(hash12(vec2(along, float(e) + 23.0)) * 1.6) + floor(hash12(vec2(floor(along / 2.0), float(e) + 29.0)) * 2.4);
			moss = moss || ((around >> e) & 1) == 0 && float(in_cell[e]) < reach;
		}
	}
	if (top && pick == 3 * 3 && !cap && moss && warm < 0.5 && ground_patch(world_pos.xz + 7.0, 21.0) > 0.66 + (h - 0.5) * 0.1) {
		col = mix(col, vec3(0.3, 0.44, 0.2) * (0.88 + 0.24 * h), 0.9);
	}
	// Leaves fallen under the crowns as the trees lose them: single texels of brown,
	// rust and yellow, thicker in patches. The filtered map goes from 1 under a crown to
	// 0 a column away: with some noise on it the leaves thin out to a ragged edge round
	// the crown rather than fill the squares of the columns it covers.
	if (top && !cap && tile != NONE && leaf_litter > 0.0) {
		float l = hash12(texel.xz + 41.0);
		float heap = ground_patch(world_pos.xz, 11.0);
		float cover = texture(roof_map_soft, (texel.xz + 0.5) / TEXELS / wrap_size).g;
		float edge = smoothstep(0.2, 0.7, cover + (hash12(texel.xz + 59.0) - 0.5) * 0.35 + (heap - 0.5) * 0.4);
		if (l < leaf_litter * (0.15 + 0.5 * heap) * edge) {
			float tone = fract(l * 37.1);
			vec3 leaf = tone < 0.4 ? vec3(0.62, 0.34, 0.13) : (tone < 0.75 ? vec3(0.74, 0.52, 0.16) : vec3(0.46, 0.3, 0.17));
			col = leaf * (0.9 + 0.2 * h);
		}
	}
	float snow = 0.0;
	if (snow_here <= 0.0) {
		// No snow: skip the snow patterns.
	} else if (top) {
		float swept = step(ground_patch(world_pos.xz, 5.0) + (h - 0.5) * 0.05, 0.07);
		snow = step(h, snow_here * 1.15 - 0.05) * (1.0 - swept);
	} else if ((flag & 2) != 0) {
		float fringe = snow_here * (0.24 + 0.24 * h);
		snow = step(1.0 - fringe, fract(world_pos.y / CELL)) * step(0.3, snow_here);
	}
	if (snow > 0.0) {
		col = mix(col, snow_color(world_pos.xz, wt), snow);
	}
	if (tile == NONE) {
		// A snowdrift's relief is a soft shade baked into its vertex alpha, halved.
		col *= COLOR.a * 2.0;
	}
	float wet = roof ? 0.0 : wetness * (1.0 - snow) * (1.0 - 0.7 * warm);
	col *= 1.0 - 0.3 * wet;
	// Puddles after rain on level open ground, not on sand, not by a fire: in patches
	// and in the low cells, shrinking from their edges as they dry, a damp rim round
	// them, and rings of drops on them while it rains.
	if (puddles.x > 0.0 && top && !cap && !roof && flag != 4 && world_normal.y > 0.95 && tile != NONE
			&& (material_bits[tile / 3] & DRAINS) == 0 && snow <= 0.0 && warm < 0.5) {
		vec2 at = world_pos.xz * 2.2;
		float n = ground_patch(at, 17.0) + (h - 0.5) * 0.02;
		float here = ground_top(world_pos.xz, vec2(0.0));
		float around = (ground_top(world_pos.xz, vec2(1.0, 0.0)) + ground_top(world_pos.xz, vec2(-1.0, 0.0))
			+ ground_top(world_pos.xz, vec2(0.0, 1.0)) + ground_top(world_pos.xz, vec2(0.0, -1.0))) * 0.25;
		n += clamp((around - here) / CELL, 0.0, 1.0) * 0.1;
		float edge = 1.0 - 0.24 * sqrt(puddles.x);
		if (n > edge) {
			// Still water shows the sky: a light cool grey over the darkened ground.
			vec3 sky = vec3(0.42, 0.5, 0.6) * (0.96 + 0.08 * h);
			col = mix(col * 0.6, sky, 0.55);
			if (n < edge + 0.01) {
				// A darker line where the water meets the ground.
				col *= 0.8;
			}
			float drop = hash13(vec3(wt, floor(TIME * 5.0 + h * 7.0)));
			if (drop > 1.0 - 0.05 * puddles.y) {
				col += vec3(0.16, 0.18, 0.2);
			}
		} else if (n > edge - 0.03) {
			col *= 0.78;
		}
	}
	vec4 veiled = veil(world_pos, depth_fade(kept ? cut_height : world_pos.y));
	ALBEDO = col * (1.0 - veiled.a);
	EMISSION = veiled.rgb;
	// Walls get less sky light than tops.
	AO = ao * (top ? 1.0 : 0.8);
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(world_pos);
}

void light() {
	// A torch or a fire lights the faces turned to where it stands in the world, not
	// to its sheared place (see unshear_dir): the foot of a wall beside it too.
	vec3 to_light = LIGHT_IS_DIRECTIONAL ? LIGHT
		: normalize((VIEW_MATRIX * vec4(unshear_dir((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz), 0.0)).xyz);
	vec3 lit = toon_light(NORMAL, to_light, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds, light_texel(light_xz),
		light_stretch(INV_VIEW_MATRIX, LIGHT));
	// Nor what a block stands between it and the light.
	if (!LIGHT_IS_DIRECTIONAL && lit != vec3(0.0) && light_hidden(shear(world_pos),
			normalize((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz), world_pos, world_normal)) {
		lit = vec3(0.0);
	}
	DIFFUSE_LIGHT += lit;
}
