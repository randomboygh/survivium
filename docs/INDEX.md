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

| Документ | О чём | Когда открывать |
|---|---|---|
| [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) | что за игра, состояние, движок, ограничения | впервые в проекте |
| [PROJECT_MAP.md](PROJECT_MAP.md) | дерево каталогов, ключевые файлы, куда класть новое, что не читать | найти место файла |
| [ARCHITECTURE.md](ARCHITECTURE.md) | слои, точки входа, модули `Main`, сигналы, работа по кадрам, правила зависимостей | менять связи систем, добавлять систему |
| [SYSTEMS.md](SYSTEMS.md) | каталог систем: файлы, контекст, тесты; чего ещё нет | любая задача |
| [systems/](systems/) | контекст системы: назначение, файлы, интерфейсы, данные, подводные камни, тесты | перед правкой системы |
| [DATA_MODEL.md](DATA_MODEL.md) | моды, бандлы, схемы, id, роли, реестры, сохранения | данные, контент, моды |
| [DEPENDENCIES.md](DEPENDENCIES.md) | граф слоёв и папок, узлы с многими зависимыми | что сломается от правки |
| [DECISIONS.md](DECISIONS.md) | архитектурные решения с причинами и номерами журнала | прежде чем менять принцип |
| [ROADMAP.md](ROADMAP.md) | где этапы и бэклог; технический долг из аудита | планировать работу |
| [generated/code-index.md](generated/code-index.md) | каждый скрипт с первой строкой его описания (генератор) | найти файл по смыслу |
| [generated/content-index.md](generated/content-index.md) | реестр сущностей: моды, бандлы и каждая запись с категорией, бандлом, заменами и патчами, числом связей и итогом проверки (`tools/content_report.gd`) | найти запись или бандл |
| [audit/AUDIT_REPORT.md](audit/AUDIT_REPORT.md), [audit/CLEANUP_REPORT.md](audit/CLEANUP_REPORT.md) | аудит этапа 0: состояние, находки, что почищено | история реорганизации |
| [specifications/BUNDLE_SYSTEM.md](specifications/BUNDLE_SYSTEM.md) | система игровых бандлов по ТЗ: понятия, связи, рецепты, станки, граф, эпохи, этапы и их состояние | менять виды контента, рецепты, станки, инструменты |
| [specifications/BUNDLE_SYSTEM_READINESS.md](specifications/BUNDLE_SYSTEM_READINESS.md) | готовность к работе над бандлами (этап 0) и ответы на её вопросы | история решения 152 |

Рядом с кодом: `README.md` в корне (по-русски: что есть в игре, как запустить) и README каждого мода
(`content/<мод>/README.md`: как устроен мод и как добавить в него своё).

## Библиотека проекта (`plan/`)

| Что | Где |
|---|---|
| Оглавление и журнал решений (№ 1–151 и дальше) | `plan/README.md` |
| Этапы MVP и их состояние | `plan/mvp.md` |
| Бэклог (единственный список задач, GitHub Issues не ведутся) | `plan/backlog.md` |
| Геймдизайн по темам | `plan/design/*.md` |
| Подробности реализации: рендер, производительность, моды | `plan/architecture/rendering.md`, `performance.md`, `modding.md` |
| Замыслы, ещё не сделанные: сервер, сеть, редактор, территории | `plan/architecture/networking.md`, `editor.md`, `deployment.md`, `plan/design/territory-pvp.md` |
| История закрытых тем (варианты, раунды, старые замеры, выполненные планы) | `plan/history/*.md` |
| Скриншоты по темам (оглавление в README) | `survivium-builds/` |
| ТЗ этапа 0 и системы бандлов | `audition.md`, `bundles.md` (корень библиотеки) |
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
  `generated/content-index.md`); CI проверяет его свежесть тем же скриптом с `-- --check`.
- Принятое архитектурное решение: строка в журнале `plan/README.md` и, если оно меняет принцип кода,
  в [DECISIONS.md](DECISIONS.md).
- Устаревший документ не удаляется молча: сверху ставится `Статус: DEPRECATED` с причиной и ссылкой на
  замену, история темы уходит в `plan/history/`.
- Техническая спецификация кода (что и как сделать в коде) — `docs/specifications/`; ТЗ и замысел
  пользователя — в библиотеке (`plan/design/`, корень).
- Временные заметки и черновики в репозиторий не кладутся: они в треде или в библиотеке.
- Куда класть новые скрипты, данные, ассеты и скриншоты — [PROJECT_MAP.md](PROJECT_MAP.md); как менять
  связи систем — [ARCHITECTURE.md](ARCHITECTURE.md); проверки после изменений — `CLAUDE.md`.
