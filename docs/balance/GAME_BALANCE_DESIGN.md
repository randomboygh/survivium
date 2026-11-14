# The balance model

Status: ACTIVE. One mathematical model of the game's characteristics (the task `game_balance.md`, 2026-11-07):
what each quantity means, where it lies, how it is computed and how it is shown. The tables by these formulas
from live data — [GAME_BALANCE_TABLES.md](GAME_BALANCE_TABLES.md) (`tools/balance_report.gd`), the limits they
must stay within — `tests/unit/balance_test.gd`; what was before it — [GAME_BALANCE_AUDIT.md](GAME_BALANCE_AUDIT.md),
what is still to come — [GAME_BALANCE_ROADMAP.md](GAME_BALANCE_ROADMAP.md). The numbers below are the mods'
data on the day of writing; the truth is in the YAML and the tables. A Russian copy:
[GAME_BALANCE_DESIGN_RU.md](GAME_BALANCE_DESIGN_RU.md).

## 1. The principle

**The tool decides how much work a blow does. The skill decides how the hand strikes.** Two axes that multiply
and do not replace each other:

| Axis | What it changes | Where it lies | What it does not change |
|---|---|---|---|
| Tool (`items`: `power`, `swing`, `area`, `reach`, `durability`) | how much durability a blow takes, how many cells it takes, how far it reaches, how many blows it lives | the tool bundle's YAML | the hand's pace: does not make a swing faster than its own `swing` |
| Skill (`skills`: `speed`, `effort`, `yield`, `care`, `quality`, `might`) | the pace of a swing and a recipe, how much strength a swing costs, the chance of an extra piece, the chance not to wear, the durability of what is made; in hunting — an addition to the blow | `content/core/data/skills.yaml` | the number of blows on a tree and a cell (`might` of chopping and digging is 0) |
| Object (`trees.hits`, `materials.hardness` and `toughness`, `creatures.health`) | how much work it needs, what strength of tool takes it at all | the bundle's YAML | — |

So a steel axe is faster than a stone one at any level (three times fewer blows), and the tenth level of
Chopping is faster than the zeroth with any axe (twice in time, 40 % cheaper in strength): neither axis devalues
the other. The formulas are the same on the server (the rules of `src/shared/game/`), in the character window
and in the hints (`FactChips.power_hint`, `PersonPanel._show_skills` call the same functions `Tools.hits_to`,
`Tools.swing_time`, `SkillSet`), and in the tables' report. The critical computations are on the server: the
rule's `who` is `src/server/player.gd`, its bag and skills; the client gets a copy of the skills
(`Protocol.SKILLS`) and computes by it only what it shows.

## 2. The quantities

| Quantity | Meaning | Unit | Limits | Where computed | How shown |
|---|---|---|---|---|---|
| `power` (strength) | how much durability one blow takes | durability points | hands 1; tools 1–8 | data | the chip «Strength» with a hint: how many blows on an oak / a stone / the biggest animal (`FactChips.power_hint`) |
| `swing` (blow) | seconds per swing with no skill | s | 0.14–0.9 | data | the chip «Blow, s» |
| a tree's `hits` | durability: how much strength must be collected by blows | points | 12–32 (soft 12, oak 24, ceiba 32) | `Trees` | «N blows left» — `Tools.hits_to(hits − collected, blow)` |
| a cell's `hardness` | what strength a pickaxe or axe must have to take it at all (a gate) | points | 1–4 | `Tools.can_dig` | «A sturdier pickaxe is needed» |
| a cell's `toughness` | durability: how many times longer a weaker blow takes | points (0 — as `hardness`) | stone 3, copper 4, tin 5, iron 8 | `Tools.swing_time` | the swing time |
| an animal's `health` | blows of strength 1 | points | small 3–5, big 22–50 | `Wildlife.hurt` | — (the animal runs and falls) |
| a skill's level | 0..`levels` (10) | — | points `first`·(`growth`^n − 1)/(`growth` − 1) | `Skills.level_at` | a scale of 10 divisions, a thin line to the next, a hint with the effects |
| a skill's share `share` | level / `levels` | 0..1 | — | `SkillSet.share_of` | in the hint in percent |
| stamina | 0..100, the swing's price from `Vitals.COSTS` | points | — | `Vitals.spend` | a bar |

Intermediate values are not rounded: a blow with `might` is rounded once (`SkillSet.blow`), the number of blows
is rounded up once (`Tools.hits_to`), the time is not rounded at all.

## 3. The formulas

**A blow** (`SkillSet.blow`): `blow = max(1, round(power × (1 + might × share)))`. `might` is 0 for all skills
except Hunting (0.5): a sword of strength 6 at the tenth level hits for 9, a stone one (2) for 3. On a player
the blow is only `power` (`Fights.strike`): PvP does not reward hunting animals.

**Chopping** (`WorldActions.chop`): blows are collected in `chops[column]`; the tree falls when the sum ≥
`hits`. Blows = `⌈hits / blow⌉`; time = blows × `swing` × `pace`; strength = blows × `COSTS.chop` × `effort`.
The Chopping skill with the chance `yield × share` (0.5 at the last) lays one more log at the stump.

**Digging a cell** (`Tools.swing_time`): `time = swing × max(1, toughness / power) × pace` (hands in soft ground
still × `hand_slow`); the `can_dig` gate: `power ≥ hardness` for a pickaxe and an axe. A tool stronger than the
cell does not hit faster than its own `swing` — the steps of pickaxes differ by their `swing` (0.55 → 0.32) and
by the fact that on hard ore a weak pickaxe lingers (bronze on iron ore 0.8 s, steel 0.43).

**Pace** (`SkillSet.pace`): `pace = 1 / (1 + speed × share)`; `speed` 1 — twice as fast at the last level. It
divides the swing's time (`WorldActions.skilled`), the recipe's (`Workshop.time_of`), and in swimming multiplies
the speed in water.

**Strength** (`Vitals.spend`): `price = COSTS[action] × (1 − effort × share)`; work with a price ≥ `WORK_COST`
(1) makes the body busy for `BUSY` (1 s), and rest in that time goes at `WORK_REST` (0.6) of the usual `REST`
(12/s). Work that spends less than 7.2 per second does not tire at all (hands, a stone pickaxe); a stone axe
with no skill — 88 s in a row, a steel one — 15 s, but in those 15 s it fells nine oaks against one and a
half. What to count: the price of one tree or cell, not the seconds to zero: an oak with a stone axe — 60
strength with no skill, 36 at the tenth level, with a steel one — 20.

**Wear** (`Workshop.use_tool`): a swing takes 1 from `durability` if the skill did not spare the tool (the
chance `care × share`, 0.5 at the last); a recipe takes `wear` blows from a tool of its class, and Crafting
spares it likewise. A thing's quality (decision 181, `Quality`) changes its durability: `durability × (1 + (q −
50)/100)` — 100 gives +50%, 10 — −40%; and the swing's pace: `× (1 + 0.003·(q − 50))`, 100 gives ×1.15. What is gathered: `35 +
5·strength (up to 30) + (the tool's quality − 50)/5 + quality·share ± 5`; what is made: the average of the
materials, not above `50 + quality·share` (Crafting, Cooking — 50) and the `quality_cap` of the station and the
recipe. Wear is on by default (`Rules.tool_wear`; «Testing» switches it off); the durabilities: a stone axe 360
blows ≈ 30 oaks, a steel one 3600 ≈ 900; repaired by `repair`.

**Experience** (`SkillSet.gain`): points are seconds of work *with no skill* (a swing that did something; a
recipe — its time, the same one in a row 0.85 times less each time, not below 0.2; a whole thing — `each`: an
animal 30, a fish 20), so levelling does not slow down when the hand speeds up. Level n costs `first ×
(growth^n − 1) / (growth − 1)`: `first` 120, `growth` 1.45 → the first for 2 min of work, the fifth for 24
min, the tenth for ~3 h (an oak with a stone axe — 7 points, the 1st level — 17 oaks, the 10th — ~1500). Digging
one's own block and putting it back gives no experience.

**Food** (`Vitals`): satiety −60 per game day (40 min at the normal clock rate), water −70, healing +50 at
satiety > 50; roast meat 30, flatbread 25, berries 2–4. Not changed: the table in TABLES, «Food against
hunger».

## 4. Progression by eras

| Era | Tools (strength) | What it opens in gathering | What to expect of a blow |
|---|---|---|---|
| 0 hands | 1 | grass, twigs, berries, soft ground (0.9 s/cell) | a small animal in 3–5 blows |
| 1 stone/wood | axe 2, pickaxe 2, sword 2, spear 4, bow 5 | stone, copper ore (durability 3–4), trees 6–16 blows | a wolf 11 blows with a sword, 6 with a spear, 5 with a bow |
| 3 copper | 3 | tin (hardness 3) | an oak 8 blows |
| 4 bronze | 4 | iron, gold, silver, platinum (hardness 4) | an oak 6 blows, a wolf 6 |
| 5 iron | 5 | the same faster (0.36 s a blow, 0.58 on iron ore) | an oak 5 |
| 6 steel | 6 | the same faster (0.32; 0.43) | an oak 4, a wolf 4, a bear 9 |

Each step is noticeably faster than the previous on everything it took, and brings new kinds of cells; the old
tools are not wholly devalued: a stone axe at the tenth level (3.6 s an oak) is faster than a steel one with no
skill only on soft kinds, a steel one with no skill (1.4 s) is faster than a stone one at any level.

## 5. Specialisation

Items of one step are not alike: a sword — reach 8, mows tall grass and knocks berries down; a knife — light,
short, fast (0.3 s), dresses carcasses; a spear — the strongest in the hand (4/6/8), slow (0.7 s), is thrown
and picked up; a sling and a bow — reach 20–36 and the use of charges; wooden pickaxe, scythe and sword — weaker than stone, but made by hand from branches and cord before flint is found; a knife hits one less than a sword of its metal (it butchers). The «Twins» check of the content graph does not let two items coincide in everything.

## 6. Display

- A skill's scale in the character window shows **only the level** (a division is a level of 10) and the way to
  the next; the green «from the tool» divisions are gone: a tool's strength is not a skill's level.
- The scale's hint — what the level does now: «Work faster by N%», «Less strength per swing by N%», «One more
  piece: chance N%», «A stronger blow by N%», «Quality of what is gathered +N» or «Quality of what is made up to
  N», «The tool does not wear: chance N%», and which tool in the hand this skill leads (`Tools.ROLE_OF`, one
  map for the rules and the window).
- The tool's «Strength» chip explains the number by an example from data: an oak (durability 24) — N blows; a
  stone (durability 3) — a blow of 0.8 s; a bear (health 50) — N blows.
- The message «blows left» is computed by the same `Tools.hits_to` as the tree's fall.

## 7. Automatic checks

`tests/unit/balance_test.gd` (in `run_tests`): a class's steps are no weaker, no slower and no more fragile than
the previous and do not coincide; the weakest axe fells any tree in ≤ 20 blows, the best — the hardest in ≥ 5
and none in one; an oak: the last level cuts the time by ≥ 40 % with any axe, the best axe with no skill is
faster than the weakest at the tenth, the best at the tenth — not less than half a second and three blows; each
cell is dug by the first fitting tool in no more than 4 of its swings, each step of pickaxes is faster on the
hardest; a big animal (mass ≥ 20) — ≥ 3 blows with the best weapon; the first level of any skill ≤ 5 min of
work, the last 1–6 h, `speed` ≤ 1.5, `might` ≤ 1, a skill other than hunting does not change the blow; a steel
axe tires, but not faster than 8 s, an oak at the tenth level costs ≤ 65 % of the strength of the zeroth; the
best weapon kills a player in ≥ 4 blows, fists in ≥ 20; food as a single piece does not feed for a day, the
best roast > 2× the raw; the rules do what the tables say (chopping, a pickaxe's blow time, a skill's blow).
Each limit with its reason is in the file. The report `tools/balance_report.gd -- --check` fails if the tables
are stale.

## 8. What the model does not touch (and why)

An animal's damage to a player (the kind's field `bite`: a boar 10, a bear 18, a wolf 7 per bite; the rules of
attack are the creatures' AI, `docs/systems/wildlife.md`), there are no armours and shields (not in the game),
the spawn and rarity of resources (the generator, bundles), recipes and their prices (the logic of chains is
more important than levelling; the table «A tool's price against its term» shows that bronze gives 1500 blows
for 2 ingots, steel 3600 for 2: each step pays off). Open questions — in
[GAME_BALANCE_ROADMAP.md](GAME_BALANCE_ROADMAP.md).
