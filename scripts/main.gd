extends Node

const DASHBOARD_SCENE := preload("res://ui/dashboard.tscn")


func _ready() -> void:
	if not DataCatalog.is_loaded:
		DataCatalog.load_all()

	GameState.ensure_initialized()

	var dashboard := DASHBOARD_SCENE.instantiate()
	add_child(dashboard)
