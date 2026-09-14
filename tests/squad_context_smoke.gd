extends SceneTree

var failures := 0

func _initialize() -> void:
	var context := SquadContext.new()
	var first := TacticalUnit.new()
	first.name = "First"
	var second := TacticalUnit.new()
	second.name = "Second"
	var target := TacticalUnit.new()
	target.name = "Target"

	context.begin_round(1)
	context.reserve_destination(first, Vector3i(5, 0, 5))
	check(context.destination_adjustment(second, Vector3i(5, 0, 5)) <= -1000.0, "An ally's exact destination is unavailable")
	check(context.destination_adjustment(second, Vector3i(5, 0, 6)) == -12.0, "A neighboring reservation discourages crowding")
	context.reserve_target(first, target)
	check(context.target_adjustment(second, target) == -15.0, "Existing allied focus softly reduces target score")
	check(context.target_adjustment(first, target) == 0.0, "A unit does not penalize its own continuing target intent")
	check(context.reserve_objective(first, &"rescue") == 0, "The first objective handler has no duplication penalty")
	check(context.reserve_objective(second, &"rescue") == 1, "Later units see an existing objective handler")

	context.begin_round(2)
	check(context.reserved_destinations.is_empty() and context.intended_targets.is_empty() and context.objective_handlers.is_empty(), "Squad intentions reset for a new round")
	first.free()
	second.free()
	target.free()
	print("Squad context smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
