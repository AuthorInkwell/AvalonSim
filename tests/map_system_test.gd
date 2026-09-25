extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameState.start_new_game()
	_expect(MapManager.terrain.size() == MapManager.MAP_HEIGHT, "generates the complete island terrain grid")
	_expect(MapManager.get_terrain(Vector2i(0, 0)) == MapManager.TERRAIN_WATER, "marks the outer map as coastline water")
	_expect(MapManager.get_terrain(Vector2i(36, 9)) == MapManager.TERRAIN_MOUNTAIN, "reserves an extreme-height mountain area")
	_expect(MapManager.placements.size() == 1, "places the authoritative starter hotel on the map")
	_expect(MapManager.facility_has_road_access(FacilityManager.facilities[0]), "gives the starter hotel road access")

	var hotel := DataCatalog.get_facility("basic_hotel")
	_expect(MapManager.get_footprint(hotel, 0) == Vector2i(3, 2), "uses a data-derived multi-tile hotel footprint")
	_expect(MapManager.get_footprint(hotel, 1) == Vector2i(2, 3), "rotates rectangular footprints")
	_expect(not MapManager.can_place_facility("cafe", MapManager.STARTER_POSITION, 0).get("success", true), "rejects overlapping construction")
	_expect(not MapManager.can_place_facility("cafe", Vector2i(0, 0), 0).get("success", true), "rejects construction in water")

	var funds_before := GameState.funds
	var road_result := EconomyManager.place_road(Vector2i(31, 16))
	_expect(road_result.get("success", false), "places a road on open flat land")
	_expect(GameState.funds == funds_before - EconomyManager.ROAD_COST, "charges the road tile cost")

	var build_result := EconomyManager.place_facility("cafe", Vector2i(26, 17), 1)
	_expect(build_result.get("success", false), "places a facility construction footprint")
	_expect(FacilityManager.construction_queue.size() == 1, "keeps construction in the existing simulation queue")
	_expect(MapManager.placements.size() == 2, "reserves the construction footprint spatially")
	_expect(MapManager.placements[-1].get("kind", "") == "construction", "renders queued work as construction")

	var demands := GameState.get_category_demand()
	for key in ["lodgings", "attractions", "amenities", "utility", "support", "research_and_development"]:
		_expect(demands.has(key), "reports %s demand" % key)

	var funds_before_loan := GameState.funds
	var loan_result := EconomyManager.take_loan()
	_expect(loan_result.get("success", false), "takes a simple playtest loan")
	_expect(GameState.funds == funds_before_loan + EconomyManager.LOAN_PRINCIPAL, "credits the loan principal immediately")
	_expect(GameState.loan_balance == EconomyManager.LOAN_TOTAL_REPAYMENT, "records principal plus flat interest as the balance")
	_expect(not EconomyManager.take_loan().get("success", true), "prevents stacking another loan while one is outstanding")

	var summary := GameState.advance_day()
	_expect(summary.get("construction_completed", []).size() == 1, "completes the one-day cafe through Advance Day")
	_expect(int(summary.get("loan_payment", 0)) == EconomyManager.LOAN_DAILY_PAYMENT, "includes the daily loan payment in expenses")
	_expect(GameState.loan_balance == EconomyManager.LOAN_TOTAL_REPAYMENT - EconomyManager.LOAN_DAILY_PAYMENT, "reduces the outstanding balance each day")
	_expect(FacilityManager.facilities.size() == 2, "adds the completed map building to authoritative facilities")
	_expect(MapManager.placements[-1].get("kind", "") == "facility", "converts construction into an operating map building")
	var cafe: Dictionary = FacilityManager.facilities[-1]
	_expect(cafe.get("map_position", []) == [26, 17], "links the completed facility back to its map position")
	_expect(MapManager.facility_has_road_access(cafe), "recognizes adjacent road access")

	var save_path := "user://map_system_test_save.json"
	var saved_placements := MapManager.placements.duplicate(true)
	_expect(SaveManager.save_game(save_path).get("success", false), "saves spatial map state")
	MapManager.roads.clear()
	MapManager.placements.clear()
	GameState.loan_balance = 0
	GameState.loan_daily_payment = 0
	_expect(SaveManager.load_game(save_path).get("success", false), "loads spatial map state")
	_expect(MapManager.placements.size() == saved_placements.size(), "round-trips the placement count")
	_expect(MapManager.placements[-1].get("definition_id", "") == "cafe", "round-trips placement identity")
	var loaded_position: Array = MapManager.placements[-1].get("position", [])
	_expect(loaded_position.size() == 2 and int(loaded_position[0]) == 26 and int(loaded_position[1]) == 17, "round-trips placement coordinates")
	_expect(MapManager.has_road(Vector2i(31, 16)), "round-trips road tiles")
	_expect(GameState.loan_balance == EconomyManager.LOAN_TOTAL_REPAYMENT - EconomyManager.LOAN_DAILY_PAYMENT, "round-trips the outstanding loan balance")
	_expect(GameState.loan_daily_payment == EconomyManager.LOAN_DAILY_PAYMENT, "round-trips the loan payment terms")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if failures == 0:
		print("Map system checks passed (terrain, footprints, roads, construction, demand, save/load).")
	else:
		push_error("%d map system check(s) failed." % failures)
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAILED: %s" % message)
