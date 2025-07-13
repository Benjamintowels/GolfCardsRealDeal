extends CharacterBody2D

# ZombieGolfer NPC - handles ZombieGolfer-specific functions
# Integrates with the Entities system for turn management

# Coin explosion system
const CoinExplosionManager = preload("res://CoinExplosionManager.gd")

signal turn_completed

@onready var sprite: Sprite2D = $ZombieGolferSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var zombie_attack_sound: AudioStreamPlayer2D = $ZombieAttack

# Footstep sound system
@onready var footsteps_grass_sound: AudioStreamPlayer2D = $FootstepsGrass
@onready var footsteps_snow_sound: AudioStreamPlayer2D = $FootstepsSnow
var footstep_sound_enabled: bool = true
var last_footstep_time: float = 0.0
var footstep_interval: float = 0.3  # Time between footstep sounds during movement

var grid_position: Vector2i
var cell_size: int = 48
var entities_manager: Node

# ZombieGolfer specific properties
var zombie_type: String = "default"
var movement_range: int = 4
var vision_range: int = 7
var attack_range: int = 1  # Attack when adjacent to player
var current_action: String = "idle"

# Turn management
var is_turn_in_progress: bool = false
var has_attacked_this_turn: bool = false

# Movement animation properties
var is_moving: bool = false
var movement_tween: Tween
var movement_duration: float = 0.3  # Duration of movement animation in seconds
var movement_start_position: Vector2  # Track where movement started

# Facing direction properties
var facing_direction: Vector2i = Vector2i(1, 0)  # Start facing right
var last_movement_direction: Vector2i = Vector2i(1, 0)  # Track last movement direction

# Health and damage properties
var max_health: int = 22
var current_health: int = 22
var is_alive: bool = true
var is_dead: bool = false

# Collision and height properties
var dead_height: float = 50.0  # Lower height when dead (laying down)
var base_collision_area: Area2D

# Health bar
var health_bar: HealthBar
var health_bar_container: Control

# State Machine
enum State {PATROL, CHASE, DEAD}
var current_state: State = State.PATROL
var state_machine: StateMachine

# References
var player: Node
var course: Node

# Performance optimization - Y-sort only when moving

func _ready():
	# Add to groups for smart optimization and roof bounce system
	add_to_group("collision_objects")
	add_to_group("NPC")
	
	# Connect to WorldTurnManager
	# Find the course_1.gd script by searching up the scene tree
	course = _find_course_script()
	print("ZombieGolfer course reference: ", course.name if course else "None")
	print("Course script: ", course.get_script().resource_path if course and course.get_script() else "None")
	
	# Try different paths to find WorldTurnManager
	var world_turn_manager = null
	var possible_paths = ["WorldTurnManager", "NPC/WorldTurnManager", "NPC/world_turn_manager"]
	
	for path in possible_paths:
		if course and course.has_node(path):
			world_turn_manager = course.get_node(path)
			print("Found WorldTurnManager at path: ", path)
			break
	
	if world_turn_manager:
		print("Found WorldTurnManager: ", world_turn_manager.name)
		world_turn_manager.register_npc(self)
		world_turn_manager.npc_turn_started.connect(_on_turn_started)
		world_turn_manager.npc_turn_ended.connect(_on_turn_ended)
		print("✓ ZombieGolfer registered with WorldTurnManager")
	else:
		print("✗ ERROR: Could not register with WorldTurnManager")
		print("Tried paths: ", possible_paths)
	
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
	
	# Setup footstep sound system
	_setup_footstep_sounds()

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
		print("✓ ZombieGolfer base collision area setup complete")
	else:
		print("✗ ERROR: BaseCollisionArea not found!")
	
	# Setup HitBox for gun collision detection
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		# Set collision layer to 2 so gun can detect it (separate from golf balls on layer 1)
		hitbox.collision_layer = 2
		# Set collision mask to 0 (gun doesn't need to detect this)
		hitbox.collision_mask = 0
		print("✓ ZombieGolfer HitBox setup complete for gun collision (layer 2)")
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
	"""Handle when projectile exits the ZombieGolfer area - reset ground level"""
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
	"""Handle ZombieGolfer area collisions using proper Area2D detection"""
	print("=== HANDLING ZOMBIEGOLFER AREA COLLISION ===")
	print("Projectile name:", projectile.name)
	print("Projectile type:", projectile.get_class())
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_reflect_projectile(projectile)
		return
	
	# Get projectile and ZombieGolfer heights
	var projectile_height = projectile.get_height()
	var zombie_height = Global.get_object_height_from_marker(self)
	
	print("Projectile height:", projectile_height)
	print("ZombieGolfer height:", zombie_height)
	
	# Check if this is a throwing knife (special handling)
	if projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_knife_area_collision(projectile, projectile_height, zombie_height)
		return
	
	# Apply the collision logic:
	# If projectile height > ZombieGolfer height: allow entry and set ground level
	# If projectile height < ZombieGolfer height: deal damage and reflect
	if projectile_height > zombie_height:
		print("✓ Projectile is above ZombieGolfer - allowing entry and setting ground level")
		_allow_projectile_entry(projectile, zombie_height)
	else:
		print("✗ Projectile is below ZombieGolfer height - dealing damage and reflecting")
		# Deal damage first, then reflect
		_handle_ball_collision(projectile)

func _handle_knife_area_collision(knife: Node2D, knife_height: float, zombie_height: float):
	"""Handle knife collision with ZombieGolfer area"""
	print("Handling knife ZombieGolfer area collision")
	
	if knife_height > zombie_height:
		print("✓ Knife is above ZombieGolfer - allowing entry and setting ground level")
		_allow_projectile_entry(knife, zombie_height)
	else:
		print("✗ Knife is below ZombieGolfer height - reflecting")
		_reflect_projectile(knife)

func _allow_projectile_entry(projectile: Node2D, zombie_height: float):
	"""Allow projectile to enter ZombieGolfer area and set ground level"""
	print("=== ALLOWING PROJECTILE ENTRY (ZOMBIEGOLFER) ===")
	
	# Set the projectile's ground level to the ZombieGolfer height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(zombie_height)
	else:
		# Fallback: directly set ground level if method doesn't exist
		if "current_ground_level" in projectile:
			projectile.current_ground_level = zombie_height
			print("✓ Set projectile ground level to ZombieGolfer height:", zombie_height)
	
	# The projectile will now land on the ZombieGolfer's head instead of passing through
	# When it exits the area, _on_area_exited will reset the ground level

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the ZombieGolfer"""
	print("=== REFLECTING PROJECTILE ===")
	
	# Play collision sound for ZombieGolfer collision
	_play_collision_sound()
	
	# Get the projectile's current velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	print("Reflecting projectile with velocity:", projectile_velocity)
	
	var projectile_pos = projectile.global_position
	var zombie_center = global_position
	
	# Calculate the direction from ZombieGolfer center to projectile
	var to_projectile_direction = (projectile_pos - zombie_center).normalized()
	
	# Simple reflection: reflect the velocity across the ZombieGolfer center
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
	
	# Use the Entities system for collision handling (includes moving NPC push system)
	if entities_manager and entities_manager.has_method("handle_npc_ball_collision"):
		entities_manager.handle_npc_ball_collision(self, ball)
		return
	
	# Fallback to original collision logic if Entities system is not available
	# Use enhanced height collision detection with TopHeight markers
	if Global.is_object_above_obstacle(ball, self):
		# Ball/knife is above ZombieGolfer entirely - let it pass through
		print("Ball/knife is above ZombieGolfer entirely - passing through")
		return
	else:
		# Ball/knife is within or below ZombieGolfer height - handle collision
		print("Ball/knife is within ZombieGolfer height - handling collision")
		
		# Check if this is a throwing knife
		if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
			# Handle knife collision with ZombieGolfer
			_handle_knife_collision(ball)
		else:
			# Handle regular ball collision
			_handle_regular_ball_collision(ball)

func _handle_knife_collision(knife: Node2D) -> void:
	"""Handle knife collision with ZombieGolfer"""
	print("Handling knife collision with ZombieGolfer")
	
	# Play collision sound effect
	_play_collision_sound()
	
	# Let the knife handle its own collision logic
	# The knife will determine if it should bounce or stick based on which side hits
	if knife.has_method("_handle_npc_collision"):
		knife._handle_npc_collision(self)
	else:
		# Fallback: just reflect the knife
		_apply_knife_reflection(knife)

func _apply_knife_reflection(knife: Node2D) -> void:
	"""Apply reflection to a knife projectile"""
	if knife.has_method("get_velocity"):
		var knife_velocity = knife.get_velocity()
		var reflected_velocity = -knife_velocity  # Simple reverse
		knife.set_velocity(reflected_velocity)
	elif "velocity" in knife:
		knife.velocity = -knife.velocity

func _handle_regular_ball_collision(ball: Node2D) -> void:
	"""Handle regular ball collision with ZombieGolfer"""
	print("Handling regular ball collision with ZombieGolfer")
	
	# Play collision sound effect
	_play_collision_sound()
	
	# Calculate velocity-based damage
	var ball_velocity = Vector2.ZERO
	if ball.has_method("get_velocity"):
		ball_velocity = ball.get_velocity()
	elif "velocity" in ball:
		ball_velocity = ball.velocity
	
	var damage = _calculate_velocity_damage(ball_velocity.length())
	print("Ball velocity:", ball_velocity.length(), "Calculated damage:", damage)
	
	# Apply damage to ZombieGolfer
	take_damage(damage, false)
	
	# Reflect the ball
	var reflected_velocity = -ball_velocity * 0.8  # Reverse and reduce speed
	if ball.has_method("set_velocity"):
		ball.set_velocity(reflected_velocity)
	elif "velocity" in ball:
		ball.velocity = reflected_velocity

func _calculate_velocity_damage(velocity_magnitude: float) -> int:
	"""Calculate damage based on ball velocity magnitude (same as Entities system)"""
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
	
	print("=== VELOCITY DAMAGE CALCULATION ===")
	print("Raw velocity magnitude:", velocity_magnitude)
	print("Clamped velocity:", clamped_velocity)
	print("Damage percentage:", damage_percentage)
	print("Calculated damage:", damage)
	print("Final damage (int):", final_damage)
	print("=== END VELOCITY DAMAGE CALCULATION ===")
	
	return final_damage

func _play_collision_sound() -> void:
	"""Play collision sound effect"""
	var death_groan = get_node_or_null("DeathGroan")
	if death_groan and death_groan.stream:
		death_groan.play()

func _play_zombie_attack_sound() -> void:
	"""Play zombie attack sound effect"""
	if zombie_attack_sound and zombie_attack_sound.stream:
		zombie_attack_sound.play()

func _trigger_coin_explosion() -> void:
	"""Trigger a coin explosion when the ZombieGolfer dies"""
	# Use the static method from CoinExplosionManager
	CoinExplosionManager.trigger_coin_explosion(global_position)

func setup(zombie_type_param: String, pos: Vector2i, cell_size_param: int = 48) -> void:
	"""Setup the ZombieGolfer with specific parameters"""
	
	zombie_type = zombie_type_param
	grid_position = pos
	cell_size = cell_size_param
	
	# Set position based on grid position
	var world_pos = Vector2(grid_position.x, grid_position.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	position = world_pos
	
	# Load appropriate sprite based on type
	_load_sprite_for_type(zombie_type)
	
	# Initialize sprite facing direction
	_update_sprite_facing()
	
	# Update Y-sorting
	update_z_index_for_ysort()

func _load_sprite_for_type(type: String) -> void:
	"""Load the appropriate sprite texture based on zombie type"""
	var texture_path = "res://NPC/Zombies/ZombieGolfer1.png"  # Default
	
	# You can expand this to load different sprites based on type
	match type:
		"default":
			texture_path = "res://NPC/Zombies/ZombieGolfer1.png"
		"variant1":
			texture_path = "res://NPC/Zombies/ZombieGolfer2.png"
		"variant2":
			texture_path = "res://NPC/Zombies/Golfer1.png"
		_:
			texture_path = "res://NPC/Zombies/ZombieGolfer1.png"
	
	var texture = load(texture_path)
	if texture and sprite:
		sprite.texture = texture
		
		# Scale sprite to fit cell size
		if texture.get_size().x > 0 and texture.get_size().y > 0:
			var scale_x = cell_size / texture.get_size().x
			var scale_y = cell_size / texture.get_size().y
			sprite.scale = Vector2(scale_x, scale_y)

func _update_sprite_facing() -> void:
	"""Update sprite facing direction based on movement"""
	if sprite:
		if facing_direction.x < 0:
			sprite.flip_h = true
		elif facing_direction.x > 0:
			sprite.flip_h = false

func update_z_index_for_ysort() -> void:
	"""Update ZombieGolfer Y-sort using the simple global system"""
	# Use the global Y-sort system for characters
	Global.update_object_y_sort(self, "characters")

func take_damage(damage: int, is_headshot: bool = false) -> void:
	"""Take damage from attacks"""
	if is_dead:
		return
	
	var final_damage = damage
	if is_headshot:
		final_damage = int(damage * 1.5)  # Headshot multiplier
	
	current_health -= final_damage
	
	# Update health bar
	if health_bar:
		health_bar.set_health(current_health, max_health)
	
	if current_health <= 0:
		die()

func die() -> void:
	"""Handle ZombieGolfer death"""
	if is_dead:
		return
	
	is_dead = true
	is_alive = false
	current_health = 0
	
	# Give death reward
	Global.give_npc_death_reward("ZombieGolfer")
	
	# Play death sound
	_play_collision_sound()
	
	# Trigger coin explosion
	_trigger_coin_explosion()
	
	# Switch to dead state
	current_state = State.DEAD
	state_machine.set_state("dead")
	
	# Hide health bar
	if health_bar_container:
		health_bar_container.visible = false
	
	# Switch to dead collision system
	_switch_to_dead_collision()
	
	# Switch to dead sprite
	_change_to_dead_sprite()

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
	
	# Update Y-sorting for dead state
	update_z_index_for_ysort()

func _update_dead_sprite_facing() -> void:
	"""Update the dead sprite facing direction"""
	var dead_sprite = get_node_or_null("Dead")
	if dead_sprite:
		# Apply the same facing direction to the dead sprite
		if facing_direction.x < 0:
			dead_sprite.flip_h = true
		elif facing_direction.x > 0:
			dead_sprite.flip_h = false

func _switch_to_dead_collision() -> void:
	"""Switch to the dead collision system"""
	
	# Disable normal collision areas
	if base_collision_area:
		base_collision_area.monitoring = false
		base_collision_area.monitorable = false
	
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
	
	# Enable dead collision area
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

func get_grid_position() -> Vector2i:
	"""Get the grid position of the ZombieGolfer"""
	return grid_position

func set_grid_position(pos: Vector2i) -> void:
	"""Set the grid position of the ZombieGolfer"""
	grid_position = pos
	
	# Update world position based on grid position
	var world_pos = Vector2(grid_position.x, grid_position.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	position = world_pos
	
	# Update Y-sorting
	update_z_index_for_ysort()
	
	print("ZombieGolfer grid position set to: ", pos, " (world position: ", world_pos, ")")

func get_height() -> float:
	"""Get the height of the ZombieGolfer for collision detection"""
	if is_dead:
		var dead_top_height = get_node_or_null("Dead/DeadGangTopHeight")
		if dead_top_height:
			return dead_top_height.global_position.y
		return global_position.y - dead_height
	
	var top_height = get_node_or_null("TopHeight")
	if top_height:
		return top_height.global_position.y
	return global_position.y - 94.0  # Default height

func get_y_sort_point() -> float:
	"""Get the Y-sort reference point for the ZombieGolfer"""
	if sprite:
		var ysort_point = sprite.get_node_or_null("YSortPoint")
		if ysort_point:
			return ysort_point.global_position.y
	return global_position.y

func _find_player_reference() -> void:
	"""Find the player reference for AI behavior"""
	# Find player in the scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("✓ Found player reference for ZombieGolfer")
	else:
		print("✗ No player found for ZombieGolfer")

func take_turn() -> void:
	"""Take the ZombieGolfer's turn"""
	if is_dead:
		_complete_turn()
		return
	
	if is_turn_in_progress:
		print("ZombieGolfer turn already in progress, skipping...")
		return
	
	is_turn_in_progress = true
	has_attacked_this_turn = false
	
	print("ZombieGolfer taking turn...")
	
	# Try to get player reference if we don't have one
	if not player and course:
		print("Attempting to get player reference from course...")
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

func _complete_turn() -> void:
	"""Complete the current turn"""
	print("=== ZOMBIEGOLFER COMPLETING TURN ===")
	print("ZombieGolfer: ", name)
	print("Setting is_turn_in_progress to false")
	is_turn_in_progress = false
	has_attacked_this_turn = false
	print("Emitting turn_completed signal")
	turn_completed.emit()
	print("Turn completed signal emitted successfully")
	
	# Note: Entities manager notification removed - turn management now handled by course_1.gd
	print("=== END ZOMBIEGOLFER TURN COMPLETION ===")

func _check_player_vision() -> void:
	"""Check if player is within vision range and switch to chase if needed"""
	if not player:
		print("No player reference found for vision check")
		return
	
	var player_pos = player.grid_pos
	var distance = _calculate_distance(grid_position, player_pos)
	
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

func _face_player() -> void:
	"""Face the player"""
	if not player:
		return
	
	var player_pos = player.grid_pos
	var direction = player_pos - grid_position
	if direction.x != 0:
		facing_direction = Vector2i(direction.x, 0)
	elif direction.y != 0:
		facing_direction = Vector2i(0, direction.y)
	
	_update_sprite_facing()

func _check_turn_completion() -> void:
	"""Check if the turn can be completed (waits for movement animation to finish)"""
	print("=== ZOMBIEGOLFER TURN COMPLETION CHECK ===")
	print("ZombieGolfer: ", name)
	print("Is turn in progress: ", is_turn_in_progress)
	print("Is moving: ", is_moving)
	print("Current state: ", current_state)
	
	if not is_turn_in_progress:
		print("ZombieGolfer turn not in progress, skipping completion check")
		print("=== END TURN COMPLETION CHECK ===")
		return
	
	if is_moving:
		print("ZombieGolfer is still moving, waiting for animation to complete...")
		print("=== END TURN COMPLETION CHECK ===")
		return
	
	print("ZombieGolfer movement finished, completing turn")
	_complete_turn()
	print("=== END TURN COMPLETION CHECK ===")

func _move_to_position(target_pos: Vector2i) -> void:
	"""Move to the target position"""
	if is_moving:
		return
	
	print("=== ZOMBIEGOLFER MOVE DEBUG ===")
	print("Current grid position:", grid_position)
	print("Target grid position:", target_pos)
	print("Cell size:", cell_size)
	
	# Validate target position is within reasonable bounds (same as GangMember)
	if target_pos.x < 0 or target_pos.y < 0 or target_pos.x > 100 or target_pos.y > 100:
		print("⚠️ WARNING: Invalid target position ", target_pos, " - staying in current position")
		_check_turn_completion()
		return
	
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

func _animate_movement_to_position(target_world_pos: Vector2) -> void:
	"""Animate the ZombieGolfer's movement to the target position using a tween"""
	# Play footstep sound right before movement starts
	_play_footstep_sound_before_movement()
	
	# Set moving state
	is_moving = true
	
	# Store the starting position for movement direction calculation
	movement_start_position = global_position
	
	# Play zombie attack sound when starting movement
	_play_zombie_attack_sound()
	
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
	movement_tween.tween_callback(_on_movement_complete)

func _on_movement_complete() -> void:
	"""Called when movement animation completes"""
	is_moving = false
	movement_tween = null
	
	# Update Y-sorting
	update_z_index_for_ysort()
	
	# Check if we should attack the player after movement
	if current_state == State.CHASE and player:
		var player_pos = player.grid_pos
		var distance_to_player = _calculate_distance(grid_position, player_pos)
		
		if distance_to_player <= attack_range and not has_attacked_this_turn:
			_attack_player()
			return  # Attack method handles turn completion
	
	# Check if we can complete the turn now
	_check_turn_completion()

func _attack_player() -> void:
	"""Attack the player"""
	if has_attacked_this_turn:
		return
	
	has_attacked_this_turn = true
	
	# Face the player
	if player:
		var player_pos = player.grid_pos
		var direction = player_pos - grid_position
		if direction.x != 0:
			facing_direction = Vector2i(direction.x, 0)
		elif direction.y != 0:
			facing_direction = Vector2i(0, direction.y)
		
		_update_sprite_facing()
		
		# Deal damage to the player (but don't push them)
		if player.has_method("take_damage"):
			var attack_damage = 25  # Zombie attack damage
			player.take_damage(attack_damage)
	
	# Play zombie attack sound when attacking
	_play_zombie_attack_sound()
	
	# Complete turn immediately after attack
	_complete_turn()

func _on_turn_started(npc: Node) -> void:
	"""Called when an NPC turn starts"""
	# Turn started

func _on_turn_ended(npc: Node) -> void:
	"""Called when an NPC turn ends"""
	# Turn ended

# State Machine Classes
class StateMachine:
	var states: Dictionary = {}
	var current_state: String = ""
	
	func add_state(state_name: String, state: Node) -> void:
		states[state_name] = state
	
	func set_state(state_name: String) -> void:
		if state_name in states:
			current_state = state_name
			if states[state_name].has_method("enter"):
				states[state_name].enter()
	
	func update() -> void:
		if current_state in states and states[current_state].has_method("update"):
			states[current_state].update()

# Base State Class
class BaseState extends Node:
	var zombie: Node
	
	func _init(zombie_ref: Node):
		zombie = zombie_ref
	
	func enter() -> void:
		pass
	
	func update() -> void:
		pass
	
	func exit() -> void:
		pass

class PatrolState extends BaseState:
	func enter() -> void:
		pass
	
	func update() -> void:
		# Random movement up to movement_range spaces away
		var move_distance = randi_range(1, zombie.movement_range)
		var target_pos = _get_random_patrol_position(move_distance)
		
		if target_pos != zombie.grid_position:
			zombie._move_to_position(target_pos)
		else:
			# Face the last movement direction when not moving
			zombie.facing_direction = zombie.last_movement_direction
			zombie._update_sprite_facing()
			# Complete turn immediately since no movement is needed
			zombie._check_turn_completion()
	
	func _get_random_patrol_position(max_distance: int) -> Vector2i:
		var attempts = 0
		var max_attempts = 20  # Increased attempts since we're more restrictive
		
		while attempts < max_attempts:
			# Generate a random direction that respects the movement range
			var random_direction: Vector2i
			
			# 50% chance to move in a cardinal direction (up, down, left, right)
			if randf() < 0.5:
				var cardinal_directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
				random_direction = cardinal_directions[randi() % cardinal_directions.size()] * randi_range(1, max_distance)
			else:
				# 50% chance to move diagonally, but ensure total distance doesn't exceed max_distance
				var x_move = randi_range(-max_distance, max_distance)
				var y_move = randi_range(-max_distance, max_distance)
				
				# Ensure the total Manhattan distance doesn't exceed max_distance
				if abs(x_move) + abs(y_move) <= max_distance:
					random_direction = Vector2i(x_move, y_move)
				else:
					# If diagonal movement would be too far, fall back to cardinal movement
					var cardinal_directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
					random_direction = cardinal_directions[randi() % cardinal_directions.size()] * randi_range(1, max_distance)
			
			var target_pos = zombie.grid_position + random_direction
			
			if zombie._is_valid_position(target_pos):
				return target_pos
			
			attempts += 1
		
		# If no valid position found, try adjacent positions
		var adjacent = zombie._get_valid_adjacent_positions()
		if adjacent.size() > 0:
			var chosen_pos = adjacent[randi() % adjacent.size()]
			return chosen_pos
		
		return zombie.grid_position

class ChaseState extends BaseState:
	func enter() -> void:
		pass
	
	func update() -> void:
		if not zombie.player:
			zombie._check_turn_completion()
			return
		
		# If already moving, don't do anything - wait for movement to complete
		if zombie.is_moving:
			return
		
		var player_pos = zombie.player.grid_pos
		var distance_to_player = zombie._calculate_distance(zombie.grid_position, player_pos)
		
		# Always face the player when in chase mode
		zombie._face_player()
		
		if distance_to_player <= zombie.attack_range:
			# Attack the player (only if we haven't already attacked this turn)
			if not zombie.has_attacked_this_turn:
				zombie._attack_player()
				# Attack method now handles turn completion
			else:
				zombie._check_turn_completion()
		else:
			# Try to move towards player using full movement range
			var path = _get_path_to_player(player_pos)
			
			if path.size() > 1:
				# Calculate how far we can move within our movement range
				var max_movement = min(zombie.movement_range, path.size() - 1)
				var target_pos = path[max_movement]
				zombie._move_to_position(target_pos)
			else:
				# Stay in chase state but complete turn
				zombie._check_turn_completion()

	func _get_path_to_player(player_pos: Vector2i) -> Array[Vector2i]:
		# Simple pathfinding - move towards player (limited to movement range)
		var path: Array[Vector2i] = [zombie.grid_position]
		var current_pos = zombie.grid_position
		var max_steps = zombie.movement_range
		var steps = 0
		
		while current_pos != player_pos and steps < max_steps:
			var direction = (player_pos - current_pos)
			# Normalize the direction vector for Vector2i
			if direction.x != 0:
				direction.x = 1 if direction.x > 0 else -1
			if direction.y != 0:
				direction.y = 1 if direction.y > 0 else -1
			var next_pos = current_pos + direction
			
			if zombie._is_valid_position(next_pos):
				current_pos = next_pos
				path.append(current_pos)
			else:
				# Try to find an alternative path
				var adjacent = zombie._get_valid_adjacent_positions()
				if adjacent.size() > 0:
					# Find the adjacent position closest to player
					var best_pos = adjacent[0]
					var best_distance = zombie._calculate_distance(best_pos, player_pos)
					
					for pos in adjacent:
						var distance = zombie._calculate_distance(pos, player_pos)
						if distance < best_distance:
							best_distance = distance
							best_pos = pos
					
					current_pos = best_pos
					path.append(current_pos)
				else:
					break
			
			steps += 1
		
		return path

class DeadState extends BaseState:
	func enter() -> void:
		pass
	
	func update() -> void:
		# Do nothing when dead
		pass 

func _get_valid_adjacent_positions() -> Array[Vector2i]:
	"""Get valid adjacent positions the ZombieGolfer can move to"""
	var valid_positions: Array[Vector2i] = []
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	
	for direction in directions:
		var new_pos = grid_position + direction
		if _is_valid_position(new_pos):
			valid_positions.append(new_pos)
	
	return valid_positions

func _is_valid_position(pos: Vector2i) -> bool:
	"""Check if a position is valid for movement"""
	# Basic bounds checking - ensure position is within reasonable grid bounds (same as GangMember)
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		return false
	
	# Check if position is occupied by the player
	if player and player.grid_pos == pos:
		return false
	
	# Check if position is not occupied by obstacles
	if course and course.has_method("get_obstacle_at_position"):
		var obstacle = course.get_obstacle_at_position(pos)
		if obstacle:
			return false
	
	return true

func _calculate_distance(pos1: Vector2i, pos2: Vector2i) -> int:
	"""Calculate Manhattan distance between two positions"""
	return abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) 

# Footstep sound system functions
func _setup_footstep_sounds() -> void:
	"""Setup the footstep sound system"""
	print("✓ Setting up ZombieGolfer footstep sound system")
	
	# Find the footstep sound nodes
	footsteps_grass_sound = get_node_or_null("FootstepsGrass")
	footsteps_snow_sound = get_node_or_null("FootstepsSnow")
	
	if footsteps_grass_sound:
		print("✓ ZombieGolfer grass footstep sound found")
	else:
		print("✗ ZombieGolfer grass footstep sound not found")
	
	if footsteps_snow_sound:
		print("✓ ZombieGolfer snow footstep sound found")
	else:
		print("✗ ZombieGolfer snow footstep sound not found")

func _play_footstep_sound_before_movement() -> void:
	"""Play footstep sound right before movement starts"""
	if not footstep_sound_enabled:
		return
	
	# Check if enough time has passed since last footstep
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_footstep_time < footstep_interval:
		return
	
	# Play appropriate footstep sound based on terrain
	if course and course.has_method("get_terrain_type"):
		var terrain_type = course.get_terrain_type(grid_position)
		if terrain_type == "snow" or terrain_type == "ice":
			_play_snow_footstep()
		else:
			_play_grass_footstep()
	else:
		# Default to grass footstep if terrain detection is not available
		_play_grass_footstep()
	
	# Update the last footstep time to prevent rapid successive sounds
	last_footstep_time = current_time

func _play_footstep_sounds_during_movement(progress: float) -> void:
	"""Play footstep sounds during movement animation"""
	if not footstep_sound_enabled:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_footstep_time < footstep_interval:
		return
	
	# Play appropriate footstep sound based on terrain
	if course and course.has_method("get_terrain_type"):
		var terrain_type = course.get_terrain_type(grid_position)
		if terrain_type == "snow" or terrain_type == "ice":
			_play_snow_footstep()
		else:
			_play_grass_footstep()
	else:
		# Default to grass footstep if terrain detection is not available
		_play_grass_footstep()
	
	last_footstep_time = current_time

func _play_grass_footstep() -> void:
	"""Play grass footstep sound"""
	if footsteps_grass_sound and footsteps_grass_sound.stream:
		footsteps_grass_sound.play()
		print("✓ ZombieGolfer played grass footstep sound")

func _play_snow_footstep() -> void:
	"""Play snow footstep sound (for ice and sand)"""
	if footsteps_snow_sound and footsteps_snow_sound.stream:
		footsteps_snow_sound.play()
		print("✓ ZombieGolfer played snow footstep sound")

func enable_footstep_sounds() -> void:
	"""Enable footstep sound effects"""
	footstep_sound_enabled = true
	print("✓ ZombieGolfer footstep sounds enabled")

func disable_footstep_sounds() -> void:
	"""Disable footstep sound effects"""
	footstep_sound_enabled = false
	print("✓ ZombieGolfer footstep sounds disabled")

func set_footstep_interval(interval: float) -> void:
	"""Set the interval between footstep sounds during movement"""
	footstep_interval = max(0.1, interval)  # Minimum 0.1 seconds
	print("✓ ZombieGolfer footstep interval set to:", footstep_interval, "seconds") 
