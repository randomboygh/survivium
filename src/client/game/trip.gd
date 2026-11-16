extends RefCounted
## Going somewhere far (a respawn point picked on the death screen, a place of the test
## page): the world is built where the player goes first (user's pick, 2026-11-16), so
## the jump lands in a world built instead of holes. `go` asks the server to make the
## place ready (Protocol.PREPARE: Session.zones makes it, PlayerLink sends it), Main
## builds the chunks round it (ChunkStreamer.focus) and `update` makes the jump once
## the chunks on the screen there are built, or after MOST_MS whatever there is.
## `game` is the Main node.

const Protocol := preload("res://src/shared/net/protocol.gd")

## The longest wait, ms (a phone builds a screen of new land in a few seconds).
const MOST_MS := 20000

var game
## Where the player is going (world units), INF when not going anywhere.
var target := Vector3.INF
var _then := Callable()
var _from := 0


func _init(g) -> void:
	game = g


## Goes to `at` (world units): `then` is called when the place is built.
func go(at: Vector3, then: Callable) -> void:
	target = at
	_then = then
	_from = Time.get_ticks_msec()
	game.net.request(Protocol.PREPARE, [at])


func going() -> bool:
	return target.is_finite()


## How much of the place is built, 0..1.
func progress() -> float:
	if not going() or game.chunks.focus != target:
		return 0.0
	return game.chunks.focus_built()


## Makes the jump once the place is built; run every frame before the chunks are built
## (Main sets their focus to `target`).
func update() -> void:
	if not going():
		return
	if progress() >= 1.0 or Time.get_ticks_msec() - _from > MOST_MS:
		var then := _then
		cancel()
		then.call()


func cancel() -> void:
	target = Vector3.INF
	_then = Callable()
