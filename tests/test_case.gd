class_name TestCase
extends RefCounted
## Base class for test files. Every method starting with `test_` is a test.
## Failures are collected (not thrown) so one run reports every problem.

var runner: Node
var failures: Array[String] = []


func check(cond: bool, msg := "assertion failed") -> void:
	if not cond:
		failures.append(msg)


func eq(got: Variant, want: Variant, msg := "") -> void:
	if typeof(got) != typeof(want) and not (_is_num(got) and _is_num(want)):
		failures.append("%s expected %s (%s) got %s (%s)" % [msg, str(want), type_string(typeof(want)), str(got), type_string(typeof(got))])
	elif got != want:
		failures.append("%s expected %s got %s" % [msg, str(want), str(got)])


func ok(result: Dictionary, msg := "") -> void:
	if not result.get("ok", false):
		failures.append("%s action rejected: %s" % [msg, result.get("error", "?")])


func rejected(result: Dictionary, err := "", msg := "") -> void:
	if result.get("ok", false):
		failures.append("%s action unexpectedly accepted" % msg)
	elif err != "" and result.get("error", "") != err:
		failures.append("%s expected error %s got %s" % [msg, err, result.get("error", "")])


func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func frames(n: int) -> void:
	for _i in n:
		await runner.get_tree().process_frame


func wait(sec: float) -> void:
	await runner.get_tree().create_timer(sec).timeout
