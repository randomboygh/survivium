// The holes cut in the ice of frozen water and the ice a fire thaws round it (IceView,
// the user's ask of 2026-11-15): included after common.gdshaderinc by water.gdshader and
// sprite_water.gdshader (the fish under the ice), which IceView gives the same values.

// The holes near the view: xy the middle (world units), z 1 for an open one, 0.5 for one
// with a crust over it, 0 for none.
uniform vec4 ice_holes[8];
// Fires burning on or by the ice: xy where (world units), z how far round the frost and
// snow are melted off (world units), 0 for none.
uniform vec4 ice_thaw[4];

// The radius of a hole, and the ring of broken ice round it, in world units.
const float ICE_HOLE_R = 0.2;
const float ICE_RIM = 0.06;

// What of a hole is at `xz`: 1 its open water, 0.5 its crust, 0.25 its rim of broken ice,
// 0 none.
float ice_hole(vec2 xz) {
	float out_k = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 h = ice_holes[i];
		if (h.z <= 0.0) {
			continue;
		}
		float d = length(xz - h.xy);
		if (d < ICE_HOLE_R) {
			return h.z;
		}
		if (d < ICE_HOLE_R + ICE_RIM) {
			out_k = 0.25;
		}
	}
	return out_k;
}

// 1 where the ice at `xz` is clear and dark, the water under it seen: patches of it
// (about a fifth of the ice), and round a fire the heat thawed the frost off.
float ice_clear(vec2 xz) {
	vec2 t = floor(xz * TEXELS) / TEXELS;
	float clear = step(0.78, ground_patch(t, 41.0));
	for (int i = 0; i < 4; i++) {
		vec4 f = ice_thaw[i];
		if (f.z > 0.0 && length(t - f.xy) < f.z * (0.92 + 0.16 * hash12(floor(xz * TEXELS)))) {
			clear = 1.0;
		}
	}
	return clear;
}
