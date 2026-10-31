extends RefCounted
## The server over the network (plan/architecture/server.md, С3): listens on a port,
## takes WebSocket connections, lets players in by name and key (Protocol.HELLO), hands
## each player's messages to their link (PlayerLink) and sends the links' events after
## each tick (flush). A player whose connection is lost keeps their character in the
## world LINGER seconds, so a page reloaded comes back to it with the key the welcome
## gave; one who says goodbye (BYE) a short while. The host's commands (command): who,
## say, kick, stop. Each message is one binary frame; the reply to HELLO goes before
## the events of joining (the client knows who it is before its copies fill), and the
## events of any other request before its reply, as over the loop. With a `store`
## (ServerStore, С4) a character that leaves the world is saved and a player who comes
## back with their key, after a restart too, gets it again; stop saves everything.

const Protocol := preload("res://src/shared/net/protocol.gd")
const PlayerLink := preload("res://src/server/player_link.gd")
const ServerStore := preload("res://src/server/server_store.gd")
const Config := preload("res://src/server/config.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

## Seconds a character stays in the world after its connection is lost, and after a
## goodbye.
const LINGER := 30.0
const BYE_LINGER := 5.0
## Seconds a connection has to say hello.
const HELLO_WAIT := 10.0
## Seconds between the animals' snapshots over a socket (PlayerLink.snap_every).
const SNAP_EVERY := 0.1
## Seconds between the other players' snapshots to a player (PlayerLink.people_every).
const PEOPLE_EVERY := 0.05
## Bytes a frame may hold each way (the chunks of С3.2 are large).
const BUFFER := 4 << 20
## Letters a name may have.
const NAME_MAX := 24
## The codes a connection is closed with: 1000 the client's own goodbye, 1001 the
## server stopping, 4000 refused at hello (or no hello), 4001 kicked by the host, 4002
## the same player came in again elsewhere.
const CLOSE_STOP := 1001
const CLOSE_REFUSED := 4000
const CLOSE_KICKED := 4001
const CLOSE_ELSEWHERE := 4002

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
		peer.ws = WebSocketPeer.new()
		peer.ws.inbound_buffer_size = BUFFER
		peer.ws.outbound_buffer_size = BUFFER
		peer.ws.max_queued_packets = 4096
		peer.since = now
		if peer.ws.accept_stream(stream) == OK:
			peers.append(peer)
	for peer in peers.duplicate():
		var ws: WebSocketPeer = peer.ws
		ws.poll()
		var state := ws.get_ready_state()
		# What came before a close (a goodbye) is read still.
		while ws.get_available_packet_count() > 0:
			_take(peer, ws.get_packet())
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


## Does the host's command `line` (who, say, kick, stop, help); the words to print.
func command(line: String) -> String:
	var parts := line.strip_edges().split(" ", false, 1)
	if parts.is_empty():
		return ""
	var rest := parts[1].strip_edges() if parts.size() > 1 else ""
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
				accounts[key].link.tell(rest)
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
		"help", "?":
			return "who — кто в мире; say <слова> — сказать всем; kick <имя или номер> — отключить; stop — остановить сервер"
	return "неизвестная команда «%s»; help — список" % parts[0]


## Puts `a` out with `why` (words for the player) and takes the character out of the world.
func kick(a: Account, why: String) -> void:
	if a.peer != null:
		a.peer.ws.put_packet(Protocol.encode(Protocol.event(Protocol.KICK, [why])))
		a.peer.close_after(CLOSE_KICKED, why)
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
		if open:
			_hello(peer, bytes)
		return
	var link: PlayerLink = peer.account.link
	var msg := Protocol.decode(bytes)
	if msg.size() == 2 and msg[0] == Protocol.BYE:
		peer.account.linger = BYE_LINGER
		if open:
			peer.close_after(1000, "пока")
		return
	var reply: Variant = link.handle(bytes)
	if reply is PackedByteArray and open:
		for b in link.flush():
			peer.ws.put_packet(b)
		peer.ws.put_packet(reply)


## The first message must be a HELLO request; the player is let in or refused.
func _hello(peer: Peer, bytes: PackedByteArray) -> void:
	var msg := Protocol.decode(bytes)
	if msg.size() != 3 or msg[0] != Protocol.HELLO or not msg[1] is int or not msg[2] is Array:
		peer.ws.close(CLOSE_REFUSED, "hello first")
		return
	var seq: int = msg[1]
	var args: Array = msg[2]
	var why := _refusal(args)
	if why != "":
		_say("%s: отказ (%s) с %s" % [str(args[2]) if args.size() > 2 else "?", why, peer.address])
		peer.ws.put_packet(Protocol.encode(Protocol.reply(seq, {"ok": false, "why": why})))
		peer.close_after(CLOSE_REFUSED, why)
		return
	var name := str(args[2]).strip_edges().left(NAME_MAX)
	var key := str(args[3])
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
		if record.is_empty():
			a.link.who.start_bag()
			a.link.who.teleport(world_info.spawn)
		else:
			ServerStore.restore(a.link, record)
		a.link.who.find_home(session.placed)
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
	var welcome := {"ok": true, "id": a.id, "key": a.key, "name": a.name, "at": a.link.who.position}
	welcome.merge(world_info)
	peer.ws.put_packet(Protocol.encode(Protocol.reply(seq, welcome)))
	for b in a.link.flush():
		peer.ws.put_packet(b)


## Why the HELLO with `args` is refused, "" when it is not.
func _refusal(args: Array) -> String:
	if args.size() != 5 or not args[0] is int or not args[1] is String or not args[2] is String \
			or not args[3] is String or not args[4] is String:
		return Protocol.WHY_VERSION
	if args[0] != Protocol.VERSION or args[1] != Protocol.build_version():
		return Protocol.WHY_VERSION
	if str(args[2]).strip_edges() == "":
		return Protocol.WHY_NAME
	if config.password != "" and args[4] != config.password:
		return Protocol.WHY_PASSWORD
	if not accounts.has(args[3]) and accounts.size() >= config.max_players:
		return Protocol.WHY_FULL
	return ""


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
	_say("%s (%d): связь потеряна, персонаж ждёт %d с" % [a.name, a.id, int(a.linger)])


## The character of `a` leaves the world, saved first (on stop the snapshot has it).
func _forget(a: Account) -> void:
	if not accounts.has(a.key):
		return
	if store != null and not stopping:
		store.save_player(a)
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
