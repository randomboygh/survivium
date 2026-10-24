extends RefCounted
## What the browser's WebGL did since the last look, for the freezes' log (PerfPanel):
## the shader programs it built and the time that took (the first draw of a thing under
## lights it was not drawn under before, or of a new kind of thing), and the data sent
## to the GPU (meshes, instances, textures) and the time that took. It wraps those
## calls of WebGL2 in the page with a clock; off the web it sees nothing.

const SCRIPT := """
(function () {
	if (window.survivium_gl || typeof WebGL2RenderingContext === 'undefined') return;
	var s = window.survivium_gl = {programs: 0, build_ms: 0, sent: 0, send_ms: 0};
	var p = WebGL2RenderingContext.prototype;
	// Bytes a call sends, as the engine calls them (data from the WASM heap with an
	// offset and a length); textures as four bytes a texel. The arguments come one by
	// one, as `arguments` handed on would be a new object, garbage, at every call.
	var sizes = {
		bufferData: function (n, a, b, c, d, e) {
			return typeof b === 'number' ? b : n >= 5 ? e : b ? b.byteLength : 0;
		},
		bufferSubData: function (n, a, b, c, d, e) { return n >= 5 ? e : c ? c.byteLength : 0; },
		texImage2D: function (n, a, b, c, d, e) { return n >= 9 ? d * e * 4 : 0; },
		texSubImage2D: function (n, a, b, c, d, e, f) { return n >= 9 ? e * f * 4 : 0; },
		texImage3D: function (n, a, b, c, d, e, f) { return d * e * f * 4; },
		texSubImage3D: function (n, a, b, c, d, e, f, g, h) { return f * g * h * 4; },
	};
	function wrap(name, build) {
		var f = p[name];
		if (typeof f !== 'function') return;
		var size = sizes[name];
		var link = name === 'linkProgram';
		p[name] = function (a, b, c, d, e, g, h, i) {
			var t = performance.now();
			var r = f.apply(this, arguments);
			t = performance.now() - t;
			if (build) {
				s.build_ms += t;
				if (link) s.programs++;
			} else {
				s.send_ms += t;
				s.sent += size(arguments.length, a, b, c, d, e, g, h, i);
			}
			return r;
		};
	}
	// Building waits on the GPU's process at the status asked after compiling and linking.
	['compileShader', 'linkProgram', 'getShaderParameter', 'getProgramParameter'].forEach(function (n) { wrap(n, true); });
	['bufferData', 'bufferSubData', 'texImage2D', 'texSubImage2D', 'texImage3D', 'texSubImage3D'].forEach(function (n) { wrap(n, false); });
})();
"""

## The page's counters (a JavaScriptObject), null off the web.
var _js = null
## The counters at the last look: programs, ms building, bytes sent, ms sending.
var _last := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])


func _init() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(SCRIPT, true)
	_js = JavaScriptBridge.get_interface("survivium_gl")


## [programs built, ms building, KB sent, ms sending] since the last call; [] off the web.
func take() -> Array:
	if _js == null:
		return []
	var now := PackedFloat64Array([float(_js.programs), float(_js.build_ms), float(_js.sent), float(_js.send_ms)])
	var out := [now[0] - _last[0], now[1] - _last[1], (now[2] - _last[2]) / 1024.0, now[3] - _last[3]]
	_last = now
	return out
