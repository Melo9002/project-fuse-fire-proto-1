extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var previous_time_scale := Engine.time_scale
	Engine.time_scale = 12.0
	var simulator := AIMatchSimulator.new()
	root.add_child(simulator)
	var config := {
		"seed": 23231,
		"generated_map": false,
		"mission_kind": MissionObjectiveDefinition.Kind.ELIMINATE,
		"player_count": 2,
		"enemy_count": 2,
		"maximum_rounds": 20,
		"stall_seconds": 4.0,
		"timeout_seconds": 20.0,
	}
	var first := await simulator.run_match(config)
	var second := await simulator.run_match(config)
	Engine.time_scale = previous_time_scale
	var matches := first.status == second.status \
		and first.battle_result == second.battle_result \
		and first.rounds == second.rounds \
		and first.decision_count == second.decision_count \
		and first.decision_records.size() == first.decision_count \
		and second.decision_records.size() == second.decision_count \
		and first.decision_records == second.decision_records
	print("[AISim] AUTHORED-MAP DETERMINISM — %s" % ("PASSED" if matches else "FAILED"))
	if not matches:
		push_error("Repeated match diverged:\n  %s\n  %s" % [first.summary(), second.summary()])
	quit(0 if matches else 1)
