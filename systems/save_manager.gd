extends Node

signal game_saved(path)
signal game_loaded(path)

const SAVE_PATH := "user://avalon_save.json"


func save_game(path: String = SAVE_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "message": "Unable to open save file."}

	file.store_string(JSON.stringify(GameState.get_state(), "\t"))
	game_saved.emit(path)
	return {"success": true, "message": "Game saved."}


func load_game(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"success": false, "message": "No save file found."}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "message": "Unable to read save file."}

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"success": false, "message": "Save file is not valid."}

	GameState.load_state(parsed)
	game_loaded.emit(path)
	return {"success": true, "message": "Game loaded."}
