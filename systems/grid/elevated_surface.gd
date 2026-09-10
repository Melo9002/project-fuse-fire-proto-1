class_name ElevatedSurface
extends CSGBox3D

@export_range(1, 20, 1) var elevation_level: int = 1
@export var blocks_ground: bool = true

func _ready() -> void:
	add_to_group("elevated_surfaces")

func covers_position(world_position: Vector3) -> bool:
	var local_position = to_local(world_position)
	return absf(local_position.x) <= size.x * 0.5 \
		and absf(local_position.z) <= size.z * 0.5
