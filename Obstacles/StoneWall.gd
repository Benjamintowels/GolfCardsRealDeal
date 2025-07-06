extends Node2D

var blocks_movement := true  # Stone walls block movement by default

func blocks(): 
	return blocks_movement

# Returns the Y-sorting reference point (base of wall)
func get_y_sort_point() -> float:
	var ysort_point_node = get_node_or_null("Sprite2D/YSortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		return global_position.y

func _ready():
	# Connect to Area2D's area_entered and area_exited signals for collision detection
	var wall_area = get_node_or_null("Sprite2D/Area2D")
	
	if wall_area:
		# Use area_entered and area_exited for wall collisions
		wall_area.connect("area_entered", _on_wall_area_entered)
		wall_area.connect("area_exited", _on_wall_area_exited)
		# Set collision layer to 1 so golf balls can detect it
		wall_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		wall_area.collision_mask = 1
		print("✓ StoneWall Area2D setup complete for collision detection")
	else:
		print("✗ ERROR: StoneWall Area2D not found!")
	
	# Deferred call to double-check collision layers after the scene is fully set up
	call_deferred("_verify_collision_setup")
	
	# Ensure z_index is properly set for Ysort
	call_deferred("_update_ysort")

func _on_wall_area_entered(area: Area2D):
	"""Handle collisions with the stone wall area"""
	var projectile = area.get_parent()
	
	print("=== STONE WALL AREA ENTERED ===")
	print("Area name:", area.name)
	print("Projectile parent:", projectile.name if projectile else "No parent")
	print("Projectile type:", projectile.get_class() if projectile else "Unknown")
	print("Projectile position:", projectile.global_position if projectile else "Unknown")
	
	if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
		print("✓ Valid projectile detected:", projectile.name)
		# Handle the collision using proper Area2D collision detection
		_handle_wall_area_collision(projectile)
	else:
		print("✗ Invalid projectile or non-projectile object:", projectile.name if projectile else "Unknown")
	
	print("=== END STONE WALL AREA ENTERED ===")

func _on_wall_area_exited(area: Area2D):
	"""Handle when projectile exits the stone wall area - reset ground level"""
	var projectile = area.get_parent()
	
	print("=== STONE WALL AREA EXITED ===")
	print("Projectile:", projectile.name if projectile else "Unknown")
	
	if projectile and projectile.has_method("get_height"):
		# Reset the projectile's ground level to normal (0.0)
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
			# Fallback: directly reset ground level if method doesn't exist
			if "current_ground_level" in projectile:
				projectile.current_ground_level = 0.0
				print("✓ Reset projectile ground level to 0.0")
	
	print("=== END STONE WALL AREA EXITED ===")

func _handle_wall_area_collision(projectile: Node2D):
	"""Handle stone wall area collisions using proper Area2D detection"""
	print("=== HANDLING STONE WALL AREA COLLISION ===")
	print("Projectile name:", projectile.name)
	print("Projectile type:", projectile.get_class())
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_reflect_projectile(projectile)
		return
	
	# Get projectile and wall heights
	var projectile_height = projectile.get_height()
	var wall_height = Global.get_object_height_from_marker(self)
	
	print("Projectile height:", projectile_height)
	print("Wall height:", wall_height)
	
	# Check if this is a throwing knife (special handling)
	if projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_knife_wall_area_collision(projectile, projectile_height, wall_height)
		return
	
	# Apply the collision logic:
	# If projectile height > wall height: allow entry and set ground level
	# If projectile height < wall height: reflect
	if projectile_height > wall_height:
		print("✓ Projectile is above wall - allowing entry and setting ground level")
		_allow_projectile_entry(projectile, wall_height)
	else:
		print("✗ Projectile is below wall height - reflecting")
		_reflect_projectile(projectile)

func _handle_knife_wall_area_collision(knife: Node2D, knife_height: float, wall_height: float):
	"""Handle knife collision with stone wall area"""
	print("Handling knife stone wall area collision")
	
	if knife_height > wall_height:
		print("✓ Knife is above wall - allowing entry and setting ground level")
		_allow_projectile_entry(knife, wall_height)
	else:
		print("✗ Knife is below wall height - reflecting")
		_reflect_projectile(knife)

func _allow_projectile_entry(projectile: Node2D, wall_height: float):
	"""Allow projectile to enter wall area and set ground level"""
	print("=== ALLOWING PROJECTILE ENTRY (STONE WALL) ===")
	
	# Set the projectile's ground level to the wall height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(wall_height)
	else:
		# Fallback: directly set ground level if method doesn't exist
		if "current_ground_level" in projectile:
			projectile.current_ground_level = wall_height
			print("✓ Set projectile ground level to wall height:", wall_height)
	
	# The projectile will now land on the wall instead of passing through
	# When it exits the area, _on_wall_area_exited will reset the ground level

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the stone wall"""
	print("=== REFLECTING PROJECTILE (STONE WALL) ===")
	
	# Play stone thunk sound
	var thunk = get_node_or_null("StoneThunk")
	if thunk:
		thunk.play()
		print("✓ StoneThunk sound played")
	else:
		print("✗ StoneThunk sound not found!")
	
	# Get the projectile's current velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	print("Original velocity:", projectile_velocity)
	
	# Get the wall's grid position to determine its orientation
	var wall_grid_pos = get_meta("grid_position") if has_meta("grid_position") else Vector2i.ZERO
	var projectile_pos = projectile.global_position
	var wall_pos = global_position
	
	# Determine wall orientation based on grid position
	# Walls are now only placed on top/bottom edges (y=0 or y=layout_height-1) and are horizontal
	var is_horizontal_wall = wall_grid_pos.y == 0 or wall_grid_pos.y == 49  # Assuming 50x50 layout
	
	print("Wall grid position:", wall_grid_pos)
	print("Is horizontal wall:", is_horizontal_wall)
	
	if is_horizontal_wall:
		# Horizontal wall - reflect Y velocity
		if wall_grid_pos.y == 0:
			# Top edge wall - bounce back up (negative Y)
			projectile_velocity.y = -abs(projectile_velocity.y)
			print("✓ Top edge wall - reversing Y velocity")
		else:
			# Bottom edge wall - bounce back down (positive Y)
			projectile_velocity.y = abs(projectile_velocity.y)
			print("✓ Bottom edge wall - reversing Y velocity")
	else:
		# Fallback: use simple reflection based on position
		print("⚠️ Unknown wall orientation - using fallback reflection")
		var to_projectile = (projectile_pos - wall_pos).normalized()
		projectile_velocity = projectile_velocity - 2 * projectile_velocity.dot(to_projectile) * to_projectile
	
	# Reduce speed slightly to prevent infinite bouncing
	projectile_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.05, 0.05)
	projectile_velocity = projectile_velocity.rotated(random_angle)
	
	print("Reflected velocity:", projectile_velocity)
	
	# Apply the reflected velocity to the projectile
	if projectile.has_method("set_velocity"):
		projectile.set_velocity(projectile_velocity)
	elif "velocity" in projectile:
		projectile.velocity = projectile_velocity

func _verify_collision_setup():
	"""Verify that collision layers are properly set up"""
	var wall_area = get_node_or_null("Sprite2D/Area2D")
	if wall_area:
		print("✓ StoneWall collision layer:", wall_area.collision_layer)
		print("✓ StoneWall collision mask:", wall_area.collision_mask)
	else:
		print("✗ StoneWall Area2D not found for verification")

func _update_ysort():
	"""Update Y-sort z_index for this object"""
	# Let the global Y-sort system handle this
	pass

func get_collision_radius() -> float:
	"""
	Get the collision radius for this stone wall.
	Used by the rolling collision system to determine when ball has entered collision area.
	"""
	return 80.0  # Stone wall collision radius (smaller than shop since walls are thinner) 
