extends GdUnitTestSuite

const PATH := "res://scripts/ui/material_speech.gd"

func _speech():
	assert_bool(ResourceLoader.exists(PATH)).is_true()
	if not ResourceLoader.exists(PATH):
		return null
	return auto_free(load(PATH).new())

func _ids(speech, source: String) -> Array[String]:
	var result: Array[String] = []
	for span: Dictionary in speech.material_spans(source):
		result.append(span.item_id)
	return result

func test_collection_names_resolve_to_their_catalog_icons() -> void:
	var speech = _speech()
	if speech == null: return
	assert_array(_ids(speech, "Raccogli 3 rame, 8 ferro e 1 cristallo. Quarzo e COBALTO.")) \
		.is_equal(["copper", "iron", "crystal", "silica", "cobalt"])

func test_plural_and_short_component_names_are_recognized() -> void:
	var speech = _speech()
	if speech == null: return
	var source := "Cristalli, componenti strutturali e componenti elettronici; 4 strutturali, 2 elettronici, un elettronico e un componente strutturale."
	assert_array(_ids(speech, source)).is_equal([
		"crystal", "structural_component", "electronic_component", "structural_component",
		"electronic_component", "electronic_component", "structural_component"])

func test_longest_material_name_wins_without_nested_copper_icon() -> void:
	var speech = _speech()
	if speech == null: return
	assert_array(_ids(speech, "Lingotto di rame, lingotti di rame, lingotto rame, vetro, rame.")) \
		.is_equal(["copper_ingot", "copper_ingot", "copper_ingot", "glass", "copper"])

func test_word_boundaries_exclude_unrelated_substrings_and_identifiers() -> void:
	var speech = _speech()
	if speech == null: return
	var source := "Ramerino, ferramenta, cristallino, acquaio, gasolio, rame_extra, 3rame, rame2, " + String.chr(233) + "rame. Dell'acqua, (rame) e ferro!"
	assert_array(_ids(speech, source)).is_equal(["water", "copper", "iron"])

func test_render_inserts_images_after_names_but_keeps_plain_source() -> void:
	var speech = _speech()
	if speech == null: return
	speech.text = "Raccogli 3 rame e 1 cristallo."
	assert_str(speech.text).is_equal("Raccogli 3 rame e 1 cristallo.")
	# Godot represents each inline image as a space in parsed text.
	assert_str(speech.rich_text.get_parsed_text()).is_equal(
		"Raccogli 3 rame   e 1 cristallo  .")
	assert_int(speech.rich_text.get_total_character_count()).is_equal(speech.text.length() + 4)

func test_literal_markup_is_not_interpreted() -> void:
	var speech = _speech()
	if speech == null: return
	speech.text = "[b]rame[/b] [img]res://anything.svg[/img]"
	assert_str(speech.rich_text.get_parsed_text()).is_equal(
		"[b]rame  [/b] [img]res://anything.svg[/img]")
	assert_bool(speech.rich_text.bbcode_enabled).is_false()

func test_repeat_and_replacement_do_not_accumulate_icons() -> void:
	var speech = _speech()
	if speech == null: return
	speech.text = "3 rame"
	var source: String = speech.text
	for index in range(3):
		speech.text = source
	assert_str(speech.rich_text.get_parsed_text()).is_equal("3 rame  ")
	speech.text = "Nessun materiale."
	assert_str(speech.rich_text.get_parsed_text()).is_equal("Nessun materiale.")
	speech.text = ""
	assert_str(speech.rich_text.get_parsed_text()).is_empty()

func test_speech_wraps_with_content_height_and_no_scrollbar() -> void:
	var speech = _speech()
	if speech == null: return
	assert_bool(speech.rich_text.fit_content).is_true()
	assert_bool(speech.rich_text.scroll_active).is_false()
	assert_int(speech.rich_text.autowrap_mode).is_equal(TextServer.AUTOWRAP_WORD_SMART)
	assert_int(speech.ICON_SIZE).is_between(18, 20)
