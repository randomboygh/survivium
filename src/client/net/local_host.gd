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

const Protocol := preload("res://src/shared/net/protocol.gd")
const PlayerLink := preload("res://src/server/player_link.gd")
const Runner := preload("res://src/server/runner.gd")
const Connection := preload("res://src/client/net/connection.gd")

var session
var link: PlayerLink
var runner: Runner
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


## Stops the server's loop and frees it at the end of the frame (Main calls this while
## the tree is taking its scene out, when a child cannot be removed at once).
func stop() -> void:
	if runner == null:
		return
	runner.set_process(false)
	runner.queue_free()
	runner = null


## The player joins the server; the client's connection to it.
func join() -> Connection:
	link = PlayerLink.new(session)
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
