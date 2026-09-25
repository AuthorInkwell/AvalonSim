extends Control

signal facility_place_requested(definition_id, cell, orientation)
signal road_place_requested(cell)
signal placement_selected(placement)
signal navigation_requested(normalized_position)
signal camera_changed(normalized_rect)

const BASE_TILE_SIZE := 22.0
const CATEGORY_COLORS := {
	"lodgings": Color("#d99b5b"),
	"attractions": Color("#c36bcf"),
	"amenities": Color("#e3ca62"),
	"utility": Color("#6bbec7"),
	"support": Color("#7aa4d8"),
	"research_and_development": Color("#9a83d8")
}

@export var minimap := false

var zoom := 0.85
var camera_offset := Vector2(-260, -150)
var active_tool := ""
var active_definition_id := ""
var orientation := 0
var hover_cell := Vector2i(-1, -1)
var _dragging := false
var _last_mouse := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	MapManager.map_changed.connect(_on_map_changed)
	resized.connect(_on_resized)
	if minimap:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func set_road_tool() -> void:
	active_tool = "road"
	active_definition_id = ""
	queue_redraw()


func set_facility_tool(definition_id: String) -> void:
	active_tool = "facility"
	active_definition_id = definition_id
	queue_redraw()


func clear_tool() -> void:
	active_tool = ""
	active_definition_id = ""
	queue_redraw()


func rotate_tool() -> void:
	orientation = posmod(orientation + 1, 2)
	queue_redraw()


func center_on_normalized(normalized_position: Vector2) -> void:
	if minimap:
		return
	var map_pixel_size := Vector2(MapManager.MAP_WIDTH, MapManager.MAP_HEIGHT) * _tile_size()
	var target := Vector2(normalized_position.x * map_pixel_size.x, normalized_position.y * map_pixel_size.y)
	camera_offset = size * 0.5 - target
	_clamp_camera()
	queue_redraw()
	_emit_camera()


func _draw() -> void:
	if minimap:
		_draw_minimap()
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color("#16495a"))
	var tile_size := _tile_size()
	for y in range(MapManager.MAP_HEIGHT):
		for x in range(MapManager.MAP_WIDTH):
			var cell := Vector2i(x, y)
			var rect := Rect2(_map_to_screen(cell), Vector2.ONE * tile_size)
			if not rect.intersects(Rect2(Vector2.ZERO, size)):
				continue
			var terrain_type := MapManager.get_terrain(cell)
			var color := Color("#337c91")
			if terrain_type == MapManager.TERRAIN_LAND:
				color = Color("#79a968") if (x + y) % 2 == 0 else Color("#74a263")
			elif terrain_type == MapManager.TERRAIN_MOUNTAIN:
				color = Color("#756d61")
			draw_rect(rect, color)
			if zoom >= 0.58:
				draw_rect(rect, Color(0.05, 0.12, 0.1, 0.2), false, 1.0)
			if terrain_type == MapManager.TERRAIN_MOUNTAIN:
				var peak := rect.get_center() + Vector2(0, -tile_size * 0.25)
				draw_colored_polygon(PackedVector2Array([
					peak,
					rect.position + Vector2(tile_size * 0.16, tile_size * 0.82),
					rect.position + Vector2(tile_size * 0.84, tile_size * 0.82)
				]), Color("#aaa18d"))

	for key in MapManager.roads:
		var cell := _key_to_cell(String(key))
		var rect := Rect2(_map_to_screen(cell), Vector2.ONE * tile_size)
		draw_rect(rect.grow(-tile_size * 0.16), Color("#3b4146"))
		draw_line(rect.position + Vector2(tile_size * 0.5, tile_size * 0.25), rect.position + Vector2(tile_size * 0.5, tile_size * 0.75), Color("#d7bf70"), maxf(1.0, zoom))

	for placement_data in MapManager.placements:
		_draw_placement(placement_data)

	_draw_hover_preview()


func _draw_placement(placement: Dictionary) -> void:
	var tile_size := _tile_size()
	var origin := _array_to_cell(placement.get("position", [0, 0]))
	var footprint := _array_to_cell(placement.get("footprint", [1, 1]))
	var rect := Rect2(_map_to_screen(origin), Vector2(footprint.x, footprint.y) * tile_size).grow(-2.0)
	var definition := DataCatalog.get_facility(String(placement.get("definition_id", "")))
	var category := String(definition.get("category", "support"))
	var color: Color = CATEGORY_COLORS.get(category, Color("#b6aa8b"))
	if placement.get("kind", "") == "construction":
		color = color.darkened(0.35)
	draw_rect(rect, color)
	draw_rect(rect, Color("#263238"), false, maxf(2.0, zoom * 2.0))
	var roof := rect.grow(-minf(tile_size * 0.25, 7.0))
	draw_rect(roof, color.lightened(0.17))
	draw_line(roof.position, roof.end, Color(1, 1, 1, 0.18), maxf(1.0, zoom))
	if zoom >= 0.65 and rect.size.x >= 50.0:
		var label := String(definition.get("name", "Building"))
		if placement.get("kind", "") == "construction":
			label = "BUILDING: " + label
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(5, 16), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, int(11 * clampf(zoom, 0.8, 1.3)), Color("#172226"))


func _draw_hover_preview() -> void:
	if hover_cell.x < 0 or active_tool.is_empty():
		return
	var tile_size := _tile_size()
	if active_tool == "road":
		var road_ok: bool = bool(MapManager.can_place_road(hover_cell).get("success", false))
		var road_rect := Rect2(_map_to_screen(hover_cell), Vector2.ONE * tile_size).grow(-1.0)
		draw_rect(road_rect, Color(0.45, 0.85, 0.95, 0.55) if road_ok else Color(0.9, 0.25, 0.2, 0.55))
		return
	var definition := DataCatalog.get_facility(active_definition_id)
	var footprint := MapManager.get_footprint(definition, orientation)
	var check := MapManager.can_place_facility(active_definition_id, hover_cell, orientation)
	var preview_rect := Rect2(_map_to_screen(hover_cell), Vector2(footprint.x, footprint.y) * tile_size).grow(-1.0)
	draw_rect(preview_rect, Color(0.35, 0.95, 0.7, 0.48) if check.get("success", false) else Color(0.95, 0.25, 0.2, 0.48))
	draw_rect(preview_rect, Color.WHITE, false, 2.0)


func _draw_minimap() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#17495a"))
	var scale := Vector2(size.x / float(MapManager.MAP_WIDTH), size.y / float(MapManager.MAP_HEIGHT))
	for y in range(MapManager.MAP_HEIGHT):
		for x in range(MapManager.MAP_WIDTH):
			var terrain_type := MapManager.get_terrain(Vector2i(x, y))
			var color := Color("#337c91")
			if terrain_type == MapManager.TERRAIN_LAND:
				color = Color("#74a263")
			elif terrain_type == MapManager.TERRAIN_MOUNTAIN:
				color = Color("#756d61")
			draw_rect(Rect2(Vector2(x, y) * scale, scale + Vector2.ONE), color)
	for key in MapManager.roads:
		var cell := _key_to_cell(String(key))
		draw_rect(Rect2(Vector2(cell) * scale, scale + Vector2.ONE), Color("#343b40"))
	for placement in MapManager.placements:
		var origin := _array_to_cell(placement.get("position", [0, 0]))
		var footprint := _array_to_cell(placement.get("footprint", [1, 1]))
		var definition := DataCatalog.get_facility(String(placement.get("definition_id", "")))
		var color: Color = CATEGORY_COLORS.get(String(definition.get("category", "")), Color.WHITE)
		draw_rect(Rect2(Vector2(origin) * scale, Vector2(footprint) * scale), color)


func _gui_input(event: InputEvent) -> void:
	if minimap:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			navigation_requested.emit(Vector2(event.position.x / size.x, event.position.y / size.y))
		return

	if event is InputEventMouseMotion:
		hover_cell = _screen_to_cell(event.position)
		if _dragging:
			camera_offset += event.position - _last_mouse
			_clamp_camera()
			_emit_camera()
		_last_mouse = event.position
		queue_redraw()
		return

	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = event.pressed
			_last_mouse = event.position
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 0.89)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var cell := _screen_to_cell(event.position)
			if active_tool == "road":
				road_place_requested.emit(cell)
			elif active_tool == "facility" and not active_definition_id.is_empty():
				facility_place_requested.emit(active_definition_id, cell, orientation)
			else:
				placement_selected.emit(MapManager.get_placement_at(cell))


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var before := (screen_position - camera_offset) / _tile_size()
	zoom = clampf(zoom * factor, 0.48, 1.6)
	camera_offset = screen_position - before * _tile_size()
	_clamp_camera()
	queue_redraw()
	_emit_camera()


func _clamp_camera() -> void:
	var map_size := Vector2(MapManager.MAP_WIDTH, MapManager.MAP_HEIGHT) * _tile_size()
	camera_offset.x = clampf(camera_offset.x, minf(40.0, size.x - map_size.x - 40.0), 40.0)
	camera_offset.y = clampf(camera_offset.y, minf(40.0, size.y - map_size.y - 40.0), 40.0)


func _emit_camera() -> void:
	var map_size := Vector2(MapManager.MAP_WIDTH, MapManager.MAP_HEIGHT) * _tile_size()
	var top_left := -camera_offset / map_size
	camera_changed.emit(Rect2(top_left, size / map_size))


func _tile_size() -> float:
	return BASE_TILE_SIZE * zoom


func _map_to_screen(cell: Vector2i) -> Vector2:
	return camera_offset + Vector2(cell) * _tile_size()


func _screen_to_cell(screen_position: Vector2) -> Vector2i:
	var local := (screen_position - camera_offset) / _tile_size()
	return Vector2i(floori(local.x), floori(local.y))


func _array_to_cell(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _key_to_cell(key: String) -> Vector2i:
	var parts := key.split(":")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func _on_map_changed() -> void:
	queue_redraw()


func _on_resized() -> void:
	_clamp_camera()
	queue_redraw()
