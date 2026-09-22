extends SceneTree

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	var scores: Array[float] = [100.0, 92.0, 60.0]
	for tier in [AIDifficultyPolicy.Tier.EASY, AIDifficultyPolicy.Tier.NORMAL]:
		var policy := AIDifficultyPolicy.create(tier)
		policy.lapse_chance = 1.0
		rng.seed = 12345
		assert(policy.choose_near_best_index(scores, rng) == 1)
		policy.lapse_chance = 0.0
		assert(policy.choose_near_best_index(scores, rng) == 0)
		policy.lapse_chance = 1.0
		assert(policy.choose_near_best_index([100.0, 60.0], rng) == 0)
	var hard := AIDifficultyPolicy.create(AIDifficultyPolicy.Tier.HARD)
	hard.lapse_chance = 1.0
	assert(hard.choose_near_best_index(scores, rng) == 0)
	print("[AI Intentional Mistakes] PASSED — bounded Easy/Normal alternatives; Hard always best")
	quit()
