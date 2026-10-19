// Terrain and voxel props. One 16x16 texture per material side; edges, material
// transitions, snow, wetness and season tints are drawn on top, so weather and
// seasons need no extra textures.
//
// Vertex data (see chunk_mesher.gd):
//   UV   = position on the face, 0..1 (v = 0 at the north edge of a top face and at
//          the top of a wall)
//   UV2.x = tile + 64 * edges + 16384 * flag; tile 63 means "colour from COLOR only"
//          (voxels); edges hold 2 bits per edge N, S, W, E: 1 light rim, 2 dark
//          outline, 3 contact shadow; flag bits: 1 = season-tinted foliage voxel,
//          2 = wall with open sky above (gets a snow fringe), 4 = sloping top or
//          diagonal wall (textured in screen texels so it is not stretched), 8 = an
//          edge along the diagonal of corner k (bits 16..32: NW, NE, SE, SW), the face
//          lying on the corner's side of it if bit 64, with the edge code in bits
//          128..256
//   UV2.y = top tiles of the 4 neighbours N, S, W, E, 6 bits each (63 = none), for
//          material transitions on top faces
//   COLOR.r = shade (dark caps of the cut)
shader_type spatial;
render_mode world_vertex_coords, cull_back;

#include "res://shaders/common.gdshaderinc"

global uniform sampler2D terrain_atlas : source_color, filter_nearest;

const int NONE = 63;
const int GRASS = 1;
const int DIRT = 2;
const int STONE = 3;
const int SAND = 4;
// Which material grows over which at a boundary; 0 never blends.
const int PRIORITY[12] = int[](0, 6, 4, 1, 3, 0, 0, 0, 0, 2, 1, 0);

varying vec3 world_pos;
varying vec3 world_normal;
varying flat vec2 packed;
varying float clouds;

void vertex() {
	world_pos = VERTEX;
	world_normal = NORMAL;
	packed = UV2;
	VERTEX = shear(VERTEX);
}

vec3 tile_texel(int tile, ivec2 t) {
	vec2 origin = vec2(float(tile % 8), float(tile / 8)) * TEXELS;
	return texture(terrain_atlas, (origin + vec2(t) + 0.5) / (8.0 * TEXELS)).rgb;
}

// Patches on bare ground: damp and dry dirt with pebbles, dunes on sand, moss and
// lichen on stone. Multiplies the tile colour.
vec3 ground_variety(int mat, vec2 xz, vec2 wt) {
	float p = ground_patch(xz, float(mat));
	float q = ground_patch(xz, float(mat) + 7.0);
	float speck = hash12(wt + 13.0);
	vec3 k = vec3(1.0);
	if (mat == DIRT) {
		k *= p > 0.66 ? vec3(0.84, 0.82, 0.8) : (p < 0.3 ? vec3(1.08, 1.06, 1.02) : vec3(1.0));
		if (speck > 1.0 - 0.05 * q) {
			k *= vec3(1.3, 1.3, 1.36);
		}
	} else if (mat == SAND) {
		k *= p > 0.64 ? vec3(1.05, 1.04, 1.02) : (p < 0.34 ? vec3(0.93, 0.92, 0.9) : vec3(1.0));
		if (speck > 0.992) {
			k *= vec3(0.78, 0.76, 0.74);
		}
	} else if (mat == STONE) {
		k *= p > 0.65 ? vec3(0.9, 1.0, 0.82) : (p < 0.3 ? vec3(1.06) : vec3(1.0));
		if (q > 0.72 && speck > 0.55) {
			k *= vec3(0.84, 0.98, 0.72);
		}
	}
	return k;
}

// Snow is not flat white: drifts in three soft tones, bluish hollows and glints.
vec3 snow_color(vec2 xz, vec2 wt) {
	float drift = ground_patch(xz, 9.0);
	vec3 c = drift > 0.62 ? vec3(0.95, 0.97, 1.0) : (drift < 0.36 ? vec3(0.85, 0.89, 0.97) : vec3(0.9, 0.93, 0.99));
	float n = hash12(wt + 29.0);
	if (n > 0.985) {
		c = vec3(1.0);
	} else if (n < 0.04) {
		c *= vec3(0.92, 0.94, 0.98);
	}
	return c;
}

void fragment() {
	// Cut levels still cast their shadows, so caves and rooms stay in the dark.
	if (world_pos.y > cut_height + 0.01 && !IN_SHADOW_PASS) {
		discard;
	}
	int a = int(packed.x + 0.5);
	int tile = a % 64;
	int edges = (a / 64) % 256;
	int flag = a / 16384;
	ivec2 t = clamp(ivec2(floor(UV * TEXELS)), ivec2(0), ivec2(15));
	// Texel distance to the N, S, W, E edges of the face.
	int dist[4] = int[](t.y, 15 - t.y, t.x, 15 - t.x);
	vec3 col = COLOR.rgb;
	bool top = world_normal.y > 0.5;
	vec2 wt = floor(world_pos.xz * TEXELS);
	float warm = warm_spot(world_pos, hash12(wt + 41.0));
	if (tile != NONE) {
		int pick = tile;
		if (top) {
			// The neighbour with the higher priority spills 1..3 texels over the edge.
			int n = int(packed.y + 0.5);
			int best = PRIORITY[tile / 3];
			for (int e = 0; e < 4; e++) {
				int nt = (n >> (6 * e)) & 63;
				if (nt == NONE || best == 0) {
					continue;
				}
				int p = PRIORITY[nt / 3];
				if (p <= best) {
					continue;
				}
				float along = e < 2 ? wt.x : wt.y;
				float reach = 1.0 + floor(hash12(vec2(along, float(e))) * 2.0) + floor(hash12(vec2(floor(along / 3.0), 9.0)) * 2.0);
				if (float(dist[e]) < reach) {
					best = p;
					pick = nt;
				}
			}
		}
		ivec2 tm = top ? tile_mirror(t, floor(world_pos.xz)) : t;
		if (flag == 4) {
			// A slope covers more or fewer screen rows than a flat top: take texels
			// where they show on screen, one texel per pixel.
			tm = ivec2(mod(floor(vec2(world_pos.x, world_pos.z - world_pos.y) * TEXELS), TEXELS));
		}
		if (top && pick == GRASS * 3 && bare_ground(world_pos.xz) > 0.5) {
			pick = DIRT * 3;
		}
		col *= tile_texel(pick, tm);
		if (pick == GRASS * 3) {
			col *= grass_tint * grass_variation(world_pos.xz);
		} else if (top && pick % 3 == 0 && COLOR.r > 0.5) {
			col *= ground_variety(pick / 3, world_pos.xz, wt);
		}
	} else if ((flag & 1) != 0) {
		col *= foliage_tint;
	}
	// Edge shading: a light rim on convex edges, a dark outline where the face meets
	// something farther away, a soft contact shadow in inner corners. On tops the
	// outline gets a lit bevel inside it, so the far edge of a raised block reads
	// clearly against the same ground behind it.
	float ao = 1.0;
	for (int e = 0; e < 4; e++) {
		int code = (edges >> (2 * e)) & 3;
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
		// Texel distance to the diagonal half a cell from corner k, counted on the face.
		int k = (flag >> 4) & 3;
		int mid = int(TEXELS) / 2;
		int sd = k == 0 ? t.x + t.y + 1 - mid : (k == 1 ? mid - t.x + t.y : (k == 2 ? 3 * mid - 1 - t.x - t.y : mid + t.x - t.y));
		int dd = (flag & 64) != 0 ? -sd : sd;
		int code = (flag >> 7) & 3;
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
	// Snow covers whole texels on upward faces and a fringe on top of walls. The
	// wind leaves a few spots bare, and it melts away around fires.
	float snow_here = snow_amount * (1.0 - warm);
	vec3 texel = floor(world_pos * TEXELS - world_normal * 0.5);
	float h = hash12(texel.xz + texel.y * 17.0);
	float snow = 0.0;
	if (snow_here <= 0.0) {
		// No snow: skip the snow patterns.
	} else if (top) {
		float swept = step(ground_patch(world_pos.xz, 5.0) + (h - 0.5) * 0.05, 0.07);
		snow = step(h, snow_here * 1.15 - 0.05) * (1.0 - swept);
	} else if ((flag & 2) != 0) {
		float fringe = snow_here * (0.12 + 0.12 * h);
		snow = step(1.0 - fringe, fract(world_pos.y)) * step(0.3, snow_here);
	}
	if (snow > 0.0) {
		col = mix(col, snow_color(world_pos.xz, wt), snow);
	}
	float wet = wetness * (1.0 - snow) * (1.0 - 0.7 * warm);
	col *= 1.0 - 0.3 * wet;
	col *= cut_shade(world_pos.y);
	ALBEDO = col;
	// Walls get less sky light than tops.
	AO = ao * (top ? 1.0 : 0.8);
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(world_pos);
}

void light() {
	DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds);
}
