class_name TerrainFeature
extends Node3D

@export var cover_type: MapCellData.CoverType = MapCellData.CoverType.NONE
@export_range(0.0, 10.0, 0.1, "suffix:m") var cover_height: float = 0.0
@export var blocks_line_of_sight: bool = false
@export_range(1, 10, 1) var movement_cost: int = 1

func _ready() -> void:
	add_to_group("terrain_features")

func covers_position(world_position: Vector3) -> bool:
	var feature_size = get("size")
	if not feature_size is Vector3:
		return false
	var local_position = to_local(world_position)
	return absf(local_position.x) <= feature_size.x * 0.5 \
		and absf(local_position.z) <= feature_size.z * 0.5 \
		and world_position.y < global_position.y + feature_size.y * 0.5
