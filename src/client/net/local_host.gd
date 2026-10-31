extends RefCounted
## The server inside the game, for single player (plan/architecture/server.md, decision
## 153): the one place the client loads the server's code. Its player's requests go
## through the same bytes they would over a socket, into Requests, and the reply comes
## back at once: the game is played through the protocol even alone, so what the
## protocol costs is measured here and nothing works only over the loop.

const Requests := preload("res://src/server/requests.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Connection := preload("res://src/client/net/connection.gd")

var requests: Requests


func _init(session, who, workshop) -> void:
	requests = Requests.new(session, who, workshop)


## The client's connection to this host.
func link() -> Connection:
	return Connection.new(deliver)


## Takes the request in `bytes` to the server and gives back the reply's bytes.
func deliver(bytes: PackedByteArray) -> PackedByteArray:
	return Protocol.encode(requests.handle(Protocol.decode(bytes)))
