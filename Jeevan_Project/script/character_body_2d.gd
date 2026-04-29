extends CharacterBody2D

const SPEED = 300.0

func _physics_process(delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction != Vector2.ZERO:
		# 1. ROTATION: This points the character where they are moving
		rotation = direction.angle()
		
		# 2. MOVEMENT
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO

	move_and_slide()
