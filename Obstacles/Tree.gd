extends CharacterBody2D

var blocks_movement := true  # Trees block by default; water might not

func blocks(): 
	return blocks_movement

# Returns the Y-sorting reference point (base of trunk)
func get_y_sort_point() -> float:
	var ysort_point_node = get_node_or_null("YsortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		return global_position.y

func _ready():
	# Connect to Area2D's area_entered signal for collision detection with Area2D balls
	var trunk_base_area = get_node_or_null("TrunkBaseArea")
	var leaves_area = get_node_or_null("Leaves")
	
	if trunk_base_area:
		# Use area_entered for trunk collisions (since golf ball uses Area2D for all collisions)
		trunk_base_area.connect("area_entered", _on_trunk_area_entered)
		# Set collision layer to 1 so golf balls can detect it
		trunk_base_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		trunk_base_area.collision_mask = 1
	else:
		print("ERROR: TrunkBaseArea not found!")
	
	if leaves_area:
		# No longer using Area2D for leaves collision - using distance-based detection instead
		# Set collision layer to 1 so golf balls can detect it (for trunk collisions only)
		leaves_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1 (for trunk collisions only)
		leaves_area.collision_mask = 1
	else:
		print("ERROR: Leaves area not found!")
	
	if trunk_base_area or leaves_area:
		print("Tree Area2D nodes found and ready for collision detection")
	else:
		print("ERROR: Tree Area2D nodes not found!")
	
	# Deferred call to double-check collision layers after the scene is fully set up
	call_deferred("_verify_collision_setup")
	
	# Ensure z_index is properly set for Ysort
	call_deferred("_update_ysort")

func _verify_collision_setup():
	"""Verify that collision layers are set correctly after the scene is fully set up"""
	var trunk_base_area = get_node_or_null("TrunkBaseArea")
	var leaves_area = get_node_or_null("Leaves")
	
	print("=== Tree collision setup verification ===")
	if trunk_base_area:
		print("TrunkBaseArea final collision_layer:", trunk_base_area.collision_layer)
		print("TrunkBaseArea final collision_mask:", trunk_base_area.collision_mask)
		print("TrunkBaseArea final monitoring:", trunk_base_area.monitoring)
		print("TrunkBaseArea final monitorable:", trunk_base_area.monitorable)
		# Verify the collision setup is correct
		if trunk_base_area.collision_layer == 1 and trunk_base_area.collision_mask == 1:
			print("✓ TrunkBaseArea collision setup is correct")
		else:
			print("✗ TrunkBaseArea collision setup is incorrect!")
	else:
		print("ERROR: TrunkBaseArea not found during verification!")
	
	if leaves_area:
		print("Leaves final collision_layer:", leaves_area.collision_layer)
		print("Leaves final collision_mask:", leaves_area.collision_mask)
		print("Leaves final monitoring:", leaves_area.monitoring)
		print("Leaves final monitorable:", leaves_area.monitorable)
		# Verify the collision setup is correct
		if leaves_area.collision_layer == 1 and leaves_area.collision_mask == 1:
			print("✓ Leaves collision setup is correct")
		else:
			print("✗ Leaves collision setup is incorrect!")
	else:
		print("ERROR: Leaves area not found during verification!")
	print("=== End collision setup verification ===")

func _on_trunk_area_entered(area: Area2D):
	"""Handle collisions with the trunk base area (ground-level collision)"""
	var ball = area.get_parent()
	print("=== TREE TRUNK COLLISION DETECTED ===")
	print("Area name:", area.name)
	print("Ball parent:", ball.name if ball else "No parent")
	print("Ball type:", ball.get_class() if ball else "Unknown")
	print("Ball position:", ball.global_position if ball else "Unknown")
	
	if ball and (ball.name == "GolfBall" or ball.name == "GhostBall"):
		print("Valid ball detected:", ball.name)
		# Handle the collision - always reflect for ground-level trunk collisions
		_handle_trunk_collision(ball)
	else:
		print("Invalid ball or non-ball object:", ball.name if ball else "Unknown")
	print("=== END TREE TRUNK COLLISION ===")

func _handle_trunk_collision(ball: Node2D):
	"""Handle trunk base collisions - check height to determine if ball should pass through"""
	print("Handling trunk collision - checking ball height")
	
	# Get ball height
	var ball_height = 0.0
	if ball.has_method("get_height"):
		ball_height = ball.get_height()
	elif "z" in ball:
		ball_height = ball.z
	
	print("Ball height:", ball_height)
	
	# Define tree height - ball must be above this to pass through
	var tree_height = 500.0  # Tree height (ball needs 505.0 to pass over)
	
	if ball_height > tree_height:
		# Ball is above the tree entirely - let it pass through
		print("Ball is above tree entirely (height:", ball_height, "> tree_height:", tree_height, ") - passing through")
		return
	else:
		# Ball is within or below tree height - reflect it off the trunk
		print("Ball is within tree height (height:", ball_height, "<= tree_height:", tree_height, ") - reflecting")
		
		# Play trunk thunk sound
		var thunk = get_node_or_null("TrunkThunk")
		if thunk:
			thunk.play()
			print("✓ TrunkThunk sound played")
		else:
			print("✗ TrunkThunk sound not found!")
		
		# Reflect the ball
		_reflect_ball_pinball(ball)

func _reflect_ball_pinball(ball: Node2D):
	"""Special reflection for low-height collisions with trunk base - creates pinball effect"""
	# Get the ball's current velocity
	var ball_velocity = Vector2.ZERO
	if ball.has_method("get_velocity"):
		ball_velocity = ball.get_velocity()
	elif "velocity" in ball:
		ball_velocity = ball.velocity
	
	print("Reflecting ball with velocity:", ball_velocity)
	
	var ball_pos = ball.global_position
	var tree_center = global_position
	
	# Calculate the direction from tree center to ball
	var to_ball_direction = (ball_pos - tree_center).normalized()
	
	# Simple reflection: reflect the velocity across the tree center
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

func set_transparent(is_transparent: bool):
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		if is_transparent:
			sprite.modulate.a = 0.4
		else:
			sprite.modulate.a = 1.0



# OPTIMIZED: Tree collision detection moved to ball for better performance
# Trees no longer check for balls every frame - ball handles its own collision detection
func _process(delta):
	# DISABLED: Tree collision detection moved to ball
	# This eliminates the performance cost of trees checking all balls every frame
	pass

func _update_ysort():
	"""Update the Tree's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")
	
	# Only print debug info once
	if not has_meta("ysort_update_printed"):
		print("Tree Ysort updated - z_index:", z_index, " global_position:", global_position)
		set_meta("ysort_update_printed", true)
	
	# Debug: Compare with other objects (only once)
	if not has_meta("ysort_comparison_printed"):
		_debug_ysort_comparison()
		set_meta("ysort_comparison_printed", true)

func _debug_ysort_comparison():
	"""Debug method to compare this Tree's Ysort with other objects"""
	var tree_ysort = get_y_sort_point()
	print("=== Tree Ysort Debug ===")
	print("Tree global_position:", global_position)
	print("Tree Ysort point:", tree_ysort)
	print("Tree z_index:", z_index)
	
	# Try to find player and ball for comparison
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_ysort = player.global_position.y
		if player.has_method("get_y_sort_point"):
			player_ysort = player.get_y_sort_point()
		print("Player Ysort point:", player_ysort)
		print("Tree vs Player Ysort difference:", tree_ysort - player_ysort)
	
	var ball = get_tree().get_first_node_in_group("golf_ball")
	if ball:
		var ball_ysort = ball.global_position.y
		if ball.has_method("get_y_sort_point"):
			ball_ysort = ball.get_y_sort_point()
		print("Ball Ysort point:", ball_ysort)
		print("Tree vs Ball Ysort difference:", tree_ysort - ball_ysort)
	
	print("=== End Tree Ysort Debug ===")
