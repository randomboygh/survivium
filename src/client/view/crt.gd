extends RefCounted
## The old screen look over the world picture (setting «Кинескоп»: off, soft, old):
## scanlines with interlace, the glow of bright pixels, the colour channels a little
## apart, the curve of the tube, dark corners, flicker and the phosphor stripes. It runs
## in the colour grade's pass (shaders/grade.gdshader, the `crt_*` uniforms), at the
## screen's resolution, so it costs no pass of its own; the interface stays sharp over it.

## The looks, by the setting's index (0 is off): scanline darkness and how many on the
## screen's height, the alternate rows darkened by turns (interlace), the glow's
## strength and the brightness it starts at, the channels' offset (a share of the
## screen's width), the curve, the dark corners, the flicker and the stripes' darkness;
## then the bright bar rolling down, and the tape's (VHS) rows jittering sideways (a
## share of the width), colour smeared along the rows (a share of the width), the torn
## band of interference near the bottom and noise. Missing ones are 0.
const LOOKS := [
	{},
	{"scan": 0.12, "lines": 600.0, "interlace": 0.04, "glow": 0.4, "threshold": 0.7, "rgb": 0.0005,
		"curve": 0.01, "vignette": 0.15, "flicker": 0.005, "mask": 0.08},
	{"scan": 0.35, "lines": 400.0, "interlace": 0.12, "glow": 1.0, "threshold": 0.55, "rgb": 0.002,
		"curve": 0.05, "vignette": 0.4, "flicker": 0.025, "mask": 0.2, "roll": 0.08},
	{"scan": 0.1, "lines": 480.0, "interlace": 0.04, "glow": 0.5, "threshold": 0.65, "rgb": 0.0015,
		"curve": 0.02, "vignette": 0.3, "flicker": 0.01, "mask": 0.0, "jitter": 0.0012, "bleed": 0.004,
		"band": 1.0, "noise": 0.03},
]
const PARAMS := ["scan", "lines", "interlace", "glow", "threshold", "rgb", "curve", "vignette", "flicker",
	"mask", "roll", "jitter", "bleed", "band", "noise"]


## Sets look `i` (an index into LOOKS) on the grade material `mat`, whose `crt_view`
## is the linear-filtered world picture the glow reads (`tex`).
static func apply(mat: ShaderMaterial, i: int, tex: Texture2D) -> void:
	var look: Dictionary = LOOKS[clampi(i, 0, LOOKS.size() - 1)]
	mat.set_shader_parameter("crt_on", not look.is_empty())
	if look.is_empty():
		mat.set_shader_parameter("crt_view", null)
		return
	mat.set_shader_parameter("crt_view", tex)
	for k in PARAMS:
		mat.set_shader_parameter("crt_" + k, look.get(k, 0.0))


## Where the picture lies on the screen this frame, for the curve: the screen's size,
## and the container's top left corner and scale (its position moves by a fraction of
## a pixel as the camera glides). `field` is which rows interlace darkens (by frames).
static func frame(mat: ShaderMaterial, screen: Vector2, corner: Vector2, scale: float, field: int) -> void:
	mat.set_shader_parameter("crt_screen", Vector4(screen.x, screen.y, corner.x, corner.y))
	mat.set_shader_parameter("crt_scale", scale)
	mat.set_shader_parameter("crt_field", float(field & 1))
