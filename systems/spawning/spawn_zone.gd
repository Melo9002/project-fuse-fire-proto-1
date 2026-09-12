class_name SpawnZone
extends Node3D

@export var faction: TacticalUnit.Faction = TacticalUnit.Faction.NEUTRAL
@export_range(0.0, 5.0, 0.1) var marker_height_offset: float = 1.0

func _ready() -> void:
	add_to_group("spawn_zones")

func get_spawn_transforms(count: int) -> Array[Transform3D]:
	var points: Array[Transform3D] = []
	for child in get_children():
		if child is Marker3D:
			points.append(child.global_transform)

	if count > points.size():
		push_error("SpawnZone %s has %d points but needs %d" % [name, points.size(), count])
		return []
	return points.slice(0, count)

func get_spawn_cells(grid: GridManager) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for child in get_children():
		if child is Marker3D:
			cells.append(grid.world_to_grid(child.global_position - Vector3.UP * marker_height_offset))
	return cells
