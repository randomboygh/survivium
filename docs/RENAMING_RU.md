# Имя игры и переименование

Английская версия: [RENAMING.md](RENAMING.md) (она основная, эта — копия).

Статус: ACTIVE. Где записано имя игры, как её переименовать и что при этом остаётся прежним.

## Где имя

Имя записано в одном месте: `config/name` в `project.godot`. Из него берут:

- код — `Protocol.game_name()` (`src/shared/net/protocol.gd`): надпись главного меню (`main_menu.gd`,
  заглавными), название сервера по умолчанию (`src/server/config.gd`, `host_screen.gd`), первая строка
  журнала сервера (`server_main.gd`), отчёт «Данные для теста» (`settings_menu.gd`), подсказка «сервер
  запускают на компьютере» (`menu_pages.gd`, имя подставляется в перевод через `%s`);
- движок — заголовок окна на ПК и `<title>` web-страницы;
- CI (`.github/workflows/build.yml`, задачи `pc` и `publish`) — имена программ `<Имя>.exe`,
  `<Имя>.console.exe`, `<Имя>.x86_64`, архивов `<имя>-windows.zip`, `<имя>-linux.tar.gz` и текст релиза;
- рисовалки `tools/make_splash.py` (заставка `assets/splash.png`) и `tools/make_icon.py`
  (карточка превью ссылки `assets/web/og.png`).

Копии, которые код прочитать не может: теги `og:site_name`, `og:title` в `html/head_include` и пути
`export_path` в `export_presets.cfg`, имя в `README.md`, `CLAUDE.md` и в `docs/`.

## Как переименовать

```
python3 tools/rename.py "Новое имя" --dry-run   # что изменится
python3 tools/rename.py "Новое имя"
python3 tools/doc_index.py
```

Скрипт меняет `config/name`, копии из списка выше (имя целым словом, как написано и заглавными;
строчное — адреса и идентификаторы — не трогает; `docs/audit/`, `docs/planning/` — история своего дня)
и заново рисует заставку и карточку превью. Затем посмотреть `assets/splash.png` (воробей сидит на
первой букве: `BIRD_X` в `make_splash.py`) и `assets/web/og.png`, прогнать проверки. Иконка 32×32 —
рисунок без букв, её имя не касается.

## Что не меняется с именем

- **Папка сохранений.** На ПК `user://` — это `…/godot/app_userdata/<config/name>`, поэтому она
  закреплена: `config/use_custom_user_dir=true`, `config/custom_user_dir_name` в `project.godot` указывает
  на прежнюю папку, и миры, настройки, `server.cfg` после переименования остаются на месте. Её не
  менять. В браузере данные лежат в `/userfs` страницы, на Android — в папке приложения: имя на них не
  влияет.
- **Адрес и репозиторий.** `randomboygh.github.io/survivium` (`src/server/tunnel.gd` `PAGE`, ссылки
  в README), `randomboygh/survivium` (`src/client/net/playtest.gd` `REPO`). Переименование репозитория
  на GitHub меняет адрес страницы: старые ссылки и закладки на телефоне перестают открывать игру.
- **Релиз `pc-latest`** — тег, не имя. Архивы со старым именем остаются в нём рядом с новыми, пока их
  не удалить на github.com.
- **Внутренние имена** `window.survivium_*` (страница и игра, `text_field.gd`, `sign_window.gd`,
  `gl_watch.gd`, `tools/web_patch.py`, `tests/browser_smoke.mjs`), имена артефактов CI
  (`survivium-web` …) — игрок их не видит.
- **Идентификатор пакета Android** `io.github.randomboygh.survivium` (`package/unique_name` пресета
  `Android`, [systems/android.md](systems/android_RU.md)) выбирается один раз и потом не меняется — иначе
  это другое приложение, без обновления и без сохранений. Как и адрес, он хранит старое имя; игроки его не
  видят. Релиз `android-latest` — тоже тег.
