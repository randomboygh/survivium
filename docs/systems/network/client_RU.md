# Клиентская сторона сети

Английская версия: [client.md](client.md) (она основная, эта — копия).

Часть раздела [Протокол и сервер](../network_RU.md). Соединение, копия мира, файлы модов, сервер внутри игры, связь с сервером.

- `src/client/net/connection.gd` — сторона клиента: `request(kind, args)` → `Reply` (`done`, `value`,
  `then(cb)` зовёт сразу, если ответ уже есть), `receive(bytes)`, счётчики `sent_bytes`,
  `received_bytes`, `coding_us`, `pending()`. Транспорт — `Callable`, что возвращает байты ответа
  сразу (петля) или `null` (сокет: ответы придут через `receive`).
- `src/client/net/remote_gen.gd` (наследует `world_gen.gd`) — копия генератора через сокет: раскладка
  земли по сиду и настройкам сервера как у него (биомы, карта, где живут звери), но ничего не
  генерирует: `saved` — он сам, запись чанка из `chunk` (`take_chunk`, `packs`) восстанавливается
  работой генератора, как сохранённый чанк (`start` только `TERRAIN` и только для присланных; чанк
  сразу `SHAPED`; `cells` и `drops` для присланного, но ещё не восстановленного чанка ждут в `held`
  (`hold_cell`, `hold_drops`) и ложатся после его записи, которая иначе положила бы поверх старые), `needed` — чанк и соседи на 1 присланы (мешер читает их ячейки по краям; зона
  видимости через сокет — `ZONE` − 1); то, что по петле делает сеанс (`Main.world_maker`):
  `make_chunk` (сразу, экран загрузки), `make_chunks(near_us, far_us)` (ближайшие к `home` первыми в
  бюджете кадра), `forget_far` пусто (забывает сервер: `forget` → `forget` + `ChunkStreamer.unload_chunk`),
  `take_work` («restore»), `gen_us`, `stages_left`; чанк, присланный заново, восстанавливается на месте
  и сигнал `changed` перестраивает его меш (`remesh_chunk`). Ячейки `cells` ставит `Mirror` прямо в
  копию мира и даёт `actions.cell_changed` по разу на столбец, с нижней его клетки (как сервер у себя после рубки); `taken` → `actions.taken`; `drops` со списком → `world.drops`.
  Материалы сервера в другом порядке — `material_map` (`Mat.remap`), как у сохранения.
- `src/client/net/socket.gd` — сокет клиента к серверу по сети: `WebSocketPeer` как транспорт
  `Connection` (`net`; ответы приходят позже, через `Reply.then`), `open(ws://…)`, `hello(name, key,
  password)` — первый запрос (что послано до открытия, ждёт в очереди), `poll()` каждый кадр
  (`opened`, входящие в `net.receive`, `closed(code, reason)` и `ended` / `close_code` /
  `close_reason`: −1 и "" — связь потеряна или сервера нет), `leave()` — `bye` и закрытие. По нему
  играет сама игра (`game.link.join_url`) и входят боты `server_test`.
- `src/client/net/updates.gd` — новая сборка для «Что нового»: сборка из main (не `dev`, не `+pr` из PR) через
  `WAIT` 3 с после показа меню один раз за запуск, тихо при отсутствии сети, просит `latest.json` рядом с веб-сборкой
  (`tools/build_info.py --latest`); новее та сборка, чей PR влит позже, чем у этой (`latest`, сигнал `found`:
  точка в меню). `note_run` хранит эту сборку и сборку прошлого запуска в `user://versions.cfg` (`before`,
  `is_new`); `coming` — изменения, которые приносит новая сборка; `update` перезагружает веб-страницу мимо кэша
  браузера, иначе открывает файл APK, Windows или Linux последнего релиза.
- `src/client/net/mod_fetch.gd` — сторона игры в файлах модов (решение 189): `begin(connection, хеш,
  бандлы)` находит, где каждый файл набора сервера лежит на этом устройстве (`plan`: свой файл игры, если его
  хеш тот же, встроенная копия, сохранённый раньше с сервера), просит список (если набор не сохранён) и
  файлы, которых нет нигде, собирает куски, проверяет каждый файл (хеш, `ModFiles.may_be`) и сохраняет
  (`ModCache`); `finished(ok)` с `table` (путь внутри `content/` → файл, где он лежит) для `Content.serve`.
  Больше `ASK_ABOVE` 50 МБ — ждёт согласия игрока (`state` «ask», `allow`); сервер, молчащий `STALL` 20 с,
  обрывает докачку. `src/client/net/mod_cache.gd` — файлы на устройстве: `user://mod_cache/<хеш>.<расширение>`,
  списки последних `SETS_KEPT` 8 наборов в `sets/`, `used.json` (когда каждый был нужен), `trim` сверх `LIMIT`
  200 МБ (сначала давно не нужные, никогда — файлы набора, с которым играют), `clear` («Настройки» → «Другое» →
  «Очистить данные серверов»).
- `src/client/net/local_host.gd` — сервер внутри игры: единственное место, где клиент грузит
  `src/server/`; `LocalHost.new(session, get_tree().root)` ставит узел сервера `src/server/runner.gd`
  под корень дерева и под ним `real_weather` (`src/server/real_weather.gd` на часах сеанса, включает
  `Settings.apply` по настройке «Погода»; без корня — тесты — узлов нет, сеанс шагает тест), `stop()` снимает его с дерева и
  освобождает (Main зовёт в `_exit_tree`); `join()` делает `PlayerLink` в сеансе и
  даёт `Connection`; `deliver(bytes)` проводит сообщение через линк и возвращает события и ответ;
  `flush(net)` после тика; `player` и `workshop` — серверные объекты, к которым до С4/С5 напрямую ходят
  сохранение и страница «Тестирование». Узел сервера — [session.md](../session_RU.md).
- `src/client/net/mirror.gd` — копии на клиенте: слушает `Connection.event` и раздаёт события
  `game.character` (`take`, `take_vitals`, `say`, `teleport`), `game.workshop` (`take`,
  `take_knowledge`, `made`), `game.props.show_drops`, `game.player.body.knock` / `nudge` (`push`),
  `game.placed` (`take_all`, `take_prop`, `take_gone`, `take_lit`, `take_chest`), `game.clock`
  (`from_snapshot`), `game.wildlife` (`take_born`, `take_gone`, `take_snap`, `take_step`),
  `game.others` (`take_people`, `take_gone`);
  `send_input()` шлёт тело, руки, экран, «на земле» и работу рук (полуразмер низкого вьюпорта в единицах мира плюс
  `SEEN_MARGIN` 4, вдоль `PixelView.right`) каждый кадр и перед каждым запросом
  (`Connection.sending`), только если что-то изменилось (руки копируются: массив из `controls.hands`
  делит с ним данные и не отличался бы).
- `src/client/net/remote_placed.gd` (наследует `placed.gd`) — копия вещей на клетках: те же записи
  `things`, `chest_items`, сигналы `added` / `removed` / `lit_changed`; занимает клетки вещей
  (`world.blockers`, в петле — те же, что сервер) и ничего в мире не меняет (`_forget`, не `_remove`:
  без `note_edit`); сундук копии — `Inventory`, которую `chest` наполняет `from_dict` (окно сумки
  слушает её `changed`). `remote_clock.gd` (наследует `clock.gd`) — копия часов: `from_snapshot` раз в
  0,25 с, между снимками `advance(delta)` сам ведёт время суток (солнце идёт каждый кадр), `step` пуст;
  сезон, погода и её силы — только из снимков. `remote_wildlife.gd` — копия зверей: свой `Animal`
  (номер, вид, место, `lift`, `facing`, `flying`, `perched`, `moving`, `hop`, `left`, `near`, `state`,
  `tint`, `frame`, `fresh`, `aloft()`), те же сигналы `born` / `gone` / `stepped`; `fresh` ставит `snap`,
  `creatures.gd` снимает, когда поставил картинку.
- `src/client/game/creatures.gd`, `props.gd`, `fire_shadows.gd`, `voices.gd`, `sky.gd`, HUD, звуки —
  читают копии как читали правила; сохранение кладётся в сеанс сервера
  `save.restore_world()` (`Session.from_saved`, [saving.md](../saving_RU.md)); страница «Тестирование» (`settings.gd`:
  сезон, погода, час, скорость времени) пишет в `session.clock` — до С5.
- `src/client/game/character.gd` — копия персонажа игрока: не крутит правил (`update` только ставит
  игрока после `go_to_column`), сумку, силы, смерть и дом берёт из `you`/`vitals`, смерть прячет
  игрока (`_fell`) и сбрасывает сохранение; остаётся `who` для того, что клиент читает у правил сам
  (превью курсора, `useful`, `front_choice`). `src/client/net/remote_workshop.gd` — копия мастерской:
  очередь и пауза из `shop`, знания из `knowledge`, сама ничего не узнаёт и не делает.
- Свой сервер из меню на ПК (С5.2): `LocalHost.host(values, root)` делает тот же узел, что сервер из
  терминала (`server_main.gd` с `hosted`: настройки даны, не читаются; `start()` сразу — мир открыт, бандлы
  включены, порт слушается; узел под корнем дерева переживает перезапуски сцены, `PROCESS_MODE_ALWAYS`, без
  ограничения кадров и терминала, `log_lines` для окна, сигнал `stopped`; `failed` — почему не запустился,
  «Порт N занят»), настройки пишет в `user://server.cfg`. `ServerLink.host_server` кладёт настройки в
  `ServerLink.host_ask` и перезапускает сцену; новая сцена в `_ready` до всего (`start_hosting`) делает сервер (`ServerLink.hosted`) и
  входит в него как клиент по `ws://127.0.0.1:порт` с его бандлами (`pending_mods`), меню открывает окно
  сервера; `stop_server` — `stop` (сохраняет мир), по `stopped` узел освобождается и сцена — свой мир.
  Пока сервер работает, закрытие сокета им не считается неудачей входа (`ServerLink.server_stopping`).
- `src/client/net/server_link.gd` (`game.link`, создаётся вместе с узлом Main) — вход на сервер через сокет, отдельно от сцены, которую строит `main.gd`; то, что живёт дольше перезапуска сцены, в нём статическое (`join_url` из статического `ServerLink.join` — его ставит экран
  «Присоединиться» (`join_server`, перезапуск сцены) или `--join <url>` с `--name`, `--password` при первом
  запуске; тест ставит `join_url` сам; `leave_server` очищает `join`, и следующий запуск — свой мир; на web
  `?server=` только открывает «Присоединиться» с адресом, `ServerLink.offered`; с `--bot` игра играет сама —
  `src/client/input/bot.gd`, ниже): `open` из `Main._ready` — сокет,
  `hello` с ключом этого сервера (`src/client/net/server_list.gd`: `user://servers.cfg` — ключи по адресу,
  недавние серверы с названием из приглашения (`title`), имя игрока; `normalize` — адрес, набранный руками:
  без схемы — `ws://` для чисел и `localhost`, иначе `wss://`, `ws://` без порта — `Protocol.PORT`;
  `problem` — `ws://` со страницы по https браузер не пустит), `mirror.watch(net)` сразу (события до постройки мира копит `Mirror._pending`,
  `replay` после); `start_world` → `_join_world` → `wait_welcome`: ждёт приглашение (`JOIN_WAIT` 15 с; отказ — слова на
  экране загрузки: «Сервер не отвечает», «Версия игры другая — обновите страницу», «Неверный пароль»,
  «Сервер полон»), при других бандлах — `pending_mods` и перезапуск сцены (решение 153, 5А); при других
  файлах модов (отказ `mods`, решение 189) — `_take_mods`: свои файлы игры для бандлов сервера, если их хеш
  совпал с серверным, иначе `ModFetch` по этой связи (экран загрузки: «Данные модов: 1.2 из 3.4 МБ»; больше
  50 МБ — игроку называют размер, и он присоединяется ещё раз, чтобы согласиться), потом `server_mods` {url,
  digest, table} и перезапуск сцены: `use_mods` включает таблицу (`Content.serve`) перед `Mods.activate`, пока
  игра на этом сервере, и свои файлы игры после; серверу, сделанному в этой игре, называется его же хеш;
  `ModReload.watch_server` принимает перезагрузки сервера в мире (`mods` → `ModFetch` → `Content.serve` →
  `reload()`; больше 50 МБ — игра выходит с сервера, назвав размер, как при входе, и новый вход соглашается);
  затем `RemoteGen` по сиду и настройкам сервера, карта и материалы как обычно, `actions` — свой
  `WorldActions` над копией мира только для чтения (превью курсора, что даёт куст; сигналы ему даёт
  `Mirror`), тело на `welcome.at`; `host`, `session`, `storms` — null (страница «Тестирование»
  и сохранение их не трогают), `world_maker` — генератор-копия; в кадре `socket.poll()` первым делом,
  `_world_made()` — восстановление присланных чанков в бюджете стримера вместо `runner.take_spent()`;
  `_exit_tree` — `socket.leave()`. Строка «Сервер» показывает адрес.
- `src/client/main.gd` — копии `clock`, `placed`, `wildlife` в `_ready`; серверные часы и вещи
  (`Clock.new()`, `Placed.new()`) в `start_world` только для сеанса (в них пишут сохранение и погода с улицы
  сервера внутри игры), `host` (с узлом сервера), `net`, `mirror` там же, первый `host.flush(net)` в конце
  `start_world` (копии полны до меню); сохранение следит за серверными объектами
  (`save.track(host.player…)`, `session.clock.to_dict()`, `session.placed.to_list()`); в кадре: узел
  сервера сделал тик до Main → `clock.advance` → небо … `host.flush(net)` (события тика) →
  `player.step` → `character.update` → `mirror.send_input()` (тик следующего кадра возьмёт его);
  строка «Сервер» в «Данных для теста» (`settings_menu.gd`) показывает счётчики соединения.

