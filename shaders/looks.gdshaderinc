// A player's looks (Figure.paint, player.yaml `looks`): the figure's pictures are drawn
// in the default look's colours, and each of those (the skin's, the hair's, the iris and
// what is made of them) is swapped here for the colour picked. The colours come as whole
// sRGB 0..255, as the picture is read (a source_color texture read as it is, see
// common.gdshaderinc), so a pixel matches exactly. Material uniforms: instance uniforms
// read as 0 in the web build. Every other sprite leaves swap_count at 0.
const int SWAPS_MAX = 12;
uniform int swap_count = 0;
uniform vec3 swap_from[12];
uniform vec3 swap_to[12];

vec3 looks_swap(vec3 c) {
	if (swap_count == 0) {
		return c;
	}
	vec3 k = floor(c * 255.0 + 0.5);
	for (int i = 0; i < SWAPS_MAX; i++) {
		if (i >= swap_count) {
			break;
		}
		if (all(equal(k, swap_from[i]))) {
			return swap_to[i] / 255.0;
		}
	}
	return c;
}
