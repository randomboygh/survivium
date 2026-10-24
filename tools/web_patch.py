"""Patches the web export after Godot writes it.

The engine's audio position worklet (index.audio.position.worklet.js) posts a message to
the page for every 128 frames of sound each playing sample makes: some 375 a second a
sound, each an object the page's garbage collector then has to sweep. With the rain, the
fire and the wind playing, that was most of the page's garbage, and the phone stopped for
a major collection of 100-150 ms every few seconds (2026-10-24). The patch posts the
position once every REPORT frames instead, and at once after a reset; the game reads it
only to pick the voice that has played longest (Sound.free_voice).

It fails when the worklet is not the one it knows, so an engine upgrade is noticed.

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


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    worklet = out / "index.audio.position.worklet.js"
    text = worklet.read_text()
    if "tools/web_patch.py" in text:
        print("%s: patched already" % worklet)
        return
    if OLD not in text:
        sys.exit("%s: not the worklet tools/web_patch.py knows; look at it again" % worklet)
    worklet.write_text(text.replace(OLD, NEW))
    print("%s: a position report every %d frames" % (worklet, REPORT))


if __name__ == "__main__":
    main()
