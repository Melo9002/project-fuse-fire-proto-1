extends SceneTree

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var first_seed := _positive_argument(arguments, 0, 1)
	var seed_count := _positive_argument(arguments, 1, 100)
	var started_at := Time.get_ticks_msec()
	var report := MapBatchTester.run(first_seed, seed_count)
	var elapsed_seconds := float(Time.get_ticks_msec() - started_at) / 1000.0

	print("[MapBatch] Tested %d seeds (%d through %d) in %.2fs" % [
		report.seed_count,
		report.first_seed,
		report.first_seed + report.seed_count - 1,
		elapsed_seconds,
	])
	print("[MapBatch] Low cover min/avg/max: %d / %.1f / %d" % [report.minimum_low_cover, report.average_low_cover(), report.maximum_low_cover])
	print("[MapBatch] Full cover min/avg/max: %d / %.1f / %d" % [report.minimum_full_cover, report.average_full_cover(), report.maximum_full_cover])
	print("[MapBatch] Cohesive cover min/avg/max: %d / %.1f / %d" % [report.minimum_cohesive_cover, report.average_cohesive_cover(), report.maximum_cohesive_cover])
	if report.passed():
		print("[MapBatch] PASSED — all %d maps are valid" % report.seed_count)
		quit(0)
		return

	for map_seed in report.failures:
		print("[MapBatch] FAILED seed %d" % map_seed)
		for message in report.failures[map_seed]:
			print("  %s" % message)
	print("[MapBatch] FAILED — %d of %d maps are invalid" % [report.failures.size(), report.seed_count])
	quit(1)

func _positive_argument(arguments: PackedStringArray, index: int, fallback: int) -> int:
	if index >= arguments.size() or not arguments[index].is_valid_int():
		return fallback
	return maxi(1, arguments[index].to_int())
