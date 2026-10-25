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
// (whole part, plus 16 for the deep layer of a crown) + sway phase (fraction), negative
// for a sprig drawn in front of a spruce's trunk.
// COLOR: tint of the tree; alpha what it does in winter (see Foliage): 1 keeps dry
// leaves under snow, 0.8 goes bare, 0.6 is evergreen, 0.1, 0.2.. a bush of type 0, 1..
// (see Foliage.bush_kind), whose berries are pixels of the texture marked in alpha.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
// Crowns clear round the player (see see_through), so the player's silhouette (see
// sprite_xray) does not show behind them (3); bushes use a copy that marks them low
// (see main.low_variant).
stencil_mode write, compare_always, 3;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D clump_texture : filter_nearest;
uniform float clump_size = 1.5;
// How far a sprig is drawn in front of a spruce's trunk, and the deep layer of a crown
// behind its outer cards, toward or away from the camera whichever way it looks.
const float SPRIG_AHEAD = 0.4375;
const float DEEP_BEHIND = 0.25;
// Rows of the clump texture, one per size of leaf bunch.
uniform int clump_rows = 1;
// Row of bare branches, which the deep layer of a bare tree shows in winter; -1 for none.
uniform int branch_row = -1;
// How far the half light and the shade of the crowns lean cool (toward blue and violet),
// as pixel artists shift the hue of shadows; 0 keeps them grey.
uniform float hue_shift = 1.0;
// Colours of ripe berries by bush type (see Bushes), black for none.
uniform vec3 berry_colors[4];
// Share of the berries ripe, by season.
global uniform float berry_amount;
// Colours of blossom by slot (Trees.blossom_slot, from 1), and how much of it is out:
// the trees blossom in spring.
uniform vec3 blossom_colors[8];
global uniform float blossom_amount;

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
	vec2 away = vec2(0.0);
	if (custom.w < 0.0) {
		away = -view_up * SPRIG_AHEAD;
		custom.w = -custom.w;
	} else if (tint.a >= 0.5 && mod(floor(custom.w), 32.0) >= 16.0) {
		away = view_up * DEEP_BEHIND;
	}
	center.xz += away;
	VERTEX.xz += away;
	float sway = sin(TIME * 1.1 + center.x * 0.4 + fract(custom.w) * 6.28) * (0.3 + length(wind) * 1.4);
	VERTEX.x += round(sway) / TEXELS;
	VERTEX = shear(stand_tall(face_view(VERTEX, center), center));
	light_xz = VERTEX.xz;
}

void fragment() {
	float phase = fract(custom.w);
	float variant = floor(phase * 4.0);
	float row = floor(custom.w);
	// Every 32 rows up, the next colour of blossom (0 none).
	float bloom = floor(row / 32.0);
	row -= bloom * 32.0;
	bool deep = row >= 15.5;
	row -= deep ? 16.0 : 0.0;
	bool evergreen = tint.a > 0.5 && tint.a < 0.7;
	float amount = leaves_left(tint.a);
	// A bare tree's deep layer shows its branches.
	bool branches = deep && amount < 0.01 && branch_row >= 0;
	if (branches) {
		row = float(branch_row);
	}
	vec4 m = texture(clump_texture, vec2((variant + UV.x) / 4.0, (row + UV.y) / float(clump_rows)));
	// The pixel of the picture this is, the same for every card over it whatever its
	// sway or offset, so the dithers of the cards lying one over another leave out the
	// same pixels instead of filling each other's gaps.
	vec2 texel = light_texel(light_xz);
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
	// See-through around the player when the clump is nearer the viewer than them.
	if (bayer4(texel) < see_through(texel, center)) {
		discard;
	}
	// The crown's normal, tilted by the leaf this texel belongs to; leaves flutter
	// on their own in the wind.
	vec2 tilt = berry ? vec2(0.0) : (m.gb * 2.0 - 1.0) * 0.5;
	tilt.x += sin(TIME * 2.3 + leaf * 6.28 + center.x * 0.7) * (0.04 + length(wind) * 0.3);
	vec2 r = vec2(-view_up.y, view_up.x);
	vec3 n = normalize(custom.xyz + vec3(r.x * tilt.x + view_up.x * tilt.y * 0.4, tilt.y, r.y * tilt.x + view_up.y * tilt.y * 0.4));
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
	// Blossom over most of the leaves in spring, lit like them; a leaf blossoms by its
	// own number, so the flowers come out and drop one by one.
	if (bloom > 0.5 && !branches && !berry && fract(leaf * 9.13 + 0.3) < blossom_amount * 0.75) {
		col = blossom_colors[int(bloom)] * tone * (edge ? 1.08 : 1.0);
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
		vec3 half_light = mix(vec3(0.7), vec3(0.6, 0.7, 0.82), hue_shift);
		vec3 shade = mix(vec3(0.32), vec3(0.25, 0.27, 0.45), hue_shift);
		vec3 band = step_n > 2.5 ? mix(vec3(1.55, 1.45, 0.7), vec3(1.6, 1.5, 0.62), hue_shift) : (step_n > 1.5 ? vec3(1.0) : (step_n > 0.5 ? half_light : shade));
		DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
	} else {
		DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, false, clouds, light_texel(light_xz));
	}
}
