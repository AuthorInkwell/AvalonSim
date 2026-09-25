extends Control

const IslandMapView := preload("res://ui/island_map.gd")
const CATEGORIES := [
	["lodgings", "Lodgings"],
	["attractions", "Attractions"],
	["amenities", "Amenities"],
	["utility", "Utility"],
	["support", "Support"],
	["research_and_development", "R&D"]
]

var stat_labels: Dictionary = {}
var demand_bars: Dictionary = {}
var category_menu: OptionButton
var build_menu: OptionButton
var footprint_label: Label
var status_label: Label
var inspector: RichTextLabel
var map_view: Control
var minimap_view: Control
var daily_dialog: AcceptDialog
var budget_dialog: AcceptDialog
var staff_dialog: AcceptDialog
var facility_dialog: AcceptDialog
var staff_list: ItemList
var hire_menu: OptionButton
var assign_staff_menu: OptionButton
var assign_facility_menu: OptionButton


func _ready() -> void:
	_build_theme()
	_build_layout()
	_connect_signals()
	_populate_build_categories()
	_populate_staff_controls()
	_refresh()
	call_deferred("_center_initial_view")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_on_rotate_tool()
		get_viewport().set_input_as_handled()


func _build_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 13
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#263d45")
	panel_style.border_color = Color("#57727b")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 2
	panel_style.corner_radius_top_right = 2
	panel_style.corner_radius_bottom_left = 2
	panel_style.corner_radius_bottom_right = 2
	ui_theme.set_stylebox("panel", "PanelContainer", panel_style)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("#3d5961")
	button_style.border_color = Color("#789099")
	button_style.set_border_width_all(1)
	button_style.set_corner_radius_all(2)
	ui_theme.set_stylebox("normal", "Button", button_style)
	var hover_style := button_style.duplicate()
	hover_style.bg_color = Color("#55727a")
	ui_theme.set_stylebox("hover", "Button", hover_style)
	theme = ui_theme


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#17292f")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_menu_bar())
	root.add_child(_build_stat_bar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	root.add_child(body)
	body.add_child(_build_construction_panel())
	body.add_child(_build_map_panel())
	body.add_child(_build_information_panel())
	root.add_child(_build_bottom_bar())
	_build_dialogs()


func _build_menu_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size.y = 34
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)

	var title := Label.new()
	title.text = "  AVALON : PARADISE ENGINE  "
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("#f2d58a"))
	row.add_child(title)

	var file_menu := MenuButton.new()
	file_menu.text = "File"
	file_menu.get_popup().add_item("New Island", 0)
	file_menu.get_popup().add_item("Save", 1)
	file_menu.get_popup().add_item("Load", 2)
	file_menu.get_popup().id_pressed.connect(_on_file_menu)
	row.add_child(file_menu)

	var management_menu := MenuButton.new()
	management_menu.text = "Management"
	management_menu.get_popup().add_item("Detailed Budget", 0)
	management_menu.get_popup().add_item("Staff Roster", 1)
	management_menu.get_popup().add_item("Facility Register", 2)
	management_menu.get_popup().id_pressed.connect(_on_management_menu)
	row.add_child(management_menu)

	var planning_menu := MenuButton.new()
	planning_menu.text = "Planning"
	planning_menu.get_popup().add_item("Research & Development (coming later)", 0)
	planning_menu.get_popup().add_item("Island Overlays (coming later)", 1)
	planning_menu.get_popup().set_item_disabled(0, true)
	planning_menu.get_popup().set_item_disabled(1, true)
	row.add_child(planning_menu)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var hint := Label.new()
	hint.text = "LMB build/select  •  RMB/MMB pan  •  Wheel zoom    "
	hint.add_theme_color_override("font_color", Color("#b5c6ca"))
	row.add_child(hint)
	return bar


func _build_stat_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size.y = 54
	var stats := GridContainer.new()
	stats.columns = 7
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(stats)
	_add_stat(stats, "day", "DAY")
	_add_stat(stats, "funds", "TREASURY")
	_add_stat(stats, "profit", "DAILY P/L")
	_add_stat(stats, "guests", "GUESTS")
	_add_stat(stats, "capacity", "CAPACITY")
	_add_stat(stats, "staff", "STAFF")
	_add_stat(stats, "satisfaction", "SATISFACTION")
	return bar


func _add_stat(parent: GridContainer, key: String, label_text: String) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#9eb4b9"))
	box.add_child(label)
	var value := Label.new()
	value.text = "-"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", Color("#f1dd9b"))
	box.add_child(value)
	parent.add_child(box)
	stat_labels[key] = value


func _build_construction_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 225
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	box.add_child(_heading("CONSTRUCTION"))

	var category_label := Label.new()
	category_label.text = "Building category"
	box.add_child(category_label)
	category_menu = OptionButton.new()
	category_menu.item_selected.connect(_on_category_selected)
	box.add_child(category_menu)

	var facility_label := Label.new()
	facility_label.text = "Structure"
	box.add_child(facility_label)
	build_menu = OptionButton.new()
	build_menu.item_selected.connect(_on_build_selected)
	box.add_child(build_menu)

	footprint_label = Label.new()
	footprint_label.text = "Select a structure."
	footprint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footprint_label.custom_minimum_size.y = 84
	box.add_child(footprint_label)

	var place_button := Button.new()
	place_button.text = "PLACE STRUCTURE"
	place_button.pressed.connect(_on_place_tool)
	box.add_child(place_button)
	var rotate_button := Button.new()
	rotate_button.text = "ROTATE FOOTPRINT [R]"
	rotate_button.pressed.connect(_on_rotate_tool)
	box.add_child(rotate_button)
	var road_button := Button.new()
	road_button.text = "BUILD ROAD  •  25 cr/tile"
	road_button.pressed.connect(_on_road_tool)
	box.add_child(road_button)
	var select_button := Button.new()
	select_button.text = "INSPECT / PAN"
	select_button.pressed.connect(_on_select_tool)
	box.add_child(select_button)

	var terrain_note := Label.new()
	terrain_note.text = "\nGreen: buildable land\nBlue: coastline / water\nGray: mountain / volcano\n\nBuildings without adjacent roads operate at reduced guest access."
	terrain_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terrain_note.add_theme_color_override("font_color", Color("#b8c8c5"))
	box.add_child(terrain_note)
	return panel


func _build_map_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view = IslandMapView.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.facility_place_requested.connect(_on_facility_place_requested)
	map_view.road_place_requested.connect(_on_road_place_requested)
	map_view.placement_selected.connect(_on_placement_selected)
	panel.add_child(map_view)
	return panel


func _build_information_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 250
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	box.add_child(_heading("ISLAND DEMAND"))
	for category_data in CATEGORIES:
		var key := String(category_data[0])
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(category_data[1])
		label.custom_minimum_size.x = 80
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.show_percentage = true
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		box.add_child(row)
		demand_bars[key] = bar

	var demand_note := Label.new()
	demand_note.text = "Higher values indicate unmet island need.\nR&D awaits the research-project system."
	demand_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demand_note.add_theme_font_size_override("font_size", 11)
	demand_note.add_theme_color_override("font_color", Color("#aebfc3"))
	box.add_child(demand_note)
	box.add_child(_heading("INSPECTOR"))
	inspector = RichTextLabel.new()
	inspector.bbcode_enabled = true
	inspector.fit_content = false
	inspector.custom_minimum_size.y = 115
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector.text = "Select a structure on the map."
	box.add_child(inspector)
	box.add_child(_heading("MINIMAP"))
	minimap_view = IslandMapView.new()
	minimap_view.minimap = true
	minimap_view.custom_minimum_size = Vector2(230, 145)
	minimap_view.navigation_requested.connect(_on_minimap_navigate)
	box.add_child(minimap_view)
	return panel


func _build_bottom_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size.y = 44
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	status_label = Label.new()
	status_label.text = "Welcome to Avalon. Select a structure or road tool."
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status_label)
	var budget_button := Button.new()
	budget_button.text = "BUDGET"
	budget_button.pressed.connect(_show_budget)
	row.add_child(budget_button)
	var staff_button := Button.new()
	staff_button.text = "STAFF"
	staff_button.pressed.connect(_show_staff)
	row.add_child(staff_button)
	var advance_button := Button.new()
	advance_button.text = "ADVANCE DAY  ▶"
	advance_button.custom_minimum_size.x = 170
	advance_button.pressed.connect(_on_advance_day)
	row.add_child(advance_button)
	return bar


func _build_dialogs() -> void:
	daily_dialog = AcceptDialog.new()
	daily_dialog.title = "Morning Island Briefing"
	add_child(daily_dialog)
	budget_dialog = AcceptDialog.new()
	budget_dialog.title = "Avalon Detailed Budget"
	add_child(budget_dialog)
	facility_dialog = AcceptDialog.new()
	facility_dialog.title = "Facility Register"
	add_child(facility_dialog)

	staff_dialog = AcceptDialog.new()
	staff_dialog.title = "Staff Roster & Assignments"
	staff_dialog.min_size = Vector2i(760, 500)
	add_child(staff_dialog)
	var staff_box := VBoxContainer.new()
	staff_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	staff_box.offset_left = 12
	staff_box.offset_top = 12
	staff_box.offset_right = -12
	staff_box.offset_bottom = -48
	staff_dialog.add_child(staff_box)
	staff_list = ItemList.new()
	staff_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	staff_box.add_child(staff_list)
	var hire_row := HBoxContainer.new()
	hire_menu = OptionButton.new()
	hire_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hire_row.add_child(hire_menu)
	var hire_button := Button.new()
	hire_button.text = "Hire"
	hire_button.pressed.connect(_on_hire)
	hire_row.add_child(hire_button)
	staff_box.add_child(hire_row)
	var assign_row := HBoxContainer.new()
	assign_staff_menu = OptionButton.new()
	assign_staff_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assign_row.add_child(assign_staff_menu)
	assign_facility_menu = OptionButton.new()
	assign_facility_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assign_row.add_child(assign_facility_menu)
	var assign_button := Button.new()
	assign_button.text = "Assign"
	assign_button.pressed.connect(_on_assign)
	assign_row.add_child(assign_button)
	staff_box.add_child(assign_row)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#f0d184"))
	return label


func _connect_signals() -> void:
	GameState.day_advanced.connect(_on_day_advanced)
	GameState.new_game_started.connect(_on_state_changed)
	GameState.funds_changed.connect(_on_state_changed)
	FacilityManager.facilities_changed.connect(_on_state_changed)
	FacilityManager.construction_changed.connect(_on_state_changed)
	StaffManager.staff_changed.connect(_on_state_changed)
	ReputationManager.reputation_changed.connect(_on_state_changed)
	MapManager.map_changed.connect(_on_state_changed)
	EconomyManager.transaction_completed.connect(_on_transaction)


func _populate_build_categories() -> void:
	category_menu.clear()
	for category_data in CATEGORIES:
		category_menu.add_item(String(category_data[1]))
		category_menu.set_item_metadata(category_menu.get_item_count() - 1, category_data[0])
	category_menu.select(0)
	_populate_build_menu("lodgings")


func _populate_build_menu(category: String) -> void:
	build_menu.clear()
	for definition in DataCatalog.facilities:
		if String(definition.get("category", "")) != category:
			continue
		if not bool(definition.get("buildable", true)) or not definition.has("build_cost"):
			continue
		build_menu.add_item("%s  •  %d cr" % [definition.name, int(definition.build_cost)])
		build_menu.set_item_metadata(build_menu.get_item_count() - 1, definition.id)
	build_menu.disabled = build_menu.item_count == 0
	_update_footprint_label()


func _update_footprint_label() -> void:
	if build_menu.item_count == 0 or build_menu.selected < 0:
		footprint_label.text = "No buildable structures are defined for this category yet."
		return
	var definition := DataCatalog.get_facility(String(build_menu.get_item_metadata(build_menu.selected)))
	var footprint := MapManager.get_footprint(definition, map_view.orientation if map_view != null else 0)
	footprint_label.text = "%s\n%d × %d tiles  •  %d day%s\nUpkeep: %d cr/day" % [
		String(definition.get("description", "")),
		footprint.x,
		footprint.y,
		int(definition.get("build_time", 1)),
		"" if int(definition.get("build_time", 1)) == 1 else "s",
		int(definition.get("upkeep", 0))
	]


func _populate_staff_controls() -> void:
	if hire_menu == null:
		return
	hire_menu.clear()
	for template in DataCatalog.staff_templates:
		hire_menu.add_item("%s — %s (%d cr)" % [template.get("template_name", "Candidate"), template.get("specialty", "Operations"), int(template.get("hire_cost", 0))])
		hire_menu.set_item_metadata(hire_menu.get_item_count() - 1, template.id)

	assign_staff_menu.clear()
	staff_list.clear()
	for staff in StaffManager.staff_roster:
		var facility := FacilityManager.get_facility_by_id(int(staff.get("assigned_facility_id", -1)))
		var assignment := "Unassigned" if facility.is_empty() else String(facility.name)
		staff_list.add_item("%s  |  %s  |  %s  |  eff %.0f%%  stress %.0f%%  |  %s" % [
			staff.name,
			StaffManager.get_staff_role_label(staff),
			staff.specialty,
			float(staff.efficiency) * 100.0,
			float(staff.stress) * 100.0,
			assignment
		])
		assign_staff_menu.add_item("%s — %s" % [staff.name, StaffManager.get_staff_role_label(staff)])
		assign_staff_menu.set_item_metadata(assign_staff_menu.get_item_count() - 1, int(staff.id))

	assign_facility_menu.clear()
	assign_facility_menu.add_item("Unassigned / Rest")
	assign_facility_menu.set_item_metadata(0, -1)
	for facility in FacilityManager.facilities:
		assign_facility_menu.add_item(String(facility.name))
		assign_facility_menu.set_item_metadata(assign_facility_menu.get_item_count() - 1, int(facility.id))


func _refresh() -> void:
	stat_labels.day.text = str(GameState.day)
	stat_labels.funds.text = "%d cr" % GameState.funds
	stat_labels.profit.text = "%+d cr" % GameState.daily_profit
	stat_labels.guests.text = str(GameState.guest_demand)
	stat_labels.capacity.text = str(FacilityManager.get_total_capacity())
	stat_labels.staff.text = str(StaffManager.staff_roster.size())
	stat_labels.satisfaction.text = "%.0f%%" % (GameState.get_guest_satisfaction() * 100.0)
	var demand := GameState.get_category_demand()
	for key in demand_bars:
		demand_bars[key].value = int(demand.get(key, 0))
	_populate_staff_controls()


func _on_category_selected(index: int) -> void:
	_populate_build_menu(String(category_menu.get_item_metadata(index)))


func _on_build_selected(_index: int) -> void:
	_update_footprint_label()


func _on_place_tool() -> void:
	if build_menu.selected < 0 or build_menu.disabled:
		status_label.text = "No buildable structure is available in this category."
		return
	var definition_id := String(build_menu.get_item_metadata(build_menu.selected))
	map_view.set_facility_tool(definition_id)
	status_label.text = "Placing %s. Choose a clear flat-land footprint." % DataCatalog.get_facility(definition_id).name


func _on_rotate_tool() -> void:
	map_view.rotate_tool()
	_update_footprint_label()
	status_label.text = "Footprint rotated."


func _on_road_tool() -> void:
	map_view.set_road_tool()
	status_label.text = "Road tool active. Place road tiles on flat land."


func _on_select_tool() -> void:
	map_view.clear_tool()
	status_label.text = "Inspect mode active. Select a structure or pan the island."


func _on_facility_place_requested(definition_id: String, cell: Vector2i, placement_orientation: int) -> void:
	var result := EconomyManager.place_facility(definition_id, cell, placement_orientation)
	status_label.text = String(result.get("message", "Unable to place structure."))
	_refresh()


func _on_road_place_requested(cell: Vector2i) -> void:
	var result := EconomyManager.place_road(cell)
	status_label.text = String(result.get("message", "Unable to place road."))
	_refresh()


func _on_placement_selected(placement: Dictionary) -> void:
	if placement.is_empty():
		inspector.text = "No structure on this tile."
		return
	var definition := DataCatalog.get_facility(String(placement.get("definition_id", "")))
	var kind := String(placement.get("kind", "facility"))
	var origin: Array = placement.get("position", [0, 0])
	var footprint: Array = placement.get("footprint", [1, 1])
	var access := MapManager.footprint_has_road_access(Vector2i(int(origin[0]), int(origin[1])), Vector2i(int(footprint[0]), int(footprint[1])))
	var lines := [
		"[font_size=18][color=#f0d184]%s[/color][/font_size]" % definition.get("name", "Structure"),
		"%s • %s" % [String(definition.get("category", "")).capitalize(), "Under construction" if kind == "construction" else "Operating"],
		"Grid: %d, %d • Footprint: %d × %d" % [int(origin[0]), int(origin[1]), int(footprint[0]), int(footprint[1])],
		"Road access: %s" % ("Connected" if access else "NONE — reduced guest access")
	]
	if kind == "facility":
		var facility := FacilityManager.get_facility_by_id(int(placement.get("entity_id", -1)))
		lines.append("Staff: %d / %d" % [StaffManager.get_staff_for_facility(int(facility.get("id", -1))).size(), int(facility.get("staff_required", 0))])
	inspector.text = "\n".join(lines)


func _on_minimap_navigate(normalized_position: Vector2) -> void:
	map_view.center_on_normalized(normalized_position)


func _on_advance_day() -> void:
	status_label.text = "Closing the books and advancing one day..."
	GameState.advance_day()


func _on_day_advanced(summary: Dictionary) -> void:
	var completed: Array = []
	for facility in summary.get("construction_completed", []):
		completed.append(String(facility.name))
	var operations: Dictionary = summary.get("operations", {})
	var event: Dictionary = summary.get("event", {})
	var important_lines := [
		"Day %d closed. Avalon is now beginning Day %d." % [int(summary.day), GameState.day],
		"",
		"Income                              %+8d cr" % int(summary.revenue),
		"Facility upkeep                    -%8d cr" % int(summary.upkeep),
		"Staff payroll                      -%8d cr" % int(summary.payroll),
		"TOTAL CHANGE                        %+8d cr" % int(summary.profit),
		"Cash on hand                        %8d cr" % int(summary.funds),
		"",
		"Guests served: %d of %d demand" % [int(summary.served_guests), int(summary.guest_demand)],
		"Guest satisfaction: %.0f%%" % (float(operations.get("satisfaction", 0.0)) * 100.0)
	]
	if not completed.is_empty():
		important_lines.append("Construction completed: %s" % ", ".join(completed))
	if event.get("triggered", false):
		important_lines.append("Notable event: %s — %s" % [event.get("title", "Island event"), event.get("description", "")])
	daily_dialog.dialog_text = "\n".join(important_lines)
	daily_dialog.popup_centered(Vector2i(570, 420))
	status_label.text = "Day %d begins. Net change: %+d cr." % [GameState.day, int(summary.profit)]
	_refresh()


func _show_budget() -> void:
	var operations := FacilityManager.calculate_daily_operations(GameState.guest_demand)
	var payroll := StaffManager.calculate_daily_payroll()
	var lines := [
		"Projected operating budget for Day %d" % GameState.day,
		"",
		"FACILITY                                  REVENUE      UPKEEP      NET"
	]
	for report in operations.get("reports", []):
		lines.append("%-38s %8d  -%8d  %+8d" % [
			String(report.get("name", "Facility")).left(38),
			int(report.get("income", 0)),
			int(report.get("upkeep", 0)),
			int(report.get("income", 0)) - int(report.get("upkeep", 0))
		])
	lines.append("")
	lines.append("Projected facility revenue:             %+d cr" % int(operations.get("revenue", 0)))
	lines.append("Projected facility upkeep:              -%d cr" % int(operations.get("upkeep", 0)))
	lines.append("Staff payroll:                           -%d cr" % payroll)
	lines.append("PROJECTED NET:                           %+d cr" % (int(operations.get("revenue", 0)) - int(operations.get("upkeep", 0)) - payroll))
	budget_dialog.dialog_text = "\n".join(lines)
	budget_dialog.popup_centered(Vector2i(720, 520))


func _show_staff() -> void:
	_populate_staff_controls()
	staff_dialog.popup_centered(Vector2i(760, 500))


func _show_facilities() -> void:
	var lines: Array = []
	for facility in FacilityManager.facilities:
		var access := MapManager.facility_has_road_access(facility)
		lines.append("%s  |  %s  |  cap %d  |  staff %d/%d  |  road %s" % [
			facility.name,
			String(facility.get("category", "")).capitalize(),
			int(facility.get("capacity", 0)),
			StaffManager.get_staff_for_facility(int(facility.id)).size(),
			int(facility.get("staff_required", 0)),
			"yes" if access else "NO"
		])
	for project in FacilityManager.construction_queue:
		lines.append("[BUILDING] %s — %d day(s) remaining" % [project.name, int(project.days_remaining)])
	facility_dialog.dialog_text = "\n".join(lines)
	facility_dialog.popup_centered(Vector2i(690, 460))


func _on_file_menu(id: int) -> void:
	match id:
		0:
			GameState.start_new_game()
			status_label.text = "New Avalon charter opened."
			_center_initial_view()
		1:
			var result := SaveManager.save_game()
			status_label.text = result.message
		2:
			var result := SaveManager.load_game()
			status_label.text = result.message
			_refresh()


func _on_management_menu(id: int) -> void:
	match id:
		0:
			_show_budget()
		1:
			_show_staff()
		2:
			_show_facilities()


func _on_hire() -> void:
	if hire_menu.selected < 0:
		return
	var result := EconomyManager.hire_staff(String(hire_menu.get_item_metadata(hire_menu.selected)))
	status_label.text = result.message
	_populate_staff_controls()
	_refresh()


func _on_assign() -> void:
	if assign_staff_menu.selected < 0 or assign_facility_menu.selected < 0:
		return
	var result := EconomyManager.assign_staff(
		int(assign_staff_menu.get_item_metadata(assign_staff_menu.selected)),
		int(assign_facility_menu.get_item_metadata(assign_facility_menu.selected))
	)
	status_label.text = result.message
	_populate_staff_controls()
	_refresh()


func _on_transaction(message: String) -> void:
	status_label.text = message


func _on_state_changed() -> void:
	_refresh()


func _center_initial_view() -> void:
	if map_view != null:
		map_view.center_on_normalized(Vector2(0.5, 0.53))
