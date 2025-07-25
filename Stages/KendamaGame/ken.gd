extends CharacterBody2D

# Controlled with mouse movement
# The Ken follows the mouse cursor smoothly

var move_speed = 1000.0

func _physics_process(delta):
	var target = get_global_mouse_position()
	var direction = (target - global_position)
	if direction.length() > 1:
		direction = direction.normalized()
		self.velocity = direction * move_speed
	else:
		self.velocity = Vector2.ZERO
	move_and_slide()

func is_ken_tip():
	# This method identifies this as the Ken tip for collision detection
	return true
