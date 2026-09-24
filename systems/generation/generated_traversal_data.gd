class_name GeneratedTraversalData
extends RefCounted

enum Kind { LADDER, STAIRS, RAMP, BRIDGE }

var kind: Kind
var from_cell: Vector3i
var to_cell: Vector3i
var path_cells: Array[Vector3i] = []

func _init(type: Kind, start: Vector3i, end: Vector3i, cells: Array[Vector3i] = []) -> void:
	kind = type
	from_cell = start
	to_cell = end
	path_cells = cells

