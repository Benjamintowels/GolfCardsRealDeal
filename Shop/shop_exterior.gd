extends Node2D

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
	# Connect to Area2D's area_entered and area_exited signals for collision detection
	var base_area = get_node_or_null("BaseArea")
	
	if base_area:
		# Use area_entered for shop collisions
		base_area.connect("area_entered", _on_area_entered)
		base_area.connect("area_exited", _on_area_exited)
		# Set collision layer to 1 so golf balls can detect it
		base_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		base_area.collision_mask = 1
	else:
		print("✗ ERROR: BaseArea not found!")
	
	# Deferred call to double-check collision layers after the scene is fully set up
	call_deferred("_verify_collision_setup")
	
	# Ensure z_index is properly set for Ysort
	call_deferred("_update_ysort")

func _on_area_entered(area: Area2D):
	"""Handle collisions with the shop base area (ground-level collision)"""
	var projectile = area.get_parent()
	if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
		# Handle the collision using proper Area2D collision detection
		_handle_area_collision(projectile)

func _on_area_exited(area: Area2D):
	"""Handle when projectile exits the shop area - reset ground level"""
	var projectile = area.get_parent()
	if projectile and projectile.has_method("get_height"):
		# Reset the projectile's ground level to normal (0.0)
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
			# Fallback: directly reset ground level if method doesn't exist
			if "current_ground_level" in projectile:
				projectile.current_ground_level = 0.0

func _handle_area_collision(projectile: Node2D):
	"""Handle shop area collisions using proper Area2D detection"""
	print("=== HANDLING SHOP AREA COLLISION ===")
	print("Projectile name:", projectile.name)
	print("Projectile type:", projectile.get_class())
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_reflect_projectile(projectile)
		return
	
	# Get projectile and shop heights
	var projectile_height = projectile.get_height()
	var shop_height = Global.get_object_height_from_marker(self)
	
	print("Projectile height:", projectile_height)
	print("Shop height:", shop_height)
	
	# Check if this is a throwing knife (special handling)
	if projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_knife_area_collision(projectile, projectile_height, shop_height)
		return
	
	# Apply the collision logic:
	# If projectile height > shop height: allow entry and set ground level
	# If projectile height < shop height: reflect
	if projectile_height > shop_height:
		print("✓ Projectile is above shop - allowing entry and setting ground level")
		_allow_projectile_entry(projectile, shop_height)
	else:
		print("✗ Projectile is below shop height - reflecting")
		_reflect_projectile(projectile)

func _handle_knife_area_collision(knife: Node2D, knife_height: float, shop_height: float):
	"""Handle knife collision with shop area"""
	print("Handling knife shop area collision")
	
	if knife_height > shop_height:
		print("✓ Knife is above shop - allowing entry and setting ground level")
		_allow_projectile_entry(knife, shop_height)
	else:
		print("✗ Knife is below shop height - reflecting")
		_reflect_projectile(knife)

func _allow_projectile_entry(projectile: Node2D, shop_height: float):
	"""Allow projectile to enter shop area and set ground level"""
	print("=== ALLOWING PROJECTILE ENTRY ===")
	
	# Set the projectile's ground level to the shop height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(shop_height)
	else:
		# Fallback: directly set ground level if method doesn't exist
		if "current_ground_level" in projectile:
			projectile.current_ground_level = shop_height
			print("✓ Set projectile ground level to shop height:", shop_height)
	
	# The projectile will now land on the shop roof instead of passing through
	# When it exits the area, _on_area_exited will reset the ground level

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the shop using proper rectangular collision detection"""
	print("=== REFLECTING PROJECTILE ===")
	
	# Play trunk thunk sound for shop collision
	var thunk = get_node_or_null("TrunkThunk")
	if thunk:
		thunk.play()
	else:
		print("✗ TrunkThunk sound not found!")
	
	# Get the projectile's current velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	print("Reflecting projectile with velocity:", projectile_velocity)
	
	var projectile_pos = projectile.global_position
	var shop_pos = global_position
	
	# Get the shop's collision shape to determine the rectangle bounds
	var base_area = get_node_or_null("BaseArea")
	var collision_shape = base_area.get_node_or_null("ShopBase") if base_area else null
	
	if not collision_shape:
		print("✗ ERROR: Shop collision shape not found - using fallback reflection")
		_fallback_reflect_projectile(projectile, projectile_velocity)
		return
	
	# Calculate the shop's rectangular bounds
	var shop_size = collision_shape.shape.size
	var shop_scale = collision_shape.scale
	var shop_offset = collision_shape.position
	
	var actual_width = shop_size.x * shop_scale.x
	var actual_height = shop_size.y * shop_scale.y
	
	# Calculate the shop's world bounds
	var shop_left = shop_pos.x + shop_offset.x - actual_width / 2
	var shop_right = shop_pos.x + shop_offset.x + actual_width / 2
	var shop_top = shop_pos.y + shop_offset.y - actual_height / 2
	var shop_bottom = shop_pos.y + shop_offset.y + actual_height / 2
	
	print("Shop bounds: left=", shop_left, " right=", shop_right, " top=", shop_top, " bottom=", shop_bottom)
	print("Projectile position:", projectile_pos)
	
	# Determine which side of the rectangle the projectile hit
	var reflected_velocity = projectile_velocity
	
	# Calculate distances to each edge
	var dist_to_left = abs(projectile_pos.x - shop_left)
	var dist_to_right = abs(projectile_pos.x - shop_right)
	var dist_to_top = abs(projectile_pos.y - shop_top)
	var dist_to_bottom = abs(projectile_pos.y - shop_bottom)
	
	# Find the closest edge (the one that was hit)
	var min_dist = min(dist_to_left, dist_to_right, dist_to_top, dist_to_bottom)
	
	if min_dist == dist_to_left or min_dist == dist_to_right:
		# Hit left or right edge - reflect horizontally
		reflected_velocity.x = -projectile_velocity.x
		print("Hit left/right edge - reflecting horizontally")
	elif min_dist == dist_to_top or min_dist == dist_to_bottom:
		# Hit top or bottom edge - reflect vertically
		reflected_velocity.y = -projectile_velocity.y
		print("Hit top/bottom edge - reflecting vertically")
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Original velocity:", projectile_velocity)
	print("Reflected velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the projectile
	if projectile.has_method("set_velocity"):
		projectile.set_velocity(reflected_velocity)
	elif "velocity" in projectile:
		projectile.velocity = reflected_velocity

func _fallback_reflect_projectile(projectile: Node2D, projectile_velocity: Vector2):
	"""Fallback reflection method if collision shape is not available"""
	print("Using fallback reflection method")
	
	# Simple velocity reversal with some randomness
	var reflected_velocity = -projectile_velocity
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Fallback reflected velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the projectile
	if projectile.has_method("set_velocity"):
		projectile.set_velocity(reflected_velocity)
	elif "velocity" in projectile:
		projectile.velocity = reflected_velocity

func _verify_collision_setup():
	"""Verify that collision layers are properly set up"""
	var base_area = get_node_or_null("BaseArea")
	if base_area:
		print("Shop collision layer:", base_area.collision_layer)
		print("Shop collision mask:", base_area.collision_mask)
		
		# Check collision shape
		var collision_shape = base_area.get_node_or_null("ShopBase")
		if collision_shape:
			print("Shop collision shape size:", collision_shape.shape.size)
			print("Shop collision shape scale:", collision_shape.scale)
			print("Shop collision shape position:", collision_shape.position)
			var actual_size = collision_shape.shape.size * collision_shape.scale
			print("Shop actual collision area size:", actual_size)
		else:
			print("ERROR: ShopBase collision shape not found!")
	else:
		print("ERROR: BaseArea not found during verification!")

func _update_ysort():
	"""Update the Shop's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")
	
	# Only print debug info once
	if not has_meta("ysort_update_printed"):
		print("Shop Ysort updated - z_index:", z_index, " global_position:", global_position)
		set_meta("ysort_update_printed", true)

func get_collision_radius() -> float:
	"""
	Get the collision radius for this shop.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 48.0  # Shop collision radius (matches tile size)
