extends RefCounted
## The client's side of the protocol (plan/architecture/server.md, Protocol): makes
## requests of the server and hands their replies to whoever asked, sends the client's
## events (its body each frame) and gives out the server's (the state of the player's
## copies) as the `event` signal. A message goes out as bytes through `transport` (a
## Callable: the loop into the game's own process in single player, LocalHost; a socket
## at stage С3); a request comes back as a Reply, done at once over the loop and later
## over a socket; `then` runs a callback either way. The bytes are counted both ways,
## with the time spent coding them, for the stats panel to tell what the protocol costs.

const Protocol := preload("res://src/shared/net/protocol.gd")


## The answer to a request: `value` once `done`.
class Reply extends RefCounted:
	var done := false
	var value: Variant = null
	var _then: Array[Callable] = []

	## Runs `cb` with the value, now if the reply is in.
	func then(cb: Callable) -> Reply:
		if done:
			cb.call(value)
		else:
			_then.append(cb)
		return self

	func resolve(v: Variant) -> void:
		done = true
		value = v
		for cb in _then:
			cb.call(v)
		_then.clear()


## An event from the server (Protocol: YOU, SHOP, SAY…), for the client's copies.
signal event(kind: String, args: Variant)
## A request is about to go out: what the server should know first (the body and the
## hands, Mirror.send_input) goes before it.
signal sending

## Sends bytes to the server; gives back what came in at once (the loop: an Array of
## the messages' bytes), else null (they come through `receive`).
var transport: Callable
var _seq := 0
var _waiting := {}
## Requests made, and the bytes both ways.
var requests := 0
var sent_bytes := 0
var received_bytes := 0
## Microseconds spent encoding requests and decoding replies.
var coding_us := 0


func _init(t: Callable) -> void:
	transport = t


## Asks the server for `kind` with `args` (Protocol); the Reply.
func request(kind: String, args: Array) -> Reply:
	sending.emit()
	_seq += 1
	requests += 1
	var reply := Reply.new()
	_waiting[_seq] = reply
	var t := Time.get_ticks_usec()
	var bytes := Protocol.encode(Protocol.request(kind, _seq, args))
	coding_us += Time.get_ticks_usec() - t
	sent_bytes += bytes.size()
	_send(bytes)
	return reply


## Tells the server `kind` with `args` (an event, Protocol): no reply.
func send(kind: String, args: Variant) -> void:
	var t := Time.get_ticks_usec()
	var bytes := Protocol.encode(Protocol.event(kind, args))
	coding_us += Time.get_ticks_usec() - t
	sent_bytes += bytes.size()
	_send(bytes)


func _send(bytes: PackedByteArray) -> void:
	var back: Variant = transport.call(bytes)
	if back is Array:
		for b in back:
			if b is PackedByteArray:
				receive(b)


## Takes in the reply in `bytes` from the server.
func receive(bytes: PackedByteArray) -> void:
	received_bytes += bytes.size()
	var t := Time.get_ticks_usec()
	var msg := Protocol.decode(bytes)
	coding_us += Time.get_ticks_usec() - t
	if msg.size() != 2:
		return
	if msg[0] is String:
		event.emit(msg[0], msg[1])
		return
	if not msg[0] is int:
		return
	var reply: Reply = _waiting.get(msg[0])
	if reply != null:
		_waiting.erase(msg[0])
		reply.resolve(msg[1])


## Requests sent and not answered yet.
func pending() -> int:
	return _waiting.size()
