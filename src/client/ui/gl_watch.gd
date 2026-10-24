extends RefCounted
## What the browser did since the last look, for the freezes' log (PerfPanel): the
## shader programs its WebGL built and the time that took (the first draw of a thing
## under lights it was not drawn under before, or of a new kind of thing; which, by
## the shader's own uniforms and the defines of the variant, once the warm-up is
## over), the data sent to the GPU (meshes, instances, textures) and the time that
## took, the page's full garbage collections, when the engine's frame callback began
## and when the last one ended (so the time outside the engine's own work splits into
## before the frame, between the callbacks and after the drawing), and the long frames
## the page saw with what ran in them (the game's frame, touch events, the sound's
## messages, the rendering), from the browser's long-animation-frame entries. It wraps
## those calls of WebGL2 and requestAnimationFrame in the page with a clock and watches
## an object no one holds that a collection takes away; off the web it sees nothing.

const SCRIPT := """
(function () {
	'use strict';
	if (window.survivium_gl || typeof WebGL2RenderingContext === 'undefined') return;
	var s = window.survivium_gl = {};
	var programs = 0, build_ms = 0, sent = 0, send_ms = 0;
	var started = false, late = [];
	var collections = 0;
	var frames = [];
	var cb_start = 0, cb_end = 0;
	var p = WebGL2RenderingContext.prototype;
	// Bytes a call sends, as the engine calls them (data from the WASM heap with an
	// offset and a length); textures as four bytes a texel.
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
	// Calls f on self with the first n arguments: WebGL picks what a call does by how
	// many it gets, and handing `arguments` on would make an object for the garbage
	// collector at every call (texSubImage3D takes the most, 12).
	function call(f, self, n, a, b, c, d, e, g, h, i, j, k, l, m) {
		switch (n) {
			case 0: return f.call(self);
			case 1: return f.call(self, a);
			case 2: return f.call(self, a, b);
			case 3: return f.call(self, a, b, c);
			case 4: return f.call(self, a, b, c, d);
			case 5: return f.call(self, a, b, c, d, e);
			case 6: return f.call(self, a, b, c, d, e, g);
			case 7: return f.call(self, a, b, c, d, e, g, h);
			case 8: return f.call(self, a, b, c, d, e, g, h, i);
			case 9: return f.call(self, a, b, c, d, e, g, h, i, j);
			case 10: return f.call(self, a, b, c, d, e, g, h, i, j, k);
			case 11: return f.call(self, a, b, c, d, e, g, h, i, j, k, l);
		}
		return f.call(self, a, b, c, d, e, g, h, i, j, k, l, m);
	}
	// What a program linked after the warm-up is: the kind of shader (by the data
	// block it reads), the names the game's own shader declared (the engine prefixes
	// them with m_: its uniforms, varyings and functions), and the defines of the
	// variant that tell what it is drawn for (the shadow pass, many instances, which
	// lights are off).
	var KEEP = /^(MODE_|USE_INSTANCING|DISABLE_LIGHT|SHADOWS_DISABLED|USE_PRIMITIVE|USE_ATTRIBUTES|USE_LIGHTING|DISABLE_LIGHTING)/;
	function describe(gl, prog) {
		var shaders = gl.getAttachedShaders(prog) || [];
		var defs = [], names = [];
		var kind = '';
		for (var q = 0; q < shaders.length; q++) {
			var src = gl.getShaderSource(shaders[q]) || '';
			if (!kind) {
				kind = src.indexOf('SceneData') >= 0 ? 'scene' : src.indexOf('CanvasData') >= 0 ? 'canvas'
					: src.indexOf('FrameData') >= 0 ? 'particles' : 'other';
			}
			var re = /^#define ([A-Z][A-Z0-9_]*)\\s*$/gm, m;
			var head = src.slice(0, 4000);
			while ((m = re.exec(head)) !== null) if (KEEP.test(m[1]) && defs.indexOf(m[1]) < 0) defs.push(m[1]);
			var rn = /\\bm_([A-Za-z0-9_]+)/g;
			while ((m = rn.exec(src)) !== null && names.length < 6) if (names.indexOf(m[1]) < 0) names.push(m[1]);
		}
		return kind + (names.length ? ' ' + names.join(',') : '') + (defs.length ? ' ' + defs.join(' ') : '');
	}
	function wrap(name, build) {
		var f = p[name];
		if (typeof f !== 'function') return;
		var size = sizes[name];
		var link = name === 'linkProgram';
		p[name] = function (a, b, c, d, e, g, h, i, j, k, l, m) {
			var n = arguments.length;
			var t = performance.now();
			var r = call(f, this, n, a, b, c, d, e, g, h, i, j, k, l, m);
			t = performance.now() - t;
			if (build) {
				build_ms += t;
				if (link) {
					programs++;
					if (started && late.length < 8) late.push(describe(this, a));
				}
			} else {
				send_ms += t;
				sent += size(n, a, b, c, d, e, g, h, i, j, k, l, m);
			}
			return r;
		};
	}
	// Building waits on the GPU's process at the status asked after compiling and linking.
	['compileShader', 'linkProgram', 'getShaderParameter', 'getProgramParameter'].forEach(function (n) { wrap(n, true); });
	['bufferData', 'bufferSubData', 'texImage2D', 'texSubImage2D', 'texImage3D', 'texSubImage3D'].forEach(function (n) { wrap(n, false); });
	// The engine runs its frame in the page's animation frame callback: when the one
	// under way began and when the last one ended.
	var raf = window.requestAnimationFrame;
	if (typeof raf === 'function') {
		window.requestAnimationFrame = function (cb) {
			return raf.call(window, function (ts) {
				cb_start = performance.now();
				cb(ts);
				cb_end = performance.now();
			});
		};
	}
	// Garbage collections, counted by an object no one holds that one takes away, put
	// back at once. A finalizer tells, unlike WeakRef.deref, which would keep the object
	// alive through the frame it is asked in; it runs after the full collections alone
	// (the young ones keep what a finalizer watches).
	if (typeof FinalizationRegistry !== 'undefined') {
		var gone = new FinalizationRegistry(function () {
			collections++;
			gone.register({}, 0);
		});
		gone.register({}, 0);
	}
	// The page's long frames (over 50 ms), each with when it began, how long it was and
	// what ran in it for 5 ms or more: the scripts by what called them, and the
	// rendering after them, as "start:ms:name ms,name ms".
	if (typeof PerformanceObserver !== 'undefined') {
		try {
			new PerformanceObserver(function (list) {
				var es = list.getEntries();
				for (var q = 0; q < es.length; q++) {
					var e = es[q];
					var by = {}, order = [], sc = e.scripts || [];
					for (var r = 0; r < sc.length; r++) {
						var inv = String(sc[r].invoker || sc[r].invokerType || '');
						if (inv.indexOf('requestAnimationFrame') >= 0 || inv.indexOf('FrameRequestCallback') >= 0) inv = 'кадр';
						else {
							var dot = inv.lastIndexOf('.');
							inv = dot >= 0 ? inv.slice(dot + 1) : inv;
							if (inv.indexOf('on') === 0) inv = inv.slice(2);
							if (inv === 'message' || inv === 'ended') inv = 'звук';
						}
						if (!(inv in by)) { by[inv] = 0; order.push(inv); }
						by[inv] += sc[r].duration;
					}
					var parts = [];
					for (r = 0; r < order.length; r++) if (by[order[r]] >= 5) parts.push(order[r] + ' ' + Math.round(by[order[r]]));
					var render = e.renderStart > 0 ? e.startTime + e.duration - e.renderStart : 0;
					if (render >= 5) parts.push('рендер ' + Math.round(render));
					if (frames.length < 16) frames.push(Math.round(e.startTime) + ':' + Math.round(e.duration) + ':' + parts.join(','));
				}
			}).observe({type: 'long-animation-frame', buffered: false});
		} catch (err) {}
	}
	s.started = function () { started = true; };
	// Everything since the last call, as one string (one call a frame, little garbage):
	// "programs,build ms,bytes sent,send ms,collections,now,callback began,last
	// callback ended|long frames;...|late programs;...". The counts are totals; the
	// frames and programs are handed over once.
	s.take = function () {
		var out = programs + ',' + build_ms.toFixed(1) + ',' + sent + ',' + send_ms.toFixed(1) + ',' + collections + ','
			+ performance.now().toFixed(1) + ',' + cb_start.toFixed(1) + ',' + cb_end.toFixed(1) + '|' + frames.join(';') + '|' + late.join(';');
		frames.length = 0;
		late.length = 0;
		return out;
	};
})();
"""

## The page's counters (a JavaScriptObject), null off the web.
var _js = null
## The counters at the last look: programs, ms building, bytes sent, ms sending,
## collections.
var _last := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])


func _init() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(SCRIPT, true)
	_js = JavaScriptBridge.get_interface("survivium_gl")


## The warm-up is over: programs linked from now on are described (see take).
func started() -> void:
	if _js != null:
		_js.started()


## What happened since the last call, or {} off the web: "programs" built and
## "build_ms", "sent" KB and "send_ms", "collections" of garbage, "now" (the page's
## clock, ms), "callback" (when the frame callback under way began on it) and
## "callback_end" (when the last one ended), "frames": the page's long frames since,
## each [start on the page's clock, ms, what ran], and "late": the programs built after
## the warm-up, described.
func take() -> Dictionary:
	if _js == null:
		return {}
	var text: String = str(_js.take())
	var sections := text.split("|")
	var nums := sections[0].split_floats(",")
	if nums.size() < 8:
		return {}
	var out := {
		"programs": nums[0] - _last[0], "build_ms": nums[1] - _last[1], "sent": (nums[2] - _last[2]) / 1024.0,
		"send_ms": nums[3] - _last[3], "collections": int(nums[4] - _last[4]),
		"now": nums[5], "callback": nums[6], "callback_end": nums[7], "frames": [], "late": [],
	}
	for i in 5:
		_last[i] = nums[i]
	if sections.size() > 1 and sections[1] != "":
		for f in sections[1].split(";"):
			var bits := f.split(":", true, 2)
			if bits.size() == 3:
				out.frames.append([float(bits[0]), float(bits[1]), bits[2]])
	if sections.size() > 2 and sections[2] != "":
		out.late = Array(sections[2].split(";"))
	return out
