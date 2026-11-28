# The game screen: HUD, windows

Part of [Interface and settings](../ui.md). The HUD and the windows opened in the game.

- The game: `hud.gd` (the main screen; parts by topic, decision 168: `hud_parts.gd` — nodes and state, small
  details ← `hud_messages.gd` — the loading line, messages, the hint ← `hud_layout.gd` — the layout over the
  screen, the item panel, hands ← `hud_menus.gd` — the bag, statistics, the pause menu, land and team,
  settings ← `hud.gd` — assembly, frame, input; the interface's scale, `Hud.fit`: on a phone or a tablet a fraction of the screen's shorter side / 400 times «Interface size», on a computer a whole step of `Hud.PC_SCALES` (×1, ×2, ×3, ×4…) nearest to the shorter side / 1080, moved by the size and never under ×1: a 1080 px screen gets ×1 at «Normal», ×2 and ×3 above it, the two smaller sizes are ×1 there too and get smaller only on larger screens; the world's «Scale» in «Graphics» moves its whole scale by whole steps too, `PixelView.pc_step`, ×1 to ×5 on 1080 px), `button_tips.gd` (hints of buttons with a mouse: the
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
  icons are a fill with a dark one-pixel outline on all sides; [character.md](../character.md)), `sign_window.gd`
  (the sign's window on a touch, decision 183: line fields, «Save», «Turn», «Close»; while a field has the
  cursor, keys do not move the character; in detail — [crafting.md](../crafting.md)), `inventory_window.gd` and
  `craft_panel.gd` (the inventory window: character, bag, chest, station, crafting), `person_panel.gd` (the
  tab «Character» of the window: the figure drawn big in the middle, `figure_stage.gd` (`FigureStage`, the same frame,
  size and arrows as on the «Character» tab of a new game), `FigurePreview` on its stand in what it
  wears and its looks, `Figure.dressed`, with what its hands hold as in the world (`FigurePreview.hold`, the
  whole frame's width shown so a scythe fits) and a short shadow to the north-west on the stand; turned through
  eight directions by a drag across it, a tap on a half or the arrows in the stage's bottom corners (no thing
  held reaches there); the slots of what is worn down the left — head, body, legs, feet, as high as on
  the figure — and the bag on the back and the two hands down the right; at the bottom of the bag's slot a
  loading bar by weight, like the torch's (`HotbarSlot.fill`, `fill_color`: green, amber at the limit, red
  when overloaded); under the figure (beside it in landscape, `PersonPanel.set_wide`) the skills in a
  separate subpanel, three columns (two beside): the name inside a scale of divisions by level (the skill
  only: a tool's strength is in the item's chips, `FactChips.power_hint` explains it by an example), with no
  heading; a thin line is the way to the next level; the hint — what the level gives and which tool in the
  hand the skill leads (`Tools.ROLE_OF`; in detail — [character.md](../character.md), «Skills», the model —
  `docs/balance/GAME_BALANCE_DESIGN.md`); a touch of a hand is like a touch of a hand on the panel
  (`Hud.tap_hand`: the active hand, then the next tool), a touch of a clothes or bag slot takes off what is
  worn or puts on a fitting one from the bag (the one chosen on «Bag» first), `InventoryWindow._tap_person`;
  the panel at the bottom with the chosen slot or stack is shared by «Character» and «Bag»; a window too
  short draws the figure smaller, `PersonPanel.shrink`, and past that the tab scrolls). The window's tabs —
  «Character», «Bag» and «Craft», «Land» (only on marked land, `land_page.gd`) and «Team» (only on a server,
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
  the one where a thing is chosen, otherwise with the nearest. A tap on a storage in the world (`HudMenus.open_prop` → `show_chest`, as the finger lifts: `Controls._prop_press`) opens the bag as before and glides the list down until that storage's strip is at the top, as far as the list scrolls (`_glide_to_chest`, `DragScroll.glide_to`: it waits till the strip is laid out under the bag's slots, not at the top where a strip just made sits, and the bar's range has caught up, then keeps the list there for `GLIDE_WAIT` ms, gliding again whenever it is not; a finger or the wheel on the list stops it, `DragScroll.touched`). Under them the panel of the chosen thing, of one
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
  (`Controls.action_name`, once per `LABEL_TIME` by `WorldActions.front_kind`, and when the hand's thing or the mode changes; a change of the bag alone leaves it for `Hud.ACTION_NAME_MS`, since a look ahead costs ~0.5 ms on a PC; `front_kind` takes the kind by `_choice_kind`, which stops at the first grass worth more than the best tree or bush where `front_choice` ranks every cell ahead — the same choice that
  `act_in_front` makes, with no change of the world): «Drink» at water with an empty hand, «Fill with water»
  with an empty vessel, «Gather» at berries with a torch in the hand, «Dig» when everything around is
  gathered, «Chop», «Mow» (grass with hands — «Gather»), «Hit», «Pick up» (a beast's body before the feet); for a building item, food and healing — «Place»,
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
  Build mode (`build_bar.gd`, [interaction.md](../interaction.md)): the hotbar is replaced by a palette of all
  the bag's blocks and things in one row, made as a hotbar without hands (the same cells, arrows, finger
  scrolling and width: up to 10 cells, in portrait up to 6; no filters yet; the same for farm mode), above it a
  panel in one row, buttons the size of ordinary ones: the figure in a circle (line → plane → square → cube) |
  «level the ground»; the kind of block in a circle (block → slope from below → slope from above → steps; no
  «turn» button since 2026-11-26: a double tap turns a lone slope's ghost, Y on PC); the figure's height (1–6, its own for each: floor 1, walls 3, cube 5) | the walls' thickness (1–4,
  a floor has none); undo ↶ | redo ↷ of the blueprint (Ctrl+Z, Ctrl+Y or Ctrl+Shift+Z on PC; dimmed when
  there is nothing to undo or redo, 2026-11-26); draw/erase (erasing is red) | «clear blueprints» (a second touch within 3 s: the button
  turns red, a notification); exit (B) separately. On a narrow screen the kind of block goes in a separate row
  above the panel. Hands are not shown, the chosen cell is the hand at work; the bag's label is hidden (the
  palette counts blocks); the action button «Build» («Level» when levelling; always 88×88, words wrap inside)
  is pressed once and held pressed («Stop») while it builds (released in the same frame building stops:
  `Hud.update_state`: the action button and the sleep screen every frame, the rest of the state every
  `STATE_EVERY` 0.1 s). In the bag, blocks and everything that is placed have a wide button «Build» (a hammer):
  it enters the mode. Notifications (`Hud.toast`) — a list of three under the state (the toasts said in a frame are shown at its end, only the last three of them): a new one floats to the
  end from transparency, rising, and the oldest (by time or when the list overflows) goes up into
  transparency, and the list closes up after it (`FadingList`). Under them, a list of its own for the server's
  notices to its host (`Hud.server_note`, the event `noted`: who joined for the first time or came back, lost
  the connection, left, was disconnected or banned by a host, was not let in and why): cool-tinted panels with
  the server's mark, three at most, 6 s each. Both lists are drawn over the windows and their shade (`TOASTS_Z`), taps go through them. `vitals_panel.gd` (the state in the
  top left corner: a big heart and health as a row of rounded cells, `Vitals.CELL` = 10 health each, as many
  as `Vitals.most` holds (more with Hardiness), then golden ones for `Vitals.extra` (the row grows), with
  a thinner stamina bar under it, then standing bars for satiety,
  water, warmth and sleep, each only while it is low (`VitalsPanel.critical`; all of them while the bag is
  open), and a column of what hinders the body — wet, out of breath, overloaded, `VitalsPanel.debuffs_of`;
  the panel is as wide as what it shows), `sleep_screen.gd`
  (clear, over the whole screen in sleep: a tap, a step or a jump wakes, `Protocol.SLEEP`; the picture
  dreams meanwhile, `CameraRig.dream`: grade.gdshader `dream` makes bright things glow, sinks the colours
  halfway into a pale blue, darkens it towards a deep blue, blurs and darkens the edges, the middle sharp; it eases in over `DREAM_IN` seconds
  and out over `DREAM_OUT`; the moon «Go to sleep» —
  on the HUD's clock), `body_feedback.gd`, `hotbar_snow.gd` (snow settling on the hotbar's top edge, `AirEffects.hotbar_snow`), `sound_marks.gd` (marks of sounds' directions), `vibration.gd`, `haptics.gd` (what the phone buzzes for: `docs/systems/character.md`).
