extends Node3D
class_name PathVisualizer

@export var grid_manager: GridManager
@export_range(0.0, 0.3, 0.01) var tile_padding: float = 0.08

var range_mesh_instance: MeshInstance3D
var path_mesh_instance: MeshInstance3D

func _ready() -> void:
	range_mesh_instance = MeshInstance3D.new()
	add_child(range_mesh_instance)
	
	path_mesh_instance = MeshInstance3D.new()
	add_child(path_mesh_instance)

func draw_range_zone(grid_positions: Array[Vector3i], color: Color) -> void:
	if grid_positions.is_empty() or not grid_manager:
		clear_range_zone()
		return
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var visual_cell_size = grid_manager.cell_size * (1.0 - tile_padding)
	var half = visual_cell_size / 2.0

	for pos in grid_positions:
		var world_pos = grid_manager.grid_to_world(pos)
		# Offset Y dynamically above floor surface
		var y = world_pos.y + 0.03
		
		var v1 = Vector3(world_pos.x - half, y, world_pos.z - half)
		var v2 = Vector3(world_pos.x + half, y, world_pos.z - half)
		var v3 = Vector3(world_pos.x + half, y, world_pos.z + half)
		var v4 = Vector3(world_pos.x - half, y, world_pos.z + half)
		
		st.add_vertex(v1); st.add_vertex(v2); st.add_vertex(v3)
		st.add_vertex(v1); st.add_vertex(v3); st.add_vertex(v4)
		
	st.generate_normals()
	range_mesh_instance.mesh = st.commit()
	range_mesh_instance.material_override = _create_material(color)

func draw_path(path_vectors: PackedVector3Array, color: Color) -> void:
	if path_vectors.size() < 1 or not grid_manager:
		clear_path()
		return
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var visual_cell_size = grid_manager.cell_size * (1.0 - tile_padding)
	var half = visual_cell_size / 2.0

	for pos in path_vectors:
		# Layer blue path (+0.06) slightly higher than yellow zone (+0.03) to prevent Z-fighting
		var y = pos.y + 0.06
		
		var v1 = Vector3(pos.x - half, y, pos.z - half)
		var v2 = Vector3(pos.x + half, y, pos.z - half)
		var v3 = Vector3(pos.x + half, y, pos.z + half)
		var v4 = Vector3(pos.x - half, y, pos.z + half)
		
		st.add_vertex(v1); st.add_vertex(v2); st.add_vertex(v3)
		st.add_vertex(v1); st.add_vertex(v3); st.add_vertex(v4)
		
	st.generate_normals()
	path_mesh_instance.mesh = st.commit()
	path_mesh_instance.material_override = _create_material(color)

func _create_material(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.resource_local_to_scene = true
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = StandardMaterial3D.CULL_DISABLED
	return mat

func clear_range_zone() -> void:
	range_mesh_instance.mesh = null

func clear_path() -> void:
	path_mesh_instance.mesh = null
