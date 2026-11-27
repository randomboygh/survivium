# The in-game content editor: state and what is left

Status: DONE (all seven steps of the plan are in the game; the user's phone checks under «Left» stay open). It was
the hand-off note (2026-11-16) of the thread «Сделать внутриигровой редактор» for the thread that continued it. Stage 2 item 3 of `plan/mvp.md` (decision 186, 11А 12А 13А).

## The user's picks (2026-11-16)

- 1Б+А: «Editor» in the main menu and in the pause menu (named just «Editor», `[editor]`).
- 2А: built-in records are changed only by patches in one's own mod; the game's files are never written.
- 3Б: several own mods; the one saves go into is picked on top of the editor («+» makes one).
- 4А: the voxel editor paints slice by slice on a flat grid with a turning 3D preview (models are PNG sheets
  of slices, `VoxelModel.from_image`).
- Phone first: one column (12А), portrait 2608×1200; screenshots of every step in the thread
  (`survivium-builds/mods/editor/`).

## Done

- Step 1, PR #708: `Yaml.write` (every data file round-trips), `src/shared/content/own_mods.gd` (where own
  mods lie: `content/` beside the game, the app folder on Android, `user://content` elsewhere through
  `ModFiles.find_extra`; `make`, `put`, `patch`, `remove`; `own: true` in mod.yaml), the read-only window.
- Step 2, PR #709: `src/shared/content/content_edits.gd` (`check`, `data_of`, `changed`, `save` — own record
  in place, else a patch — `undo`), `src/client/ui/editor/record_form.gd` (switch, row of values, text field;
  lists and mappings as one line of YAML), `content_editor.gd` (mod row with «+», Save, Undo, `join` puts the
  mod's bundles into `Content.BUNDLES` and `game.world_mods`, then `ModReload.reload`), main menu button.
  Tests `tests/unit/editor_test.gd`; shots `editor-items`, `editor-wolf`, `editor-wolf-wrong` (`editor`,
  `record`, `editor_mod`, `edit`, `edit_check` keys of `tools/shot/shots.gd`).

- Step 3: `ContentEdits.copy` («Copy», a new record of the mod from any), `delete` («Delete» one's own record
  with its phrases, «Reset» one's patch), title and description fields on top of the form written as the
  mod's phrases (`key_of`, `lang/<code>.yaml`, English too while missing); undo takes back every file of a
  write. Shots `editor-copy-row`, `editor-dog` (`copy`, `copy_make`, `texts` keys). Field names are still
  the YAML's: the user was asked about translated names in the thread.

- Step 3b, PR #712: field names in the game's language with a line under each (`field_names.gd`).
- Step 4: «Load PNG» on picture fields (`ContentEdits.PICTURES`, `picture`, `picture_path`;
  `picture_pick.gd` native dialog or the page's file input; `Content.asset` reads `<mod>:<name>`). Shot
  `editor-picture` (`picture`, `scroll_to` keys).
- Step 5: the voxel model editor (4А): «Edit model» on `items.model` (`ContentEdits.MODELS`) opens
  `voxel_editor.gd` (`VoxelSheet` the PNG of slices with undo, `SliceGrid` painting with the level under it
  faint, `VoxelPreview` turning in its own world); saved through `ContentEdits.picture`. Shots
  `editor-voxel`, `editor-voxel-new` (`voxel`, `voxel_level`, `voxel_paint`, `voxel_turn`, `voxel_save`).
- Step 6: «Export zip» / «Import zip» on top of the editor (`ModImport.pack`, `offer` — browser download,
  native save dialog — `unpack_bytes` with `refuse` for mods not one's own; `PicturePick.pick(done, true)`).
  Shot `editor-zips` (`zips` key). Android's save dialog writing to a content:// path is untested on a phone.

- Step 7: an author's own mod put on a server (`Protocol.MOD_PUT`, `src/client/net/mod_put.gd`,
  `Requests._mod_put`, `Server.put_mod`, `ModZip.unpack_mod`; zip code moved to
  `src/shared/content/mod_zip.gd`). Joined to a server far away, the editor's saves go to the server (not
  read here): it unpacks the mod in place of its copy, joins its bundles to the world's and sends the files
  to every player. Rights (the user's pick Б, 2026-11-16): the owner and the authors the owner names with
  `/author <who>` (`unauthor`, `authors`; `access.authors`, `Server.may_author`), not hosts by `op` alone;
  anyone else is told the save stayed on the device. A server made in the game: its `mods_reread` joins
  the bundles the editor joined.

## Left

Nothing of the plan's seven steps. Phone checks of the user stay open (Android save dialog, a mod put on a
server from a phone).

## Known gaps

- Bounded floats are text fields, not sliders (no slider in the UI kit yet).
- Own-mod bundles that add materials change cell numbering only for new worlds (`Mods.cells_kept`).
