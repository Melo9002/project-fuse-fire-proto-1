extends Node3D
class_name PathVisualizer

@export var cell_size: float = 1.0

var range_mesh_instance: MeshInstance3D
var path_mesh_instance: MeshInstance3D

func _ready() -> void:
	# Initialize our display layers
	range_mesh_instance = MeshInstance3D.new()
	add_child(range_mesh_instance)
	
	path_mesh_instance = MeshInstance3D.new()
	add_child(path_mesh_instance)

func draw_range_zone(grid_positions: Array[Vector3i], color: Color) -> void:
	if grid_positions.is_empty():
		clear_range_zone()
		return
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var pf = get_parent().get("pathfinder")
	if not pf: return
	
	var half = cell_size / 2.0
	var y = 0.05 # Keep it low but visible

	for pos in grid_positions:
		if not pf.grid_to_id_map.has(pos): continue
		var world_pos = pf.astar.get_point_position(pf.grid_to_id_map[pos])
		
		var v1 = Vector3(world_pos.x - half, y, world_pos.z - half)
		var v2 = Vector3(world_pos.x + half, y, world_pos.z - half)
		var v3 = Vector3(world_pos.x + half, y, world_pos.z + half)
		var v4 = Vector3(world_pos.x - half, y, world_pos.z + half)
		
		# Define two triangles explicitly (ensuring they face UP)
		st.add_vertex(v1); st.add_vertex(v2); st.add_vertex(v3)
		st.add_vertex(v1); st.add_vertex(v3); st.add_vertex(v4)
		
	st.generate_normals()
	range_mesh_instance.mesh = st.commit()
	
	# FORCE material to be double-sided so it can't be culled
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = StandardMaterial3D.CULL_DISABLED # <--- THIS IS THE KEY!
	range_mesh_instance.material_override = mat

func draw_path(path_vectors: PackedVector3Array, color: Color) -> void:
	if path_vectors.size() < 2:
		clear_path()
		return
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var thick = cell_size * 0.2
	var y = 0.15 # Slightly higher than the range zone so it sits on top
	
	for i in range(path_vectors.size() - 1):
		var p1 = Vector3(path_vectors[i].x, y, path_vectors[i].z)
		var p2 = Vector3(path_vectors[i+1].x, y, path_vectors[i+1].z)
		
		var dir = (p2 - p1).normalized()
		var lat = Vector3(-dir.z, 0, dir.x) * thick
		
		st.add_triangle_fan([p1 - lat, p1 + lat, p2 + lat])
		st.add_triangle_fan([p1 - lat, p2 + lat, p2 - lat])
		
	st.generate_normals()
	path_mesh_instance.mesh = st.commit()
	path_mesh_instance.material_override = _create_material(color)

func _create_material(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.resource_local_to_scene = true # <--- THIS IS THE MAGIC FIX
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = StandardMaterial3D.CULL_DISABLED
	return mat

func clear_range_zone() -> void:
	range_mesh_instance.mesh = null

func clear_path() -> void:
	path_mesh_instance.mesh = null
