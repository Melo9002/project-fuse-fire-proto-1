class_name SpawnZone
extends Node3D

@export var faction: TacticalUnit.Faction = TacticalUnit.Faction.NEUTRAL

func get_spawn_transforms(count: int) -> Array[Transform3D]:
	var points: Array[Transform3D] = []
	for child in get_children():
		if child is Marker3D:
			points.append(child.global_transform)

	if count > points.size():
		push_error("SpawnZone %s has %d points but needs %d" % [name, points.size(), count])
		return []
	return points.slice(0, count)
