extends Node

signal key_collected

var has_key := false

func collect_key() -> void:
	has_key = true
	key_collected.emit()
