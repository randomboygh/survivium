# The Android build

Status: ACTIVE. A Russian copy: [android_RU.md](android_RU.md).

**Purpose.** The game as an Android app (APK, arm64): the same client as in the phone's browser, with single
player (the server inside the game, `local_host.gd`), joining a server and «Create a server» (`menu_pages.gd`
`host_here`): players on the same Wi-Fi join by the phone's address; no tunnel (cloudflared runs only on a computer,
`host_screen.gd` hides «Access from the internet»), and the server stops while the app is in the background. CI builds it on every run and puts
the build of `main` into its GitHub release `v<stage>.<PR>` (and the rolling `android-latest`; `docs/testing/CI_PIPELINE.md`, Releases); it is installed by hand.

**Files**
- `export_presets.cfg`, the preset `Android`: arm64-v8a only, the prebuilt template (no Gradle), the package id
  `package/unique_name`, the icons `launcher_icons/*`, immersive full screen, the permissions `internet` (joining a
  server) and `vibrate` (`vibration.gd`); `package/retain_data_on_uninstall` lets the player keep the saves when
  the app is removed.
- `project.godot`: `display/window/handheld/orientation=6` (the screen turns with the phone, as in the browser),
  `application/config/quit_on_go_back=false`, `rendering/textures/vram_compression/import_etc2_astc=true` (the
  Android export requires it).
- `src/client/main.gd` `_notification`: the back button (`NOTIFICATION_WM_GO_BACK_REQUEST`) is the Escape key.
- `src/client/view/camera_rig.gd` `_safe_rect`: the HUD keeps off the camera cutout
  (`DisplayServer.get_display_safe_area`) and above the keyboard (`DisplayServer.virtual_keyboard_get_height`,
  read ten times a second by `poll_safe_rect`): the app's window keeps its size under the keyboard, so the
  interface moves up as in the browser.
- `assets/app/`: the icons drawn by `tools/make_icon.py` (Android's plain, adaptive and one-colour ones, the
  Windows program's `icon.ico`).
- `.github/workflows/build.yml`, the jobs `android` (the export, the artifact `survivium-android`) and
  `release` (the APK as a file of the release); `.github/actions/godot` unpacks the template `android_release.apk`.

**Signing.** A phone installs an APK over the one it has only if both are signed by the same key and the new
version code (`version/code`, CI sets it to the run's number) is greater. The key lives in the repository's
secrets: `ANDROID_KEYSTORE` (the keystore in base64, the key's alias `survivium`) and `ANDROID_KEYSTORE_PASSWORD`
(the keystore's and the key's password); CI gives them only to a build of `main`, so an APK of a pull request is
signed by a key of its run and does not install over a release. Without them CI signs with a key made for that run and says so in the
release's text: such an APK must be removed before the next one is installed, and the saves go with it. The
step prints the certificate's SHA-256 to the run's summary.

**What the code sees.** `OS.has_feature("android")`, `"mobile"` are true; `"pc"`, `"web"` are false. So the mods
are read from the copy built in (`ContentFields.find_root`), the screen turns (`CameraRig.turns`), the full
screen setting is hidden (`Settings.can_fullscreen`), sounds play from the start, the «Quit» button closes the
app. `user://` is the app's private folder.

**The package id** (`io.github.randomboygh.survivium`) is written only in the preset. It does not change with
the game's name (`tools/rename.py` leaves it, [../RENAMING.md](../RENAMING.md)): another id is another app,
with no update over the old one and no saves.

**Local export.** Needs the Android SDK (`platform-tools`, `build-tools` with `apksigner`) and a JDK 17+, their
paths in the editor settings (`export/android/android_sdk_path`, `java_sdk_path`), and a key in
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER`, `_PASSWORD`:
`godot --headless --path . --export-release "Android" build/android/survivium-android.apk`.

**A crash** leaves no message on a phone: the engine's file log is on for Android
(`debug/file_logging/enable_file_logging.android`), and «Data for the test» shows the end of the last run's log
(`src/client/ui/last_log.gd`); a run that ended with no close, pause or «Quit» (the file `user://running` left) is a crash,
and the main menu then offers «Crash log» with that log to copy; in the developer mode the settings have the tab
«Debug» with what needs no world: the last run's log, the freeze log, the interface gallery, wiping the data, and «Shader check» (`src/client/view/shader_probe.gd`: each 3D
shader drawn alone, with and without lights; a step the app crashed on is marked so at the next run); the shader warm-up prints each mix it draws.

**The renderer: Vulkan (Mobile).** The Adreno 840's OpenGL ES driver (the user's phone, 2026-11-12) crashed the app
building any big shader of ours, at random from run to run («Shader check»: stencil, int arrays, varyings and the disk
cache of shaders were each suspected and ruled out), while the browser on the same phone, whose Chrome rewrites shaders
before the driver sees them, draws them. Under Vulkan every step passed and the world loads (2026-11-13), so the Android
app uses the Mobile renderer (`project.godot`: `renderer/rendering_method.mobile="mobile"`, `.web="gl_compatibility"`
keeps the web on Compatibility); a phone without Vulkan falls back to OpenGL by itself
(`rendering_device/fallback_to_opengl3`). The two renderers take colours differently: `common.gdshaderinc` makes the Mobile
one see them as Compatibility does (`SRGB`, `SRGB_HINT`, `COMPAT_ALBEDO`, `COMPAT_COLORS`, [rendering.md](rendering.md));
the sun's light with a shadow, which Compatibility adds in sRGB in a pass of its own, goes through `compat_sun`
(the globals `ambient_light`, `sun_shadowed` set by `sky.gd`); what blends (water, particles) and the torch's and fires'
light with shadows still mix in linear light there. Shots side by side: `survivium-builds/android/vulkan-colours-*.png`.

**Tests.** No device in CI: the `android` job fails if the export or the signature check fails; how it plays
is checked on a phone.
