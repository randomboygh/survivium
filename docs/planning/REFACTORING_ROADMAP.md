# План рефакторинга (этап 4)

Статус: DONE (шаги 1–6 сделаны 2026-11-01, PR #289–#293; итоги — в отчёте). Находки и их номера — [../audit/CODEBASE_AUDIT.md](../audit/CODEBASE_AUDIT.md); что
сделано и чем проверено — [../audit/REFACTORING_REPORT.md](../audit/REFACTORING_REPORT.md). Пользователь
поручил выполнить план целиком без остановки после него (тред «Провести рефакторинг по refactoring.md»,
2026-11-01); пункты, меняющие структуру, игру или протокол, не делаются, а вынесены в раздел 3.

## 1. Приоритеты

| Приоритет | Находки |
|---|---|
| Critical | нет находок этого уровня в обычной игре; ближе всего — world-4 и world-m2 (сбой записи затирает целое сохранение), client-core-1 (мир сервера из меню не сохраняется при закрытии окна) — сделаны первыми среди исправлений |
| High | ошибки: game-1, net-1, net-2, net-3 (живой игрок), client-world-1, client-world-2, client-view-1, ui-rest-1, tests-tools-1; производительность: world-1, client-view-2, client-view-3, ui-big-1 |
| Medium | world-3, world-5, world-6, net-5, client-core-2, client-core-3, client-core-4, client-world-3, client-world-4, client-world-5, client-view-4, client-view-5, client-view-6, client-view-m1, ui-big-2, ui-rest-2…7, content-1, content-2, tests-tools-2, tests-tools-4…7 |
| Low | остальное: мёртвый код, комментарии, мелкие дубли и мелкие траты |

## 2. Порядок работ: шаги и PR

Каждый шаг — отдельный PR с проверками из `CLAUDE.md`; три категории ТЗ (ошибки, архитектура,
производительность) не смешиваются.

| Шаг | Этап ТЗ | Что | Находки |
|---|---|---|---|
| 1 | A, B | этот план и аудит | — |
| 2 | C | безопасная очистка: мёртвый код, оторванные комментарии, мелкие дубли | content-5, content-15, world-9, world-12, world-13, game-4, game-7, game-12, net-11, net-12, net-16, client-core-6, client-core-7, client-core-11, client-core-12, client-world-9, client-world-10, client-world-11, client-view-10, client-view-11, ui-big-5, ui-big-11, ui-rest-6, ui-rest-13, ui-rest-m1, tests-tools-11, tests-tools-m1 |
| 3 | C/F | исправление ошибок без смены игры и протокола | world-4, world-m2, world-5, world-8, content-3, content-6, content-12, content-13, net-1, net-2, net-3 (только живой), net-5, net-13, net-15, client-core-1, client-core-2, client-core-3, client-core-9, client-core-10, client-world-1, client-world-2, client-world-3, client-world-8, client-view-1, game-6, ui-big-4, ui-rest-1, ui-rest-4, ui-rest-5, ui-rest-11, tests-tools-1, tests-tools-2, tests-tools-7 |
| 4 | D | архитектура: правило весны в сеансе, общая сборка мира в `main.gd`, списки модов из скана, поколение загрузки контента, общие кнопки и окна UI, одна точка чтения `build_info.json`, тесты: автопоиск юнит-тестов, раскладка INPUT из протокола, старые сохранения | game-1, game-m1, client-core-4, content-1, content-m1, content-8, content-11, content-14, ui-big-7, ui-big-9, ui-rest-7, ui-rest-8, net-17, tests-tools-4, tests-tools-5, tests-tools-6, tests-tools-10, tests-tools-12 |
| 5 | E | производительность: замер до, правка, замер после | world-1, world-3, world-6, world-10, world-11, world-m1, content-2, content-9, content-10, game-3, game-9, client-world-5, client-world-6, client-world-7, client-view-2…8, client-view-m1, ui-big-1, ui-big-2, ui-big-12, ui-rest-2, ui-rest-3, ui-rest-9, ui-rest-12, net-9, net-10, net-m1, net-m2 |
| 6 | F, G | полный прогон, отчёты, обновление документов систем | — |

## 3. Не делается без решения пользователя

| Находка | Почему не сама | Последствия, если оставить | Предложение |
|---|---|---|---|
| content-4 | смена структуры слоёв (правило проекта) | правило рубки дерева живёт в слое контента; серверу не мешает | сделано (выбор пользователя «Перенести сейчас»): `src/shared/world/growth.gd`, `src/shared/game/felling.gd`; реестры остались |
| content-7 | смысл данных модов | два патча `bag+` одного предмета дают последнее число, а не сумму; сейчас такого в данных нет | решить: `+` у количеств прибавляет |
| game-2 | темп игры на медленных телефонах | при < 20 FPS время сеанса идёт медленнее реального | сделано: кадр до `Session.CATCH_UP` (1 с) засчитывается целиком, тело идёт шагами по 0,05 с |
| net-3 (место), net-4, net-14 | этап С6 плана сервера: проверки предметов | клиент с подделкой может воскреснуть в любой точке и пользоваться не своими вещами | сделать на этапе С6 |
| net-6, net-7, net-8, net-m1 | меняет протокол рассылки | лишний трафик при нескольких игроках далеко друг от друга | рассылать по зоне игрока на этапе С6 |
| world-2 | под сомнением, нужен замер на сервере | редкая большая перестройка форм | проверить замером при нескольких игроках |
| world-7 | поиск спавна по заданиям меняет поток запуска | на океанском зерне долгий синхронный поиск | вынести в задания генератора вместе с тредом холодного старта |
| ui-big-3 | перекладка HUD связана с подгонкой окон; риск сдвигов | лишняя работа при смене настройки | разделить `_place` по частям после тестов интерфейса |
| tests-tools-3 | меняет состав CI | `frame_test` проверяет и интерфейс | вынести проверки интерфейса в свой тест |
| tests-tools-13, 14, 15 | CI и проверка в браузере, без пользы для кода | лишние минуты CI | при следующей правке CI |
| game-5, game-8, ui-big-8, client-world-4 | меняют то, что видит игрок (сезонность косьбы, ягоды при косьбе, подтверждения, раздачу точек кроны) | мелкие расхождения | по одному, с картинками до и после |
| ui-big-6, ui-rest-10, tests-tools-9, client-core-8 | дешёвые, но без измеримой пользы сейчас | — | при следующей правке этих файлов |
| game-10, client-view-9, ui-big-10, world-2 | под сомнением | — | не трогать |
| content-2, content-10, client-world-7, world-10, world-11, client-view-5, client-view-7, client-view-8, ui-big-12, ui-rest-3, ui-rest-12, net-9, net-m1, net-m2, world-m1 | шаг 5: малый выигрыш или риск сдвинуть мир (content-2: граница биома при float32) | мелкие траты | при следующей правке этих файлов, с замером |

## 4. Как проверяется каждый шаг

`--import`, `validate.gd`, `content_report.gd --check`, `run_tests.gd`, `save_test.gd`, `progress_test.gd`
(после правок правил), `server_test.gd`, `frame_test.gd` (отдельно, шумит — Т11), `doc_index.py --check`,
CI на PR (с web-экспортом и проверкой в браузере, если менялись шейдеры или клиент). Для шага 5 —
`tools/bench_*.gd` до и после, цифры в [../audit/PERFORMANCE_REPORT.md](../audit/PERFORMANCE_REPORT.md).
