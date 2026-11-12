# Android-сборка

Статус: ACTIVE. Английский оригинал: [android.md](android.md).

**Назначение.** Игра как приложение Android (APK, arm64): тот же клиент, что в браузере телефона, с одиночной
игрой (сервер внутри игры, `local_host.gd`) и подключением к серверу; сервер на телефоне не создаётся («Создать
сервер» меню предлагает только на компьютере, `menu_pages.gd` `host_here`). CI собирает его при каждом запуске
и кладёт сборку `main` в релиз `android-latest`; ставится вручную.

**Файлы**
- `export_presets.cfg`, пресет `Android`: только arm64-v8a, готовый шаблон (без Gradle), идентификатор пакета
  `package/unique_name`, значки `launcher_icons/*`, полноэкранный режим, разрешения `internet` (подключение к
  серверу) и `vibrate` (`vibration.gd`); `package/retain_data_on_uninstall` даёт игроку оставить сохранения при
  удалении приложения.
- `project.godot`: `display/window/handheld/orientation=6` (экран поворачивается с телефоном, как в браузере),
  `application/config/quit_on_go_back=false`, `rendering/textures/vram_compression/import_etc2_astc=true` (его
  требует экспорт Android).
- `src/client/main.gd` `_notification`: кнопка «Назад» (`NOTIFICATION_WM_GO_BACK_REQUEST`) — это клавиша Escape.
- `src/client/view/camera_rig.gd` `_safe_rect`: интерфейс обходит вырез камеры
  (`DisplayServer.get_display_safe_area`).
- `assets/app/`: значки, нарисованные `tools/make_icon.py` (обычный, адаптивный и одноцветный для Android,
  `icon.ico` программы для Windows).
- `.github/workflows/build.yml`, задачи `android` (экспорт, артефакт `survivium-android`) и `publish-android`;
  `.github/actions/godot` распаковывает шаблон `android_release.apk`.

**Подпись.** Телефон ставит APK поверх прежнего, только если оба подписаны одним ключом и код версии нового
(`version/code`, CI ставит номер запуска) больше. Ключ лежит в секретах репозитория: `ANDROID_KEYSTORE`
(хранилище ключа в base64, псевдоним ключа `survivium`) и `ANDROID_KEYSTORE_PASSWORD` (пароль хранилища и
ключа). Без них CI подписывает ключом, сделанным для этого запуска, и пишет это в тексте релиза: такой APK
придётся удалить перед установкой следующего, вместе с сохранениями. Шаг печатает SHA-256 сертификата в сводку
запуска.

**Что видит код.** `OS.has_feature("android")`, `"mobile"` — истина; `"pc"`, `"web"` — ложь. Поэтому моды
читаются из встроенной копии (`ContentFields.find_root`), экран поворачивается (`CameraRig.turns`), настройка
полного экрана скрыта (`Settings.can_fullscreen`), звук играет сразу, кнопка «Выход» закрывает приложение.
`user://` — закрытая папка приложения.

**Идентификатор пакета** (`io.github.randomboygh.survivium`) записан только в пресете. С названием игры он не
меняется (`tools/rename.py` его не трогает, [../RENAMING.md](../RENAMING_RU.md)): другой идентификатор — другое
приложение, без обновления поверх старого и без сохранений.

**Экспорт у себя.** Нужны Android SDK (`platform-tools`, `build-tools` с `apksigner`) и JDK 17+, их пути в
настройках редактора (`export/android/android_sdk_path`, `java_sdk_path`) и ключ в
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER`, `_PASSWORD`:
`godot --headless --path . --export-release "Android" build/android/survivium-android.apk`.

**Тесты.** Устройства в CI нет: задача `android` падает, если не вышел экспорт или проверка подписи; как
играется, проверяют на телефоне.
