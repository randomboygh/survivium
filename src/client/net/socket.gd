extends RefCounted
## The client's connection to a server over the network (plan/architecture/server.md,
## С3): a WebSocket the Connection's bytes go through (its transport), polled each frame
## for what came in (Connection.receive). Opened with the server's address, it says
## hello once the socket is open (hello: the first request, Protocol.HELLO; what is
## sent before waits in a queue) and tells how the connection stands: `opened`, then
## `closed` with the code and the words the server closed with (Server's codes; -1 and
## "" when the connection was lost or the server is not there). A client over a socket
## gets a request's reply later, through `Reply.then`.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Connection := preload("res://src/client/net/connection.gd")

## Bytes a frame may hold each way (the chunks of С3.2 are large).
const BUFFER := 4 << 20

## The socket is open: what waited went out.
signal opened
## The socket closed, with the server's code and words.
signal closed(code: int, reason: String)

var ws := WebSocketPeer.new()
## The client's side of the protocol over this socket.
var net: Connection
var url := ""
## The socket closed (see closed), with this code and these words (-1 and "" when the
## connection was lost or never made).
var ended := false
var close_code := -1
var close_reason := ""
var _queue: Array[PackedByteArray] = []
var _open := false
## Polls left before the close asked by leave (the goodbye goes first: a close frame
## would go before the data queued).
var _close_in := -1


func _init() -> void:
	# A method, not a lambda: a Callable to a method does not hold the socket, so the
	# socket and its connection are freed together.
	net = Connection.new(_transport)
	ws.inbound_buffer_size = BUFFER
	ws.outbound_buffer_size = BUFFER
	ws.max_queued_packets = 4096


## Starts connecting to `address` ("ws://host:port"); the error if it is not an address.
func open(address: String) -> Error:
	url = address
	return ws.connect_to_url(address)


## The first request: who the player is (Protocol.HELLO); the welcome or the refusal
## comes as the reply.
func hello(name: String, key := "", password := ""):
	return net.request(Protocol.HELLO, [Protocol.VERSION, Protocol.build_version(), name, key, password])


## Takes what came in and sends what waited; call every frame.
func poll() -> void:
	ws.poll()
	var state := ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not _open:
		_open = true
		for b in _queue:
			ws.put_packet(b)
		_queue.clear()
		opened.emit()
	# What came before a close (a refusal's reply) is still read after it.
	while ws.get_available_packet_count() > 0:
		net.receive(ws.get_packet())
	if _close_in >= 0 and state == WebSocketPeer.STATE_OPEN:
		_close_in -= 1
		if _close_in < 0:
			ws.close(1000, "bye")
	if state == WebSocketPeer.STATE_CLOSED:
		_open = false
		if not ended:
			ended = true
			close_code = ws.get_close_code()
			close_reason = ws.get_close_reason()
			closed.emit(close_code, close_reason)


## Says goodbye (Protocol.BYE) and closes, a few polls later.
func leave() -> void:
	if _open and _close_in < 0:
		net.send(Protocol.BYE, [])
		_close_in = 2


func _transport(bytes: PackedByteArray) -> Variant:
	if _open:
		ws.put_packet(bytes)
	else:
		_queue.append(bytes)
	return null
