extends RefCounted
## What the browser did since the last look, for the freezes' log (PerfPanel): the
## shader programs its WebGL built and the time that took (the first draw of a thing
## under lights it was not drawn under before, or of a new kind of thing; which, by
## the defines of its shaders, once the warm-up is over), the data sent to the GPU
## (meshes, instances, textures) and the time that took, the page's garbage
## collections (any, and the full ones, which take the old objects too), and the long
## frames the page saw with what ran in them (the game's frame, touch events, the
## sound's messages), from the browser's long-animation-frame entries. It wraps those
## calls of WebGL2 in the page with a clock and watches objects no one holds that a
## collection takes away; off the web it sees nothing.

const SCRIPT := """
(function () {
	'use strict';
	if (window.survivium_gl || typeof WebGL2RenderingContext === 'undefined') return;
	var s = window.survivium_gl = {};
	var programs = 0, build_ms = 0, sent = 0, send_ms = 0;
	var started = false, late = [];
	var collections = 0, full = 0, full_at = -1000;
	var frames = [];
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
	// What a program linked after the warm-up is, by its shaders' defines and the
	// data block that tells the kind of shader.
	function describe(gl, prog) {
		var shaders = gl.getAttachedShaders(prog) || [];
		var out = [];
		var kind = '';
		for (var q = 0; q < shaders.length; q++) {
			var src = gl.getShaderSource(shaders[q]) || '';
			if (!kind) {
				kind = src.indexOf('SceneData') >= 0 ? 'scene' : src.indexOf('CanvasData') >= 0 ? 'canvas'
					: src.indexOf('FrameData') >= 0 ? 'particles' : 'other';
			}
			var re = /^#define ([A-Z][A-Z0-9_]*)\\s*$/gm, m;
			var head = src.slice(0, 4000);
			while ((m = re.exec(head)) !== null) if (out.indexOf(m[1]) < 0) out.push(m[1]);
		}
		return kind + ' ' + out.join(' ');
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
	// Garbage collections, counted by objects no one holds that they take away: a young
	// one, put back at once, goes at any collection that looks at the young objects'
	// weak cells; an old one, held eight seconds before it is let go (so it has moved
	// among the old objects, which only a full collection sweeps), goes at a full one.
	// A finalizer tells, unlike WeakRef.deref, which would keep the object alive through
	// the frame it is asked in. One is let go every two seconds, so one is always
	// waiting; the ones a full collection takes together count once.
	if (typeof FinalizationRegistry !== 'undefined') {
		var gone = new FinalizationRegistry(function (old) {
			if (!old) {
				collections++;
				gone.register({}, 0);
				return;
			}
			var now = performance.now();
			if (now - full_at > 100) full++;
			full_at = now;
		});
		gone.register({}, 0);
		var held = [];
		setInterval(function () {
			held.push({});
			if (held.length > 4) gone.register(held.shift(), 1);
		}, 2000);
	}
	// The page's long frames (over 50 ms), each with when it began, how long it was and
	// what scripts ran in it for 5 ms or more, by what called them, as
	// "start:ms:name ms,name ms".
	if (typeof PerformanceObserver !== 'undefined') {
		try {
			new PerformanceObserver(function (list) {
				var es = list.getEntries();
				for (var q = 0; q < es.length; q++) {
					var e = es[q];
					var by = {}, order = [], sc = e.scripts || [];
					for (var r = 0; r < sc.length; r++) {
						var inv = String(sc[r].invoker || sc[r].invokerType || '');
						if (inv.indexOf('requestAnimationFrame') >= 0) inv = 'кадр';
						else {
							var dot = inv.lastIndexOf('.');
							inv = dot >= 0 ? inv.slice(dot + 1) : inv;
							if (inv.indexOf('on') === 0) inv = inv.slice(2);
							if (inv === 'message') inv = 'звук';
						}
						if (!(inv in by)) { by[inv] = 0; order.push(inv); }
						by[inv] += sc[r].duration;
					}
					var parts = [];
					for (r = 0; r < order.length; r++) parts.push(order[r] + ' ' + Math.round(by[order[r]]));
					if (frames.length < 16) frames.push(Math.round(e.startTime) + ':' + Math.round(e.duration) + ':' + parts.join(','));
				}
			}).observe({type: 'long-animation-frame', buffered: false});
		} catch (err) {}
	}
	s.started = function () { started = true; };
	// Everything since the last call, as one string (one call a frame, little garbage):
	// "programs,build ms,bytes sent,send ms,collections,full collections,now|long
	// frames;...|late programs;...". The counts are totals; the frames and programs
	// are handed over once.
	s.take = function () {
		var out = programs + ',' + build_ms.toFixed(1) + ',' + sent + ',' + send_ms.toFixed(1) + ',' + collections + ','
			+ full + ',' + performance.now().toFixed(1) + '|' + frames.join(';') + '|' + late.join(';');
		frames.length = 0;
		late.length = 0;
		return out;
	};
})();
"""

## The page's counters (a JavaScriptObject), null off the web.
var _js = null
## The counters at the last look: programs, ms building, bytes sent, ms sending,
## collections, full collections.
var _last := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])


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
## "build_ms", "sent" KB and "send_ms", "collections" of garbage and "full" ones,
## "now" (the page's clock, ms), "frames": the page's long frames since, each
## [start on the page's clock, ms, what ran], and "late": the programs built after
## the warm-up, described.
func take() -> Dictionary:
	if _js == null:
		return {}
	var text: String = str(_js.take())
	var sections := text.split("|")
	var nums := sections[0].split_floats(",")
	if nums.size() < 7:
		return {}
	var out := {
		"programs": nums[0] - _last[0], "build_ms": nums[1] - _last[1], "sent": (nums[2] - _last[2]) / 1024.0,
		"send_ms": nums[3] - _last[3], "collections": int(nums[4] - _last[4]), "full": int(nums[5] - _last[5]),
		"now": nums[6], "frames": [], "late": [],
	}
	for i in 6:
		_last[i] = nums[i]
	if sections.size() > 1 and sections[1] != "":
		for f in sections[1].split(";"):
			var bits := f.split(":", true, 2)
			if bits.size() == 3:
				out.frames.append([float(bits[0]), float(bits[1]), bits[2]])
	if sections.size() > 2 and sections[2] != "":
		out.late = Array(sections[2].split(";"))
	return out
