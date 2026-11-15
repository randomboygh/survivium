# Data, pitfalls, tests

Part of [Interface and settings](../ui.md). Texts, the pitfalls of the keyboard and the browser, the tests.

**Data.** The interface's texts are keys `[…]` in the UI code, translated by `lang/<code>.yaml`
([lang.md](../lang.md)); item pictures are with their bundles; the loading tips — `MainMenu.TIPS`; the sky's
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
- A touch in the browser arrives also as mouse motion (see [interaction.md](../interaction.md)).
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
