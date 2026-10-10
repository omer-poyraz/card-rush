class_name ENetAdapter
extends RefCounted
## Connection adapter for LAN and direct-IP play (Godot's built-in ENet, UDP).
## Works out of the box on the same Wi-Fi/LAN. Across the internet it needs a
## reachable host (public IP / port forwarding / a VPN such as a mesh VPN);
## mobile carrier NAT usually prevents that — see docs/NETWORKING.md.

const MAX_CLIENTS := 16


static func host(port := NetProtocol.GAME_PORT) -> Dictionary:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, MAX_CLIENTS, 2)
	if err != OK:
		return {"ok": false, "error": "ERR_NET_PORT_BUSY" if err == ERR_ALREADY_IN_USE or err == ERR_CANT_CREATE else "ERR_NET_HOST_FAILED"}
	var t := PeerTransport.new()
	t.setup(p, true)
	return {"ok": true, "transport": t}


static func join(address: String, port := NetProtocol.GAME_PORT) -> Dictionary:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(address, port, 2)
	if err != OK:
		return {"ok": false, "error": "ERR_NET_JOIN_FAILED"}
	var t := PeerTransport.new()
	t.setup(p, false)
	return {"ok": true, "transport": t}


## Private IPv4 addresses of this device (shown to the host for direct joins).
static func local_ipv4() -> Array[String]:
	var out: Array[String] = []
	for a in IP.get_local_addresses():
		if a.contains(":"):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or _is_172_private(a) or a.begins_with("100."):
			out.append(a)
	return out


static func _is_172_private(a: String) -> bool:
	if not a.begins_with("172."):
		return false
	var parts := a.split(".")
	return parts.size() == 4 and int(parts[1]) >= 16 and int(parts[1]) <= 31
