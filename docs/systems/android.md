# The Android build

Status: ACTIVE. A Russian copy: [android_RU.md](android_RU.md).

**Purpose.** The game as an Android app (APK, arm64): the same client as in the phone's browser, with single
player (the server inside the game, `local_host.gd`) and joining a server; it does not host a server (the menu
offers «Create a server» only on a computer, `menu_pages.gd` `host_here`). CI builds it on every run and puts
the build of `main` on the release `android-latest`; it is installed by hand.

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
  (`DisplayServer.get_display_safe_area`).
- `assets/app/`: the icons drawn by `tools/make_icon.py` (Android's plain, adaptive and one-colour ones, the
  Windows program's `icon.ico`).
- `.github/workflows/build.yml`, the jobs `android` (the export, the artifact `survivium-android`) and
  `publish-android`; `.github/actions/godot` unpacks the template `android_release.apk`.

**Signing.** A phone installs an APK over the one it has only if both are signed by the same key and the new
version code (`version/code`, CI sets it to the run's number) is greater. The key lives in the repository's
secrets: `ANDROID_KEYSTORE` (the keystore in base64, the key's alias `survivium`) and `ANDROID_KEYSTORE_PASSWORD`
(the keystore's and the key's password). Without them CI signs with a key made for that run and says so in the
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
(`src/client/ui/last_log.gd`); the shader warm-up prints each mix it draws.

**Tests.** No device in CI: the `android` job fails if the export or the signature check fails; how it plays
is checked on a phone.
