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
		vec2 cc = sp - 0.5;
		sp = 0.5 + cc * (1.0 + crt_curve * dot(cc, cc) * 4.0) / (1.0 + crt_curve);
		vec2 out_px = min(sp, 1.0 - sp) * crt_screen.xy;
		edge = clamp(min(out_px.x, out_px.y) / 2.0, 0.0, 1.0);
		vec2 read = sp;
		if (crt_jitter > 0.0) {
			// Rows of two screen pixels wander sideways, a little each frame and in a slow wave.
			float line = floor(sp.y * crt_screen.y / 2.0);
			float frame = floor(TIME * 30.0);
			read.x += (crt_hash(vec2(line, frame)) - 0.5) * crt_jitter + sin(sp.y * 37.0 + TIME * 2.3) * crt_jitter * 0.6;
			// The torn band near the bottom: rows thrown far aside and snow.
			float band_y = 0.93 + 0.03 * sin(TIME * 0.7);
			float in_band = 1.0 - smoothstep(0.0, 0.02, abs(sp.y - band_y));
			read.x += in_band * crt_band * (crt_hash(vec2(line, frame + 7.0)) - 0.3) * 0.03;
			band = in_band * crt_band;
		}
		uv = (read * crt_screen.xy - crt_screen.zw) / picture;
		float off = crt_rgb * crt_screen.x / picture.x;
		src = vec3(texture(TEXTURE, uv + vec2(off, 0.0)).r, texture(TEXTURE, uv).g, texture(TEXTURE, uv - vec2(off, 0.0)).b);
		if (crt_bleed > 0.0) {
			// Colour smeared to the right along the row; the brightness stays sharp.
			float b = crt_bleed * crt_screen.x / picture.x;
			vec3 smear = (texture(crt_view, uv - vec2(b, 0.0)).rgb * 2.0 + texture(crt_view, uv - vec2(b * 2.0, 0.0)).rgb
				+ texture(crt_view, uv).rgb) / 4.0;
			vec3 w = vec3(0.299, 0.587, 0.114);
			src = clamp(vec3(dot(src, w)) + smear - vec3(dot(smear, w)), 0.0, 1.0);
		}
	} else {
		src = texture(TEXTURE, uv).rgb;
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
	if (crt_on) {
		c += crt_bloom(uv, TEXTURE_PIXEL_SIZE) * crt_glow * exposure * tint;
		// Scanlines, every other one darker by turns (interlace), on the screen's rows.
		float row = sp.y * crt_lines;
		float s = sin(row * 3.14159265);
		c *= 1.0 - crt_scan * s * s;
		c *= 1.0 - crt_interlace * float(mod(floor(row) + crt_field, 2.0) < 1.0);
		// The phosphor stripes: each screen column lights its own colour best.
		float col = mod(floor(sp.x * crt_screen.x), 3.0);
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
