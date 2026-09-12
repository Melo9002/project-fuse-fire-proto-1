class_name MapValidationResult
extends RefCounted

var errors: Array[MapValidationIssue] = []

func is_valid() -> bool:
	return errors.is_empty()

func add_error(code: String, message: String, cell := Vector3i.ZERO, has_cell: bool = false) -> void:
	errors.append(MapValidationIssue.new(code, message, cell, has_cell))

func has_code(code: String) -> bool:
	return errors.any(func(issue: MapValidationIssue) -> bool: return issue.code == code)

func describe() -> String:
	if is_valid():
		return "Map validation passed"
	var lines: Array[String] = []
	for issue in errors:
		lines.append(issue.describe())
	return "\n".join(lines)
