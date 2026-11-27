# Maps, settings, debugging, shared parts

Part of [Interface and settings](../ui.md). The maps, the settings, the performance panel and the shared drawing.

- Maps: `minimap.gd` (the map is painted a chunk at a time into regions of 32 chunks, kept in the save: a chunk
  with its trees once it is PLANTED, the crowns its neighbours plant later added, again once SHAPED; the queue
  nearest to the player first — `ChunkStreamer._on_generated`, `_next_paint`; marks
  of what was placed, of sacks and of rafts and boats on water, except the one one sits in — `set_marks`, from
  `hud.gd`; teammates — `draw_mates` by `Team.mates`, see [territory.md](../territory.md);
  `shaders/map_ground.gdshader`), `map_view.gd` (full screen; a pinch moves the map after the middle of the
  fingers and scales around it, the wheel — around the cursor; a finger released over another button is
  forgotten too — `_input`), `src/client/game/markers.gd` (the player's markers; teleport from the «Testing»
  page).
- Settings: `src/client/settings.gd` (the saved settings and the switches of «Testing»: each module reads its
  values there; «Save» on «Testing» keeps the switches of `TEST_SAVED` in section `test` of `settings.cfg`, loaded
  at the next start, «Defaults» there puts them back and forgets them; «All survival» turns the `SURVIVAL` ones
  at once), `settings_menu.gd` (pages of rows «name ‹ value ›», sections parted by strips `{"section": icon, "title"}` → `Kit.section`; the settings' tabs «Game», «Interface», «Graphics», «Sound» (the music's and the sounds' volumes, each under its strip) and «Other» (the mods' files kept from servers and «Clear server data», where one's own mods go); «Game» ends with the section «Building»: «Things from the bag» — by blueprint (a door, a window or furniture is drawn into the blueprint) or at once (`build_things`), and «Ground under a figure» — level it (a figure drawn on uneven ground digs out
  the bumps and fills the dips under it) or as it lies (`build_level`, [../interaction.md](../interaction.md)); a tabbed page keeps one height on every tab, its longest section's (the window's, never its rows': a tab whose rows fit shows no scroll bar), and a taller tab scrolls in it; on a server the rows of day length, time of day, season and weather are faded with a note, the server's host sets them in its window; the version and «What's new» from
  `build_info.json`: also opened from the main menu, «Back» goes there; the changes are built by
  `CHANGES_STEP` while scrolling). With a newer build out (`src/client/net/updates.gd`) the page starts with its
  changes under the strip «Update <version>», then the ones that came since the build run before on this device
  under «New since <version>» (`user://versions.cfg`), then the rest, dimmed, under «Earlier»; «Update» beside
  «Back» reloads the web page or downloads the latest release's APK or PC archive (shot `ui-main-menu-changes-update`).
- Playtest keys (`Controls._playtest_keys`): Z — the next season, X — rain on/off, T — the clock ×100; only in
  developer mode (`Settings.testing_unlocked`) where the switches work (`Settings.may_cheat`), else nothing.
- Debugging: `perf_panel.gd` (F3; the graph button in the top row only with the setting «Interface» →
  «Statistics button», hidden by default, decision 186, `Hud.show_stats_button`; the panel is opened by F3 and
  by «Testing» → «Debug» → «Statistics»), `freeze_log.gd` and `gl_watch.gd` (`GlWatch.software()` — the
  browser draws without a video card: a fresh WebGL2 context with `failIfMajorPerformanceCaveat` is refused or
  the renderer is software — SwiftShader, WARP, llvmpipe; then under the buttons of the menu's first page — how
  to switch on graphics acceleration, decision 186, and in «Test data» — the line `Browser draws with`;
  `StartTimes.slow_code()` — the computer's browser runs code without compiling (scripts were built for more
  than 10 s: Edge with «Enhanced Security on the Web» does so, 27 s instead of 1.3 and a world in 387 s,
  2026-11-11), then under the buttons — how to switch this mode off; the «menu» mark in «Loading» is set only
  while a world is not requested, otherwise a menu opened from the game after the scene restarted counted as a
  step of loading; the freeze log: the game's parts, the engine — everything outside the measured parts, so
  every node with noticeable work in `_process` measures itself with `perf.note`: «rays», «sound», «fire
  shadows», «animals»; world generation by the server is the part «world», `Runner.took_us`, drawing, the
  browser's page and garbage collection, compiled shaders, data in the GPU; a line also tells in brackets what
  was around the player where that changed from the line below, `FreezeLog.scene`: daylight, weather, water,
  roof, cut view, fires, animals drawn, screen effects), `src/client/view/draw_census.gd`;
  «Test data» (`SettingsMenu.report_text`, tabs World · Mods (the mods on, their versions and bundles, the files' hash) · Device · Loading · Settings · Log by `report_lines`; «Copy tab» takes the tab shown, «Copy all» the whole report): the build, world, place, time, weather, settings, device,
  «Loading» (`start_times.gd`: in the browser the page, the download of wasm and pck — from the network or
  cache, the start of the engine; then graphics up to the engine's line «OpenGL API», which the page catches —
  `svStart` in the `head_include` of `export_presets.cfg`, compiling the scripts up to the static var of
  `main.gd`, the mods' data inside it — read by the static init of `materials.gd`, `Content.read_ms`,
  `load_ms`, the scene, the modules' `_ready`, the menu, the world from the choice in the menu — place, chunks,
  meshes and the first frames (the shader warm-up and calm frames); everything before the menu from opening
  the page), «Past runs» (the last ones in `user://starts.txt`); «Server» — requests to the rules through the
  protocol and their bytes, the encoding time (`Connection`, [network.md](../network.md)).
  The «Interface gallery» (`ui_gallery.gd`, «Testing» → «Debug», loaded only on opening; the settings window
  hides for that time so that its rows do not scroll under a finger): all kinds of window elements on the tabs
  «Buttons», «Rows», «Cells», «Fields», «Lists», «Look» — window buttons (plain, amber, unavailable, two-touch,
  green), small ones and with an icon, joined ones, tabs, a block in the corner, ground colours, the screen's
  octagonal buttons; settings rows, actions, explanations, places; cells with a number, a hand, a key, a bar,
  quality, pale, the chosen thing's chips, the weight gauge, the column of kinds of things; input fields;
  scrolled lists; text colours, the large font, frames and all `UiStyle.ICONS` icons. Everything is pressable,
  the line under the page says what was pressed; the gallery does not change the game. A new shared element is
  added here too. The shots `ui-gallery-<tab>` in `tools/shot/shots.gd`.
- Shared: `ui_style.gd` (it extends `ui_icons.gd`, the drawings of the icons, `ICONS`; panels, frames, buttons, the font; `accent(b)` — the amber «press» button, `arm` /
  `succeed` — red and green, `well()` — the shared sunken frame of text), `item_icons.gd` (item pictures
  `icons/<icon>.png` 12×12 and the icons of `assets/ui/`, among them the bare hands, `hand` (the right one) and
  `hand_left`, and the grey pictures of the character's empty slots, `slot_<place>`, shown faint; the path of an item's picture is looked up on disk
  once, `ItemIcons._paths`; an item that places a block and has no icon shows its material as a small cube
  in the items' style, cut from the terrain atlas once, `block_image`: the front from its side tile, a lid
  of two rows of its top tile going back up to the right, the right side in shade, an outline in a dark
  tone of the tile's mean colour), `hotbar_slot.gd`, `icon_tabs.gd`, `tab_row.gd`, `fact_chips.gd`,
  `scroll_column.gd` (a column of buttons: more than six or than fit in height beside the cells, `fit_height` —
  arrows at the top and bottom and a finger drag, like the hotbar's; the tabs of kinds `icon_tabs.gd` are on
  it), `drag_scroll.gd` (a drag over a ScrollContainer's list scrolls it, including one started on a button: as
  soon as the finger moves, the press of the list's buttons is released, and the finger's release presses
  nothing; a touch of a slider, a bar or an input field stays theirs; like a phone's lists, a flick flies on
  and slows by itself (`FRICTION`; a touch stops it and picks nothing), a pull past the top or the end stretches
  the list less and less (`PULL`) and springs back when let go (`SPRING`), a flick into an end bounces off it a
  little (`BOUNCE`); the mouse wheel glides an eighth of the list a notch and bounces too; `glide_to` glides the list to a given scroll, slowing as it comes (`GLIDE`), a touch stops it (`touched` counts the touches and wheel turns, so a caller gliding again gives way to them); a list whose rows fit
  neither scrolls nor stretches and leaves its wheel to the list around it; the stretch moves the content after
  each sort of the ScrollContainer, its scroll stays within bounds; the engine's own touch drag of the list is
  off; `DragScroll.attach`: every `Kit.scroll` (settings, testing, main menu pages, host and join windows,
  «Load world», «New world», the gallery), the bag, crafting, «Land», «Team», the server log). The crafting recipe list taller than four rows
  (`CraftPanel.ROWS`) or than the window's room scrolls.
