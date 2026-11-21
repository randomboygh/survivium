// A player's looks (Figure.paint, player.yaml `looks`): the figure's pictures are drawn
// in the default look's colours, and each of those (the skin's, the hair's, the iris and
// what is made of them) is swapped here for the colour picked. The colours come as whole
// sRGB 0..255, as the picture is read (a source_color texture read as it is, see
// common.gdshaderinc), so a pixel matches exactly. Material uniforms: instance uniforms
// read as 0 in the web build. Every other sprite leaves swap_count at 0 (and has no key
// colours).
const int SWAPS_MAX = 12;
uniform int swap_count = 0;
uniform vec3 swap_from[12];
uniform vec3 swap_to[12];

// Clothes that can be dyed are drawn in key colours (Figure.dye_key): red 254, blue 1 and
// green the slot's number times three plus the shade (light, middle, dark), each taking
// the colour of dye_to at that number: the dye's shades, or the thing's own cloth.
const int DYE_KEYS = 21;
uniform vec3 dye_to[21];

vec3 looks_swap(vec3 c) {
	vec3 k = floor(c * 255.0 + 0.5);
	if (k.r == 254.0 && k.b == 1.0 && k.g < float(DYE_KEYS)) {
		return dye_to[int(k.g)] / 255.0;
	}
	if (swap_count == 0) {
		return c;
	}
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
