# The loader and YAML

Part of [Mods, bundles and registries (code)](../content.md). `content.gd` and the YAML parser.

- `src/shared/content/content.gd` — the mods' data; one script divided by topic into a chain of inheritance
  (decision 168, like 145): each part extends the previous one and calls only its own and the earlier ones,
  from outside only `content.gd` is known (`Content.records`, `Content.SCHEMAS` — everything through it).
  - `content_schema.gd` — `SCHEMAS` of all kinds, the common fields `COMMON`, the dictionary of links
    `RELATIONS` and actions `ACTIONS`, `MOD_SCHEMA`, `BUNDLE_SCHEMA`; `schema`, `refs` / `target` / `named`
    (a kind's reference fields and what a record names by them), `qualify`.
  - `content_fields.gd` — reading a YAML file (from the build's cache `PARSED` or by parsing), checking a
    record's fields against the schema and conversion into the engine's types (`_check_fields`, `_convert`),
    `problems`.
  - `content_mods.gd` — the mods and bundles on disk, read once (`universe`, `_scan`), `resolve` (the order
    and the dropped bundles), `closure`, `deps`, `BUNDLES`, `loaded`, `dropped`.
  - `content.gd` — loading a set (`load_all`), replacements (`replaces`) and patches, checking references (and
    inside `entries`), warnings about names, `records` / `find` / `canon` / `origin`, `asset`, `sound_files`.
- `src/shared/content/yaml.gd` — our own parsing of the part of YAML the data needs (keys with `:` inside,
  `{core:fiber: 1}`), and writing it back (`Yaml.write`: what `parse` reads as the same value; every data
  file of the game goes through both unchanged, `editor_test.gd`). It reads by lines and characters in GDScript, so
  what is long is cut up by the engine's own string calls: a line without `#` keeps no comment to cut, and a flow
  list of plain scalars (no quotes, nothing nested: the numbers of the trees' look.yaml) is split at its commas
  whole.
- The content editor (stage 2, decision 186, 11А, 13А; under way): `src/shared/content/own_mods.gd`
  (`OwnMods`) — one's own mods, the ones the editor writes: `root()` is `Content.ROOT` when the mods lie
  beside the game, else `ModFiles.extra_dir` (the app's folder on a phone; `ModFiles.USER_DIR`
  `user://content` in the browser and on a computer running the built-in copy, laid over the game's like a
  phone's folder, `find_extra`); `make(id, name)` writes a mod.yaml with `own: true` (`MOD_SCHEMA`) and its
  English name; `put` writes a record of a kind into `data/<kind>.yaml`, `patch` a patch of another mod's
  record (`patch: true`, only the fields given, gathered into one patch per record), `remove` takes one out.
  Writing changes only files: the caller rereads the mods. `src/shared/content/content_edits.gd`
  (`ContentEdits`) — a form's changes: `check` (a field's value against its schema, as the loader checks it),
  `data_of` (a loaded value back to the data's: colours, vectors), `changed` (the fields that differ from the
  loaded record), `save` (into the record itself when it is the mod's own — `owns` — else a patch of the
  other's: the game's files are never written, 2А) and `undo` (the file as it was; `history`, at most
  `MOST_UNDO`). `src/client/ui/editor/content_editor.gd` — the editor's window («Editor» in the main menu and
  the pause menu): the own mod saves go into (several, 3Б; «+» makes one by its id), the kind (`KINDS`), a
  search by name or id, the list of records; a record opens as a form (`record_form.gd`, `RecordForm`: a
  switch for a bool, a row of values for an enum or a whole number of a short range, a text field for the
  rest, lists and mappings as one line of YAML; changed names amber, default ones faded, wrong ones red; each
  field named in the game's language with a line under it on what it does and its YAML name,
  `src/client/ui/editor/field_names.gd`, keys `[field.<kind>.<field>]`, `….about`).
  «Save» writes the changed fields, the mod's bundles join the loaded set and the world played
  (`join`: `Content.BUNDLES`, `game.world_mods`, kept with the save), and the mods are read again at once
  (`ModReload.reload`); «Undo» takes the last save back. A record's title and description are fields on top of
  the form in the game's language, written as the mod's phrases (`ContentEdits.key_of`: `[<mod>.<kind>.<id>]`,
  `….about`; a patch of another mod's record gets `[<mod>.<kind>.<other>_<id>]`) into its `lang/<code>.yaml`,
  English's too while it has none. «Copy» makes a new record of the mod from any record (`ContentEdits.copy`:
  the fields as loaded, defaults and `was` left out, title and description under the copy's keys in English
  and the game's language); «Delete» takes the mod's own record out with its phrases, «Reset» its patch of
  another's (`ContentEdits.delete`). A save, copy or delete is taken back whole (`history` keeps every file
  each one changed). A picture field (`ContentEdits.PICTURES`: an item's icon, held sprite and worn look, a
  creature's and a plant's sprite, a material's texture, a tree's bark, an item's model) shows its picture and «Load PNG»
  (`src/client/ui/editor/picture_pick.gd`: the system's file picker, a file input of the page in the
  browser); `ContentEdits.picture` checks it (`ModFiles.may_be`) and writes it into the mod's
  `<folder>/<name>.png` with the field, one write to take back: a record of another mod gets
  `<mod>:<name>`, which `Content.asset` finds in that mod's folder. A model field (`ContentEdits.MODELS`) has
  «Edit model» too: the voxel editor (`src/client/ui/editor/voxel_editor.gd`, 4А) paints the model level by
  level on a flat grid (`slice_grid.gd`: the level under it faint; paint, erase, fill, take a colour) beside
  its 3D picture turning (`voxel_preview.gd`: `VoxelModel.build_mesh` in a small world of its own, a drag
  turns it, the level painted outlined); levels added, copied up and taken out, the slice made 4..32 across
  (round its middle for a thing lying, its corner for one placed on cells), a palette of the model's colours
  and the game's, lighter and darker, a leaf switch (alpha 128, tinted by the season); «Undo» takes back a
  stroke. The model is `voxel_sheet.gd` (`VoxelSheet`: the PNG of slices `VoxelModel.from_image` reads);
  «Save» writes it as a picture (`ContentEdits.picture`). Upright, one column; sideways, three. «Export
  zip» packs the chosen own mod (`ModZip.pack`, `src/shared/content/mod_zip.gd`: `<mod>/…`, only files a
  mod may have) and hands it out (`ModImport.offer`, `src/client/mod_import.gd`: the browser's download,
  else the system's save dialog); «Import zip» takes one in (`PicturePick.pick(…, true)`,
  `ModZip.unpack_bytes` into `OwnMods.root()`, never over a mod that is not one's own) and chooses the mod
  it brought. On a server (step 7): joined to a server far away, every save puts the mod there instead of reading it here (`ContentEditor.server_mode`,
  `src/client/net/mod_put.gd`: the zip in pieces of `Protocol.MOD_PIECE` 128 KB, at most `MOD_PIECES` 64,
  one put each `ModPut.EVERY` 5.5 s, saves in between put once after; closing the editor does not stop
  it); the server (`Server.put_mod`) takes it only from its owner or an author the owner named
  (`/author <who>`, `Server.may_author`; a host by `op` alone may not) and only as an own mod (`ModZip.unpack_mod`:
  unpacked aside, then in place of what the mod had in its `OwnMods.root()`), joins its bundles to the
  world's (kept in the save) and sends the files to every player (`Protocol.MODS`), the author too. Any
  other player is told the save stayed on the device. A server made in the game takes the mod with the
  game's reload (`Server.mods_reread` joins the bundles the editor joined). State:
  `docs/planning/archive/editor.md`.
- Where the mods lie (decision 186): `Content.ROOT` — the folder `content/` beside the program in the built
  game on PC (Windows, Linux), if it has `core/mod.yaml` (`Content.find_root`, `Content.beside()`), otherwise
  the built-in copy `res://content` (`BUILT_IN`; the editor, the browser, a phone, a build without the
  folder). CI puts all the mods as open files (YAML, PNG, WAV, without `.import`) into `content/` beside the
  exe in the PC archives (`.github/workflows/build.yml`, the job `pc`); one's own mods — separate folders in
  the same place, an update replaces only the built-in ones. From there pictures and sounds are read from
  files (`Content.picture`, `Content.sound`, `Content.exists`; the player's drawings — `Figure.SPRITES`), the
  parsed YAML is taken from `content_cache.bin` while the file's text has not changed, and hot reload works in
  the built game too. The check is `content_test.gd` `_test_content_beside` (a copy of the mods in `user://`).
- One's own mods on a phone (decision 189, 4В): the game's mods are sealed inside the APK there, so one's own
  go into a folder of the app, `ModFiles.extra_dir` (`find_extra`: on Android
  `Android/data/<the app>/files/content` of the shared storage, no permission needed; made at the first start;
  "" elsewhere), laid out like `content/`. Its files are laid over the built-in ones: new mods and bundles, or
  other files for the built-in (`ModFiles.extra()`, `own(root)`, `where(root, rel)`, `own_table(root)`). While
  the game plays with its own files the table `Content.served` is then that of its own (`Content.lay_own`,
  `served_own`; `serving()` is true only for a server's), read again at every load (`Content.refresh`). A server
  made there lists and gives these files (`ContentHost`), and the settings show the folder and how many files
  it has («Your own mods», `SettingsMenu._own_mods_rows`). The folder is out of reach of the file managers of
  new Androids, so mods are brought in from a zip picked with the system's file picker («Import mods from a
  zip», `src/client/mod_import.gd`, `ModImport.pick` by `DisplayServer.file_dialog_show`, the content:// path
  copied to `user://` and unpacked by `unpack`: a `content/` folder inside the zip, else one mod with its
  mod.yaml at the top named after the zip, `placing`, `mod_name`; only names `valid_path` takes, under
  `FILE_MAX`; then the mods are read again), and deleted («Delete your own mods», `ModImport.clear`;
  `mod_files_test.gd` `_test_import`). A file whose name no list may carry (`valid_path`:
  plain letters, digits, `_ - + .`) or over `FILE_MAX` is left out of every scan (`ModFiles.skipped`; a server
  says so in its log). The check is `mod_files_test.gd` `_test_own_mods`.
- Hot reload (decision 184): `src/shared/content/content_watch.gd` (`ContentWatch`) watches the files of
  `content/` (YAML, PNG, WAV) by `BUDGET` 120 files and folders per step (`BUDGET_PLAYED` 12 while the game's window is in
  front, `ModReload.update`: the files are edited in another program) and at the end of a pass says whether a
  file changed, appeared or vanished (the first pass only remembers the time); it works where the files lie
  by themselves — the game run by the editor's engine from the project folder or the built game on PC with
  the mods beside it (`can_watch`), not the built-in copy and not the browser. `src/client/mod_reload.gd`
  (`ModReload`, Main's module `mod_reload`) steps the watch every frame (except headless: tests and tools
  reread by themselves) and rereads: `Mods.rescan(true)`, translations (`Lang.reread`), models
  (`VoxelProps.forget`), icons (`ItemIcons.forget`), the session's rules (`Session.reread`: the things'
  tracks, `Wildlife.reread`), sounds (`Sound.read_records`), the beasts' pictures (`Creatures.relook`), things
  on the ground and on cells (`Props.remodel`), the bag and crafting. The button «Reread the mods' data» in
  «Debug» does the same at once; the server — by the command `reload` (`Server.reload_mods`). After it
  `Content.live`: pictures and sounds are read from files (`Content.picture`, `Content.sound`), not from the
  import made at start. The cells' materials, if their list changed, stay as they were (`Mods.cells_kept`):
  new ones — in a new world; biomes and relief — for new chunks.
- A server's mods' files (decision 189): `src/shared/content/mod_files.gd` (`ModFiles`) — the list of the
  files a set of bundles is made of, `{path inside content/: [hash, size]}` (`scan(root)` — every YAML, PNG and
  WAV under a folder with the first 128 bits of the SHA-256 of its bytes; `of_set(all, bundles)` — every YAML,
  so the game reads the same mods as the server and decides the same about each, and the pictures and sounds of
  the set's bundles and of their mods), the one hash that names a set (`digest`), the list for the wire
  (`pack`, `unpack` — with every path, size and count checked: `valid_path`, `FILE_MAX` 8 MB, `SET_MAX` 256 MB,
  `FILES_MAX`), `may_be(bytes, ext)` (a picture is a PNG no larger than `PICTURE_MAX` 2048 by its header, a
  sound a WAVE). The built-in copy of an exported game has pictures and sounds only as imported, so its list is
  written at the build: `tools/content_cache.gd` puts it into `res://content_files.bin` (`ModFiles.LISTED`, not
  in git, into the export by `include_filter`). `Content.playing()` — the hash of what the game plays with
  now, `own_digest(bundles)` — of its own files for a set. `Content.serve(table, digest)` plays with a server's
  files in place of the game's own: `table` is a path inside `content/` → the file that holds it (the game's own
  file, the built-in copy's or one kept from a server, `src/client/net/mod_cache.gd`); every path of a mod's
  file stays `ROOT/…` and is looked up when read (`Content.real`, used by `_read`, `picture`, `sound`, `exists`,
  `text`, `file_exists`), and the folders are listed from the table (`dirs_at`, `files_at`, `dir_exists`), so
  only what the server has is there; an empty table — the game's own files again. Who takes the files and
  when: [network.md](../network.md).
