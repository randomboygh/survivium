# The animals drawn from references and by hand: the drawings as data

The frames of the redrawn animals, kept as Python data modules (rows of letters per state, direction and frame), and
the writers that turn them into the art tables the game's creature sheets are made from (`tools/art/<animal>_art.gd`,
then `tools/make_sprites.gd -- <sprite>.png`). The data modules are the source: a frame is changed in its module, the
writer is run, then the sheet is made again. How an animal is drawn from a reference, the user's rules and the
review tools (cutting a reference, palettes, review GIFs) are in the library: `survivium-builds/animals/anim/HANDOFF.md`
and its `src/`.

Run from this folder (`python3 -I -B`: the writers find their modules beside them):

| Animal | Writes | Command | Data |
|---|---|---|---|
| boar | `tools/art/boar_art.gd` | `python3 -I -B write_art07.py ../boar_art.gd` | `boar_07.py` (×0.7 of `boar_frames.py`, which picks frames of `boar_a.py`…`boar_n.py`) |
| fox | `tools/art/fox_art.gd` | `python3 -I -B write_fox_art.py ../fox_art.gd` | `fox_a.py` |
| deer | `tools/art/deer_art.gd` | `python3 -I -B write_deer_art.py ../deer_art.gd` | `deer_a.py` |
| hare | `tools/art/rabbit_art.gd` | `python3 -I -B write_hare_art.py ../rabbit_art.gd` | `hare_b.py` |
| black grouse | `tools/art/grouse_art.gd` | `python3 -I -B write_grouse_art.py ../grouse_art.gd` | `grouse_a.py` |
| bear | `tools/art/bear_art.gd` | `python3 -I -B write_bear_art.py ../bear_art.gd` | `bear_x1.py` |
| sparrow, crow, owl, duck, squirrel | `tools/art/<animal>_art.gd` | `python3 -I -B write_wild_art.py <sp, cr, ow, dk, sq> ../<animal>_art.gd` | `sp.py`, `cr.py`, `ow.py`, `dk.py`, `sq.py` (drawn by hand, no reference; `bird.py`, `eng.py` their parts) |

Each writes its table again byte for byte from the modules as they are here (checked when they were moved here from
the library, 2026-11-27). `proto.py` reads a module's letters (the boar's chain uses it). The wolf, the cat, the frog,
the fish and the hedgehog of the older style are drawn by `tools/make_wolf.py`, `make_cat.py`, `make_frog.py`,
`make_fish.py` and `make_hedgehog.py`; the other animals by `tools/make_creatures.py`.
