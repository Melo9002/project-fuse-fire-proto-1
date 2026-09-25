class_name MapQualityReport
extends RefCounted

var seed := 0
var source_kind := ""
var map_size := Vector2i.ZERO
var stoppable_cells := 0
var player_cover_access := 0.0
var enemy_cover_access := 0.0
var cover_fairness := 1.0
var player_route_options := 0.0
var enemy_route_options := 0.0
var route_fairness := 1.0
var open_space_ratio := 0.0
var largest_open_region_ratio := 0.0
var average_firing_lane := 0.0
var maximum_firing_lane := 0
var player_spawn_exposure := 0.0
var enemy_spawn_exposure := 0.0
var exposure_fairness := 1.0
var cover_score := 0.0
var route_score := 0.0
var open_space_score := 0.0
var firing_lane_score := 0.0
var spawn_safety_score := 0.0
var overall_score := 0.0

func category_scores() -> Dictionary[String, float]:
	return {
		"cover": cover_score,
		"routes": route_score,
		"open_space": open_space_score,
		"firing_lanes": firing_lane_score,
		"spawn_safety": spawn_safety_score,
	}

func weakest_category() -> String:
	var weakest := ""
	var weakest_score := INF
	for category in category_scores():
		var score: float = category_scores()[category]
		if score < weakest_score:
			weakest = category
			weakest_score = score
	return weakest

func calibration_summary() -> String:
	return "%dx%d | score %.0f | cover %.0f | routes %.0f | open %.0f | lanes %.0f | spawn safety %.0f | weakest %s" % [
		map_size.x, map_size.y, overall_score, cover_score, route_score, open_space_score,
		firing_lane_score, spawn_safety_score, weakest_category().replace("_", " "),
	]

func summary() -> String:
	return "score %.0f | cover P %.0f%% E %.0f%% fair %.0f%% | routes P %.1f E %.1f fair %.0f%% | open %.0f%% cluster %.0f%% | lanes %.1f/%d | exposure P %.0f%% E %.0f%% fair %.0f%%" % [
		overall_score,
		player_cover_access * 100.0, enemy_cover_access * 100.0, cover_fairness * 100.0,
		player_route_options, enemy_route_options, route_fairness * 100.0,
		open_space_ratio * 100.0, largest_open_region_ratio * 100.0,
		average_firing_lane, maximum_firing_lane,
		player_spawn_exposure * 100.0, enemy_spawn_exposure * 100.0, exposure_fairness * 100.0,
	]
