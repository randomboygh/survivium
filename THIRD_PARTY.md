# Third-party components

What the game and its tools use that was not written for the project. A licence text of each is in its own
package; the game shows the engine's notices in its settings once that screen exists (the engine gives
them by `Engine.get_license_text()` and `Engine.get_license_info()`).

## In the builds (web, Android, Windows, Linux)

| Component | Version | Licence | Note |
|---|---|---|---|
| Godot Engine and its export templates | 4.5.1 | MIT | The engine carries its own third-party libraries (Apache 2.0, BSD, zlib and others), listed in the engine's `COPYRIGHT.txt` |
| Press Start 2P (font, `assets/fonts/`) | 2012 release | SIL OFL 1.1 | [OFL.txt](assets/fonts/OFL.txt); the font may not be sold by itself |
| Android template libraries (AndroidX, Kotlin, ...) | those of the Godot 4.5.1 template | Apache 2.0 | Come with the template |

Everything else in the builds (pictures, sounds, music notes, models) is made by the project's own scripts in
`tools/` from noise, tones and drawn pixels.

## Build and development only (not in the game)

| Component | Licence | Used for |
|---|---|---|
| Android SDK and build-tools 35.0.0 (Google) | Android SDK License | Building and signing the APK |
| JDK (OpenJDK) | GPLv2 with Classpath Exception | Android export |
| GitHub Actions (checkout, upload-artifact, download-artifact, upload-pages-artifact) | MIT | CI |
| Python 3 | PSF | `tools/*.py` |
| Pillow | HPND | Drawing tools (`tools/make_*.py`) |
| NumPy | BSD-3-Clause | `tools/sound/thunder_bands.py` |
| Node.js and playwright-core 1.64.1 | Apache 2.0 | Browser smoke test in CI |
| Chromium | BSD-3-Clause and others | Browser for that test |
| cloudflared (Cloudflare) | Apache 2.0 | Server tunnel; not shipped, the host downloads it; the Cloudflare service has its own terms |

Pillow and NumPy have no pinned versions yet (no `requirements.txt`).
