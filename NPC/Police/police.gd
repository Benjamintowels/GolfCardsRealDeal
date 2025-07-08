extends CharacterBody2D

# Police NPC - handles Police-specific functions
# Integrates with the Entities system for turn management

signal turn_completed

@onready var police_sprite: Sprite2D = $Police
@onready var police_aim_sprite: Sprite2D = $PoliceAim
@onready var pistol_shot_sound: AudioStreamPlayer2D = $PistolShot
@onready var death_groan_sound: AudioStreamPlayer2D = $DeathGroan

var grid_position: Vector2i
var cell_size: int = 48
var entities_manager: Node

# Police specific properties
var movement_range: int = 2
var vision_range: int = 10
var attack_range: int = 10  # Same as vision range for immediate attack
var current_action: String = "idle"

# Movement animation properties
var is_moving: bool = false
var movement_tween: Tween
var movement_duration: float = 0.3

# Facing direction properties
var facing_direction: Vector2i = Vector2i(1, 0)  # Start facing right
var last_movement_direction: Vector2i = Vector2i(1, 0)

# Health and damage properties
var max_health: int = 100
var current_health: int = 100
var is_alive: bool = true
var is_dead: bool = false

# Attack properties
var is_attacking: bool = false
var attack_damage: int = 50
var attack_cooldown: float = 2.0
var last_attack_time: float = -10.0  # Start with negative value so first attack is allowed

# Collision and height properties
var base_collision_area: Area2D

# Health bar
var health_bar: HealthBar
var health_bar_container: Control

# State Machine
enum State {PATROL, CHASE, ATTACK, DEAD}
var current_state: State = State.PATROL
var state_machine: StateMachine

# References
var player: Node
var course: Node

func _ready():
	# Add to groups for smart optimization and roof bounce system
	add_to_group("collision_objects")
	
	# Connect to Entities manager
	course = _find_course_script()
	print("Police course reference: ", course.name if course else "None")
	if course and course.has_node("Entities"):
		entities_manager = course.get_node("Entities")
		entities_manager.register_npc(self)
		entities_manager.npc_turn_started.connect(_on_turn_started)
		entities_manager.npc_turn_ended.connect(_on_turn_ended)
	
	# Initialize state machine
	state_machine = StateMachine.new()
	state_machine.add_state("patrol", PatrolState.new(self))
	state_machine.add_state("chase", ChaseState.new(self))
	state_machine.add_state("attack", AttackState.new(self))
	state_machine.add_state("dead", DeadState.new(self))
	state_machine.set_state("patrol")
	
	# Setup base collision area
	_setup_base_collision()
	
	# Create health bar
	_create_health_bar()
	
	# Defer player finding until after scene is fully loaded
	call_deferred("_find_player_reference")

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
		print("✓ Police base collision area setup complete")
	else:
		print("✗ ERROR: BaseCollisionArea not found!")
	
	# Setup HitBox for gun collision detection
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		# Set collision layer to 2 so gun can detect it (separate from golf balls on layer 1)
		hitbox.collision_layer = 2
		# Set collision mask to 0 (gun doesn't need to detect this)
		hitbox.collision_mask = 0
		print("✓ Police HitBox setup complete for gun collision (layer 2)")
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
		_handle_area_collision(projectile)

func _on_area_exited(area: Area2D) -> void:
	"""Handle when projectile exits the Police area - reset ground level"""
	var projectile = area.get_parent()
	if projectile and projectile.has_method("get_height"):
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
			if "current_ground_level" in projectile:
				projectile.current_ground_level = 0.0

func _handle_area_collision(projectile: Node2D):
	"""Handle Police area collisions using proper Area2D detection"""
	print("=== HANDLING POLICE AREA COLLISION ===")
	print("Projectile name:", projectile.name)
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_reflect_projectile(projectile)
		return
	
	# Get projectile and Police heights
	var projectile_height = projectile.get_height()
	var police_height = Global.get_object_height_from_marker(self)
	
	print("Projectile height:", projectile_height)
	print("Police height:", police_height)
	
	# Apply the collision logic:
	# If projectile height > Police height: allow entry and set ground level
	# If projectile height < Police height: reflect
	if projectile_height > police_height:
		print("✓ Projectile is above Police - allowing entry and setting ground level")
		_allow_projectile_entry(projectile, police_height)
	else:
		print("✗ Projectile is below Police height - reflecting")
		_reflect_projectile(projectile)

func _allow_projectile_entry(projectile: Node2D, police_height: float):
	"""Allow projectile to enter Police area and set ground level"""
	print("=== ALLOWING PROJECTILE ENTRY (POLICE) ===")
	
	# Set the projectile's ground level to the Police height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(police_height)
	else:
		if "current_ground_level" in projectile:
			projectile.current_ground_level = police_height
			print("✓ Set projectile ground level to Police height:", police_height)

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the Police"""
	print("=== REFLECTING PROJECTILE ===")
	
	# Get the projectile's current velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	print("Reflecting projectile with velocity:", projectile_velocity)
	
	var projectile_pos = projectile.global_position
	var police_center = global_position
	
	# Calculate the direction from Police center to projectile
	var to_projectile_direction = (projectile_pos - police_center).normalized()
	
	# Simple reflection: reflect the velocity across the Police center
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

func _find_player_reference() -> void:
	"""Find the player reference in the scene"""
	# First try to find the player by name
	player = get_tree().get_first_node_in_group("players")
	if player:
		print("✓ Police found player reference via group: ", player.name)
		return
	
	# Fallback: search for any node with grid_pos property and take_damage method
	var scene_tree = get_tree()
	var all_nodes = scene_tree.get_nodes_in_group("")
	
	for node in all_nodes:
		if "grid_pos" in node and node.has_method("take_damage"):
			player = node
			print("✓ Police found player reference via search: ", player.name)
			break
	
	if not player:
		print("✗ ERROR: Police could not find player reference!")

func take_turn() -> void:
	"""Take the Police's turn"""
	print("=== POLICE TURN STARTED ===")
	
	# Check player vision and update state
	_check_player_vision()
	
	# Update state machine
	state_machine.update()
	
	print("=== POLICE TURN ENDED ===")

func _check_player_vision() -> void:
	"""Check if player is within vision range and switch to appropriate state"""
	if not player:
		print("No player reference found for vision check")
		return
	
	print("=== POLICE VISION CHECK ===")
	print("Police position:", grid_position)
	print("Player reference:", player.name if player else "None")
	print("Player has grid_pos:", "grid_pos" in player)
	
	var player_pos = player.grid_pos
	var distance = grid_position.distance_to(player_pos)
	
	print("Vision check - Player at ", player_pos, ", Police at ", grid_position, ", distance: ", distance, ", vision range: ", vision_range, ", attack range: ", attack_range)
	
	if distance <= attack_range:
		if current_state != State.ATTACK:
			print("Player in attack range! Switching to attack state")
			current_state = State.ATTACK
			state_machine.set_state("attack")
		else:
			print("Already in attack state, player still in range")
		
		# Face the player when in attack mode
		_face_player()
	elif distance <= vision_range:
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
	
	print("=== END VISION CHECK ===")

func _on_turn_started(npc: Node) -> void:
	"""Called when an NPC's turn starts"""
	if npc == self:
		print("Police turn started: ", name)

func _on_turn_ended(npc: Node) -> void:
	"""Called when an NPC's turn ends"""
	if npc == self:
		print("Police turn ended: ", name)

func _complete_turn() -> void:
	"""Complete the current turn"""
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
	"""Get valid adjacent positions the Police can move to"""
	var valid_positions: Array[Vector2i] = []
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	
	for direction in directions:
		var new_pos = grid_position + direction
		if _is_position_valid(new_pos):
			valid_positions.append(new_pos)
	
	return valid_positions

func _is_position_valid(pos: Vector2i) -> bool:
	"""Check if a position is valid for the Police to move to"""
	# Basic bounds checking
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		return false
	
	# For now, allow movement to any position within bounds
	return true

func _move_to_position(target_pos: Vector2i) -> void:
	"""Move the Police to a new position with smooth animation"""
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
	
	print("Police moving from ", old_pos, " to ", target_pos, " with direction: ", movement_direction)

func _animate_movement_to_position(target_world_pos: Vector2) -> void:
	"""Animate the Police's movement to the target position using a tween"""
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
	print("Police movement animation completed")
	
	# Ensure normal sprite is visible after movement
	ensure_normal_sprite_visible()
	
	# Update Y-sorting one final time
	update_z_index_for_ysort()
	
	# Check if we can complete the turn now
	_check_turn_completion()

func _check_turn_completion() -> void:
	"""Check if the turn can be completed (waits for movement animation to finish)"""
	if is_moving:
		print("Police is still moving, waiting for animation to complete...")
		return
	
	if is_attacking:
		print("Police is still attacking, waiting for animation to complete...")
		return
	
	# Ensure normal sprite is visible before completing turn
	ensure_normal_sprite_visible()
	
	print("Police movement finished, completing turn")
	_complete_turn()

func _face_player() -> void:
	"""Face the player"""
	if not player:
		return
	
	var player_pos = player.grid_pos
	var direction = player_pos - grid_position
	
	if direction.x != 0 or direction.y != 0:
		# Normalize the direction vector for Vector2i
		if direction.x != 0:
			direction.x = 1 if direction.x > 0 else -1
		if direction.y != 0:
			direction.y = 1 if direction.y > 0 else -1
		
		facing_direction = direction
		_update_sprite_facing()

func _update_sprite_facing() -> void:
	"""Update the sprite facing direction based on facing_direction"""
	if not police_sprite:
		return
	
	# Flip sprite horizontally based on facing direction
	# If facing left (negative x), flip the sprite
	if facing_direction.x < 0:
		police_sprite.flip_h = true
		if police_aim_sprite:
			police_aim_sprite.flip_h = true
	elif facing_direction.x > 0:
		police_sprite.flip_h = false
		if police_aim_sprite:
			police_aim_sprite.flip_h = false
	
	print("Updated sprite facing - Direction: ", facing_direction, ", Flip H: ", police_sprite.flip_h)

func update_z_index_for_ysort() -> void:
	"""Update z_index for Y-sorting"""
	var y_sort_point = get_y_sort_point()
	var z_index = int(y_sort_point)
	z_index = z_index
	
	# Set z_index for both sprites
	if police_sprite:
		police_sprite.z_index = z_index
	if police_aim_sprite:
		police_aim_sprite.z_index = z_index

func get_y_sort_point() -> float:
	var ysort_point_node = get_node_or_null("Police/YSortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		return global_position.y

func setup(pos: Vector2i, cell_size_param: int = 48) -> void:
	"""Setup the Police with specific parameters"""
	grid_position = pos
	cell_size = cell_size_param
	
	# Set position based on grid position
	position = Vector2(grid_position.x, grid_position.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Initialize sprite facing direction
	_update_sprite_facing()
	
	# Update Y-sorting
	update_z_index_for_ysort()
	
	print("Police setup at ", pos)

func take_damage(amount: int, is_headshot: bool = false) -> void:
	"""Take damage and handle death if health reaches 0"""
	if not is_alive:
		print("Police is already dead, ignoring damage")
		return
	
	current_health = current_health - amount
	print("Police took", amount, "damage. Current health:", current_health, "/", max_health)
	
	# Update health bar
	var display_health = max(0, current_health)
	if health_bar:
		health_bar.set_health(display_health, max_health)
	
	# Flash damage effect
	flash_damage()
	
	if current_health <= 0 and not is_dead:
		print("Police health reached 0, calling die()")
		die()
	else:
		print("Police survived with", current_health, "health")

func flash_damage() -> void:
	"""Flash the Police red to indicate damage taken"""
	if not police_sprite:
		return
	
	var original_modulate = police_sprite.modulate
	var tween = create_tween()
	tween.tween_property(police_sprite, "modulate", Color(1, 0, 0, 1), 0.1)
	tween.tween_property(police_sprite, "modulate", original_modulate, 0.2)

func _play_collision_sound() -> void:
	"""Play collision sound for Police"""
	# For now, just print a message - you can add actual sound effects later
	print("Police collision sound played")

func die() -> void:
	"""Handle Police death"""
	if is_dead:
		return
	
	print("=== POLICE DEATH ===")
	is_dead = true
	is_alive = false
	
	# Play death sound
	if death_groan_sound:
		death_groan_sound.play()
	
	# Switch to dead state
	current_state = State.DEAD
	state_machine.set_state("dead")
	
	# Hide health bar
	if health_bar_container:
		health_bar_container.visible = false
	
	# Fade out sprites
	if police_sprite:
		var tween = create_tween()
		tween.tween_property(police_sprite, "modulate:a", 0.0, 1.0)
		tween.tween_callback(queue_free)
	
	if police_aim_sprite:
		var tween = create_tween()
		tween.tween_property(police_aim_sprite, "modulate:a", 0.0, 1.0)

func attack_player() -> void:
	"""Attack the player with a pistol shot"""
	if is_attacking or not player:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	var time_since_last_attack = current_time - last_attack_time
	
	if time_since_last_attack < attack_cooldown:
		print("Attack on cooldown, time remaining:", attack_cooldown - time_since_last_attack)
		_check_turn_completion()
		return
	
	print("=== POLICE ATTACKING PLAYER ===")
	is_attacking = true
	last_attack_time = current_time
	
	# Switch to aim sprite
	_switch_to_aim_sprite()
	
	# Play pistol shot sound
	if pistol_shot_sound:
		pistol_shot_sound.play()
	
	# Perform raycast to check if player is in line of sight
	var hit_target = _perform_attack_raycast()
	if hit_target:
		# Deal damage to whatever was hit
		if hit_target.has_method("take_damage"):
			hit_target.take_damage(attack_damage)
			print("Police dealt", attack_damage, "damage to", hit_target.name)
		else:
			print("Target doesn't have take_damage method")
	else:
		print("No target hit, attack missed")
	
	# Switch back to normal sprite after a delay
	await get_tree().create_timer(0.5).timeout
	_switch_to_normal_sprite()
	
	is_attacking = false
	_check_turn_completion()

func _switch_to_aim_sprite() -> void:
	"""Switch to the aiming sprite"""
	if police_sprite:
		police_sprite.visible = false
	if police_aim_sprite:
		police_aim_sprite.visible = true

func _switch_to_normal_sprite() -> void:
	"""Switch back to the normal sprite"""
	if police_sprite:
		police_sprite.visible = true
	if police_aim_sprite:
		police_aim_sprite.visible = false
	print("✓ Police switched to normal sprite")

func ensure_normal_sprite_visible() -> void:
	"""Safety function to ensure the normal sprite is visible when not attacking"""
	if not is_attacking:
		if police_sprite:
			police_sprite.visible = true
		if police_aim_sprite:
			police_aim_sprite.visible = false
		print("✓ Police normal sprite visibility ensured")

func _perform_attack_raycast() -> Node:
	"""Perform a raycast to check what's in the line of fire"""
	if not player:
		return null
	
	print("=== POLICE RAYCAST DEBUG ===")
	print("Police position:", global_position)
	print("Player position:", player.global_position)
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.collision_mask = 2  # Layer 2 for HitBoxes (weapons layer)
	query.collide_with_bodies = false
	query.collide_with_areas = true
	
	print("Raycast from", global_position, "to", player.global_position, "on layer 2")
	
	var result = space_state.intersect_ray(query)
	
	if result:
		print("✓ Raycast hit something!")
		# Check if the hit object is a HitBox
		var hit_object = result.collider
		print("Hit object:", hit_object.name, "Type:", hit_object.get_class())
		
		if hit_object.name == "HitBox":
			var parent = hit_object.get_parent()
			print("HitBox parent:", parent.name if parent else "None")
			if parent and parent.has_method("take_damage"):
				print("✓ HitBox parent has take_damage method - returning parent")
				return parent  # Return the parent object (player, NPC, etc.)
			else:
				print("✗ HitBox parent doesn't have take_damage method")
				return null
		else:
			print("✗ Raycast hit non-HitBox object:", hit_object.name)
			return null
	else:
		print("✗ Raycast missed - no HitBoxes hit")
		# No HitBoxes hit, check if player is directly in the path
		var distance = global_position.distance_to(player.global_position)
		print("Distance to player:", distance, "pixels, attack range:", attack_range * 48, "pixels")
		
		if distance <= attack_range * 48:  # Convert tiles to pixels
			# Check if player is in the direct line of fire
			var direction = (player.global_position - global_position).normalized()
			var to_player = player.global_position - global_position
			var dot_product = to_player.normalized().dot(direction)
			
			print("Dot product for direct line check:", dot_product)
			
			if dot_product > 0.99:  # Very precise aim required
				print("✓ Player in direct line of fire - returning player")
				return player
			else:
				print("✗ Player not in direct line of fire")
		else:
			print("✗ Player too far away")
		
		print("=== END RAYCAST DEBUG ===")
		return null

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
	var police: Node
	
	func _init(p: Node):
		police = p
	
	func enter() -> void:
		pass
	
	func update() -> void:
		pass
	
	func exit() -> void:
		pass

# Patrol State
class PatrolState extends BaseState:
	func enter() -> void:
		print("Police entering patrol state")
		# Ensure normal sprite is visible when entering patrol state
		police.ensure_normal_sprite_visible()
	
	func update() -> void:
		print("PatrolState update called")
		# Random movement up to 2 spaces away
		var move_distance = randi_range(1, police.movement_range)
		print("Patrol move distance: ", move_distance)
		var target_pos = _get_random_patrol_position(move_distance)
		print("Patrol target position: ", target_pos)
		
		if target_pos != police.grid_position:
			print("Moving to new position")
			police._move_to_position(target_pos)
		else:
			print("Staying in same position")
			# Face the last movement direction when not moving
			police.facing_direction = police.last_movement_direction
			police._update_sprite_facing()
			# Complete turn immediately since no movement is needed
			police._check_turn_completion()
	
	func _get_random_patrol_position(max_distance: int) -> Vector2i:
		var attempts = 0
		var max_attempts = 10
		
		while attempts < max_attempts:
			var random_direction = Vector2i(
				randi_range(-max_distance, max_distance),
				randi_range(-max_distance, max_distance)
			)
			
			var target_pos = police.grid_position + random_direction
			
			if police._is_position_valid(target_pos):
				return target_pos
			
			attempts += 1
		
		# If no valid position found, try adjacent positions
		var adjacent = police._get_valid_adjacent_positions()
		if adjacent.size() > 0:
			return adjacent[randi() % adjacent.size()]
		
		return police.grid_position

# Chase State
class ChaseState extends BaseState:
	func enter() -> void:
		print("Police entering chase state")
		# Ensure normal sprite is visible when entering chase state
		police.ensure_normal_sprite_visible()
	
	func update() -> void:
		print("ChaseState update called")
		if not police.player:
			print("No player found for chase")
			return
		
		var player_pos = police.player.grid_pos
		print("Player position: ", player_pos)
		var path = _get_path_to_player(player_pos)
		print("Chase path: ", path)
		
		if path.size() > 1:
			var next_pos = path[1]  # First step towards player
			print("Moving towards player to: ", next_pos)
			police._move_to_position(next_pos)
		else:
			print("No path found to player")
			# Complete turn immediately since no movement is needed
			police._check_turn_completion()
		
		# Always face the player when in chase mode
		police._face_player()

	func _get_path_to_player(player_pos: Vector2i) -> Array[Vector2i]:
		# Simple pathfinding - move towards player
		var path: Array[Vector2i] = [police.grid_position]
		var current_pos = police.grid_position
		var max_steps = police.movement_range
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
			
			if police._is_position_valid(next_pos):
				current_pos = next_pos
				path.append(current_pos)
				print("Pathfinding - Valid position, moving to: ", current_pos)
			else:
				print("Pathfinding - Invalid position, trying adjacent positions")
				# Try to find an alternative path
				var adjacent = police._get_valid_adjacent_positions()
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

# Attack State
class AttackState extends BaseState:
	func enter() -> void:
		print("Police entering attack state")
	
	func update() -> void:
		print("=== ATTACK STATE UPDATE ===")
		if not police.player:
			print("No player found for attack")
			return
		
		print("Police in attack state, calling attack_player()")
		# Attack the player
		police.attack_player()
		print("=== END ATTACK STATE UPDATE ===")

# Dead State
class DeadState extends BaseState:
	func enter() -> void:
		print("Police entering dead state")
		# Hide health bar
		if police.health_bar_container:
			police.health_bar_container.visible = false
	
	func update() -> void:
		# Dead Police don't move or take actions
		pass
	
	func exit() -> void:
		pass
