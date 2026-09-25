extends SceneTree

var failures := 0

func _init() -> void:
	var reports: Array[MapQualityReport] = []
	for dimensions in FlatMapGenerator.MAP_SIZES:
		for map_seed in range(23000, 23020):
			reports.append(_check_map(dimensions, map_seed, false))
	for map_seed in range(23100, 23120):
		reports.append(_check_map(Vector2i(40, 30), map_seed, true))
	var lowest_score := 100.0
	var highest_score := 0.0
	for report in reports:
		lowest_score = minf(lowest_score, report.overall_score)
		highest_score = maxf(highest_score, report.overall_score)
	print("[MapQuality] Tested %d maps; score range %.0f–%.0f; %d failures" % [reports.size(), lowest_score, highest_score, failures])
	_print_calibration_report(reports)
	quit(1 if failures else 0)

func _print_calibration_report(reports: Array[MapQualityReport]) -> void:
	reports.sort_custom(func(first: MapQualityReport, second: MapQualityReport) -> bool: return first.overall_score < second.overall_score)
	var category_names: Array[String] = ["cover", "routes", "open_space", "firing_lanes", "spawn_safety"]
	for category in category_names:
		var minimum := 100.0
		var maximum := 0.0
		var total := 0.0
		for report in reports:
			var score: float = report.category_scores()[category]
			minimum = minf(minimum, score)
			maximum = maxf(maximum, score)
			total += score
		var diagnostic := " | NO DISCRIMINATION" if is_equal_approx(minimum, maximum) else ""
		print("[MapQuality] CATEGORY %s — average %.0f | range %.0f–%.0f%s" % [category.replace("_", " "), total / float(reports.size()), minimum, maximum, diagnostic])
	var representative_indices: Array[int] = [0, reports.size() / 2, reports.size() - 1]
	var labels: Array[String] = ["LOW", "MIDDLE", "HIGH"]
	for index in representative_indices.size():
		var report := reports[representative_indices[index]]
		print("[MapQuality] REPRESENTATIVE %s — seed %d | %s | %s" % [labels[index], report.map_seed, report.source_kind, report.calibration_summary()])

func _check_map(dimensions: Vector2i, map_seed: int, refinery: bool) -> MapQualityReport:
	var data := FlatMapGenerator.generate_with_cover(dimensions.x, dimensions.y, 1.0, map_seed, 5, refinery)
	var graph := Pathfinder.new()
	MapGraphBuilder.build(data, graph)
	var report := MapQualityEvaluator.evaluate(data, graph)
	var repeated := MapQualityEvaluator.evaluate(data, graph)
	check(report.stoppable_cells > 0, map_seed, "counts stoppable terrain")
	check(report.map_size == dimensions, map_seed, "records map dimensions for reproduction")
	for value in [report.player_cover_access, report.enemy_cover_access, report.cover_fairness, report.open_space_ratio, report.largest_open_region_ratio, report.player_spawn_exposure, report.enemy_spawn_exposure, report.exposure_fairness]:
		check(is_finite(value) and value >= 0.0 and value <= 1.0, map_seed, "keeps normalized metrics in range")
	check(report.player_route_options > 0.0 and report.enemy_route_options > 0.0, map_seed, "finds viable route branches for both factions")
	check(report.route_fairness >= 0.0 and report.route_fairness <= 1.0, map_seed, "normalizes route fairness")
	check(report.average_firing_lane > 0.0 and report.maximum_firing_lane >= roundi(report.average_firing_lane), map_seed, "measures firing lanes")
	check(report.largest_open_region_ratio <= report.open_space_ratio, map_seed, "keeps the largest open region within total open space")
	check(is_finite(report.overall_score) and report.overall_score >= 0.0 and report.overall_score <= 100.0, map_seed, "produces a bounded quality score")
	for score in report.category_scores().values():
		check(is_finite(score) and score >= 0.0 and score <= 100.0, map_seed, "produces bounded category scores")
	check(not report.weakest_category().is_empty(), map_seed, "identifies its weakest category")
	check(not report.summary().is_empty(), map_seed, "produces readable debug output")
	check(report.summary() == repeated.summary(), map_seed, "repeats metrics deterministically")
	var player_spawn := data.get_spawn_cells(TacticalUnit.Faction.PLAYER)[0]
	var enemy_spawn := data.get_spawn_cells(TacticalUnit.Faction.ENEMY)[0]
	check(not graph.calculate_3d_path(player_spawn, enemy_spawn).is_empty(), map_seed, "leaves the path graph unchanged")
	return report

func check(condition: bool, map_seed: int, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("Seed %d %s" % [map_seed, message])
