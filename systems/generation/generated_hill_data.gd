class_name GeneratedHillData
extends RefCounted

var footprint: Rect2i
var surface_cells: Array[Vector3i] = []
var reserved_area: Rect2i

func _init(hill_footprint: Rect2i) -> void:
	footprint = hill_footprint
	reserved_area = footprint.grow(1)

