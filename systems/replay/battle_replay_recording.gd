class_name BattleReplayRecording
extends RefCounted

var configuration: Dictionary = {}
var actions: Array[Dictionary] = []
var expected_result := TurnManager.BattleResult.ONGOING

func append_action(record: Dictionary) -> void:
	actions.append(record.duplicate(true))

func is_playable() -> bool:
	return not configuration.is_empty() and not actions.is_empty()
