class_name ElevationPath
extends Node3D

@export var start_cell: Vector3i
@export var direction: Vector3i = Vector3i.FORWARD
@export_range(1, 12, 1) var step_count: int = 4
@export_range(1, 10, 1) var start_elevation: int = 1
@export_range(1, 4, 1) var elevation_per_step: int = 1
@export var blocks_ground: bool = true

func _ready() -> void:
	add_to_group("elevation_paths")

func get_cells() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for index in step_count:
		var horizontal = Vector3i(start_cell.x, 0, start_cell.z) + direction * index
		result.append(Vector3i(horizontal.x, start_elevation + elevation_per_step * index, horizontal.z))
	return result
