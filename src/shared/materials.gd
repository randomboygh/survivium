extends RefCounted
## Cell materials of the prototype. In the MVP they move to data files in content/core.

const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const WATER := 5
const LOG := 6
const LEAVES := 7
const PLANKS := 8
const CLAY := 9
const COPPER_ORE := 10
const BRICK := 11
const COUNT := 12

const NAMES := [
	"Воздух", "Трава", "Земля", "Камень", "Песок", "Вода",
	"Бревно", "Листва", "Доски", "Глина", "Медная руда", "Кирпич",
]

## Blocks the player can place, in hotbar order.
const PLACEABLE := [STONE, DIRT, PLANKS, BRICK, SAND, CLAY, LOG]


static func is_solid(m: int) -> bool:
	return m != AIR and m != WATER


## Solid cells that count as a roof for the level cutaway (tree trunks and crowns do not).
static func is_roof(m: int) -> bool:
	return is_solid(m) and m != LEAVES and m != LOG


## Loose ground that lies as a slope where it steps down one level (see WorldData.slope_mask).
static func can_slope(m: int) -> bool:
	return m == GRASS or m == DIRT or m == SAND or m == CLAY
