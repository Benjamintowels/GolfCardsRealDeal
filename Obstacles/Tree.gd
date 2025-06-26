extends CharacterBody2D

var blocks_movement := true  # Trees block by default; water might not
var show_debug_line := true  # Toggle for debug line visibility

func blocks(): 
	return blocks_movement

# Returns the Y-sorting reference point (base of trunk)
func get_y_sort_point() -> float:
	# Use the tree's global position Y for Y-sorting
	return global_position.y

func _ready():
	# Connect to Area2D's area_entered signal for collision detection with Area2D balls
	var trunk_base_area = get_node_or_null("TrunkBaseArea")
	var leaves_area = get_node_or_null("Leaves")
	
	print("Tree _ready called at position:", global_position, "grid position:", global_position / 48.0)
	
	if trunk_base_area:
		# Use area_entered for trunk collisions (since golf ball uses Area2D for all collisions)
		trunk_base_area.connect("area_entered", _on_trunk_area_entered)
		# Set collision layer to 1 so golf balls can detect it
		trunk_base_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		trunk_base_area.collision_mask = 1
		print("TrunkBaseArea connected to area_entered signal")
		print("TrunkBaseArea collision_layer:", trunk_base_area.collision_layer)
		print("TrunkBaseArea collision_mask:", trunk_base_area.collision_mask)
		# Test if Area2D is working by checking if it's monitoring
		print("TrunkBaseArea monitoring:", trunk_base_area.monitoring)
		print("TrunkBaseArea monitorable:", trunk_base_area.monitorable)
	else:
		print("ERROR: TrunkBaseArea not found!")
	
	if leaves_area:
		# No longer using Area2D for leaves collision - using distance-based detection instead
		# Set collision layer to 1 so golf balls can detect it (for trunk collisions only)
		leaves_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1 (for trunk collisions only)
		leaves_area.collision_mask = 1
		print("Leaves area collision layers set (for trunk collisions only)")
		print("Leaves collision_layer:", leaves_area.collision_layer)
		print("Leaves collision_mask:", leaves_area.collision_mask)
		# Test if Area2D is working by checking if it's monitoring
		print("Leaves monitoring:", leaves_area.monitoring)
		print("Leaves monitorable:", leaves_area.monitorable)
	else:
		print("ERROR: Leaves area not found!")
	
	if trunk_base_area or leaves_area:
		print("Tree Area2D nodes found and ready for collision detection")
	else:
		print("ERROR: Tree Area2D nodes not found!")
	
	# Force redraw to show the debug line after ready
	call_deferred("queue_redraw")
	
	# Deferred call to double-check collision layers after the scene is fully set up
	call_deferred("_verify_collision_setup")

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
	var tree_height = 400.0  # If ball shadow hits trunk base and ball is over 400 pixels high, pass through
	
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

func _draw():
	if not show_debug_line:
		return
	
	# Draw a horizontal red line at the Y-sorting cutoff (tree base)
	var line_length = 150
	var color = Color(1, 0, 0, 1)
	var line_width = 3
	
	draw_line(Vector2(-line_length/2, 0), Vector2(line_length/2, 0), color, line_width)
	var marker_length = 10
	draw_line(Vector2(-line_length/2, -marker_length/2), Vector2(-line_length/2, marker_length/2), color, line_width)
	draw_line(Vector2(line_length/2, -marker_length/2), Vector2(line_length/2, marker_length/2), color, line_width)

	# Draw a cross at the origin (0,0) to visualize the node's origin
	var cross_size = 12
	var cross_color = Color(0, 1, 1, 1) # Cyan for visibility
	draw_line(Vector2(-cross_size/2, 0), Vector2(cross_size/2, 0), cross_color, 2)
	draw_line(Vector2(0, -cross_size/2), Vector2(0, cross_size/2), cross_color, 2)

# Function to toggle debug line visibility
func toggle_debug_line():
	show_debug_line = !show_debug_line
	queue_redraw()  # Force redraw
	print("Tree debug line toggled: ", show_debug_line)

# Function to set debug line visibility
func set_debug_line_visible(visible: bool):
	show_debug_line = visible
	queue_redraw()  # Force redraw
	print("Tree debug line visibility set to: ", visible)

func _process(delta):
	# Check for nearby balls and play leaves rustling sound
	var balls = get_tree().get_nodes_in_group("balls")
	for ball in balls:
		if ball and (ball.name == "GolfBall" or ball.name == "GhostBall"):
			# Get the ball's ground position (shadow position)
			var ball_ground_pos = ball.global_position
			if ball.has_method("get_ground_position"):
				ball_ground_pos = ball.get_ground_position()
			
			# Check if ball's shadow is near the tree trunk
			var tree_center = global_position
			var distance_to_trunk = ball_ground_pos.distance_to(tree_center)
			var trunk_radius = 120.0  # Increased from 60.0 to 120.0 for more forgiveness
			
			# Only check if ball is within the trunk radius
			if distance_to_trunk <= trunk_radius:
				# Get ball height
				var ball_height = 0.0
				if ball.has_method("get_height"):
					ball_height = ball.get_height()
				elif "z" in ball:
					ball_height = ball.z
				
				var tree_height = 1500.0  # Updated from 100.0 to 1500.0 to match max ball height of 2000
				var min_leaves_height = 60.0  # Increased from 40.0 to 60.0 - slightly higher requirement
				
				# Check if ball is at the right height to pass through leaves
				if ball_height > min_leaves_height and ball_height < tree_height:
					# Check if we haven't played the sound recently for this ball
					var ball_id = ball.get_instance_id()
					var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
					if not ball.has_meta("last_leaves_rustle_time") or ball.get_meta("last_leaves_rustle_time") + 0.5 < current_time:
						var rustle = get_node_or_null("LeavesRustle")
						if rustle:
							rustle.play()
							print("✓ LeavesRustle sound played - ball passing through leaves near trunk")
							# Mark when we last played the sound for this ball
							ball.set_meta("last_leaves_rustle_time", current_time)
						else:
							print("✗ LeavesRustle sound not found!")
