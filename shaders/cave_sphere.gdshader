// The section of the rock on the far half of the sphere round the player (setting «Вид
// в пещере» → «сфера», CaveSphere): drawn on the inside of a sphere mesh that already
// stands in the drawn, sheared space (not sheared again), so it is round on the screen.
// Where the sphere passes through rock, or through another cave the player cannot
// reach from where they stand, it shows stone in dots; where it passes through the
// cave they are in, nothing, and the world beyond shows.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

varying vec3 drawn;

void vertex() {
	drawn = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The shear is linear: undone on a point as on a way.
	vec3 p = unshear_dir(drawn);
	if (reached_cell(floor(p / CELL))) {
		discard;
	}
	vec2 st = floor(screen_plane(p) * TEXELS);
	// Darker deeper under the player's feet, a little lighter toward the rim, in dots.
	float below = clamp((sphere_view.z - p.y) / max(sphere_cell.w, 0.5), -1.0, 1.0);
	vec3 rock = vec3(0.36, 0.34, 0.33) * (1.0 - 0.3 * max(below, 0.0));
	float speck = hash12(floor(p.xz * TEXELS) + floor(p.y * TEXELS) * 17.0);
	ALBEDO = rock * (bayer4(st) < 0.5 ? 1.0 : 0.82) * (speck > 0.9 ? 0.8 : 1.0);
}
