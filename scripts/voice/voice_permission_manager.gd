class_name VoicePermissionManager
extends RefCounted
## Microphone permission, requested only when the player turns the mic on.
## Android: RECORD_AUDIO runtime permission. iOS: the OS shows its prompt the
## first time capture starts (needs NSMicrophoneUsageDescription in the export).
## Desktop: no permission needed.

const ANDROID_PERMISSION := "android.permission.RECORD_AUDIO"

static var denied := false


static func has_permission() -> bool:
	if OS.get_name() == "Android":
		return OS.get_granted_permissions().has(ANDROID_PERMISSION)
	return true


## Calls cb(granted: bool). Never blocks the game when refused.
static func request(tree: SceneTree, cb: Callable) -> void:
	if has_permission():
		denied = false
		cb.call(true)
		return
	if OS.get_name() != "Android":
		cb.call(true)
		return
	var handler := func(permission: String, granted: bool):
		if permission == ANDROID_PERMISSION:
			denied = not granted
			cb.call(granted)
	tree.on_request_permissions_result.connect(handler, CONNECT_ONE_SHOT)
	if not OS.request_permission(ANDROID_PERMISSION):
		# already decided by the system (e.g. "don't ask again")
		if tree.on_request_permissions_result.is_connected(handler):
			tree.on_request_permissions_result.disconnect(handler)
		denied = not has_permission()
		cb.call(not denied)
