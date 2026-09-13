class_name MissionObjectiveState
extends RefCounted

enum Status {
	ACTIVE,
	COMPLETED,
	FAILED,
}

var definition: MissionObjectiveDefinition
var progress := 0
var status: Status = Status.ACTIVE

func _init(objective_definition: MissionObjectiveDefinition) -> void:
	definition = objective_definition

func is_active() -> bool:
	return status == Status.ACTIVE

func is_completed() -> bool:
	return status == Status.COMPLETED

func is_failed() -> bool:
	return status == Status.FAILED

func get_progress_ratio() -> float:
	return float(progress) / float(definition.target_amount)
