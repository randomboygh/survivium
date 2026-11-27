# Beasts

Status: ACTIVE. A Russian copy: [wildlife_RU.md](wildlife_RU.md).

**Purpose.** The world's animals. A kind sets only properties; who is food and a threat to whom is derived by
shared rules. Beasts appear around people, roam, graze, rest outside their hours, flee from threats, hunt when
hungry; packs follow a leader, flyers roost in crowns, climbing walkers climb trees, swimmers keep to open
water, a kind with `biomes` appears only on its own land.

**Where to look.** This page is the overview; the files and the detail are split by topic into `wildlife/`: read
only the page the change reaches.

| Topic | Page |
|---|---|
| `wildlife.gd` and its chain of parts. | [wildlife/rules.md](wildlife/rules.md) |
| Rules by properties, the client's copy, drawing, voices. | [wildlife/client.md](wildlife/client.md) |
| The kind `creatures` and its fields. | [wildlife/data.md](wildlife/data.md) |

**Who uses it.** The world session (`session.gd`: creates, `start_wildlife` after the world is ready, the step
`step_wildlife` every frame from Main), `player_link.gd` (events for the client); the copy — `creatures.gd`,
`voices.gd`, tracks, `fire_shadows.gd` (the beasts' shadows by a fire); tests and `tools/shot.gd` write into
`main.session.wildlife`.

**Limits.** A walker does not reach a swimmer and the other way round, a flyer reaches both. The column's
biome is taken from `gen.lay_out`. Only fish dive (see Depth); the beast's side on the client is derived from its
movement, the server does not know it. The voices are brought by a bundle as ready `.wav` (the synthesis — a
table in `tools/make_sounds.gd`).

**Tests.** `tests/unit/wildlife_test.gd` (`ai_relations`, `wildlife`, `climbers`, `biomes`, `swimmers`,
`fishing`, `birds`, `shore`, `jostle`, `hunting`, `fire`, `taming`, `attacks`; a pack waits for the ticks of
thinking, not for the order of random numbers); the drawn ones: `tests/unit/view_test.gd` (`animal_flinch`,
`boar_states`: the boar's frames and its body, `fox_states`: the fox's, `grouse_states`: the grouse's wing beats and steps, `deer_states`: the deer's).

**In more detail.** `plan/design/creatures-ai.md`; `plan/architecture/ai.md` — the idea of the behaviour
engine (the formulas are marked as a draft, in the code it is simpler).
