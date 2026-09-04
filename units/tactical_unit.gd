extends Node3D
class_name TacticalUnit

enum Faction { PLAYER, ENEMY, ALLY, NEUTRAL }

signal movement_finished
signal defeated(unit: TacticalUnit)

@export var movement_speed: float = 5.0
@export var move_range: int = 10
@export var attack_range: int = 3
@export var faction: Faction = Faction.PLAYER
@export var stats: UnitStats
@export var unit_hud_scene: PackedScene = preload("res://ui/unit_world_bar.tscn")

var current_path: PackedVector3Array = PackedVector3Array()
var current_waypoint_idx: int = 0
var is_moving: bool = false

func _ready() -> void:
	if stats:
		stats.defeated.connect(_on_stats_defeated)
	_spawn_world_hud()

func _on_stats_defeated() -> void:
	defeated.emit(self)

func _process(delta: float) -> void:
	if not is_moving: 
		return
		
	if current_waypoint_idx >= current_path.size():
		is_moving = false
		movement_finished.emit() 
		return
		
	var target_waypoint = current_path[current_waypoint_idx]
	target_waypoint.y = global_position.y
	
	global_position = global_position.move_toward(target_waypoint, movement_speed * delta)
	
	if global_position.distance_to(target_waypoint) < 0.01:
		current_waypoint_idx += 1

func move_along_path(path: PackedVector3Array) -> void:
	if path.size() == 0: 
		return
	current_path = path
	current_waypoint_idx = 0
	is_moving = true

func finish_movement(old_grid: Vector3i, new_grid: Vector3i, grid_manager: GridManager) -> void:
	if is_instance_valid(grid_manager):
		grid_manager.update_unit_position(self, old_grid, new_grid)
	movement_finished.emit()

func _spawn_world_hud() -> void:
	if not unit_hud_scene:
		push_warning("[TacticalUnit] %s: unit_hud_scene is missing!" % name)
		return
	if not stats:
		push_warning("[TacticalUnit] %s: stats component reference is missing!" % name)
		return
		
	var ui_layer: Node = get_tree().get_first_node_in_group("UI_LAYER")
	if not ui_layer:
		push_error("[TacticalUnit] %s: No CanvasLayer found in 'UI_LAYER' group!" % name)
		return

	var hud_instance: UnitWorldBar = unit_hud_scene.instantiate() as UnitWorldBar
	if hud_instance:
		ui_layer.add_child(hud_instance)
		hud_instance.setup(self, stats, faction)
