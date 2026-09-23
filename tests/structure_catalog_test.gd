extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(DataCatalog.facilities.size() == 41, "loads exactly the 41 structures defined in the specification")
	_expect(not _has_category("research_and_development"), "does not invent Research & Development structures")

	var basic_hotel: Dictionary = DataCatalog.get_facility("basic_hotel")
	_expect(int(basic_hotel.get("build_cost", -1)) == 2500, "resolves Low build cost centrally")
	_expect(int(DataCatalog.get_facility("bar").get("capacity", -1)) == 10, "resolves Low-to-Medium capacity by range")
	_expect(not DataCatalog.get_facility("medical_center").has("build_cost"), "leaves incomplete Medical Center values unset")
	_expect(not bool(DataCatalog.get_facility("medical_center").get("buildable", true)), "marks incomplete Medical Center non-buildable")

	GameState.start_new_game()
	_expect(FacilityManager.facilities.size() == 1, "starts with one facility")
	_expect(String(FacilityManager.facilities[0].definition_id) == "basic_hotel", "uses Basic Hotel as the starter structure")

	_complete_facility("rented_mansion")
	var mansion: Dictionary = FacilityManager.facilities[-1]
	var mode_result: Dictionary = FacilityManager.set_work_mode(int(mansion.id), "card_service")
	_expect(bool(mode_result.get("success", false)), "changes a configurable work mode")
	_expect(String(mansion.get("work_mode", "")) == "card_service", "stores selected work mode on the facility")

	_complete_facility("small_power_station")
	var operations: Dictionary = FacilityManager.calculate_daily_operations(GameState.guest_demand)
	_expect(int(operations.get("utility_totals", {}).get("power_production", 0)) == 10, "reports provisional utility production without requiring a grid simulation")

	var save_path := "user://structure_catalog_test_save.json"
	var save_result: Dictionary = SaveManager.save_game(save_path)
	_expect(bool(save_result.get("success", false)), "saves extended facility state")
	mansion.work_mode = "arcana_service"
	var load_result: Dictionary = SaveManager.load_game(save_path)
	_expect(bool(load_result.get("success", false)), "loads extended facility state")
	var loaded_mansion: Dictionary = FacilityManager.get_facility_by_id(int(mansion.id))
	_expect(String(loaded_mansion.get("work_mode", "")) == "card_service", "round-trips work mode through save/load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if failures == 0:
		print("Structure catalog checks passed (41 definitions, tiers, modes, utilities, save/load).")
	else:
		push_error("%d structure catalog check(s) failed." % failures)
	get_tree().quit(failures)


func _complete_facility(definition_id: String) -> void:
	var result: Dictionary = FacilityManager.queue_construction(definition_id)
	_expect(bool(result.get("success", false)), "queues %s" % definition_id)
	for _day in range(int(result.get("project", {}).get("total_days", 1))):
		FacilityManager.progress_construction()


func _has_category(category_name: String) -> bool:
	for definition in DataCatalog.facilities:
		if String(definition.get("category", "")) == category_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAILED: %s" % message)
