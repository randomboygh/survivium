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
// Sun rays in the air (god rays): how bright, the way they run on the image, their
// colour, where on the top edge of the image (0 left .. 1 right) the middle of their fan
// crosses it, and
// the seconds that make them breathe.
uniform float rays_amount = 0.0;
uniform vec2 rays_dir = vec2(0.0, 1.0);
uniform vec3 rays_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float rays_anchor = 1.0;
uniform float rays_time = 0.0;
// The world pixel at the top left of the image, so the banks stay on the ground as
// the view moves.
uniform vec2 view_origin = vec2(0.0);
global uniform sampler2D cloud_noise : filter_linear, repeat_enable;
global uniform vec2 cloud_offset;
global uniform float cloud_cover;

void fragment() {
	vec3 src = texture(TEXTURE, UV).rgb;
	vec3 c = src * exposure;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c = c * tint + shadow_tint * (1.0 - clamp(l * 1.6, 0.0, 1.0));
	c = mix(c, src * exposure, smoothstep(0.3, 0.75, l) * keep_highlights);
	vec2 px = floor(view_origin + UV / TEXTURE_PIXEL_SIZE);
	ivec2 b = ivec2(mod(px, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	float dither = (float(m[b.y * 4 + b.x]) + 0.5) / 16.0 - 0.5;
	if (rays_amount > 0.0) {
		// The shafts hang still on the image on the sun's side and run from the top
		// to the ground, fanning out a little from a point high above the image.
		// They are told apart by their angle from that point: noise read along the
		// angle gives wide and thin shafts with soft edges.
		vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 q = floor(UV * size);
		float lift = size.y * 1.4;
		vec2 from = vec2(rays_anchor * size.x - rays_dir.x / rays_dir.y * lift, -lift);
		vec2 v = q - from;
		float ang = atan(v.x, v.y) - atan(rays_dir.x, rays_dir.y);
		float s = ang * lift;
		// Full along the middle of the fan, gone 0.4 radians off it.
		float side = clamp(1.0 - abs(ang) / 0.4, 0.0, 1.0);
		float n = texture(cloud_noise, vec2(s / 150.0, 0.13)).r * 0.6
			+ texture(cloud_noise, vec2(s / 38.0, 0.61)).r * 0.4;
		// Each shaft breathes in its own time: it widens and narrows, brightens and
		// fades.
		float phase = texture(cloud_noise, vec2(s / 70.0, 0.37)).r * 12.0;
		float th = 0.5 - 0.05 * sin(rays_time * 0.4 + phase);
		float shaft = smoothstep(th, th + 0.05, n) * 0.6 + smoothstep(th + 0.06, th + 0.1, n) * 0.4;
		shaft *= (0.7 + 0.3 * sin(rays_time * 0.27 + phase * 1.7)) * smoothstep(0.0, 0.6, side);
		// Only where the sun gets through the clouds (the ground's cloud_light, read
		// at the ground under the pixel): through the gaps as the clouds break up.
		float cloud = texture(cloud_noise, (px / 16.0 + cloud_offset) / 96.0).r;
		float sunlit = 1.0 - smoothstep(-0.12, 0.04, cloud - (1.0 - cloud_cover));
		// A soft glow of the lit air in the fan. Brightest at the top, fading down.
		float glow = 0.4 * side * side;
		float k = (shaft + glow) * (1.0 - 0.55 * UV.y) * sunlit * rays_amount;
		// Light added in the air: screen blend, so bright ground does not burn out.
		c = 1.0 - (1.0 - c) * (1.0 - rays_color * k);
	}
	if (haze_amount > 0.0) {
		// Banks from two layers of noise, in whole pixels, with a dithered edge.
		vec2 p = px / 16.0 + haze_offset;
		float n = texture(cloud_noise, p / 40.0).r * 0.65 + texture(cloud_noise, p / 13.0 + 0.37).r * 0.35;
		float bank = clamp((n - 0.35) * 3.0 + dither * 0.25, 0.0, 1.0);
		float k = haze_amount * mix(1.0, floor(bank * 4.0 + 0.5) / 4.0, haze_patchy);
		c = mix(c, haze_color, k);
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
