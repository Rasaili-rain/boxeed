# LightCone.gd
extends Area2D

@export var cone_color: Color = Color(1.0, 1.0, 0.0, 0.18)

@onready var _visual: Polygon2D = $Polygon2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_visual.color = cone_color

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.is_boxed or body.is_morphing:
			return
		body.die()
