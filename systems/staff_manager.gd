extends Node

signal staff_changed

const FALLBACK_GIVEN_NAMES := ["Ari", "Briar", "Cass", "Dara", "Eli", "Jules", "Kai", "Lina", "Milo", "Noor", "Opal", "Pax", "Rhea", "Sera", "Tavi", "Vera"]
const FALLBACK_FAMILY_NAMES := ["Ash", "Bloom", "Crown", "Dawn", "Finch", "Hart", "Lux", "Maris", "Pike", "Quill", "Rivers", "Sable", "Vale", "Ward", "Wren", "Zephyr"]

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

	var template_name := String(template.get("template_name", template.get("name", "Staff Candidate")))
	var staff: Dictionary = {
		"id": next_staff_id,
		"template_id": template.get("id", ""),
		"template_name": template_name,
		"name": _generate_unique_name(template),
		"category": template.get("category", "Staff"),
		"house": template.get("house", ""),
		"role": template.get("role", "Generalist"),
		"specialty": template.get("specialty", "Operations"),
		"description": template.get("description", ""),
		"salary": int(template.get("salary", 200)),
		"efficiency": float(template.get("efficiency", 0.65)),
		"charisma": float(template.get("charisma", 0.65)),
		"reliability": float(template.get("reliability", 0.65)),
		"stress": float(template.get("stress", 0.1)),
		"satisfaction": float(template.get("satisfaction", 0.65)),
		"affinity_tags": template.get("affinity_tags", []),
		"contribution": template.get("contribution", {}),
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


func calculate_facility_contribution(staff_members: Array, facility: Dictionary) -> Dictionary:
	var revenue_modifier := 0.0
	var satisfaction_bonus := 0.0
	var upkeep_reduction := 0.0
	var capacity_modifier := 0.0
	var effect_lines: Array = []

	for staff_data in staff_members:
		var staff: Dictionary = staff_data
		_hydrate_staff_from_template(staff)

		var contribution: Dictionary = staff.get("contribution", {})
		var affinity := _calculate_facility_affinity(staff, facility)
		var revenue_delta := float(contribution.get("revenue", 0.0)) * affinity
		var satisfaction_delta := float(contribution.get("satisfaction", 0.0)) * affinity
		var upkeep_delta := float(contribution.get("upkeep_reduction", 0.0)) * affinity
		var capacity_delta := float(contribution.get("capacity", 0.0)) * affinity

		revenue_modifier += revenue_delta
		satisfaction_bonus += satisfaction_delta
		upkeep_reduction += upkeep_delta
		capacity_modifier += capacity_delta

		var effects: Array = []
		if absf(revenue_delta) >= 0.005:
			effects.append("+%d%% revenue" % int(round(revenue_delta * 100.0)))
		if absf(satisfaction_delta) >= 0.005:
			effects.append("+%d%% satisfaction" % int(round(satisfaction_delta * 100.0)))
		if absf(upkeep_delta) >= 0.005:
			effects.append("-%d%% upkeep" % int(round(upkeep_delta * 100.0)))
		if absf(capacity_delta) >= 0.005:
			effects.append("+%d%% guest flow" % int(round(capacity_delta * 100.0)))

		if not effects.is_empty():
			effect_lines.append("%s (%s): %s" % [
				staff.name,
				get_staff_role_label(staff),
				", ".join(effects)
			])

	return {
		"revenue_modifier": clamp(revenue_modifier, -0.25, 0.45),
		"satisfaction_bonus": clamp(satisfaction_bonus, -0.25, 0.35),
		"upkeep_reduction": clamp(upkeep_reduction, 0.0, 0.4),
		"capacity_modifier": clamp(capacity_modifier, -0.2, 0.25),
		"effect_lines": effect_lines
	}


func get_staff_role_label(staff: Dictionary) -> String:
	_hydrate_staff_from_template(staff)
	var house := String(staff.get("house", ""))
	var role := String(staff.get("role", "Staff"))
	if house.is_empty() or house == role:
		return role
	return "%s %s" % [house, role]


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
	for staff in staff_roster:
		var staff_data: Dictionary = staff
		_hydrate_staff_from_template(staff_data)
	staff_changed.emit()


func _generate_unique_name(template: Dictionary) -> String:
	var preferred_names: Array = template.get("name_pool", [])
	for candidate_data in preferred_names:
		var candidate := String(candidate_data)
		if not _is_name_in_use(candidate):
			return candidate

	for attempt in range(FALLBACK_GIVEN_NAMES.size() * FALLBACK_FAMILY_NAMES.size()):
		var given_name := String(FALLBACK_GIVEN_NAMES[(next_staff_id + attempt) % FALLBACK_GIVEN_NAMES.size()])
		var family_name := String(FALLBACK_FAMILY_NAMES[(next_staff_id * 3 + attempt) % FALLBACK_FAMILY_NAMES.size()])
		var candidate := "%s %s" % [given_name, family_name]
		if not _is_name_in_use(candidate):
			return candidate

	return "%s %03d" % [String(template.get("template_name", "Staff")), next_staff_id]


func _is_name_in_use(candidate: String) -> bool:
	for staff in staff_roster:
		if String(staff.get("name", "")) == candidate:
			return true
	return false


func _calculate_facility_affinity(staff: Dictionary, facility: Dictionary) -> float:
	var affinity_tags: Array = staff.get("affinity_tags", [])
	var facility_tags: Array = facility.get("reputation_focus", [])
	if affinity_tags.is_empty() or facility_tags.is_empty():
		return 1.0

	var matches := 0
	for tag_data in facility_tags:
		if affinity_tags.has(String(tag_data)):
			matches += 1

	if matches == 0:
		return 0.65
	return 1.0 + minf(float(matches) * 0.2, 0.5)


func _hydrate_staff_from_template(staff: Dictionary) -> void:
	var template := DataCatalog.get_staff_template(String(staff.get("template_id", "")))
	if template.is_empty():
		return

	for key in ["template_name", "category", "house", "role", "specialty", "description", "affinity_tags", "contribution", "traits"]:
		if not staff.has(key):
			staff[key] = template.get(key, staff.get(key, ""))
