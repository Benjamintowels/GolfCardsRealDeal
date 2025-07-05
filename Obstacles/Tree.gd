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
	
	# Setup HitBox for gun collision detection
	_setup_hitbox()
	
	# Deferred call to double-check collision layers after the scene is fully set up
	call_deferred("_verify_collision_setup")
	
	# Ensure z_index is properly set for Ysort
	call_deferred("_update_ysort")

func _on_trunk_area_entered(area: Area2D):
	"""Handle collisions with the trunk base area (ground-level collision)"""
	var ball = area.get_parent()
	
	print("=== TREE TRUNK AREA ENTERED ===")
	print("Area name:", area.name)
	print("Ball parent:", ball.name if ball else "No parent")
	print("Ball type:", ball.get_class() if ball else "Unknown")
	print("Ball position:", ball.global_position if ball else "Unknown")
	
	if ball and (ball.name == "GolfBall" or ball.name == "GhostBall" or ball.has_method("is_throwing_knife")):
		print("✓ Valid ball/knife detected:", ball.name)
		# Handle the collision - always reflect for ground-level trunk collisions
		_handle_trunk_collision(ball)
	else:
		print("✗ Invalid ball/knife or non-ball object:", ball.name if ball else "Unknown")
	
	print("=== END TREE TRUNK AREA ENTERED ===")

func _handle_trunk_collision(ball: Node2D):
	"""Handle trunk base collisions - check height to determine if ball should pass through"""
	print("=== HANDLING TRUNK COLLISION ===")
	print("Ball/knife name:", ball.name)
	print("Ball/knife type:", ball.get_class())
	
	# Use enhanced height collision detection with TopHeight markers
	if Global.is_object_above_obstacle(ball, self):
		# Ball/knife is above the tree entirely - let it pass through
		print("✓ Ball/knife is above tree entirely - passing through")
		print("=== END TRUNK COLLISION (PASSED THROUGH) ===")
		return
	else:
		# Ball/knife is within or below tree height - handle collision
		print("✗ Ball/knife is within tree height - handling collision")
		
		# Check if this is a throwing knife
		if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
			# Handle knife collision with tree
			print("Handling knife trunk collision")
			_handle_knife_trunk_collision(ball)
		else:
			# Handle regular ball collision
			print("Handling ball trunk collision")
			_handle_ball_trunk_collision(ball)
		
		print("=== END TRUNK COLLISION (COLLIDED) ===")

func _handle_knife_trunk_collision(knife: Node2D):
	"""Handle knife collision with tree trunk"""
	print("Handling knife trunk collision")
	
	# Play trunk thunk sound
	var thunk = get_node_or_null("TrunkThunk")
	if thunk:
		thunk.play()
		print("✓ TrunkThunk sound played")
	else:
		print("✗ TrunkThunk sound not found!")
	
	# Let the knife handle its own collision logic
	# The knife will determine if it should bounce or stick based on which side hits
	if knife.has_method("_handle_tree_collision"):
		knife._handle_tree_collision(self)
	else:
		# Fallback: just reflect the knife
		_reflect_knife_pinball(knife)

func _handle_ball_trunk_collision(ball: Node2D):
	"""Handle ball collision with tree trunk"""
	print("Handling ball trunk collision")
	
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

func _reflect_knife_pinball(knife: Node2D):
	"""Special reflection for knife collisions with trunk base - creates pinball effect"""
	# Get the knife's current velocity
	var knife_velocity = Vector2.ZERO
	if knife.has_method("get_velocity"):
		knife_velocity = knife.get_velocity()
	elif "velocity" in knife:
		knife_velocity = knife.velocity
	
	print("Reflecting knife with velocity:", knife_velocity)
	
	var knife_pos = knife.global_position
	var tree_center = global_position
	
	# Calculate the direction from tree center to knife
	var to_knife_direction = (knife_pos - tree_center).normalized()
	
	# Simple reflection: reflect the velocity across the tree center
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

func set_transparent(is_transparent: bool):
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		if is_transparent:
			sprite.modulate.a = 0.4
		else:
			sprite.modulate.a = 1.0

func _setup_hitbox() -> void:
	"""Setup HitBox for gun collision detection"""
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		# Set collision layer to 1 so gun can detect it
		hitbox.collision_layer = 1
		# Set collision mask to 0 (gun doesn't need to detect this)
		hitbox.collision_mask = 0
		print("✓ Tree HitBox setup complete for gun collision")
	else:
		print("✗ ERROR: Tree HitBox not found!")



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
		set_meta("ysort_comparison_printed", true)
