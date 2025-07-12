extends CharacterBody2D

# Import TreeData for sprite variations
const TreeData = preload("res://Obstacles/TreeData.gd")

var blocks_movement := true  # Trees block by default; water might not

# TreeData support for sprite variations
@export var tree_data: TreeData

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
	# Connect to Area2D's area_entered and area_exited signals for collision detection
	var trunk_base_area = get_node_or_null("TrunkBaseArea")
	var leaves_area = get_node_or_null("Leaves")
	
	if trunk_base_area:
		# Use area_entered and area_exited for trunk collisions
		trunk_base_area.connect("area_entered", _on_trunk_area_entered)
		trunk_base_area.connect("area_exited", _on_trunk_area_exited)
		# Set collision layer to 1 so golf balls can detect it
		trunk_base_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		trunk_base_area.collision_mask = 1
		print("✓ Tree TrunkBaseArea setup complete for collision detection")
	else:
		print("✗ ERROR: TrunkBaseArea not found!")
	
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
	
	# Setup mouse detection area for hover transparency
	_setup_mouse_detection()
	
	# Deferred call to double-check collision layers after the scene is fully set up
	call_deferred("_verify_collision_setup")
	
	# Ensure z_index is properly set for Ysort
	call_deferred("_update_ysort")
	
	# Apply TreeData if provided
	call_deferred("_apply_tree_data")

func _on_trunk_area_entered(area: Area2D):
	"""Handle collisions with the trunk base area (ground-level collision)"""
	var projectile = area.get_parent()
	
	print("=== TREE TRUNK AREA ENTERED ===")
	print("Area name:", area.name)
	print("Projectile parent:", projectile.name if projectile else "No parent")
	print("Projectile type:", projectile.get_class() if projectile else "Unknown")
	print("Projectile position:", projectile.global_position if projectile else "Unknown")
	
	if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
		print("✓ Valid projectile detected:", projectile.name)
		# Handle the collision using proper Area2D collision detection
		_handle_trunk_area_collision(projectile)
	else:
		print("✗ Invalid projectile or non-projectile object:", projectile.name if projectile else "Unknown")
	
	print("=== END TREE TRUNK AREA ENTERED ===")

func _on_trunk_area_exited(area: Area2D):
	"""Handle when projectile exits the tree trunk area - reset ground level"""
	var projectile = area.get_parent()
	
	print("=== TREE TRUNK AREA EXITED ===")
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
	
	print("=== END TREE TRUNK AREA EXITED ===")

func _handle_trunk_area_collision(projectile: Node2D):
	"""Handle tree trunk area collisions using proper Area2D detection"""
	print("=== HANDLING TREE TRUNK AREA COLLISION ===")
	print("Projectile name:", projectile.name)
	print("Projectile type:", projectile.get_class())
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_reflect_projectile(projectile)
		return
	
	# Get projectile and tree heights
	var projectile_height = projectile.get_height()
	var tree_height = Global.get_object_height_from_marker(self)
	
	print("Projectile height:", projectile_height)
	print("Tree height:", tree_height)
	
	# Check if this is a throwing knife (special handling)
	if projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_knife_trunk_area_collision(projectile, projectile_height, tree_height)
		return
	
	# Apply the collision logic:
	# If projectile height > tree height: allow entry and set ground level
	# If projectile height < tree height: reflect
	if projectile_height > tree_height:
		print("✓ Projectile is above tree - allowing entry and setting ground level")
		_allow_projectile_entry(projectile, tree_height)
	else:
		print("✗ Projectile is below tree height - reflecting")
		_reflect_projectile(projectile)

func _handle_knife_trunk_area_collision(knife: Node2D, knife_height: float, tree_height: float):
	"""Handle knife collision with tree trunk area"""
	print("Handling knife tree trunk area collision")
	
	if knife_height > tree_height:
		print("✓ Knife is above tree - allowing entry and setting ground level")
		_allow_projectile_entry(knife, tree_height)
	else:
		print("✗ Knife is below tree height - reflecting")
		_reflect_projectile(knife)

func _allow_projectile_entry(projectile: Node2D, tree_height: float):
	"""Allow projectile to enter tree area and set ground level"""
	print("=== ALLOWING PROJECTILE ENTRY (TREE) ===")
	
	# Set the projectile's ground level to the tree height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(tree_height)
	else:
		# Fallback: directly set ground level if method doesn't exist
		if "current_ground_level" in projectile:
			projectile.current_ground_level = tree_height
			print("✓ Set projectile ground level to tree height:", tree_height)
	
	# The projectile will now land on the tree trunk instead of passing through
	# When it exits the area, _on_trunk_area_exited will reset the ground level

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the tree trunk"""
	print("=== REFLECTING PROJECTILE (TREE) ===")
	
	# Play trunk thunk sound
	var thunk = get_node_or_null("TrunkThunk")
	if thunk:
		thunk.play()
		print("✓ TrunkThunk sound played")
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
	var tree_center = global_position
	
	# Calculate the direction from tree center to projectile
	var to_projectile_direction = (projectile_pos - tree_center).normalized()
	
	# Simple reflection: reflect the velocity across the tree center
	var reflected_velocity = projectile_velocity - 2 * projectile_velocity.dot(to_projectile_direction) * to_projectile_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Reflected velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the projectile
	if projectile.has_method("set_velocity"):
		projectile.set_velocity(reflected_velocity)
	elif "velocity" in projectile:
		projectile.velocity = reflected_velocity

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
		# Set collision layer to 2 so gun can detect it (separate from golf balls on layer 1)
		hitbox.collision_layer = 2
		# Set collision mask to 0 (gun doesn't need to detect this)
		hitbox.collision_mask = 0
		print("✓ Tree HitBox setup complete for gun collision (layer 2)")
	else:
		print("✗ ERROR: Tree HitBox not found!")

func _verify_collision_setup():
	"""Verify that collision layers are properly set up"""
	var trunk_base_area = get_node_or_null("TrunkBaseArea")
	if trunk_base_area:
		print("Tree collision layer:", trunk_base_area.collision_layer)
		print("Tree collision mask:", trunk_base_area.collision_mask)
		
		# Check collision shape
		var collision_shape = trunk_base_area.get_node_or_null("TrunkBase")
		if collision_shape:
			print("Tree collision shape radius:", collision_shape.shape.radius)
			print("Tree collision shape scale:", collision_shape.scale)
			print("Tree collision shape position:", collision_shape.position)
			var actual_radius = collision_shape.shape.radius * collision_shape.scale.x
			print("Tree actual collision radius:", actual_radius)
		else:
			print("ERROR: TrunkBase collision shape not found!")
	else:
		print("ERROR: TrunkBaseArea not found during verification!")

func set_tree_data(new_tree_data: TreeData):
	"""Set the TreeData for this tree and apply it immediately"""
	tree_data = new_tree_data
	_apply_tree_data()

func _apply_tree_data():
	"""Apply TreeData to change the tree sprite"""
	if not tree_data or not tree_data.sprite_texture:
		return
	
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = tree_data.sprite_texture
		print("✓ Applied TreeData sprite:", tree_data.name)
	else:
		print("✗ ERROR: Tree Sprite2D not found!")

# OPTIMIZED: Tree collision detection moved to ball for better performance
# Trees no longer check for balls every frame - ball handles its own collision detection
func _process(delta):
	# Check if mouse is over the tree using the control node
	var mouse_control = get_node_or_null("MouseControl")
	if mouse_control:
		var mouse_pos = mouse_control.get_local_mouse_position()
		var tree_rect = Rect2(Vector2.ZERO, mouse_control.size)
		
		if tree_rect.has_point(mouse_pos):
			if not is_mouse_over:
				is_mouse_over = true
				_on_mouse_entered()
		else:
			if is_mouse_over:
				is_mouse_over = false
				_on_mouse_exited()

func _update_ysort():
	"""Update the Tree's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this tree.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 120.0  # Tree trunk radius

func _setup_mouse_detection() -> void:
	"""Setup MouseDetectionArea for hover transparency effect"""
	var mouse_area = get_node_or_null("MouseDetectionArea")
	var mouse_control = get_node_or_null("MouseControl")
	
	# Setup Area2D mouse detection
	if mouse_area:
		# Enable mouse input detection
		mouse_area.input_pickable = true
		mouse_area.monitoring = true
		mouse_area.monitorable = true
		
		# Connect mouse enter/exit signals for transparency effect
		mouse_area.mouse_entered.connect(_on_mouse_entered)
		mouse_area.mouse_exited.connect(_on_mouse_exited)
		
		# Set collision layer to 0 (not used for physics)
		mouse_area.collision_layer = 0
		# Set collision mask to 0 (not used for physics)
		mouse_area.collision_mask = 0
		
		print("✓ Tree MouseDetectionArea setup complete for hover transparency")
		print("  - input_pickable:", mouse_area.input_pickable)
		print("  - monitoring:", mouse_area.monitoring)
		print("  - monitorable:", mouse_area.monitorable)
	else:
		print("✗ ERROR: MouseDetectionArea not found!")
	
	# Setup Control mouse detection as backup
	if mouse_control:
		# Connect gui_input for better mouse detection in camera container
		mouse_control.gui_input.connect(_on_mouse_control_input)
		
		print("✓ Tree MouseControl setup complete for hover transparency")
		print("  - mouse_filter:", mouse_control.mouse_filter)
	else:
		print("✗ ERROR: MouseControl not found!")

func _on_mouse_control_input(event: InputEvent) -> void:
	"""Handle mouse input events for the control node"""
	var mouse_control = get_node_or_null("MouseControl")
	if not mouse_control:
		return
		
	if event is InputEventMouseMotion:
		# Mouse is over the tree
		if not is_mouse_over:
			is_mouse_over = true
			_on_mouse_entered()
	elif event is InputEventMouseButton:
		# Mouse button event - check if mouse is still over
		var mouse_pos = mouse_control.get_local_mouse_position()
		var tree_rect = Rect2(Vector2.ZERO, mouse_control.size)
		if not tree_rect.has_point(mouse_pos):
			if is_mouse_over:
				is_mouse_over = false
				_on_mouse_exited()

var is_mouse_over: bool = false

func _on_mouse_entered() -> void:
	"""Handle mouse entering the tree area - make tree transparent"""
	set_transparent(true)

func _on_mouse_exited() -> void:
	"""Handle mouse exiting the tree area - restore tree opacity"""
	set_transparent(false)
