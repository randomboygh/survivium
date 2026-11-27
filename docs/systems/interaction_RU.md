# Руки и мир: копать, строить, рубить, косить, собирать

Английская версия: [interaction.md](interaction.md) (она основная, эта — копия).

Статус: ACTIVE.

**Назначение.** Что руки персонажа делают с миром: копают ячейки, ставят блоки, рубят и валят деревья,
косят траву, ломают ветки, собирают ягоды, сажают, работают кнопкой действия перед собой, поднимают
лежащее. Правила общие (их проверит сервер), ввод и подсказки — клиентские.

**Куда смотреть.** Эта страница — обзор; файлы и подробности разложены по темам в `interaction/`: читайте
только ту страницу, которой касается правка.

| Тема | Страница |
|---|---|
| Рубка, правила рук, плоты и лодки. | [interaction/hands_RU.md](interaction/hands_RU.md) |
| Чертёж (планы) и что может инструмент. | [interaction/plans_RU.md](interaction/plans_RU.md) |
| Управление, режим строительства, режим земледелия и их панели. | [interaction/build-mode_RU.md](interaction/build-mode_RU.md) |
| Рамка курсора, призрак чертежа, сбор и вещи на земле. | [interaction/cursor-gathering_RU.md](interaction/cursor-gathering_RU.md) |

**Контракт `who`** (общий `src/shared/game/character.gd` и его наследники). `inventory`, `position`,
`held_back`, `feet()`, `facing_step()`, `moving()`, `overlaps_cell(cell)`, `held()`, `tool()`, `brush()`,
`act(action)` (платит выносливостью, false — нет сил), `give(id, n, worn)`, `use_tool()` (износ),
`nag(reason, text)`, `say(text)`, `note(stat, n)` (статистика жизни), `is_dead()`, `sacks` (где лежат мешки
после смерти). Взмах, который что-то сделал, возвращает `{"swing", "work", "time", "at"}`, пустой — `{}` или
только `{"swing"}`.

**Данные.** Земледелие: материалы ролей `bed` / `bed_wet` (бандл `resources/soil`), предметы с `crop`
(зерно), растения вида `crop` (`grows: field`, `grow_days`, `mown`, кадры стадий; пшеница — бандл
`plants/ears`, репа, морковь, горох — `plants/turnip`, `plants/carrot`, `plants/peas`, посевной лён —
`plants/flax`; их семена находят, срезая дикие растения: поле `finds`, `Plants.harvest`), ростки вида
`sapling` (`tree` — порода, в которую вырастает; жёлудь и шишка — их `crop`): сажаются на открытую землю на
решётке деревьев (нечётные x, z, `sapling_spot`, `can_root`: не ближе `SAPLING_GAP` к дереву или ростку),
растут в тёплые сезоны без полива (лейка грядку с ростком не поливает: третье поле его записи — признак
деревца, не сырость; `can_water`, `wet`): росток и побег (кадры шириной `across` карточек, `foliage._crop`
ставит их на один корень со сдвигом в 4-м поле: `grass.gdshader`), с доли `young` срока — маленькое деревце
(`grow_young`, `Growth.place_young`; ствол тонкий, `Growth.YOUNG_GIRTH`, по записи ростка под ним:
`Growth.young_at`; срубленное даёт только ветки: `young_tree`, `Felling.fell(…, young)`), выросший становится
деревом (`grow_tree`: деревце убирает `Felling.clear`, потом `Growth.place`), если над ним есть место; тяпка
(`tools/hoe`, класс `hoe`), серп (`tools/sickle`, класс `sickle`), лейка (`tools/watering_can`, класс `can`);
грядки — `WorldData.fields`. Предметы с `tool`, `power`, `area`, `reach`, `swing`, `mows`, `durability`,
`repair`, `anim`, `hands`, `trail` (вид `items`); материалы с `dig`, `hardness`, `item`, `bonus`, `mow`,
`mow_gives` (вид `materials`); деревья и кусты — что дают (`log`, `twig`, `seed`, `fruit`). Стройка берёт
блоки из сумки (бесплатно — переключатель «Тестирования»; копание, покос и сбор урожая дают своё и тогда).

**Подводные камни.** Клиент сетевой игры берёт клетку с сервера (`Protocol.CELLS`) через `Mirror.take_cell`:
политая или высохшая грядка сохраняет посев (`set_cell` стирает запись `fields`). Касание пальцем в браузере
приходит ещё и как `InputEventMouseMotion`: `controls.input` считает движение мыши мышью, только когда нет
пальца и прошло больше 1 с после касания. Джойстик и `TouchButton` следят за своим индексом касания, чтобы
работали два пальца.

**Тесты.** `tests/unit/boat_test.gd` (спуск, в том числе на плоскую воду моря, ход по воде, двое в лодке,
берег, судно у берега и в сумку, вёсла, сохранение, лёд, смерть),
`tests/unit/farming_test.gd` (грядка, посев, полив, дождь, рост, зима, жатва, сохранение),
`tests/unit/actions_test.gd` (`felling`, `front_choice`, `snow_gathered`, `world_actions`, `stairs_placed`,
`placed`, `start_camp`, `lights`, `drinking`, `furniture`, `openings`),
`tests/unit/plans_test.gd` (формы чертежа, стройка по клеткам из сумки, стирание, сохранение, вещи-призраки:
поставлены, сдвинуты, повёрнуты, сняты, сохранены, построены после блоков, `_test_ghost_things`),
`tests/unit/content_test.gd` (`tools`), `tests/progress_test.gd` (весь путь игры от голых рук до всех
рецептов через те же вызовы). После правки инструментов, материалов, станков, рецептов или рук —
обязательно `progress_test`.

**Подробнее.** `plan/design/character.md` («Взаимодействие с миром»), `plan/design/ui.md` (управление).
