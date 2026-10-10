class_name VoiceConnection
extends RefCounted
## Sends this device's voice packets through the current room connection.
## Host: straight to every client that wants voice. Client: to the host,
## which relays to the others (star topology, same as the game messages).

var host: RoomHost
var client: RoomClient


static func for_host(h: RoomHost) -> VoiceConnection:
	var c := VoiceConnection.new()
	c.host = h
	return c


static func for_client(cl: RoomClient) -> VoiceConnection:
	var c := VoiceConnection.new()
	c.client = cl
	return c


func my_pid() -> int:
	if host:
		return RoomHost.HOST_PID
	return client.pid if client else -1


func send(seq: int, data: PackedByteArray) -> void:
	if host and is_instance_valid(host):
		host.relay_voice(RoomHost.HOST_PID, seq, data)
	elif client and is_instance_valid(client) and client.transport:
		client.transport.send(NetTransport.HOST_ID, {"k": NetProtocol.C_VOICE, "s": seq, "d": data}, false)


## Tells the host whether this device wants to receive voice at all.
func set_receive(enabled: bool) -> void:
	if client and is_instance_valid(client) and client.transport:
		client.transport.send(NetTransport.HOST_ID, {"k": NetProtocol.C_VOICE_PREF, "recv": enabled})


func valid() -> bool:
	return (host != null and is_instance_valid(host)) or (client != null and is_instance_valid(client))
