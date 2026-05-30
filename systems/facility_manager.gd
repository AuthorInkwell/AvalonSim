extends Node

signal facilities_changed
signal construction_changed

var facilities: Array = []
var construction_queue: Array = []
var next_facility_id := 1
var next_project_id := 1


func setup_new_game() -> void:
	facilities.clear()
	construction_queue.clear()
	next_facility_id = 1
	next_project_id = 1
	_add_completed_facility("starter_hotel")
	facilities_changed.emit()
	construction_changed.emit()


func queue_construction(definition_id: String) -> Dictionary:
	var definition := DataCatalog.get_facility(definition_id)
	if definition.is_empty():
		return {"success": false, "message": "Unknown facility: %s" % definition_id}

	var project := {
		"project_id": next_project_id,
		"definition_id": definition_id,
		"name": definition.get("name", definition_id),
		"days_remaining": int(definition.get("build_time", 1)),
		"total_days": int(definition.get("build_time", 1)),
		"build_cost": int(definition.get("build_cost", 0))
	}
	next_project_id += 1
	construction_queue.append(project)
	construction_changed.emit()
	return {"success": true, "project": project, "message": "Started construction: %s" % project.name}


func cancel_construction(project_id: int) -> Dictionary:
	for index in range(construction_queue.size()):
		var project: Dictionary = construction_queue[index]
		if int(project.project_id) == project_id:
			construction_queue.remove_at(index)
			construction_changed.emit()
			return {"success": true, "project": project}
	return {"success": false, "message": "Construction project not found."}


func progress_construction() -> Array:
	var completed := []
	for index in range(construction_queue.size() - 1, -1, -1):
		var project: Dictionary = construction_queue[index]
		project.days_remaining = int(project.days_remaining) - 1
		if int(project.days_remaining) <= 0:
			var facility := _add_completed_facility(String(project.definition_id))
			completed.append(facility)
			construction_queue.remove_at(index)

	if not completed.is_empty():
		facilities_changed.emit()
	construction_changed.emit()
	return completed


func calculate_daily_operations(guest_demand: int) -> Dictionary:
	var reports := []
	var total_capacity := get_total_capacity()
	var occupancy := 0.0
	if total_capacity > 0:
		occupancy = clamp(float(guest_demand) / float(total_capacity), 0.15, 1.0)

	var revenue := 0
	var upkeep := 0
	var served_guests := 0
	var satisfaction_total := 0.0
	var active_facilities := 0
	var understaffed_facilities := 0

	for facility in facilities:
		var definition := DataCatalog.get_facility(String(facility.definition_id))
		var required_staff := int(facility.get("staff_required", definition.get("staff_required", 0)))
		var assigned_staff := StaffManager.get_staff_for_facility(int(facility.id))
		var staff_ratio := 1.0
		if required_staff > 0:
			staff_ratio = clamp(float(assigned_staff.size()) / float(required_staff), 0.0, 1.0)

		if required_staff > 0 and assigned_staff.size() < required_staff:
			understaffed_facilities += 1

		var avg_efficiency := StaffManager.average_stat(assigned_staff, "efficiency", 0.55)
		var avg_charisma := StaffManager.average_stat(assigned_staff, "charisma", 0.5)
		var level := int(facility.get("level", 1))
		var level_modifier := 1.0 + float(level - 1) * 0.25
		var staff_modifier := 0.45 + staff_ratio * 0.4 + avg_efficiency * 0.25
		var charisma_modifier := 0.9 + avg_charisma * 0.2
		var base_income := float(facility.get("base_income", definition.get("base_income", 0)))
		var income := int(round(base_income * occupancy * level_modifier * staff_modifier * charisma_modifier))
		var facility_upkeep := int(facility.get("upkeep", definition.get("upkeep", 0)))
		var facility_capacity := int(facility.get("capacity", definition.get("capacity", 0)))
		var facility_served := int(round(float(facility_capacity) * occupancy))
		var satisfaction := clamp(0.52 + staff_ratio * 0.24 + avg_efficiency * 0.16 + avg_charisma * 0.08, 0.0, 1.0)

		revenue += income
		upkeep += facility_upkeep
		served_guests += facility_served
		satisfaction_total += satisfaction
		active_facilities += 1

		reports.append({
			"facility_id": int(facility.id),
			"name": facility.name,
			"income": income,
			"upkeep": facility_upkeep,
			"assigned_staff": assigned_staff.size(),
			"required_staff": required_staff,
			"satisfaction": satisfaction,
			"served_guests": facility_served
		})

	var average_satisfaction := 0.0
	if active_facilities > 0:
		average_satisfaction = satisfaction_total / float(active_facilities)

	return {
		"reports": reports,
		"revenue": revenue,
		"upkeep": upkeep,
		"served_guests": served_guests,
		"guest_demand": guest_demand,
		"total_capacity": total_capacity,
		"satisfaction": average_satisfaction,
		"understaffed_facilities": understaffed_facilities
	}


func get_total_capacity() -> int:
	var total := 0
	for facility in facilities:
		total += int(facility.get("capacity", 0))
	return total


func get_facility_by_id(facility_id: int) -> Dictionary:
	for facility in facilities:
		if int(facility.id) == facility_id:
			return facility
	return {}


func get_state() -> Dictionary:
	return {
		"facilities": facilities.duplicate(true),
		"construction_queue": construction_queue.duplicate(true),
		"next_facility_id": next_facility_id,
		"next_project_id": next_project_id
	}


func load_state(state: Dictionary) -> void:
	facilities = state.get("facilities", []).duplicate(true)
	construction_queue = state.get("construction_queue", []).duplicate(true)
	next_facility_id = int(state.get("next_facility_id", 1))
	next_project_id = int(state.get("next_project_id", 1))
	facilities_changed.emit()
	construction_changed.emit()


func _add_completed_facility(definition_id: String) -> Dictionary:
	var definition := DataCatalog.get_facility(definition_id)
	var facility := {
		"id": next_facility_id,
		"definition_id": definition_id,
		"name": definition.get("name", definition_id),
		"district": definition.get("district", "Avalon"),
		"description": definition.get("description", ""),
		"level": 1,
		"upkeep": int(definition.get("upkeep", 0)),
		"capacity": int(definition.get("capacity", 0)),
		"staff_required": int(definition.get("staff_required", 0)),
		"base_income": int(definition.get("base_income", 0)),
		"reputation_focus": definition.get("reputation_focus", [])
	}
	next_facility_id += 1
	facilities.append(facility)
	return facility
