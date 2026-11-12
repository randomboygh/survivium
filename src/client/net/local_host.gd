extends RefCounted
## The server inside the game, for single player (plan/architecture/server.md, decision
## 153): the one place the client loads the server's code. The player joins it as a
## link (PlayerLink) and talks to it through a Connection over a loop: the request's
## bytes go into the link, the state it changed comes back as events before the reply,
## and `flush` after each tick brings the rest. So the game is played through the
## protocol even alone, what it costs is measured here (Connection's counters), and
## nothing works only over the loop. The server's loop is a node under the tree's root
## (Runner): it ticks the session and has the world made before the client's frame, and
## it is stopped when the client's scene leaves the tree (Main), unless kept (С5). Until
## the saves move to the server (С4) and the playtest page gets its commands (С5),
## `player` and `workshop` are reached directly.
## On a computer the menu's «Создать сервер» makes here the server of the terminal
## (src/server/server_main.gd, `host`), which the game then joins over a socket.

const Protocol := preload("res://src/shared/net/protocol.gd")
const PlayerLink := preload("res://src/server/player_link.gd")
const Runner := preload("res://src/server/runner.gd")
const RealWeather := preload("res://src/server/real_weather.gd")
const Connection := preload("res://src/client/net/connection.gd")
const Rules := preload("res://src/shared/game/rules.gd")
## The server made from the menu: compiled only when one is made; its settings.
const SERVER_MAIN := "res://src/server/server_main.gd"
const SERVER_CONFIG := "res://src/server/config.gd"

var session
var link: PlayerLink
var runner: Runner
## The weather of the real world pinned on the session's clock while the game's setting
## asks (Settings.apply); with the loop only.
var real_weather: RealWeather
## The player's character and workshop on the server.
var player
var workshop


## Makes the server's loop for `s` (Session) under `tree_root`; with none (tests), there
## is no loop and the test steps the session itself.
func _init(s, tree_root: Node = null) -> void:
	session = s
	if tree_root != null:
		runner = Runner.new(s)
		tree_root.add_child(runner)
		real_weather = RealWeather.new()
		real_weather.clock = s.clock
		runner.add_child(real_weather)


## The server the menu makes (С5.2) with the settings `values` (Config's: title, port,
## max_players, password, world, seed_value, settings), started at once: its world
## opened (its bundles activated) and listening; the node goes under `tree_root` at the
## end of the frame and outlives the game's scene. Its `failed` says why it did not
## start; its settings are written to the server's settings file, so a server from the
## terminal starts the same.
static func host(values: Dictionary, tree_root: Node) -> Node:
	var node: Node = load(SERVER_MAIN).new()
	node.name = "HostedServer"
	node.hosted = true
	node.config.read()
	for k: String in values:
		if k == "rules":
			# The window's rules over the file's: the others it keeps (Rules.to_dict keys).
			node.config.rules.merge(values.rules, true)
		else:
			node.config.set(k, values[k])
	node.config.console = false
	if node.start():
		node.config.write()
		tree_root.add_child.call_deferred(node)
	return node


## The settings of the server the menu makes, as its window «Создать сервер» shows
## them: those of the server's settings file (Config), or the defaults when `saved` is
## off; `rules` with every rule (Rules.to_dict), the file's over their defaults.
static func server_settings(saved := true) -> Dictionary:
	var c = load(SERVER_CONFIG).new()
	if saved:
		c.read()
	return settings_of(c)


## The same of the settings `c` (Config) of a server that runs.
static func settings_of(c) -> Dictionary:
	return {"title": c.title, "port": c.port, "max_players": c.max_players, "password": c.password,
		"autosave": c.autosave, "tunnel": c.tunnel, "real_weather": c.real_weather,
		"day_minutes": c.day_minutes, "rules": Rules.of(c.rules).to_dict()}


## Stops the server's loop and frees it at the end of the frame (Main calls this while
## the tree is taking its scene out, when a child cannot be removed at once).
func stop() -> void:
	if runner == null:
		return
	runner.set_process(false)
	runner.queue_free()
	runner = null
	real_weather = null


## The player joins the server; the client's connection to it.
func join() -> Connection:
	link = PlayerLink.new(session)
	# The world is the player's own: they may see what the animals have in mind.
	link.requests.may_debug = true
	player = link.who
	workshop = link.workshop
	return Connection.new(deliver)


## Takes the message in `bytes` to the server and gives back what the server sends:
## the events of what changed, then the reply.
func deliver(bytes: PackedByteArray) -> Array:
	var reply: Variant = link.handle(bytes)
	var back: Array = Array(link.flush())
	if reply is PackedByteArray:
		back.append(reply)
	return back


## Brings the client's connection `net` the events of the tick.
func flush(net: Connection) -> void:
	for b in link.flush():
		net.receive(b)
