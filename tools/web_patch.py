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


if __name__ == "__main__":
    main()
