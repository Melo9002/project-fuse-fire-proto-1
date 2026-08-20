extends Node3D
class_name TacticalUnit

# --- 1. THE SIGNAL ---
# This is the "radio" the BattleController listens for
signal movement_finished 

@export var movement_speed: float = 5.0
@export var move_range: int = 20

var current_path: PackedVector3Array = PackedVector3Array()
var current_waypoint_idx: int = 0
var is_moving: bool = false
var current_ap: int = 1 

func move_along_path(path: PackedVector3Array) -> void:
	if path.size() == 0: return
	current_path = path
	current_waypoint_idx = 0
	is_moving = true

func _process(delta: float) -> void:
	if not is_moving: return
		
	# Check if we reached the end of the path
	if current_waypoint_idx >= current_path.size():
		is_moving = false
		# --- 2. THE EMITTER ---
		# Broadcast to the BattleController that we have arrived!
		movement_finished.emit() 
		return
		
	var target_waypoint = current_path[current_waypoint_idx]
	target_waypoint.y = global_position.y
	
	global_position = global_position.move_toward(target_waypoint, movement_speed * delta)
	
	if global_position.distance_to(target_waypoint) < 0.01:
		current_waypoint_idx += 1
