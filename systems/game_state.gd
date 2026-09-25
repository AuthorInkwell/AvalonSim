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
	MapManager.setup_new_game()
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
		"version": 3,
		"day": day,
		"funds": funds,
		"daily_profit": daily_profit,
		"guest_demand": guest_demand,
		"last_day_summary": last_day_summary.duplicate(true),
		"map_manager": MapManager.get_state(),
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
	MapManager.load_state(state.get("map_manager", {}))
	StaffManager.load_state(state.get("staff_manager", {}))
	EventManager.load_state(state.get("event_manager", {}))
	new_game_started.emit()


func get_guest_satisfaction() -> float:
	if not last_day_summary.is_empty():
		return float(last_day_summary.get("operations", {}).get("satisfaction", 0.0))
	return float(FacilityManager.calculate_daily_operations(guest_demand).get("satisfaction", 0.0))


func get_category_demand() -> Dictionary:
	var demand: int = maxi(1, guest_demand)
	var capacities := {
		"lodgings": 0,
		"attractions": 0,
		"amenities": 0
	}
	var support_count := 0
	for facility in FacilityManager.facilities:
		var category := String(facility.get("category", ""))
		if capacities.has(category) and String(facility.get("capacity_scope", "guest")) == "guest":
			capacities[category] += int(facility.get("capacity", 0))
		elif category == "support":
			support_count += 1

	var operations := FacilityManager.calculate_daily_operations(demand)
	var utilities: Dictionary = operations.get("utility_totals", {})
	var power_gap := maxi(0, int(utilities.get("power_use", 0)) - int(utilities.get("power_production", 0)))
	var waste_gap := maxi(0, int(utilities.get("waste_production", 0)) - int(utilities.get("waste_removal", 0)))
	var utility_pressure: int = 15
	if power_gap > 0 or waste_gap > 0:
		utility_pressure = mini(100, 45 + (power_gap + waste_gap) * 4)
	elif int(utilities.get("power_production", 0)) == 0:
		utility_pressure = 55

	return {
		"lodgings": _shortage_percent(int(capacities.lodgings), demand),
		"attractions": _shortage_percent(int(capacities.attractions), maxi(1, int(ceil(float(demand) * 0.7)))),
		"amenities": _shortage_percent(int(capacities.amenities), maxi(1, int(ceil(float(demand) * 0.5)))),
		"utility": utility_pressure,
		"support": clampi(70 - support_count * 25 + int(FacilityManager.calculate_daily_operations(demand).get("understaffed_facilities", 0)) * 8, 5, 100),
		"research_and_development": 0
	}


func _shortage_percent(supply: int, target: int) -> int:
	if target <= 0:
		return 0
	return clampi(int(round(maxf(0.0, float(target - supply)) / float(target) * 100.0)), 0, 100)
