extends Node

const SAVE_DIR := "user://saves"
const CONFIG_DIR := "user://config"
const PRIMARY_SAVE_PATH := SAVE_DIR + "/slot_01.json"
const SETTINGS_PATH := CONFIG_DIR + "/settings.json"

func _ready() -> void:
	ensure_storage_dirs()

func ensure_storage_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(CONFIG_DIR)

func write_primary_save(data: Dictionary) -> bool:
	return _write_json(PRIMARY_SAVE_PATH, data)

func read_primary_save() -> Dictionary:
	return _read_json(PRIMARY_SAVE_PATH)

func write_settings(data: Dictionary) -> bool:
	return _write_json(SETTINGS_PATH, data)

func read_settings() -> Dictionary:
	return _read_json(SETTINGS_PATH)

func _write_json(path: String, data: Dictionary) -> bool:
	ensure_storage_dirs()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open JSON file for writing: %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open JSON file for reading: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON dictionary in file: %s" % path)
		return {}
	return parsed
