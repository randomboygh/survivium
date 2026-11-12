# The game's name and renaming

Status: ACTIVE. Where the game's name is written, how to rename it and what stays as it was. A Russian
copy: [RENAMING_RU.md](RENAMING_RU.md).

## Where the name is

The name is written in one place: `config/name` in `project.godot`. It is taken by:

- the code — `Protocol.game_name()` (`src/shared/net/protocol.gd`): the main menu's inscription
  (`main_menu.gd`, in capitals), the server's default name (`src/server/config.gd`, `host_screen.gd`), the
  first line of the server's log (`server_main.gd`), the «Data for the test» report (`settings_menu.gd`), the
  hint «a server is started on a computer» (`menu_pages.gd`, the name is put into the translation through
  `%s`);
- the engine — the window's title on PC and the web page's `<title>`;
- CI (`.github/workflows/build.yml`, the jobs `pc` and `publish`) — the names of the programs `<Name>.exe`,
  `<Name>.console.exe`, `<Name>.x86_64`, of the archives `<name>-windows.zip`, `<name>-linux.tar.gz` and the
  release text;
- the drawing tools `tools/make_splash.py` (the splash `assets/splash.png`) and `tools/make_icon.py` (the
  link preview card `assets/web/og.png`).

Copies the code cannot read: the tags `og:site_name`, `og:title` in `html/head_include` and the paths
`export_path` in `export_presets.cfg`, the name in `README.md`, `CLAUDE.md` and in `docs/`.

## How to rename

```
python3 tools/rename.py "New name" --dry-run   # what will change
python3 tools/rename.py "New name"
python3 tools/doc_index.py
```

The script changes `config/name`, the copies from the list above (the name as a whole word, as written and
in capitals; lower-case — addresses and identifiers — it does not touch; `docs/audit/`, `docs/planning/` are
the history of their day) and draws the splash and the preview card again. Then look at `assets/splash.png`
(the sparrow sits on the first letter: `BIRD_X` in `make_splash.py`) and `assets/web/og.png`, and run the
checks. The 32×32 icon is a picture without letters, the name does not touch it.

## What does not change with the name

- **The saves folder.** On PC `user://` is `…/godot/app_userdata/<config/name>`, so it is pinned:
  `config/use_custom_user_dir=true`, `config/custom_user_dir_name` in `project.godot` points to the former
  folder, and the worlds, settings, `server.cfg` stay in place after renaming. Do not change it. In the
  browser the data lies in the page's `/userfs`, on Android — in the app's folder: the name does not affect
  them.
- **The address and the repository.** `randomboygh.github.io/survivium` (`src/server/tunnel.gd` `PAGE`, the
  links in README), `randomboygh/survivium` (`src/client/net/playtest.gd` `REPO`). Renaming the repository on
  GitHub changes the page's address: old links and bookmarks on a phone stop opening the game.
- **The release `pc-latest`** is a tag, not a name. The archives with the old name stay in it beside the new
  ones until they are deleted on github.com.
- **Internal names** `window.survivium_*` (the page and the game, `text_field.gd`, `sign_window.gd`,
  `gl_watch.gd`, `tools/web_patch.py`, `tests/browser_smoke.mjs`), the names of CI artifacts
  (`survivium-web` …) — the player does not see them.
- **Android** (not built yet): the package identifier is chosen once and then does not change — otherwise it
  is another app, with no update and no saves; take it with no game name or with one that will not change.
