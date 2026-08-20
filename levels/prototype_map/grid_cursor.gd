extends Decal
class_name GridCursor

@export var cell_size: float = 1.0
@export var highlight_color: Color = Color(1.0, 0.0, 0.0, 0.4) # Semi-transparent Red

func _ready() -> void:
	# --- RUNTIME TEXTURE GENERATION ---
	# We create a 16x16 pixel flat texture entirely in RAM so we don't need image files
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(highlight_color)
	
	var texture := ImageTexture.create_from_image(image)
	
	# Apply this procedural color texture to the Decal projector slot
	self.texture_albedo = texture
	
	# Match the physical bounds of the projector box to our exact grid cell scale
	# Decal size takes a Vector3: (Width, Height/Depth of projection box, Length)
	self.size = Vector3(cell_size, 2.0, cell_size)

# This function takes the raw mouse hover position and snaps the cursor to that cell center
func update_hover_position(raw_position: Vector3) -> void:
	var half_cell = cell_size / 2.0
	
	var snapped_x = floor(raw_position.x / cell_size) * cell_size + half_cell
	var snapped_z = floor(raw_position.z / cell_size) * cell_size + half_cell
	
	# Decals project downwards, so we place it slightly above the floor (Y: 1.0)
	# This ensures the light completely envelopes the floor plane without clipping
	global_position = Vector3(snapped_x, 0.1, snapped_z)
