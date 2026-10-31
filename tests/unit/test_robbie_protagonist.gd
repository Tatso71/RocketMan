extends GdUnitTestSuite

const Expedition = preload("res://scripts/systems/expedition_state.gd")
const Crew = preload("res://scripts/data/cryo_crew.gd")
const Rooms = preload("res://scripts/ui/ship_rooms.gd")
const Texts = preload("res://scripts/data/robbie_texts.gd")
const Guide = preload("res://scripts/systems/drone_guide_state.gd")
const Saves = preload("res://scripts/core/save_manager.gd")

func test_variant_can_only_be_chosen_before_the_first_flight() -> void:
	var state := Expedition.new()
	assert_bool(state.choose_variant("robbie")).is_true()
	assert_bool(state.arrive_immediately()).is_true()
	assert_bool(state.choose_variant("explorer")).is_false()
	assert_str(state.variant).is_equal("robbie")
	assert_bool(state.takeoff()).is_true()
	state.advance(3)
	assert_bool(state.choose_variant("explorer")).is_false()

func test_variant_roundtrips_and_old_campaigns_stay_explorer_mode() -> void:
	var state := Expedition.new()
	state.choose_variant("robbie")
	var loaded := Expedition.new()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state.snapshot()))
	assert_bool(loaded.restore(saved)).is_true()
	assert_str(loaded.variant).is_equal("robbie")
	var legacy := Expedition.new().snapshot()
	legacy.erase("variant")
	assert_bool(loaded.restore(legacy)).is_true()
	assert_str(loaded.variant).is_equal("explorer")
	legacy.variant = "unknown"
	assert_bool(loaded.restore(legacy)).is_false()
	assert_str(loaded.variant).is_equal("explorer")

func test_crew_has_two_specialists_and_one_cat_in_nonoverlapping_capsules() -> void:
	assert_int(Crew.MEMBERS.size()).is_equal(3)
	assert_str(Crew.MEMBERS[0].role).contains("biomedicina")
	assert_str(Crew.MEMBERS[1].role).contains("chimica")
	assert_str(Crew.MEMBERS[2].species).is_equal("cat")
	for index in range(3):
		assert_bool(Rooms.BEDROOM.encloses(Crew.capsule(index))).is_true()
		assert_bool(Crew.capsule(index).end.x < 80).is_true()
		for other in range(index):
			assert_bool(Crew.capsule(index).intersects(Crew.capsule(other))).is_false()

func test_variant_saves_use_different_paths_without_changing_legacy_slots() -> void:
	assert_str(Saves.variant_path("user://saves/campaign_v1.json", "explorer")).is_equal("user://saves/campaign_v1.json")
	assert_str(Saves.variant_path("user://saves/campaign_v1.json", "robbie")).is_equal("user://saves/campaign_v1_robbie.json")

func test_diagnostics_keep_stable_ids_and_use_the_selected_voice() -> void:
	var guide := Guide.new()
	var original := guide.message("first_dig")
	assert_str(original[2]).contains("aspettami")
	guide.variant = "robbie"
	assert_str(guide.message("first_dig")[2]).contains("direttamente nel mio cargo")
	assert_str(guide.message("water_danger")[2]).contains("mia scocca")
	assert_str(guide.message("ocra/reach_workshop")[2]).contains("criosonno")
	assert_array(Texts.message("first_dig")).is_equal(original)

func test_text_validation_rejects_invalid_variant_copy() -> void:
	var data := {"version": 1, "entries": [Texts.all().welcome.duplicate(true)]}
	data.entries[0].robbie = {"body": ""}
	assert_dict(Texts.validate(data)).is_empty()
	data.entries[0].robbie = {"unknown": "value"}
	assert_dict(Texts.validate(data)).is_empty()
