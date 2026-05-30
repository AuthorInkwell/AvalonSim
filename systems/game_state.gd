extends Node

signal new_game_started
signal day_advanced(summary)
signal funds_changed

var day := 1
var funds := 25000:
	set(value):
		funds = value
		funds_changed.emit()
var daily_profit := 0
var guest_demand := 12
var last_day_summary: Dictionary = {}


func start_new_game() -> void:
	day = 1
	funds = 25000
	daily_profit = 0
	guest_demand = 12
	last_day_summary = {}
	ReputationManager.setup_new_game()
	StaffManager.setup_new_game()
	FacilityManager.setup_new_game()
	EconomyManager.setup_new_game()
	EventManager.setup_new_game()
	new_game_started.emit()


func ensure_initialized() -> void:
	if FacilityManager.facilities.is_empty() and FacilityManager.construction_queue.is_empty() and StaffManager.staff_roster.is_empty():
		start_new_game()


func advance_day() -> Dictionary:
	ensure_initialized()
	var summary := EconomyManager.process_day()
	last_day_summary = summary
	day += 1
	day_advanced.emit(summary)
	return summary


func get_state() -> Dictionary:
	return {
		"version": 1,
		"day": day,
		"funds": funds,
		"daily_profit": daily_profit,
		"guest_demand": guest_demand,
		"last_day_summary": last_day_summary.duplicate(true),
		"facility_manager": FacilityManager.get_state(),
		"staff_manager": StaffManager.get_state(),
		"reputation_manager": ReputationManager.get_state(),
		"event_manager": EventManager.get_state()
	}


func load_state(state: Dictionary) -> void:
	day = int(state.get("day", 1))
	funds = int(state.get("funds", 25000))
	daily_profit = int(state.get("daily_profit", 0))
	guest_demand = int(state.get("guest_demand", 12))
	last_day_summary = state.get("last_day_summary", {}).duplicate(true)
	ReputationManager.load_state(state.get("reputation_manager", {}))
	FacilityManager.load_state(state.get("facility_manager", {}))
	StaffManager.load_state(state.get("staff_manager", {}))
	EventManager.load_state(state.get("event_manager", {}))
	new_game_started.emit()
