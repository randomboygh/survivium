# The balance change plan

Status: ACTIVE. What of [GAME_BALANCE_AUDIT.md](GAME_BALANCE_AUDIT.md) this task did (2026-11-07) and what
remains, by priority; the systems it touches and the risks. What was done, in detail —
[GAME_BALANCE_REPORT.md](GAME_BALANCE_REPORT.md). A Russian copy: [GAME_BALANCE_ROADMAP_RU.md](GAME_BALANCE_ROADMAP_RU.md).

## Critical — done

| What | Systems | Risk | State |
|---|---|---|---|
| Separate a tool's strength from a skill's action: the blow is the tool's, pace/strength/extra piece/wear are the skill's (`SkillSet.blow`, `effort`, `care`; `Tools.ROLE_OF`) | hands and world, character, crafting | the number of blows on a tree grew: progress_test is longer | done |
| Trees' durability ×4 (12–32) and the cells' `toughness`; `Tools.swing_time` by durability | trees' and materials' data, hands and world | the feeling «a tree became long» with a stone axe (6–16 blows) | done |
| Separate the steps of pickaxes, shovels, axes, swords by `swing` | the tools' data | — | done |

## High — done

| What | Systems | Risk | State |
|---|---|---|---|
| Stamina: rest during work 0.6 (`Vitals.WORK_REST`, `BUSY`), a swing's price × skill | character | a strong tool tires in 11–15 s in a row; progress_test resets strength itself (`_rest`) | done |
| Wear on by default, durabilities ×3, the skill's care | rules, crafting, settings | old players will see wear for the first time; the switch stayed | done (the user's choice 1А) |
| The experience curve 120 / 1.45 (the tenth level ≈ 3 h of work) | skills | old saves' points make more levels: a gift, not a loss | done (choice 2А) |
| A skill's scale without «from the tool» divisions, a hint with the effects, the «Strength» chip with an example | interface | — | done |
| Big animals ×2 health, Hunting +50 % to the blow at the maximum | animals, hands and world | hunting a bear with a stone sword — 25 blows (a spear/bow — 13/10) | done |
| `pvp_damage` 5 → 4 | the server's rules | a server config with an explicit value does not change | done |
| Tables from data (`tools/balance_report.gd`) and the limits test (`balance_test.gd`) | tools, tests | — | done |

## Medium — remaining

| What | Why | Systems | Risk |
|---|---|---|---|
| Durability and `toughness` of cells for buildings (log wall 4, planks 3, brick 3, hewn stone 4) discuss with the decay of buildings (the backlog) | knocking down walls must cost effort, but not be a punishment | building, territory | a design decision |
| Digging: give Digging a `yield` on a cell's `bonus` (flint from earth, fibre from grass) | the Digging skill gets only pace and strength | hands and world | small; can be done by data if `bonus_chance` is multiplied by the skill |
| Sleep, cold, thirst: the thresholds were not touched; check on a phone with 40-minute days after wear was switched on | whether survival is a routine | character | playtest only |
| Fishing: `each` 20 and `yield` 0.5 with no casting time in points | Fishing grows only with the catch | fishing | small |
| Crafting: the points are a recipe's time with fading; the tenth level ≈ 2000 recipes | may turn out the longest skill | crafting | playtest: on complaints raise `first`/lower `growth` only for Crafting in the YAML |

## Low — remaining

| What | Why | Systems |
|---|---|---|
| The balance report in CI (`balance_report.gd -- --check` beside `content_report`) | the tables will not go stale unnoticed | CI |
| Show the «Blow, s» chip with the skill (now — without) | fairer to the player | interface |
| Armour, shields, an animal's damage to a player | they are not in the game; when they appear the model extends with the field `armor` of `wear_on` and `attack` of a creature | design |
| Era 7 (late materials): `power` 7–8 will need the new ores' `toughness` 10–12 and trees unchanged | the row is open upward | data |
