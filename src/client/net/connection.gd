extends RefCounted
## The client's side of the protocol (plan/architecture/server.md, Protocol): makes
## requests of the server and hands their replies to whoever asked. A request goes out
## as bytes through `transport` (a Callable: the loop into the game's own process in
## single player, LocalHost; a socket at stage С3) and comes back as a Reply, which is
## done at once over the loop and later over a socket; `then` runs a callback either
## way. The bytes are counted both ways, with the time spent coding them, for the
## stats panel to tell what the protocol costs.

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


## Sends bytes to the server; gives back the reply's bytes when it is in at once (the
## loop), else null (the replies come through `receive`).
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
	_seq += 1
	requests += 1
	var reply := Reply.new()
	_waiting[_seq] = reply
	var t := Time.get_ticks_usec()
	var bytes := Protocol.encode(Protocol.request(kind, _seq, args))
	coding_us += Time.get_ticks_usec() - t
	sent_bytes += bytes.size()
	var back: Variant = transport.call(bytes)
	if back is PackedByteArray:
		receive(back)
	return reply


## Takes in the reply in `bytes` from the server.
func receive(bytes: PackedByteArray) -> void:
	received_bytes += bytes.size()
	var t := Time.get_ticks_usec()
	var msg := Protocol.decode(bytes)
	coding_us += Time.get_ticks_usec() - t
	if msg.size() != 2 or not msg[0] is int:
		return
	var reply: Reply = _waiting.get(msg[0])
	if reply != null:
		_waiting.erase(msg[0])
		reply.resolve(msg[1])


## Requests sent and not answered yet.
func pending() -> int:
	return _waiting.size()
