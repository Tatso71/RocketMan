extends GdUnitTestSuite

const Factory = preload("res://scripts/systems/fabrication_state.gd")

func test_component_job_batches_and_ready_buffer_survive_json() -> void:
	var state := Factory.new()
	var saved := state.snapshot()
	saved.jobs = [{"id": "electronic_component", "level": 1, "station": ["ship"], "elapsed": 1.5, "seconds": 6.0, "batches": 3}]
	saved.outputs = [{"station": ["laboratory", -5, 1], "stock": {"structural_component": 6}}]
	var accepted: bool = state.restore(JSON.parse_string(JSON.stringify(saved)))
	assert_bool(accepted).is_true()
	if not accepted:
		return
	assert_int(state.jobs[0].batches).is_equal(3)
	assert_int(state.snapshot().outputs[0].stock.structural_component).is_equal(6)
	var before := state.snapshot()
	saved = before.duplicate(true)
	saved.jobs[0].batches = 0
	assert_bool(state.restore(saved)).is_false()
	assert_dict(state.snapshot()).is_equal(before)
	saved = before.duplicate(true)
	saved.outputs[0].stock = {"copper": 100}
	assert_bool(state.restore(saved)).is_false()
