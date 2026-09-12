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
var use_generated_map: bool = false
var generation_seed: int = 1

func configure(player_count: int, enemy_count: int, generate_map: bool = false, seed: int = 1) -> void:
	player_unit_count = clampi(player_count, 1, 5)
	enemy_unit_count = clampi(enemy_count, 1, 5)
	use_generated_map = generate_map
	generation_seed = seed

func _ready() -> void:
	if use_generated_map:
		_set_authored_geometry_enabled(false)
		var grid := battle_controller.grid_manager
		var width := int(grid.map_floor.size.x / grid.cell_size)
		var depth := int(grid.map_floor.size.z / grid.cell_size)
		var generated_map := FlatMapGenerator.generate_with_cover(width, depth, grid.cell_size, generation_seed, 5)
		var generated_geometry := Node3D.new()
		generated_geometry.name = "GeneratedTerrain"
		add_child(generated_geometry)
		GeneratedTerrainPresenter.build(generated_map, generated_geometry, grid.cell_size)
		_spawn_generated_team(player_unit_count, TacticalUnit.Faction.PLAYER, player_units_parent, generated_map)
		_spawn_generated_team(enemy_unit_count, TacticalUnit.Faction.ENEMY, enemy_units_parent, generated_map)
		var cover_counts := _count_cover(generated_map)
		print_rich("[color=cyan][MapGenerator][/color] COVER — seed %d, %dx%d, %d low, %d full" % [generation_seed, width, depth, cover_counts.x, cover_counts.y])
		await battle_controller.initialize_battle(generated_map)
	else:
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
		var unit := _create_unit("%sUnit%d" % ["Enemy" if add_ai else "Player", index + 1], zone.faction, parent)
		unit.global_transform = spawn_transforms[index]
		_register_team_unit(unit)

func _spawn_generated_team(count: int, faction: TacticalUnit.Faction, parent: Node3D, map_data: MapData) -> void:
	var spawn_cells := map_data.get_spawn_cells(faction)
	if spawn_cells.size() < count:
		push_error("Generated map has insufficient faction %s spawns" % faction)
		return
	for index in count:
		var unit := _create_unit("%sUnit%d" % ["Enemy" if faction == TacticalUnit.Faction.ENEMY else "Player", index + 1], faction, parent)
		unit.global_position = map_data.get_cell(spawn_cells[index]).world_position + Vector3.UP * unit.standing_height
		_register_team_unit(unit)

func _create_unit(unit_name: String, faction: TacticalUnit.Faction, parent: Node3D) -> TacticalUnit:
	var unit = unit_scene.instantiate() as TacticalUnit
	unit.name = unit_name
	unit.faction = faction
	unit.attack_range = test_battle_attack_range
	parent.add_child(unit)
	var ai := AIController.new()
	ai.name = "%sAI" % unit_name
	ai.unit = unit
	ai.turn_manager = turn_manager
	ai.battle_controller = battle_controller
	parent.add_child(ai)
	return unit

func _register_team_unit(unit: TacticalUnit) -> void:
	if unit.faction == TacticalUnit.Faction.ENEMY:
		turn_manager.enemy_units.append(unit)
	else:
		turn_manager.player_units.append(unit)

func _set_authored_geometry_enabled(enabled: bool) -> void:
	for group_name in ["terrain_features", "elevated_surfaces", "elevation_paths", "traversal_links"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node3D:
				(node as Node3D).visible = enabled
			_set_collision_enabled(node, enabled)

func _set_collision_enabled(node: Node, enabled: bool) -> void:
	if node is CSGShape3D:
		(node as CSGShape3D).use_collision = enabled
	for child in node.get_children():
		_set_collision_enabled(child, enabled)

func _count_cover(map_data: MapData) -> Vector2i:
	var counts := Vector2i.ZERO
	for cell: MapCellData in map_data.cells.values():
		if cell.cover_type == MapCellData.CoverType.LOW:
			counts.x += 1
		elif cell.cover_type == MapCellData.CoverType.FULL:
			counts.y += 1
	return counts
