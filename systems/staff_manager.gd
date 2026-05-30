extends Node

signal staff_changed

var staff_roster: Array = []
var next_staff_id := 1


func setup_new_game() -> void:
	staff_roster.clear()
	next_staff_id = 1
	for template in DataCatalog.get_default_staff_templates(3):
		hire_from_template(template)
	staff_changed.emit()


func hire_from_template(template: Dictionary) -> Dictionary:
	if template.is_empty():
		return {"success": false, "message": "Unknown staff template."}

	var staff: Dictionary = {
		"id": next_staff_id,
		"template_id": template.get("id", ""),
		"name": template.get("name", "New Hire"),
		"category": template.get("category", "Staff"),
		"role": template.get("role", "Generalist"),
		"specialty": template.get("specialty", "Operations"),
		"salary": int(template.get("salary", 200)),
		"efficiency": float(template.get("efficiency", 0.65)),
		"charisma": float(template.get("charisma", 0.65)),
		"reliability": float(template.get("reliability", 0.65)),
		"stress": float(template.get("stress", 0.1)),
		"satisfaction": float(template.get("satisfaction", 0.65)),
		"traits": template.get("traits", []),
		"assigned_facility_id": -1
	}
	next_staff_id += 1
	staff_roster.append(staff)
	staff_changed.emit()
	return {"success": true, "staff": staff, "message": "Hired %s." % staff.name}


func fire_staff(staff_id: int) -> Dictionary:
	for index in range(staff_roster.size()):
		var staff: Dictionary = staff_roster[index]
		if int(staff.id) == staff_id:
			staff_roster.remove_at(index)
			staff_changed.emit()
			return {"success": true, "message": "Released %s from the roster." % staff.name}
	return {"success": false, "message": "Staff member not found."}


func assign_staff(staff_id: int, facility_id: int) -> Dictionary:
	var staff: Dictionary = get_staff_by_id(staff_id)
	if staff.is_empty():
		return {"success": false, "message": "Staff member not found."}

	if facility_id != -1 and FacilityManager.get_facility_by_id(facility_id).is_empty():
		return {"success": false, "message": "Facility not found."}

	staff.assigned_facility_id = facility_id
	staff_changed.emit()
	if facility_id == -1:
		return {"success": true, "message": "%s is now unassigned." % staff.name}

	var facility: Dictionary = FacilityManager.get_facility_by_id(facility_id)
	return {"success": true, "message": "%s assigned to %s." % [staff.name, facility.name]}


func get_staff_by_id(staff_id: int) -> Dictionary:
	for staff in staff_roster:
		if int(staff.id) == staff_id:
			return staff
	return {}


func get_staff_for_facility(facility_id: int) -> Array:
	var assigned := []
	for staff in staff_roster:
		if int(staff.get("assigned_facility_id", -1)) == facility_id:
			assigned.append(staff)
	return assigned


func get_unassigned_staff() -> Array:
	var unassigned := []
	for staff in staff_roster:
		if int(staff.get("assigned_facility_id", -1)) == -1:
			unassigned.append(staff)
	return unassigned


func average_stat(staff_members: Array, stat_name: String, fallback: float) -> float:
	if staff_members.is_empty():
		return fallback

	var total := 0.0
	for staff in staff_members:
		total += float(staff.get(stat_name, fallback))
	return total / float(staff_members.size())


func calculate_daily_payroll() -> int:
	var payroll := 0
	for staff in staff_roster:
		payroll += int(staff.get("salary", 0))
	return payroll


func update_after_day(operations: Dictionary, event_result: Dictionary = {}) -> void:
	var understaffed_ids := {}
	for report in operations.get("reports", []):
		if int(report.assigned_staff) < int(report.required_staff):
			understaffed_ids[int(report.facility_id)] = true

	var event_stress_delta := float(event_result.get("staff_stress_delta", 0.0))
	for staff in staff_roster:
		var assigned_facility_id := int(staff.get("assigned_facility_id", -1))
		var stress_delta := 0.015 + event_stress_delta
		var satisfaction_delta := 0.01

		if assigned_facility_id == -1:
			stress_delta = -0.035 + event_stress_delta
			satisfaction_delta = -0.005
		elif understaffed_ids.has(assigned_facility_id):
			stress_delta += 0.035
			satisfaction_delta = -0.02

		staff.stress = clamp(float(staff.get("stress", 0.0)) + stress_delta, 0.0, 1.0)
		staff.satisfaction = clamp(float(staff.get("satisfaction", 0.65)) + satisfaction_delta - float(staff.stress) * 0.01, 0.0, 1.0)

	staff_changed.emit()


func get_state() -> Dictionary:
	return {
		"staff_roster": staff_roster.duplicate(true),
		"next_staff_id": next_staff_id
	}


func load_state(state: Dictionary) -> void:
	staff_roster = state.get("staff_roster", []).duplicate(true)
	next_staff_id = int(state.get("next_staff_id", 1))
	staff_changed.emit()
