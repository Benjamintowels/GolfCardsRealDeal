extends Node2D

# Shop height for collision detection
var height: float = 350.0  # Shop height (ball needs to be above this to pass over)

# Returns the Y-sorting reference point (base of shop building)
func get_y_sort_point() -> float:
	# Use the YsortPoint node for consistent Y-sorting reference
	var ysort_point_node = get_node_or_null("YsortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		# Fallback to the collision area position
		return global_position.y - 1.43885

func _ready():
	# Connect to Area2D's area_entered signal for collision detection with Area2D balls
	var shop_base_area = get_node_or_null("ShopBaseArea")
	
	if shop_base_area:
		# Use area_entered for shop collisions (since golf ball uses Area2D for all collisions)
		shop_base_area.connect("area_entered", _on_shop_area_entered)
		# Set collision layer to 1 so golf balls can detect it
		shop_base_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		shop_base_area.collision_mask = 1
		print("✓ Shop Area2D setup complete for collision detection")
	else:
		print("✗ ERROR: ShopBaseArea not found!")
	
	# Deferred call to double-check collision layers after the scene is fully set up
	call_deferred("_verify_collision_setup")
	
	# Ensure z_index is properly set for Ysort
	call_deferred("_update_ysort")

func _on_shop_area_entered(area: Area2D):
	"""Handle collisions with the shop base area (ground-level collision)"""
	var ball = area.get_parent()
	
	print("=== SHOP AREA ENTERED ===")
	print("Area name:", area.name)
	print("Ball parent:", ball.name if ball else "No parent")
	print("Ball type:", ball.get_class() if ball else "Unknown")
	print("Ball position:", ball.global_position if ball else "Unknown")
	print("Shop position:", global_position)
	print("Distance to shop:", ball.global_position.distance_to(global_position) if ball else "Unknown")
	
	if ball and (ball.name == "GolfBall" or ball.name == "GhostBall" or ball.has_method("is_throwing_knife")):
		print("✓ Valid ball/knife detected:", ball.name)
		# Handle the collision - always reflect for ground-level shop collisions
		_handle_shop_collision(ball)
	else:
		print("✗ Invalid ball/knife or non-ball object:", ball.name if ball else "Unknown")
	
	print("=== END SHOP AREA ENTERED ===")

func _handle_shop_collision(ball: Node2D):
	"""Handle shop base collisions - check height to determine if ball should pass through"""
	print("=== HANDLING SHOP COLLISION ===")
	print("Ball/knife name:", ball.name)
	print("Ball/knife type:", ball.get_class())
	
	# Use enhanced height collision detection with TopHeight markers
	if Global.is_object_above_obstacle(ball, self):
		# Ball/knife is above the shop entirely - let it pass through
		print("✓ Ball/knife is above shop entirely - passing through")
		print("=== END SHOP COLLISION (PASSED THROUGH) ===")
		return
	else:
		# Ball/knife is within or below shop height - handle collision
		print("✗ Ball/knife is within shop height - handling collision")
		
		# Check if this is a throwing knife
		if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
			# Handle knife collision with shop
			print("Handling knife shop collision")
			_handle_knife_shop_collision(ball)
		else:
			# Handle regular ball collision
			print("Handling ball shop collision")
			_handle_ball_shop_collision(ball)
		
		print("=== END SHOP COLLISION (COLLIDED) ===")

func _handle_knife_shop_collision(knife: Node2D):
	"""Handle knife collision with shop"""
	print("Handling knife shop collision")
	
	# Let the knife handle its own collision logic
	# The knife will determine if it should bounce or stick based on which side hits
	if knife.has_method("_handle_shop_collision"):
		knife._handle_shop_collision(self)
	else:
		# Fallback: just reflect the knife
		_reflect_knife_pinball(knife)

func _handle_ball_shop_collision(ball: Node2D):
	"""Handle ball collision with shop"""
	print("Handling ball shop collision")
	
	# Reflect the ball
	_reflect_ball_pinball(ball)

func _reflect_ball_pinball(ball: Node2D):
	"""Special reflection for low-height collisions with shop base - creates pinball effect"""
	# Get the ball's current velocity
	var ball_velocity = Vector2.ZERO
	if ball.has_method("get_velocity"):
		ball_velocity = ball.get_velocity()
	elif "velocity" in ball:
		ball_velocity = ball.velocity
	
	print("Reflecting ball with velocity:", ball_velocity)
	
	var ball_pos = ball.global_position
	var shop_center = global_position
	
	# Calculate the direction from shop center to ball
	var to_ball_direction = (ball_pos - shop_center).normalized()
	
	# Simple reflection: reflect the velocity across the shop center
	# This creates a more predictable pinball effect
	var reflected_velocity = ball_velocity - 2 * ball_velocity.dot(to_ball_direction) * to_ball_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Reflected velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the ball
	if ball.has_method("set_velocity"):
		ball.set_velocity(reflected_velocity)
	elif "velocity" in ball:
		ball.velocity = reflected_velocity

func _reflect_knife_pinball(knife: Node2D):
	"""Special reflection for knife collisions with shop base - creates pinball effect"""
	# Get the knife's current velocity
	var knife_velocity = Vector2.ZERO
	if knife.has_method("get_velocity"):
		knife_velocity = knife.get_velocity()
	elif "velocity" in knife:
		knife_velocity = knife.velocity
	
	print("Reflecting knife with velocity:", knife_velocity)
	
	var knife_pos = knife.global_position
	var shop_center = global_position
	
	# Calculate the direction from shop center to knife
	var to_knife_direction = (knife_pos - shop_center).normalized()
	
	# Simple reflection: reflect the velocity across the shop center
	# This creates a more predictable pinball effect
	var reflected_velocity = knife_velocity - 2 * knife_velocity.dot(to_knife_direction) * to_knife_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Reflected knife velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the knife
	if knife.has_method("set_velocity"):
		knife.set_velocity(reflected_velocity)
	elif "velocity" in knife:
		knife.velocity = reflected_velocity

func _verify_collision_setup():
	"""Verify that collision layers are properly set up"""
	var shop_base_area = get_node_or_null("ShopBaseArea")
	if shop_base_area:
		print("Shop collision layer:", shop_base_area.collision_layer)
		print("Shop collision mask:", shop_base_area.collision_mask)
		
		# Check collision shape
		var collision_shape = shop_base_area.get_node_or_null("ShopBase")
		if collision_shape:
			print("Shop collision shape size:", collision_shape.shape.size)
			print("Shop collision shape scale:", collision_shape.scale)
			print("Shop collision shape position:", collision_shape.position)
			var actual_size = collision_shape.shape.size * collision_shape.scale
			print("Shop actual collision area size:", actual_size)
		else:
			print("ERROR: ShopBase collision shape not found!")
	else:
		print("ERROR: ShopBaseArea not found during verification!")

func _update_ysort():
	"""Update the Shop's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")
	
	# Only print debug info once
	if not has_meta("ysort_update_printed"):
		print("Shop Ysort updated - z_index:", z_index, " global_position:", global_position)
		set_meta("ysort_update_printed", true)
