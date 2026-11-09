# Документация Survivium

Статус: ACTIVE. Вход в документацию. Здесь описан **код как он есть**; что игра должна делать
(геймдизайн), принятые решения, этапы и бэклог живут в библиотеке проекта Claude, папка `plan/`
(«библиотека» ниже), и сюда не копируются.

## С чего начать

1. [`../CLAUDE.md`](../CLAUDE.md): коротко о проекте, правила, проверки, порядок работы.
2. [PROJECT_MAP.md](PROJECT_MAP.md): где что лежит и куда класть новое.
3. [SYSTEMS.md](SYSTEMS.md): найти свою систему, затем открыть только её файл в [systems/](systems/).

Вся документация разом не читается: задача начинается с контекста одной системы.

## Документы

Статусы: **ACTIVE** — описывает код как он есть, по нему работают; **DONE** — выполненный план этапа, его
открытые хвосты помечены в тексте; **ARCHIVED** — отчёт или снимок на свою дату: история и причины
решений, не инструкция (пути и числа там — того дня). Сгенерированные файлы руками не правятся.

**Общее**

| Документ | Назначение | Статус | Кому и когда |
|---|---|---|---|
| [`../CLAUDE.md`](../CLAUDE.md) | коротко о проекте, правила кода, порядок работы, проверки, подводные камни | ACTIVE | всем, перед любой задачей |
| [`../README.md`](../README.md) | что есть в игре, как играть, свой сервер, как устроена разработка (по-русски) | ACTIVE | игроку и новому разработчику |
| [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) | что за игра, что сделано и чего нет, движок, ограничения | ACTIVE | впервые в проекте |
| [PROJECT_MAP.md](PROJECT_MAP.md) | дерево каталогов, ключевые файлы, куда класть новое, что не читать | ACTIVE | найти место файла |

**Архитектура и решения**

| Документ | Назначение | Статус | Кому и когда |
|---|---|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | слои, точки входа, модули `Main`, сеанс и сервер, сигналы, работа по кадрам, как расширять | ACTIVE | менять связи систем, добавлять систему |
| [DEPENDENCIES.md](DEPENDENCIES.md) | граф слоёв и папок, узлы с многими зависимыми, кто кому передан во время игры | ACTIVE | что сломается от правки |
| [DECISIONS.md](DECISIONS.md) | архитектурные решения с причинами и номерами журнала `plan/README.md` | ACTIVE | прежде чем менять принцип |
| [ROADMAP.md](ROADMAP.md) | где этапы и бэклог; технический долг Т1–Т11 и его состояние; отчёты этапов | ACTIVE | планировать работу |
| [generated/code-index.md](generated/code-index.md) | каждый скрипт с первой строкой его описания, какие папки какие грузят (`tools/doc_index.py`) | генерируется | найти файл по смыслу |

**Игровые системы**

| Документ | Назначение | Статус | Кому и когда |
|---|---|---|---|
| [SYSTEMS.md](SYSTEMS.md) | каталог систем: главные файлы, контекст, тесты; чего ещё нет | ACTIVE | любая задача: найти свою систему |
| [systems/](systems/) | контекст каждой системы (18 файлов): назначение, файлы, интерфейсы, данные, подводные камни, тесты | ACTIVE | перед правкой системы — только её файл |

**Модель данных, бандлы, рецепты и производство**

| Документ | Назначение | Статус | Кому и когда |
|---|---|---|---|
| [DATA_MODEL.md](DATA_MODEL.md) | моды, бандлы, виды записей и их число, id, роли, ассеты, номера материалов, сохранения | ACTIVE | данные, контент, моды |
| [systems/content.md](systems/content.md) | код загрузчика и реестров, граф контента, как добавить поле и вид | ACTIVE | менять загрузчик, схему, реестр |
| [specifications/BUNDLE_SYSTEM.md](specifications/BUNDLE_SYSTEM.md) | система игровых бандлов (решение 152): понятия, id и имена, виды, связи, рецепты, станки, инструменты, эпохи, граф и проверки, что добавляется без кода | ACTIVE | менять виды контента, рецепты, станки, инструменты |
| [systems/crafting.md](systems/crafting.md) | крафт, очередь, станки флагами, вещи на клетках (двери, окна, лестницы, мебель, камин) | ACTIVE | рецепты и станки в игре |
| `content/<мод>/README.md` | как устроен мод и как добавить в него своё (примеры YAML) | ACTIVE | добавить запись или бандл |
| [generated/content-index.md](generated/content-index.md) | реестр сущностей: моды, бандлы и каждая запись с категорией, бандлом, заменами и патчами, эпохой, числом связей и итогом проверки | генерируется (`tools/content_report.gd`) | найти запись или бандл |
| [generated/content-graph.md](generated/content-graph.md) | граф контента: старт, предметы по глубине, откуда и куда каждый, общие ресурсы, чем что добывается, станки, цепочки, карта эпох, схема рецептов | генерируется | что из чего и чем, в какой эпохе |
| [generated/content-recipes.md](generated/content-recipes.md) | реестр рецептов по процессам: изделие и побочное, что тратит и что держит, станок, инструменты и износ, время, глубина, эпоха, альтернативы | генерируется | баланс рецептов, производственные цепочки |
| [generated/content-checks.md](generated/content-checks.md) | что нашли проверки контента: каждая проверка, что значит и как исправить, найденное | генерируется | тупики, двойники, ошибки графа |

**Баланс**

| Документ | Назначение | Статус | Кому и когда |
|---|---|---|---|
| [balance/GAME_BALANCE_DESIGN.md](balance/GAME_BALANCE_DESIGN.md) | модель баланса: инструмент — удар, навык — рука; величины, формулы, прогрессия, отображение, автоматические пределы | ACTIVE | менять силу, прочность, навыки, выносливость, здоровье зверей |
| [balance/GAME_BALANCE_TABLES.md](balance/GAME_BALANCE_TABLES.md) | таблицы по живым данным: инструменты, дерево × топор × навык, ячейка × кирка, зверь × оружие, PvP, навыки, выносливость, цена и срок, еда | генерируется (`tools/balance_report.gd`) | проверить число перед правкой данных |
| [balance/GAME_BALANCE_ROADMAP.md](balance/GAME_BALANCE_ROADMAP.md) | что сделано и что осталось по приоритетам, системы и риски | ACTIVE | планировать баланс |
| [balance/GAME_BALANCE_AUDIT.md](balance/GAME_BALANCE_AUDIT.md), [balance/GAME_BALANCE_REPORT.md](balance/GAME_BALANCE_REPORT.md) | аудит до проработки 2026-11-07 и отчёт о ней: что найдено, что изменено, тесты, что осталось | ARCHIVED | причины нынешних чисел |

**Тестирование и CI/CD**

| Документ | Назначение | Статус | Кому и когда |
|---|---|---|---|
| [testing/TESTING_GUIDE.md](testing/TESTING_GUIDE.md) | как проверять изменение по уровням, что запускать для какой системы, как добавить тест | ACTIVE | перед пушем |
| [testing/TEST_COVERAGE.md](testing/TEST_COVERAGE.md) | что покрыто чем, что только руками, нестабильные проверки и почему | ACTIVE | прежде чем винить код за красный тест |
| [testing/CI_PIPELINE.md](testing/CI_PIPELINE.md) | задания CI, что блокирует, логи, публикация, безопасность, что делать при красном CI | ACTIVE | когда CI красный, при правке `build.yml` |
| [systems/testing.md](systems/testing.md) | тесты, инструменты `tools/`, CI и версии с «Что нового» | ACTIVE | инструменты и версии |

**Безопасность**

| Документ | Назначение | Статус | Кому и когда |
|---|---|---|---|
| [security/THREAT_MODEL.md](security/THREAT_MODEL.md) | активы, кто нападает, границы доверия, точки входа, классы атак | ACTIVE | менять протокол, сервер, правила, которые зовут запросы |
| [security/NETWORK_SECURITY.md](security/NETWORK_SECURITY.md) | лимиты транспорта, приветствие, что сервер проверяет у каждого запроса и у тела | ACTIVE | новый запрос, новое поле `input` |
| [security/COMMAND_PERMISSIONS.md](security/COMMAND_PERMISSIONS.md) | роли, таблица команд и прав, как добавить команду | ACTIVE | новая команда хозяина |
| [security/ANTI_CHEAT.md](security/ANTI_CHEAT.md) | что замечается, уровни реакции, журнал безопасности, допуски | ACTIVE | менять проверки, разбирать журнал |
| [security/SECURITY_TESTING.md](security/SECURITY_TESTING.md) | тесты безопасности, сценарии ТЗ и где они, как добавить | ACTIVE | проверить защиту, добавить регрессию |

**Аудит, отчёты и планы этапов (история)**

| Документ | Назначение | Статус | Кому и когда |
|---|---|---|---|
| [audit/SECURITY_AUDIT.md](audit/SECURITY_AUDIT.md), [audit/SECURITY_REMEDIATION_REPORT.md](audit/SECURITY_REMEDIATION_REPORT.md) | этап 7 (2026-11-06): аудит безопасности, 22 находки, исправления, тесты, остаточные риски | ARCHIVED | история защиты сервера, что осталось |
| [audit/DOCUMENTATION_AUDIT.md](audit/DOCUMENTATION_AUDIT.md), [audit/DOCUMENTATION_UPDATE_REPORT.md](audit/DOCUMENTATION_UPDATE_REPORT.md) | этап 6 (2026-11-05): аудит документации, что исправлено, расхождения и вопросы | ACTIVE до решения открытых вопросов | что осталось несверенным |
| [audit/TESTING_CI_AUDIT.md](audit/TESTING_CI_AUDIT.md), [planning/TESTING_CI_ROADMAP.md](planning/TESTING_CI_ROADMAP.md), [audit/TESTING_CI_REPORT.md](audit/TESTING_CI_REPORT.md) | этап 5 (2026-11-03): аудит тестов и CI, план (раздел «Дальше» — открытые задачи), итог с замерами | ARCHIVED; план — DONE | история и дальнейшие шаги тестов и CI |
| [audit/CODEBASE_AUDIT.md](audit/CODEBASE_AUDIT.md), [planning/REFACTORING_ROADMAP.md](planning/REFACTORING_ROADMAP.md), [audit/REFACTORING_REPORT.md](audit/REFACTORING_REPORT.md), [audit/PERFORMANCE_REPORT.md](audit/PERFORMANCE_REPORT.md) | этап 4 (2026-11-01): 131 находка по системам, план рефакторинга (что ждёт решения пользователя), что сделано, замеры | ARCHIVED; план и отчёты — DONE | технический долг кода, прежде чем чинить систему |
| [audit/AUDIT_REPORT.md](audit/AUDIT_REPORT.md), [audit/CLEANUP_REPORT.md](audit/CLEANUP_REPORT.md) | этап 0 (2026-10-30): состояние, находки, что почищено | ARCHIVED | история реорганизации |
| [specifications/BUNDLE_SYSTEM_READINESS.md](specifications/BUNDLE_SYSTEM_READINESS.md) | готовность к системе бандлов (этап 0) и ответы на её вопросы | ARCHIVED | история решения 152 |


## Библиотека проекта (`plan/`)

| Что | Где |
|---|---|
| Оглавление и журнал решений (№ 1–167) | `plan/README.md` |
| Этапы MVP и их состояние | `plan/mvp.md` |
| Бэклог (единственный список задач, GitHub Issues не ведутся) | `plan/backlog.md` |
| Геймдизайн по темам | `plan/design/*.md` |
| Подробности реализации: рендер, производительность, моды, сервер | `plan/architecture/rendering.md`, `performance.md`, `modding.md`, `server.md` (сервер построен, этапы С1–С7) |
| Замыслы, ещё не сделанные: редактор, сборки и хостинг (кроме Pages и ПК) | `plan/architecture/editor.md` (PROPOSED), `deployment.md` (PROPOSED); ранний замысел сети `networking.md` — DEPRECATED, заменён `server.md` |
| История закрытых тем (варианты, раунды, старые замеры, выполненные планы) | `plan/history/*.md` |
| Скриншоты по темам (оглавление в README) | `survivium-builds/` |
| ТЗ этапов: 0 (аудит), система бандлов, 4 (рефакторинг), 5 (тесты и CI), 6 (документация), 7 (безопасность), баланс | `audition.md`, `bundles.md`, `refactoring.md`, `testing_ci.md`, `documentation_audit.md`, `security_audit.md`, `game_balance.md` (ARCHIVED, `plan/history/tasks/` библиотеки) |
| План системы бандлов: анализ ТЗ, аудит данных, этапы с файлами и рисками | `plan/architecture/bundle-system.md` |

Статусы документов библиотеки (ACTIVE, DRAFT, PROPOSED, DEPRECATED, ARCHIVED) стоят строкой
`Статус:` под заголовком каждого документа и в оглавлении `plan/README.md`. Документ со статусом
PROPOSED или DRAFT описывает замысел, а не код: что сделано, проверяйте по `docs/` и коду.

Что устарело и куда перенесено (2026-10-30): `plan/architecture/code-structure.md` (DEPRECATED) —
[ARCHITECTURE.md](ARCHITECTURE.md) и [PROJECT_MAP.md](PROJECT_MAP.md), его текст и прежний раздел «Модули»
`plan/architecture/overview.md` — `plan/history/code-structure.md`; старые замеры из `performance.md` —
`plan/history/performance.md`; выполненный план разделения на моды из `modding.md` —
`plan/history/modding.md`; сделанные пункты бэклога — `plan/history/backlog-done.md`.

## Как искать, не читая всё

- Файл по смыслу: [generated/code-index.md](generated/code-index.md), затем `git grep`.
- Кто использует файл: `python3 tools/doc_index.py uses src/shared/game/inventory.gd`.
- Что делает решение № N: `plan/README.md`, таблица «Журнал решений».
- Как выглядело: `survivium-builds/README.md`.

## Как вести документацию

- Документ в `docs/` описывает код в том же PR, что меняет код. Новая система — строка в
  [SYSTEMS.md](SYSTEMS.md) и файл в [systems/](systems/); новый каталог — строка в
  [PROJECT_MAP.md](PROJECT_MAP.md).
- После добавления, переноса или удаления скрипта и смены его первой строки `##`:
  `python3 tools/doc_index.py` (пишет `generated/code-index.md`). CI запускает
  `python3 tools/doc_index.py --check`: индекс свежий, а пути, названные в документах, существуют.
- После правки данных модов: `godot --headless --path . --script res://tools/content_report.gd` (пишет
  `generated/content-index.md`, `content-graph.md`, `content-recipes.md`, `content-checks.md`); CI проверяет
  их свежесть тем же скриптом с `-- --check`.
- Принятое архитектурное решение: строка в журнале `plan/README.md` и, если оно меняет принцип кода,
  в [DECISIONS.md](DECISIONS.md).
- Устаревший документ не удаляется молча: сверху ставится `Статус: DEPRECATED` с причиной и ссылкой на
  замену, история темы уходит в `plan/history/`.
- Техническая спецификация кода (что и как сделать в коде) — `docs/specifications/`; ТЗ и замысел
  пользователя — в библиотеке (`plan/design/`, корень).
- Временные заметки и черновики в репозиторий не кладутся: они в треде или в библиотеке.
- Куда класть новые скрипты, данные, ассеты и скриншоты — [PROJECT_MAP.md](PROJECT_MAP.md); как менять
  связи систем — [ARCHITECTURE.md](ARCHITECTURE.md); проверки после изменений — `CLAUDE.md`.
