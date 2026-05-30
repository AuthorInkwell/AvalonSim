extends Control

var stat_labels: Dictionary = {}
var facility_list: ItemList
var staff_list: ItemList
var reputation_list: ItemList
var event_log: ItemList
var daily_summary: RichTextLabel
var build_menu: OptionButton
var hire_menu: OptionButton
var assign_staff_menu: OptionButton
var assign_facility_menu: OptionButton
var status_label: Label
var event_dialog: AcceptDialog


func _ready() -> void:
	_build_layout()
	_connect_signals()
	_populate_menus()
	_refresh()


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Avalon: Paradise Engine"
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Luxury island operations prototype - management loop, staffing, facilities, reputation, and events"
	root.add_child(subtitle)

	var stats := GridContainer.new()
	stats.columns = 6
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(stats)
	_add_stat(stats, "day", "Day")
	_add_stat(stats, "funds", "Credits")
	_add_stat(stats, "profit", "Daily P/L")
	_add_stat(stats, "demand", "Guest Demand")
	_add_stat(stats, "staff", "Staff")
	_add_stat(stats, "capacity", "Capacity")

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	root.add_child(button_row)

	var advance_button := Button.new()
	advance_button.text = "Advance Day"
	advance_button.pressed.connect(_on_advance_day_pressed)
	button_row.add_child(advance_button)

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_on_save_pressed)
	button_row.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(_on_load_pressed)
	button_row.add_child(load_button)

	var new_game_button := Button.new()
	new_game_button.text = "New Game"
	new_game_button.pressed.connect(_on_new_game_pressed)
	button_row.add_child(new_game_button)

	status_label = Label.new()
	status_label.text = "Ready."
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(status_label)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	root.add_child(columns)

	columns.add_child(_build_facility_panel())
	columns.add_child(_build_staff_panel())
	columns.add_child(_build_intelligence_panel())

	event_dialog = AcceptDialog.new()
	add_child(event_dialog)


func _build_facility_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var heading := Label.new()
	heading.text = "Facilities"
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)

	facility_list = ItemList.new()
	facility_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(facility_list)

	var build_row := HBoxContainer.new()
	build_row.add_theme_constant_override("separation", 6)
	box.add_child(build_row)

	build_menu = OptionButton.new()
	build_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_row.add_child(build_menu)

	var build_button := Button.new()
	build_button.text = "Build"
	build_button.pressed.connect(_on_build_pressed)
	build_row.add_child(build_button)

	return panel


func _build_staff_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var heading := Label.new()
	heading.text = "Staff Roster"
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)

	staff_list = ItemList.new()
	staff_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(staff_list)

	var hire_row := HBoxContainer.new()
	hire_row.add_theme_constant_override("separation", 6)
	box.add_child(hire_row)

	hire_menu = OptionButton.new()
	hire_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hire_row.add_child(hire_menu)

	var hire_button := Button.new()
	hire_button.text = "Hire"
	hire_button.pressed.connect(_on_hire_pressed)
	hire_row.add_child(hire_button)

	var assign_label := Label.new()
	assign_label.text = "Assignment"
	box.add_child(assign_label)

	assign_staff_menu = OptionButton.new()
	box.add_child(assign_staff_menu)

	assign_facility_menu = OptionButton.new()
	box.add_child(assign_facility_menu)

	var assign_button := Button.new()
	assign_button.text = "Assign Selected Staff"
	assign_button.pressed.connect(_on_assign_pressed)
	box.add_child(assign_button)

	return panel


func _build_intelligence_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var rep_heading := Label.new()
	rep_heading.text = "Reputation"
	rep_heading.add_theme_font_size_override("font_size", 20)
	box.add_child(rep_heading)

	reputation_list = ItemList.new()
	reputation_list.custom_minimum_size = Vector2(0, 130)
	box.add_child(reputation_list)

	var summary_heading := Label.new()
	summary_heading.text = "Daily Report"
	summary_heading.add_theme_font_size_override("font_size", 20)
	box.add_child(summary_heading)

	daily_summary = RichTextLabel.new()
	daily_summary.fit_content = true
	daily_summary.custom_minimum_size = Vector2(0, 150)
	box.add_child(daily_summary)

	var events_heading := Label.new()
	events_heading.text = "Event Log"
	events_heading.add_theme_font_size_override("font_size", 20)
	box.add_child(events_heading)

	event_log = ItemList.new()
	event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(event_log)

	return panel


func _connect_signals() -> void:
	GameState.day_advanced.connect(_on_day_advanced)
	GameState.new_game_started.connect(_on_state_changed)
	GameState.funds_changed.connect(_on_state_changed)
	FacilityManager.facilities_changed.connect(_on_state_changed)
	FacilityManager.construction_changed.connect(_on_state_changed)
	StaffManager.staff_changed.connect(_on_state_changed)
	ReputationManager.reputation_changed.connect(_on_state_changed)
	EconomyManager.transaction_completed.connect(_on_transaction_completed)


func _add_stat(parent: GridContainer, key: String, label_text: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)

	var label := Label.new()
	label.text = label_text
	box.add_child(label)

	var value := Label.new()
	value.text = "-"
	value.add_theme_font_size_override("font_size", 18)
	box.add_child(value)
	stat_labels[key] = value


func _populate_menus() -> void:
	build_menu.clear()
	for definition in DataCatalog.facilities:
		var index := build_menu.get_item_count()
		build_menu.add_item("%s (%d cr, %dd)" % [definition.name, int(definition.build_cost), int(definition.build_time)])
		build_menu.set_item_metadata(index, definition.id)

	hire_menu.clear()
	for template in DataCatalog.staff_templates:
		var index := hire_menu.get_item_count()
		hire_menu.add_item("%s - %s (%d cr)" % [template.name, template.role, int(template.hire_cost)])
		hire_menu.set_item_metadata(index, template.id)

	_populate_assignment_menus()


func _populate_assignment_menus() -> void:
	assign_staff_menu.clear()
	for staff in StaffManager.staff_roster:
		var index := assign_staff_menu.get_item_count()
		assign_staff_menu.add_item("%s - %s" % [staff.name, staff.role])
		assign_staff_menu.set_item_metadata(index, int(staff.id))

	assign_facility_menu.clear()
	assign_facility_menu.add_item("Unassigned / Rest")
	assign_facility_menu.set_item_metadata(0, -1)
	for facility in FacilityManager.facilities:
		var index := assign_facility_menu.get_item_count()
		assign_facility_menu.add_item(facility.name)
		assign_facility_menu.set_item_metadata(index, int(facility.id))


func _refresh() -> void:
	stat_labels["day"].text = str(GameState.day)
	stat_labels["funds"].text = "%d cr" % GameState.funds
	stat_labels["profit"].text = "%+d cr" % GameState.daily_profit
	stat_labels["demand"].text = str(GameState.guest_demand)
	stat_labels["staff"].text = str(StaffManager.staff_roster.size())
	stat_labels["capacity"].text = str(FacilityManager.get_total_capacity())

	_refresh_facilities()
	_refresh_staff()
	_refresh_reputation()
	_refresh_daily_summary()
	_refresh_event_log()
	_populate_assignment_menus()


func _refresh_facilities() -> void:
	facility_list.clear()
	for facility in FacilityManager.facilities:
		var assigned := StaffManager.get_staff_for_facility(int(facility.id)).size()
		facility_list.add_item("%s L%d | %s | cap %d | staff %d/%d | base %d cr" % [
			facility.name,
			int(facility.level),
			facility.district,
			int(facility.capacity),
			assigned,
			int(facility.staff_required),
			int(facility.base_income)
		])

	for project in FacilityManager.construction_queue:
		facility_list.add_item("[Building] %s | %d/%d days remaining" % [
			project.name,
			int(project.days_remaining),
			int(project.total_days)
		])


func _refresh_staff() -> void:
	staff_list.clear()
	for staff in StaffManager.staff_roster:
		var assignment := "Unassigned"
		var facility := FacilityManager.get_facility_by_id(int(staff.get("assigned_facility_id", -1)))
		if not facility.is_empty():
			assignment = facility.name

		staff_list.add_item("%s | %s %s | eff %.0f%% cha %.0f%% rel %.0f%% | stress %.0f%% | %s" % [
			staff.name,
			staff.category,
			staff.role,
			float(staff.efficiency) * 100.0,
			float(staff.charisma) * 100.0,
			float(staff.reliability) * 100.0,
			float(staff.stress) * 100.0,
			assignment
		])


func _refresh_reputation() -> void:
	reputation_list.clear()
	for line in ReputationManager.get_display_lines():
		reputation_list.add_item(line)


func _refresh_daily_summary() -> void:
	if GameState.last_day_summary.is_empty():
		daily_summary.text = "No day has been processed yet. Build, hire, assign, then advance the day."
		return

	var summary := GameState.last_day_summary
	var completed_names := []
	for facility in summary.get("construction_completed", []):
		completed_names.append(facility.name)

	daily_summary.text = "Day %d closed\nRevenue: %d cr\nExpenses: %d cr (Payroll %d, Upkeep %d)\nProfit: %+d cr\nGuests served: %d / demand %d\nConstruction completed: %s" % [
		int(summary.day),
		int(summary.revenue),
		int(summary.expenses),
		int(summary.payroll),
		int(summary.upkeep),
		int(summary.profit),
		int(summary.served_guests),
		int(summary.guest_demand),
		", ".join(completed_names) if not completed_names.is_empty() else "None"
	]


func _refresh_event_log() -> void:
	event_log.clear()
	for entry in EventManager.event_log:
		event_log.add_item("Day %d: %s" % [int(entry.day), entry.title])


func _on_advance_day_pressed() -> void:
	status_label.text = "Processing day..."
	GameState.advance_day()


func _on_save_pressed() -> void:
	var result := SaveManager.save_game()
	status_label.text = result.message


func _on_load_pressed() -> void:
	var result := SaveManager.load_game()
	status_label.text = result.message
	_refresh()


func _on_new_game_pressed() -> void:
	GameState.start_new_game()
	status_label.text = "New Avalon charter opened."
	_refresh()


func _on_build_pressed() -> void:
	if build_menu.selected < 0:
		return
	var definition_id := String(build_menu.get_item_metadata(build_menu.selected))
	var result := EconomyManager.build_facility(definition_id)
	status_label.text = result.message
	_refresh()


func _on_hire_pressed() -> void:
	if hire_menu.selected < 0:
		return
	var template_id := String(hire_menu.get_item_metadata(hire_menu.selected))
	var result := EconomyManager.hire_staff(template_id)
	status_label.text = result.message
	_refresh()


func _on_assign_pressed() -> void:
	if assign_staff_menu.selected < 0 or assign_facility_menu.selected < 0:
		return

	var staff_id := int(assign_staff_menu.get_item_metadata(assign_staff_menu.selected))
	var facility_id := int(assign_facility_menu.get_item_metadata(assign_facility_menu.selected))
	var result := EconomyManager.assign_staff(staff_id, facility_id)
	status_label.text = result.message
	_refresh()


func _on_day_advanced(summary: Dictionary) -> void:
	status_label.text = "Day %d complete. Profit: %+d cr." % [int(summary.day), int(summary.profit)]
	if summary.get("event", {}).get("triggered", false):
		var event: Dictionary = summary.event
		event_dialog.title = event.title
		event_dialog.dialog_text = event.description
		event_dialog.popup_centered(Vector2i(460, 220))
	_refresh()


func _on_transaction_completed(message: String) -> void:
	status_label.text = message


func _on_state_changed() -> void:
	_refresh()
