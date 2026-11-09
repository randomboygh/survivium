extends RefCounted
## The server over the network (plan/architecture/server.md, С3): listens on a port,
## takes WebSocket connections, lets players in by name and key (Protocol.HELLO), hands
## each player's messages to their link (PlayerLink) and sends the links' events after
## each tick (flush). A player whose connection is lost keeps their character in the
## world LINGER seconds, so a page reloaded comes back to it with the key the welcome
## gave, and so a fight is not left by leaving the game; one who leaves standing in
## their own or their team's land (Territory.at_home) is gone at once (linger_of). The host's commands (command): who,
## say, kick, stop, give, tp, ban, whitelist, op. A line of chat (Protocol.CHAT, С6) is
## heard by the players within CHAT_RANGE of who said it (HEARD), a line to the team
## (TEAM_CHAT) by its members wherever they are; one that begins with
## "/" is a command, done for the server's hosts (`access.hosts`: the keys `op` gave,
## and the player who made the server in the game) and answered to them alone. Each message is one binary frame; the reply to HELLO goes before
## the events of joining (the client knows who it is before its copies fill), and the
## events of any other request before its reply, as over the loop. With a `store`
## (ServerStore, С4) a character that leaves the world is saved and a player who comes
## back with their key, after a restart too, gets it again; stop saves everything.

const Protocol := preload("res://src/shared/net/protocol.gd")
const PlayerLink := preload("res://src/server/player_link.gd")
const ServerStore := preload("res://src/server/server_store.gd")
const Config := preload("res://src/server/config.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Items := preload("res://src/shared/content/items.gd")
const Mods := preload("res://src/shared/content/mods.gd")

## Seconds a character stays in the world after its connection is lost or a goodbye,
## out of their land (see linger_of).
const LINGER := 30.0
## How far a line of chat is heard, in world units (sixty cells: about a screen and a half).
const CHAT_RANGE := 30.0
## Seconds a connection has to say hello.
const HELLO_WAIT := 10.0
## Seconds between the animals' snapshots over a socket (PlayerLink.snap_every).
const SNAP_EVERY := 0.1
## Seconds between the other players' snapshots to a player (PlayerLink.people_every).
const PEOPLE_EVERY := 0.05
## Bytes a frame may hold going out (the chunks of С3.2 are large), and coming in (a
## client sends only small messages: a bigger one is not taken).
const BUFFER := 4 << 20
const INBOUND := 256 << 10
## Connections that have not said hello yet, at most, and from one address at most (all
## of a tunnel's come from this machine: only the first counts for them).
const PENDING_MAX := 16
const PENDING_PER_ADDRESS := 4
## Messages a connection may send a second, and in a burst: more are not read, and one
## that keeps sending past it (FLOOD_KICK seconds' worth refused) is put out.
const MSG_RATE := 300.0
const MSG_BURST := 600.0
const FLOOD_KICK := 3.0
## Wrong passwords from one address in PASSWORD_WINDOW seconds before a new player from
## it waits that long (one with a key the server knows comes in all the same); new
## players (no key the server knows) in NEW_WINDOW seconds at most.
const PASSWORD_TRIES := 8
const PASSWORD_WINDOW := 60.0
const NEW_PLAYERS := 10
const NEW_WINDOW := 60.0
## Names only the server goes by (lower case): a player may not take them.
const RESERVED_NAMES := ["сервер", "server", "admin", "админ", "система", "system"]
## What may give a command (command): a host (`op`), an owner (the player who made the
## server in the game) and the terminal or the host's window, each able to do all the
## one before can; and the commands each needs (COMMANDS, the one place they are named).
enum { ROLE_PLAYER, ROLE_HOST, ROLE_OWNER, ROLE_CONSOLE }
const COMMANDS := {"who": ROLE_HOST, "say": ROLE_HOST, "kick": ROLE_HOST, "give": ROLE_HOST,
	"tp": ROLE_HOST, "ban": ROLE_HOST, "unban": ROLE_HOST, "bans": ROLE_HOST, "whitelist": ROLE_HOST,
	"hosts": ROLE_HOST, "help": ROLE_HOST, "?": ROLE_HOST, "security": ROLE_HOST, "reload": ROLE_HOST,
	"op": ROLE_OWNER, "deop": ROLE_OWNER, "stop": ROLE_OWNER}
## Lines the security log keeps (security), and seconds between two lines of one kind
## about one player (the others are counted into the next).
const SECURITY_KEPT := 500
const SECURITY_EVERY := 10.0
## Letters a name may have.
const NAME_MAX := 24
## The codes a connection is closed with: 1000 the client's own goodbye, 1001 the
## server stopping, 4000 refused at hello (or no hello), 4001 kicked by the host, 4002
## the same player came in again elsewhere.
const CLOSE_STOP := 1001
const CLOSE_REFUSED := 4000
const CLOSE_KICKED := 4001
const CLOSE_ELSEWHERE := 4002
## 4003: put out for sending far more than a client does.
const CLOSE_FLOOD := 4003

## Polls a close waits after the last message sent, so the message goes first: a close
## frame goes before the data queued (wslay sends control frames first).
const CLOSE_AFTER := 2


## A connection: a socket, and the player on it once welcomed.
class Peer extends RefCounted:
	var ws: WebSocketPeer
	var since: float
	var address := ""
	var account: Account
	## A close asked for (see close_after), in this many polls.
	var close_code := 0
	var close_reason := ""
	var close_in := 0
	## Messages it may still send now (MSG_RATE), when that was counted, and how many
	## past it were not read lately.
	var tokens := MSG_BURST
	var tokens_at := -1.0
	var refused := 0.0

	## Closes the socket after what was sent went out.
	func close_after(code: int, reason: String) -> void:
		if close_code == 0:
			close_code = code
			close_reason = reason
			close_in = CLOSE_AFTER


## A player known to the server: their key, their character (the link) and the
## connection they are on, if any.
class Account extends RefCounted:
	var id := 0
	var name := ""
	var key := ""
	var link: PlayerLink
	var peer: Peer
	## When the connection was lost, and how long the character waits.
	var left_at := -1.0
	var linger := LINGER


var session
var config: Config
## The save (ServerStore), null for a world not saved.
var store
## What the welcome tells of the world: seed, settings, mods, materials, spawn.
var world_info := {}
var tcp := TCPServer.new()
var peers: Array[Peer] = []
## The accounts by key.
var accounts := {}
var next_id := 1
var listening := false
## The animals were let into the world (with the first player: they come around people).
var wild := false
## Stop was asked: the connections are being closed (done tells when they are).
var stopping := false
## Lines for the terminal (the server's scene prints them).
var lines: Array[String] = []
## Who may come in, kept in the world's save (ServerStore.ACCESS): the keys blocked
## (with the name each had), the names blocked (lower case), whether only the names on
## the list are let in, the list (lower case), and the keys of the hosts (who may give
## commands in the chat) with the name each had.
## The owners (keys → names) may also op and deop and stop the server (COMMANDS); the
## names on the list come in with the key they first came with (`listed_keys`, name →
## key), so nobody else gets in by typing a name on it.
var access := {"banned_keys": {}, "banned_names": [], "listed_only": false, "listed": [], "hosts": {},
	"owners": {}, "listed_keys": {}}
## What looked wrong, newest last ({"at", "id", "name", "what", "detail", "level"}), and
## when each kind about each player was last written (SECURITY_EVERY) with how many since.
var security_log: Array = []
var _flag_at := {}
## Wrong passwords by address: the times of the last ones; the times new players came.
var _wrong := {}
var _new_at: Array[float] = []


func _init(s, cfg: Config, info: Dictionary) -> void:
	session = s
	config = cfg
	world_info = info


## Listens on the config's port; the error if the port is taken.
func listen() -> Error:
	var err := tcp.listen(config.port, config.bind)
	listening = err == OK
	return err


## Takes what came over the connections: new ones, hellos, requests and inputs; drops
## the connections closed and the characters that waited long enough.
func poll() -> void:
	var now := _now()
	while tcp.is_connection_available():
		var peer := Peer.new()
		var stream := tcp.take_connection()
		peer.address = stream.get_connected_host()
		if _pending() >= PENDING_MAX or _pending(peer.address) >= PENDING_PER_ADDRESS:
			stream.disconnect_from_host()
			flag(null, "connections", "слишком много входов без приветствия с " + peer.address, 1)
			continue
		peer.ws = WebSocketPeer.new()
		peer.ws.inbound_buffer_size = INBOUND
		peer.ws.outbound_buffer_size = BUFFER
		peer.ws.max_queued_packets = 1024
		peer.since = now
		if peer.ws.accept_stream(stream) == OK:
			peers.append(peer)
	for peer in peers.duplicate():
		var ws: WebSocketPeer = peer.ws
		ws.poll()
		var state := ws.get_ready_state()
		# What came before a close (a goodbye) is read still.
		while ws.get_available_packet_count() > 0:
			var bytes := ws.get_packet()
			if _within_rate(peer, now):
				_take(peer, bytes)
		if peer.close_code != 0 and state == WebSocketPeer.STATE_OPEN:
			peer.close_in -= 1
			if peer.close_in <= 0:
				ws.close(peer.close_code, peer.close_reason)
		match state:
			WebSocketPeer.STATE_OPEN:
				# One that never said hello; a connection closing (kicked, refused,
				# elsewhere) has no account either, and goes its own way.
				if peer.account == null and peer.close_code == 0 and now - peer.since > HELLO_WAIT:
					ws.close(CLOSE_REFUSED, "hello first")
			WebSocketPeer.STATE_CONNECTING:
				if now - peer.since > HELLO_WAIT:
					ws.close(CLOSE_REFUSED, "hello first")
			WebSocketPeer.STATE_CLOSED:
				_dropped(peer)
	for key in accounts.keys():
		var a: Account = accounts[key]
		if a.peer == null and now - a.left_at >= a.linger:
			_forget(a)


## Sends each player the events of the tick.
func flush() -> void:
	for key in accounts:
		var a: Account = accounts[key]
		if a.peer != null and a.peer.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			for b in a.link.flush():
				a.peer.ws.put_packet(b)
		elif a.peer == null:
			# Lingering without a connection: nothing piles up (rejoin sends it all).
			a.link.outbox.clear()


## The players in the world: their accounts, by id.
func players() -> Array:
	var out: Array = accounts.values()
	out.sort_custom(func(a: Account, b: Account) -> bool: return a.id < b.id)
	return out


## Players connected now.
func online() -> int:
	var n := 0
	for key in accounts:
		if accounts[key].peer != null:
			n += 1
	return n


## Does the host's command `line` (who, say, kick, stop, help) for one of `role` (the
## terminal's by default; a player's by role_of, looked at anew each time); the words to
## print. A command the role may not give is refused as an unknown one is not done.
func command(line: String, role := ROLE_CONSOLE) -> String:
	# "/give …" as in a chat, or "give …".
	var parts := line.strip_edges().trim_prefix("/").split(" ", false, 1)
	if parts.is_empty():
		return ""
	var rest := parts[1].strip_edges() if parts.size() > 1 else ""
	if not COMMANDS.has(parts[0]):
		return "неизвестная команда «%s»; help — список" % parts[0].left(32)
	if role < COMMANDS[parts[0]]:
		return "«%s» — только для владельца сервера" % parts[0]
	match parts[0]:
		"who":
			var out: Array[String] = ["Игроков на связи: %d из %d" % [online(), config.max_players]]
			for a: Account in players():
				var at: Vector3 = a.link.who.position / WorldData.CELL
				out.append("  %s (%d)%s: %d, %d, %d" % [a.name, a.id, "" if a.peer != null else ", без связи",
					floori(at.x), floori(at.y), floori(at.z)])
			return "\n".join(out)
		"say":
			if rest == "":
				return "say <слова для всех>"
			for key in accounts:
				accounts[key].link.hear(0, "Сервер", rest)
			return "сказано: " + rest
		"kick":
			var a := _find(rest)
			if a == null:
				return "нет такого игрока: " + rest
			kick(a, "хозяин отключил вас")
			return "отключён: " + a.name
		"stop":
			stop()
			return "сервер останавливается"
		"give":
			return _give(rest)
		"tp":
			return _tp(rest)
		"ban":
			return _ban(rest)
		"unban":
			return _unban(rest)
		"bans":
			return "заблокированы: " + (", ".join(_banned()) if not _banned().is_empty() else "никто")
		"whitelist":
			return _whitelist(rest)
		"op":
			var a := _find(rest)
			if a == null:
				return "op <кто> — дать команды в чате; нет такого игрока: " + rest
			access.hosts[a.key] = a.name
			_save_access()
			flag(a, "role", "дан хозяин (op)", 1)
			a.link.hear(0, "", "Вы хозяин сервера: команды в чате через «/», /help — список")
			return "хозяин: " + a.name
		"deop":
			var low := rest.to_lower()
			for key in access.hosts.keys():
				if str(access.hosts[key]).to_lower() == low or str(key) == rest:
					access.hosts.erase(key)
					_save_access()
					flag(accounts.get(key), "role", "снят хозяин (deop): " + rest, 1)
					return "больше не хозяин: " + rest
			return "не хозяин: " + rest
		"hosts":
			var names: Array = access.owners.values().map(func(n) -> String: return "%s (владелец)" % n) + access.hosts.values()
			return "хозяева: " + (", ".join(names) if not names.is_empty() else "только терминал")
		"security":
			var shown: Array = security_log.slice(-20)
			if rest != "":
				shown = security_log.filter(func(e: Dictionary) -> bool: return e.what == rest or e.name == rest).slice(-20)
			var out: Array[String] = ["журнал безопасности: %d записей" % security_log.size()]
			for e: Dictionary in shown:
				out.append("  %s" % _security_line(e))
			return "\n".join(out)
		"reload":
			return reload_mods()
		"help", "?":
			return "\n".join(["who — кто в мире; say <слова> — сказать всем; kick <кто> — отключить; stop — остановить сервер",
				"give <кто> <предмет> [сколько] — дать; tp <кто> <x> <y> <z> | <к кому> — перенести (клетки)",
				"ban <кто или имя>, unban <имя>, bans — блокировка; whitelist on|off|add <имя>|remove <имя> — пускать только своих",
				"op <кто>, deop <имя>, hosts — кто может давать команды в чате через «/» (op, deop, stop — владелец)",
				"security [вид или имя] — что выглядело подозрительно",
				"reload — перечитать данные модов с диска (горячая перезагрузка: числа, звери, рецепты; клетки мира прежние)",
				"<кто> — имя или номер игрока (who)"])
	return ""


## Reads the mods' data under content/ again (the command `reload`, a hot reload): the
## rules play with it at once (Session.reread); the materials of the cells stay those the
## world was made with (Mods.cells_kept). The players are told; their own games read
## their own files (a game on the same computer by itself, ModReload). The words to print.
func reload_mods() -> String:
	var problems := Mods.rescan(true)
	if session != null:
		session.reread()
	for key in accounts:
		accounts[key].link.hear(0, "", "Сервер перечитал данные модов")
	var out: Array[String] = ["данные модов перечитаны" if problems.is_empty() else "данные модов перечитаны, ошибок: %d" % problems.size()]
	for p in problems.slice(0, 10):
		out.append("  " + p)
	if Mods.cells_kept:
		out.append("материалы клеток изменились: мир играет прежними, новые — в новом мире")
	return "\n".join(out)


## Loads who may come in from the world's save (the server's scene, at start).
func load_access() -> void:
	if store == null:
		return
	var d: Dictionary = store.read_access()
	for k in ["banned_keys", "hosts", "owners", "listed_keys"]:
		if d.get(k) is Dictionary:
			access[k] = d[k]
	for k in ["banned_names", "listed"]:
		if d.get(k) is Array:
			access[k] = d[k]
	access.listed_only = d.get("listed_only") == true


## The player of `key` owns the server: they made it in the game (Main._on_welcome).
func make_host(key: String) -> void:
	var a: Account = accounts.get(key)
	access.owners[key] = a.name if a != null else str(access.owners.get(key, ""))
	_save_access()


func is_host(key: String) -> bool:
	return role_of(key) >= ROLE_HOST


## What the player of `key` may command (COMMANDS), by the server's lists, never by
## anything the client says.
func role_of(key: String) -> int:
	if access.owners.has(key):
		return ROLE_OWNER
	if access.hosts.has(key):
		return ROLE_HOST
	return ROLE_PLAYER


## Player `key` said `text`: a command for a host (answered to them), else a line heard
## by everyone within CHAT_RANGE, the speaker too.
func _on_chat(text: String, key: String) -> void:
	var a: Account = accounts.get(key)
	if a == null:
		return
	if text.begins_with("/"):
		if not is_host(key):
			flag(a, "command", "команда без прав: " + text.left(40), 1)
			a.link.hear(0, "", "Команды через «/» — только для хозяина сервера")
			return
		_say("%s (%d): %s" % [a.name, a.id, text])
		for line in command(text, role_of(key)).split("\n"):
			a.link.hear(0, "", line)
		return
	_say("%s (%d): %s" % [a.name, a.id, text])
	var at: Vector3 = a.link.who.position
	for k in accounts:
		var b: Account = accounts[k]
		if b.link.who.position.distance_to(at) <= CHAT_RANGE:
			b.link.hear(a.id, a.name, text)


## Player `key` said `text` to their team: heard by its members in the world, wherever
## they are.
func _on_team_chat(text: String, key: String) -> void:
	var a: Account = accounts.get(key)
	if a == null:
		return
	_say("%s (%d) команде: %s" % [a.name, a.id, text])
	for k in accounts:
		var b: Account = accounts[k]
		if session.teams.together(a.id, b.id):
			b.link.hear(a.id, a.name, text, true)


func _save_access() -> void:
	if store != null:
		store.write_access(access)


## "give <кто> <предмет> [сколько]": into the player's bag (an item by its id, the
## end of its id or its name).
func _give(rest: String) -> String:
	var args := rest.split(" ", false)
	if args.size() < 2:
		return "give <кто> <предмет> [сколько]"
	var a := _find(args[0])
	if a == null:
		return "нет такого игрока: " + args[0]
	var n := clampi(int(args[2]), 1, 999) if args.size() > 2 and args[2].is_valid_int() else 1
	var id := _item(args[1])
	if id == "":
		return "нет такого предмета: " + args[1]
	var got: int = a.link.who.give(id, n)
	flag(a, "give", "выдано командой: %d × %s" % [got, id], 0)
	return "выдано %s: %d × %s" % [a.name, got, Items.title(id)]


## The item meant by `what`: its id, the part after the colon, or its name.
static func _item(what: String) -> String:
	var id := Items.canon(what)
	if Items.has(id):
		return id
	for i: String in Items.IDS:
		if i.get_slice(":", 1) == what or Items.title(i).to_lower() == what.to_lower().replace("_", " "):
			return i
	return ""


## "tp <кто> <x> <y> <z>" (cells) or "tp <кто> <к кому>".
func _tp(rest: String) -> String:
	var args := rest.split(" ", false)
	if args.size() != 2 and args.size() != 4:
		return "tp <кто> <x> <y> <z> | tp <кто> <к кому>"
	var a := _find(args[0])
	if a == null:
		return "нет такого игрока: " + args[0]
	var to: Vector3
	if args.size() == 2:
		var b := _find(args[1])
		if b == null:
			return "нет такого игрока: " + args[1]
		to = b.link.who.position
	else:
		for k in range(1, 4):
			if not args[k].is_valid_int():
				return "клетки — целые числа: " + rest
		to = (Vector3(int(args[1]), int(args[2]), int(args[3])) + Vector3(0.5, 0.0, 0.5)) * WorldData.CELL
	a.link.who.teleport(to)
	var c := (to / WorldData.CELL).floor()
	return "%s перенесён на %d, %d, %d" % [a.name, c.x, c.y, c.z]


## "ban <кто или имя>": a player here is put out and their key blocked; a name not
## here is blocked by the name.
func _ban(rest: String) -> String:
	if rest == "":
		return "ban <кто или имя>"
	var a := _find(rest)
	var name := a.name if a != null else rest
	if not access.banned_names.has(name.to_lower()):
		access.banned_names.append(name.to_lower())
	if a != null:
		access.banned_keys[a.key] = a.name
		kick(a, "хозяин заблокировал вас")
	_save_access()
	_say("%s заблокирован" % name)
	return "заблокирован: " + name


## "unban <имя>": the name and the keys that came with it.
func _unban(rest: String) -> String:
	var low := rest.to_lower()
	var was: bool = access.banned_names.has(low)
	access.banned_names.erase(low)
	for key in access.banned_keys.keys():
		if str(access.banned_keys[key]).to_lower() == low:
			access.banned_keys.erase(key)
			was = true
	if not was:
		return "не заблокирован: " + rest
	_save_access()
	return "разблокирован: " + rest


func _banned() -> Array:
	var out: Array = access.banned_names.duplicate()
	for key in access.banned_keys:
		var n := str(access.banned_keys[key]).to_lower()
		if not out.has(n):
			out.append(n)
	return out


## "whitelist on|off|add <имя>|remove <имя>": only the names on the list come in while
## it is on; turning it on puts those here on it.
func _whitelist(rest: String) -> String:
	var args := rest.split(" ", false, 1)
	var what := args[0] if not args.is_empty() else ""
	var name := args[1].strip_edges().to_lower() if args.size() > 1 else ""
	match what:
		"on":
			access.listed_only = true
			for a: Account in players():
				if not access.listed.has(a.name.to_lower()):
					access.listed.append(a.name.to_lower())
				access.listed_keys[a.name.to_lower()] = a.key
		"off":
			access.listed_only = false
		"add":
			if name == "":
				return "whitelist add <имя>"
			if not access.listed.has(name):
				access.listed.append(name)
		"remove":
			access.listed.erase(name)
			access.listed_keys.erase(name)
		"":
			pass
		_:
			return "whitelist on|off|add <имя>|remove <имя>"
	_save_access()
	return "только свои: %s; в списке: %s" % ["да" if access.listed_only else "нет",
		", ".join(access.listed) if not access.listed.is_empty() else "никого"]


## Puts `a` out with `why` (words for the player) and takes the character out of the world.
func kick(a: Account, why: String, code := CLOSE_KICKED) -> void:
	flag(a, "kick", why, 2)
	if a.peer != null:
		a.peer.ws.put_packet(Protocol.encode(Protocol.event(Protocol.KICK, [why])))
		a.peer.close_after(code, why)
		a.peer.account = null
		a.peer = null
	_forget(a)


## Closes every connection; the characters leave the world.
func stop() -> void:
	if store != null and not stopping:
		if store.save(self):
			_say("мир сохранён")
		else:
			_say("мир не сохранить: см. ошибки выше")
	stopping = true
	for peer in peers:
		if peer.ws.get_ready_state() in [WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING]:
			peer.ws.close(CLOSE_STOP, "сервер остановлен")
	for key in accounts.keys():
		_forget(accounts[key])
	if listening:
		tcp.stop()
		listening = false


## Every connection is closed (after stop, over a few polls).
func done() -> bool:
	for peer in peers:
		if peer.ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			return false
	return true


func _take(peer: Peer, bytes: PackedByteArray) -> void:
	var open := peer.ws.get_ready_state() == WebSocketPeer.STATE_OPEN
	if peer.account == null:
		# One refused, kicked or gone elsewhere says nothing more.
		if open and peer.close_code == 0:
			_hello(peer, bytes)
		return
	var link: PlayerLink = peer.account.link
	var msg := Protocol.decode(bytes)
	if msg.is_empty() or not msg[0] is String:
		flag(peer.account, "malformed", "не сообщение (%d байт)" % bytes.size(), 1)
		return
	if msg.size() == 2 and msg[0] == Protocol.BYE:
		peer.account.linger = linger_of(peer.account)
		if open:
			peer.close_after(1000, "пока")
		return
	# What the animals have in mind only a host may see (Protocol.AI_DEBUG): a role taken
	# away stops it.
	link.requests.may_debug = is_host(peer.account.key)
	link.requests.ai_debug = link.requests.ai_debug and link.requests.may_debug
	var reply: Variant = link.handle_msg(msg)
	if reply is PackedByteArray and open:
		for b in link.flush():
			peer.ws.put_packet(b)
		peer.ws.put_packet(reply)


## The first message must be a HELLO request; the player is let in or refused.
func _hello(peer: Peer, bytes: PackedByteArray) -> void:
	var msg := Protocol.decode(bytes)
	if msg.size() != 3 or not msg[0] is String or msg[0] != Protocol.HELLO or not msg[1] is int or not msg[2] is Array:
		peer.ws.close(CLOSE_REFUSED, "hello first")
		return
	var seq: int = msg[1]
	var args: Array = msg[2]
	var why := _refusal(args, peer.address)
	if why != "":
		var who_said := Protocol.clean_text(str(args[2]), NAME_MAX) if args.size() > 2 else "?"
		_say("%s: отказ (%s) с %s" % [who_said, why, peer.address])
		if why in [Protocol.WHY_PASSWORD, Protocol.WHY_WAIT, Protocol.WHY_BANNED, Protocol.WHY_LIST]:
			flag(null, "login", "%s: отказ (%s) с %s" % [who_said, why, peer.address], 1)
		peer.ws.put_packet(Protocol.encode(Protocol.reply(seq, {"ok": false, "why": why})))
		peer.close_after(CLOSE_REFUSED, why)
		return
	var name := Protocol.clean_text(args[2], NAME_MAX)
	var key: String = args[3]
	var a: Account = accounts.get(key)
	if a != null:
		if a.peer != null:
			# The same player from another device or tab: the old connection goes.
			a.peer.close_after(CLOSE_ELSEWHERE, "вы вошли с другого устройства")
			a.peer.account = null
		a.name = name
		a.link.who.player_name = name
		a.link.rejoin()
		_say("%s (%d): снова на связи с %s" % [a.name, a.id, peer.address])
	else:
		# One who was here before (the character left the world, or the server was
		# restarted) comes back to it by the key.
		var record: Dictionary = store.read_player(key) if store != null and key != "" else {}
		a = Account.new()
		if record.is_empty():
			a.id = next_id
			a.key = Crypto.new().generate_random_bytes(16).hex_encode()
			_new_at.append(_now())
		else:
			a.id = int(record.id)
			a.key = key
		next_id = maxi(next_id, a.id + 1)
		a.name = name
		a.link = PlayerLink.new(session)
		a.link.snap_every = SNAP_EVERY
		a.link.people_every = PEOPLE_EVERY
		a.link.send_world = true
		a.link.who.id = a.id
		a.link.who.player_name = a.name
		a.link.who.check_moves = true
		a.link.requests.paced = true
		a.link.requests.flagged.connect(_on_flagged.bind(a.key))
		a.link.requests.chatted.connect(_on_chat.bind(a.key))
		a.link.requests.team_chatted.connect(_on_team_chat.bind(a.key))
		if record.is_empty():
			a.link.who.start_bag()
			a.link.who.teleport(world_info.spawn)
		else:
			ServerStore.restore(a.link, record)
		a.link.who.find_home(session.placed)
		session.teams.seen(a.id, a.name)
		accounts[a.key] = a
		if not wild:
			wild = true
			session.start_wildlife(int(world_info.seed))
		_say("%s (%d): %s с %s (%d из %d)" % [a.name, a.id, "вход" if record.is_empty() else "возвращается",
			peer.address, online() + 1, config.max_players])
	a.peer = peer
	a.left_at = -1.0
	a.linger = LINGER
	peer.account = a
	if access.listed.has(name.to_lower()) and not access.listed_keys.has(name.to_lower()):
		# A name on the list is the first key's that comes with it.
		access.listed_keys[name.to_lower()] = a.key
		_save_access()
	var welcome := {"ok": true, "id": a.id, "key": a.key, "name": a.name, "at": a.link.who.position,
		"title": config.title}
	welcome.merge(world_info)
	peer.ws.put_packet(Protocol.encode(Protocol.reply(seq, welcome)))
	for b in a.link.flush():
		peer.ws.put_packet(b)


## Why the HELLO with `args` from `address` is refused, "" when it is not.
func _refusal(args: Array, address := "") -> String:
	if args.size() != 5 or not args[0] is int or not args[1] is String or not args[2] is String \
			or not args[3] is String or not args[4] is String or args[3].length() > 64:
		return Protocol.WHY_VERSION
	if args[0] != Protocol.VERSION or args[1] != Protocol.build_version():
		return Protocol.WHY_VERSION
	var name := Protocol.clean_text(args[2], NAME_MAX)
	if name == "":
		return Protocol.WHY_NAME
	var now := _now()
	# A player the server knows (by the key it gave) is never held up by others' tries:
	# behind a tunnel everyone comes from this machine.
	var known: bool = accounts.has(args[3]) or store != null and args[3] != "" and not store.read_player(args[3]).is_empty()
	var wrong: Array = _wrong.get(address, []).filter(func(t: float) -> bool: return now - t < PASSWORD_WINDOW)
	_wrong[address] = wrong
	if wrong.size() >= PASSWORD_TRIES and not known:
		return Protocol.WHY_WAIT
	if config.password != "" and not _same(args[4], config.password):
		wrong.append(now)
		return Protocol.WHY_PASSWORD
	if wrong.is_empty():
		_wrong.erase(address)
	var low := name.to_lower()
	if access.banned_keys.has(args[3]) or access.banned_names.has(low):
		return Protocol.WHY_BANNED
	if access.listed_only and (not access.listed.has(low)
			or access.listed_keys.has(low) and access.listed_keys[low] != args[3]):
		return Protocol.WHY_LIST
	if low in RESERVED_NAMES:
		return Protocol.WHY_TAKEN
	for key in accounts:
		if key != args[3] and accounts[key].name.to_lower() == low:
			return Protocol.WHY_TAKEN
	if not accounts.has(args[3]) and accounts.size() >= config.max_players:
		return Protocol.WHY_FULL
	if not known:
		while not _new_at.is_empty() and now - _new_at[0] > NEW_WINDOW:
			_new_at.pop_front()
		if _new_at.size() >= NEW_PLAYERS:
			return Protocol.WHY_WAIT
	return ""


## Whether two words are the same, compared in a time that does not tell how much of
## them matched.
static func _same(a: String, b: String) -> bool:
	var x := a.sha256_buffer()
	var y := b.sha256_buffer()
	var d := 0
	for i in x.size():
		d |= x[i] ^ y[i]
	return d == 0


## Connections that have not said hello (from `address`; "" any, and all of this
## machine's count as one address only if it is another).
func _pending(address := "") -> int:
	var n := 0
	for p in peers:
		if p.account == null and p.close_code == 0 and (address == "" or p.address == address):
			n += 1
	return n


## Whether one more message of `peer` may be read now (MSG_RATE); one that keeps sending
## past it is put out.
func _within_rate(peer: Peer, now: float) -> bool:
	if peer.tokens_at >= 0.0:
		var dt := now - peer.tokens_at
		peer.tokens = minf(MSG_BURST, peer.tokens + dt * MSG_RATE)
		peer.refused = maxf(0.0, peer.refused - dt * MSG_RATE)
	peer.tokens_at = now
	if peer.tokens >= 1.0:
		peer.tokens -= 1.0
		return true
	peer.refused += 1.0
	if peer.refused > FLOOD_KICK * MSG_RATE and peer.close_code == 0:
		flag(peer.account, "flood", "слишком много сообщений: отключён", 2)
		if peer.account != null:
			kick(peer.account, "слишком много сообщений", CLOSE_FLOOD)
		else:
			peer.close_after(CLOSE_FLOOD, "слишком много сообщений")
	elif int(peer.refused) % int(MSG_RATE) == 1:
		flag(peer.account, "flood", "сообщения чаще %d в секунду не читаются" % int(MSG_RATE), 1)
	return false


## Notes in the security log that something looked wrong (`what` its kind, `detail` in
## words, `level` 0 a note, 1 a warning, 2 what put one out) with player `a` (null: a
## connection not let in); a line for the terminal, at most one of a kind about one
## player in SECURITY_EVERY seconds (the others counted into it). Nothing secret is
## written: no keys, no passwords.
func flag(a: Account, what: String, detail: String, level := 1) -> void:
	var now := _now()
	var e := {"at": Time.get_datetime_string_from_system(), "id": a.id if a != null else 0,
		"name": a.name if a != null else "", "what": what, "detail": detail, "level": level}
	security_log.append(e)
	while security_log.size() > SECURITY_KEPT:
		security_log.pop_front()
	var k := "%d:%s" % [e.id, what]
	var last: Array = _flag_at.get(k, [-INF, 0])
	if level < 2 and now - last[0] < SECURITY_EVERY:
		_flag_at[k] = [last[0], last[1] + 1]
		return
	_flag_at[k] = [now, 0]
	_say("безопасность: " + _security_line(e) + (" (и ещё %d)" % last[1] if last[1] > 0 else ""))


static func _security_line(e: Dictionary) -> String:
	return "%s [%s] %s%s: %s" % [e.at, ["заметка", "внимание", "меры"][clampi(e.level, 0, 2)], e.what,
		" — %s (%d)" % [e.name, e.id] if e.id != 0 else "", e.detail]


## A request of the player of `key` looked wrong (Requests.flagged).
func _on_flagged(what: String, detail: String, key: String) -> void:
	flag(accounts.get(key), what, detail, 1)


## The connection `peer` is closed: its player waits for them to come back.
func _dropped(peer: Peer) -> void:
	peers.erase(peer)
	var a := peer.account
	if a == null:
		return
	peer.account = null
	if a.peer != peer:
		return
	a.peer = null
	a.left_at = _now()
	a.linger = minf(a.linger, linger_of(a))
	if a.linger > 0.0:
		_say("%s (%d): связь потеряна, персонаж ждёт %d с" % [a.name, a.id, int(a.linger)])
	else:
		_say("%s (%d): вышел на своей земле" % [a.name, a.id])


## Seconds the character of `a` stays in the world once they leave: none in their own
## or their team's land, else LINGER (decision on leaving, plan/design/territory-pvp.md).
func linger_of(a: Account) -> float:
	return 0.0 if session.territory.at_home(a.link.who) else LINGER


## The character of `a` leaves the world, saved first (on stop the snapshot has it).
func _forget(a: Account) -> void:
	if not accounts.has(a.key):
		return
	if store != null and not stopping:
		# The whole snapshot, the player still in it: a thing moved between a chest and
		# the bag is saved in one of them, never both or neither.
		store.save(self)
	accounts.erase(a.key)
	if a.peer != null:
		a.peer.account = null
		a.peer = null
	a.link.leave()
	_say("%s (%d): персонаж покинул мир" % [a.name, a.id])


func _find(what: String) -> Account:
	for key in accounts:
		var a: Account = accounts[key]
		if a.name == what or str(a.id) == what:
			return a
	return null


func _say(text: String) -> void:
	lines.append(text)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
