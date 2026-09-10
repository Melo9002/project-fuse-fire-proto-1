class_name BattleLevel
extends Node3D

@export var unit_scene: PackedScene
@export var player_spawn_zone: SpawnZone
@export var enemy_spawn_zone: SpawnZone
@export var player_units_parent: Node3D
@export var enemy_units_parent: Node3D
@export var turn_manager: TurnManager
@export var battle_controller: BattleController
@export_range(1, 20, 1) var test_battle_attack_range: int = 5

var player_unit_count: int = 2
var enemy_unit_count: int = 2

func configure(player_count: int, enemy_count: int) -> void:
	player_unit_count = clampi(player_count, 1, 5)
	enemy_unit_count = clampi(enemy_count, 1, 5)

func _ready() -> void:
	_spawn_team(player_unit_count, player_spawn_zone, player_units_parent, false)
	_spawn_team(enemy_unit_count, enemy_spawn_zone, enemy_units_parent, true)
	await battle_controller.initialize_battle()

func _spawn_team(count: int, zone: SpawnZone, parent: Node3D, add_ai: bool) -> void:
	if not unit_scene or not zone or not parent or not turn_manager:
		push_error("BattleLevel: missing unit-spawning dependencies")
		return

	var spawn_transforms = zone.get_spawn_transforms(count)
	if spawn_transforms.size() != count:
		return

	for index in count:
		var unit = unit_scene.instantiate() as TacticalUnit
		unit.name = "%sUnit%d" % ["Enemy" if add_ai else "Player", index + 1]
		unit.faction = zone.faction
		unit.attack_range = test_battle_attack_range
		parent.add_child(unit)
		unit.global_transform = spawn_transforms[index]
		var ai = AIController.new()
		ai.name = "AIController%d" % (index + 1)
		ai.unit = unit
		ai.turn_manager = turn_manager
		ai.battle_controller = battle_controller
		parent.add_child(ai)

		if add_ai:
			turn_manager.enemy_units.append(unit)
		else:
			turn_manager.player_units.append(unit)
