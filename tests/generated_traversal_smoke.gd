extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	for map_seed in range(1, 101):
		var data := FlatMapGenerator.generate_with_cover(40, 30, 1.0, map_seed, 5, true)
		var graph := Pathfinder.new()
		MapGraphBuilder.build(data, graph)
		check(data.source_kind == "generated_refinery", "Special map identifies itself as a refinery")
		check(data.platforms.size() >= 3, "Refinery generates at least three elevated platforms")
		check(data.platforms.any(func(platform: GeneratedPlatformData) -> bool: return platform.elevation_level >= 5), "Refinery tower tops provide high ground")
		check(data.generated_traversals.size() == data.platforms.size() + 2, "Every refinery platform receives access plus two fixed catwalks")
		check(data.generated_traversals.filter(func(item: GeneratedTraversalData) -> bool: return item.kind == GeneratedTraversalData.Kind.BRIDGE).size() == 2, "Refinery contains two fixed catwalks")
		var validation := MapValidator.validate(data, graph)
		check(validation.is_valid(), "Refinery seed %d passes shared validation: %s" % [map_seed, validation.describe()])
		for traversal in data.generated_traversals:
			check(not graph.calculate_3d_path(traversal.from_cell, traversal.to_cell).is_empty(), "Seed %d traversal %d connects %s to %s" % [map_seed, traversal.kind, traversal.from_cell, traversal.to_cell])
			check(data.get_cell(traversal.from_cell).can_stop, "Traversal approach remains a legal stopping cell")
			check(data.get_cell(traversal.to_cell).can_stop, "Traversal landing remains a legal stopping cell")
		for platform in data.platforms.filter(func(item: GeneratedPlatformData) -> bool: return item.elevation_level >= 5):
			check(data.generated_traversals.any(func(item: GeneratedTraversalData) -> bool: return item.kind == GeneratedTraversalData.Kind.STAIRS and platform.footprint.has_point(Vector2i(item.to_cell.x, item.to_cell.z))), "Each refinery tower cap has stair access")

	var level := load("res://levels/prototype_map/prototype_map.tscn").instantiate() as BattleLevel
	level.configure(2, 2, true, 24680, 0, Vector2i(40, 30), false, MissionActor.VIPBehavior.PLAYER_CONTROLLED, null, AIDifficultyPolicy.Tier.NORMAL, true)
	root.add_child(level)
	await create_timer(0.2).timeout
	var data := level.battle_controller.grid_manager.map_data
	var terrain := level.get_node("GeneratedTerrain")
	var traversal_nodes := terrain.get_children().filter(func(child: Node) -> bool: return child.name.begins_with("Traversal_"))
	check(traversal_nodes.size() == data.generated_traversals.size(), "Presenter draws every refinery traversal")
	level.queue_free()
	await process_frame
	print("Generated traversal: 100 refinery seeds; %d failures" % failures)
	quit(1 if failures else 0)
