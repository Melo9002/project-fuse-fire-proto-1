class_name TraversalLinkData
extends RefCounted

var from_cell: Vector3i
var to_cell: Vector3i
var bidirectional: bool

func _init(start: Vector3i, end: Vector3i, two_way: bool = true) -> void:
	from_cell = start
	to_cell = end
	bidirectional = two_way
