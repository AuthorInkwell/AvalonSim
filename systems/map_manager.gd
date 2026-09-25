extends Node

signal map_changed

const MAP_WIDTH := 48
const MAP_HEIGHT := 32
const TERRAIN_WATER := 0
const TERRAIN_LAND := 1
const TERRAIN_MOUNTAIN := 2
const STARTER_POSITION := Vector2i(22, 14)

var terrain: Array = []
var roads: Dictionary = {}
var placements: Array = []


func setup_new_game() -> void:
	_generate_terrain()
	roads.clear()
	placements.clear()
	for x in range(18, 31):
		roads[_cell_key(Vector2i(x, 16))] = true
	for y in range(16, 22):
		roads[_cell_key(Vector2i(24, y))] = true

	if not FacilityManager.facilities.is_empty():
		var starter: Dictionary = FacilityManager.facilities[0]
		var definition := DataCatalog.get_facility(String(starter.get("definition_id", "")))
		var footprint := get_footprint(definition, 0)
		placements.append(_make_placement(
			"facility",
			int(starter.get("id", -1)),
			String(starter.get("definition_id", "")),
			STARTER_POSITION,
			0,
			footprint
		))
		_write_spatial_data(starter, STARTER_POSITION, 0, footprint)
	map_changed.emit()


func get_terrain(cell: Vector2i) -> int:
	if not is_in_bounds(cell):
		return TERRAIN_WATER
	return int(terrain[cell.y][cell.x])


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_WIDTH and cell.y < MAP_HEIGHT


func is_buildable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and get_terrain(cell) == TERRAIN_LAND


func get_footprint(definition: Dictionary, orientation: int = 0) -> Vector2i:
	var raw: Array = definition.get("footprint", [2, 2])
	var footprint := Vector2i(int(raw[0]), int(raw[1]))
	if posmod(orientation, 2) == 1:
		footprint = Vector2i(footprint.y, footprint.x)
	return footprint


func can_place_facility(definition_id: String, origin: Vector2i, orientation: int = 0) -> Dictionary:
	var definition := DataCatalog.get_facility(definition_id)
	if definition.is_empty():
		return {"success": false, "message": "Unknown facility."}
	var footprint := get_footprint(definition, orientation)
	for cell in get_footprint_cells(origin, footprint):
		if not is_buildable(cell):
			var terrain_name := "water" if get_terrain(cell) == TERRAIN_WATER else "mountain"
			return {"success": false, "message": "Cannot build on %s." % terrain_name}
		if is_occupied(cell) or has_road(cell):
			return {"success": false, "message": "That footprint overlaps an existing structure or road."}
	return {"success": true, "footprint": footprint, "road_access": footprint_has_road_access(origin, footprint)}


func reserve_construction(project: Dictionary, origin: Vector2i, orientation: int) -> Dictionary:
	var definition_id := String(project.get("definition_id", ""))
	var check := can_place_facility(definition_id, origin, orientation)
	if not check.get("success", false):
		return check
	var footprint: Vector2i = check.footprint
	placements.append(_make_placement(
		"construction",
		int(project.get("project_id", -1)),
		definition_id,
		origin,
		orientation,
		footprint
	))
	project["map_position"] = [origin.x, origin.y]
	project["orientation"] = orientation
	project["footprint"] = [footprint.x, footprint.y]
	map_changed.emit()
	return {"success": true, "road_access": bool(check.road_access)}


func complete_construction(project: Dictionary, facility: Dictionary) -> void:
	var project_id := int(project.get("project_id", -1))
	for placement in placements:
		if String(placement.get("kind", "")) == "construction" and int(placement.get("entity_id", -1)) == project_id:
			placement["kind"] = "facility"
			placement["entity_id"] = int(facility.get("id", -1))
			var origin := _array_to_cell(placement.get("position", [0, 0]))
			var footprint := _array_to_cell(placement.get("footprint", [1, 1]))
			_write_spatial_data(facility, origin, int(placement.get("orientation", 0)), footprint)
			map_changed.emit()
			return


func remove_construction(project_id: int) -> void:
	for index in range(placements.size() - 1, -1, -1):
		var placement: Dictionary = placements[index]
		if placement.get("kind", "") == "construction" and int(placement.get("entity_id", -1)) == project_id:
			placements.remove_at(index)
	map_changed.emit()


func can_place_road(cell: Vector2i) -> Dictionary:
	if not is_buildable(cell):
		return {"success": false, "message": "Roads require flat land."}
	if is_occupied(cell):
		return {"success": false, "message": "A structure already occupies that tile."}
	if has_road(cell):
		return {"success": false, "message": "A road is already present."}
	return {"success": true}


func place_road(cell: Vector2i) -> Dictionary:
	var check := can_place_road(cell)
	if not check.get("success", false):
		return check
	roads[_cell_key(cell)] = true
	map_changed.emit()
	return {"success": true, "message": "Road placed at %d, %d." % [cell.x, cell.y]}


func has_road(cell: Vector2i) -> bool:
	return roads.has(_cell_key(cell))


func is_occupied(cell: Vector2i) -> bool:
	for placement in placements:
		var origin := _array_to_cell(placement.get("position", [0, 0]))
		var footprint := _array_to_cell(placement.get("footprint", [1, 1]))
		if cell.x >= origin.x and cell.y >= origin.y and cell.x < origin.x + footprint.x and cell.y < origin.y + footprint.y:
			return true
	return false


func get_placement_at(cell: Vector2i) -> Dictionary:
	for placement_data in placements:
		var placement: Dictionary = placement_data
		var origin := _array_to_cell(placement.get("position", [0, 0]))
		var footprint := _array_to_cell(placement.get("footprint", [1, 1]))
		if cell.x >= origin.x and cell.y >= origin.y and cell.x < origin.x + footprint.x and cell.y < origin.y + footprint.y:
			return placement
	return {}


func facility_has_road_access(facility: Dictionary) -> bool:
	if not facility.has("map_position"):
		return true
	var definition := DataCatalog.get_facility(String(facility.get("definition_id", "")))
	var origin := _array_to_cell(facility.get("map_position", [0, 0]))
	var footprint := get_footprint(definition, int(facility.get("orientation", 0)))
	return footprint_has_road_access(origin, footprint)


func footprint_has_road_access(origin: Vector2i, footprint: Vector2i) -> bool:
	for x in range(origin.x - 1, origin.x + footprint.x + 1):
		if has_road(Vector2i(x, origin.y - 1)) or has_road(Vector2i(x, origin.y + footprint.y)):
			return true
	for y in range(origin.y, origin.y + footprint.y):
		if has_road(Vector2i(origin.x - 1, y)) or has_road(Vector2i(origin.x + footprint.x, y)):
			return true
	return false


func get_footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array:
	var cells: Array = []
	for y in range(origin.y, origin.y + footprint.y):
		for x in range(origin.x, origin.x + footprint.x):
			cells.append(Vector2i(x, y))
	return cells


func get_state() -> Dictionary:
	return {
		"roads": roads.duplicate(true),
		"placements": placements.duplicate(true)
	}


func load_state(state: Dictionary) -> void:
	_generate_terrain()
	roads = state.get("roads", {}).duplicate(true)
	placements = state.get("placements", []).duplicate(true)
	if state.is_empty():
		_rebuild_legacy_map()
	map_changed.emit()


func _generate_terrain() -> void:
	terrain.clear()
	var center := Vector2(23.5, 15.5)
	for y in range(MAP_HEIGHT):
		var row: Array = []
		for x in range(MAP_WIDTH):
			var nx := (float(x) - center.x) / 22.0
			var ny := (float(y) - center.y) / 13.5
			var edge_noise := sin(float(x) * 0.73) * 0.035 + cos(float(y) * 1.17) * 0.03
			var island_distance := nx * nx + ny * ny
			var terrain_type := TERRAIN_LAND if island_distance < 1.0 + edge_noise else TERRAIN_WATER
			var mountain_distance := Vector2(float(x - 36), float(y - 9)).length()
			if terrain_type == TERRAIN_LAND and mountain_distance < 4.0 and island_distance < 0.82:
				terrain_type = TERRAIN_MOUNTAIN
			row.append(terrain_type)
		terrain.append(row)


func _rebuild_legacy_map() -> void:
	setup_new_game()
	for index in range(1, FacilityManager.facilities.size()):
		var facility: Dictionary = FacilityManager.facilities[index]
		var definition := DataCatalog.get_facility(String(facility.get("definition_id", "")))
		var footprint := get_footprint(definition, 0)
		var origin := Vector2i(18 + (index % 4) * 4, 19 + (index / 4) * 4)
		if can_place_facility(String(facility.get("definition_id", "")), origin, 0).get("success", false):
			placements.append(_make_placement("facility", int(facility.id), String(facility.definition_id), origin, 0, footprint))
			_write_spatial_data(facility, origin, 0, footprint)


func _make_placement(kind: String, entity_id: int, definition_id: String, origin: Vector2i, orientation: int, footprint: Vector2i) -> Dictionary:
	return {
		"kind": kind,
		"entity_id": entity_id,
		"definition_id": definition_id,
		"position": [origin.x, origin.y],
		"orientation": orientation,
		"footprint": [footprint.x, footprint.y]
	}


func _write_spatial_data(facility: Dictionary, origin: Vector2i, orientation: int, footprint: Vector2i) -> void:
	facility["map_position"] = [origin.x, origin.y]
	facility["orientation"] = orientation
	facility["footprint"] = [footprint.x, footprint.y]


func _array_to_cell(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is Vector2i:
		return value
	return Vector2i.ZERO


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
