class_name MapValidationIssue
extends RefCounted

var code: String
var message: String
var cell: Vector3i
var has_cell: bool

func _init(issue_code: String, issue_message: String, issue_cell := Vector3i.ZERO, includes_cell: bool = false) -> void:
	code = issue_code
	message = issue_message
	cell = issue_cell
	has_cell = includes_cell

func describe() -> String:
	return "[%s] %s%s" % [code, message, " at %s" % cell if has_cell else ""]
