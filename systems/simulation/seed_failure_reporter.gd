class_name SeedFailureReporter
extends RefCounted

const DEFAULT_DIRECTORY := "user://ai_sim_failure_reports"

static func save(result: AIMatchSimulationResult, directory: String = DEFAULT_DIRECTORY) -> String:
	if result.completed():
		return ""
	var absolute_directory := ProjectSettings.globalize_path(directory)
	var error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if error != OK:
		push_error("Could not create AI simulation failure-report directory: %s" % absolute_directory)
		return ""
	var filename := "seed_%d_%s_%s.json" % [result.seed, _safe_name(result.mission_id), result.status_label().to_lower()]
	var path := directory.path_join(filename)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Could not write AI simulation failure report: %s" % ProjectSettings.globalize_path(path))
		return ""
	file.store_string(JSON.stringify(result.reproduction_data(), "  "))
	file.close()
	result.failure_report_path = ProjectSettings.globalize_path(path)
	return result.failure_report_path

static func _safe_name(value: StringName) -> String:
	var text := String(value).to_lower()
	for character in ["/", "\\", ":", " "]:
		text = text.replace(character, "_")
	return text
