class_name GeneratedTerrainPresenter
extends RefCounted

static func build(map_data: MapData, parent: Node3D, cell_size: float) -> void:
	for cell: MapCellData in map_data.cells.values():
		if cell.cover_type == MapCellData.CoverType.NONE:
			continue
		var block := MeshInstance3D.new()
		block.name = "Cover_%d_%d_%d" % [cell.grid_position.x, cell.grid_position.y, cell.grid_position.z]
		var box := BoxMesh.new()
		box.size = Vector3(cell_size * 0.9, cell.cover_height, cell_size * 0.9)
		block.mesh = box
		block.position = cell.world_position + Vector3.UP * cell.cover_height * 0.5
		block.material_override = _material_for(cell.cover_type)
		block.set_meta("grid_position", cell.grid_position)
		block.set_meta("cover_type", cell.cover_type)
		parent.add_child(block)

static func _material_for(cover_type: MapCellData.CoverType) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.08, 0.08) if cover_type == MapCellData.CoverType.LOW else Color(0.32, 0.015, 0.015)
	material.roughness = 0.82
	return material
