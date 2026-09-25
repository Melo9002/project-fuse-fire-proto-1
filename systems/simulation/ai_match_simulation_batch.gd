class_name AIMatchSimulationBatch
extends RefCounted

var results: Array[AIMatchSimulationResult] = []

func add(result: AIMatchSimulationResult) -> void:
	results.append(result)

func completed_count() -> int:
	return results.filter(func(result: AIMatchSimulationResult): return result.completed()).size()

func issue_count() -> int:
	return results.size() - completed_count()

func average_rounds() -> float:
	if results.is_empty():
		return 0.0
	var total := 0
	for result in results:
		total += result.rounds
	return float(total) / float(results.size())

func summary() -> String:
	return "%d matches | %d completed | %d issues | %.1f average rounds" % [results.size(), completed_count(), issue_count(), average_rounds()]
