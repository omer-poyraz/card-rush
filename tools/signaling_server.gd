extends Node
## Local development signaling server (same protocol as the Cloudflare Worker).
##   godot --headless --path . res://tools/signaling_server.tscn -- --port 9080 [--bind 0.0.0.0]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var port := 9080
	var bind := "127.0.0.1"
	for i in a.size():
		if a[i] == "--port" and i + 1 < a.size():
			port = int(a[i + 1])
		if a[i] == "--bind" and i + 1 < a.size():
			bind = a[i + 1]
	var s := DevSignalingServer.new()
	add_child(s)
	var err := s.start(port, bind)
	print("Card Rush dev signaling on ws://%s:%d -> %s" % [bind, port, "ok" if err == OK else error_string(err)])
