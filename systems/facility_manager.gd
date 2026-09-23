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
	_add_completed_facility("basic_hotel")
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
	var utility_totals := {
		"power_use": 0,
		"power_production": 0,
		"energy_storage": 0,
		"waste_production": 0,
		"waste_removal": 0
	}

	for facility in facilities:
		var definition := DataCatalog.get_facility(String(facility.definition_id))
		var assigned_staff := StaffManager.get_staff_for_facility(int(facility.id))
		var profile := _get_effective_profile(facility, definition, assigned_staff)
		var required_staff := int(facility.get("staff_required", definition.get("staff_required", 0)))
		var qualified_staff := _get_qualified_staff(assigned_staff, definition.get("staffing", {}))
		var staff_ratio := 1.0
		if required_staff > 0:
			staff_ratio = clamp(float(qualified_staff.size()) / float(required_staff), 0.0, 1.0)

		if required_staff > 0 and qualified_staff.size() < required_staff:
			understaffed_facilities += 1

		var avg_efficiency := StaffManager.average_stat(assigned_staff, "efficiency", 0.55)
		var avg_charisma := StaffManager.average_stat(assigned_staff, "charisma", 0.5)
		var role_contribution: Dictionary = StaffManager.calculate_facility_contribution(assigned_staff, facility)
		var level := int(facility.get("level", 1))
		var level_modifier := 1.0 + float(level - 1) * 0.25
		var staff_modifier := 0.45 + staff_ratio * 0.35 + avg_efficiency * 0.2 + float(role_contribution.revenue_modifier)
		var charisma_modifier := 0.9 + avg_charisma * 0.15
		var base_income := float(facility.get("base_income", definition.get("base_income", 0)))
		var experience_modifier := 1.0 + float(profile.get("pleasure", 0.0)) * 0.08
		var income := int(round(base_income * occupancy * level_modifier * staff_modifier * charisma_modifier * experience_modifier))
		var base_upkeep := int(facility.get("upkeep", definition.get("upkeep", 0)))
		var facility_upkeep := int(round(float(base_upkeep) * (1.0 - float(role_contribution.upkeep_reduction))))
		var facility_capacity := 0
		if String(facility.get("capacity_scope", definition.get("capacity_scope", "guest"))) == "guest":
			facility_capacity = int(facility.get("capacity", definition.get("capacity", 0)))
		var effective_capacity := int(round(float(facility_capacity) * (1.0 + float(role_contribution.capacity_modifier))))
		var facility_served := int(round(float(effective_capacity) * occupancy))
		var experience_satisfaction := (float(profile.get("comfort", 0.0)) + float(profile.get("pleasure", 0.0)) + float(profile.get("safety", 0.0))) * 0.05
		var satisfaction: float = clamp(0.52 + staff_ratio * 0.22 + avg_efficiency * 0.14 + avg_charisma * 0.07 + experience_satisfaction + float(role_contribution.satisfaction_bonus), 0.0, 1.0)

		revenue += income
		upkeep += facility_upkeep
		served_guests += facility_served
		satisfaction_total += satisfaction
		active_facilities += 1
		for utility_name in utility_totals:
			utility_totals[utility_name] += int(round(float(profile.get(utility_name, 0))))

		reports.append({
			"facility_id": int(facility.id),
			"name": facility.name,
			"income": income,
			"upkeep": facility_upkeep,
			"assigned_staff": assigned_staff.size(),
			"required_staff": required_staff,
			"qualified_staff": qualified_staff.size(),
			"satisfaction": satisfaction,
			"served_guests": facility_served,
			"effective_capacity": effective_capacity,
			"role_effects": role_contribution.effect_lines,
			"effective_attributes": profile,
			"special_effects": profile.get("special_effects", [])
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
		"understaffed_facilities": understaffed_facilities,
		"utility_totals": utility_totals
	}


func get_total_capacity() -> int:
	var total := 0
	for facility in facilities:
		if String(facility.get("capacity_scope", "guest")) == "guest":
			total += int(facility.get("capacity", 0))
	return total


func set_work_mode(facility_id: int, mode_id: String) -> Dictionary:
	var facility := get_facility_by_id(facility_id)
	if facility.is_empty():
		return {"success": false, "message": "Facility not found."}

	var definition := DataCatalog.get_facility(String(facility.definition_id))
	for mode_data in definition.get("work_modes", []):
		var mode: Dictionary = mode_data
		if String(mode.get("id", "")) == mode_id:
			facility["work_mode"] = mode_id
			facilities_changed.emit()
			return {"success": true, "message": "%s set to %s." % [facility.name, mode.get("name", mode_id)]}
	return {"success": false, "message": "Work mode is not available for this facility."}


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
	for facility_data in facilities:
		var facility: Dictionary = facility_data
		_hydrate_facility(facility)
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
		"category": definition.get("category", "uncategorized"),
		"level": 1,
		"upkeep": int(definition.get("upkeep", 0)),
		"capacity": int(definition.get("capacity", 0)),
		"capacity_scope": definition.get("capacity_scope", "guest"),
		"staff_required": int(definition.get("staff_required", 0)),
		"base_income": int(definition.get("base_income", 0)),
		"reputation_focus": definition.get("reputation_focus", []),
		"work_mode": definition.get("default_work_mode", "")
	}
	next_facility_id += 1
	facilities.append(facility)
	return facility


func _hydrate_facility(facility: Dictionary) -> void:
	var definition := DataCatalog.get_facility(String(facility.get("definition_id", "")))
	if definition.is_empty():
		return
	for key in ["category", "capacity_scope", "reputation_focus"]:
		if not facility.has(key):
			facility[key] = definition.get(key)
	if not facility.has("work_mode"):
		facility["work_mode"] = definition.get("default_work_mode", "")


func _get_effective_profile(facility: Dictionary, definition: Dictionary, assigned_staff: Array) -> Dictionary:
	var profile := {}
	for property_name in ["comfort", "pleasure", "safety", "power_use", "power_production", "energy_storage", "waste_production", "waste_removal"]:
		if definition.has(property_name):
			profile[property_name] = definition[property_name]

	var special_effects: Array = []
	var mode := _get_selected_work_mode(facility, definition)
	if not mode.is_empty():
		var mode_active := _staff_matches_preferences(assigned_staff, mode)
		if mode_active:
			_merge_profile(profile, DataCatalog.resolve_effects(mode.get("effects", {})), 1.0)
		special_effects.append("%s: %s" % [
			mode.get("name", "Work mode"),
			"active" if mode_active else "awaiting preferred staff"
		])

	for modifier_data in definition.get("modifiers", []):
		var modifier: Dictionary = modifier_data
		var is_implemented := bool(modifier.get("implemented", true))
		var active := is_implemented and _condition_is_met(modifier.get("condition", {}), assigned_staff)
		if active:
			_merge_profile(profile, DataCatalog.resolve_effects(modifier.get("effects", {})), 1.0)
			_merge_profile(profile, DataCatalog.resolve_effects(modifier.get("penalties", {})), -1.0)
			special_effects.append("%s: active" % modifier.get("label", modifier.get("id", "Modifier")))
		elif not is_implemented:
			special_effects.append("%s: data hook (pending related system)" % modifier.get("label", modifier.get("id", "Modifier")))

	profile["special_effects"] = special_effects
	return profile


func _get_selected_work_mode(facility: Dictionary, definition: Dictionary) -> Dictionary:
	var selected_id := String(facility.get("work_mode", definition.get("default_work_mode", "")))
	for mode_data in definition.get("work_modes", []):
		var mode: Dictionary = mode_data
		if String(mode.get("id", "")) == selected_id:
			return mode
	return {}


func _merge_profile(profile: Dictionary, changes: Dictionary, direction: float) -> void:
	for property_data in changes:
		var property_name := String(property_data)
		if changes[property_data] is bool:
			profile[property_name] = changes[property_data]
		else:
			profile[property_name] = float(profile.get(property_name, 0.0)) + float(changes[property_data]) * direction


func _condition_is_met(condition: Dictionary, assigned_staff: Array) -> bool:
	var condition_type := String(condition.get("type", "always"))
	if condition_type == "always":
		return true
	if condition_type == "staff_category":
		return _staff_has_value(assigned_staff, "category", String(condition.get("value", "")))
	if condition_type == "staff_house":
		return _staff_has_value(assigned_staff, "house", String(condition.get("value", "")))
	return false


func _staff_matches_preferences(assigned_staff: Array, source: Dictionary) -> bool:
	var preferred_categories: Array = source.get("preferred_categories", [])
	var preferred_houses: Array = source.get("preferred_houses", [])
	if preferred_categories.is_empty() and preferred_houses.is_empty():
		return true
	for staff_data in assigned_staff:
		var staff: Dictionary = staff_data
		if preferred_categories.has(String(staff.get("category", ""))) or preferred_houses.has(String(staff.get("house", ""))):
			return true
	return false


func _get_qualified_staff(assigned_staff: Array, staffing: Dictionary) -> Array:
	var qualified := []
	var required_categories: Array = staffing.get("required_categories", [])
	var required_houses: Array = staffing.get("required_houses", [])
	for staff_data in assigned_staff:
		var staff: Dictionary = staff_data
		if required_categories.is_empty() and required_houses.is_empty():
			qualified.append(staff)
		elif required_categories.has(String(staff.get("category", ""))) or required_houses.has(String(staff.get("house", ""))):
			qualified.append(staff)
	return qualified


func _staff_has_value(assigned_staff: Array, key: String, value: String) -> bool:
	for staff_data in assigned_staff:
		var staff: Dictionary = staff_data
		if String(staff.get(key, "")) == value:
			return true
	return false
