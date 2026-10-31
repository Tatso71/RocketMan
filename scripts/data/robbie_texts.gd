extends RefCounted

const PATH := "res://design/v1/robbie_texts.json"
static var cached: Dictionary = {}

static func validate(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("version") != 1 or not data.get("entries") is Array or data.entries.is_empty():
		return {}
	var result := {}
	for entry in data.entries:
		if not entry is Dictionary or not entry.get("id") is String or entry.id.is_empty() or result.has(entry.id):
			return {}
		for key: String in ["title", "body", "detail"]:
			if not entry.get(key) is String or (key != "detail" and entry[key].strip_edges().is_empty()):
				return {}
		if entry.has("robbie"):
			if not entry.robbie is Dictionary:
				return {}
			for key in entry.robbie:
				if key not in ["title", "body", "detail"] or not entry.robbie[key] is String or (key != "detail" and entry.robbie[key].strip_edges().is_empty()):
					return {}
		var priority = entry.get("priority")
		if not (priority is int or priority is float) or not is_finite(priority) or priority != floorf(priority) or priority < 0 or priority > 100:
			return {}
		result[entry.id] = entry.duplicate(true)
	return result

static func all() -> Dictionary:
	if cached.is_empty():
		cached = validate(JSON.parse_string(FileAccess.get_file_as_string(PATH)))
		if cached.is_empty():
			push_error("Catalogo testi Robbie non valido: " + PATH)
		else:
			cached = with_tutorial_defaults(cached)
	return cached

static func with_tutorial_defaults(entries: Dictionary) -> Dictionary:
	var result := entries.duplicate(true)
	var progression = JSON.parse_string(FileAccess.get_file_as_string("res://design/v1/progression.json"))
	if not progression is Dictionary:
		return result
	for step: Dictionary in progression.get("ocra_tutorial", {}).get("steps", []):
		var id := "ocra/" + str(step.id)
		if not result.has(id):
			result[id] = {"id": id, "priority": 65, "title": step.title_it, "body": step.hint_it, "detail": step.detail_it}
	return result

static func for_variant(entry: Dictionary, variant: String = "explorer") -> Dictionary:
	var result := entry.duplicate(true)
	if variant == "robbie":
		result.merge(entry.get("robbie", {}), true)
	return result

static func message(id: String, variant: String = "explorer") -> Array:
	var entry := for_variant(all().get(id, {}), variant)
	return [] if entry.is_empty() else [int(entry.priority), entry.title, entry.body]

static func tutorial_step(step: Dictionary, variant: String = "explorer") -> Dictionary:
	var entry := for_variant(all().get("ocra/" + str(step.id), {}), variant)
	if entry.is_empty():
		return step
	var result := step.duplicate(true)
	result.title_it = entry.title
	result.hint_it = entry.body
	result.detail_it = entry.detail
	return result

static func save_entries(entries: Array, expected_source: String, path: String = PATH) -> Error:
	var data := {"version": 1, "entries": entries}
	var validated := validate(data)
	if validated.is_empty():
		return ERR_INVALID_DATA
	if FileAccess.get_file_as_string(path) != expected_source:
		return ERR_ALREADY_IN_USE
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t", false) + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	var absolute := ProjectSettings.globalize_path(path)
	error = DirAccess.copy_absolute(absolute, absolute + ".bak")
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute)
	if error == OK and path == PATH:
		cached = with_tutorial_defaults(validated)
	return error
