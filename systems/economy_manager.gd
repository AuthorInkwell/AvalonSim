extends Node

signal transaction_completed(message)

const ROAD_COST := 25


func setup_new_game() -> void:
	pass


func process_day() -> Dictionary:
	var guest_demand := ReputationManager.calculate_guest_demand(GameState.day)
	GameState.guest_demand = guest_demand

	var construction_completed := FacilityManager.progress_construction()
	var operations := FacilityManager.calculate_daily_operations(guest_demand)
	var payroll := StaffManager.calculate_daily_payroll()
	var event_result := EventManager.roll_daily_event(operations, guest_demand)
	var reputation_changes := ReputationManager.apply_daily_results(operations, event_result, construction_completed)

	StaffManager.update_after_day(operations, event_result)

	var revenue := int(operations.get("revenue", 0)) + int(event_result.get("revenue_delta", 0))
	var expenses := int(operations.get("upkeep", 0)) + payroll + int(event_result.get("expense_delta", 0))
	var profit := revenue - expenses
	GameState.funds += profit
	GameState.daily_profit = profit

	return {
		"day": GameState.day,
		"guest_demand": guest_demand,
		"served_guests": int(operations.get("served_guests", 0)),
		"revenue": revenue,
		"expenses": expenses,
		"profit": profit,
		"funds": GameState.funds,
		"payroll": payroll,
		"upkeep": int(operations.get("upkeep", 0)),
		"operations": operations,
		"event": event_result,
		"reputation_changes": reputation_changes,
		"construction_completed": construction_completed
	}


func build_facility(definition_id: String) -> Dictionary:
	var definition := DataCatalog.get_facility(definition_id)
	if definition.is_empty():
		return {"success": false, "message": "Unknown facility."}
	if not bool(definition.get("buildable", true)) or not definition.has("build_cost"):
		return {"success": false, "message": "%s is defined, but its construction values are not specified yet." % definition.get("name", definition_id)}

	var build_cost := int(definition.get("build_cost", 0))
	if GameState.funds < build_cost:
		return {"success": false, "message": "Insufficient funds to build %s." % definition.get("name", definition_id)}

	GameState.funds -= build_cost
	var result := FacilityManager.queue_construction(definition_id)
	if not result.get("success", false):
		GameState.funds += build_cost
		return result

	transaction_completed.emit(result.message)
	return result


func place_facility(definition_id: String, origin: Vector2i, orientation: int = 0) -> Dictionary:
	var placement_check := MapManager.can_place_facility(definition_id, origin, orientation)
	if not placement_check.get("success", false):
		return placement_check

	var result := build_facility(definition_id)
	if not result.get("success", false):
		return result

	var project: Dictionary = result.project
	var reservation := MapManager.reserve_construction(project, origin, orientation)
	if not reservation.get("success", false):
		FacilityManager.cancel_construction(int(project.project_id))
		GameState.funds += int(project.get("build_cost", 0))
		return reservation
	result["message"] = "%s placed at %d, %d%s" % [
		project.name,
		origin.x,
		origin.y,
		" (no road access)" if not reservation.get("road_access", false) else ""
	]
	transaction_completed.emit(result.message)
	return result


func place_road(cell: Vector2i) -> Dictionary:
	var check := MapManager.can_place_road(cell)
	if not check.get("success", false):
		return check
	if GameState.funds < ROAD_COST:
		return {"success": false, "message": "Insufficient funds for a road tile (%d cr)." % ROAD_COST}
	var result := MapManager.place_road(cell)
	if result.get("success", false):
		GameState.funds -= ROAD_COST
		result["message"] = "Road placed for %d cr." % ROAD_COST
		transaction_completed.emit(result.message)
	return result


func hire_staff(template_id: String) -> Dictionary:
	var template := DataCatalog.get_staff_template(template_id)
	if template.is_empty():
		return {"success": false, "message": "Unknown staff template."}

	var hire_cost := int(template.get("hire_cost", 0))
	if GameState.funds < hire_cost:
		return {"success": false, "message": "Insufficient funds to hire %s." % template.get("name", template_id)}

	GameState.funds -= hire_cost
	var result := StaffManager.hire_from_template(template)
	if not result.get("success", false):
		GameState.funds += hire_cost
		return result

	transaction_completed.emit(result.message)
	return result


func fire_staff(staff_id: int) -> Dictionary:
	var result := StaffManager.fire_staff(staff_id)
	if result.get("success", false):
		transaction_completed.emit(result.message)
	return result


func assign_staff(staff_id: int, facility_id: int) -> Dictionary:
	var result := StaffManager.assign_staff(staff_id, facility_id)
	if result.get("success", false):
		transaction_completed.emit(result.message)
	return result


func set_facility_work_mode(facility_id: int, mode_id: String) -> Dictionary:
	var result := FacilityManager.set_work_mode(facility_id, mode_id)
	if result.get("success", false):
		transaction_completed.emit(result.message)
	return result
