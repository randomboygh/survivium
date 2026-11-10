"""Patches the web export after Godot writes it.

The engine's audio position worklet (index.audio.position.worklet.js) posts a message to
the page for every 128 frames of sound each playing sample makes: some 375 a second a
sound, each an object the page's garbage collector then has to sweep. With the rain, the
fire and the wind playing, that was most of the page's garbage, and the phone stopped for
a major collection of 100-150 ms every few seconds (2026-10-24). The patch posts the
position once every REPORT frames instead, and at once after a reset; the game reads it
only to pick the voice that has played longest (Sound.free_voice).

The engine's sample playback (index.js, GodotAudio.Sample.getAudioBuffer) also copied the
whole sample into a new AudioBuffer at every play, two Float32Arrays and the buffer: a
megabyte and more of garbage a footstep, so the page's memory limit came every few
seconds and each full collection stopped the phone for 45 ms (2026-10-24). An AudioBuffer
may feed any number of source nodes at once and is never written after it is filled, so
the patch hands out the one buffer the sample was registered with.

Nor did it loop a looping sound in Web Audio: it waited for the sound to end, and in the
page's own time started it again from where it was first started. So a loop started in
the middle (Sound._fade) played only its end over and over, and each time with a gap as
long as the page was busy: the rain, the wind, the water and the fire came in bursts
(2026-10-24). The patch makes the buffer source loop by itself, without a seam, so it
never ends until it is stopped.

The engine asks the page for the time hundreds of times a frame (clock_time_get), and
each answer was written to the engine's memory as a new BigInt; and it asks whether the
browser runs on a phone or a computer (godot_js_os_has_feature) every frame, and sets the
volume and pitch of each sound playing in the world, each time reading the name of the
feature or the voice into a new string. That was most of what the page made
for its garbage collector while walking (2026-11-08, sampled in headless Chrome), and the
phone stopped for a full collection of 50-130 ms every half a minute or so. The patch
writes the time as two 32-bit halves and finds each name among those read before by a
hash of its bytes, without making a string.

A touch on the page gave the canvas the page's focus, and so took it from the hidden input
the phone's keyboard types into: a tap on the field being edited closed the keyboard, and
the field, taking the tap, opened it again at once (2026-11-10). The patch leaves the focus
with the keyboard's input while it has it (the game lets the field go when a tap lands off
it: src/client/ui/text_field.gd). The keyboard asked for again still hides its input and
focuses it anew in the same moment: that is what opens the keyboard again once the phone
has put it away (the back button) while the input kept the focus; a focus it already has
opens nothing, and the keyboard never came back (2026-11-10).

It fails when the files are not the ones it knows, so an engine upgrade is noticed.

    python3 tools/web_patch.py [build/web]
"""

import sys
from pathlib import Path

# Sound frames between two reports: about a quarter of a second at 48 kHz.
REPORT = 12288

OLD = """		if (parameters['reset'][0] > 0) {
			this.position = 0;
		}

		if (inputs.length > 0) {
			const input = inputs[0];
			if (input.length > 0) {
				this.position += input[0].length;
				this.port.postMessage({ type: 'position', data: this.position });
			}
		}"""

NEW = """		let report = false;
		if (parameters['reset'][0] > 0) {
			this.position = 0;
			report = true;
		}

		if (inputs.length > 0) {
			const input = inputs[0];
			if (input.length > 0) {
				this.position += input[0].length;
				// Patched by tools/web_patch.py: a report every %d frames, not every 128.
				this.unreported = (this.unreported || 0) + input[0].length;
				if (report || this.unreported >= %d) {
					this.unreported = 0;
					this.port.postMessage({ type: 'position', data: this.position });
				}
			}
		}""" % (REPORT, REPORT)


# The sample's buffer handed to a new source node: a copy, and the one it has.
COPY = "getAudioBuffer(){return this._duplicateAudioBuffer()}"
SHARED = "getAudioBuffer(){return this._audioBuffer}"

# Where the sample player gives a new source node its sound: when it is made and when it
# starts again.
SOURCE = "this._source.buffer=this.getSample().getAudioBuffer();"
LOOPED = SOURCE + 'this._source.loop=this.getSample().loopMode==="forward";'


# The time written as a BigInt, and as two unsigned 32-bit halves (nanoseconds stay below
# 2^53, so the division is exact enough).
CLOCK = "HEAP64[ptime>>3]=BigInt(nsec);return 0}"
CLOCK_HALVES = "HEAPU32[ptime>>2]=nsec>>>0;HEAPU32[(ptime>>2)+1]=Math.floor(nsec/4294967296);return 0}"

# Names the engine hands over (a feature, a playing voice) read into a new string at every
# call, from a buffer made anew each time; then found among those read before by a hash of
# their bytes, and checked byte by byte, without making a string.
KEPT = ("var _keptNames=new Map();function _keptName(p){let h=0,n=0;"
    "while(HEAPU8[p+n]!==0){h=(Math.imul(h,31)+HEAPU8[p+n])|0;n++}"
    "const k=_keptNames.get(h);if(k!==undefined&&k.length===n){let same=true;"
    "for(let i=0;same&&i<n;i++){same=HEAPU8[p+i]===k.charCodeAt(i)}if(same){return k}}"
    "const s=GodotRuntime.parseString(p);if(s.length===n){if(_keptNames.size>1024){_keptNames.clear()}"
    "_keptNames.set(h,s)}return s}")
FEATURE = "function _godot_js_os_has_feature(p_ftr){const ftr=GodotRuntime.parseString(p_ftr);"
FEATURE_KEPT = KEPT + "function _godot_js_os_has_feature(p_ftr){const ftr=_keptName(p_ftr);"
VOLUMES = "function _godot_audio_sample_set_volumes_linear(playbackObjectIdStrPtr,busesPtr,busesSize,volumesPtr,volumesSize){const playbackObjectId=GodotRuntime.parseString(playbackObjectIdStrPtr);"
VOLUMES_KEPT = VOLUMES.replace("GodotRuntime.parseString(", "_keptName(")
PITCH = "function _godot_audio_sample_update_pitch_scale(playbackObjectIdStrPtr,pitchScale){const playbackObjectId=GodotRuntime.parseString(playbackObjectIdStrPtr);"
PITCH_KEPT = PITCH.replace("GodotRuntime.parseString(", "_keptName(")

# A touch starting on the canvas gave it the page's focus; not while the keyboard's input has it.
TOUCH = "function touch_cb(type,evt){if(type===0){GodotConfig.canvas.focus()}"
TOUCH_KEPT = ("function touch_cb(type,evt){if(type===0&&document.activeElement!==GodotDisplayVK.textinput"
    "&&document.activeElement!==GodotDisplayVK.textarea){GodotConfig.canvas.focus()}")


def patch(path: Path, old: str, new: str, what: str, count: int = 1) -> None:
    text = path.read_text()
    if new in text:
        print("%s: patched already" % path)
        return
    if text.count(old) != count:
        sys.exit("%s: not the file tools/web_patch.py knows; look at it again" % path)
    path.write_text(text.replace(old, new))
    print("%s: %s" % (path, what))


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    patch(out / "index.audio.position.worklet.js", OLD, NEW, "a position report every %d frames" % REPORT)
    patch(out / "index.js", COPY, SHARED, "a sample's buffer shared by its source nodes, not copied at every play")
    patch(out / "index.js", SOURCE, LOOPED, "looping sounds loop in Web Audio", 2)
    patch(out / "index.js", CLOCK, CLOCK_HALVES, "the time written without a BigInt")
    patch(out / "index.js", FEATURE, FEATURE_KEPT, "the names of the browser's features kept, not read into a string each call")
    patch(out / "index.js", VOLUMES, VOLUMES_KEPT, "the names of the voices whose volumes change kept")
    patch(out / "index.js", PITCH, PITCH_KEPT, "the names of the voices whose pitch changes kept")
    patch(out / "index.js", TOUCH, TOUCH_KEPT, "a touch leaves the page's focus with the keyboard's input")


if __name__ == "__main__":
    main()
