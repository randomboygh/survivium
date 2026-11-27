# The character's animations: the drawings as data

The frames of the character's animations drawn whole, kept as Python data modules (rows of letters per direction and
frame), and the generators that write them into the art tables the game's sprites are made from
(`tools/art/player_<work>_art.gd`, then `tools/make_sprites.gd`). The data modules are the source: a frame is
changed in its module, its generator is run, then the sprites are made again. The thread notes on how they were
drawn are in `docs/planning/character-animations.md`; the review pictures in the library
(`survivium-builds/character/anim/`).

Run from this folder (`python3 -B`, so no `__pycache__` is left here):

| Writes | Command |
|---|---|
| `tools/art/player_swim_art.gd` | `python3 -B gen_swim_gd.py swim_a ../player_swim_art.gd` |
| `tools/art/player_chop_art.gd` | `python3 -B gen_chop_gd.py chop_k ../player_chop_art.gd` |
| `tools/art/player_dig_art.gd` | `python3 -B gen_dig_gd.py dig_h ../player_dig_art.gd` |
| `tools/art/player_reach_art.gd` | `python3 -B gen_reach_gd.py reach_f ../player_reach_art.gd` |
| `tools/art/player_slash_art.gd` | `python3 -B gen_slash_gd.py slash_p ../player_slash_art.gd` |
| `tools/art/player_aim_art.gd` | `QUICK=<dir> python3 -B gen_aim_gd.py aim_e ../player_aim_art.gd` (see below) |
| `tools/art/player_eat_art.gd` | `python3 -B gen_eat_gd.py eat_b ../player_eat_art.gd` |
| `tools/art/player_mow_art.gd` | `python3 -B gen_mow_gd.py mow_d ../player_mow_art.gd` |
| `tools/art/player_row_art.gd` | `python3 -B gen_row_gd.py row_f ../player_row_art.gd` |
| `tools/art/player_gesture_art.gd` | `python3 -B gen_gesture_gd.py ../player_gesture_art.gd wave=gestures_i:WAVE nod=gestures_nod_a:ALL_B:0,50 shake=gestures_shake_a:ALL_D point=gestures_point_a:ALL_B beckon=gestures_beckon_a:ALL bow=gestures_bow_a:ALL_B clap=gestures_clap_a:ALL_D` |

Each writes its table again byte for byte from the modules as they are here (checked when they were moved here from
the library, 2026-11-27). A module named later in a chain builds on the earlier ones (`chop_k` on `chop_e`, `slash_p`
on `slash_a`…`slash_o`): the earlier ones are the drawings the user went back to, not drafts to delete.

The bow (`aim_d.peeled`) takes the figure's outline from the default look's bare sheet, which `quick.gd` draws
straight from `PlayerArt` in seconds. Godot leaves this folder alone (`.gdignore`), so the script is run from a copy:

```
cp tools/art/character/quick.gd tools/_quick.gd
godot --headless --path . --script res://tools/_quick.gd -- /tmp/q   # writes /tmp/q/bare.png, layout.json
rm tools/_quick.gd
```

and `QUICK=/tmp/q` is given to `gen_aim_gd.py` (without it the sheet is looked for in `../q`).

After a table changes: `godot --headless --path . --script res://tools/make_sprites.gd -- --all`, then `--import`,
and check that only the animation's columns changed in the pictures.
