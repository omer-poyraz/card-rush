class_name Economy
extends RefCounted
## Cosmetic soft currency ("coins"). Never buys gameplay advantages.
## Every grant can carry a unique key; the same key is never paid twice
## (rewarded-ad callbacks, mission claims, daily rewards...).

const LEDGER_MAX := 300


static func coins() -> int:
	return int(Save.section("wallet").get("coins", 0))


static func grant(amount: int, reason: String, unique_key := "") -> bool:
	if amount <= 0:
		return false
	var w := Save.section("wallet")
	var ledger: Array = w.get("ledger", [])
	if unique_key != "":
		if ledger.has(unique_key):
			return false
		ledger.append(unique_key)
		while ledger.size() > LEDGER_MAX:
			ledger.pop_front()
		w["ledger"] = ledger
	w["coins"] = coins() + amount
	var hist: Array = w.get("history", [])
	hist.push_front([int(Time.get_unix_time_from_system()), amount, reason])
	w["history"] = hist.slice(0, 50)
	Save.mark_dirty()
	return true


static func spend(amount: int, reason: String) -> bool:
	if amount <= 0 or coins() < amount:
		return false
	var w := Save.section("wallet")
	w["coins"] = coins() - amount
	var hist: Array = w.get("history", [])
	hist.push_front([int(Time.get_unix_time_from_system()), -amount, reason])
	w["history"] = hist.slice(0, 50)
	Save.mark_dirty()
	return true
