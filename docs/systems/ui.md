# Interface and settings

Status: ACTIVE. A Russian copy: [ui_RU.md](ui_RU.md) (it may trail this page: it is caught up weekly).

This page is the overview; the detail is split by topic into `ui/`. Read the overview, then only the page the
change reaches (`grep -n '^#' docs/systems/ui/<page>.md` first if it is long).

**Purpose.** A pixel interface after the mock-ups: the main menu over a drawn landscape and the loading screen,
«New world» and «Load world», the HUD (clock, the slice of levels, the panel, buttons), the bag window with
crafting and chests, maps, the death screen, settings and the «Testing» page, the performance panel and the
freeze log. The layout adapts to the screen's proportions and switches between touch and mouse by the last
input.

**Where to look**

| Topic | Page | Key files |
|---|---|---|
| The UI kit: windows, buttons, switches, choice rows, lists, the slot strip | [ui/kit.md](ui/kit.md) | `src/client/ui/kit/*` |
| Screens before the game: main menu, loading, new/load world, join, create a server | [ui/screens.md](ui/screens.md) | `main_menu.gd` and its parts |
| The game screen: HUD, bag, crafting, chests, death screen, pause | [ui/hud.md](ui/hud.md) | `hud.gd` and its parts |
| Maps, settings and «Testing», the performance panel, the freeze log, shared drawing | [ui/maps-settings-debug.md](ui/maps-settings-debug.md) | `minimap.gd`, `settings.gd`, `perf_panel.gd`, `ui_style.gd` |
| Texts, pitfalls of the keyboard and the browser, tests | [ui/pitfalls.md](ui/pitfalls.md) | `assets/web/keyboard.html` |

**More.** `plan/design/ui.md` (mock-ups and decisions on the interface), screenshots `survivium-builds/ui/`.
