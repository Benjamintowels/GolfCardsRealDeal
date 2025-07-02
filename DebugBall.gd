extends Node2D

# Debug Ball for height and collision testing
# This ball follows mouse movement and allows height adjustment with W/S keys

signal debug_collision_detected(object_name: String, object_height: float, ball_height: float)

var sprite: Sprite2D
var shadow: Sprite2D
var base_scale := Vector2.ONE
var max_height := 1000.0  # Maximum height for testing
var min_height := 0.0     # Minimum height

# Height and position
var z := 0.0  # Current height
var mouse_position := Vector2.ZERO

# Collision detection
var collision_area: Area2D
var map_manager: Node = null

# Debug output
var debug_label: Label

func _ready():
	# Get references
	sprite = $Sprite2D
	shadow = $Shadow
	collision_area = $Area2D
	
	print("Debug Ball _ready - Sprite:", sprite, "Shadow:", shadow, "CollisionArea:", collision_area)
	
	# Setup collision area
	if collision_area:
		collision_area.collision_layer = 1
		collision_area.collision_mask = 1
		collision_area.monitoring = true
		collision_area.monitorable = true
		collision_area.connect("area_entered", _on_area_entered)
		collision_area.connect("area_exited", _on_area_exited)
		print("Debug Ball collision area setup complete")
	else:
		print("ERROR: Debug Ball collision area not found!")
	
	# Create debug label
	_create_debug_label()
	
	# Set initial position to mouse
	position = get_global_mouse_position()
	mouse_position = position
	
	# Ensure the ball is visible
	if sprite:
		sprite.z_index = 9999  # Very high z-index to stay on top
		sprite.modulate = Color(2.0, 2.0, 0.0, 1.0)  # Very bright yellow
		sprite.visible = true
		# Use normal golf ball scale
		base_scale = Vector2(0.22, 0.22)  # Same scale as regular golf ball
		sprite.scale = base_scale
	
	print("Debug Ball initialized - Use W/S to adjust height, mouse to move")
	print("Move mouse over objects to test collision detection")
	print("Height range: 0.0 to %.1f" % max_height)
	print("Initial position:", position)

func _process(delta):
	# Follow mouse position
	mouse_position = get_global_mouse_position()
	position = mouse_position
	
	# Handle height adjustment
	if Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		z = clamp(z + 1.0, min_height, max_height)
		_update_debug_output()
		print("Debug Ball height increased to:", z)
	
	if Input.is_action_just_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		z = clamp(z - 1.0, min_height, max_height)
		_update_debug_output()
		print("Debug Ball height decreased to:", z)
	
	# Test collision detection with T key
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_T):
		print("=== MANUAL COLLISION TEST ===")
		print("Debug ball position:", position)
		print("Debug ball height:", z)
		print("Debug ball collision area:", collision_area)
		if collision_area:
			print("Collision area monitoring:", collision_area.monitoring)
			print("Collision area monitorable:", collision_area.monitorable)
			print("Collision area layer:", collision_area.collision_layer)
			print("Collision area mask:", collision_area.collision_mask)
		print("=== END MANUAL COLLISION TEST ===")
	
	# Check for collisions with objects at current position
	check_collisions_at_position()
	
	# Update visual effects
	update_visual_effects()
	
	# Update Y-sorting
	update_y_sort()
	
	# Debug position every few frames
	if Engine.get_process_frames() % 60 == 0:  # Every 60 frames (about once per second)
		print("Debug Ball position:", position, "height:", z, "visible:", sprite.visible if sprite else "no sprite")

func update_visual_effects():
	"""Update ball and shadow visuals based on height"""
	if not sprite or not shadow:
		return
	
	# Ball sprite moves up based on height
	sprite.position.y = -z
	
	# Ball scale changes with height (smaller when higher) - same as regular golf ball
	var height_scale = 1.0 - (z / 1000.0) * 0.3  # Reduce size by up to 30% at max height
	height_scale = clamp(height_scale, 0.7, 1.0)
	sprite.scale = base_scale * height_scale  # Normal golf ball scaling
	
	# Make debug ball very visible with bright yellow color
	sprite.modulate = Color(2.0, 2.0, 0.0, 1.0)  # Very bright yellow
	sprite.z_index = 9999  # Very high z-index to stay on top
	
	# Ensure sprite is visible
	sprite.visible = true
	
	# Shadow scale changes with height (smaller when ball is higher)
	var shadow_scale = 1.0 - (z / 1000.0) * 0.5  # Reduce shadow size by up to 50% at max height
	shadow_scale = clamp(shadow_scale, 0.5, 1.0)
	shadow.scale = base_scale * shadow_scale
	
	# Shadow opacity changes with height
	var shadow_alpha = 0.3 - (z / 1000.0) * 0.2  # Less opaque when ball is higher
	shadow_alpha = clamp(shadow_alpha, 0.1, 0.3)
	shadow.modulate = Color(0, 0, 0, shadow_alpha)
	
	# Ensure shadow is behind the ball
	shadow.z_index = sprite.z_index - 1

func update_y_sort():
	"""Update Y-sorting using the same system as the real ball"""
	Global.update_ball_y_sort(self)

func _create_debug_label():
	"""Create a debug label to show current height and collision info"""
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.text = "Debug Ball - Height: 0.0"
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.add_theme_font_size_override("font_size", 16)
	
	# Add to the scene
	var course = _find_course_script()
	if course and course.has_node("UILayer"):
		course.get_node("UILayer").add_child(debug_label)
		debug_label.z_index = 1000  # Keep on top

func _update_debug_output():
	"""Update the debug output with current height"""
	if debug_label:
		debug_label.text = "Debug Ball - Height: %.1f" % z

func _on_area_entered(area: Area2D):
	"""Handle collision detection"""
	print("=== DEBUG BALL AREA ENTERED ===")
	print("Area name:", area.name)
	print("Area parent:", area.get_parent().name if area.get_parent() else "No parent")
	print("Ball position:", position)
	print("Ball height:", z)
	
	var parent = area.get_parent()
	if not parent:
		print("No parent found for area")
		return
	
	# Check if this is a known object type and get its height
	var object_height = 0.0
	var object_name = parent.name
	
	if parent.has_method("get_height"):
		object_height = parent.get_height()
	elif "height" in parent:
		object_height = parent.height
	elif parent.name.begins_with("GangMember"):
		object_height = 88.0  # Ball height needed to pass over GangMember
	elif parent.name.begins_with("Tree"):
		object_height = 230.0  # Ball height needed to pass over Tree
	elif parent.name.begins_with("Pin"):
		object_height = 100.0  # Ball height needed to pass over Pin
	elif parent.name.begins_with("Player"):
		object_height = 69.0  # Ball height needed to pass over Player
	elif parent.name.begins_with("Shop") or parent.name.begins_with("ShopExterior"):
		object_height = 110.0  # Ball height needed to pass over Shop
	
	print("Object height:", object_height)
	
	# Determine collision result
	if z > object_height:
		print("RESULT: Ball would pass over (height %.1f > object height %.1f)" % [z, object_height])
		print("DIFFERENCE: Ball is %.1f units above object" % (z - object_height))
		if debug_label:
			debug_label.text = "Debug Ball - Height: %.1f | PASSING OVER %s (%.1f) | +%.1f above" % [z, object_name, object_height, z - object_height]
	else:
		print("RESULT: Ball would collide (height %.1f <= object height %.1f)" % [z, object_height])
		print("DIFFERENCE: Ball is %.1f units below object" % (object_height - z))
		if debug_label:
			debug_label.text = "Debug Ball - Height: %.1f | COLLIDED with %s (%.1f) | -%.1f below" % [z, object_name, object_height, object_height - z]
	
	# Emit signal for external handling
	debug_collision_detected.emit(object_name, object_height, z)
	print("=== END DEBUG BALL COLLISION ===")

func _on_area_exited(area: Area2D):
	"""Handle collision exit"""
	var parent = area.get_parent()
	if parent and debug_label:
		debug_label.text = "Debug Ball - Height: %.1f" % z

func _find_course_script() -> Node:
	"""Find the course_1.gd script by searching up the scene tree"""
	var current_node = self
	while current_node:
		if current_node.get_script() and current_node.get_script().resource_path.ends_with("course_1.gd"):
			return current_node
		current_node = current_node.get_parent()
	return null

func get_height() -> float:
	"""Return current height for collision detection"""
	return z

func get_velocity() -> Vector2:
	"""Return zero velocity for collision detection"""
	return Vector2.ZERO

func set_velocity(new_velocity: Vector2) -> void:
	"""Stub for collision detection compatibility"""
	pass

func get_ground_position() -> Vector2:
	"""Return ground position for Y-sorting"""
	return global_position

func check_collisions_at_position():
	"""Check for collisions with objects at the current position"""
	var course = _find_course_script()
	if not course:
		return
	
	# Check if we have an obstacle layer to search
	if not course.has_method("get_obstacle_at_position"):
		return
	
	# Get the grid position
	var cell_size = 48  # Same as course
	var grid_pos = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
	
	# Check for obstacles at this position
	var obstacle = course.get_obstacle_at_position(grid_pos)
	if obstacle:
		print("=== DEBUG BALL COLLISION DETECTED ===")
		print("Collided with:", obstacle.name)
		print("Ball height:", z)
		
		# Get object height
		var object_height = 0.0
		if obstacle.has_method("get_height"):
			object_height = obstacle.get_height()
		elif "height" in obstacle:
			object_height = obstacle.height
		elif obstacle.name.begins_with("GangMember"):
			object_height = 88.0  # Ball height needed to pass over GangMember
		elif obstacle.name.begins_with("Tree"):
			object_height = 230.0  # Ball height needed to pass over Tree
		elif obstacle.name.begins_with("Pin"):
			object_height = 100.0  # Ball height needed to pass over Pin
		elif obstacle.name.begins_with("Player"):
			object_height = 69.0  # Ball height needed to pass over Player
		elif obstacle.name.begins_with("Shop") or obstacle.name.begins_with("ShopExterior"):
			object_height = 110.0  # Ball height needed to pass over Shop
		
		print("Object height:", object_height)
		
		# Determine collision result
		if z > object_height:
			print("RESULT: Ball would pass over (height %.1f > object height %.1f)" % [z, object_height])
			print("DIFFERENCE: Ball is %.1f units above object" % (z - object_height))
			if debug_label:
				debug_label.text = "Debug Ball - Height: %.1f | PASSING OVER %s (%.1f) | +%.1f above" % [z, obstacle.name, object_height, z - object_height]
		else:
			print("RESULT: Ball would collide (height %.1f <= object height %.1f)" % [z, object_height])
			print("DIFFERENCE: Ball is %.1f units below object" % (object_height - z))
			if debug_label:
				debug_label.text = "Debug Ball - Height: %.1f | COLLIDED with %s (%.1f) | -%.1f below" % [z, obstacle.name, object_height, object_height - z]
		
		# Emit signal for external handling
		debug_collision_detected.emit(obstacle.name, object_height, z)
		print("=== END DEBUG BALL COLLISION ===")
	else:
		# No collision detected
		if debug_label:
			debug_label.text = "Debug Ball - Height: %.1f | No collision" % z 