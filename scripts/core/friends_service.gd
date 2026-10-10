class_name FriendsService
extends RefCounted
## Service contract for social features. A central backend would implement
## global friend lists, invites and reports; without one, LocalFriendsService
## below does only what is genuinely possible on a single device:
##   - recent players met in online rooms (names, local history)
##   - local block list: blocked names are muted in voice chat and refused when
##     they try to join a room you host
## Global friends, cross-device invites and abuse reports are NOT available and
## the UI says so — no button pretends otherwise.

func supports_global_friends() -> bool:
	return false


func supports_reports() -> bool:
	return false


func recent_players() -> Array:
	return []


func is_blocked(_name: String) -> bool:
	return false


func set_blocked(_name: String, _blocked: bool) -> void:
	pass


class LocalFriendsService:
	extends FriendsService
	const RECENT_MAX := 30

	func recent_players() -> Array:
		return Save.section("social").get("recent", [])

	func record_players(names: Array, online: bool) -> void:
		var social := Save.section("social")
		var list: Array = social.get("recent", [])
		var me := str(Save.section("profile").get("name", ""))
		for n in names:
			var name := str(n)
			if name == "" or name == me:
				continue
			list = list.filter(func(e): return e.get("name", "") != name)
			list.push_front({"name": name, "t": int(Time.get_unix_time_from_system()), "online": online})
		social["recent"] = list.slice(0, RECENT_MAX)
		Save.mark_dirty()

	func is_blocked(name: String) -> bool:
		return Save.section("social").get("blocked", []).has(name)

	func set_blocked(name: String, blocked: bool) -> void:
		var social := Save.section("social")
		var list: Array = social.get("blocked", [])
		if blocked and not list.has(name):
			list.append(name)
		elif not blocked:
			list.erase(name)
		social["blocked"] = list
		Save.mark_dirty()
		if blocked:
			VoiceSettings.set_name_muted(name, true)


static var _local: LocalFriendsService


static func local() -> LocalFriendsService:
	if _local == null:
		_local = LocalFriendsService.new()
	return _local
