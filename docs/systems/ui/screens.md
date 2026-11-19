# Screens: main menu and loading

Part of [Interface and settings](../ui.md). Files of the screens before the game.

**Files** (`src/client/ui/`, except where noted)
- Screens: `main_menu.gd` (parts by topic, decision 168: `menu_backdrop.gd` — the landscape, sky, sparrow and
  the burst of feathers ← `menu_loading.gd` — the loading screen ← `menu_pages.gd` — pages, buttons, screens
  over the menu, layout ← `main_menu.gd` — assembly, frame, keys; the first screen over a landscape in the
  colours of the time of day by the device's clock — a sun by day, a moon and stars by night; the world behind
  the menu is not built: `Main.begin_world` starts loading only when the player has chosen a world —
  «Play/Continue», a world from «Worlds» or «New world»; another world — a restart of the scene, which at once
  opens the loading screen. The loading screen in place of the menu: a map around the start with the seed,
  under it a tip (the height by the longest, the text centred), below a bar in two lines — what is being done,
  seconds and percent — and a cross to cancel: `Main.cancel_loading` restarts the scene with no world, the menu
  opens on the page it came from (`MainMenu.back_to`). The bar goes evenly: the parts of loading (the steps of
  `start_world`, the near chunks, the shader warm-up, the first frames) take the share they took by time last
  time (`StartTimes.part_shares`, `user://load_parts.cfg`). While shaders warm up, the world is not drawn, and
  the loading screen does not leave until the warm-up ends and the calm first frames pass
  (`MainMenu._settle`). The logo stands at its own height of the screen (`TITLE_AT`), the menu under it; a page
  that does not fit (landscape, a large interface) stands beside the logo if the width allows, or the logo
  rises to the top and the buttons scroll in the panel (`MenuPages._fit`); a flock of birds flies at one speed
  on any screen (`FLOCK_SPEED`); «Play/Continue» in two lines — the seed, the kind of world and the day, as in
  «Load world». An Easter egg: 10 touches in a row on the sparrow on the logo — a burst of feathers, a flash,
  the «Testing» buttons (a flask icon and a pause-menu line, `Settings.testing_unlocked`, static: it holds on
  a move to another world, to a server and on creating a server; before that they are not there, and it is not
  saved: after the game restarts they are gone again; the switches kept by «Save» of «Testing» are used
  only in this mode: loaded but not applied before it, applied at once when the egg turns it on,
  `Settings.set_testing`), the logo's shudder and a scatter of feathers that then,
  swaying and turning, sink down among the fluff (`MainMenu._explode`); each touch is a light vibration, the
  burst a strong one (by the setting «Vibration»); after 12 s the sparrow flies back. In this developer mode
  the build number is written small under the logo, at the right edge (`MainMenu.version_text`, from
  `build_info.json`; «dev» without it; the shot `ui-main-menu-dev`). The pages in one panel: «Continue» (only
  over a running world — from the pause or the death screen: closes the menu, lit first), «Single player»,
  «Multiplayer», «Editor», «What's new» (the list of the build's changes, `MainMenu._open_changes`; a red dot in its corner while a
  newer build is out, `_update_dot`, shot `ui-main-menu-update`),
  «Settings», «Exit» → «Single player» (Play/Continue, New game, Load a game, Back) and «Multiplayer» (Join,
  Create a server — PC only, on a phone a touch explains; on a server first «Back to the server»,
  «Disconnect»; while one's own server runs, «Single player», «Join» and «Disconnect» are closed: other
  bundles would load under the server); `main.restart()` reloads the scene; the world of a server one has
  joined loads at once), `join_screen.gd` («Join», two tabs `TabRow.tabs`: «Character» — `character_page.gd`, the name, opened first while no
  name is kept, Enter in the name goes on to «Server»; «Server» — address, password, recent servers from
  `src/client/net/server_list.gd`; the fields and the recent servers inset as the settings' rows, the buttons flush; fields one under another — fits a phone held upright, with the keyboard up
  the panel goes to the top; the link `?server=` opens it with the address, a failed login — again with the
  reason), `host_screen.gd` («Create a server» on PC, four tabs `TabRow.tabs`: «Character» — the host's `character_page.gd`; «World» — «New world…» (opens
  `world_setup.gd` over it without «Character» (`with_character` false, titled «New world»), its button «Choose this world»; the world set up comes first in
  the list and the server makes it with its mods on start, over a save of its seed only after the setup's
  second tap) over the saved worlds, a button each; «Server» — a name, a password, «Access from the internet» (С7, the cloudflared tunnel); «Settings» —
  everything else the server takes (`Config` and its `rules`): the port, players, how often to save, the length
  of a day, «Real weather outside» (`Config.real_weather`), «Animals attack», «Tool wear», PvP, damage in
  combat, the newcomer's shield, how long combat lasts, land (lands first, per level, reach, levels, when
  abandoned, the step and kind of decay), «Defaults» (two touches); the values from `user://server.cfg`
  (`LocalHost.server_settings`), a file value not in the list is put into the list; «Start the server» under
  both tabs → `ServerLink.host_server`; while it runs — the port and players, the home network's addresses, the tabs
  «Server», «Settings» and «Access»; «Server»: «Copy the address», «From the internet:» (the tunnel's address, «still
  starting…» or why not) and «Copy the link», players with «Kick» and «Ban» (two touches), the log (12 lines) and the
  command field; «Settings»: the same rows as before it starts, each change made at once
  (`ServerMain.apply_settings`, the port faded until a restart), the sections parted by `Kit.section`; «Access»: «Whitelist only», the list with «Remove» and the field «Add», the banned with
  «Unban» and the field «Ban» (the same commands `whitelist`, `ban`, `unban`, `Server.access`); under all
  «Play», «Stop the server» (two touches), «Back»; the same window is the «Server» item in the pause menu;
  taller than the screen — it scrolls, the bar does not cover the rows, `UiStyle.bar_room`; the rows inset as the settings', `UiStyle.inset_room`), `world_setup.gd`
  («New game», two tabs: «Character» — `character_page.gd`, taking the room of «World», the figure where the map is;
  «World» — seed, kind of world, generator settings with a map round the middle of the world, the start a dot on it (not round the start: the start moves with the biomes chosen, the land does not; laid out with the biomes of the bundles chosen there: `Biomes.refresh(only)`, the tables swapped in round each frame's rows by `Biomes.tables`/`use`, so the world behind keeps its own), the rows inset as the settings' (`UiStyle.inset`), the page «Mods» and a page per mod, its first row the mod as a whole switching all its bundles, `_whole_mod_row` (a switch keeps its place in the list: the page is made anew at the same scroll): under a dropped bundle the
  whole chain of the reason, `Mods.why`; when a world of the seed and settings is saved, a red note says
  «Create a world» makes it anew with the mods chosen now on a second tap, `_check_saved`,
  `SaveGame.replace_world` deletes the save), `world_list.gd` («Load a game»; a world has a square trash button:
  the first touch paints it red, the second deletes, for the test world — resets; recent servers on the «Join»
  screen have the same, `ServerList.forget`), `death_screen.gd`. `character_page.gd` («Character», stage 3 of plan/mvp.md: a character belongs
  to its world): `figure_preview.gd` (the player's sheet, `Figure`, built a part of a row a frame, drawn big,
  breathing, in the colours of the looks by `figure_preview.gdshader`; a drag or a tap on a side turns it through
  eight directions, the keys left and right too while no row is picked) beside or over its rows: the name
  (`ServerList.player_name`, kept as typed), then the looks (`Looks`, `ChoiceRows`: hair style, hair colour,
  skin, eyes, face, on the face; kept on the device, `ServerList.player_looks`; up and down pick a row,
  `CharacterPage.key`). A new character takes them, one met again keeps its own. Shots `ui-setup-character`,
  `ui-setup-looks`, and the looks in the world `people-looks`.
