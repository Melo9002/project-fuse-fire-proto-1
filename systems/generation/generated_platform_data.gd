class_name GeneratedPlatformData
extends RefCounted

var footprint: Rect2i
var elevation_level: int
var cells: Array[Vector3i] = []
var reserved_area: Rect2i

func _init(platform_footprint: Rect2i, level: int) -> void:
	footprint = platform_footprint
	elevation_level = level
	reserved_area = footprint.grow(1)

