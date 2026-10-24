"""Patches the web export after Godot writes it.

1. The engine's audio position worklet (index.audio.position.worklet.js) posts a message to
the page for every 128 frames of sound each playing sample makes: some 375 a second a
sound, each an object the page's garbage collector then has to sweep. With the rain, the
fire and the wind playing, that was most of the page's garbage, and the phone stopped for
a major collection of 100-150 ms every few seconds (2026-10-24). The patch posts the
position once every REPORT frames instead, and at once after a reset; the game reads it
only to pick the voice that has played longest (Sound.free_voice).

2. The engine's sample player (in index.js) does not loop a looping sound in Web Audio: it
waits for the sound to end, and in the page's own time starts it again from where it was
first started. So a loop started in the middle (Sound._fade) played only its end over and
over, and each time with a gap as long as the page was busy: the rain, the wind, the
water and the fire came in bursts (2026-10-24). The patch makes the buffer source loop by
itself, without a seam, so it never ends until it is stopped.

It fails when the engine's code is not the one it knows, so an engine upgrade is noticed.

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


# Where the sample player gives a new buffer source its sound: when it is made and when it
# starts again (index.js is minified, one statement each).
SOURCE = "this._source.buffer=this.getSample().getAudioBuffer();"
LOOPED = SOURCE + 'this._source.loop=this.getSample().loopMode==="forward";'
SOURCES = 2


def patch(path: Path, old: str, new: str, count: int, what: str) -> None:
    text = path.read_text()
    if new in text:
        print("%s: patched already" % path)
        return
    if text.count(old) != count:
        sys.exit("%s: not the code tools/web_patch.py knows; look at it again" % path)
    path.write_text(text.replace(old, new))
    print("%s: %s" % (path, what))


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    patch(out / "index.audio.position.worklet.js", OLD, NEW, 1,
          "a position report every %d frames" % REPORT)
    patch(out / "index.js", SOURCE, LOOPED, SOURCES, "looping sounds loop in Web Audio")


if __name__ == "__main__":
    main()
