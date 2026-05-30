extends Node

signal reputation_changed

const DEFAULT_REPUTATION := {
	"luxury": 50,
	"safety": 50,
	"secrecy": 50,
	"innovation": 45,
	"decadence": 45,
	"hospitality": 55
}

var scores: Dictionary = {}


func setup_new_game() -> void:
	scores = DEFAULT_REPUTATION.duplicate(true)
	reputation_changed.emit()


func calculate_guest_demand(day: int) -> int:
	var hospitality := float(scores.get("hospitality", 50))
	var luxury := float(scores.get("luxury", 50))
	var safety := float(scores.get("safety", 50))
	var decadence := float(scores.get("decadence", 45))
	var reputation_factor := (hospitality + luxury + safety + decadence) / 200.0
	var growth := min(day - 1, 30) * 0.35
	return max(4, int(round(8.0 + growth + reputation_factor * 8.0)))


func apply_daily_results(operations: Dictionary, event_result: Dictionary, construction_completed: Array) -> Dictionary:
	var changes := {}
	var satisfaction := float(operations.get("satisfaction", 0.75))
	var unstaffed := int(operations.get("understaffed_facilities", 0))

	_add_change(changes, "hospitality", int(round((satisfaction - 0.72) * 8.0)))
	_add_change(changes, "luxury", 1 if operations.get("served_guests", 0) > 0 and satisfaction >= 0.82 else 0)
	_add_change(changes, "safety", -unstaffed)

	for facility in construction_completed:
		for focus in facility.get("reputation_focus", []):
			_add_change(changes, String(focus), 1)

	var event_reputation: Dictionary = event_result.get("reputation", {})
	for key in event_reputation:
		_add_change(changes, String(key), int(event_reputation[key]))

	for key in changes:
		scores[key] = clamp(int(scores.get(key, 50)) + int(changes[key]), 0, 100)

	reputation_changed.emit()
	return changes


func apply_direct_changes(changes: Dictionary) -> void:
	for key in changes:
		scores[String(key)] = clamp(int(scores.get(String(key), 50)) + int(changes[key]), 0, 100)
	reputation_changed.emit()


func get_average() -> float:
	if scores.is_empty():
		return 0.0

	var total := 0.0
	for key in scores:
		total += float(scores[key])
	return total / float(scores.size())


func get_display_lines() -> Array:
	var lines := []
	for key in scores.keys():
		lines.append("%s: %d" % [_titleize(String(key)), int(scores[key])])
	return lines


func get_state() -> Dictionary:
	return {
		"scores": scores.duplicate(true)
	}


func load_state(state: Dictionary) -> void:
	scores = state.get("scores", DEFAULT_REPUTATION).duplicate(true)
	reputation_changed.emit()


func _add_change(changes: Dictionary, key: String, amount: int) -> void:
	if amount == 0:
		return
	changes[key] = int(changes.get(key, 0)) + amount


func _titleize(value: String) -> String:
	return value.replace("_", " ").capitalize()
