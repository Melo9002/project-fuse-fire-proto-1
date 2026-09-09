class_name TerrainFeature
extends Node3D

@export var cover_type: MapCellData.CoverType = MapCellData.CoverType.NONE
@export_range(0.0, 10.0, 0.1, "suffix:m") var cover_height: float = 0.0
@export var blocks_line_of_sight: bool = false
@export_range(1, 10, 1) var movement_cost: int = 1

