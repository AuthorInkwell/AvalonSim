extends Node

signal event_triggered(event_result)

var event_log: Array = []
var daily_event_chance := 0.25


func setup_new_game() -> void:
	randomize()
	event_log.clear()


func roll_daily_event(operations: Dictionary, guest_demand: int) -> Dictionary:
	var result := {
		"triggered": false,
		"title": "",
		"description": "",
		"revenue_delta": 0,
		"expense_delta": 0,
		"reputation": {},
		"staff_stress_delta": 0.0
	}

	var chance := daily_event_chance
	if operations.get("understaffed_facilities", 0) > 0:
		chance += 0.08
	if guest_demand > operations.get("total_capacity", 0) and operations.get("total_capacity", 0) > 0:
		chance += 0.05

	if randf() > chance or DataCatalog.events.is_empty():
		return result

	var event: Dictionary = _pick_weighted_event(DataCatalog.events)
	var effects: Dictionary = event.get("effects", {})
	result.triggered = true
	result.title = event.get("title", "Avalon Incident")
	result.description = event.get("description", "")
	result.revenue_delta = int(effects.get("revenue_delta", 0))
	result.expense_delta = int(effects.get("expense_delta", 0))
	result.reputation = effects.get("reputation", {})
	result.staff_stress_delta = float(effects.get("staff_stress_delta", 0.0))

	event_log.push_front({
		"day": GameState.day,
		"title": result.title,
		"description": result.description
	})
	if event_log.size() > 20:
		event_log.resize(20)

	event_triggered.emit(result)
	return result


func get_state() -> Dictionary:
	return {
		"event_log": event_log.duplicate(true)
	}


func load_state(state: Dictionary) -> void:
	event_log = state.get("event_log", []).duplicate(true)


func _pick_weighted_event(available_events: Array) -> Dictionary:
	var total_weight := 0
	for event in available_events:
		total_weight += int(event.get("weight", 1))

	var roll := randi_range(1, max(total_weight, 1))
	var running_total := 0
	for event in available_events:
		running_total += int(event.get("weight", 1))
		if roll <= running_total:
			return event

	return available_events[0]
