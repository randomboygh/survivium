// Tree crowns made of leaf cluster cards (MultiMesh, see foliage.gd), lit like
// t3ssel8r's trees: colour comes from the light alone, in four steps from a warm
// yellow-green on the sunny top to a cool blue-green underneath, and every card takes
// the normal of the crown at its spot, so the bands run across the whole crown. Single
// pointed leaves of the texture tilt that normal a little and flutter in the wind, so
// band edges follow leaf outlines and shimmer. Cards sway in whole pixels, thin out in
// winter, take snow on top, and turn see-through around the player when they hide them.
// Single leaves differ a little in tone and their upper edges catch the light, so they
// show one by one the way grass blades do.
// INSTANCE_CUSTOM: xyz = normal of the crown at the card, w = row of the clump texture
// (whole part, plus 8 for the deep layer of a crown) + sway phase (fraction).
// COLOR: tint of the tree; alpha what it does in winter (see Foliage): 1 keeps dry
// leaves under snow, 0.8 goes bare, 0.6 is evergreen, 0.1, 0.2.. a bush of type 0, 1..
// (see Foliage.bush_kind), whose berries are pixels of the texture marked in alpha.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
// Crowns are tall for the player's silhouette (see sprite_xray), bushes use a copy
// that marks them low (see main.low_variant).
stencil_mode write, compare_always, 2;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D clump_texture : filter_nearest;
uniform float clump_size = 1.5;
// The window round the player in a crown nearer the viewer, and the thinner rim
// beyond it, in world units.
const float SEE_THROUGH = 1.8;
const float SEE_RIM = 0.5;
// Rows of the clump texture, one per size of leaf bunch.
uniform int clump_rows = 1;
// Row of bare branches, which the deep layer of a bare tree shows in winter; -1 for none.
uniform int branch_row = -1;
// Colours of ripe berries by bush type (see Bushes), black for none.
uniform vec3 berry_colors[4];
// Share of the berries ripe, by season.
global uniform float berry_amount;

varying vec3 center;
varying flat vec4 custom;
varying vec4 tint;
varying float clouds;

// Where the point is in the picture, for the dither of the light rings (light_texel).
varying vec2 light_xz;

void vertex() {
	center = VERTEX - vec3((UV.x - 0.5) * clump_size, (0.5 - UV.y) * clump_size, 0.0);
	custom = INSTANCE_CUSTOM;
	tint = COLOR;
	float sway = sin(TIME * 1.1 + center.x * 0.4 + fract(custom.w) * 6.28) * (0.3 + length(wind) * 1.4);
	VERTEX.x += round(sway) / TEXELS;
	VERTEX = shear(face_view(VERTEX, center));
	light_xz = VERTEX.xz;
}

void fragment() {
	float phase = fract(custom.w);
	float variant = floor(phase * 4.0);
	float row = floor(custom.w);
	bool deep = row >= 7.5;
	row -= deep ? 8.0 : 0.0;
	bool evergreen = tint.a > 0.5 && tint.a < 0.7;
	float amount = leaves_left(tint.a);
	// A bare tree's deep layer shows its branches.
	bool branches = deep && amount < 0.01 && branch_row >= 0;
	if (branches) {
		row = float(branch_row);
	}
	vec4 m = texture(clump_texture, vec2((variant + UV.x) / 4.0, (row + UV.y) / float(clump_rows)));
	vec2 texel = floor(screen_plane(center) * TEXELS + UV * clump_size * TEXELS);
	if (m.a < 0.5 || cut_dither(center.y, texel)) {
		discard;
	}
	// Leaves fall cluster by cluster, and single leaves of the remaining clusters
	// thin out (red is a random number per leaf).
	float leaf = m.r;
	bool berry = m.a < 0.75;
	bool edge = !berry && m.a < 0.9;
	if (!branches && (hash13(floor(center)) > amount || fract(leaf * 13.7 + phase) > 0.6 + 0.4 * amount)) {
		discard;
	}
	// See-through around the player when the clump is nearer the viewer than them:
	// every other texel within SEE_THROUGH, one in four over a rim beyond it. Counted
	// in the world's texels, so the pattern does not crawl as the view moves.
	vec2 frag = screen_plane(center) + vec2((UV.x - 0.5) * clump_size, -(0.5 - UV.y) * clump_size * view_slope);
	vec2 body = screen_plane(player_pos + vec3(0.0, 0.5, 0.0));
	float near = length(frag - body);
	float toward = view_slope / view_squash;
	if (center.y - dot(center.xz, view_up) * toward > player_pos.y - dot(player_pos.xz, view_up) * toward + 1.0
			&& near < SEE_THROUGH + SEE_RIM) {
		if (bayer4(texel) < (near < SEE_THROUGH ? 0.5 : 0.25)) {
			discard;
		}
	}
	// The crown's normal, tilted by the leaf this texel belongs to; leaves flutter
	// on their own in the wind.
	vec2 tilt = berry ? vec2(0.0) : (m.gb * 2.0 - 1.0) * 0.5;
	tilt.x += sin(TIME * 2.3 + leaf * 6.28 + center.x * 0.7) * (0.04 + length(wind) * 0.3);
	vec3 n = normalize(custom.xyz + vec3(tilt.x, tilt.y, -tilt.y * 0.4));
	// Autumn colours differ from tree to tree; evergreens hardly change.
	vec3 season = foliage_tint * (1.0 + (hash12(floor(center.xz / 3.0) + 5.0) - 0.5) * (foliage_tint - 1.0) * vec3(0.5, 0.8, 1.0));
	season = evergreen ? mix(vec3(1.0), season, 0.15) : season;
	// Three tones of single leaves, and a lighter upper edge on each.
	float tone = 1.0 + (floor(fract(leaf * 5.31) * 3.0) - 1.0) * 0.04;
	vec3 col = tint.rgb * season * tone * (edge ? 1.06 : 1.0);
	if (branches) {
		col = vec3(0.3, 0.24, 0.2) * tone * (edge ? 1.15 : 1.0);
	}
	// Berries of a bush, each ripe or not by its own number; an unripe one is hidden
	// among the leaves. Green of the texture shades a berry from shine to shadow.
	if (berry && tint.a < 0.5) {
		vec3 ripe = berry_colors[clamp(int(round(tint.a * 10.0)) - 1, 0, 3)];
		if (ripe != vec3(0.0) && fract(leaf * 3.7) < berry_amount) {
			col = ripe * (m.g > 0.75 ? 1.45 : (m.g > 0.25 ? 1.0 : 0.72));
		}
	}
	// The underside of the crown is shaded by the crown itself whatever the sun does,
	// a step darker and cooler toward the bottom.
	float under = n.y;
	col *= under < -0.05 ? vec3(0.68, 0.76, 0.86) : vec3(1.0);
	// Snow lies on the leaves of the crown's top, on the upper half of the sprigs on top
	// of an evergreen's tiers, and on some bare twigs.
	float snowy = fract(leaf * 7.3);
	if (branches ? (edge && snowy < snow_amount * 0.4) :
			(evergreen ? under > 0.4 && UV.y < 0.5 && snowy < snow_amount * 1.1 : under > 0.5 && snowy < snow_amount * 1.2 - 0.1)) {
		col = vec3(0.73, 0.76, 0.82);
	}
	col *= 1.0 - 0.25 * wetness;
	vec4 veiled = veil(center, depth_fade(center.y));
	ALBEDO = col * (1.0 - veiled.a);
	EMISSION = veiled.rgb;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(center);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		// Four steps: a warm highlight where the crown faces the sun, full light, half
		// light, and a shade that still lets some sun through the leaves (the cool
		// ambient light adds the blue). A sun shadow (often of the crown's own upper
		// leaves, which a convex crown would not cast on its sunny side) or a cloud
		// takes one step off.
		float ndl = dot(NORMAL, sun_view);
		float shadow = min(step(0.5, ATTENUATION), step(0.99, clouds));
		float step_n = (ndl > 0.6 ? 3.0 : (ndl > 0.38 ? 2.0 : (ndl > 0.08 ? 1.0 : 0.0))) - (1.0 - shadow);
		vec3 band = step_n > 2.5 ? vec3(1.55, 1.45, 0.7) : (step_n > 1.5 ? vec3(1.0) : (step_n > 0.5 ? vec3(0.7) : vec3(0.32)));
		DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
	} else {
		DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, false, clouds, light_texel(light_xz));
	}
}
