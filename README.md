# Survivium

A meditative survival sandbox: an endless procedural world of levels in 3D pixel art seen at 3/4.
Plays in the browser (phones too), with multiplayer through your own server. Godot 4.5.1, pure GDScript.

A Russian copy of this file: [README_RU.md](README_RU.md).

## Play

- **Browser:** https://randomboygh.github.io/survivium/ — built from `main` after every merge (the browser
  may show an old build for about ten minutes). The version and the list of changes are under «What's new»
  in the main menu.
- **PC (Windows, Linux):** the [pc-latest](https://github.com/randomboygh/survivium/releases/tag/pc-latest)
  release, also updated with every merge.
- **Multiplayer:** «Multiplayer» → «Join» (a link with `?server=address` opens this screen with the address
  filled in).

## What is in the game

A world without an edge: continents, mountains, caves, rivers, swamps, deserts and two dozen more biomes;
20 species of trees, shrubs and grasses that follow the seasons; 22 kinds of beasts, birds and fish, hunting
and fishing. Day and night, seasons, weather, light from a campfire, a torch, a candle and a lantern. Dig,
chop, mow, gather, craft at stations; build walls, floors and rooms by blocks or by blueprint, place doors,
windows, stairs, furniture and a fireplace. Hunger, thirst, sleep, warmth and health, clothes and worn bags,
nine skills that grow with use. Teams, land plots and PvP on a server. Saves per world. Mods and bundles are
data in YAML (`content/<mod>/`, each mod has its own README).

Controls: WASD or arrows — walk, Space — jump, LMB/RMB — action of the left/right hand, F — action button,
1–8 — hotbar slot, V — next tool, C — brush, I/Tab — bag, Q/E — slice the levels (R — reset), `[`/`]` —
rotate the camera, `-`/`=` — tilt, Enter — chat on a server, H — hints, F3 — stats, Esc — menu; the map is
a tap on the minimap. On a phone: a joystick on the left, action and jump buttons on the right, a tap on the
world acts with the active hand.

## Your own server

On a computer: «Multiplayer» → «Create a server», or from a terminal
`Survivium.console.exe --headless -- --server` (Linux: `./Survivium.x86_64 --headless -- --server`).
Friends on the same network join by the address in the server window (`ws://192.168.…:7777`).

For friends over the internet without setting up a router: put
[cloudflared](https://github.com/cloudflare/cloudflared/releases) next to the game (rename it to
`cloudflared.exe` or `cloudflared`), turn on «Access from the internet» (`--tunnel` in a terminal) and send
a friend the link from «Copy the link». The address is new at every start; the computer must not sleep. A
password or `whitelist on` lets in only people you know. The «Real weather outside» checkbox
(`--real-weather` in a terminal) makes the world's weather real: the weather right now where the server's
computer is.

Without a computer: on GitHub «Actions» → «Playtest server» → «Run workflow» (minutes, world seed, bots; by
default the test world and 3 bots that play beside you on their own), or in the game «Testing» → «Start the test server», then «Join the test server». In a couple of minutes the link for a phone appears in the step
«Start the server»; the world is not saved.

## Development

- Every change is a PR into `main`. When CI is green the PR merges itself, with no manual «merge»; changes
  of structure and architecture are agreed first.
- Every PR description has at least one line for the player, in Russian: `Что нового [вид]: …`, where the
  kind is `новое`, `улучшено`, `исправлено`, `оптимизировано` or `ядро`. CI shows them in «Testing».
- The client's version is `<stage>.<PR number>`; CI (`.github/workflows/build.yml`) runs the tests, builds
  the web and PC versions, checks the web build in Chrome and publishes from `main` to GitHub Pages and to
  `pc-latest`.
- All the checks at once: `tests/run_all.sh`. Rules, checks and pitfalls: [CLAUDE.md](CLAUDE.md); the code's
  documentation: [docs/INDEX.md](docs/INDEX.md). The plan and game design live in the `plan/` folder of the
  Claude project.
