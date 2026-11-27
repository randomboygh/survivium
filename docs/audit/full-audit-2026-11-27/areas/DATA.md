# DATA audit: content loader, YAML, schema, saves, world cells, generator

**What I read.** I read these files whole: `src/shared/content/{content.gd, content_mods.gd, mods.gd, yaml.gd, materials.gd, mod_files.gd, mod_zip.gd, trees.gd (head), bushes.gd (head)}`, `src/shared/world/world_store.gd`, `src/client/save_game.gd`, `src/server/server_store.gd`, `src/client/mod_import.gd`. I read these in ranges: `content_fields.gd`, `content_schema.gd` (head, tail, helpers), `world_cells.gd` (Chunk, cell access, pack/unpack), `world_gen.gd` (header, init, jobs, start/step), `world_data.gd` (function list, `_old_slope`), `land_layout.gd` (`_cover_row` head), `test_ground.gd` (header, ids), `tools/validate.gd` (`_init`, `_check_each_bundle`), `tools/content_report.gd` (consts), `field_names.gd`, `server.gd` (mods reload and put_mod), `server_link.gd` (`use_mods`), `mod_reload.gd`, `main.gd:440-532`, `server_main.gd:286-320`, and the tests `store_test.gd`, `content_test.gd` (yaml), `editor_test.gd`, `save_test.gd` by grep.
**Earlier records.** I grepped `docs/audit/CODEBASE_AUDIT.md`, `REFACTORING_ROADMAP.md` and `OPEN_ISSUES.md` for each finding.
**What I did not cover.** I did not read `land_layout.gd` beyond its function list and `_cover_row` head, `grass.gd`, `growth.gd` or `currents.gd` in depth. I did not read the item, crafting, plants, biomes or tools registries beyond grep. I did not check `content_graph.gd`. I did not check the content YAML's conformity file by file: the validator does that in CI and Godot is not installed here. Nothing was run. Statements about engine behaviour are marked unverified where they matter.

---

### DATA-1 · Critical · Correctness
- **What:** After any change of material order, the first save writes the new order into `world.json` `materials`. The chunk files that were not re-saved that session keep the old numbering. The next load reads them without a remap, so their cells become other materials.
- **Where:** `src/client/save_game.gd:286` (`"materials": Array(Mat.IDS)`, unconditional); `src/server/server_store.gd:182` (same); `src/shared/world/world_gen.gd:272-279` (remap on read; the chunk is *not* marked unsaved); `src/shared/world/world_gen.gd:320-336` (only the tree-regrow path sets `world.unsaved`); `src/client/main.gd:447-449`; `src/server/server_main.gd:313-314`.
- **Evidence:**
  - `start()` remaps `d.cells` through `material_map` for a saved chunk. Nothing puts the chunk into `world.unsaved`, so the remapped bytes never reach disk unless the player edits that chunk.
  - Both writers stamp `world.json` with the current `Mat.IDS` on every save.
  - On the next start, `WorldStore.materials_of(meta)` equals `Mat.IDS`, so `Mat.remap` returns an empty table (`materials.gd:240`). The old-numbered files are then read raw.
- **When the order differs:**
  - every save from before `content` 5 (`OLD_MATERIALS`, `world_store.gd:31`);
  - saves before the materials/resources split (`Mat.RENAMED`);
  - a mod update that adds a material to a bundle earlier in the load order;
  - a bundle that has gone missing (see DATA-3).
- **Tests:** `store_test.gd:93-105` tests only the remap on read, not remap, save, reload.
- **Why it matters:** Silent corruption of every unvisited chunk of a converted world, on the second launch after the conversion. This holds in single player and on the server.
- **Proposed refactoring (save format change, the owner picks one):**
  - (a) Store the material id table (or its hash plus a per-world table history) in each chunk file. Remap per chunk on read.
  - (b) When `material_map` is non-empty, keep the *saved* list in `world.json` until a background migration has rewritten every chunk file in `store._chunks`. Do it a few files a frame, then write the new list.
  - (c) Mark every remapped chunk `unsaved` *and* keep the old list until no old-numbered file remains.

  Add a test: save with list A, load with list B, save without visiting chunk X, reload, check chunk X.
- **Effort:** M. **Risk:** medium. **Confidence:** high (code path traced; the run itself is not reproduced since Godot is not installed).

### DATA-2 · High · Data
- **What:** Saves keep the tree species, bush type and column biome as load-order *indices*, with no id table and no remap. Unlike materials, they have no `materials`-style list at all.
- **Where:**
  - `src/shared/world/world_cells.gd:961` (`tree_list.append([at, trees[at]])`, int species);
  - `world_cells.gd:983` (`"biome": c.biome`, Biomes indices) and `:1047-1056`, `:1064-1067` (`add_tree(..., t[1])`, `add_bush(b[0], b[1])` as read);
  - `src/shared/world/world_gen.gd:255` (`"planted"` with species ints);
  - `src/shared/content/trees.gd:33-34` ("a tree is noted in WorldData.trees by its species index");
  - `bushes.gd:17-21`.
- **Evidence:**
  - `add_tree(x, z, species: int)` (`world_cells.gd:641`) stores any int.
  - About 118 sites index `Trees.SPECIES[` or `Bushes.TYPES[`. Only a few guard the range (`growth.gd:147,194,218,262`, `world_data.gd:440,485`).
  - Indices also shift *during play*. `Server.put_mod` (`server.gd:521-524`) and the editor's `join` (`content_editor.gd:492-497`) add any bundle of an own mod to the running world, with no `additive` filter. `Mods.rescan(true)` then refreshes `Trees`/`Bushes`/`Biomes` while keeping only `Mat` (`mods.gd:95-96`).
- **Why it matters:** Trees, bushes and biome tints of saved chunks change species silently when another bundle with trees, bushes or biomes appears earlier in load order. Causes: a mod update, an own mod hot-joined, a bundle removed. An index past the end throws at the unguarded sites. Not recorded in earlier audits.
- **Proposed refactoring (save format):**
  - Write `trees`, `bushes` and `biomes` id lists in `world.json`, the same way as `materials`. Add `Trees.remap`, `Bushes.remap` and `Biomes.remap` (same shape as `Mat.remap`), and apply them in `unpack_chunk` and to `planted`.
  - Treat unknown ids explicitly: drop the tree, or fall back to the biome's first tree.
  - Make the live reload keep `Trees`/`Bushes`/`Biomes` like `cells_kept` keeps `Mat`, or refuse a non-additive live join.
  - Fold this into the DATA-1 fix, since the same "per-chunk table" design solves both.
- **Effort:** M. **Risk:** medium. **Confidence:** high.

### DATA-3 · High · Correctness
- **What:** A world whose bundle is no longer installed loads without any warning. The first save then permanently rewrites `mods`, `known` and `materials` without that bundle, so restoring the mod later cannot bring the world back.
- **Where:** `src/shared/content/mods.gd:189-204` (`expand`: "the unknown are left out"); `mods.gd:165-183` (`of_world`); `src/shared/content/materials.gd:244-245` (unknown material becomes `STONE`); `src/client/save_game.gd:131, 283-286`; `src/server/server_store.gd:179-182`.
- **Evidence:**
  - `expand` filters to `every` (the bundles on disk). A missing name never reaches `Content.load_all`, so even the "no such bundle" problem (`content.gd:+75`) is not raised.
  - `Mat.remap` turns the missing materials into stone.
  - The bundle is gone from `known`, so it is no longer "known". If it is not additive it never rejoins (`of_world` only re-adds `additive` bundles).
- **Why it matters:** Data loss with no message. This happens easily on a phone, where own mods live in `extra_dir` and the "clear own mods" button exists (`mod_import.gd:44`), and on a server after a mods folder change.
- **Proposed refactoring:**
  - Have `of_world` return the missing bundles too: `{"bundles", "missing"}`.
  - Single player asks the player: open read-only, or continue and lose. The server refuses to start, or starts with `--force`.
  - Writers keep listing the missing bundles in `mods` and `known`, so a restored mod comes back.
  - Add a test in `save_test`.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### DATA-4 · Medium · Correctness
- **What:** If `world.json` is unreadable or has another format, single player starts the world anew and later overwrites `world.json`. The server refuses to start in the same case. Two behaviours for one file.
- **Where:** `src/client/save_game.gd:122-126` (`push_error(... "started anew")`, `meta = {}`, return; `store` stays pointed at the folder); `save_game.gd:300-307` (later writes `world.json` over it); `src/shared/world/world_store.gd:211-215` (`read_json_at` returns `{}` on any parse failure); `src/server/server_main.gd:290-293` (returns false).
- **Evidence:**
  - After the "started anew" branch, `has_save` stays false but the store and its `chunks/` remain. Chunk files are still found by `WorldStore._init` and read by the generator.
  - The first autosave writes a fresh `world.json`. Placed things, territory, plans, tame animals and the clock are lost. The old chunks are mixed into a world with no `materials` list.
  - There is no backup copy.
- **Why it matters:** One truncated JSON (an IndexedDB flush cut off on the web is the likely case; the writes themselves are atomic) loses everything except the chunks.
- **Proposed refactoring:**
  - Keep `world.json.bak` (the previous good file) on each `move_over` and fall back to it.
  - On an unreadable save, never write into that folder: rename it `<dir>.broken-<date>` or ask.
  - Use one shared `WorldStore.open_meta(dir) -> {meta, error}` for client and server.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### DATA-5 · Medium · Duplication
- **What:** `world.json` is composed in two places, and "open a saved world" is written three times.
- **Where:**
  - `src/client/save_game.gd:279-299` (`_write_world`) vs `src/server/server_store.gd:174-198` (`_world_meta`).
  - The settings normalisation loop appears at `save_game.gd:115-116`, `src/server/server_main.gd:297-298` and `src/shared/world/world_store.gd:118-119`.
  - The world height `48` appears at `src/client/main.gd:445` and `server_main.gd:311`. `"levels"` is written to `world.json` but never read; only the per-chunk `levels` is checked (`world_cells.gd:996`).
- **Evidence:**
  - The same 12 keys appear twice (`format` … `decay`, each calling `session.<part>.to_x()`). Single player merges over the old meta (`meta.merge(own, true)`); the server replaces it. This drift already caused WA-020 (the lost `next_player`).
  - The player record is likewise split: `ServerStore.SECTIONS` (const, `server_store.gd:24`) vs `SaveGame.track(name, obj)` (dynamic).
- **Why it matters:** Every new piece of session state must be added in two writers and two readers. A forgotten one is lost in one mode only.
- **Proposed refactoring:**
  - Move `Session.to_saved() -> Dictionary` and `Session.from_saved(meta)` into `src/shared/game/session.gd`. Each writer adds only its own keys (`teams`, `fights`, `next_player`).
  - Have `WorldStore.read_settings(meta)` do the normalisation, used in the three places.
  - Read `levels` from `world.json`, with a `WorldStore.LEVELS` const default.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### DATA-6 · Medium · Architecture
- **What:** Content-derived caches are invalidated by three different mechanisms, and several callers set `Content.BUNDLES` and call `Content.refresh()` around `Mods`.
- **Where:**
  - `src/shared/content/mods.gd:104-118` (a hand list of 12 registry `refresh()` calls);
  - `src/shared/content/looks.gd:28` (polls `Content.generation`);
  - `src/client/mod_reload.gd:71-75` (`forget_files`: `Lang.reread`, `VoxelProps`, `ItemIcons`, `Figure`) plus `server_link.gd:221-223` (`sound.read_records`);
  - direct writes at `src/server/server.gd:521-523`, `src/client/ui/editor/content_editor.gd:492-495`, `src/client/mod_reload.gd:130`;
  - `src/shared/content/tree_looks.gd:37,130` (`hold_most` only grows, never reset on refresh).
- **Evidence:**
  - Every registry's `_static_init()` calls `refresh()`, which calls `Content.records()`, which runs `load_all()` of *all bundles on disk* (`content_mods.gd:9`, `static var BUNDLES = _all_on_disk()`) as a side effect of the first `preload`. `Mods.activate` then loads again with the world's set.
  - A new registry must be added by hand to `_refresh_registries`, to the validator's list (twice, see DATA-15) and possibly to `forget_files`.
  - Recorded as content-11 (Low). It is only partly fixed by the `_built` generation check: the three direct writers above still bypass it.
- **Why it matters:** This is the root of "two mod sets in one process" bugs. A forgotten registry silently keeps the previous set, as in a client after joining a server, a test after `Content.refresh()`, or a hot reload. There are 60+ `Content.refresh()` calls in tests (`grep`), each relying on an implicit lazy reload.
- **Proposed refactoring:**
  - One entry point, `Mods.load(set, live := false)`, that owns `BUNDLES`, `refresh`, the registries and a `Mods.changed` notification. Make `Content.BUNDLES` private.
  - Each registry (shared and client) checks `Content.generation` lazily like `Looks`, or registers itself in one `const REGISTRIES` list that `validate.gd` iterates too.
  - Reset `TreeLooks.hold_most` in `Trees.refresh`.
- **Effort:** M. **Risk:** medium. **Confidence:** high.

### DATA-7 · Medium · Security
- **What:** The registries' engine checks never run at runtime. A server's mods, a zip import or a phone's override folder can load more than 255 materials, or a set without `core:air` first, and corrupt the byte-sized cells.
- **Where:** `src/shared/content/materials.gd:250-265` (`check`: `COUNT > 255`, `AIR` first, `KNOWN` present). It is called only from `tools/validate.gd:39,83` and `tests/unit/content_test.gd:75,255`. Cells are `PackedByteArray` (`world_cells.gd:209`). `Mat.remap` returns a `PackedByteArray` (`materials.gd:242-246`).
- **Evidence:**
  - `grep '\.check()' src` finds no runtime call.
  - `Mods.activate` (`mods.gd:71-77`) returns `Content.problems` only.
  - `ModFiles` limits a server's set to 20 000 files and 256 MB, but not the record counts.
- **Why it matters:** Material index 256+ wraps to 0..255 in cells and in the remap table. Missing `core:air` makes `Mat.AIR` = -1, and every "air" test breaks. A hostile or careless server can push this to every client.
- **Proposed refactoring:** In `Mods.activate`/`rescan`, run the registries' `check()`, and refuse the set (keep the previous one, tell the player or console) on a fatal problem such as the 255 limit, `AIR` or `KNOWN`. Add a `security_test` with 300 materials.
- **Effort:** S. **Risk:** low. **Confidence:** high (the effect of a 256th material is inferred from the byte storage).

### DATA-8 · Medium · Security
- **What:** The hand-written YAML reader has no nesting or size limit, recurses for every nested flow or block level, and parses files a server sends.
- **Where:** `src/shared/content/yaml.gd:155-205` (`_flow` recurses per `[`/`{`); `:48-115` (`_block` → `_list`/`_map` → `_block`); `content_fields.gd:420-426`; server files reach it via `Content._read` (`content_fields.gd:370-393`), with `ModFiles.FILE_MAX` = 8 MB per file (`mod_files.gd:40`).
- **Evidence:**
  - `a: [[[[…` 100 k deep is a 100 KB file and recurses 100 k times.
  - **Unverified:** I could not confirm whether a release export template's GDScript VM checks call depth or crashes natively. Confirm with a `content_test` case parsing `"[" * 100000`.
  - Other limits from the code:
    - one error drops the whole file (`parse_text` returns null, `_read_records` → `[]`), and only the first error is reported;
    - `yes`/`no`/`on`/`off` are booleans (`yaml.gd:240-243`, YAML 1.1). No current content trips it (grep finds 0 such plain values), but a value like `no` silently changes type;
    - `_flow_scalar` ends a quoted string at the first quote and ignores `\"` (`yaml.gd:211`);
    - parsing indexes a `String` per character (`line[i]`), which is slow on a phone for MB-sized files.
- **Why it matters:** A malicious or broken server can crash or freeze every client that joins. The client checks sizes and hashes but not structure.
- **Proposed refactoring:**
  - Add `MAX_DEPTH` (for example 64) tracked in `_block` and `_flow`, failing with "too deeply nested".
  - Cap lines and characters per file.
  - Make the YAML 1.1 booleans an error or a warning in strict mode.
  - Add an adversarial-input test block to `content_test._test_yaml`.
- **Effort:** S. **Risk:** low. **Confidence:** medium (recursion verified; crash behaviour unverified).

### DATA-9 · Medium · Coupling
- **What:** The cell index layout `(y << 8) | (z & MASK) << SHIFT | (x & MASK)` is written out by hand about 30 times in 6 files, though `LAYER`/`SHIFT`/`MASK` exist. The `natural` and `shapes` bytes also pack bits by hand (`& 15`, bits 4..7).
- **Where:**
  - `src/shared/world/world_cells.gd:345,355,386,433,442,457,477,568,594`;
  - `src/shared/world/world_data.gd:100,137,160,191,208,271,356,376,391,658,685,744`;
  - `src/shared/game/decay.gd:220,270,279`;
  - `src/client/world/chunk_mesher.gd:298`;
  - `src/client/world/roof_map.gd:152,248`;
  - `src/client/view/fire_shadows.gd:648`.
- **Evidence:** `const LAYER := CHUNK * CHUNK` (256) and `SHIFT := 4` are defined (`world_cells.gd:30-34`), but `8` (log2 of LAYER) has no name. The client meshers and `decay.gd` reach into `Chunk.cells`/`natural`/`shapes` directly.
- **Why it matters:**
  - Changing `CHUNK` (a plausible tuning for phones) silently breaks every literal `<< 8`.
  - The flag bits are spread between `world_cells.gd:82-93` and the shapes doc comment.
  - There are no bounds checks in hot paths; that is fine by design, but it means a wrong index is not caught.
- **Proposed refactoring:**
  - Add `const LAYER_SHIFT := SHIFT * 2` and a static `idx(x, y, z)` / `idx_col(y, col)`, inlined by hand where profiling demands, but naming the const.
  - Name the shapes masks (`SLOPE_BITS := 15`, `CORNER_SHIFT := 4`).
  - Add a `shapes_test` assertion that `LAYER == 1 << LAYER_SHIFT`.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### DATA-10 · Medium · Architecture
- **What:** `test_ground.gd` (1182 lines, 45 functions) is a shipped feature in shared code: the «Тестирование» world, and the server's `--seed -1`. It hard-codes 30+ ids of non-core mods, against the "ids only core's" rule.
- **Where:** `src/shared/world/test_ground.gd:148-158` (`HOUSE_THINGS`: `tools:table`, `tools:lantern`…); `:232-235` (`CAMP_DROPS`, `CAMP_THINGS`); `:299` (`Mat.index("materials:" + name)`); `:928-937`. It is loaded by `src/client/main.gd:33,444` and `src/server/server_main.gd:43,310`.
- **Evidence:** 16 lines hold quoted `mod:name` ids. It is the only file in the area that names non-core ids outside the rename maps (`grep` across `src/`). The layout plan (coordinates, sizes, things) is data written as GDScript consts.
- **Why it matters:**
  - A world with the `tools` mod switched off gets a test ground that silently lacks the house and camp (or errors: unverified which).
  - Every content rename must also edit this script.
  - It is the largest single "data in code" block in the area. Earlier audits recorded world-8 and world-11 here but not the ids.
- **Proposed refactoring:**
  - Move the plan's things and drops into a YAML of a core-side test bundle (for example `content/core/test_ground.yaml` read through `Content`), or ask by role (`Items.with_prop`).
  - Split the remaining code by ground, as a chain of parts (`test_ground_*.gd`).

  This changes structure, so the owner picks.
- **Effort:** M. **Risk:** low. **Confidence:** high.

### DATA-11 · Medium · Data
- **What:** Save migrations are scattered, with two version numbers and rename tables in code, though the data-driven `was` field already exists.
- **Where:**
  - `WorldStore.FORMAT = 1` (`world_store.gd:20`): never bumped; a mismatch means "start anew" (DATA-4).
  - `CONTENT = 9` (`:28`); `OLD_MATERIALS` (`:31`).
  - `Mods.RENAMED`, `SPLITS`, `OLD_ADDITIVE` (`mods.gd:29-42`); `Mat.RENAMED` (`materials.gd:25`); `Items.RENAMED` (`items.gd:16`); `Crafting.RENAMED` (`crafting.gd:38`).
  - The per-chunk `looks` version and regrow (`world_gen.gd:290-292`); presence checks for `biome`/`frost` (`world_gen.gd:285-289`, `world_cells.gd:1018-1029`).
- **Evidence:**
  - Each conversion lives in the module it touches. There is no list of what a given `content` mark implies and no window after which a conversion may be retired.
  - `Content.canon` already reads `was` (`content.gd:123-126`) and `_check_renames` accepts qualified old ids from other mods (`content.gd:+215`). So most `*.RENAMED` consts could be `was:` lines in the YAML ("content is data").
- **Why it matters:** Each format change adds code in 2–4 places. Nothing tests the matrix (old `content` × feature), and old-save code can never be retired with confidence.
- **Proposed refactoring:**
  - One `src/shared/world/save_migrations.gd` with ordered steps keyed by `content`, applied to `meta` (and to chunk dicts lazily).
  - Move the item, material and recipe renames into `was:` fields of the records.
  - Decide a support window, for example "saves from before content 5 are no longer opened".

  This is a save-architecture change, so the owner picks.
- **Effort:** L. **Risk:** medium. **Confidence:** high.

### DATA-12 · Low · Dead code
- **What:** The material fields `edge`/`edge_size` and `Mat.edge_mode`/`edge_size`/`EDGE_*` are computed but never read. The comment itself says "Nothing draws them since … 2026-11-20".
- **Where:** `src/shared/content/materials.gd:92-100, 142-144`; `content_schema.gd:31-34`; `src/client/ui/editor/field_names.gd:19-20` (plus their lang keys).
- **Evidence:** `grep 'edge_mode|edge_size|EDGE_ROUND|EDGE_BEVEL'` outside `materials.gd` finds only the schema and the editor's names. `corner_shape` *is* still used (`chunk_mesher.gd:403,984,1100`).
- **Why it matters:** The editor shows modders two fields that do nothing.
- **Proposed refactoring:** Remove the arrays and consts. Either drop the schema fields (any YAML that still writes them must be cleaned; check with grep in `content/`) or mark them `provisional`/deprecated with a validator warning.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### DATA-13 · Low · Tests
- **What:** The generator's determinism depends on the engine's `hash()` of Variants, and no golden fingerprint test pins it across engine upgrades.
- **Where:** `src/shared/world/world_gen.gd:435` (ore veins `hash(Vector4i(...))`); `src/shared/world/growth.gd:45,50,121,133,139` (tree girth, turn, looks); `src/shared/world/grass.gd:186,212,406,465,545`.
- **Evidence:** `tests/unit/generation_test.gd` has no stored digest (`grep golden|fingerprint|checksum` finds nothing).
- **Why it matters:** If a Godot upgrade changes Variant hashing (unverified for 4.5→next), unsaved chunks regenerate differently beside saved ones. That gives seams, and ore and trees move in every existing world. Nobody would notice until players report it.
- **Proposed refactoring:** Add a test that generates 2–3 fixed chunks of seed 42 and compares a SHA of `pack()` with a committed value. Put "re-check generation digest" into the engine-upgrade checklist next to `web_patch.py`.
- **Effort:** S. **Risk:** low. **Confidence:** medium.

### DATA-14 · Low · Tooling
- **What:** `tools/content_report.gd` mixes Russian labels with raw lang keys, so the generated docs print literal keys. The generated docs are also Russian-only, against the "docs in English" rule.
- **Where:** `tools/content_report.gd:34-42` (`"bushes": "[bushes]"`, `"world": "[world_n2]"`, `"craft": "[crafting]"` beside `"Предметы"`).
- **Evidence:** `docs/generated/content-index.md:624` has `## [bushes] (...)`. `content-recipes.md:19,24` has `[crafting]`. `content-graph.md` has 46 such keys (grep). Lines with Cyrillic: 798 in `content-index.md`, 248 in `content-recipes.md`.
- **Why it matters:** These are the docs agents grep for content; the half-translated labels are noise.
- **Proposed refactoring:** Make the labels plain English strings, which is what tools and docs are written in, and regenerate.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### DATA-15 · Low · Duplication
- **What:** The registry list is repeated (see DATA-6).
  - `tools/validate.gd` calls the same ten `X.check()` twice: `:39-48` and `:83-92`.
  - `content_test.gd:75,255` repeats subsets.
  - `field_names.gd` (381 lines) holds 368 entries, every one exactly `"<kind>.<field>": ["[field.<kind>.<field>]", "[field.<kind>.<field>.about]"]` (checked with a script: 0 irregular).
- **Where:** `tools/validate.gd:39-48,83-92`; `src/client/ui/editor/field_names.gd:6-374`.
- **Why it matters:** A new registry or field needs the same line in 3–4 places. The editor table is a second copy of the schema's field list: it matches today (12 `description` fields excepted), but only because a test enforces it.
- **Proposed refactoring:**
  - A `const CHECKS` list (or `Mods.check_all()`) used by `validate` and the tests.
  - Have `FieldNames.of()` derive the keys from `kind.field`. If `tools/lang_check.py` needs literal keys to see them used, teach it the `field.<kind>.<field>` pattern from `SCHEMAS` instead.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### DATA-16 · Low · Performance
- **What:** The material remap of a saved chunk walks every cell in one call (16·16·48 = 12 288 iterations) at job start. That is chunk-sized work in one frame, against the per-frame rule.
- **Where:** `src/shared/world/world_gen.gd:275-279`.
- **Evidence:** Recorded as world-10 (CODEBASE_AUDIT), deferred in `REFACTORING_ROADMAP.md:48`. Still open. Only saves whose order differs pay it, every load (see DATA-1, which would also remove the repeat cost).
- **Proposed refactoring:** Do it as the job's first rows, a level per step. Or fix DATA-1 so that it happens once per chunk ever.
- **Effort:** S. **Risk:** low. **Confidence:** high.

### DATA-17 · Low · Size
- **What:** `land_layout.gd`'s per-row functions are still long. `_cover_row` is 239 lines and `_water_row` 179 lines.
- **Where:** `src/shared/world/land_layout.gd:922-1101, 1107-1346`; `grids[0..9]` 12 times in `land_layout.gd` and 3 in `world_gen.gd`; `lay` dict built at `land_layout.gd:501`.
- **Evidence:** The layout window `lay` is an untyped `Dictionary` used as a struct. Its `grids` is an `Array` read by position (`var steep: PackedByteArray = grids[6]`).
- **Why it matters:** The file being whole is accepted; the function length and the positional struct are not covered by that decision. Adding a noise grid means renumbering by hand.
- **Proposed refactoring:**
  - Name the grid slots as consts (`G_HILLS := 0` …), or make `Layout` an inner class with typed fields.
  - Split `_cover_row` into its commented phases (ravines/rock, swamps, climate biome, woods, sheer tops/cave mouths).
- **Effort:** M. **Risk:** low (byte-identical layout can be checked as WA-025 did). **Confidence:** high.

### DATA-18 · Low · Correctness
- **What:** Small save-format nits.
  - (a) Seeds go through JSON, which reads numbers as floats. A server seed above 2^53 (`--seed N`, `config.gd:93,155`, unbounded) comes back different from `world.json` (`server_main.gd:296`, `int(meta.seed)`), so the world regenerates differently. The client UI limits seeds to 10 digits (`world_setup.gd:347,365`).
  - (b) A doc comment is detached: `world_store.gd:279` ("Removes directory `path`…") sits on `was_hosted`, not on `erase_dir`.
  - (c) A broken chunk file is reported once per load (`world_gen.gd:297`) and kept on disk for ever, since the regenerated chunk is not `edited`.
- **Proposed refactoring:** (a) Store the seed as a string, or clamp `--seed` to ±2^53. (b) Move the comment. (c) Rename the broken file to `.broken` on the first failure.
- **Effort:** S. **Risk:** low. **Confidence:** high for (a) logic, given Godot's JSON parses numbers as float; (b) and (c) are verified in code.

---

## Healthy
- **Atomic writes:** every chunk, map, JSON and server snapshot is written to `.tmp`, checked (`_written`: store result, `get_error`, non-empty) and renamed; `remove_beside` cleans leftovers (`world_store.gd:218-276`, `server_store.gd:104-134`). Earlier world-4 and world-m2 are fixed.
- **Untrusted mod files from a server:** `ModFiles.unpack` checks size, list size, path charset (`valid_path` rejects `..`, leading dots, other characters), per-file and per-set limits, hash, and PNG header dimensions before decode (`mod_files.gd:229-298`).
- **Zip import:** sizes come from the central directory before `read_file` (no zip bomb), every path goes through `valid_path`, `unpack_mod` stages and checks `own: true` before replacing (`mod_zip.gd`). Keep as is.
- **Bundle resolution:** `content_mods.gd` (scan once, Kahn ordering stable by scan order, hard/soft refs, patches/replaces) is clear and well commented. `Mods.of_world` is covered by a matrix test (`content_test.gd:331-353`).
- **The `was` rename mechanism and `Content.canon`:** data-driven and validated (`_check_renames`). The right base for retiring the code tables (DATA-11).
- **`WorldData` chunk access:** negative coordinates are handled correctly (arithmetic `>>` and `& MASK`, `chunk_key`), cells below are stone and above are air, there is a last-chunk cache, and `can_unpack` validates shapes and sizes before replacing a chunk.
- **`Mat.remap` with `Content.canon` plus `RENAMED`:** correct on read (the bug is on write: DATA-1).

## Not covered
- `land_layout.gd` beyond structure (per-row budgets not measured), `grass.gd`, `growth.gd`, `currents.gd`, `content_graph.gd`, `content_edits.gd`, `own_mods.gd`, `lang.gd` internals.
- Schema conformity of every YAML in `content/` (the validator's job; not runnable here).
- Balance; client meshers beyond the cell-index grep.
- Whether Godot release templates crash or error on deep GDScript recursion (DATA-8).
- Whether `hash()` changes between engine versions (DATA-13).
