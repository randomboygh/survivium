# Interface and settings

Status: ACTIVE. A Russian copy: [ui_RU.md](ui_RU.md).

**Purpose.** A pixel interface after the mock-ups: the main menu over a drawn landscape and the loading screen,
«New world» and «Load world», the HUD (clock, the slice of levels, the panel, buttons), the bag window with
crafting and chests, maps, the death screen, settings and the «Testing» page, the performance panel and the
freeze log. The layout adapts to the screen's proportions and switches between touch and mouse by the last
input.

**The UI kit** (`src/client/ui/kit/`, decision 2026-11-11, option Б). Windows are assembled from ready parts,
not drawn anew; all the game's windows are already moved to the kit. A new window is made from the kit too,
and a new shared part is added to the kit and to the «Interface gallery».
- `kit.gd` — static parts: a window title, a caption, an explanation; a window button (plain, amber
  `accent_button`, with the plain one's states: lighter under the cursor, darker pressed, faded when disabled), a square one with an icon `icon_button`, one in the panel frame for the game screen
  `framed_button` (the HUD buttons, the strip's arrows), the switch `check` (`switch.gd`: in pixels: a pill track in a dark edge and a round knob in a thick one, off — dark track and pale knob on the left, on — dim amber track and amber knob on the right; the round ends are pixel circles drawn by pixel art's rules — even steps that never grow towards the diagonal, the same on every side (`_round`); inside its edge the track's ends follow the knob's steps (`_round_around`), so the room between them is one pixel all round — the text to its left); the input field `field` (the caret
  and tab switching in the browser — `TextField.fit`); column, row, inset; a scrolled list `scroll` (also by
  finger, `DragScroll`, with insets as in the settings: on the right as on the left, more only for a shown bar); the look of the screen's big buttons `octagon_look`,
  semi-transparent ones `see_through` (icon edged dark by `UiStyle.outlined`, like the letters), a colour sample `swatch`; the section strip `section` (a pale line with an icon and a name between groups: the chests in the inventory, the sections of the settings and of the server window). Sizes: `BUTTON_H` 30, `FIELD_H` 26, `SQUARE`
  32.
- `window.gd` — a window over the screen's shadow: `build(title)` gives the panel and the column `box`,
  `show_fitted()` lays out at every change of the screen; the panel is centred, and taller than the screen (the
  keyboard is up) — at the top. A window sets `layout(screen)` (the heights of lists) and `back()` (what Escape
  does too). «New world», «Load world», «Join», «Create a server», the sign and the gallery are made so.
  The window never changes its width while open: `build(title, gap, width)` fixes its column (the parts fill
  it, no part sized to the window's full width), and a list of `Kit.scroll` counts its bar's room in its width
  whether the bar shows or not (with no bar the rows fill that room). Every text put straight into the column
  gets the rows' room from the sides (`Kit.text_room`, `UiStyle.BAR_GAP`), so no words touch the frame; a text in
  a list that is not inset gets it by `Kit.text_room` too. When a part asks for other room after the window is
  laid out (a wrapped text measured anew at its width, a note shown), the window fits itself again.
- `shade.gd` — the shade behind a window, the pause menu and the sleep screen: as large as its parent but drawn
  over the whole window (`window_rect`), so a phone's camera cutout and a browser's toolbars, outside the safe
  rect the HUD is laid out in, are darkened too; the map and the death screen draw theirs with `window_rect`.
- `two_tap.gd` — two-touch buttons: the first paints red, the second does; with `wait` the redness fades by
  itself; `paint` — its own look of waiting (the build and farm palettes light like tabs, «Stop the server»
  changes its label).
- `choice_rows.gd` — rows «name ‹ value ›»: values, reading and writing, in a circle or to the edges (`stop`),
  straight to the edges (`direct`), skipping a value, «none» (`other`), inactive (`works`), an «open» button;
  focus by keys: up and down pick a row, left and right turn the values. A row whose values are only «off | on»
  (or «hidden | shown», `SWITCHES`) is a switch in place of the arrows and the value (a tap on it or on its name turns it, left turns it off, right
  on; `"switch": false` keeps the arrows): every on/off setting is a switch. A row that stops at its ends
  (`stop`, `direct`) has the arrow towards the end it is at disabled; the settings' scales (volume, sizes, speeds, quality, the caves' layers, `SettingsMenu.SCALES`) and the land's amounts in «New world» stop so, the rows of kinds (language, weather, the hour) go round. Settings, «Testing», «New world» and
  its mods, «Create a server».
- `fading_list.gd` — `FadingList`, a list of lines that come and go as notifications do: `add(line, before)`
  brings a line in its holder out of transparency, rising, while the list opens room for it; `drop(holder)`
  fades it up and the list closes up after it (`TIME` 0.35 s, `RISE` 8 px; the gap between lines is inside the
  holders); `shown()` — the holders not going. Out of the tree nothing moves (the tests). The toasts, the chat's
  lines and the server's notices to its host are such lists.
- `slot_strip.gd` — a strip of big cells between arrows: the hotbar (hands on the left, outside the strip; on a
  touch screen held upright only the left hand, and one more cell, unless «Interface» → «Second hand in portrait»
  shows it: `Hud.one_hand`), the
  build and farm palettes; the owner puts cells in `cells` and says how many things and cells there are
  (`set_counts`), the strip holds the first shown (`first`), arrows and a finger drag over a cell, and sends
  `scrolled`. `fitting` — how many cells fit.
- The gesture wheel is a round menu of its own kind, its buttons stay its own.

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
  saved: after the game restarts they are gone again), the logo's shudder and a scatter of feathers that then,
  swaying and turning, sink down among the fluff (`MainMenu._explode`); each touch is a light vibration, the
  burst a strong one (by the setting «Vibration»); after 12 s the sparrow flies back. In this developer mode
  the build number is written small under the logo, at the right edge (`MainMenu.version_text`, from
  `build_info.json`; «dev» without it; the shot `ui-main-menu-dev`). The pages in one panel: «Continue» (only
  over a running world — from the pause or the death screen: closes the menu, lit first), «Single player»,
  «Multiplayer», «Editor», «What's new» (the list of the build's changes, `MainMenu._open_changes`),
  «Settings», «Exit» → «Single player» (Play/Continue, New world, Load world, Back) and «Multiplayer» (Join,
  Create a server — PC only, on a phone a touch explains; on a server first «Back to the server»,
  «Disconnect»; while one's own server runs, «Single player», «Join» and «Disconnect» are closed: other
  bundles would load under the server); `main.restart()` reloads the scene; the world of a server one has
  joined loads at once), `join_screen.gd` («Join»: address, name, password, recent servers from
  `src/client/net/server_list.gd`; the fields and the recent servers inset as the settings' rows, the buttons flush; fields one under another — fits a phone held upright, with the keyboard up
  the panel goes to the top; the link `?server=` opens it with the address, a failed login — again with the
  reason), `host_screen.gd` («Create a server» on PC, two tabs `TabRow.tabs`: «Creation» — a world from the
  saved ones, a name, a password, «Access from the internet» (С7, the cloudflared tunnel); «Settings» —
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
  («New world»: seed, kind of world, generator settings with a map round the middle of the world, the start a dot on it (not round the start: the start moves with the biomes chosen, the land does not; laid out with the biomes of the bundles chosen there: `Biomes.refresh(only)`, the tables swapped in round each frame's rows by `Biomes.tables`/`use`, so the world behind keeps its own), the rows inset as the settings' (`UiStyle.inset`), the page «Mods» and a page per mod, its first row the mod as a whole switching all its bundles, `_whole_mod_row` (a switch keeps its place in the list: the page is made anew at the same scroll): under a dropped bundle the
  whole chain of the reason, `Mods.why`; when a world of the seed and settings is saved, a red note says
  «Create a world» makes it anew with the mods chosen now on a second tap, `_check_saved`,
  `SaveGame.replace_world` deletes the save), `world_list.gd` («Load world»; a world has a square trash button:
  the first touch paints it red, the second deletes, for the test world — resets; recent servers on the «Join»
  screen have the same, `ServerList.forget`), `death_screen.gd`.
- The game: `hud.gd` (the main screen; parts by topic, decision 168: `hud_parts.gd` — nodes and state, small
  details ← `hud_messages.gd` — the loading line, messages, the hint ← `hud_layout.gd` — the layout over the
  screen, the item panel, hands ← `hud_menus.gd` — the bag, statistics, the pause menu, land and team,
  settings ← `hud.gd` — assembly, frame, input; the interface's scale, `Hud.fit`: on a phone or a tablet a fraction of the screen's shorter side / 400 times «Interface size», on a computer a step of `Hud.PC_SCALES` (×1, ×1.5, ×2, ×2.5, ×3, ×4…) nearest to the shorter side / 480, moved by the size: a 1080 px screen gets ×2, its five sizes ×1 to ×3), `button_tips.gd` (hints of buttons with a mouse: the
  `tooltip_text` of the control under the cursor after 0.45 s beside the cursor, in the same panel and scale as
  the hint over the ground, above all windows and the main menu; Godot's own hints are switched off by
  `gui/timers/tooltip_delay_sec` in `project.godot`; on a touch screen and for a button whose label says the
  same, nothing; the hint over the ground on PC — only with «Debug hints»; the mouse wheel over a window or
  button does not scroll the item panel, `Hud.wheel_taken`), `chat_box.gd` (chat on a server, С6: the last
  lines in the bottom left corner above the joystick or the panel, in a `FadingList` growing up from its
  bottom: a new line comes up from transparency, and after 12 s (or pushed out by newer ones: 5 shown, 10 while
  the field is open) a line goes up into transparency like a notification; after one's own line is sent the
  last ones come back for 12 s; in single player one's own line goes into the chat at once,
  with no server; the field is opened by Enter or the chat button at the top — seen only on a server; while the
  field has the cursor, keys do not move the character, `Controls._typing`; a line said nearby (another's or one's own) is seen over
  the speaker's head too for 6 s in a pixel balloon, `UiStyle.balloon` with a stepped tail, `src/client/view/others.gd`), `gesture_wheel.gd` (the gesture circle, decision 183: a
  button with a palm in the top row next to the chat, the key C; in single player chat and gestures are hidden
  until the setting «Interface» → «Chat and gestures» is «always», `Hud.show_social`; eight round buttons with
  an icon and a word, the digits 1–8, a touch outside or Escape closes; only the circle under the icons is
  darkened (the edge dissolves by dithering over 4 pixels of the world, as large as the game draws them and on its grid), the world around is seen as it is; the icons have
  no buttons under them, the word under an icon lights under the cursor; the icons on the circle's buttons are
  at a whole number of screen pixels per icon pixel at any (even fractional) interface scale; the gesture
  icons are a fill with a dark one-pixel outline on all sides; [character.md](character.md)), `sign_window.gd`
  (the sign's window on a touch, decision 183: line fields, «Save», «Turn», «Close»; while a field has the
  cursor, keys do not move the character; in detail — [crafting.md](crafting.md)), `inventory_window.gd` and
  `craft_panel.gd` (the inventory window: character, bag, chest, station, crafting), `person_panel.gd` (the
  character in the window: slots in their places on the body — body, legs, shoes in the middle, a headdress at
  the top left, a bag on the back at the right, hands under them — tight, with no body lines; at the bottom of
  the bag's slot a loading bar by weight, like the torch's (`HotbarSlot.fill`, `fill_color`: green, amber at
  the limit, red when overloaded), «+24» in the top corner; beside it the ten skills in two columns in a
  separate subpanel: the name inside a scale of 10 divisions (by level, the skill only: a tool's strength is
  in the item's chips, `FactChips.power_hint` explains it by an example), with no heading; a thin line is the
  way to the next level; the hint — what the level gives and which tool in the hand the skill leads
  (`Tools.ROLE_OF`; in detail — [character.md](character.md), «Skills», the model —
  `docs/balance/GAME_BALANCE_DESIGN.md`); a touch of a hand is like a touch of a hand on the panel
  (`Hud.tap_hand`: the active hand, then the next tool), a touch of a clothes or bag slot takes off what is
  worn or puts on a fitting one from the bag, `InventoryWindow._tap_person`; in landscape it stands to the left
  of the bag, in portrait above it, and shows only on the «Inventory» tab). The window's tabs —
  «Inventory» and «Crafting», «Land» (only on marked land, `land_page.gd`) and «Team» (only on a server,
  `team_page.gd`), see `docs/systems/territory.md`. All rows of tabs (window, settings, «Testing») are one
  joined group one window button tall (`TabRow.tabs`, the chosen one amber, `light`); new tabs are made the
  same way. The scrolled rows of a window keep off the edges and the bar by `UiStyle.BAR_GAP` (`UiStyle.inset`:
  settings, «Testing», «Land», «Team»). The kit's rule: with no scroll the room on the right is the same as
  on the left and the rows reach it (everything in a list fills its width: `ChoiceRows` rows, the settings' grid, its action buttons, places and notes; no fixed-width piece left short of the right side);
  only a shown bar adds its own room (shown in the gallery's «Lists»); new pages are made the same way, tabs have no headings. The bag's cells
  show 4 whole rows (`InventoryWindow.ROWS`), fewer if the window does not fit, the rest scrolls — by a thin
  bar (`UiStyle.SCROLL_BAR`) and by a drag of a finger or mouse over the cells themselves (`drag_scroll.gd`;
  the cells are then chosen on release, `HotbarSlot.on_release`, and the drag chooses nothing); the crafting
  recipes scroll the same way. Chests in reach, and after them bags and chests lying in the bag (`_packed`,
  open ones `Inventory.open`, the icon — a sack or a chest) — in the same list under the bag, each with its own
  grid after a pale strip (the colour of the death screen's headings) with a schematic chest
  `UiStyle.icon("chest")` (`_chest_line`, insets `CHEST_GAP`); a bag or chest in a cell has an amber strip of
  how full it is (`Inventory.fullness`); what is worn is marked «W»; the chest's buttons (take, move) work with
  the one where a thing is chosen, otherwise with the nearest. Under them the panel of the chosen thing, of one
  height with a thing chosen and without: a picture and the name (the amount only if more than one), at the
  top right the lock of the first row (on: sorting and «all into the chest» do not touch the hotbar; off —
  everything that fits is sorted and moved), sorting (by hand and «by kind | by weight» together), groups with
  captions in a row (`FactChips.item_groups`: weight, food, bag, tool, weapon charges, light, resource), then
  one line of buttons: on the left a wide yellow button with an action icon (`InventoryWindow.USES`: take, eat,
  place, plant, put on, bandage, take off), for a light — a joined «take | place» (2/3 yellow and 1/3 plain), on
  the right, if a chest is near, «into the chest» (for a thing in the chest — «take from the chest»; the choice
  stays on the thing where it went), «all into the chest» and, if the chest holds something, «take all», a
  wrench «Repair» for a worn tool (at a repair station, for materials), «drop | drop all» and a trash can. A
  weapon with nothing to shoot (`ammo` not in the bag, `FactChips.unarmed`) is pale in the cells of the bag,
  hotbar and hands (`HotbarSlot.inactive`), in the panel — in the group «Charges» a red «none». A recipe in
  crafting is the same: the groups «Materials», «Not consumed», «At», «With» (tools), «Time», «Product»,
  «Byproduct» in a row; the recipe's name takes a line with no picture of its own and no «get» gift (the test's
  free things), otherwise the crafting window is wider than the bag; then one line: on the left a yellow «make»
  as wide as the bag's action button (`TabRow.WIDE`); if more than one can be made — «MAX» beside it, from five
  — and «×5» (then «make» is 2/3 of the width, they 1/3 each), on the right the stations in a row (hands, near
  ones, then far ones pale — as many as fit). The sorting by kind and the tabs go in the order of
  `Items.CATEGORIES`: stations, tools, light, gear, materials, blocks, food, healing, plants; the crafting
  recipes are sorted the same way. The action button on the game screen names what it will do now
  (`Controls.action_name`, once per `LABEL_TIME` by `WorldActions.front_kind` — the same choice that
  `act_in_front` makes, with no change of the world): «Drink» at water with an empty hand, «Fill with water»
  with an empty vessel, «Gather» at berries with a torch in the hand, «Dig» when everything around is
  gathered, «Chop», «Mow» (grass with hands — «Gather»), «Hit»; for a building item, food and healing — «Place»,
  «Plant», «Put», «Eat», «Bandage»; if there is nothing in front — by the tool in the hand («Fish», «Throw»,
  «Shoot»…), otherwise «Gather», and shows its picture (a hand with no item); the label over the hotbar is in
  the same frame as the clock and of the same height (`Hud.SLEEP_SIZE`): the bag's gauge, a division per cell,
  all divisions of one width with any bag (`Hud.BAG_DIVISION` 6 px, free ones slightly lighter than the pit:
  with a backpack there are more and the label is longer, `_fit_bag_meter`), the occupied ones filled with a
  light shift to warm towards the end (`Hud.bar_shade`), on top — only the weight «35 / 40 kg»
  (`UiStyle.draw_weight`, red when overloaded). The clothes and bag slots on the character are chosen by the
  first tap (the panel says what is there), the next changes what is worn for the next thing for that place
  from the bag, after the last takes it off (`_next_wear`). The clock: the season, the air temperature
  (`Hud.air`, `Warmth.air` without fires and clothes; the line is updated 4 times a second, `CLOCK_EVERY`), the
  day, the time and the sleep button «zz» lying over the right edge of the clock flush with the frame
  (`_align_clock`). Manual sorting does not drop the cell's choice and is switched off when the window closes.
  Build mode (`build_bar.gd`, [interaction.md](interaction.md)): the hotbar is replaced by a palette of all
  the bag's blocks and things in one row, made as a hotbar without hands (the same cells, arrows, finger
  scrolling and width: up to 10 cells, in portrait up to 6; no filters yet; the same for farm mode), above it a
  panel in one row, buttons the size of ordinary ones: the figure in a circle (line → plane → square → cube) |
  «level the ground»; the kind of block in a circle (block → slope from below → slope from above → steps) |
  «turn»; the figure's height (1–6, its own for each: floor 1, walls 3, cube 5) | the walls' thickness (1–4,
  a floor has none); draw/erase (erasing is red) | «clear blueprints» (a second touch within 3 s: the button
  turns red, a notification); exit (B) separately. On a narrow screen the kind of block goes in a separate row
  above the panel. Hands are not shown, the chosen cell is the hand at work; the bag's label is hidden (the
  palette counts blocks); the action button «Build» («Level» when levelling; always 88×88, words wrap inside)
  is pressed once and held pressed («Stop») while it builds (released in the same frame building stops:
  `Hud.update_state`). In the bag, blocks and everything that is placed have a wide button «Build» (a hammer):
  it enters the mode. Notifications (`Hud.toast`) — a list of three under the state: a new one floats to the
  end from transparency, rising, and the oldest (by time or when the list overflows) goes up into
  transparency, and the list closes up after it (`FadingList`). Under them, a list of its own for the server's
  notices to its host (`Hud.server_note`, the event `noted`: who joined for the first time or came back, lost
  the connection, left, was disconnected or banned by a host, was not let in and why): cool-tinted panels with
  the server's mark, three at most, 6 s each. Both lists are drawn over the windows and their shade (`TOASTS_Z`), taps go through them. `vitals_panel.gd` (the state in the
  top left corner: a thick health bar with a thinner stamina bar under it, then standing bars for satiety,
  water, warmth and sleep, each only while it is low (`VitalsPanel.critical`; all of them while the bag is
  open), and a column of what hinders the body — wet, out of breath, overloaded, `VitalsPanel.debuffs_of`;
  the panel is as wide as what it shows), `sleep_screen.gd`
  (darkening in sleep: a tap, a step or a jump wakes, `Protocol.SLEEP`; the moon «Go to sleep» — on the HUD's
  clock), `body_feedback.gd`, `sound_marks.gd` (marks of sounds' directions), `vibration.gd`.
- Maps: `minimap.gd` (the map is painted a chunk at a time into regions of 32 chunks, kept in the save; marks
  of what was placed, of sacks and of rafts and boats on water, except the one one sits in — `set_marks`, from
  `hud.gd`; teammates — `draw_mates` by `Team.mates`, see [territory.md](territory.md);
  `shaders/map_ground.gdshader`), `map_view.gd` (full screen; a pinch moves the map after the middle of the
  fingers and scales around it, the wheel — around the cursor; a finger released over another button is
  forgotten too — `_input`), `src/client/game/markers.gd` (the player's markers; teleport from the «Testing»
  page).
- Settings: `src/client/settings.gd` (the saved settings and the switches of «Testing»: each module reads its
  values there), `settings_menu.gd` (pages of rows «name ‹ value ›», sections parted by strips `{"section": icon, "title"}` → `Kit.section`; the settings' tabs «Game», «Interface», «Graphics», «Sound» (the music's and the sounds' volumes, each under its strip) and «Other» (the mods' files kept from servers and «Clear server data», where one's own mods go); a tabbed page keeps one height on every tab, its longest section's, and a taller tab scrolls in it; on a server the rows of day length, time of day, season and weather are faded with a note, the server's host sets them in its window; the version and «What's new» from
  `build_info.json`: also opened from the main menu, «Back» goes there; the changes are built by
  `CHANGES_STEP` while scrolling).
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
  browser's page and garbage collection, compiled shaders, data in the GPU), `src/client/view/draw_census.gd`;
  «Test data» (`SettingsMenu.report_text`): the build, world, place, time, weather, settings, device,
  «Loading» (`start_times.gd`: in the browser the page, the download of wasm and pck — from the network or
  cache, the start of the engine; then graphics up to the engine's line «OpenGL API», which the page catches —
  `svStart` in the `head_include` of `export_presets.cfg`, compiling the scripts up to the static var of
  `main.gd`, the mods' data inside it — read by the static init of `materials.gd`, `Content.read_ms`,
  `load_ms`, the scene, the modules' `_ready`, the menu, the world from the choice in the menu — place, chunks,
  meshes and the first frames (the shader warm-up and calm frames); everything before the menu from opening
  the page), «Past runs» (the last ones in `user://starts.txt`); «Server» — requests to the rules through the
  protocol and their bytes, the encoding time (`Connection`, [network.md](network.md)).
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
  `icons/<icon>.png` 12×12 and the icons of `assets/ui/`; the path of an item's picture is looked up on disk
  once, `ItemIcons._paths`), `hotbar_slot.gd`, `icon_tabs.gd`, `tab_row.gd`, `fact_chips.gd`,
  `scroll_column.gd` (a column of buttons: more than six or than fit in height beside the cells, `fit_height` —
  arrows at the top and bottom and a finger drag, like the hotbar's; the tabs of kinds `icon_tabs.gd` are on
  it), `drag_scroll.gd` (a drag over a ScrollContainer's list scrolls it, including one started on a button: as
  soon as the finger moves, the press of the list's buttons is released, and the finger's release presses
  nothing; a touch of a slider, a bar or an input field stays theirs; `DragScroll.attach`: the bag, crafting,
  «Load world», «New world», settings, «Land», «Team»). The crafting recipe list taller than four rows
  (`CraftPanel.ROWS`) or than the window's room scrolls.

**Data.** The interface's texts are keys `[…]` in the UI code, translated by `lang/<code>.yaml`
([lang.md](lang.md)); item pictures are with their bundles; the loading tips — `MainMenu.TIPS`; the sky's
colours by the clock — `MainMenu.SKIES`.

**Pitfalls**
- After getting new assets (fonts, textures) run `--import` again, otherwise the HUD scripts fall with null
  errors that look like code bugs.
- The hotbar and the bag window listen to `Character.state_changed` (and chests to their own `changed`) and
  refresh at the end of the frame once, however many server events come (`Hud._counts_later`,
  `InventoryWindow._refresh_later`); a direct call of `refresh()` / `refresh_counts()` refreshes at once. The
  crafting tab piles up changes the same way (`CraftPanel.refresh`).
- A JS snippet run from GDScript must be strict and must not touch `arguments` in a wrapper with named
  parameters: that makes an object per call (`gl_watch.gd`).
- A touch in the browser arrives also as mouse motion (see [interaction.md](interaction.md)).
- While shaders warm up, the HUD is hidden by the loading screen; the interface elements for the warm-up are
  on the world's canvas.
- While a world is not chosen, `Main.world` is empty and `_process` only watches the screen's safe area: the
  interface modules must not wait for a world on the menu.
- An input field on a phone in the browser opens the keyboard only with `html/experimental_virtual_keyboard=true`
  in `export_presets.cfg` (a hidden `<input>` over the canvas).
- Every input field of the interface (the sign, chat, joining a server, the server and its commands, the
  world's seed) passes through `src/client/ui/text_field.gd` (`TextField.fit`): on focus the caret stands after
  the text and nothing is selected; the caret is drawn while the field is edited (`caret_force_displayed`: in
  the browser the page's focus is on the keyboard's hidden field, and without the window's focus `LineEdit`
  hides the caret); in the browser, when the tab is hidden or shown again, the field releases the keys and the
  keyboard closes, so that the next touch opens it anew (on Android after a tab switch letters did not reach
  the field). While the keyboard is up (the visible area is lower than the tallest at this width,
  `window.survivium_tabs.up`), a touch does not give the canvas the page's focus (`tools/web_patch.py`): the
  keyboard does not close under a finger on a button or another field, does not blink on a touch of the field
  being written in, and the window does not shift under a finger. A touch begun beside the field being
  written in (on a button — after its action, on the world, on an empty place of the window) releases the field
  when the finger is lifted, and the keyboard closes; one begun on the field never releases it, wherever the
  finger ends up, when the keyboard has shifted the window. The chat opens with the field in editing, and the
  keyboard rises at once. When the phone itself has put the keyboard away, a touch gives the canvas the focus,
  as in the engine: a focus left at the hidden field did not open the keyboard on the next touch (2026-11-10).
  The keyboard's fields are marked `autocomplete="off"` so that the browser does not offer passwords on them,
  and the text is 16 px so that the iPhone does not zoom the page. The iPhone opens the keyboard only for a
  field that got focus in the touch handler itself, while the engine gives focus a frame later: on the iPhone a
  finger lifted from a field that asked for the keyboard gives the hidden field focus once more
  (`tools/web_patch.py`; nothing changes on Android). The chat button on the iPhone opens the field with no
  keyboard: it is opened by a touch of the field.
  The Enter of a phone's keyboard («→», «Done») was not heard by the engine: it listens to keys only on the
  canvas, and the keyboard's single-line field does not change on Enter. `tools/web_patch.py` (`VK_ENTER`)
  passes this field's Enter to the canvas as a press and an immediate release (and a `beforeinput` with a line
  break — from keyboards with no key code), so the chat is sent and the login field goes to the next
  (2026-11-11). A new input field goes through `TextField.fit` too.
- The buttons of windows with input fields (the sign, chat, «Join», «Start the server», «Create a world») act
  on release, like all buttons: the keyboard under a finger does not close, and the button does not run away.
- Under the sign's window the world is not touched: a touch does not go to the world (`Hud.covers`), a drag
  ends, an action button held when the window opened does nothing (`controls.gd`).
- The canvas in the browser is fixed (`#canvas{position:fixed}` in `head_include`), and after the visible area
  changes (`visualViewport` resize: the keyboard, the browser's bars) the page sends `resize` after 0.1 and
  0.7 s and, if there is no keyboard, scrolls to the top: otherwise after the keyboard the game stayed shifted
  under the browser's bars. The key log (a test setting) shows the sizes too: `in` the window, `sy` the scroll,
  `vv` the visible area and its top, `cv` the canvas; `page` — the window in focus (`F`), the user's touch now
  (`A`) and was (`a`).
- `assets/web/keyboard.html` is laid out beside the game (`/keyboard.html`): a page without the game opens the
  phone's keyboard in different ways (as the engine does: focus of the hidden field a frame later, the canvas
  takes focus on a touch; right in the touch handler; a frame later without the canvas's focus) and by the
  height of the visible area writes whether the keyboard rose. It is used to check what the phone's browser lets
  through before and after leaving it.

**Tests.** There are no unit tests of the interface; `tests/browser_smoke.mjs` opens the build in Chrome as a PC,
as a phone (DPR 3, touches) and as a phone held upright by the link `?server=` (the «Join» screen is on
screen, the name typed, a login to a nonexistent server returns the screen with the reason) and fails on SCRIPT
ERROR, SHADER ERROR, Parse Error and the errors `Invalid call/access/get/set`; the screenshots of
`tools/shot.gd` (`--phone` — the phone's layout).

**More.** `plan/design/ui.md` (mock-ups and decisions on the interface), screenshots `survivium-builds/ui/`.
