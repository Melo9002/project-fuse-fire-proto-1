extends Decal
class_name GridCursor

@export var grid_manager: GridManager
@export var highlight_color: Color = Color(1.0, 0.0, 0.0, 0.4)

func _ready() -> void:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(highlight_color)
	self.texture_albedo = ImageTexture.create_from_image(image)
	
	var c_size = grid_manager.cell_size if grid_manager else 1.0
	self.size = Vector3(c_size, 2.0, c_size)

func update_hover_position(raw_position: Vector3) -> void:
	if not grid_manager:
		return
		
	var center = grid_manager.get_tile_center(raw_position)
	# Position Decal box center slightly above tile top so it projects cleanly
	global_position = Vector3(center.x, center.y + 0.5, center.z)
