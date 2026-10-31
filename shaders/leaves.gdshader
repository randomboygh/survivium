// Tree crowns made of leaf bundle cards (MultiMesh, see foliage.gd), drawn after SLYNYRD's
// top-down trees: each card is one bundle of leaves whose texture bakes its own sphere
// shading (green = tone step, see PixelTextures._bundle), and the card as a whole is lit
// from the normal of the crown at its spot in four bands, from a warm yellow-green on the
// sunny side to a cool blue-green underneath, so bundles layer toward the light. Cards
// sway in whole pixels, thin out in winter, take snow on top, and turn see-through around
// the player when they hide them.
// INSTANCE_CUSTOM: xyz = normal of the crown at the card, w = row of the clump texture
// (whole part, plus 16 for the deep layer of a crown) + sway phase (fraction), negative
// for a card drawn in front of the trunk (a spruce's sprigs, the collar round a trunk in a crown).
// COLOR: tint of the tree; alpha what it does in winter (see Foliage): 1 keeps dry
// leaves under snow, 0.8 goes bare, 0.6 is evergreen, 0.1, 0.2.. a bush of type 0, 1..
// (see Foliage.bush_kind), whose berries are pixels of the texture marked in alpha.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, shadows_disabled;
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
// A bush (main.gd sets it in the bushes' copy of this shader): clears round the player
// as low things do (low_through).
const bool LOW_PLANT = false;
const float DEEP_BEHIND = 0.25;
// How much nearer the camera a flat bundle is drawn than it lies (in depth alone).
const float FLAT_AHEAD = 0.75;
// The first row of spruce branches in the clump texture (PixelTextures.NEEDLE_ROW).
const float NEEDLE_ROW = 3.0;
// Rows of the smaller and larger spruce branches (PixelTextures.SMALL_BRANCH_ROW..).
const float SMALL_BRANCH_ROW = 13.0;
const float UP_BRANCH_ROW = 14.0;
const float LARGE_BRANCH_ROW = 15.0;
// How deep a conifer's tier is drawn along the view, as a share of its width.
const float CONE_DEPTH = 0.45;
// How much of its colour a leaf keeps (1 all, 0 grey).
const float LEAF_SATURATION = 0.6;
// How much of the steps of its ramp a bundle keeps (1 all, 0 one flat colour).
const float LEAF_CONTRAST = 0.75;
// Rows of the clump texture, one per size of leaf bunch.
uniform int clump_rows = 1;
// How much of its square each row's pictures fill, from the middle out
// (PixelTextures.row_reach): a card is cut down to it, so the pixels round a small
// bundle cost nothing to draw; 0 (not set, the bushes) keeps the whole card.
uniform float row_reach[16];
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
	// The card cut down to what its row draws (a bare tree's deep layer may show the
	// branches instead).
	float row_in = mod(floor(abs(custom.w)), 32.0);
	bool deep_card = row_in >= 15.5;
	float reach = row_reach[int(row_in) - (deep_card ? 16 : 0)];
	if (deep_card && branch_row >= 0 && tint.a > 0.7 && tint.a < 0.9) {
		reach = max(reach, row_reach[branch_row]);
	}
	reach = reach > 0.0 ? reach : 1.0;
	VERTEX = center + (VERTEX - center) * reach;
	UV = 0.5 + (UV - 0.5) * reach;
	// A card whose normal is longer than 1 lies flat, a bundle of a layer of the crown
	// (Foliage._layer_cards): square to the screen whichever way the camera looks, its
	// depth along the view kept so the shear draws it at its size in pixels.
	bool flat_card = dot(custom.xyz, custom.xyz) > 2.0;
	vec2 away = vec2(0.0);
	if (flat_card) {
		custom.w = abs(custom.w);
	} else if (custom.w < 0.0) {
		away = -view_up * SPRIG_AHEAD;
		custom.w = -custom.w;
	} else if (tint.a >= 0.5 && mod(floor(custom.w), 32.0) >= 16.0) {
		away = view_up * DEEP_BEHIND;
	}
	center.xz += away;
	VERTEX.xz += away;
	float sway = sin(TIME * 1.1 + center.x * 0.4 + fract(custom.w) * 6.28) * (0.3 + length(wind) * 1.4);
	VERTEX.x += round(sway) / TEXELS;
	if (flat_card) {
		// A conifer's branch carries how far out from its trunk it lies in the length of
		// its normal beyond 2 (Foliage._spruce): its tier is drawn shallower along the
		// view than across it, the ring of branches an ellipse, as SLYNYRD draws a tree
		// seen from the side and above at once.
		float from_trunk = length(custom.xyz) - 2.0;
		if (from_trunk > 0.01) {
			center.xz -= view_up * dot(normalize(custom.xz), view_up) * from_trunk * (1.0 - CONE_DEPTH);
			center.xz = round(center.xz * TEXELS) / TEXELS;
		}
		vec2 r = vec2(-view_up.y, view_up.x);
		vec2 o = r * (UV.x - 0.5) * clump_size + view_up * (0.5 - UV.y) * clump_size / view_squash;
		float swayed = VERTEX.x - center.x - (UV.x - 0.5) * clump_size;
		VERTEX = shear(vec3(center.x + o.x + swayed, center.y, center.z + o.y));
		// Drawn nearer the camera than they lie (which leaves the picture as it is), so
		// the trunk running up through the layers never shows over them; and bundles of
		// one layer, in one plane, each a hair nearer or farther by its own number.
		VERTEX.y += FLAT_AHEAD + fract(custom.w) * 0.04;
	} else {
		VERTEX = shear(stand_tall(face_view(VERTEX, center), center));
	}
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
	// A flat card of needles is a spruce branch pointing away from the trunk the way
	// its normal leans, as it shows on the screen (PixelTextures._spruce_branch, eight
	// ways in two rows); a card on the trunk's line takes the tuft of a tip.
	bool sized = row > SMALL_BRANCH_ROW - 0.5;
	bool needle_branch = dot(custom.xyz, custom.xyz) > 2.0 && !branches
		&& (row > NEEDLE_ROW - 0.5 && row < NEEDLE_ROW + 1.5 || sized);
	float u = UV.x;
	if (needle_branch) {
		vec2 outward = custom.xz;
		vec2 screen = vec2(dot(outward, vec2(-view_up.y, view_up.x)), -dot(outward, view_up));
		if (length(outward) < 0.2) {
			// On the trunk's line: a tuft, or the small branch up at the very tip.
			bool up = row > UP_BRANCH_ROW - 0.5 && row < UP_BRANCH_ROW + 0.5;
			row = up ? UP_BRANCH_ROW : NEEDLE_ROW + 2.0;
			variant = up ? 0.0 : variant;
		} else {
			// Branches droop: seen from above at 3/4 none points up the screen but at the
			// top, the ones behind lie to the sides.
			screen = normalize(screen) + vec2(0.0, 0.4);
			float way = mod(round(atan(screen.y, screen.x) / (TAU / 8.0)), 8.0);
			if (sized) {
				// The small and large branches point four ways, mirrored for the left
				// (PixelTextures.BRANCH_WAYS), and up.
				bool large = row > LARGE_BRANCH_ROW - 0.5;
				if (way > 2.5 && way < 5.5) {
					way = mod(4.0 - way + 8.0, 8.0);
					u = 1.0 - u;
				}
				if (way > 5.5 && way < 6.5) {
					row = UP_BRANCH_ROW;
					variant = large ? 1.0 : 0.0;
				} else {
					row = large ? LARGE_BRANCH_ROW : SMALL_BRANCH_ROW;
					variant = way > 6.5 ? 3.0 : way;
				}
			} else {
				row = NEEDLE_ROW + floor(way / 4.0);
				variant = mod(way, 4.0);
			}
		}
	}
	vec4 m = texture(clump_texture, vec2((variant + u) / 4.0, (row + UV.y) / float(clump_rows)));
	// The pixel of the picture this is, the same for every card over it whatever its
	// sway or offset, so the dithers of the cards lying one over another leave out the
	// same pixels instead of filling each other's gaps.
	vec2 texel = light_texel(light_xz);
	if (m.a < 0.5 || cut_hides(center, texel)) {
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
	if (bayer4(texel) < (LOW_PLANT ? low_through(texel, center) : see_through(texel, center))) {
		discard;
	}
	// The card is lit as a whole by the crown's normal at its spot (see light), so each
	// bundle of leaves takes one step of the light; inside it, the light baked into the
	// bundle (green: crevices, shade, body, lit edges) gives steps of one ramp, darker
	// steps cooler, the lit one warmer (hue_shift).
	vec3 n = normalize(custom.xyz);
	// Autumn colours differ from tree to tree; evergreens hardly change.
	vec3 season = foliage_tint * (1.0 + (hash12(floor(center.xz / 3.0) + 5.0) - 0.5) * (foliage_tint - 1.0) * vec3(0.5, 0.8, 1.0));
	season = evergreen ? mix(vec3(1.0), season, 0.15) : season;
	// Steps of the tree's ramp below or above its own colour (PixelTextures._tone_px:
	// BUNDLE_DARKEST -4 .. BUNDLE_LIGHTEST 1), the darks cooler, toward blue.
	float off = berry ? 0.0 : round(m.g * 5.0) - 4.0;
	// The darkest step is the rim of the leaves, kept soft: a little under the shade.
	vec3 tone = off < -3.5 ? vec3(0.45, 0.55, 0.8) : (off < -2.5 ? vec3(0.53, 0.64, 0.92) :
		(off < -1.5 ? vec3(0.78, 0.88, 1.05) : (off < -0.5 ? vec3(1.0) :
		(off < 0.5 ? vec3(1.25, 1.22, 1.0) : vec3(1.6, 1.52, 1.05)))));
	tone = mix(vec3(dot(tone, vec3(0.333))), tone, hue_shift);
	tone = mix(vec3(1.0), tone, LEAF_CONTRAST);
	vec3 col = tint.rgb * season * tone;
	// Toned down toward grey to sit with the grass and the ground.
	col = mix(vec3(dot(col, vec3(0.3, 0.55, 0.15))), col, LEAF_SATURATION);
	if (branches) {
		col = vec3(0.3, 0.24, 0.2) * (edge ? 1.15 : 1.0);
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
		col = blossom_colors[int(bloom)] * mix(vec3(1.0), tone, 0.6);
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
	// A conifer's branches turned from the sun sink toward indigo, as SLYNYRD's dark
	// branches do: the sides of a cone part into light and shade more than a crown's.
	if (needle_branch) {
		float sun_side = dot(normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz), sun_view);
		col *= mix(mix(vec3(0.7), vec3(0.6, 0.62, 0.86), hue_shift), vec3(1.0), smoothstep(-0.35, 0.15, sun_side));
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
		// Steps a notch of the ramp apart (the dark, middle and light variants of a
		// bundle, SLYNYRD), the half light and the shade cooler.
		vec3 half_light = mix(vec3(0.8), vec3(0.74, 0.82, 0.96), hue_shift);
		vec3 shade = mix(vec3(0.5), vec3(0.42, 0.48, 0.74), hue_shift);
		vec3 band = step_n > 2.5 ? mix(vec3(1.4), vec3(1.46, 1.4, 0.98), hue_shift) : (step_n > 1.5 ? vec3(1.0) : (step_n > 0.5 ? half_light : shade));
		DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
	} else {
		DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, false, clouds, light_texel(light_xz),
			light_stretch(INV_VIEW_MATRIX, LIGHT));
	}
}
