class_name MapZoneData
extends RefCounted

enum Kind { DEPLOYMENT, OBJECTIVE, EXTRACTION }

var zone_id: StringName
var kind: Kind
var cells: Array[Vector3i] = []
var faction: int = -1

func _init(id: StringName, zone_kind: Kind, zone_cells: Array[Vector3i] = [], owner_faction := -1) -> void:
	zone_id = id
	kind = zone_kind
	cells = zone_cells.duplicate()
	faction = owner_faction
