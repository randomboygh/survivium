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

void fragment() {
	vec3 src = texture(TEXTURE, UV).rgb;
	vec3 c = src * exposure;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c = c * tint + shadow_tint * (1.0 - clamp(l * 1.6, 0.0, 1.0));
	c = mix(c, src * exposure, smoothstep(0.3, 0.75, l) * keep_highlights);
	if (haze_amount > 0.0) {
		// Banks from two layers of noise, in whole pixels, with a dithered edge.
		vec2 px = floor(view_origin + UV / TEXTURE_PIXEL_SIZE);
		vec2 p = px / 16.0 + haze_offset;
		float n = texture(cloud_noise, p / 40.0).r * 0.65 + texture(cloud_noise, p / 13.0 + 0.37).r * 0.35;
		ivec2 b = ivec2(mod(px, 4.0));
		int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
		float dither = (float(m[b.y * 4 + b.x]) + 0.5) / 16.0 - 0.5;
		float bank = clamp((n - 0.35) * 3.0 + dither * 0.25, 0.0, 1.0);
		float k = haze_amount * mix(1.0, floor(bank * 4.0 + 0.5) / 4.0, haze_patchy);
		c = mix(c, haze_color, k);
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
