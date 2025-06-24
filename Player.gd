extends CharacterBody2D

const SPEED := 200.0   # pixels per second

func _physics_process(delta):
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
	)
	velocity = input.normalized() * SPEED
	move_and_slide()
