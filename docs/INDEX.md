# Survivium documentation

Status: ACTIVE. The way into the documentation. It describes **the code as it is**; what the game should
do (game design), the decisions taken, the stages and the backlog live in the Claude project's library,
the `plan/` folder ("the library" below), and are not copied here.

Language: the English file is the main one and a page's Russian copy sits beside it as `<name>_RU.md`
(rules in [TRANSLATION.md](TRANSLATION.md)). A page with no `_RU` copy is not translated yet and is in
Russian only.

## Where to start

1. [`../CLAUDE.md`](../CLAUDE.md): the project in short, the rules, the checks, the order of work.
2. [PROJECT_MAP.md](PROJECT_MAP.md): where things are and where to put new ones.
3. [SYSTEMS.md](SYSTEMS.md): find your system, then open only its file in [systems/](systems/).

The whole documentation is not read at once: a task starts from the context of one system.

## Documents

Statuses: **ACTIVE** — describes the code as it is, work by it; **DONE** — a finished stage plan, its open
tails are marked in the text; **ARCHIVED** — a report or a snapshot of its date: history and the reasons
for decisions, not instructions (the paths and numbers in it are of that day). Generated files are not
edited by hand.

**General**

| Document | Purpose | Status | For whom and when |
|---|---|---|---|
| [`../CLAUDE.md`](../CLAUDE.md) | the project in short, code rules, order of work, checks, pitfalls | ACTIVE | everyone, before any task |
| [`../README.md`](../README.md) | what is in the game, how to play, your own server, how development works | ACTIVE | a player and a new developer |
| [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) | what the game is, what is done and what is not, the engine, limits | ACTIVE | the first time in the project |
| [PROJECT_MAP.md](PROJECT_MAP.md) | the tree of folders, key files, where to put new ones, what not to read | ACTIVE | find a file's place |

**Architecture and decisions**

| Document | Purpose | Status | For whom and when |
|---|---|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | layers, entry points, the modules of `Main`, the session and the server, signals, work by frames, how to extend | ACTIVE | change how systems link, add a system |
| [DEPENDENCIES.md](DEPENDENCIES.md) | the graph of layers and folders, nodes with many dependents, who is handed to whom during play | ACTIVE | what breaks from an edit |
| [DECISIONS.md](DECISIONS.md) | architectural decisions with reasons and the numbers of the `plan/README.md` journal | ACTIVE | before changing a principle |
| [ROADMAP.md](ROADMAP.md) | where the stages and the backlog are; technical debt T1–T11 and its state; stage reports | ACTIVE | plan work |
| [generated/code-index.md](generated/code-index.md) | every script with the first line of its description, which folders load which (`tools/doc_index.py`) | generated | find a file by meaning |

**Game systems**

| Document | Purpose | Status | For whom and when |
|---|---|---|---|
| [SYSTEMS.md](SYSTEMS.md) | the catalog of systems: main files, context, tests; what is not there yet | ACTIVE | any task: find your system |
| [systems/](systems/) | the context of each system (19 files): purpose, files, interfaces, data, pitfalls, tests | ACTIVE | before editing a system — only its file |

**The data model, bundles, recipes and production**

| Document | Purpose | Status | For whom and when |
|---|---|---|---|
| [DATA_MODEL.md](DATA_MODEL.md) | mods, bundles, kinds of records and their number, ids, roles, assets, material numbers, saves | ACTIVE | data, content, mods |
| [systems/content.md](systems/content.md) | the code of the loader and registries, the content graph, how to add a field and a kind | ACTIVE | change the loader, the schema, a registry |
| [specifications/BUNDLE_SYSTEM.md](specifications/BUNDLE_SYSTEM.md) | the game's bundle system (decision 152): concepts, ids and names, kinds, links, recipes, stations, tools, eras, the graph and checks, what is added without code | ACTIVE | change content kinds, recipes, stations, tools |
| [systems/crafting.md](systems/crafting.md) | crafting, the queue, stations by flags, things on cells (doors, windows, stairs, furniture, fireplace) | ACTIVE | recipes and stations in the game |
| [RENAMING.md](RENAMING.md) | where the game's name is written, how to rename the game with one command and what stays the same (saves, address, repository) | ACTIVE | rename the game |
| [TRANSLATION.md](TRANSLATION.md), [TRANSLATION_RU.md](TRANSLATION_RU.md) | translation of the game's text: a new language, translating the game and a mod, what is never translated, and how the docs are translated | ACTIVE | translate, add a language |
| `content/<mod>/README.md` | how a mod is built and how to add your own to it (YAML examples) | ACTIVE | add a record or a bundle |
| [generated/content-index.md](generated/content-index.md) | the registry of entities: mods, bundles and every record with its category, bundle, replacements and patches, era, number of links and the result of the checks | generated (`tools/content_report.gd`) | find a record or a bundle |
| [generated/content-graph.md](generated/content-graph.md) | the content graph: the start, items by depth, where each comes from and goes to, shared resources, what is got with what, stations, chains, the map of eras, the scheme of recipes | generated | what is made of what and with what, in which era |
| [generated/content-recipes.md](generated/content-recipes.md) | the registry of recipes by process: the product and the by-product, what it spends and what it holds, the station, tools and wear, time, depth, era, alternatives | generated | recipe balance, production chains |
| [generated/content-checks.md](generated/content-checks.md) | what the content checks found: each check, what it means and how to fix it, what was found | generated | dead ends, twins, graph errors |

**Balance**

| Document | Purpose | Status | For whom and when |
|---|---|---|---|
| [balance/GAME_BALANCE_DESIGN.md](balance/GAME_BALANCE_DESIGN.md) | the balance model: the tool is the blow, the skill is the hand; values, formulas, progression, display, automatic limits | ACTIVE | change strength, durability, skills, stamina, beasts' health |
| [balance/GAME_BALANCE_TABLES.md](balance/GAME_BALANCE_TABLES.md) | tables from the live data: tools, tree × axe × skill, cell × pickaxe, beast × weapon, PvP, skills, stamina, price and term, food | generated (`tools/balance_report.gd`) | check a number before editing data |
| [balance/GAME_BALANCE_ROADMAP.md](balance/GAME_BALANCE_ROADMAP.md) | what is done and what is left by priority, systems and risks | ACTIVE | plan balance |
| [balance/GAME_BALANCE_AUDIT.md](balance/GAME_BALANCE_AUDIT.md), [balance/GAME_BALANCE_REPORT.md](balance/GAME_BALANCE_REPORT.md) | the audit before the 2026-11-07 pass and the report on it: what was found, what changed, tests, what is left | ARCHIVED | the reasons for today's numbers |

**Testing and CI/CD**

| Document | Purpose | Status | For whom and when |
|---|---|---|---|
| [testing/TESTING_GUIDE.md](testing/TESTING_GUIDE.md) | how to check a change by levels, what to run for which system, how to add a test | ACTIVE | before a push |
| [testing/TEST_COVERAGE.md](testing/TEST_COVERAGE.md) | what is covered by what, what is only by hand, flaky checks and why | ACTIVE | before blaming the code for a red test |
| [testing/CI_PIPELINE.md](testing/CI_PIPELINE.md) | the CI jobs, what blocks, logs, publishing, security, what to do when CI is red | ACTIVE | when CI is red, when editing `build.yml` |
| [systems/testing.md](systems/testing.md) | the tests, the `tools/`, CI and the versions with «What's new» | ACTIVE | tools and versions |

**Security**

| Document | Purpose | Status | For whom and when |
|---|---|---|---|
| [security/THREAT_MODEL.md](security/THREAT_MODEL.md) | assets, who attacks, trust boundaries, entry points, classes of attacks | ACTIVE | change the protocol, the server, the rules the requests call |
| [security/NETWORK_SECURITY.md](security/NETWORK_SECURITY.md) | transport limits, the greeting, what the server checks in every request and in its body | ACTIVE | a new request, a new `input` field |
| [security/COMMAND_PERMISSIONS.md](security/COMMAND_PERMISSIONS.md) | roles, the table of commands and rights, how to add a command | ACTIVE | a new host command |
| [security/ANTI_CHEAT.md](security/ANTI_CHEAT.md) | what is noticed, the levels of reaction, the security log, tolerances | ACTIVE | change the checks, read the log |
| [security/SECURITY_TESTING.md](security/SECURITY_TESTING.md) | the security tests, the spec's scenarios and where they are, how to add one | ACTIVE | check the defence, add a regression |

**Audits, reports and stage plans (history)**

| Document | Purpose | Status | For whom and when |
|---|---|---|---|
| [reports/weekly-audits/INDEX.md](reports/weekly-audits/INDEX.md), [reports/weekly-audits/OPEN_ISSUES.md](reports/weekly-audits/OPEN_ISSUES.md) | the weekly audits (Fridays, since 2026-11-14): a dated report each, their chronology, and the register of the problems still open | ACTIVE (the register); the reports ARCHIVED | what is broken or risky now, before planning a week |
| [audit/SECURITY_AUDIT.md](audit/SECURITY_AUDIT.md), [audit/SECURITY_REMEDIATION_REPORT.md](audit/SECURITY_REMEDIATION_REPORT.md) | stage 7 (2026-11-06): the security audit, 22 findings, fixes, tests, residual risks | ARCHIVED | the history of the server's defence, what is left |
| [audit/DOCUMENTATION_AUDIT.md](audit/DOCUMENTATION_AUDIT.md), [audit/DOCUMENTATION_UPDATE_REPORT.md](audit/DOCUMENTATION_UPDATE_REPORT.md) | stage 6 (2026-11-05): the documentation audit, what was fixed, discrepancies and questions | ACTIVE until the open questions are settled | what is still unchecked |
| [audit/TESTING_CI_AUDIT.md](audit/TESTING_CI_AUDIT.md), [planning/TESTING_CI_ROADMAP.md](planning/TESTING_CI_ROADMAP.md), [audit/TESTING_CI_REPORT.md](audit/TESTING_CI_REPORT.md) | stage 5 (2026-11-03): the audit of tests and CI, the plan (the «Next» section holds the open tasks), the result with measurements | ARCHIVED; the plan is DONE | the history and next steps of tests and CI |
| [audit/CODEBASE_AUDIT.md](audit/CODEBASE_AUDIT.md), [planning/REFACTORING_ROADMAP.md](planning/REFACTORING_ROADMAP.md), [audit/REFACTORING_REPORT.md](audit/REFACTORING_REPORT.md), [audit/PERFORMANCE_REPORT.md](audit/PERFORMANCE_REPORT.md) | stage 4 (2026-11-01): 131 findings by system, the refactoring plan (what waits for the user's decision), what was done, measurements | ARCHIVED; the plan and reports are DONE | the code's technical debt, before fixing a system |
| [audit/AUDIT_REPORT.md](audit/AUDIT_REPORT.md), [audit/CLEANUP_REPORT.md](audit/CLEANUP_REPORT.md) | stage 0 (2026-10-30): the state, the findings, what was cleaned | ARCHIVED | the history of the reorganization |
| [specifications/BUNDLE_SYSTEM_READINESS.md](specifications/BUNDLE_SYSTEM_READINESS.md) | readiness for the bundle system (stage 0) and the answers to its questions | ARCHIVED | the history of decision 152 |


## The project library (`plan/`)

| What | Where |
|---|---|
| The index and the decision journal (no. 1–189) | `plan/README.md` |
| The MVP stages and their state | `plan/mvp.md` |
| The backlog (the only task list, GitHub Issues are not kept) | `plan/backlog.md` |
| Game design by topic | `plan/design/*.md` |
| Implementation details: rendering, performance, mods, the server | `plan/architecture/rendering.md`, `performance.md`, `modding.md`, `server.md` (the server is built, stages С1–С7) |
| Ideas not done yet: the editor, builds and hosting (apart from Pages and PC) | `plan/architecture/editor.md` (PROPOSED), `deployment.md` (PROPOSED); the early idea of the network `networking.md` is DEPRECATED, replaced by `server.md` |
| The history of closed topics (variants, rounds, old measurements, finished plans) | `plan/history/*.md` |
| Screenshots by topic (the index is in its README) | `survivium-builds/` |
| The stages' specs: 0 (audit), the bundle system, 4 (refactoring), 5 (tests and CI), 6 (documentation), 7 (security), balance | `audition.md`, `bundles.md`, `refactoring.md`, `testing_ci.md`, `documentation_audit.md`, `security_audit.md`, `game_balance.md` (ARCHIVED, in the library's `plan/history/tasks/`) |
| The bundle system's plan: analysis of the spec, the data audit, stages with files and risks | `plan/architecture/bundle-system.md` |

The statuses of the library's documents (ACTIVE, DRAFT, PROPOSED, DEPRECATED, ARCHIVED) stand in a
`Статус:` line under the title of each document and in the index `plan/README.md`. A document with the
status PROPOSED or DRAFT describes an intent, not the code: check what is done against `docs/` and the code.

What went out of date and where it was moved (2026-10-30): `plan/architecture/code-structure.md`
(DEPRECATED) — [ARCHITECTURE.md](ARCHITECTURE.md) and [PROJECT_MAP.md](PROJECT_MAP.md), its text and the
former «Modules» section of `plan/architecture/overview.md` — `plan/history/code-structure.md`; the old
measurements from `performance.md` — `plan/history/performance.md`; the finished plan of the split into
mods from `modding.md` — `plan/history/modding.md`; the done backlog items — `plan/history/backlog-done.md`.

## How to search without reading everything

- A file by meaning: [generated/code-index.md](generated/code-index.md), then `git grep`.
- Who uses a file: `python3 tools/doc_index.py uses src/shared/game/inventory.gd`.
- What decision no. N does: `plan/README.md`, the «Decision journal» table.
- How it looked: `survivium-builds/README.md`.

## How to keep the documentation

- A document in `docs/` describes the code in the same PR that changes the code. A new system is a row in
  [SYSTEMS.md](SYSTEMS.md) and a file in [systems/](systems/); a new folder is a row in
  [PROJECT_MAP.md](PROJECT_MAP.md).
- After adding, moving or deleting a script and changing its first `##` line:
  `python3 tools/doc_index.py` (writes `generated/code-index.md`). CI runs
  `python3 tools/doc_index.py --check`: the index is fresh, and the paths the documents name exist.
- After editing the mods' data: `godot --headless --path . --script res://tools/content_report.gd` (writes
  `generated/content-index.md`, `content-graph.md`, `content-recipes.md`, `content-checks.md`); CI checks
  that they are fresh with the same script with `-- --check`.
- An architectural decision taken: a row in the `plan/README.md` journal and, if it changes a principle of
  the code, in [DECISIONS.md](DECISIONS.md).
- An outdated document is not deleted silently: `Статус: DEPRECATED` goes on top with the reason and a link
  to the replacement, the topic's history goes to `plan/history/`.
- A technical specification of the code (what to do and how in the code) is in `docs/specifications/`; the
  user's spec and idea are in the library (`plan/design/`, the root).
- Temporary notes and drafts are not put in the repository: they are in a thread or the library.
- Where to put new scripts, data, assets and screenshots — [PROJECT_MAP.md](PROJECT_MAP.md); how to change
  the links of systems — [ARCHITECTURE.md](ARCHITECTURE.md); the checks after changes — `CLAUDE.md`.
