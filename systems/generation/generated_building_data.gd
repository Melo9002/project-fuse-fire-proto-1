class_name GeneratedBuildingData
extends RefCounted

var footprint: Rect2i
var roof_level: int
var ladder_ground_cell: Vector3i
var ladder_roof_cell: Vector3i
var reserved_area: Rect2i
var stair_cells: Array[Vector3i] = []
var stair_ground_cell: Vector3i
var upper_footprint := Rect2i()
var upper_cells: Array[Vector3i] = []
var upper_ladder_ground_cell: Vector3i
var upper_ladder_roof_cell: Vector3i

func _init(
	building_footprint: Rect2i,
	building_roof_level: int,
	ground_cell: Vector3i,
	roof_cell: Vector3i
) -> void:
	footprint = building_footprint
	reserved_area = footprint.grow(1)
	roof_level = building_roof_level
	ladder_ground_cell = ground_cell
	ladder_roof_cell = roof_cell
