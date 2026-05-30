extends Node

signal data_loaded

const FACILITIES_PATH := "res://data/facilities.json"
const STAFF_PATH := "res://data/staff_templates.json"
const EVENTS_PATH := "res://data/events.json"
const GUEST_TYPES_PATH := "res://data/guest_types.json"

var facilities: Array = []
var facilities_by_id: Dictionary = {}
var staff_templates: Array = []
var staff_templates_by_id: Dictionary = {}
var events: Array = []
var guest_types: Array = []
var is_loaded := false


func _ready() -> void:
	load_all()


func load_all() -> void:
	facilities = _load_array(FACILITIES_PATH)
	staff_templates = _load_array(STAFF_PATH)
	events = _load_array(EVENTS_PATH)
	guest_types = _load_array(GUEST_TYPES_PATH)
	facilities_by_id = _index_by_id(facilities)
	staff_templates_by_id = _index_by_id(staff_templates)
	is_loaded = true
	data_loaded.emit()


func get_facility(definition_id: String) -> Dictionary:
	return facilities_by_id.get(definition_id, {})


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


func _index_by_id(items: Array) -> Dictionary:
	var index := {}
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and item.has("id"):
			index[item.id] = item
	return index
