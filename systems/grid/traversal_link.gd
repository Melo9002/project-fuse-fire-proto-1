class_name TraversalLink
extends Node3D

@export var from_cell: Vector3i
@export var to_cell: Vector3i
@export var bidirectional: bool = true

func _ready() -> void:
	add_to_group("traversal_links")

func to_data() -> TraversalLinkData:
	return TraversalLinkData.new(from_cell, to_cell, bidirectional)
