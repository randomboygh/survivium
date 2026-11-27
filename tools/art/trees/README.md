# The trees: the approved drawing as a program

The program the trees were redrawn with (thread «Перерисовать деревья», rounds 3 to 25, 2026-11) and the exports
that turn its approved drawing into the game's pictures of the trees: `content/plants/<species>/tree/` `frames.png`,
`bare.png`, `snow.png`, `snow_dry.png`, `stumps.png`, `pieces.png` and the lines of `look.yaml` that place them.
Each round of the redraw added modules on top of the earlier ones; `src/` holds the latest version of every module
the exports reach (moved here from the library 2026-11-27), `ref/` the user's references and the data cut from them.
The review sheets of each round stay in the library (`survivium-builds/trees-redraw/`, its HANDOFF.md has the
user's picks round by round).

Needs numpy, Pillow and scipy (`pip install numpy pillow scipy`). Once, from the repository's root:

```
python3 tools/art/trees/setup.py     # ref/c_n.png, l_n.png, k_n.png from the GIFs, ref/bark/pine_bark.png from the game
```

Then, from `tools/art/trees/src/`, a species' pictures are made again step by step, each export into a folder of
its own outside the repository (`<out>`), each pack writing into the repository (`<repo>`, the path of its root):

| Step | Export | Pack into `content/plants/<key>/tree/` |
|---|---|---|
| the broadleaf trees: `frames.png`, `bare.png`, `look.yaml` | `python3 export_pr1.py <out>/e1 <keys> 4` | `python3 pack_pr1.py <out>/e1 <repo> <keys>` |
| the conifers | `python3 export_pr2.py <out>/e2 <keys> 4` | `python3 pack_pr2.py <out>/e2 <repo> <keys>` |
| the willow and the palms | `python3 export_pr3.py <out>/e3 <keys> 4` | `python3 pack_pr3.py <out>/e3 <repo> <keys>` |
| the seasons: winter `bare.png`, `snow.png`, `snow_dry.png`, `frames.png` re-laid | `python3 export_pr4.py <out>/e4 <keys> 4` | `python3 pack_pr4.py <out>/e4 <repo> <keys>` |
| the stumps: `stumps.png` | `python3 export_pr5.py <out>/e5 <keys> 4` | `python3 pack_pr5.py <out>/e5 <repo> <keys>` |
| the pieces in the woods: `pieces.png` | `python3 export_pieces.py <out>/ep <keys> 4` | `python3 pack_pieces.py <out>/ep <repo> <keys>` |

then, from the root, `python3 tools/tree_feet.py` (the trunk's `foot`, `taper`, `cut` and `top` in each look.yaml;
`tools/lint.py` fails while they are stale). `<keys>` is a comma-separated list of species (`oak,birch`); left out,
each step takes all of its own (`export_pr1.BROADLEAF`, `export_pr2.CONIFERS`, `export_pr3.KEYS`, `export_pr4.ALL`,
every tree for the stumps and pieces). The last number is the worker processes. A pack replaces what its step
wrote before, so a step is run again with the steps after it. A species' pictures come out the same as the
repository's pixel for pixel (checked for the oak when the program was moved here). The exports are slow: the oak
takes about a quarter of an hour for its frames on 4 cores, and as much again for its winter.

`decode_pr1.py`, `decode_pr2.py`, `decode_pr3.py` are the game's shader rules in numpy, and `chk_pr1.py`, `chk_pr2.py`
compare an export against the drawing pixel for pixel. The labels in Russian in the modules are the captions of the
review sheets the user read.
