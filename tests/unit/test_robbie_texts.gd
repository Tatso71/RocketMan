extends GdUnitTestSuite

const Texts = preload("res://scripts/data/robbie_texts.gd")
const Guide = preload("res://scripts/systems/drone_guide_state.gd")
const Tutorial = preload("res://scripts/systems/ocra_tutorial.gd")

func test_all_balloon_and_tutorial_texts_have_stable_editable_ids() -> void:
	assert_int(Texts.all().size()).is_greater_equal(42)
	var guide := Guide.new()
	for id: String in Texts.all():
		assert_array(guide.message(id)).is_not_empty()
	for step: Dictionary in Tutorial.new().definition.steps:
		assert_bool(Texts.all().has("ocra/" + step.id)).is_true()
		assert_str(Texts.tutorial_step(step).hint_it).is_equal(Texts.message("ocra/" + step.id)[2])

func test_text_validation_rejects_duplicates_empty_text_and_invalid_priority() -> void:
	var entries := Texts.all().values().duplicate(true)
	entries.append(entries[0])
	assert_dict(Texts.validate({"version": 1, "entries": entries})).is_empty()
	entries.pop_back()
	entries[0].body = " "
	assert_dict(Texts.validate({"version": 1, "entries": entries})).is_empty()
	entries[0].body = "Prova"
	entries[0].priority = 101
	assert_dict(Texts.validate({"version": 1, "entries": entries})).is_empty()

func test_save_keeps_backup_and_never_overwrites_external_edits() -> void:
	var path := "res://reports/robbie-text-test.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("original")
	file.close()
	var entries := Texts.all().values().duplicate(true)
	entries[0].body = "Un messaggio di prova."
	assert_int(Texts.save_entries(entries, "original", path)).is_equal(OK)
	assert_str(FileAccess.get_file_as_string(path + ".bak")).is_equal("original")
	var saved := FileAccess.get_file_as_string(path)
	assert_str(Texts.validate(JSON.parse_string(saved))[entries[0].id].body).is_equal("Un messaggio di prova.")
	assert_int(Texts.save_entries(entries, "stale source", path)).is_equal(ERR_ALREADY_IN_USE)
	assert_str(FileAccess.get_file_as_string(path)).is_equal(saved)

func test_same_catalog_drives_real_balloon_and_objective_copy() -> void:
	var original := Texts.all().duplicate(true)
	var tutorial := Tutorial.new()
	var step: Dictionary = tutorial.current()
	Texts.cached.welcome.body = "Una frase aggiornata."
	Texts.cached["ocra/" + step.id].title = "Obiettivo aggiornato"
	Texts.cached["ocra/" + step.id].detail = "Dettaglio aggiornato"
	var guide := Guide.new()
	assert_str(guide.message("welcome")[2]).is_equal("Una frase aggiornata.")
	assert_str(guide.message("ocra/" + step.id)[1]).is_equal("Obiettivo aggiornato")
	assert_str(tutorial.current().title_it).is_equal("Obiettivo aggiornato")
	assert_str(tutorial.current().detail_it).is_equal("Dettaglio aggiornato")
	Texts.cached = original

func test_new_tutorial_steps_are_available_without_manual_catalog_duplication() -> void:
	var defaults := Texts.with_tutorial_defaults({})
	for step: Dictionary in Tutorial.new().definition.steps:
		assert_bool(defaults.has("ocra/" + step.id)).is_true()
		assert_str(defaults["ocra/" + step.id].body).is_equal(step.hint_it)
