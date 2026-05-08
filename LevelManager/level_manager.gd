extends Node

const LEVELS = [
	"res://levels/level_1.tscn",
	"res://levels/level_2.tscn",
	"res://levels/level1.tscn"
	
	# todo : add more levels
]

var current_level_index : int = 0
var highest_unlocked    : int = 0  # 0 = only level 1 unlocked

func go_to_level(index: int) -> void:
	current_level_index = index
	get_tree().call_deferred("change_scene_to_file", LEVELS[index])

func reload_current() -> void:
	get_tree().call_deferred("change_scene_to_file", LEVELS[current_level_index])

func complete_current_level() -> void:
	if current_level_index >= highest_unlocked:
		highest_unlocked = current_level_index + 1

	if current_level_index + 1 < LEVELS.size():
		go_to_level(current_level_index + 1)
	else:
		get_tree().call_deferred("change_scene_to_file", "res://LevelManager/main_menu.tscn")
