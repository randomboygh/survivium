# The UI kit

Part of [Interface and settings](../ui.md). The parts windows are assembled from.

**The UI kit** (`src/client/ui/kit/`, decision 2026-11-11, option Б). Windows are assembled from ready parts,
not drawn anew; all the game's windows are already moved to the kit. A new window is made from the kit too,
and a new shared part is added to the kit and to the «Interface gallery».
- `kit.gd` — static parts: a window title, a caption, an explanation; a window button (plain, amber
  `accent_button`, darker pressed, faded when disabled, not lit under the cursor: a tap leaves it there), a square one with an icon `icon_button`, one in the panel frame for the game screen
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
