// Terrain and voxel props. One 16x16 texture per material side; edges, material
// transitions, snow, wetness and season tints are drawn on top, so weather and
// seasons need no extra textures.
//
// Vertex data (see chunk_mesher.gd):
//   UV   = position on the face, 0..1 (v = 0 at the north edge of a top face and at
//          the top of a wall)
//   UV2.x = tile + 64 * edges + 16384 * flag; tile 63 means "colour from COLOR only"
//          (voxels); edges hold 2 bits per edge N, S, W, E: 1 light rim, 2 dark
//          outline, 3 contact shadow; flag 1 = season-tinted foliage voxel,
//          flag 2 = wall with open sky above (gets a snow fringe)
//   UV2.y = top tiles of the 4 neighbours N, S, W, E, 6 bits each (63 = none), for
//          material transitions on top faces
//   COLOR.r = shade (dark caps of the cut)
shader_type spatial;
render_mode world_vertex_coords, cull_back;

#include "res://shaders/common.gdshaderinc"

global uniform sampler2D terrain_atlas : source_color, filter_nearest;

const int NONE = 63;
const int GRASS = 1;
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

void fragment() {
	if (world_pos.y > cut_height + 0.01) {
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
	if (tile != NONE) {
		int pick = tile;
		if (top) {
			// The neighbour with the higher priority spills 1..3 texels over the edge.
			int n = int(packed.y + 0.5);
			int best = PRIORITY[tile / 3];
			vec2 wt = floor(world_pos.xz * TEXELS);
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
		col *= tile_texel(pick, t);
		if (pick / 3 == GRASS && pick % 3 == 0) {
			col *= grass_tint;
		}
	} else if (flag == 1) {
		col *= foliage_tint;
	}
	// Edge shading: a light rim on convex edges, a dark outline where the face meets
	// something farther away, a soft contact shadow in inner corners.
	float ao = 1.0;
	for (int e = 0; e < 4; e++) {
		int code = (edges >> (2 * e)) & 3;
		if (code == 1 && dist[e] == 0) {
			col = col * vec3(1.22, 1.2, 1.1) + vec3(0.025);
		} else if (code == 2 && dist[e] == 0) {
			col *= 0.6;
		} else if (code == 3 && dist[e] <= 1) {
			ao = min(ao, dist[e] == 0 ? 0.6 : 0.8);
		}
	}
	// Snow covers whole texels on upward faces and a fringe on top of walls.
	vec3 texel = floor(world_pos * TEXELS - world_normal * 0.5);
	float h = hash12(texel.xz + texel.y * 17.0);
	float snow = 0.0;
	if (top) {
		snow = step(h, snow_amount * 1.15 - 0.05);
	} else if (flag == 2) {
		float fringe = snow_amount * (0.12 + 0.12 * h);
		snow = step(1.0 - fringe, fract(world_pos.y)) * step(0.3, snow_amount);
	}
	col = mix(col, vec3(0.9, 0.93, 1.0), snow);
	float wet = wetness * (1.0 - snow);
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
