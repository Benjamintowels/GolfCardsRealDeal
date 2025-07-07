extends CharacterBody2D

# GangMember NPC - handles GangMember-specific functions
# Integrates with the Entities system for turn management

signal turn_completed

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var grid_position: Vector2i
var cell_size: int = 48
var entities_manager: Node

# GangMember specific properties
var gang_member_type: String = "default"
var movement_range: int = 3
var vision_range: int = 12
var current_action: String = "idle"

# Movement animation properties
var is_moving: bool = false
var movement_tween: Tween
var movement_duration: float = 0.3  # Duration of movement animation in seconds



# Facing direction properties
var facing_direction: Vector2i = Vector2i(1, 0)  # Start facing right
var last_movement_direction: Vector2i = Vector2i(1, 0)  # Track last movement direction

# Health and damage properties
var max_health: int = 30
var current_health: int = 30
var is_alive: bool = true
var is_dead: bool = false

# Freeze effect properties
var is_frozen: bool = false
var freeze_turns_remaining: int = 0
var original_modulate: Color
var freeze_sound: AudioStreamPlayer

# Collision and height properties
var dead_height: float = 50.0  # Lower height when dead (laying down)
var base_collision_area: Area2D

# Headshot mechanics
const HEADSHOT_MIN_HEIGHT = 150.0  # Minimum height for headshot (150-200 range)
const HEADSHOT_MAX_HEIGHT = 200.0  # Maximum height for headshot (150-200 range)
const HEADSHOT_MULTIPLIER = 1.5    # Damage multiplier for headshots

func _is_headshot(ball_height: float) -> bool:
	"""Check if a ball/knife hit is a headshot based on height"""
	# Headshot occurs when the ball/knife hits in the head region (150-200 height)
	return ball_height >= HEADSHOT_MIN_HEIGHT and ball_height <= HEADSHOT_MAX_HEIGHT

func get_headshot_info() -> Dictionary:
	"""Get information about the headshot system for debugging and UI"""
	return {
		"min_height": HEADSHOT_MIN_HEIGHT,
		"max_height": HEADSHOT_MAX_HEIGHT,
		"multiplier": HEADSHOT_MULTIPLIER,
		"total_height": Global.get_object_height_from_marker(self),
		"headshot_range": HEADSHOT_MAX_HEIGHT - HEADSHOT_MIN_HEIGHT
	}

# Health bar
var health_bar: HealthBar
var health_bar_container: Control

# Knife attachment system
var attached_knives: Array[Node2D] = []  # Array to track attached knife sprites

# Ragdoll animation properties
var is_ragdolling: bool = false
var ragdoll_tween: Tween
var ragdoll_duration: float = 1.5  # Duration of ragdoll animation
var ragdoll_landing_position: Vector2i  # Where the GangMember will land after ragdoll

# State Machine
enum State {PATROL, CHASE, DEAD}
var current_state: State = State.PATROL
var state_machine: StateMachine

# References
var player: Node
var course: Node

# Performance optimization - Y-sort only when moving
# No camera tracking needed since camera panning doesn't affect Y-sort in 2.5D

func _ready():
	# Add to groups for smart optimization and roof bounce system
	add_to_group("collision_objects")
	
	# Connect to Entities manager
	# Find the course_1.gd script by searching up the scene tree
	course = _find_course_script()
	print("GangMember course reference: ", course.name if course else "None")
	print("Course script: ", course.get_script().resource_path if course and course.get_script() else "None")
	if course and course.has_node("Entities"):
		entities_manager = course.get_node("Entities")
		entities_manager.register_npc(self)
		entities_manager.npc_turn_started.connect(_on_turn_started)
		entities_manager.npc_turn_ended.connect(_on_turn_ended)
	
	# Initialize state machine
	state_machine = StateMachine.new()
	state_machine.add_state("patrol", PatrolState.new(self))
	state_machine.add_state("chase", ChaseState.new(self))
	state_machine.add_state("dead", DeadState.new(self))
	state_machine.set_state("patrol")
	
	# Setup base collision area
	_setup_base_collision()
	
	# Create health bar
	_create_health_bar()
	
	# Defer player finding until after scene is fully loaded
	call_deferred("_find_player_reference")
	
	# Initialize freeze effect system
	_setup_freeze_system()

func _find_course_script() -> Node:
	"""Find the course_1.gd script by searching up the scene tree"""
	var current_node = self
	while current_node:
		if current_node.get_script() and current_node.get_script().resource_path.ends_with("course_1.gd"):
			print("Found course_1.gd script at: ", current_node.name)
			return current_node
		current_node = current_node.get_parent()
	
	print("ERROR: Could not find course_1.gd script in scene tree!")
	return null

func _setup_base_collision() -> void:
	"""Setup the base collision area for ball detection"""
	base_collision_area = get_node_or_null("BaseCollisionArea")
	if base_collision_area:
		# Set collision layer to 1 so golf balls can detect it
		base_collision_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		base_collision_area.collision_mask = 1
		# Connect to area_entered and area_exited signals for collision detection
		base_collision_area.connect("area_entered", _on_base_area_entered)
		base_collision_area.connect("area_exited", _on_area_exited)
		print("✓ GangMember base collision area setup complete")
	else:
		print("✗ ERROR: BaseCollisionArea not found!")
	
	# Setup HitBox for gun collision detection
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		# Set collision layer to 1 so gun can detect it
		hitbox.collision_layer = 1
		# Set collision mask to 0 (gun doesn't need to detect this)
		hitbox.collision_mask = 0
		print("✓ GangMember HitBox setup complete for gun collision")
	else:
		print("✗ ERROR: HitBox not found!")

func _create_health_bar() -> void:
	"""Create and setup the health bar"""
	# Create container for health bar
	health_bar_container = Control.new()
	health_bar_container.name = "HealthBarContainer"
	health_bar_container.custom_minimum_size = Vector2(60, 30)
	health_bar_container.size = Vector2(60, 30)
	health_bar_container.position = Vector2(-30, 11.145)
	health_bar_container.scale = Vector2(0.35, 0.35)
	add_child(health_bar_container)
	
	# Create health bar
	var health_bar_scene = preload("res://HealthBar.tscn")
	health_bar = health_bar_scene.instantiate()
	health_bar_container.add_child(health_bar)
	
	# Set initial health
	health_bar.set_health(current_health, max_health)

func _on_base_area_entered(area: Area2D) -> void:
	"""Handle collisions with the base collision area"""
	var projectile = area.get_parent()
	if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
		# Handle the collision using proper Area2D collision detection
		_handle_area_collision(projectile)

func _on_area_exited(area: Area2D) -> void:
	"""Handle when projectile exits the GangMember area - reset ground level"""
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
	"""Handle GangMember area collisions using proper Area2D detection"""
	print("=== HANDLING GANGMEMBER AREA COLLISION ===")
	print("Projectile name:", projectile.name)
	print("Projectile type:", projectile.get_class())
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_reflect_projectile(projectile)
		return
	
	# Get projectile and GangMember heights
	var projectile_height = projectile.get_height()
	var gang_member_height = Global.get_object_height_from_marker(self)
	
	print("Projectile height:", projectile_height)
	print("GangMember height:", gang_member_height)
	
	# Check if this is a throwing knife (special handling)
	if projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_knife_area_collision(projectile, projectile_height, gang_member_height)
		return
	
	# Apply the collision logic:
	# If projectile height > GangMember height: allow entry and set ground level
	# If projectile height < GangMember height: reflect
	if projectile_height > gang_member_height:
		print("✓ Projectile is above GangMember - allowing entry and setting ground level")
		_allow_projectile_entry(projectile, gang_member_height)
	else:
		print("✗ Projectile is below GangMember height - reflecting")
		_reflect_projectile(projectile)

func _handle_knife_area_collision(knife: Node2D, knife_height: float, gang_member_height: float):
	"""Handle knife collision with GangMember area"""
	print("Handling knife GangMember area collision")
	
	if knife_height > gang_member_height:
		print("✓ Knife is above GangMember - allowing entry and setting ground level")
		_allow_projectile_entry(knife, gang_member_height)
	else:
		print("✗ Knife is below GangMember height - reflecting")
		_reflect_projectile(knife)

func _allow_projectile_entry(projectile: Node2D, gang_member_height: float):
	"""Allow projectile to enter GangMember area and set ground level"""
	print("=== ALLOWING PROJECTILE ENTRY (GANGMEMBER) ===")
	
	# Set the projectile's ground level to the GangMember height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(gang_member_height)
	else:
		# Fallback: directly set ground level if method doesn't exist
		if "current_ground_level" in projectile:
			projectile.current_ground_level = gang_member_height
			print("✓ Set projectile ground level to GangMember height:", gang_member_height)
	
	# The projectile will now land on the GangMember's head instead of passing through
	# When it exits the area, _on_area_exited will reset the ground level

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the GangMember"""
	print("=== REFLECTING PROJECTILE ===")
	
	# Play collision sound for GangMember collision
	_play_collision_sound()
	
	# Get the projectile's current velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	print("Reflecting projectile with velocity:", projectile_velocity)
	
	var projectile_pos = projectile.global_position
	var gang_member_center = global_position
	
	# Calculate the direction from GangMember center to projectile
	var to_projectile_direction = (projectile_pos - gang_member_center).normalized()
	
	# Simple reflection: reflect the velocity across the GangMember center
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

func _handle_ball_collision(ball: Node2D) -> void:
	"""Handle ball/knife collisions - check height to determine if ball/knife should pass through"""
	print("Handling ball/knife collision - checking ball/knife height")
	
	# Use enhanced height collision detection with TopHeight markers
	if Global.is_object_above_obstacle(ball, self):
		# Ball/knife is above GangMember entirely - let it pass through
		print("Ball/knife is above GangMember entirely - passing through")
		return
	else:
		# Ball/knife is within or below GangMember height - handle collision
		print("Ball/knife is within GangMember height - handling collision")
		
		# Check if this is a throwing knife
		if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
			# Handle knife collision with GangMember
			_handle_knife_collision(ball)
		else:
			# Handle regular ball collision
			_handle_regular_ball_collision(ball)

func _handle_knife_collision(knife: Node2D) -> void:
	"""Handle knife collision with GangMember"""
	print("Handling knife collision with GangMember")
	
	# Play collision sound effect
	_play_collision_sound()
	
	# Let the knife handle its own collision logic
	# The knife will determine if it should bounce or stick based on which side hits
	if knife.has_method("_handle_npc_collision"):
		knife._handle_npc_collision(self)
	else:
		# Fallback: just reflect the knife
		_apply_knife_reflection(knife)

func attach_knife_sprite(knife_sprite: Sprite2D, knife_position: Vector2, knife_rotation: float) -> void:
	"""Attach a knife sprite to the GangMember at the specified position and rotation"""
	# Create a new Node2D to hold the knife sprite
	var knife_holder = Node2D.new()
	knife_holder.name = "AttachedKnife_" + str(attached_knives.size())
	
	# Calculate the local position relative to the GangMember
	var local_position = knife_position - global_position
	knife_holder.position = local_position
	knife_holder.rotation = knife_rotation
	
	# Store the original position for proper mirroring when the GangMember flips
	knife_holder.set_meta("original_position", local_position)
	
	# Create a copy of the knife sprite
	var knife_sprite_copy = Sprite2D.new()
	knife_sprite_copy.texture = knife_sprite.texture
	knife_sprite_copy.scale = knife_sprite.scale
	knife_sprite_copy.modulate = knife_sprite.modulate
	knife_sprite_copy.z_index = knife_sprite.z_index
	
	# Add the knife sprite to the holder
	knife_holder.add_child(knife_sprite_copy)
	
	# Add the holder to the GangMember
	add_child(knife_holder)
	
	# Track the attached knife
	attached_knives.append(knife_holder)
	
	# Add visual feedback - slightly tint the GangMember when they have knives
	if sprite and attached_knives.size() == 1:
		# First knife - add a subtle red tint
		sprite.modulate = Color(1.1, 0.9, 0.9, 1.0)

func remove_knife_sprite(knife_holder: Node2D) -> void:
	"""Remove a specific knife sprite from the GangMember"""
	if knife_holder in attached_knives:
		attached_knives.erase(knife_holder)
		knife_holder.queue_free()
		
		# Reset visual feedback if no more knives
		if sprite and attached_knives.is_empty():
			sprite.modulate = Color.WHITE

func clear_all_attached_knives() -> void:
	"""Remove all attached knife sprites from the GangMember"""
	for knife_holder in attached_knives:
		knife_holder.queue_free()
	attached_knives.clear()
	
	# Reset visual feedback
	if sprite:
		sprite.modulate = Color.WHITE

func get_attached_knives_count() -> int:
	"""Get the number of knives currently attached to this GangMember"""
	return attached_knives.size()

func has_attached_knives() -> bool:
	"""Check if this GangMember has any knives attached"""
	return not attached_knives.is_empty()

func dislodge_random_knife() -> bool:
	"""Randomly dislodge one knife from the GangMember (for gameplay mechanics)"""
	if attached_knives.is_empty():
		return false
	
	# Randomly select a knife to dislodge
	var random_index = randi() % attached_knives.size()
	var knife_to_remove = attached_knives[random_index]
	
	remove_knife_sprite(knife_to_remove)
	return true

func dislodge_all_knives() -> void:
	"""Dislodge all knives from the GangMember (for gameplay mechanics)"""
	if attached_knives.is_empty():
		return
	
	clear_all_attached_knives()

func get_knife_attachment_info() -> Dictionary:
	"""Get information about attached knives for debugging"""
	var info = {
		"knife_count": attached_knives.size(),
		"has_knives": not attached_knives.is_empty(),
		"knife_positions": []
	}
	
	for knife_holder in attached_knives:
		info.knife_positions.append({
			"local_position": knife_holder.position,
			"rotation": knife_holder.rotation,
			"name": knife_holder.name
		})
	
	return info

func _handle_regular_ball_collision(ball: Node2D) -> void:
	"""Handle regular ball collision with GangMember"""
	print("Handling regular ball collision with GangMember")
	
	# Play collision sound effect
	_play_collision_sound()
	
	# Apply collision effect to the ball
	_apply_ball_collision_effect(ball)

func _apply_knife_reflection(knife: Node2D) -> void:
	"""Apply reflection effect to a knife (fallback method)"""
	# Get the knife's current velocity
	var knife_velocity = Vector2.ZERO
	if knife.has_method("get_velocity"):
		knife_velocity = knife.get_velocity()
	elif "velocity" in knife:
		knife_velocity = knife.velocity
	
	print("Applying knife reflection with velocity:", knife_velocity)
	
	var knife_pos = knife.global_position
	var gang_member_center = global_position
	
	# Calculate the direction from GangMember center to knife
	var to_knife_direction = (knife_pos - gang_member_center).normalized()
	
	# Simple reflection: reflect the velocity across the GangMember center
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

func _apply_ball_collision_effect(ball: Node2D) -> void:
	"""Apply collision effect to the ball (bounce, damage, etc.)"""
	# Check if this is a ghost ball (shouldn't deal damage)
	var is_ghost_ball = false
	if ball.has_method("is_ghost"):
		is_ghost_ball = ball.is_ghost
	elif "is_ghost" in ball:
		is_ghost_ball = ball.is_ghost
	elif ball.name == "GhostBall":
		is_ghost_ball = true
	
	if is_ghost_ball:
		print("Ghost ball detected - no damage dealt, just reflection")
		# Ghost balls only reflect, no damage
		var ball_velocity = Vector2.ZERO
		if ball.has_method("get_velocity"):
			ball_velocity = ball.get_velocity()
		elif "velocity" in ball:
			ball_velocity = ball.velocity
		
		var ball_pos = ball.global_position
		var gang_member_center = global_position
		
		# Calculate the direction from GangMember center to ball
		var to_ball_direction = (ball_pos - gang_member_center).normalized()
		
		# Simple reflection: reflect the velocity across the GangMember center
		var reflected_velocity = ball_velocity - 2 * ball_velocity.dot(to_ball_direction) * to_ball_direction
		
		# Reduce speed slightly to prevent infinite bouncing
		reflected_velocity *= 0.8
		
		# Add a small amount of randomness to prevent infinite loops
		var random_angle = randf_range(-0.1, 0.1)
		reflected_velocity = reflected_velocity.rotated(random_angle)
		
		print("Ghost ball reflected velocity:", reflected_velocity)
		
		# Apply the reflected velocity to the ball
		if ball.has_method("set_velocity"):
			ball.set_velocity(reflected_velocity)
		elif "velocity" in ball:
			ball.velocity = reflected_velocity
		return
	
	# Get the ball's current velocity
	var ball_velocity = Vector2.ZERO
	if ball.has_method("get_velocity"):
		ball_velocity = ball.get_velocity()
	elif "velocity" in ball:
		ball_velocity = ball.velocity
	
	print("Applying collision effect to ball with velocity:", ball_velocity)
	
	# Get ball height for headshot detection
	var ball_height = 0.0
	if ball.has_method("get_height"):
		ball_height = ball.get_height()
	elif "z" in ball:
		ball_height = ball.z
	
	# Check if this is a headshot
	var is_headshot = _is_headshot(ball_height)
	var damage_multiplier = HEADSHOT_MULTIPLIER if is_headshot else 1.0
	
	# Calculate base damage based on ball velocity
	var base_damage = _calculate_velocity_damage(ball_velocity.length())
	
	# Apply headshot multiplier if applicable
	var damage = int(base_damage * damage_multiplier)
	
	if is_headshot:
		print("HEADSHOT! Ball height:", ball_height, "Base damage:", base_damage, "Final damage:", damage)
	else:
		print("Body shot. Ball height:", ball_height, "Damage:", damage)
	
	# Check for ice element and apply freeze effect
	if ball.has_method("get_element"):
		var ball_element = ball.get_element()
		if ball_element and ball_element.name == "Ice":
			print("Ice element detected! Applying freeze effect")
			freeze()
	
	# Check if this damage will kill the GangMember
	var will_kill = damage >= current_health
	var overkill_damage = 0
	
	if will_kill:
		# Calculate overkill damage (negative health value)
		overkill_damage = damage - current_health
		print("Damage will kill GangMember! Overkill damage:", overkill_damage)
		
		# Apply damage to the GangMember (this will set health to negative)
		take_damage(damage, is_headshot)
		
		# Apply velocity dampening based on overkill damage
		var dampened_velocity = _calculate_kill_dampening(ball_velocity, overkill_damage)
		print("Ball passed through with dampened velocity:", dampened_velocity)
		
		# Apply the dampened velocity to the ball (no reflection)
		if ball.has_method("set_velocity"):
			ball.set_velocity(dampened_velocity)
		elif "velocity" in ball:
			ball.velocity = dampened_velocity
	else:
		# Normal collision - apply damage and reflect
		take_damage(damage, is_headshot)
		
		var ball_pos = ball.global_position
		var gang_member_center = global_position
		
		# Calculate the direction from GangMember center to ball
		var to_ball_direction = (ball_pos - gang_member_center).normalized()
		
		# Simple reflection: reflect the velocity across the GangMember center
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

func _process(delta):
	# OPTIMIZED: Only update Y-sort when GangMember moves
	# Camera panning doesn't change Y-sort relationships in 2.5D perspective
	# No need to update Y-sort every frame or when camera moves
	pass

func _find_player_reference() -> void:
	"""Find the player reference using multiple methods"""
	print("=== PLAYER FINDING DEBUG ===")
	
	# Method 1: Try to get player from course method (most reliable)
	if course and course.has_method("get_player_reference"):
		player = course.get_player_reference()
		if player:
			print("Found player from course get_player_reference: ", player.name)
			return
		else:
			print("course.get_player_reference returned null")
	
	# Method 2: Try to find player in course
	if course and course.has_node("Player"):
		player = course.get_node("Player")
		print("Found player in course: ", player.name if player else "None")
		if player:
			return
	
	# Method 3: Try to get player from course_1.gd script method
	if course and course.has_method("get_player_node"):
		player = course.get_player_node()
		print("Found player from course script: ", player.name if player else "None")
		if player:
			return
	
	# Method 4: Try to find player in scene tree by name
	var scene_tree = get_tree()
	var all_nodes = scene_tree.get_nodes_in_group("")
	print("Searching ", all_nodes.size(), " nodes in scene tree...")
	
	for node in all_nodes:
		if node.name == "Player":
			player = node
			print("Found player in scene tree: ", player.name)
			return
	
	# Method 5: Try to find by script type
	for node in all_nodes:
		if node.get_script():
			var script_path = node.get_script().resource_path
			print("Node ", node.name, " has script: ", script_path)
			if script_path.ends_with("Player.gd"):
				player = node
				print("Found player by script: ", player.name)
				return
	
	print("ERROR: Could not find player reference!")
	print("=== END PLAYER FINDING DEBUG ===")

func _exit_tree():
	# Unregister from Entities manager when destroyed
	if entities_manager:
		entities_manager.unregister_npc(self)

func setup(member_type: String, pos: Vector2i, cell_size_param: int = 48) -> void:
	"""Setup the GangMember with specific parameters"""
	gang_member_type = member_type
	grid_position = pos
	cell_size = cell_size_param
	
	# Set position based on grid position
	position = Vector2(grid_position.x, grid_position.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Load appropriate sprite based on type
	_load_sprite_for_type(member_type)
	
	# Initialize sprite facing direction
	_update_sprite_facing()
	
	# Update Y-sorting
	update_z_index_for_ysort()
	
	print("GangMember setup: ", member_type, " at ", pos)
	
	# Debug visual height
	if sprite:
		Global.debug_visual_height(sprite, "GangMember")

func _load_sprite_for_type(type: String) -> void:
	"""Load the appropriate sprite texture based on gang member type"""
	var texture_path = "res://NPC/Gang/GangMember1.png"  # Default
	
	# You can expand this to load different sprites based on type
	match type:
		"default":
			texture_path = "res://NPC/Gang/GangMember1.png"
		"variant1":
			texture_path = "res://NPC/Gang/GangMember1.png"  # Same for now
		"variant2":
			texture_path = "res://NPC/Gang/GangMember1.png"  # Same for now
		_:
			texture_path = "res://NPC/Gang/GangMember1.png"
	
	var texture = load(texture_path)
	if texture and sprite:
		sprite.texture = texture
		
		# Scale sprite to fit cell size
		if texture.get_size().x > 0 and texture.get_size().y > 0:
			var scale_x = cell_size / texture.get_size().x
			var scale_y = cell_size / texture.get_size().y
			sprite.scale = Vector2(scale_x, scale_y)

func take_turn() -> void:
	"""Called by Entities manager when it's this NPC's turn"""
	print("GangMember taking turn: ", name)
	
	# Skip turn if dead, ragdolling, or frozen
	if is_dead:
		print("GangMember is dead, skipping turn")
		call_deferred("_complete_turn")
		return
	
	if is_ragdolling:
		print("GangMember is ragdolling, skipping turn")
		call_deferred("_complete_turn")
		return
	
	if is_frozen:
		print("GangMember is frozen, skipping turn")
		call_deferred("_complete_turn")
		return
	
	# Try to get player reference if we don't have one
	if not player and course:
		print("Attempting to get player reference from course...")
		print("Course during turn: ", course.name if course else "None")
		print("Course script during turn: ", course.get_script().resource_path if course and course.get_script() else "None")
		if course.has_method("get_player_reference"):
			player = course.get_player_reference()
			print("Got player reference during turn: ", player.name if player else "None")
		else:
			print("Course does not have get_player_reference method")
			# Try direct access as fallback
			if "player_node" in course:
				player = course.player_node
				print("Got player reference via direct access: ", player.name if player else "None")
			else:
				print("Course does not have player_node property")
		
		# Final fallback: search scene tree for player
		if not player:
			print("Trying final fallback - searching scene tree for player...")
			var scene_tree = get_tree()
			var all_nodes = scene_tree.get_nodes_in_group("")
			for node in all_nodes:
				if node.name == "Player":
					player = node
					print("Found player in final fallback: ", player.name)
					break
	
	# Check if player is in vision range
	_check_player_vision()
	
	# Let the current state handle the turn
	state_machine.update()
	
	# Complete turn after state processing (will wait for movement if needed)
	_check_turn_completion()

func _check_player_vision() -> void:
	"""Check if player is within vision range and switch to chase if needed"""
	if not player:
		print("No player reference found for vision check")
		return
	
	var player_pos = player.grid_pos
	var distance = grid_position.distance_to(player_pos)
	
	print("Vision check - Player at ", player_pos, ", distance: ", distance, ", vision range: ", vision_range)
	
	if distance <= vision_range:
		if current_state != State.CHASE:
			print("Player detected! Switching to chase state")
			current_state = State.CHASE
			state_machine.set_state("chase")
		else:
			print("Already in chase state, player still in range")
		
		# Face the player when in chase mode
		_face_player()
	else:
		if current_state != State.PATROL:
			print("Player out of range, returning to patrol")
			current_state = State.PATROL
			state_machine.set_state("patrol")
		else:
			print("Already in patrol state, player still out of range")

func _on_turn_started(npc: Node) -> void:
	"""Called when an NPC's turn starts"""
	if npc == self:
		print("GangMember turn started: ", name)

func _on_turn_ended(npc: Node) -> void:
	"""Called when an NPC's turn ends"""
	if npc == self:
		print("GangMember turn ended: ", name)

func _complete_turn() -> void:
	"""Complete the current turn"""
	# Handle freeze effect thawing
	if is_frozen:
		freeze_turns_remaining -= 1
		print("Freeze turns remaining:", freeze_turns_remaining)
		if freeze_turns_remaining <= 0:
			thaw()
	
	turn_completed.emit()
	
	# Notify Entities manager that turn is complete
	if entities_manager:
		entities_manager._on_npc_turn_completed()

func get_grid_position() -> Vector2i:
	"""Get the current grid position"""
	return grid_position

func set_grid_position(pos: Vector2i) -> void:
	"""Set the grid position and update world position"""
	grid_position = pos
	position = Vector2(pos.x, pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)

func _get_valid_adjacent_positions() -> Array[Vector2i]:
	"""Get valid adjacent positions the GangMember can move to"""
	var valid_positions: Array[Vector2i] = []
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	
	for direction in directions:
		var new_pos = grid_position + direction
		if _is_position_valid(new_pos):
			valid_positions.append(new_pos)
	
	return valid_positions

func _is_position_valid(pos: Vector2i) -> bool:
	"""Check if a position is valid for the GangMember to move to"""
	# Basic bounds checking - ensure position is within reasonable grid bounds
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		return false
	
	# For now, allow movement to any position within bounds
	# In the future, you can add obstacle checking here
	return true

func _move_to_position(target_pos: Vector2i) -> void:
	"""Move the GangMember to a new position with smooth animation"""
	var old_pos = grid_position
	grid_position = target_pos
	
	# Calculate movement direction and update facing
	var movement_direction = target_pos - old_pos
	if movement_direction != Vector2i.ZERO:
		last_movement_direction = movement_direction
		# Only update facing direction in patrol mode (not when chasing player)
		if current_state == State.PATROL:
			facing_direction = last_movement_direction
			_update_sprite_facing()
	
	# Update world position
	var target_world_pos = Vector2(target_pos.x, target_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Animated movement using tween
	_animate_movement_to_position(target_world_pos)
	
	print("GangMember moving from ", old_pos, " to ", target_pos, " with direction: ", movement_direction)
	
	# Check if we moved to the same tile as the player (only if we weren't already there)
	if player and "grid_pos" in player and player.grid_pos == target_pos and old_pos != target_pos:
		print("GangMember collided with player! Dealing damage and pushing back...")
		var approach_direction = target_pos - old_pos
		_handle_player_collision(approach_direction)

func _animate_movement_to_position(target_world_pos: Vector2) -> void:
	"""Animate the GangMember's movement to the target position using a tween"""
	# Set moving state
	is_moving = true
	
	# Stop any existing movement tween
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
	
	# Create new tween for movement
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_QUAD)
	movement_tween.set_ease(Tween.EASE_OUT)
	
	# Start the movement animation
	movement_tween.tween_property(self, "position", target_world_pos, movement_duration)
	
	# Update Y-sorting during movement
	movement_tween.tween_callback(update_z_index_for_ysort)
	
	# When movement completes
	movement_tween.tween_callback(_on_movement_completed)
	
	print("Started movement animation to position: ", target_world_pos)

func _on_movement_completed() -> void:
	"""Called when movement animation completes"""
	is_moving = false
	print("GangMember movement animation completed")
	
	# Update Y-sorting one final time
	update_z_index_for_ysort()
	
	# Check if we can complete the turn now
	_check_turn_completion()

func _check_turn_completion() -> void:
	"""Check if the turn can be completed (waits for movement animation to finish)"""
	if is_moving:
		print("GangMember is still moving, waiting for animation to complete...")
		return
	
	if is_ragdolling:
		print("GangMember is still ragdolling, waiting for animation to complete...")
		return
	
	print("GangMember movement finished, completing turn")
	_complete_turn()

func _handle_player_collision(approach_direction: Vector2i = Vector2i.ZERO) -> void:
	"""Handle collision with player - deal damage and push back"""
	if not player:
		return
	
	# Play collision sound effect
	_play_collision_sound()
	
	# Deal 15 damage to the player
	if course and course.has_method("take_damage"):
		course.take_damage(15)
		print("Player took 15 damage from GangMember collision")
		
		# Flash the player red to indicate damage
		if player and player.has_method("flash_damage"):
			player.flash_damage()
	
	# Push player back to nearest available adjacent tile
	var pushback_pos = _find_nearest_available_adjacent_tile(player.grid_pos, approach_direction)
	print("Pushback calculation - Player at: ", player.grid_pos, ", Pushback target: ", pushback_pos)
	if pushback_pos != player.grid_pos:
		print("Pushing player from ", player.grid_pos, " to ", pushback_pos)
		
		# Temporarily disconnect the moved_to_tile signal to prevent conflicts
		var signal_was_connected = false
		if player and player.has_signal("moved_to_tile") and course:
			signal_was_connected = true
			player.moved_to_tile.disconnect(course._on_player_moved_to_tile)
		
		# Use animated pushback if the player supports it
		if player.has_method("push_back"):
			player.push_back(pushback_pos)
			print("Applied animated pushback to player")
		else:
			# Fallback to instant position change
			player.set_grid_position(pushback_pos)
			print("Applied instant pushback to player (no animation support)")
		
		print("Player grid position updated to: ", player.grid_pos)
		print("Player world position: ", player.position)
		
		# Reconnect the signal if it was connected
		if signal_was_connected:
			player.moved_to_tile.connect(course._on_player_moved_to_tile)
		
		# Update the course's player_grid_pos variable first
		if course and "player_grid_pos" in course:
			course.player_grid_pos = pushback_pos
			print("Course player_grid_pos updated to: ", course.player_grid_pos)
		
		# Update the attack handler's player position if it exists
		if course and course.has_method("get_attack_handler"):
			var attack_handler = course.get_attack_handler()
			if attack_handler and attack_handler.has_method("update_player_position"):
				attack_handler.update_player_position(pushback_pos)
				print("Attack handler player position updated to: ", pushback_pos)
		
		# Update the course's player position reference
		if course and course.has_method("update_player_position"):
			course.update_player_position()
		
		# Verify the position was actually updated
		print("Final verification - Player grid_pos: ", player.grid_pos, ", Course player_grid_pos: ", course.player_grid_pos if course else "N/A")
		
		# The GangMember stays in the position where the collision occurred (player's original position)
		# No need to move the GangMember - it should occupy the tile the player was pushed from
		print("GangMember staying in collision position: ", grid_position)
		
		# Update Y-sorting for the new position
		update_z_index_for_ysort()
	else:
		print("No available adjacent tile found for pushback")

func _move_gang_member_away_from_player() -> void:
	"""Move the GangMember to a position away from the player to prevent immediate re-collision"""
	var current_pos = grid_position
	var player_pos = player.grid_pos if player else Vector2i.ZERO
	
	print("GangMember repositioning - Current pos: ", current_pos, ", Player pos after pushback: ", player_pos)
	
	# Try to find a position that's not the player's new position
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # Up, Right, Down, Left
	
	for direction in directions:
		var new_pos = current_pos + direction
		print("Checking GangMember move to: ", new_pos, " (direction: ", direction, ")")
		if new_pos != player_pos and _is_position_valid(new_pos):
			print("Moving GangMember away from collision to: ", new_pos)
			grid_position = new_pos
			position = Vector2(new_pos.x, new_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
			return
		else:
			if new_pos == player_pos:
				print("Position ", new_pos, " is occupied by player")
			else:
				print("Position ", new_pos, " is not valid for GangMember")
	
	# If no valid position found, try the opposite direction from the player
	var away_direction = (current_pos - player_pos)
	if away_direction.x != 0 or away_direction.y != 0:
		# Normalize the direction
		if away_direction.x != 0:
			away_direction.x = 1 if away_direction.x > 0 else -1
		if away_direction.y != 0:
			away_direction.y = 1 if away_direction.y > 0 else -1
		
		var new_pos = current_pos + away_direction
		print("Trying opposite direction: ", new_pos, " (away_direction: ", away_direction, ")")
		if _is_position_valid(new_pos):
			print("Moving GangMember in opposite direction to: ", new_pos)
			grid_position = new_pos
			position = Vector2(new_pos.x, new_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
			return
		else:
			print("Opposite direction position ", new_pos, " is not valid")
	
	print("Could not move GangMember away from collision - staying in place")

func update_z_index_for_ysort() -> void:
	"""Update GangMember Y-sort using the simple global system"""
	# Use the global Y-sort system for characters
	Global.update_object_y_sort(self, "characters")

func _play_collision_sound() -> void:
	"""Play a sound effect when colliding with the player"""
	# Try to find an audio player in the course
	if course:
		var audio_players = course.get_tree().get_nodes_in_group("audio_players")
		if audio_players.size() > 0:
			var audio_player = audio_players[0]
			if audio_player.has_method("play"):
				audio_player.play()
				return
		
		# Try to find Push sound specifically
		var push_sound = course.get_node_or_null("Push")
		if push_sound and push_sound is AudioStreamPlayer2D:
			push_sound.play()
			return
	
	# Fallback: create a temporary audio player
	var temp_audio = AudioStreamPlayer2D.new()
	var sound_file = load("res://Sounds/Push.mp3")
	if sound_file:
		temp_audio.stream = sound_file
		temp_audio.volume_db = -10.0  # Slightly quieter
		add_child(temp_audio)
		temp_audio.play()
		# Remove the audio player after it finishes
		temp_audio.finished.connect(func(): temp_audio.queue_free())

func _calculate_velocity_damage(velocity_magnitude: float) -> int:
	"""Calculate damage based on ball velocity magnitude"""
	# Define velocity ranges for damage scaling
	const MIN_VELOCITY = 25.0  # Minimum velocity for 1 damage
	const MAX_VELOCITY = 1200.0  # Maximum velocity for 88 damage
	
	# Clamp velocity to our defined range
	var clamped_velocity = clamp(velocity_magnitude, MIN_VELOCITY, MAX_VELOCITY)
	
	# Calculate damage percentage (0.0 to 1.0)
	var damage_percentage = (clamped_velocity - MIN_VELOCITY) / (MAX_VELOCITY - MIN_VELOCITY)
	
	# Scale damage from 1 to 88
	var damage = 1 + (damage_percentage * 87)
	
	# Return as integer
	var final_damage = int(damage)
	
	# Debug output
	print("=== VELOCITY DAMAGE CALCULATION ===")
	print("Raw velocity magnitude:", velocity_magnitude)
	print("Clamped velocity:", clamped_velocity)
	print("Damage percentage:", damage_percentage)
	print("Calculated damage:", damage)
	print("Final damage (int):", final_damage)
	print("=== END VELOCITY DAMAGE CALCULATION ===")
	
	return final_damage

func _calculate_kill_dampening(ball_velocity: Vector2, overkill_damage: int) -> Vector2:
	"""Calculate velocity dampening when ball kills an NPC"""
	# Define dampening ranges
	const MIN_OVERKILL = 1  # Minimum overkill for maximum dampening
	const MAX_OVERKILL = 60  # Maximum overkill for minimum dampening
	
	# Clamp overkill damage to our defined range
	var clamped_overkill = clamp(overkill_damage, MIN_OVERKILL, MAX_OVERKILL)
	
	# Calculate dampening factor (0.0 = no dampening, 1.0 = maximum dampening)
	# Higher overkill = less dampening (ball keeps more speed)
	var dampening_percentage = 1.0 - ((clamped_overkill - MIN_OVERKILL) / (MAX_OVERKILL - MIN_OVERKILL))
	
	# Apply dampening factor to velocity
	# Maximum dampening reduces velocity to 20% of original
	# Minimum dampening reduces velocity to 80% of original
	var dampening_factor = 0.2 + (dampening_percentage * 0.6)  # 0.2 to 0.8 range
	var dampened_velocity = ball_velocity * dampening_factor
	
	# Debug output
	print("=== KILL DAMPENING CALCULATION ===")
	print("Overkill damage:", overkill_damage)
	print("Clamped overkill:", clamped_overkill)
	print("Dampening percentage:", dampening_percentage)
	print("Dampening factor:", dampening_factor)
	print("Original velocity magnitude:", ball_velocity.length())
	print("Dampened velocity magnitude:", dampened_velocity.length())
	print("=== END KILL DAMPENING CALCULATION ===")
	
	return dampened_velocity

func _play_death_sound() -> void:
	"""Play the death groan sound when the GangMember dies"""
	# Use the existing DeathGroan audio player on the GangMember
	var death_audio = get_node_or_null("DeathGroan")
	if death_audio:
		death_audio.volume_db = 0.0  # Set to full volume
		death_audio.play()
	else:
		pass

func _find_nearest_available_adjacent_tile(player_pos: Vector2i, approach_direction: Vector2i = Vector2i.ZERO) -> Vector2i:
	"""Find the nearest available adjacent tile to push the player to based on GangMember's approach direction"""
	# Use the passed approach direction
	var gang_member_approach_direction = approach_direction
	print("GangMember approach direction: ", gang_member_approach_direction)
	
	# The pushback direction is the same as the approach direction (player gets pushed in the direction GangMember came from)
	var pushback_direction = gang_member_approach_direction
	print("Pushback direction: ", pushback_direction)
	
	# Try the primary pushback direction first
	var primary_pushback_pos = player_pos + pushback_direction
	print("Checking primary pushback position: ", primary_pushback_pos)
	if _is_position_valid_for_player(primary_pushback_pos):
		print("Found valid primary pushback position: ", primary_pushback_pos)
		return primary_pushback_pos
	
	# If primary direction is blocked, try perpendicular directions
	var perpendicular_directions = _get_perpendicular_directions(pushback_direction)
	for direction in perpendicular_directions:
		var adjacent_pos = player_pos + direction
		print("Checking perpendicular position: ", adjacent_pos, " (direction: ", direction, ")")
		if _is_position_valid_for_player(adjacent_pos):
			print("Found valid perpendicular pushback position: ", adjacent_pos)
			return adjacent_pos
	
	# If perpendicular directions are blocked, try any available adjacent tile
	var all_directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # Up, Right, Down, Left
	for direction in all_directions:
		var adjacent_pos = player_pos + direction
		print("Checking fallback position: ", adjacent_pos, " (direction: ", direction, ")")
		if _is_position_valid_for_player(adjacent_pos):
			print("Found valid fallback pushback position: ", adjacent_pos)
			return adjacent_pos
	
	# If no valid adjacent tile found, return the original position
	print("No valid adjacent tile found for player pushback")
	return player_pos

func _get_gang_member_approach_direction() -> Vector2i:
	"""Get the direction the GangMember moved to reach the player"""
	# We need to track the previous position before the collision
	# For now, we'll calculate it based on the current movement
	# This assumes the collision just happened and we're still in the _move_to_position function
	
	# The approach direction is the direction from the old position to the current position
	# We can get this from the _move_to_position function's old_pos parameter
	# But since we're in a different function, we'll need to pass this information
	
	# For now, let's use a simple approach - we'll modify the collision handling to pass this info
	return Vector2i.ZERO  # Placeholder

func _get_perpendicular_directions(direction: Vector2i) -> Array[Vector2i]:
	"""Get the two perpendicular directions to the given direction"""
	var perpendicular_dirs: Array[Vector2i] = []
	
	if direction.x != 0:  # Horizontal movement
		perpendicular_dirs.append(Vector2i(0, -1))  # Up
		perpendicular_dirs.append(Vector2i(0, 1))   # Down
	elif direction.y != 0:  # Vertical movement
		perpendicular_dirs.append(Vector2i(-1, 0))  # Left
		perpendicular_dirs.append(Vector2i(1, 0))   # Right
	
	return perpendicular_dirs

func _is_position_valid_for_player(pos: Vector2i) -> bool:
	"""Check if a position is valid for the player to move to"""
	# Basic bounds checking
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		print("Position ", pos, " is out of bounds")
		return false
	
	# Check if the position is occupied by an obstacle
	if course and "obstacle_map" in course:
		var obstacle = course.obstacle_map.get(pos)
		if obstacle and obstacle.has_method("blocks") and obstacle.blocks():
			print("Position ", pos, " is blocked by obstacle: ", obstacle.name)
			return false
	
	# Check if the position is occupied by another GangMember
	if course:
		var entities = course.get_node_or_null("Entities")
		if entities and entities.has_method("get_npcs"):
			var npcs = entities.get_npcs()
			for npc in npcs:
				if npc != self and npc.has_method("get_grid_position"):
					if npc.get_grid_position() == pos:
						print("Position ", pos, " is occupied by NPC: ", npc.name)
						return false
	
	print("Position ", pos, " is valid for player pushback")
	return true

func _update_sprite_facing() -> void:
	"""Update the sprite facing direction based on facing_direction"""
	if not sprite:
		return
	
	# Flip sprite horizontally based on facing direction
	# If facing left (negative x), flip the sprite
	if facing_direction.x < 0:
		sprite.flip_h = true
	elif facing_direction.x > 0:
		sprite.flip_h = false
	
	# Also update dead sprite if it's visible
	var dead_sprite = get_node_or_null("Dead")
	if dead_sprite and dead_sprite.visible:
		if facing_direction.x < 0:
			dead_sprite.flip_h = true
		elif facing_direction.x > 0:
			dead_sprite.flip_h = false
	
	# Update attached knives to flip with the GangMember
	_update_attached_knives_facing()
	
	print("Updated sprite facing - Direction: ", facing_direction, ", Flip H: ", sprite.flip_h)

func _update_attached_knives_facing() -> void:
	"""Update the facing direction of all attached knives when the GangMember flips"""
	if attached_knives.is_empty():
		return
	
	for knife_holder in attached_knives:
		if not is_instance_valid(knife_holder):
			continue
		
		# Get the knife sprite (first child of the knife holder)
		var knife_sprite = knife_holder.get_child(0) if knife_holder.get_child_count() > 0 else null
		if not knife_sprite or not (knife_sprite is Sprite2D):
			continue
		
		# Get the original position for proper mirroring
		var original_position = knife_holder.get_meta("original_position", Vector2.ZERO)
		
		# Flip the knife sprite horizontally to match the GangMember
		if facing_direction.x < 0:
			knife_sprite.flip_h = true
		elif facing_direction.x > 0:
			knife_sprite.flip_h = false
		
		# Mirror the position horizontally when the GangMember flips
		# This ensures the knife appears on the correct side of the GangMember
		if facing_direction.x < 0:
			# Facing left - mirror the X position from original
			knife_holder.position.x = -original_position.x
			knife_holder.position.y = original_position.y
		elif facing_direction.x > 0:
			# Facing right - use original position
			knife_holder.position = original_position
		
		print("Updated knife facing - Holder: ", knife_holder.name, ", Original Pos: ", original_position, ", New Pos: ", knife_holder.position, ", Flip H: ", knife_sprite.flip_h)
	
	print("Updated ", attached_knives.size(), " attached knives for facing direction: ", facing_direction)

func force_update_knife_facing() -> void:
	"""Force update the facing of all attached knives (useful for debugging or edge cases)"""
	print("Force updating knife facing for ", attached_knives.size(), " knives")
	_update_attached_knives_facing()

func _face_player() -> void:
	"""Make the GangMember face the player"""
	if not player:
		return
	
	var player_pos = player.grid_pos
	var direction_to_player = player_pos - grid_position
	
	# Normalize the direction to get primary direction
	if direction_to_player.x != 0:
		direction_to_player.x = 1 if direction_to_player.x > 0 else -1
	if direction_to_player.y != 0:
		direction_to_player.y = 1 if direction_to_player.y > 0 else -1
	
	# Update facing direction to face the player
	facing_direction = direction_to_player
	_update_sprite_facing()
	
	print("Facing player - Direction: ", facing_direction)

func _update_dead_sprite_facing() -> void:
	"""Update the dead sprite facing direction based on facing_direction"""
	var dead_sprite = get_node_or_null("Dead")
	if not dead_sprite:
		return
	
	# Flip dead sprite horizontally based on facing direction
	# If facing left (negative x), flip the sprite
	if facing_direction.x < 0:
		dead_sprite.flip_h = true
	elif facing_direction.x > 0:
		dead_sprite.flip_h = false
	
	# Update attached knives to flip with the dead GangMember
	_update_attached_knives_facing()
	
	print("Updated dead sprite facing - Direction: ", facing_direction, ", Flip H: ", dead_sprite.flip_h)

# Height and collision shape methods for Entities system
func get_height() -> float:
	"""Get the height of this GangMember for collision detection"""
	return Global.get_object_height_from_marker(self)

func get_y_sort_point() -> float:
	var ysort_point_node = get_node_or_null("YsortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		return global_position.y

func get_base_collision_shape() -> Dictionary:
	"""Get the base collision shape dimensions for this GangMember"""
	return {
		"width": 10.0,
		"height": 6.5,
		"offset": Vector2(0, 25)  # Offset from GangMember center to base
	}

func handle_ball_collision(ball: Node2D) -> void:
	"""Handle collision with a ball - called by Entities system"""
	_handle_ball_collision(ball)

# State Machine Class
class StateMachine:
	var states: Dictionary = {}
	var current_state: String = ""
	
	func add_state(state_name: String, state: Node) -> void:
		states[state_name] = state
	
	func set_state(state_name: String) -> void:
		if state_name in states:
			if current_state != "" and current_state in states:
				states[current_state].exit()
			current_state = state_name
			states[current_state].enter()
	
	func update() -> void:
		if current_state != "" and current_state in states:
			print("StateMachine updating state: ", current_state)
			states[current_state].update()
		else:
			print("StateMachine: No current state or state not found")

# Base State Class
class BaseState extends Node:
	var gang_member: Node
	
	func _init(gm: Node):
		gang_member = gm
	
	func enter() -> void:
		pass
	
	func update() -> void:
		pass
	
	func exit() -> void:
		pass

# Patrol State
class PatrolState extends BaseState:
	func enter() -> void:
		print("GangMember entering patrol state")
	
	func update() -> void:
		print("PatrolState update called")
		# Random movement up to 3 spaces away
		var move_distance = randi_range(1, gang_member.movement_range)
		print("Patrol move distance: ", move_distance)
		var target_pos = _get_random_patrol_position(move_distance)
		print("Patrol target position: ", target_pos)
		
		if target_pos != gang_member.grid_position:
			print("Moving to new position")
			gang_member._move_to_position(target_pos)
		else:
			print("Staying in same position")
			# Face the last movement direction when not moving
			gang_member.facing_direction = gang_member.last_movement_direction
			gang_member._update_sprite_facing()
			# Complete turn immediately since no movement is needed
			gang_member._check_turn_completion()
	
	func _get_random_patrol_position(max_distance: int) -> Vector2i:
		var attempts = 0
		var max_attempts = 10
		
		while attempts < max_attempts:
			var random_direction = Vector2i(
				randi_range(-max_distance, max_distance),
				randi_range(-max_distance, max_distance)
			)
			
			var target_pos = gang_member.grid_position + random_direction
			
			if gang_member._is_position_valid(target_pos):
				return target_pos
			
			attempts += 1
		
		# If no valid position found, try adjacent positions
		var adjacent = gang_member._get_valid_adjacent_positions()
		if adjacent.size() > 0:
			return adjacent[randi() % adjacent.size()]
		
		return gang_member.grid_position

# Chase State
class ChaseState extends BaseState:
	func enter() -> void:
		print("GangMember entering chase state")
	
	func update() -> void:
		print("ChaseState update called")
		if not gang_member.player:
			print("No player found for chase")
			return
		
		var player_pos = gang_member.player.grid_pos
		print("Player position: ", player_pos)
		var path = _get_path_to_player(player_pos)
		print("Chase path: ", path)
		
		if path.size() > 1:
			var next_pos = path[1]  # First step towards player
			print("Moving towards player to: ", next_pos)
			gang_member._move_to_position(next_pos)
		else:
			print("No path found to player")
			# Complete turn immediately since no movement is needed
			gang_member._check_turn_completion()
		
		# Always face the player when in chase mode
		gang_member._face_player()

	func _get_path_to_player(player_pos: Vector2i) -> Array[Vector2i]:
		# Simple pathfinding - move towards player
		var path: Array[Vector2i] = [gang_member.grid_position]
		var current_pos = gang_member.grid_position
		var max_steps = gang_member.movement_range
		var steps = 0
		
		print("Pathfinding - Starting from ", current_pos, " to ", player_pos, " with max steps: ", max_steps)
		
		while current_pos != player_pos and steps < max_steps:
			var direction = (player_pos - current_pos)
			# Normalize the direction vector for Vector2i
			if direction.x != 0:
				direction.x = 1 if direction.x > 0 else -1
			if direction.y != 0:
				direction.y = 1 if direction.y > 0 else -1
			var next_pos = current_pos + direction
			
			print("Pathfinding step ", steps, " - Direction: ", direction, ", Next pos: ", next_pos)
			
			if gang_member._is_position_valid(next_pos):
				current_pos = next_pos
				path.append(current_pos)
				print("Pathfinding - Valid position, moving to: ", current_pos)
			else:
				print("Pathfinding - Invalid position, trying adjacent positions")
				# Try to find an alternative path
				var adjacent = gang_member._get_valid_adjacent_positions()
				if adjacent.size() > 0:
					# Find the adjacent position closest to player
					var best_pos = adjacent[0]
					var best_distance = (best_pos - player_pos).length()
					
					for pos in adjacent:
						var distance = (pos - player_pos).length()
						if distance < best_distance:
							best_distance = distance
							best_pos = pos
					
					current_pos = best_pos
					path.append(current_pos)
					print("Pathfinding - Using adjacent position: ", current_pos)
				else:
					print("Pathfinding - No valid adjacent positions found")
					break
			
			steps += 1
		
		print("Pathfinding - Final path: ", path)
		return path

# Dead State
class DeadState extends BaseState:
	func enter() -> void:
		print("GangMember entering dead state")
		# Change sprite to dead version
		gang_member._change_to_dead_sprite()
		# Height is now handled by TopHeight marker - no need to set height property
		# Hide health bar
		if gang_member.health_bar_container:
			gang_member.health_bar_container.visible = false
		# Update dead sprite facing direction
		gang_member._update_dead_sprite_facing()
	
	func update() -> void:
		# Dead GangMembers don't move or take actions
		pass
	
	func exit() -> void:
		pass

# Health and damage methods
func take_damage(amount: int, is_headshot: bool = false, weapon_position: Vector2 = Vector2.ZERO) -> void:
	"""Take damage and handle death if health reaches 0, or pushback if survives"""
	if not is_alive:
		print("GangMember is already dead, ignoring damage")
		return
	
	# Allow negative health for overkill calculations
	current_health = current_health - amount
	print("GangMember took", amount, "damage. Current health:", current_health, "/", max_health)
	
	# Update health bar (but don't show negative values to player)
	var display_health = max(0, current_health)
	if health_bar:
		health_bar.set_health(display_health, max_health)
	
	# Flash appropriate effect based on damage type
	if is_headshot:
		flash_headshot()
	else:
		flash_damage()
	
	if current_health <= 0 and not is_dead:
		print("GangMember health reached 0, calling die()")
		die()
	else:
		print("GangMember survived with", current_health, "health")
		# If weapon position is provided and gang member survived, trigger pushback
		if weapon_position != Vector2.ZERO:
			_handle_survival_pushback(weapon_position)

func _handle_survival_pushback(weapon_position: Vector2) -> void:
	"""Handle pushback animation when gang member survives weapon damage"""
	print("=== HANDLING SURVIVAL PUSHBACK ===")
	
	# Calculate pushback direction (away from weapon)
	var gang_member_pos = global_position
	var pushback_direction = (gang_member_pos - weapon_position).normalized()
	
	# Calculate pushback distance (2 tiles)
	var pushback_distance = 2 * cell_size  # 2 tiles * cell_size
	var pushback_force = 300.0  # Force for ragdoll animation
	
	print("Gang member position:", gang_member_pos)
	print("Weapon position:", weapon_position)
	print("Pushback direction:", pushback_direction)
	print("Pushback distance:", pushback_distance)
	
	# Calculate target position (2 tiles away from current position)
	var target_world_pos = gang_member_pos + (pushback_direction * pushback_distance)
	
	# Convert world position to grid position
	var target_grid_x = floor((target_world_pos.x - cell_size / 2) / cell_size)
	var target_grid_y = floor((target_world_pos.y - cell_size / 2) / cell_size)
	var target_grid_pos = Vector2i(target_grid_x, target_grid_y)
	
	print("Target world position:", target_world_pos)
	print("Target grid position:", target_grid_pos)
	
	# Start ragdoll animation with pushback
	start_ragdoll_animation(pushback_direction, pushback_force)
	
	# Also trigger the push_back method to update grid position
	push_back(target_grid_pos)
	
	print("✓ Gang member survival pushback initiated")

func heal(amount: int) -> void:
	"""Heal the GangMember"""
	if not is_alive:
		return
	
	current_health = min(max_health, current_health + amount)
	print("GangMember healed", amount, "HP. Current health:", current_health, "/", max_health)

func die() -> void:
	"""Handle the GangMember's death"""
	if not is_alive or is_dead:
		print("GangMember is already dead, ignoring die() call")
		return
	
	is_alive = false
	is_dead = true
	print("GangMember has died!")
	
	# Play death groan sound
	print("Calling _play_death_sound()")
	_play_death_sound()
	
	# Clear all attached knives when the GangMember dies
	clear_all_attached_knives()
	
	# Switch to dead state
	current_state = State.DEAD
	state_machine.set_state("dead")
	
	# Don't unregister from Entities system - dead GangMembers can still be pushed
	# But they won't take turns anymore since the dead state doesn't do anything

func _change_to_dead_sprite() -> void:
	"""Change the sprite to the dead version"""
	# Hide the main sprite
	if sprite:
		sprite.visible = false
	
	# Show the dead sprite
	var dead_sprite = get_node_or_null("Dead")
	if dead_sprite:
		dead_sprite.visible = true
		# Apply the same facing direction to the dead sprite
		_update_dead_sprite_facing()
		print("✓ GangMember switched to dead sprite")
	else:
		print("✗ ERROR: Dead sprite not found")
	
	# Switch collision shapes
	_switch_to_dead_collision()

func _switch_to_dead_collision() -> void:
	"""Switch to the dead collision shape"""
	# Disable the main base collision area
	if base_collision_area:
		base_collision_area.monitoring = false
		base_collision_area.monitorable = false
		print("✓ Disabled main collision area")
	
	# Enable the dead collision area
	var dead_collision_area = get_node_or_null("Dead/BaseCollisionArea")
	if dead_collision_area:
		dead_collision_area.monitoring = true
		dead_collision_area.monitorable = true
		# Set collision layer to 1 so golf balls can detect it
		dead_collision_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		dead_collision_area.collision_mask = 1
		# Connect to area_entered and area_exited signals for collision detection
		if not dead_collision_area.is_connected("area_entered", _on_base_area_entered):
			dead_collision_area.connect("area_entered", _on_base_area_entered)
		if not dead_collision_area.is_connected("area_exited", _on_area_exited):
			dead_collision_area.connect("area_exited", _on_area_exited)
		print("✓ Enabled dead collision area")
	else:
		print("✗ ERROR: Dead/BaseCollisionArea not found")

func flash_damage() -> void:
	"""Flash the GangMember red to indicate damage taken"""
	if not sprite:
		return
	
	var original_modulate = sprite.modulate
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0, 0, 1), 0.1)
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)

func flash_headshot() -> void:
	"""Flash the GangMember with a special headshot effect"""
	if not sprite:
		return
	
	var original_modulate = sprite.modulate
	var tween = create_tween()
	# Flash with a bright gold color for headshots
	tween.tween_property(sprite, "modulate", Color(1, 0.84, 0, 1), 0.15)  # Bright gold
	tween.tween_property(sprite, "modulate", Color(1, 0.65, 0, 1), 0.1)   # Deeper gold
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)

func play_death_effect() -> void:
	"""Play death animation or effect"""
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
		tween.tween_callback(queue_free)

func get_health_percentage() -> float:
	"""Get current health as a percentage"""
	return float(current_health) / float(max_health)

func is_healthy() -> bool:
	"""Check if the GangMember is at full health"""
	return current_health >= max_health

func get_is_dead() -> bool:
	"""Check if the GangMember is dead"""
	return is_dead

func get_collision_radius() -> float:
	"""
	Get the collision radius for this GangMember.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 30.0  # GangMember collision radius

func is_currently_moving() -> bool:
	"""Check if the GangMember is currently moving"""
	return is_moving

func get_movement_duration() -> float:
	"""Get the current movement animation duration"""
	return movement_duration

func set_movement_duration(duration: float) -> void:
	"""Set the movement animation duration"""
	movement_duration = max(0.1, duration)  # Minimum 0.1 seconds

func stop_movement() -> void:
	"""Stop any current movement animation"""
	if is_moving and movement_tween and movement_tween.is_valid():
		movement_tween.kill()
		is_moving = false
		print("GangMember movement stopped")

func push_back(target_pos: Vector2i) -> void:
	"""Push the GangMember back to a new position with smooth animation"""
	var old_pos = grid_position
	grid_position = target_pos
	
	# Calculate pushback direction
	var pushback_direction = target_pos - old_pos
	if pushback_direction != Vector2i.ZERO:
		last_movement_direction = pushback_direction
		# Update facing direction to face the pushback direction
		facing_direction = last_movement_direction
		_update_sprite_facing()
	
	# Update world position
	var target_world_pos = Vector2(target_pos.x, target_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Animated pushback using tween
	_animate_pushback_to_position(target_world_pos)
	
	print("GangMember pushed back from ", old_pos, " to ", target_pos, " with direction: ", pushback_direction)

func _animate_pushback_to_position(target_world_pos: Vector2) -> void:
	"""Animate the GangMember's pushback to the target position using a tween"""
	# Set moving state
	is_moving = true
	
	# Stop any existing movement tween
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
	
	# Create new tween for pushback (slightly faster than normal movement)
	var pushback_duration = movement_duration * 0.7  # 70% of normal movement duration
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_QUAD)
	movement_tween.set_ease(Tween.EASE_OUT)
	
	# Start the pushback animation
	movement_tween.tween_property(self, "position", target_world_pos, pushback_duration)
	
	# Update Y-sorting during pushback
	movement_tween.tween_callback(update_z_index_for_ysort)
	
	# When pushback completes
	movement_tween.tween_callback(_on_pushback_completed)
	
	print("Started pushback animation to position: ", target_world_pos)

func _on_pushback_completed() -> void:
	"""Called when pushback animation completes"""
	is_moving = false
	print("GangMember pushback animation completed")
	
	# Update Y-sorting one final time
	update_z_index_for_ysort()

# Ragdoll Animation Methods
func start_ragdoll_animation(direction: Vector2, force: float) -> void:
	"""Start the ragdoll animation for the GangMember"""
	if is_ragdolling:
		print("GangMember is already ragdolling, ignoring new ragdoll request")
		return
	
	print("=== STARTING GANGMEMBER RAGDOLL ANIMATION ===")
	print("Direction:", direction)
	print("Force:", force)
	
	is_ragdolling = true
	
	# Stop any current movement
	stop_movement()
	
	# Calculate landing position based on direction and force
	_calculate_ragdoll_landing_position(direction, force)
	
	# Start the ragdoll animation sequence
	_start_ragdoll_sequence(direction, force)

func _calculate_ragdoll_landing_position(direction: Vector2, force: float) -> void:
	"""Calculate where the GangMember will land after the ragdoll animation"""
	var current_pos = global_position
	var distance = force * 0.8  # Convert force to distance (reduced for realistic landing)
	
	# Calculate the landing world position
	var landing_world_pos = current_pos + (direction * distance)
	
	# Convert world position to grid position
	var cell_size = 48  # Default cell size
	var grid_x = floor((landing_world_pos.x - cell_size / 2) / cell_size)
	var grid_y = floor((landing_world_pos.y - cell_size / 2) / cell_size)
	
	ragdoll_landing_position = Vector2i(grid_x, grid_y)
	
	print("Current position:", current_pos)
	print("Landing world position:", landing_world_pos)
	print("Landing grid position:", ragdoll_landing_position)

func _start_ragdoll_sequence(direction: Vector2, force: float) -> void:
	"""Start the complete ragdoll animation sequence"""
	print("=== STARTING RAGDOLL SEQUENCE ===")
	
	# Stop any existing ragdoll tween
	if ragdoll_tween and ragdoll_tween.is_valid():
		ragdoll_tween.kill()
	
	# Create new ragdoll tween
	ragdoll_tween = create_tween()
	ragdoll_tween.set_parallel(true)
	
	# Phase 1: Launch upward and backward
	var launch_duration = ragdoll_duration * 0.4  # 40% of total time
	var launch_distance = force * 0.6  # 60% of force for launch
	var launch_direction = Vector2(direction.x, -0.8)  # Add upward component
	var launch_target = global_position + (launch_direction * launch_distance)
	
	print("Launch phase - Duration:", launch_duration, "Target:", launch_target)
	
	# Move to launch position
	ragdoll_tween.tween_property(self, "global_position", launch_target, launch_duration)
	ragdoll_tween.set_trans(Tween.TRANS_QUAD)
	ragdoll_tween.set_ease(Tween.EASE_OUT)
	
	# Phase 2: Tilt backward during launch
	var tilt_angle = -45.0  # Tilt backward 45 degrees
	ragdoll_tween.tween_property(self, "rotation_degrees", tilt_angle, launch_duration)
	
	# Phase 3: Fall back down to landing position
	var fall_duration = ragdoll_duration * 0.6  # 60% of total time for falling
	var landing_world_pos = Vector2(ragdoll_landing_position.x, ragdoll_landing_position.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	print("Fall phase - Duration:", fall_duration, "Landing position:", landing_world_pos)
	
	# Fall to landing position (delayed)
	ragdoll_tween.tween_property(self, "global_position", landing_world_pos, fall_duration).set_delay(launch_duration)
	ragdoll_tween.set_trans(Tween.TRANS_QUAD)
	ragdoll_tween.set_ease(Tween.EASE_IN)
	
	# Phase 4: Return to normal rotation during fall
	ragdoll_tween.tween_property(self, "rotation_degrees", 0.0, fall_duration).set_delay(launch_duration)
	
	# Phase 5: Complete ragdoll and switch to dead state
	ragdoll_tween.tween_callback(_on_ragdoll_complete).set_delay(ragdoll_duration)
	
	print("✓ Ragdoll animation sequence started")

func _on_ragdoll_complete() -> void:
	"""Called when the ragdoll animation is complete"""
	print("=== RAGDOLL ANIMATION COMPLETE ===")
	
	is_ragdolling = false
	
	# Update grid position to landing position
	grid_position = ragdoll_landing_position
	print("Updated grid position to landing position:", grid_position)
	
	# Update Y-sorting for new position
	update_z_index_for_ysort()
	
	# Switch to dead state and show dead sprite
	if not is_dead:
		print("GangMember died from ragdoll - switching to dead state")
		die()
	else:
		print("GangMember was already dead - just updating position")
		# Update the dead sprite position
		_update_dead_sprite_facing()
	
	print("✓ Ragdoll animation complete")

func stop_ragdoll() -> void:
	"""Stop the ragdoll animation if it's currently running"""
	if is_ragdolling and ragdoll_tween and ragdoll_tween.is_valid():
		ragdoll_tween.kill()
		is_ragdolling = false
		print("✓ Ragdoll animation stopped")

func is_currently_ragdolling() -> bool:
	"""Check if the GangMember is currently ragdolling"""
	return is_ragdolling

# State Machine Class

func _setup_freeze_system() -> void:
	"""Setup the freeze effect system"""
	# Create freeze sound player
	freeze_sound = AudioStreamPlayer.new()
	var freeze_sound_stream = preload("res://Sounds/IceOn.mp3")
	freeze_sound.stream = freeze_sound_stream
	freeze_sound.volume_db = -10.0  # Slightly quieter
	add_child(freeze_sound)
	
	# Store original modulate for restoration
	if sprite:
		original_modulate = sprite.modulate

func freeze() -> void:
	"""Apply freeze effect to the gang member"""
	if is_frozen or is_dead:
		return
	
	is_frozen = true
	freeze_turns_remaining = 1  # Freeze for 1 turn
	print("GangMember frozen for", freeze_turns_remaining, "turns!")
	
	# Play freeze sound
	if freeze_sound:
		freeze_sound.play()
	
	# Apply light blue tint
	if sprite:
		var freeze_color = Color(0.7, 0.9, 1.0, 1.0)  # Light blue tint
		sprite.modulate = freeze_color

func thaw() -> void:
	"""Remove freeze effect from the gang member"""
	if not is_frozen:
		return
	
	is_frozen = false
	freeze_turns_remaining = 0
	print("GangMember thawed!")
	
	# Restore original modulate
	if sprite:
		sprite.modulate = original_modulate

func is_frozen_state() -> bool:
	"""Check if the gang member is currently frozen"""
	return is_frozen
