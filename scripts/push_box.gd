extends CharacterBody2D

@export var friction := 0.92 

func _physics_process(_delta: float) -> void:
	velocity *= friction
	move_and_collide(velocity)

func push(force: Vector2) -> void:
	velocity += force
