extends Node

signal data_loaded

const FACILITIES_PATH := "res://data/facilities.json"
const BALANCE_TIERS_PATH := "res://data/balance_tiers.json"
const STAFF_PATH := "res://data/staff_templates.json"
const EVENTS_PATH := "res://data/events.json"
const GUEST_TYPES_PATH := "res://data/guest_types.json"

const FACILITY_TIER_FIELDS := {
	"build_cost": ["build_cost_tier", "build_cost"],
	"upkeep": ["maintenance_tier", "maintenance"],
	"capacity": ["capacity_tier", "capacity"],
	"fee": ["fee_tier", "fee"],
	"comfort": ["comfort_tier", "effect"],
	"pleasure": ["pleasure_tier", "effect"],
	"safety": ["safety_tier", "effect"],
	"power_use": ["power_use_tier", "utility"],
	"power_production": ["power_production_tier", "utility"],
	"energy_storage": ["energy_storage_tier", "utility"],
	"waste_production": ["waste_production_tier", "utility"],
	"waste_removal": ["waste_removal_tier", "utility"]
}
const LEGACY_FACILITY_ALIASES := {
	"starter_hotel": "basic_hotel",
	"cocktail_lounge": "bar",
	"spa": "massage_parlor",
	"entertainment_venue": "cabaret",
	"themed_roleplay_venue": "fantasy_resort",
	"security_office": "security_station"
}

var facilities: Array = []
var facilities_by_id: Dictionary = {}
var raw_facilities: Array = []
var balance_tiers: Dictionary = {}
var staff_templates: Array = []
var staff_templates_by_id: Dictionary = {}
var events: Array = []
var guest_types: Array = []
var is_loaded := false


func _ready() -> void:
	load_all()


func load_all() -> void:
	balance_tiers = _load_dictionary(BALANCE_TIERS_PATH)
	raw_facilities = _load_array(FACILITIES_PATH)
	facilities = []
	for raw_definition in raw_facilities:
		if typeof(raw_definition) == TYPE_DICTIONARY:
			facilities.append(_resolve_facility_definition(raw_definition))
	staff_templates = _load_array(STAFF_PATH)
	events = _load_array(EVENTS_PATH)
	guest_types = _load_array(GUEST_TYPES_PATH)
	facilities_by_id = _index_by_id(facilities)
	staff_templates_by_id = _index_by_id(staff_templates)
	is_loaded = true
	data_loaded.emit()


func get_facility(definition_id: String) -> Dictionary:
	if LEGACY_FACILITY_ALIASES.has(definition_id):
		definition_id = String(LEGACY_FACILITY_ALIASES[definition_id])
	return facilities_by_id.get(definition_id, {})


func resolve_tier(group_name: String, tier_value: Variant, fallback: float = 0.0) -> float:
	if tier_value is int or tier_value is float:
		return float(tier_value)

	var tier_name := String(tier_value).to_lower().replace("-", "_").replace("/", "_").replace(" ", "_")
	var tiers: Dictionary = balance_tiers.get("tiers", {}).get(group_name, {})
	if tiers.has(tier_name):
		return float(tiers[tier_name])

	var range_names: Array = balance_tiers.get("ranges", {}).get(tier_name, [])
	if range_names.size() == 2 and tiers.has(range_names[0]) and tiers.has(range_names[1]):
		return (float(tiers[range_names[0]]) + float(tiers[range_names[1]])) / 2.0
	return fallback


func resolve_effects(effect_tiers: Dictionary) -> Dictionary:
	var resolved := {}
	for property_data in effect_tiers:
		var property_name := String(property_data)
		if property_name == "operational":
			resolved[property_name] = effect_tiers[property_data]
			continue
		var group_name := "utility" if property_name in ["power_use", "power_production", "energy_storage", "waste_production", "waste_removal"] else "effect"
		resolved[property_name] = resolve_tier(group_name, effect_tiers[property_data])
	return resolved


func get_staff_template(template_id: String) -> Dictionary:
	return staff_templates_by_id.get(template_id, {})


func get_default_staff_templates(count: int) -> Array:
	return staff_templates.slice(0, min(count, staff_templates.size()))


func _load_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("Data file missing: %s" % path)
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Unable to open data file: %s" % path)
		return []

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Expected array JSON in %s" % path)
		return []

	return parsed


func _load_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Data file missing: %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Unable to open data file: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Expected dictionary JSON in %s" % path)
		return {}
	return parsed


func _resolve_facility_definition(raw_definition: Dictionary) -> Dictionary:
	var definition := raw_definition.duplicate(true)
	var tier_labels := {}
	for target_data in FACILITY_TIER_FIELDS:
		var target := String(target_data)
		var mapping: Array = FACILITY_TIER_FIELDS[target_data]
		var source := String(mapping[0])
		var group_name := String(mapping[1])
		if definition.has(source):
			tier_labels[target] = definition[source]
			definition[target] = resolve_tier(group_name, definition[source])

	var staffing: Dictionary = definition.get("staffing", {})
	if staffing.has("required_tier"):
		tier_labels["staff_required"] = staffing.required_tier
		definition["staff_required"] = int(round(resolve_tier("staffing", staffing.required_tier)))

	if definition.has("build_cost_tier"):
		definition["build_time"] = int(round(resolve_tier("build_time", definition.build_cost_tier, 1.0)))

	if not definition.has("base_income"):
		var fee := float(definition.get("fee", 0.0))
		var capacity := float(definition.get("capacity", 0.0))
		if String(definition.get("capacity_scope", "guest")) == "guest":
			definition["base_income"] = int(round(fee * capacity * float(balance_tiers.get("income_per_fee_capacity", 0.7))))
		else:
			definition["base_income"] = 0

	if not definition.has("footprint"):
		definition["footprint"] = _default_footprint(definition)

	definition["tier_labels"] = tier_labels
	definition["district"] = definition.get("district", String(definition.get("category", "Avalon")).capitalize())
	return definition


func _default_footprint(definition: Dictionary) -> Array:
	match String(definition.get("size", "")):
		"small":
			return [2, 2]
		"medium":
			return [3, 2]
		"large":
			return [3, 3]

	match String(definition.get("category", "")):
		"lodgings":
			return [3, 2]
		"attractions":
			return [3, 3]
		"amenities", "support":
			return [2, 2]
		"utility":
			return [2, 2]
	return [2, 2]


func _index_by_id(items: Array) -> Dictionary:
	var index := {}
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and item.has("id"):
			index[item.id] = item
	return index
