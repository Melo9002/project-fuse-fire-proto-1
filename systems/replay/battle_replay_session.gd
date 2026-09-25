class_name BattleReplaySession
extends RefCounted

static var last_recording

static func store(recording) -> void:
	last_recording = recording

static func has_recording() -> bool:
	return last_recording != null and last_recording.is_playable()
