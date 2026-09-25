class_name BattleReplayPlayer
extends Node

const StateFingerprint := preload("res://systems/replay/battle_state_fingerprint.gd")

signal playback_finished(success: bool)

var recording
var level: BattleLevel
var action_delay := 0.18
var playback_complete := false
var playback_succeeded := false
var verified_actions := 0

func begin(p_level: BattleLevel, p_recording) -> void:
	level = p_level
	recording = p_recording
	_play.call_deferred()

func _play() -> void:
	print("[Replay] PLAYBACK — %d actions" % recording.actions.size())
	for index in recording.actions.size():
		if level.turn_manager.battle_result != TurnManager.BattleResult.ONGOING:
			break
		var record: Dictionary = recording.actions[index]
		var expected_state: String = record.get("expected_state", "")
		var state_before := StateFingerprint.capture(level.turn_manager, level.battle_controller.grid_manager, level.objective_manager)
		# Some gameplay signals commit an automatic action while their enclosing action is
		# still finishing. If the earlier replayed action already produced this exact
		# authoritative state, the nested record has already been applied.
		if not expected_state.is_empty() and state_before == expected_state:
			verified_actions += 1
			print("[Replay] COALESCED — action %d (%s) was already applied by gameplay rules" % [index, record.get("kind", "unknown")])
			await get_tree().create_timer(action_delay).timeout
			continue
		if not await _execute(record):
			push_error("Replay diverged at action %d: %s" % [index, record])
			playback_complete = true
			playback_finished.emit(false)
			return
		var actual_state := StateFingerprint.capture(level.turn_manager, level.battle_controller.grid_manager, level.objective_manager)
		if not expected_state.is_empty() and actual_state != expected_state:
			push_error("Replay state diverged at action %d (%s by %s).\nExpected: %s\nActual:   %s" % [index, record.get("kind", "unknown"), record.get("actor", ""), expected_state, actual_state])
			playback_complete = true
			playback_finished.emit(false)
			return
		verified_actions += 1
		await get_tree().create_timer(action_delay).timeout
	var matches: bool = level.turn_manager.battle_result == recording.expected_result
	print("[Replay] %s — verified %d/%d actions | expected %s, got %s" % [
		"COMPLETED" if matches else "DIVERGED",
		verified_actions, recording.actions.size(),
		TurnManager.BattleResult.keys()[recording.expected_result],
		TurnManager.BattleResult.keys()[level.turn_manager.battle_result],
	])
	playback_complete = true
	playback_succeeded = matches
	playback_finished.emit(matches)

func _execute(record: Dictionary) -> bool:
	var kind: String = record.get("kind", "")
	if kind == "end_turn":
		level.turn_manager.end_current_turn()
		return true
	var actor: TacticalUnit = _find_unit(record.get("actor", ""))
	if not is_instance_valid(actor):
		return false
	if not _activate(actor):
		print("[Replay] ACTOR REJECTED — wanted %s | active %s | phase %s" % [
			actor.name,
			_active_unit_name(),
			TurnManager.TurnPhase.keys()[level.turn_manager.current_phase],
		])
		return false
	match kind:
		"move":
			var destination := _array_to_cell(record.get("to", []))
			var moved := await level.battle_controller.try_move(actor, destination)
			if not moved:
				print("[Replay] MOVE REJECTED — actor %s at %s | destination %s | active %s | phase %s | AP %d" % [
					actor.name, level.battle_controller.grid_manager.get_unit_grid(actor), destination,
					_active_unit_name(),
					TurnManager.TurnPhase.keys()[level.turn_manager.current_phase], actor.stats.current_ap,
				])
			return moved
		"attack":
			var target: TacticalUnit = _find_unit(record.get("target", ""))
			if not is_instance_valid(target):
				return false
			return level.battle_controller.try_attack(actor, target)
		"defend":
			return level.battle_controller.try_defend(actor)
		"rescue":
			var target: TacticalUnit = _find_unit(record.get("target", ""))
			return is_instance_valid(target) and level.objective_manager.try_rescue(actor, target)
		"extract":
			return level.objective_manager.try_extract(actor)
	return false

func _activate(actor: TacticalUnit) -> bool:
	if level.turn_manager.active_unit == actor:
		return true
	if level.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_TURN:
		return level.turn_manager.select_player_unit(actor)
	return false

func _find_unit(unit_name: String) -> TacticalUnit:
	var candidate := level.find_child(unit_name, true, false)
	return candidate as TacticalUnit

func _active_unit_name() -> String:
	if is_instance_valid(level.turn_manager.active_unit):
		return String(level.turn_manager.active_unit.name)
	return "none"

func _array_to_cell(value: Variant) -> Vector3i:
	if value is Array and value.size() == 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	return Vector3i(-1, -1, -1)
