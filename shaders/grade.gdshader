// Colour grade of the whole picture: one place that sets the mood of the time of
// day, season, weather and biome. Applied to the low-res image before upscaling.
shader_type canvas_item;

uniform float exposure = 1.0;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 shadow_tint : source_color = vec3(0.0);
// How much bright pixels (fire, lamps) keep their own colour instead of the grade.
uniform float keep_highlights = 0.0;
// Fog, blizzard or sand haze over the picture: its colour, how thick it is, how much
// it lies in banks (0 even, 1 only in banks), and how far the banks have drifted.
uniform vec3 haze_color : source_color = vec3(0.6);
uniform float haze_amount = 0.0;
uniform float haze_patchy = 0.7;
uniform vec2 haze_offset = vec2(0.0);
// The world pixel at the top left of the image, so the banks stay on the ground as
// the view moves.
uniform vec2 view_origin = vec2(0.0);
// Short of sleep (CameraRig.drowsiness), 0..1: the picture swims in slow waves, a
// faint second image drifts off it, and the edges darken as if the eyes were closing.
uniform float sway = 0.0;
// Visions after a glowing mushroom (CameraRig.visions), 0..1: the picture swims harder
// and breathes, rings ripple out from the middle, the colours split apart and run round
// the wheel in waves, and the edges glow the mushrooms' teal and violet.
uniform float trip = 0.0;
global uniform sampler2D cloud_noise : filter_linear, repeat_enable;
global uniform vec2 cloud_offset;
global uniform float cloud_cover;
// The old screen look (src/client/view/crt.gd, setting «Кинескоп»), off unless crt_on.
// crt_screen: the screen's size and the picture's top left corner on it; crt_scale:
// screen pixels to a picture pixel. crt_view is the picture again, filtered, for glow.
uniform bool crt_on = false;
uniform sampler2D crt_view : filter_linear;
uniform vec4 crt_screen = vec4(1.0);
uniform float crt_scale = 1.0;
uniform float crt_field = 0.0;
uniform float crt_scan = 0.0;
uniform float crt_lines = 400.0;
uniform float crt_interlace = 0.0;
uniform float crt_glow = 0.0;
uniform float crt_threshold = 1.0;
uniform float crt_rgb = 0.0;
uniform float crt_curve = 0.0;
uniform float crt_vignette = 0.0;
uniform float crt_flicker = 0.0;
uniform float crt_mask = 0.0;
// The bright bar rolling down the screen; the tape's look: rows jittering sideways (a
// share of the screen's width), colour smeared along the rows, the torn band of
// interference near the bottom, and noise.
uniform float crt_roll = 0.0;
uniform float crt_jitter = 0.0;
uniform float crt_bleed = 0.0;
uniform float crt_band = 0.0;
uniform float crt_noise = 0.0;

// How far, in picture pixels, the waves of a sleepy eye move the pixel at screen point
// `sp` (0..1): slow sines across and along, crossing, so nothing moves in step.
vec2 sway_shift(vec2 sp) {
	float t = TIME;
	vec2 w = vec2(sin(sp.y * 9.0 + t * 1.3) + 0.6 * sin(sp.y * 23.0 - t * 2.1 + sp.x * 5.0),
		sin(sp.x * 7.0 - t * 1.1) * 0.6 + 0.4 * sin(sp.x * 19.0 + t * 1.7));
	vec2 shift = w * (sway * 1.6 + trip * 2.6);
	if (trip > 0.0) {
		// Rings running out from the middle push the picture in and out.
		vec2 c = sp - 0.5;
		float r = length(c);
		shift += c / max(r, 0.001) * sin(r * 18.0 - t * 2.4) * trip * 1.2;
	}
	return shift;
}

// Turns colour `c` round the colour wheel by `a` radians, keeping its brightness.
vec3 hue_turn(vec3 c, float a) {
	vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

float crt_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// The bright part of the picture around `uv`, blurred: eight filtered taps on two rings.
vec3 crt_bloom(vec2 uv, vec2 texel) {
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398 + (i >= 4 ? 0.392699 : 0.0);
		float r = i >= 4 ? 3.0 : 1.5;
		vec3 s = texture(crt_view, uv + vec2(cos(a), sin(a)) * r * texel).rgb;
		float l = max(s.r, max(s.g, s.b));
		sum += s * smoothstep(crt_threshold, 1.0, l);
	}
	return sum / 8.0 * 0.5;
}

void fragment() {
	vec2 uv = UV;
	// Where this pixel is on the screen, 0..1.
	vec2 picture = crt_scale / TEXTURE_PIXEL_SIZE;
	vec2 sp = (crt_screen.zw + UV * picture) / crt_screen.xy;
	float edge = 1.0;
	float band = 0.0;
	vec3 src;
	if (crt_on) {
		// The tube's curve: the middle swells, the corners bend away and go black.
		// Offsets go by the screen's long side, the same either way the phone is held; the
		// bend goes by the diagonal (a corner at 0.5 as on a square), so it is round.
		float long_side = max(crt_screen.x, crt_screen.y);
		vec2 cc = sp - 0.5;
		vec2 cn = cc * crt_screen.xy / length(crt_screen.xy) * 1.41421;
		sp = 0.5 + cc * (1.0 + crt_curve * dot(cn, cn) * 4.0) / (1.0 + crt_curve);
		vec2 out_px = min(sp, 1.0 - sp) * crt_screen.xy;
		edge = clamp(min(out_px.x, out_px.y) / 2.0, 0.0, 1.0);
		vec2 read = sp;
		if (sway > 0.0 || trip > 0.0) {
			read += sway_shift(sp) / picture;
		}
		if (crt_jitter > 0.0) {
			// Rows of two screen pixels wander sideways, a little each frame and in a slow wave.
			float line = floor(sp.y * crt_screen.y / 2.0);
			float frame = floor(TIME * 30.0);
			float jit = crt_jitter * long_side / crt_screen.x;
			read.x += (crt_hash(vec2(line, frame)) - 0.5) * jit + sin(sp.y * 37.0 + TIME * 2.3) * jit * 0.6;
			// The torn band near the bottom: rows thrown far aside and snow.
			float band_y = 0.93 + 0.03 * sin(TIME * 0.7);
			float in_band = 1.0 - smoothstep(0.0, 0.02, abs(sp.y - band_y));
			read.x += in_band * crt_band * (crt_hash(vec2(line, frame + 7.0)) - 0.3) * 0.03 * long_side / crt_screen.x;
			band = in_band * crt_band;
		}
		uv = (read * crt_screen.xy - crt_screen.zw) / picture;
		float off = crt_rgb * long_side / picture.x;
		src = vec3(texture(TEXTURE, uv + vec2(off, 0.0)).r, texture(TEXTURE, uv).g, texture(TEXTURE, uv - vec2(off, 0.0)).b);
		if (crt_bleed > 0.0) {
			// Colour smeared to the right along the row; the brightness stays sharp.
			float b = crt_bleed * long_side / picture.x;
			vec3 smear = (texture(crt_view, uv - vec2(b, 0.0)).rgb * 2.0 + texture(crt_view, uv - vec2(b * 2.0, 0.0)).rgb
				+ texture(crt_view, uv).rgb) / 4.0;
			vec3 w = vec3(0.299, 0.587, 0.114);
			src = clamp(vec3(dot(src, w)) + smear - vec3(dot(smear, w)), 0.0, 1.0);
		}
	} else {
		if (sway > 0.0 || trip > 0.0) {
			uv += sway_shift(sp) * TEXTURE_PIXEL_SIZE;
		}
		if (trip > 0.0) {
			// The picture breathes: it swells and shrinks slowly round the middle.
			uv = 0.5 + (uv - 0.5) * (1.0 - trip * 0.025 * (0.5 + 0.5 * sin(TIME * 0.8)));
		}
		src = texture(TEXTURE, uv).rgb;
	}
	if (sway > 0.0) {
		// The second image, a few pixels off and wandering, comes and goes.
		vec2 off = vec2(sin(TIME * 0.7), cos(TIME * 0.53)) * (1.5 + 2.5 * sway) * TEXTURE_PIXEL_SIZE;
		float ghost = sway * (0.22 + 0.13 * sin(TIME * 0.9));
		src = mix(src, texture(TEXTURE, uv + off).rgb, ghost);
	}
	if (trip > 0.0) {
		// Red and blue drift apart round the picture, and a second image, turned along
		// the colour wheel, wanders the other way.
		float a = TIME * 0.9;
		vec2 split = vec2(cos(a), sin(a)) * trip * (1.0 + 1.0 * sin(TIME * 1.3)) * TEXTURE_PIXEL_SIZE;
		src = vec3(texture(TEXTURE, uv + split).r, src.g, texture(TEXTURE, uv - split).b);
		vec2 off = vec2(sin(TIME * 0.45 + 2.0), cos(TIME * 0.61)) * 5.0 * trip * TEXTURE_PIXEL_SIZE;
		src = mix(src, hue_turn(texture(TEXTURE, uv - off).rgb, 2.1), trip * (0.18 + 0.07 * sin(TIME * 1.1)));
	}
	vec3 c = src * exposure;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c = c * tint + shadow_tint * (1.0 - clamp(l * 1.6, 0.0, 1.0));
	c = mix(c, src * exposure, smoothstep(0.3, 0.75, l) * keep_highlights);
	vec2 px = floor(view_origin + uv / TEXTURE_PIXEL_SIZE);
	ivec2 b = ivec2(mod(px, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	float dither = (float(m[b.y * 4 + b.x]) + 0.5) / 16.0 - 0.5;
	if (haze_amount > 0.0) {
		// Banks from two layers of noise, in whole pixels, with a dithered edge.
		vec2 p = px / 16.0 + haze_offset;
		float n = texture(cloud_noise, p / 40.0).r * 0.65 + texture(cloud_noise, p / 13.0 + 0.37).r * 0.35;
		float bank = clamp((n - 0.35) * 3.0 + dither * 0.25, 0.0, 1.0);
		float k = haze_amount * mix(1.0, floor(bank * 4.0 + 0.5) / 4.0, haze_patchy);
		c = mix(c, haze_color, k);
	}
	if (sway > 0.0) {
		// The eyelids: the edges darken and lift again, slowly, more the more tired.
		vec2 shape = vec2(crt_screen.x / crt_screen.y, 1.0);
		float d = length((sp - 0.5) * shape) / length(shape * 0.5);
		float lids = sway * (0.45 + 0.25 * sin(TIME * 0.6));
		c *= 1.0 - lids * smoothstep(0.35, 1.05, d);
	}
	if (trip > 0.0) {
		// The colours run round the wheel in waves from the middle and grow richer; the
		// edges glow, teal to violet and back.
		vec2 shape = vec2(crt_screen.x / crt_screen.y, 1.0);
		float d = length((sp - 0.5) * shape) / length(shape * 0.5);
		float turn = 0.25 * sin(TIME * 0.3) + 0.4 * sin(d * 7.0 - TIME * 1.5 + sp.x * 3.0);
		c = hue_turn(c, turn * trip);
		float cl = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(vec3(cl), c, 1.0 + 0.45 * trip);
		vec3 glow = mix(vec3(0.25, 0.95, 0.8), vec3(0.75, 0.35, 1.0), 0.5 + 0.5 * sin(TIME * 0.7));
		c = mix(c, glow, trip * (0.28 + 0.1 * sin(TIME * 1.7)) * smoothstep(0.5, 1.1, d));
	}
	if (crt_on) {
		c += crt_bloom(uv, TEXTURE_PIXEL_SIZE) * crt_glow * exposure * tint;
		// Scanlines, every other one darker by turns (interlace), on the screen's rows.
		float row = sp.y * crt_lines;
		float s = sin(row * 3.14159265);
		c *= 1.0 - crt_scan * s * s;
		c *= 1.0 - crt_interlace * float(mod(floor(row) + crt_field, 2.0) < 1.0);
		// The phosphor stripes: each column lights its own colour best; a stripe is wider
		// on a dense screen (a phone), else it is too fine to see.
		float stripe = max(1.0, floor(max(crt_screen.x, crt_screen.y) / 1100.0 + 0.5));
		float col = mod(floor(sp.x * crt_screen.x / stripe), 3.0);
		vec3 mask = vec3(1.0 - crt_mask);
		mask[int(col)] = 1.0;
		c *= mask * (1.0 + crt_mask * 0.6);
		vec2 cc = sp - 0.5;
		// Dark corners: 0 in the middle, 1 in a corner, by the screen's shape.
		vec2 shape = vec2(crt_screen.x / crt_screen.y, 1.0);
		float d = length(cc * shape) / length(shape * 0.5);
		c *= 1.0 - crt_vignette * smoothstep(0.3, 1.0, d);
		c *= 1.0 + crt_flicker * (sin(TIME * 71.0) + sin(TIME * 23.0) * 0.6);
		// The bright bar rolling slowly down.
		float bar = fract(sp.y - TIME * 0.06) - 0.5;
		c *= 1.0 + crt_roll * exp(-bar * bar * 60.0);
		float grain = crt_hash(floor(sp * crt_screen.xy / 2.0) + fract(TIME) * 91.0) - 0.5;
		c += grain * (crt_noise + band * 0.5);
		c *= edge;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
