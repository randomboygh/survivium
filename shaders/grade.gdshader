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
// A heartbeat at low health (BodyFeedback._dark_picture), 0..1: the picture goes darker
// and harsher for the moment of the beat.
uniform float heart = 0.0;
// A death (DeathFx): which look of DeathFx.LOOKS (1-based, 0 none), how far it has come
// in, 0..1, its seconds, the body's middle in world pixels, and a light over it (x, y in
// world pixels, z how strong) for the looks that have one.
uniform int death_look = 0;
uniform float death_mix = 0.0;
uniform float death_time = 0.0;
uniform vec2 death_at = vec2(0.0);
uniform vec3 death_light = vec3(0.0);
// Asleep (CameraRig.dream), 0..1: bright things glow out round themselves, the colours
// sink halfway into a pale blue of one hue, the picture darkens towards a deep blue, and
// the edges blur and darken, the middle (the sleeper) staying sharp.
uniform float dream = 0.0;
// The air trembling over the fires nearest the view (AirEffects): each spot is the
// flames' base in pixels of the picture, how far the trembling reaches to each side and
// how high over them, in pixels; heat_power how strongly each fire burns (0 none).
uniform vec4 heat_spots[4];
uniform vec4 heat_power = vec4(0.0);
// Drops of rain running down the screen's edges in a downpour or after a swim
// (AirEffects): x their clock (seconds), y how thick they come now (0..1), z when on
// that clock the screen began to dry (-1 while it does not), w how thick they were then.
uniform vec4 drop_state = vec4(0.0, 0.0, -1.0, 0.0);
// Snow on the screen (AirEffects): x its clock (seconds), y how thick flakes stick to
// the edges while it snows (0..1), z how far frost has crept in from the edges (0..1).
uniform vec4 frost_state = vec4(0.0);
// The wind across the screen (AirEffects._glass_wind), -1..1, + to the right: the drops
// run aslant and the flakes slide aside with it, by up to GLASS_LANES lanes or cells.
uniform float glass_wind = 0.0;
// The rainbow after rain (AirEffects._rainbow): x how strong (0..1), y how far its top
// stands from the middle of the screen towards its edge (a share of the way there:
// high with a low sun, low at noon), zw the way across the screen
// away from the sun (x right, y down), where the bow stands.
uniform vec4 rainbow = vec4(0.0);
const float GLASS_LANES = 2.0;
// Behind a system menu (the pause, the settings, «Тестирование», the editor, the main menu
// over the world; CameraRig.ease_menu_blur), 0..1: the picture blurred and darkened by MENU_DARK.
// The blur is two rings of linear taps of crt_view on the low-res picture: a few
// hundred thousand reads a frame even on a phone.
uniform float menu_blur = 0.0;
const float MENU_DARK = 0.3;
// How far the inner ring of the blur reaches, in picture pixels (the outer one twice as far).
const float MENU_REACH = 2.8;
// The pixels of the picture round its edges left off the screen (PixelView.MARGIN).
uniform float view_margin = 0.0;
// How far the picture is moved on the screen, in its pixels (CameraRig: the margin and
// the leftover fraction the view glides by): the drops and the snow on the screen are
// placed by this, so they stay put on the glass while the world glides under them.
uniform vec2 screen_shift = vec2(0.0);
global uniform sampler2D cloud_noise : filter_linear, repeat_enable;
global uniform vec2 cloud_offset;

// The pixel of the screen's own grid (in pixels of the picture) under `uv` of the picture.
vec2 glass_px(vec2 uv, vec2 texel) {
	return floor(uv / texel + screen_shift);
}
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
// The retro palette (crt.gd PALETTES, setting «Палитра»), 0 none: the colours brought to
// it with ordered dithering by big pixels: 1 the NES's (55 colours), 2 black and white,
// 3 CGA (black, cyan, magenta, white).
uniform int retro = 0;
// The pixel's size (crt.gd PIXELS, setting «Размер пикселя»): how many pixels of the
// picture make one big pixel, on the world's grid so they do not crawl as the view moves.
uniform float retro_px = 1.0;
// The nearest colour of the NES palette for 8 bit (assets/nes_lut.png, tools/make_nes_lut.py).
uniform sampler2D retro_lut : filter_nearest;
// The gamma 1 bit and CGA lift the picture's darks by before the palette
// (Sky._update_grade: lower the darker the sky), 1 by day.
uniform float retro_lift = 1.0;
const vec3 CGA[4] = vec3[](vec3(0.0), vec3(0.333, 1.0, 1.0), vec3(1.0, 0.333, 1.0), vec3(1.0));

// The picture around `uv` blurred (crt_view: linear, so each tap averages four pixels):
// the middle, a ring of six taps `reach` picture pixels away and one of six twice as far,
// turned by 30°, weighted like a bell.
vec3 menu_blurred(vec2 uv, vec2 texel, float reach) {
	vec3 sum = texture(crt_view, uv).rgb * 0.16;
	for (int i = 0; i < 6; i++) {
		float a = float(i) * 1.0471976;
		vec2 d = vec2(cos(a), sin(a));
		sum += texture(crt_view, uv + d * reach * texel).rgb * 0.09;
		vec2 e = vec2(d.x * 0.8660254 - d.y * 0.5, d.x * 0.5 + d.y * 0.8660254);
		sum += texture(crt_view, uv + e * reach * 2.1 * texel).rgb * 0.05;
	}
	return sum;
}

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

// How many pixels the hot air moves the picture at its pixel `p` sideways: rows waving
// up over each fire, weaker to its sides and top, a pixel at most.
float heat_shift(vec2 p) {
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		if (heat_power[i] <= 0.0) {
			continue;
		}
		vec4 h = heat_spots[i];
		vec2 d = p - h.xy;
		float up = -d.y / h.w;
		float side = abs(d.x) / h.z;
		if (up < -0.1 || up > 1.0 || side > 1.0) {
			continue;
		}
		// Long, slow waves up the column: several rows go aside together and drift up,
		// rather than every other row shivering.
		float k = heat_power[i] * (1.0 - up * up) * (1.0 - side * side) * 1.5;
		float w = sin(p.y * 0.3 + TIME * 3.5 + h.x) * 0.7 + sin(p.y * 0.11 + TIME * 1.9) * 0.5;
		s += floor(w * k + 0.5);
	}
	return clamp(s, -1.0, 1.0);
}

// A drop of rain on the screen at pixel `p` of a picture `size` pixels: xy how far it
// moves the picture under it (a drop shows what is behind it upside down, shrunk), z its
// light (a glint at its top, a darker rim below, a wet trail above, negative darker).
// Lanes along the left and right edges get a drop now and then: it clings, runs down in
// a slide and dries away. Drops born before the screen began to dry (drop_state.z) run
// down and shrink away fast instead of vanishing.
vec3 screen_drop(vec2 p, vec2 size) {
	const float LANE = 12.0;
	const float DRY_RUN = 1.6;
	p -= view_margin;
	size -= 2.0 * view_margin;
	float lanes = floor(size.x / LANE);
	float col = floor(p.x / LANE);
	if (min(col, lanes - 1.0 - col) > 2.0 + GLASS_LANES) {
		return vec3(0.0);
	}
	float now = drop_state.x;
	bool drying = drop_state.z >= 0.0;
	// The wind blows the drops aside as they run (glass_wind): at most GLASS_LANES lanes
	// over their run, so a pixel looks at that many lanes upwind of it too.
	float run_y = size.y * 0.3;
	float slant = glass_wind * GLASS_LANES * LANE / run_y;
	vec3 out_d = vec3(0.0);
	for (int j = -int(GLASS_LANES); j <= int(GLASS_LANES); j++) {
		float c = col + float(j);
		float edge = min(c, lanes - 1.0 - c);
		if (c < 0.0 || edge > 2.0) {
			continue;
		}
		// Two drops a lane, on clocks of their own.
		for (int k = 0; k < 2; k++) {
			float seed = c + float(k) * 57.0;
			float h = crt_hash(vec2(seed, 3.1));
			float speed = 0.07 + 0.08 * h;
			float t = now * speed + h * 7.0;
			float round_n = floor(t);
			float f = fract(t);
			// As thick as the drops were when this one came: the ones there before the drying
			// run off.
			float born = (round_n - h * 7.0) / speed;
			bool old = drying && born < drop_state.z;
			if (crt_hash(vec2(seed, round_n)) > (old ? drop_state.w : drop_state.y) * (0.8 - edge * 0.2)) {
				continue;
			}
			float run = old ? clamp((now - drop_state.z) / DRY_RUN, 0.0, 1.0) : 0.0;
			f += (1.0 - f) * run;
			if (run >= 1.0) {
				continue;
			}
			float x0 = c * LANE + 3.0 + floor(crt_hash(vec2(round_n, seed)) * (LANE - 6.0));
			float y0 = floor(crt_hash(vec2(seed + 9.0, round_n)) * size.y * 0.7);
			float y = floor(y0 + smoothstep(0.3, 0.9, f) * run_y + run * 14.0);
			float x = floor(x0 + (y - y0) * slant + 0.5);
			float r = floor((mix(3.4, 0.8, smoothstep(0.75, 1.0, f)) + crt_hash(vec2(seed, round_n + 0.5)) * 1.4) * (1.0 - run) + 0.5);
			vec2 d = p - vec2(x, y);
			// Drawn out up and down, pointed at the top: a drop hanging as it runs.
			vec2 e = d + 0.5;
			e.y *= e.y < 0.0 ? 0.55 : 0.85;
			float dist = length(e);
			if (r >= 1.0 && dist < r) {
				// A brighter body over the picture under it, turned over, a darker rim at the
				// bottom and a glint at the top left.
				float light = 0.1;
				vec2 g = vec2(-floor(r * 0.5), -floor(r * 0.9));
				if (d == g || (r >= 3.0 && d == g + vec2(0.0, 1.0))) {
					light = 0.55;
				} else if (dist > r - 1.0 && d.y >= -0.5) {
					light = -0.2;
				}
				return vec3(-d * vec2(1.6, 1.1), light);
			}
			// The wet trail it leaves along the way it ran: two pixels wide near the drop,
			// one further up, bending the picture behind it a pixel toward its middle,
			// fading as it dries.
			float above = -d.y;
			float tx = p.x - floor(x0 + (p.y - y0) * slant + 0.5);
			float wide = above < 10.0 && r >= 2.0 ? 1.0 : 0.0;
			if (above > 0.0 && p.y > y0 && f > 0.3 && (tx == 0.0 || (wide > 0.0 && tx == -1.0))) {
				float fade = (1.0 - smoothstep(0.85, 1.0, f)) * (1.0 - run);
				out_d = vec3(tx == 0.0 ? -1.0 : 1.0, -1.0, (0.06 - above * 0.0008) * fade);
			}
		}
	}
	return out_d;
}

// A pixel `d` from the middle of a snowflake of `r` pixels: on one of its six arms (and
// the twigs off the ends of a big one: a star, not a cross).
bool flake_arm(vec2 d, float r) {
	d = abs(d);
	bool arm = (d.x == 0.0 && d.y <= r) || (d.y == 0.0 && d.x <= r) || (d.x == d.y && d.x <= r - 1.0);
	return arm || (r >= 4.0 && ((d.x == r - 1.0 && d.y == 1.0) || (d.y == r - 1.0 && d.x == 1.0)));
}

// The rainbow at pixel `p` of the screen's own grid (a picture `size` pixels): an arc of
// six bands of whole pixels, red outside, round a point far off the screen away from
// the sun, so it hangs where the sky would be and stays put on the glass as the world
// glides (a rainbow goes along with the one who looks); the sky inside it a little
// lighter, a faint second bow outside with its colours turned round, and its feet
// fading towards the near side of the view. rgb its colour, a how much of it.
vec4 rainbow_at(vec2 p, vec2 size) {
	vec3 bands[6] = vec3[](vec3(0.95, 0.27, 0.25), vec3(1.0, 0.6, 0.22), vec3(1.0, 0.92, 0.38),
		vec3(0.38, 0.86, 0.36), vec3(0.3, 0.52, 1.0), vec3(0.62, 0.38, 0.92));
	float half_diag = length(size) * 0.5;
	float band = max(1.0, floor(min(size.x, size.y) / 80.0));
	float radius = half_diag * 1.3;
	vec2 dir = rainbow.zw;
	vec2 off = p + 0.5 - size * 0.5;
	// How far the screen reaches from its middle along the bow's way, so its top stands
	// as high on a wide screen as on a tall one.
	float reach = 0.5 * dot(abs(dir), size);
	vec2 rel = off - dir * (reach * rainbow.y - radius);
	float t = (radius - length(rel)) / band;
	float feet = smoothstep(-0.75, 0.15, dot(off, dir) / half_diag);
	vec4 out_c = vec4(0.0);
	if (t >= 0.0 && t < 6.0) {
		out_c = vec4(bands[int(t)], 0.32);
	} else if (t >= 6.0 && t < 18.0) {
		out_c = vec4(vec3(1.0), 0.07 * (1.0 - (t - 6.0) / 12.0));
	} else if (t < -8.0 && t >= -14.0) {
		out_c = vec4(bands[int(-8.0 - t)], 0.11);
	}
	out_c.a *= feet * rainbow.x;
	// In steps of an eighth, dithered on the screen's grid: whole pixels, no smear.
	ivec2 b = ivec2(mod(p, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	out_c.a = floor(out_c.a * 8.0 + (float(m[b.y * 4 + b.x]) + 0.5) / 16.0) / 8.0;
	return out_c;
}

// Snow on the screen at pixel `p` of the picture (`size` pixels): flakes that land near
// the edges, lie a while and melt away, each a little six-armed star; and frost growing
// in from the edges, deeper in the corners, in feathery ridges. xyz the colour, w how much.
vec4 screen_snow(vec2 p, vec2 size) {
	p -= view_margin;
	size -= 2.0 * view_margin;
	vec2 near2 = min(p, size - 1.0 - p);
	float near = min(near2.x, near2.y);
	vec4 out_c = vec4(0.0);
	if (frost_state.z > 0.0) {
		// Deeper in a corner: how near the other edge is too.
		float corner = 1.0 - smoothstep(0.0, 60.0, max(near2.x, near2.y));
		float reach = frost_state.z * (16.0 + 44.0 * corner);
		vec2 q = p / 64.0;
		float n = texture(cloud_noise, q).r * 0.6 + texture(cloud_noise, q * 3.1 + 0.37).r * 0.4;
		float in_k = near - reach * (0.55 + n);
		if (in_k < 0.0) {
			// Feathers: thin ridges of the noise, a solid rim along the edge itself.
			float ridge = abs(fract(n * 7.0 + texture(cloud_noise, q * 9.0).r * 0.6) - 0.5);
			float rim = step(near, frost_state.z * 2.5);
			float a = max(rim * 0.75, step(ridge, 0.2) * 0.6 + 0.2);
			a *= clamp(-in_k / 4.0, 0.0, 1.0);
			out_c = vec4(0.86, 0.94, 1.0, a);
		}
	}
	if (frost_state.y > 0.0 && near < 48.0 + GLASS_LANES * 15.0) {
		// Cells of 15 pixels along the edges, each with a flake now and then; the wind
		// slides a lying flake aside over its life (glass_wind), so a pixel looks at the
		// cells upwind of it too.
		for (int j = -int(GLASS_LANES); j <= int(GLASS_LANES); j++) {
			vec2 cell = floor(p / 15.0) + vec2(float(j), 0.0);
			vec2 mid = cell * 15.0 + 7.5;
			vec2 near_c = min(mid, size - 1.0 - mid);
			float cell_near = min(near_c.x, near_c.y);
			if (cell_near >= 48.0 || mid.x < 0.0 || mid.x > size.x) {
				continue;
			}
			float h = crt_hash(cell + 5.3);
			float t = frost_state.x * (0.05 + 0.04 * h) + h * 9.0;
			float round_n = floor(t);
			float f = fract(t);
			float edge_k = 1.0 - cell_near / 48.0;
			if (crt_hash(cell + round_n * 1.7) >= frost_state.y * edge_k * 0.8 || f >= 0.85) {
				continue;
			}
			vec2 at = cell * 15.0 + 4.0 + floor(vec2(crt_hash(cell + round_n), crt_hash(cell - round_n)) * 7.0);
			at.x += floor(glass_wind * GLASS_LANES * 15.0 * f + 0.5);
			// It lands at once, lies, and melts down to a dot at the end.
			float r = f < 0.55 ? 4.0 : (f < 0.68 ? 3.0 : (f < 0.78 ? 2.0 : 1.0));
			if (crt_hash(cell * 1.3 + round_n) < 0.35) {
				r = min(r, 3.0);
			}
			vec2 d = p - at;
			if (abs(d.x) > 5.0 || abs(d.y) > 5.0) {
				continue;
			}
			float a = 0.0;
			vec3 col = vec3(0.97, 0.99, 1.0);
			if (flake_arm(d, r)) {
				a = d == vec2(0.0) ? 0.95 : 0.82;
			} else if (flake_arm(d + vec2(1.0, 0.0), r) || flake_arm(d - vec2(1.0, 0.0), r)
					|| flake_arm(d + vec2(0.0, 1.0), r) || flake_arm(d - vec2(0.0, 1.0), r)) {
				// A thin bluish shadow round it, so it shows over snow too.
				a = 0.32;
				col = vec3(0.42, 0.55, 0.72);
			}
			a *= 1.0 - smoothstep(0.7, 0.85, f);
			if (a > 0.0) {
				out_c = vec4(mix(out_c.rgb, col, a), max(out_c.a, a));
			}
		}
	}
	return out_c;
}

// Brings colour `c` to the retro palette (`retro`), `d` the big pixel's ordered dither
// threshold, 0..1.
vec3 retro_color(vec3 c, float d) {
	if (retro == 1) {
		// The NES's palette: the colour, richer first (the palette's greys would take the
		// muted greens of the crowns) and nudged by the dither, looked up in retro_lut, which
		// holds the nearest of the palette's 55 for each of 32 levels of red, green and blue.
		float g = dot(c, vec3(0.299, 0.587, 0.114));
		c = clamp(mix(vec3(g), c, 1.6), 0.0, 1.0);
		ivec3 k = ivec3(clamp(floor((c + (d - 0.5) * 0.16) * 31.0 + 0.5), 0.0, 31.0));
		return texelFetch(retro_lut, ivec2(k.b * 32 + k.r, k.g), 0).rgb;
	}
	if (retro == 2) {
		// The greys in five steps, black, three patterns and white, so a surface keeps one
		// even pattern instead of a noise of dots; brightness spread wider first, so the
		// picture is not all half grey.
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		l = clamp((l - 0.45) * 1.7 + 0.5, 0.0, 1.0);
		return vec3(step(d, floor(l * 4.0 + 0.5) / 4.0));
	}
	// Colours a little richer and harder first: the palette is far from the picture's.
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = clamp((mix(vec3(g), c, 1.4) - 0.45) * 1.3 + 0.5, 0.0, 1.0);
	// The nearest two colours of the palette, and between them by the dither: how far `c`
	// lies from the first toward the second.
	int a = 0;
	int b = 1;
	float da = 1e9;
	float db = 1e9;
	for (int i = 0; i < 4; i++) {
		vec3 e = c - CGA[i];
		float k = dot(e, e);
		if (k < da) {
			db = da;
			b = a;
			da = k;
			a = i;
		} else if (k < db) {
			db = k;
			b = i;
		}
	}
	vec3 ab = CGA[b] - CGA[a];
	float t = clamp(dot(c - CGA[a], ab) / dot(ab, ab), 0.0, 1.0);
	// In steps too, as the greys of 1 bit.
	return floor(t * 4.0 + 0.5) / 4.0 > d ? CGA[b] : CGA[a];
}

// The first pixel of the big pixel (retro_px) under `uv`, in pixels of the picture: the
// big pixels start at the world's pixels that divide by their size.
vec2 big_pixel(vec2 uv, vec2 texel) {
	vec2 pp = floor(uv / texel);
	return pp - mod(pp + floor(view_origin + 0.5), retro_px);
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

// A death's look over the graded picture (see death_look): the world fades, cools,
// darkens or goes sepia round the body, rings run out from it, night or fog closes in.
// Everything goes by world pixels, `dither` is the 4x4 matrix's (-0.5..0.5).
vec3 death_grade(vec3 c, vec2 px, float dither) {
	float k = death_mix;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec2 rel = px + 0.5 - death_at;
	float d = length(vec2(rel.x, rel.y / 0.8));
	if (death_look == 1) {
		// A small light over the body: dusk all round, its glow in bands on the ground.
		c = mix(c, vec3(l) * vec3(0.85, 0.92, 1.08), 0.75 * k) * (1.0 - 0.35 * k);
		float g = length(px + 0.5 - death_light.xy);
		c += floor(clamp(1.0 - g / 24.0, 0.0, 1.0) * 3.0) / 3.0 * vec3(0.43, 0.33, 0.16) * 0.6 * death_light.z;
		if (g < 4.5 && dither < 0.0) {
			c = mix(c, vec3(1.0, 0.86, 0.55), 0.4 * death_light.z);
		}
	} else if (death_look == 2 || death_look == 4 || death_look == 8 || death_look == 9) {
		// Dust, flowers, moths, leaves: the world a little paler and dimmer.
		float sat = death_look == 2 ? 0.5 : death_look == 8 ? 0.45 : 0.3;
		vec3 hue = death_look == 9 ? vec3(1.1, 0.95, 0.8) : death_look == 4 ? vec3(0.92, 0.9, 1.05) : vec3(1.0);
		c = mix(c, vec3(l) * hue, sat * k) * (1.0 - (death_look == 4 ? 0.3 : 0.22) * k);
	} else if (death_look == 3) {
		// Sepia, the body left in colour, and a dark dithered ring closing in on it.
		// Near it only what is not green (the grass round it goes sepia with the rest).
		float keep = step(length(rel / vec2(11.0, 7.0)), 1.0) * step(c.g, max(c.r, c.b) + 0.02);
		c = mix(c, vec3(l) * vec3(1.07, 0.9, 0.68), 0.85 * k * (1.0 - keep));
		float r = 150.0 - 90.0 * k;
		float dark = clamp((d - r) / 40.0, 0.0, 1.0);
		float dk = (0.25 + 0.45 * step(dither + 0.5, dark)) * k * clamp((d - r) / 10.0, 0.0, 1.0);
		c = mix(c, vec3(0.12, 0.086, 0.055), dk);
	} else if (death_look == 5 || death_look == 10) {
		// A ghost, snow: the world cold and pale; round the ghost a faint blue glow.
		c = mix(c, vec3(l) * vec3(0.9, 0.96, 1.1), 0.58 * k) * (1.0 - 0.22 * k);
		float g = length(px + 0.5 - death_light.xy);
		c += floor(clamp(1.0 - g / 16.0, 0.0, 1.0) * 3.0) / 3.0 * vec3(0.16, 0.22, 0.31) * 0.6 * death_light.z;
	} else if (death_look == 6) {
		// Rings run out from the body every 1.1 s; behind the first the world is grey.
		float dr = length(vec2(rel.x, rel.y / 0.75));
		float reach = max(0.0, (death_time - 0.5) * 30.0);
		float passed = clamp((reach - dr) / 30.0, 0.0, 1.0) * k;
		c = mix(c, vec3(l) * vec3(0.95, 0.97, 1.05), 0.7 * passed) * (1.0 - 0.25 * passed);
		float wave = reach - dr;
		float at = mod(wave, 33.0);
		if (wave > 0.0 && wave < 33.0 * 5.0 && at < 1.4 && dither + 0.5 < (1.0 - dr / 120.0) * k) {
			c = mix(c, vec3(0.92, 0.94, 1.0), 0.65);
		}
	} else if (death_look == 7) {
		// Night falls at once; only a warm patch round the body stays lit.
		vec3 night = c * 0.35 + vec3(l) * vec3(0.25, 0.32, 0.55) * 0.4;
		float lit = clamp((22.0 - d) / 10.0, 0.0, 1.0);
		lit = step(dither + 0.5, lit) * 0.6 + floor(lit * 2.0) / 2.0 * 0.4;
		vec3 warm = mix(vec3(l) * vec3(1.0, 0.72, 0.42), c, 0.3);
		c = mix(c, mix(night, warm, lit), k);
	} else if (death_look == 11) {
		// The stars: a deep night blue.
		c = mix(c, vec3(l) * vec3(0.35, 0.42, 0.7), 0.7 * k);
	} else if (death_look == 12) {
		// Fog creeps in from the edges in four dithered steps till the body's glade is left.
		float t = death_time;
		float n = (sin(px.x * 0.09 + t * 0.6) + sin(px.y * 0.07 - t * 0.4) + sin((px.x + px.y) * 0.05 + t * 0.3)) / 3.0;
		c = mix(c, vec3(l), 0.4 * k) * (1.0 - 0.1 * k);
		float r = 160.0 - 130.0 * k;
		float dens = clamp((d - r) / 40.0 + n * 0.35, 0.0, 0.9);
		float f = clamp(floor(dens * 4.0 + dither + 0.5) / 4.0, 0.0, 0.9) * step(0.001, k);
		c = mix(c, vec3(0.8, 0.83, 0.86) * clamp(exposure, 0.3, 1.0) * tint, f);
	}
	return c;
}

void fragment() {
	vec2 uv = UV;
	// Where this pixel is on the screen, 0..1.
	vec2 picture = crt_scale / TEXTURE_PIXEL_SIZE;
	vec2 sp = (crt_screen.zw + UV * picture) / crt_screen.xy;
	float edge = 1.0;
	float band = 0.0;
	vec3 drop = vec3(0.0);
	vec2 glass = vec2(0.0);
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
		// The glass does not swim or jitter with the picture.
		glass = glass_px((sp * crt_screen.xy - crt_screen.zw) / picture, TEXTURE_PIXEL_SIZE);
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
		if (heat_power != vec4(0.0)) {
			uv.x += heat_shift(floor(uv / TEXTURE_PIXEL_SIZE)) * TEXTURE_PIXEL_SIZE.x;
		}
		if (drop_state.y > 0.0 || drop_state.z >= 0.0) {
			drop = screen_drop(glass, 1.0 / TEXTURE_PIXEL_SIZE);
			uv += drop.xy * TEXTURE_PIXEL_SIZE;
		}
		if (retro_px > 1.0) {
			uv = (big_pixel(uv, TEXTURE_PIXEL_SIZE) + 0.5) * TEXTURE_PIXEL_SIZE;
		}
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
		glass = glass_px(uv, TEXTURE_PIXEL_SIZE);
		if (sway > 0.0 || trip > 0.0) {
			uv += sway_shift(sp) * TEXTURE_PIXEL_SIZE;
		}
		if (heat_power != vec4(0.0)) {
			uv.x += heat_shift(floor(uv / TEXTURE_PIXEL_SIZE)) * TEXTURE_PIXEL_SIZE.x;
		}
		if (drop_state.y > 0.0 || drop_state.z >= 0.0) {
			drop = screen_drop(glass, 1.0 / TEXTURE_PIXEL_SIZE);
			uv += drop.xy * TEXTURE_PIXEL_SIZE;
		}
		if (trip > 0.0) {
			// The picture breathes: it swells and shrinks slowly round the middle.
			uv = 0.5 + (uv - 0.5) * (1.0 - trip * 0.025 * (0.5 + 0.5 * sin(TIME * 0.8)));
		}
		if (retro_px > 1.0) {
			// The big pixel, read in one filtered tap at its middle (crt_view): its middle four
			// pixels averaged, so the fine detail does not turn into a noise of dots; uv stays
			// on its first pixel.
			vec2 pp = big_pixel(uv, TEXTURE_PIXEL_SIZE);
			uv = (pp + 0.5) * TEXTURE_PIXEL_SIZE;
			src = texture(crt_view, (pp + retro_px * 0.5) * TEXTURE_PIXEL_SIZE).rgb;
		} else {
			src = texture(TEXTURE, uv).rgb;
		}
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
	if (menu_blur > 0.0) {
		src = mix(src, menu_blurred(uv, TEXTURE_PIXEL_SIZE, MENU_REACH * menu_blur), menu_blur);
	}
	src = clamp(src + drop.z, 0.0, 1.0);
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
	if (rainbow.x > 0.0) {
		// Light added in the air, as warm or cool as the hour's light.
		vec4 bow = rainbow_at(glass, 1.0 / TEXTURE_PIXEL_SIZE);
		c = 1.0 - (1.0 - c) * (1.0 - clamp(bow.rgb * tint, 0.0, 1.0) * bow.a);
	}
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
	if (dream > 0.0) {
		vec2 shape = vec2(crt_screen.x / crt_screen.y, 1.0);
		float d = length((sp - 0.5) * shape) / length(shape * 0.5);
		float soft = dream * smoothstep(0.3, 0.95, d);
		vec3 glow = vec3(0.0);
		vec3 blur = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398 + (i >= 4 ? 0.392699 : 0.0);
			vec2 way = vec2(cos(a), sin(a)) * TEXTURE_PIXEL_SIZE;
			vec3 s = texture(TEXTURE, uv + way * (i >= 4 ? 5.0 : 2.5)).rgb * exposure;
			glow += s * smoothstep(0.6, 1.0, max(s.r, max(s.g, s.b)));
			blur += texture(TEXTURE, uv + way * (i >= 4 ? 3.0 : 1.5) * (0.5 + 2.0 * soft)).rgb;
		}
		// The blur shifts the graded colour by how the picture round differs from the pixel.
		c += (blur / 8.0 - src) * exposure * soft;
		c += glow / 8.0 * 0.45 * dream;
		float dl = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 blue = vec3(0.55, 0.7, 1.0) * dl * 0.9 + vec3(0.01, 0.02, 0.05);
		c = mix(c, blue, 0.5 * dream);
		// The whole picture sinks towards a deep night blue.
		c = mix(c, vec3(0.02, 0.04, 0.12), 0.4 * dream);
		c *= 1.0 - dream * 0.4 * smoothstep(0.25, 1.05, d);
	}
	if (death_look > 0) {
		c = death_grade(c, px, dither);
	}
	if (heart > 0.0) {
		c = (c - 0.45) * (1.0 + 0.6 * heart) + 0.45;
		c *= 1.0 - 0.4 * heart;
		c = mix(c, c * vec3(1.0, 0.75, 0.75), heart * 0.5);
	}
	if (frost_state.y > 0.0 || frost_state.z > 0.0) {
		vec4 snow = screen_snow(glass, 1.0 / TEXTURE_PIXEL_SIZE);
		c = mix(c, snow.rgb * max(exposure, 0.35) * tint, snow.a);
	}
	if (retro > 0) {
		// The dither by big pixels, on the world's grid as they are.
		ivec2 rb = ivec2(mod(floor(px / retro_px), 4.0));
		if (retro > 1) {
			// Four colours lose a dark picture whole: by night its darks are lifted by the
			// sky's light (retro_lift, a gamma), so the ground still shows dim round a fire's
			// patch while the patch itself does not go all white.
			c = pow(max(c, vec3(0.0)), vec3(retro_lift));
		}
		c = retro_color(clamp(c, 0.0, 1.0), (float(m[rb.y * 4 + rb.x]) + 0.5) / 16.0);
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
	c *= 1.0 - MENU_DARK * menu_blur;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
