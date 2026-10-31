# Зависимости

Статус: ACTIVE, 2026-10-30. Две карты: **что какой скрипт грузит** (`preload` / `extends`; таблица по
папкам генерируется в [generated/code-index.md](generated/code-index.md), по файлу —
`python3 tools/doc_index.py uses <путь>`) и **кто кому передан во время игры** (Main раздаёт объекты,
правила шлют сигналы; это ниже, вручную).

## Слои

```mermaid
graph LR
  subgraph client["src/client/"]
    main["main.gd"]
    cworld["world/"]
    view["view/"]
    input["input/"]
    cgame["game/"]
    audio["audio/"]
    ui["ui/"]
    cnet["net/"]
  end
  subgraph server["src/server/"]
    requests["requests.gd"]
  end
  subgraph shared["src/shared/"]
    net["net/"]
    game["game/"]
    world["world/"]
    content["content/"]
  end
  main --> cworld & view & input & cgame & audio & ui & cnet
  cnet -. local_host.gd .-> requests
  client --> net & game & world & content
  requests --> net & game & content
  game --> world --> content
  game --> content
  net --> content
```

Запрещено (тест `_test_layers`): `src/shared/` → `src/client/` или `src/server/`; `src/server/` →
`src/client/`; `src/client/` → `src/server/` кроме `net/local_host.gd`; внутри shared обратные стрелки
(`content/` не грузит `world/`, `game/`, `net/`; `world/` не грузит `game/`, `net/`; `net/` грузит только
`content/`).

## Узлы, от которых зависит больше всего

Больше 30 файлов грузят `src/shared/content/materials.gd`, `src/shared/world/world_data.gd`,
`src/shared/content/items.gd`; больше 15 — `src/client/ui/ui_style.gd`, `src/client/view/pixel_view.gd`,
`src/shared/content/content.gd`, `src/shared/content/trees.gd`, `src/shared/world/world_gen.gd`.
Правка их интерфейса затрагивает генератор, меши, правила, UI и тесты: перед правкой
`python3 tools/doc_index.py uses <путь>`.

## Правила внутри shared

| Скрипт | Грузит |
|---|---|
| `game/world_actions.gd` | `world_data`, `materials`, `items`, `tools`, `trees`, `bushes`, `plants`, `grass` |
| `game/wildlife.gd` | `world_data`, `body`, `ai_rules`, `materials`, `grass`, `biomes` |
| `game/placed.gd` | `world_data`, `materials`, `items`, `inventory`, `body` |
| `game/character.gd` | `inventory`, `vitals`, `items`, `world_data` |
| `game/workshop.gd` | `crafting`, `craft_queue`, `knowledge`, `items` |
| `game/clock.gd` | `world_gen`, `biomes`, `world_data` |
| `world/world_gen.gd` → `world/land_layout.gd` | `materials`, `biomes`, `trees`, `bushes`, `world_data` |
| `world/world_data.gd` → `world/world_cells.gd` | `materials`, `trees`, `items` |

## Кто кому передан во время игры

Main создаёт модули и раздаёт им соседей (см. [ARCHITECTURE.md](ARCHITECTURE.md), «Main и модули»).
Общие правила получают объекты, а не грузят их скрипты: `WorldActions.new(world, clock, settings)`,
`Workshop.new(character, placed, settings)`, `Storms.new(world, clock, actions)`; `wildlife.world`,
`.gen`, `.clock`; `clock.world`, `.gen`; `character.world`, `.placed`, `.clock`. Настройки (`settings`)
— клиентский объект, правило читает из него только значения.

```mermaid
graph LR
  actions["WorldActions"] -- cell_changed / looks_changed --> chunks["ChunkStreamer"]
  actions -- drops_changed / taken --> props["Props"]
  placed["Placed"] -- added / removed / lit_changed --> props
  placed -- cell_changed --> chunks
  wildlife["Wildlife"] -- born / gone / stepped --> creatures["Creatures"]
  clock["Clock"] -- season_changed --> sky["Sky"]
  inventory["Inventory"] -- changed --> hud["HUD, окно сумки"]
  workshop["Workshop"] -- changed / made --> hud
  knowledge["Knowledge"] -- learned --> hud
  storms["Storms"] --> actions
  save["SaveGame"] -. to_dict / from_dict .-> inventory & workshop & knowledge & clock & placed
```

## Данные

Записи модов связаны ссылками (`ref:<вид>`): рецепт → предметы и станок, предмет → материал,
куст, растение, дерево → предметы, биом → деревья и кусты, существо → растения и биомы. Жёсткая ссылка
связывает бандлы, мягкая только задаёт порядок ([DATA_MODEL.md](DATA_MODEL.md)). Зависимости
конкретного бандла: `Content.deps(b)`, со всеми, без кого он не может, — `Content.closure(b)`; полный
реестр записей с бандлами и связями — [generated/content-index.md](generated/content-index.md).
