extends CharacterBody2D

signal player_clicked
signal moved_to_tile(new_grid_pos: Vector2i)

var grid_pos: Vector2i
var movement_range: int = 1
var base_mobility: int = 0
var valid_movement_tiles: Array = []
var is_movement_mode: bool = false
var selected_card = null
var obstacle_map = {}
var grid_size: Vector2i
var cell_size: int = 48

# Highlight effect variables
var character_sprite: Sprite2D = null
var highlight_tween: Tween = null

# Movement animation properties
var is_moving: bool = false
var movement_tween: Tween
var movement_duration: float = 0.3  # Duration of movement animation in seconds
var animations_enabled: bool = false  # Only enable animations after player is placed on tee

# Ball collision and health properties
var base_collision_area: Area2D
var max_health: int = 100
var current_health: int = 100
var is_alive: bool = true

# Ball collision delay system
var collision_delay_distance: float = 100.0  # Distance ball must travel before player collision activates
var ball_launch_position: Vector2 = Vector2.ZERO  # Store where ball was launched from

# Mouse facing system
var game_phase: String = "move"  # Will be updated by parent
var is_charging: bool = false  # Will be updated by parent
var is_charging_height: bool = false  # Will be updated by parent
var camera: Camera2D = null  # Will be set by parent
var is_in_launch_mode: bool = false  # Track if we're in launch mode (ball flying)

# Player facing direction tracking
var current_facing_direction: Vector2i = Vector2i(1, 0)  # Start facing right (1, 0) = right, (-1, 0) = left

# Swing animation system
var swing_animation: Node2D = null
var previous_charging_height: bool = false  # Track previous state to detect changes

# Kick animation system
var kick_animation: Node2D = null
var kick_sprite: Sprite2D = null
var is_kicking: bool = false
var kick_duration: float = 0.5  # Duration of the kick animation
var kick_tween: Tween

# PunchB animation system
var punchb_animation: AnimatedSprite2D = null
var is_punching: bool = false
var punchb_duration: float = 0.5  # Duration of the punch animation
var punchb_tween: Tween

# Meditation system
var meditate_sprite: Sprite2D = null
var is_meditating: bool = false
var meditation_duration: float = 1.0  # Duration of meditation state
var meditation_tween: Tween
var heal_amount: int = 75  # Health restored during meditation

# Ragdoll animation properties
var is_ragdolling: bool = false
var ragdoll_tween: Tween
var ragdoll_duration: float = 1.5  # Duration of ragdoll animation
var ragdoll_landing_position: Vector2i  # Where the player will land after ragdoll

# Performance optimization - Y-sort only when moving
# No camera tracking needed since camera panning doesn't affect Y-sort in 2.5D

# Footstep sound system
var footsteps_grass_sound: AudioStreamPlayer2D = null
var footsteps_snow_sound: AudioStreamPlayer2D = null
var footstep_sound_enabled: bool = true
var last_footstep_time: float = 0.0
var footstep_interval: float = 0.3  # Time between footstep sounds during movement

# Jump animation system (for RooBoost card)
var is_jumping: bool = false
var jump_height: float = 400.0  # Height of the jump in pixels
var jump_duration: float = 0.6  # Duration of the jump animation
var jump_tween: Tween
var shadow_sprite: Sprite2D = null
var ballhop_sound: AudioStreamPlayer2D = null

const SPRITE_GROUND_Y = -43.72

func _ready():
	print("=== PLAYER _READY FUNCTION CALLED ===")
	print("Player name:", name)
	print("Player scene path:", scene_file_path)
	
	# Add to groups for smart optimization and roof bounce system
	add_to_group("collision_objects")
	add_to_group("rectangular_obstacles")  # For rolling ball collisions
	
	# Look for the character sprite (it's added as a direct child by the course script)
	for child in get_children():
		if child is Sprite2D:
			character_sprite = child
			print("[Player.gd] Found character sprite for highlight:", character_sprite, "Initial modulate:", character_sprite.modulate)
			break
		elif child is Node2D:
			# Also check Node2D children in case the structure changes
			for grandchild in child.get_children():
				if grandchild is Sprite2D:
					character_sprite = grandchild
					print("[Player.gd] Found character sprite for highlight:", character_sprite, "Initial modulate:", character_sprite.modulate)
					break
	
	# Setup ball collision area
	_setup_ball_collision()
	
	# Connect to character scene's Area2D for collision detection
	_connect_character_collision()
	
	# Setup swing animation system
	_setup_swing_animation()
	
	# Setup kick animation system
	_setup_kick_animation()
	
	# Setup PunchB animation system
	print("🚨 ABOUT TO CALL _setup_punchb_animation() 🚨")
	_setup_punchb_animation()
	print("🚨 FINISHED CALLING _setup_punchb_animation() 🚨")
	
	# Setup footstep sound system
	_setup_footstep_sounds()
	
	# Setup jump animation system
	_setup_jump_animation()
	
	# Setup meditation system (will be called after character scene is added)
	print("=== MEDITATION SYSTEM SETUP WILL BE DEFERRED ===")
	
	print("[Player.gd] Player ready with health:", current_health, "/", max_health)
	
	# Debug visual height
	var char_sprite = get_character_sprite()
	if char_sprite:
		Global.debug_visual_height(char_sprite, "Player")
	
	print("=== PLAYER _READY COMPLETE ===")

func _connect_character_collision() -> void:
	"""Connect to the character scene's Area2D for collision detection"""
	var character_area = _find_character_area2d()
	if character_area:
		# Disconnect any existing connections to avoid duplicates
		if character_area.area_entered.is_connected(_on_character_area_entered):
			character_area.area_entered.disconnect(_on_character_area_entered)
		if character_area.area_exited.is_connected(_on_area_exited):
			character_area.area_exited.disconnect(_on_area_exited)
		
		# Connect to the character's Area2D
		character_area.area_entered.connect(_on_character_area_entered)
		character_area.area_exited.connect(_on_area_exited)
		print("✓ Connected to character Area2D for collision detection")
	else:
		print("⚠ No character Area2D found for collision detection")

func _setup_ball_collision() -> void:
	"""Setup the base collision area for ball detection"""
	base_collision_area = _find_character_area2d()
	if base_collision_area:
		# Set collision layer to 1 so golf balls can detect it
		# Also set layer 2 so VisionArea2D can detect the player
		base_collision_area.collision_layer = 3  # Layer 1 (1) + Layer 2 (2) = 3
		# Set collision mask to 1 so it can detect golf balls on layer 1
		base_collision_area.collision_mask = 1
		print("✓ Player base collision area setup complete")
		print("✓ Player collision layer: ", base_collision_area.collision_layer, " (layers 1 & 2)")
		print("✓ Player collision mask: ", base_collision_area.collision_mask)
		print("✓ Player monitoring: ", base_collision_area.monitoring)
		print("✓ Player monitorable: ", base_collision_area.monitorable)
	else:
		print("✗ ERROR: BaseCollisionArea not found!")

func _on_character_area_entered(area: Area2D) -> void:
	"""Handle collisions with the character's collision area"""
	var projectile = area.get_parent()
	if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
		# Handle the collision using proper Area2D collision detection
		_handle_area_collision(projectile)

func _on_area_exited(area: Area2D) -> void:
	"""Handle when projectile exits the Player area - reset ground level"""
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
	"""Handle Player area collisions using proper Area2D detection"""
	print("=== HANDLING PLAYER AREA COLLISION ===")
	print("Projectile name:", projectile.name)
	print("Projectile type:", projectile.get_class())
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_reflect_projectile(projectile)
		return
	
	# Get projectile and Player heights
	var projectile_height = projectile.get_height()
	var player_height = Global.get_object_height_from_marker(self)
	
	print("Projectile height:", projectile_height)
	print("Player height:", player_height)
	
	# Check if this is a throwing knife (special handling)
	if projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_knife_area_collision(projectile, projectile_height, player_height)
		return
	
	# Apply the collision logic:
	# If projectile height > Player height: allow entry and set ground level
	# If projectile height < Player height: reflect
	if projectile_height > player_height:
		print("✓ Projectile is above Player - allowing entry and setting ground level")
		_allow_projectile_entry(projectile, player_height)
	else:
		print("✗ Projectile is below Player height - reflecting")
		_reflect_projectile(projectile)

func _handle_knife_area_collision(knife: Node2D, knife_height: float, player_height: float):
	"""Handle knife collision with Player area"""
	print("Handling knife Player area collision")
	
	if knife_height > player_height:
		print("✓ Knife is above Player - allowing entry and setting ground level")
		_allow_projectile_entry(knife, player_height)
	else:
		print("✗ Knife is below Player height - reflecting")
		_reflect_projectile(knife)

func _allow_projectile_entry(projectile: Node2D, player_height: float):
	"""Allow projectile to enter Player area and set ground level"""
	print("=== ALLOWING PROJECTILE ENTRY (PLAYER) ===")
	
	# Set the projectile's ground level to the Player height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(player_height)
	else:
		# Fallback: directly set ground level if method doesn't exist
		if "current_ground_level" in projectile:
			projectile.current_ground_level = player_height
			print("✓ Set projectile ground level to Player height:", player_height)
	
	# The projectile will now land on the Player's head instead of passing through
	# When it exits the area, _on_area_exited will reset the ground level

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the Player"""
	print("=== REFLECTING PROJECTILE ===")
	
	# Play collision sound for Player collision
	_play_collision_sound()
	
	# Get the projectile's current velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	print("Reflecting projectile with velocity:", projectile_velocity)
	
	var projectile_pos = projectile.global_position
	var player_center = global_position
	
	# Calculate the direction from Player center to projectile
	var to_projectile_direction = (projectile_pos - player_center).normalized()
	
	# Simple reflection: reflect the velocity across the Player center
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
		# Ball/knife is above Player entirely - let it pass through
		print("Ball/knife is above Player entirely - passing through")
		return
	else:
		# Ball/knife is within or below Player height - handle collision
		print("Ball/knife is within Player height - handling collision")
		
		# Check if this is a throwing knife
		if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
			# Handle knife collision with Player
			_handle_knife_collision(ball)
		else:
			# Handle regular ball collision
			_handle_regular_ball_collision(ball)

func _handle_knife_collision(knife: Node2D) -> void:
	"""Handle knife collision with Player"""
	print("Handling knife collision with Player")
	
	# Play collision sound effect
	_play_collision_sound()
	
	# Let the knife handle its own collision logic
	# The knife will determine if it should bounce or stick based on which side hits
	if knife.has_method("_handle_player_collision"):
		knife._handle_player_collision(self)
	else:
		# Fallback: just reflect the knife
		_apply_knife_reflection(knife)

func _handle_regular_ball_collision(ball: Node2D) -> void:
	"""Handle regular ball collision with Player"""
	print("Handling regular ball collision with Player")
	
	# Play collision sound effect
	_play_collision_sound()
	
	# Apply collision effect to the ball
	_apply_ball_collision_effect(ball)

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
		var player_center = global_position
		
		# Calculate the direction from Player center to ball
		var to_ball_direction = (ball_pos - player_center).normalized()
		
		# Simple reflection: reflect the velocity across the Player center
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
	
	# Check if this damage will kill the Player
	var will_kill = damage >= current_health
	var overkill_damage = 0
	
	if will_kill:
		# Calculate overkill damage (negative health value)
		overkill_damage = damage - current_health
		print("Damage will kill Player! Overkill damage:", overkill_damage)
		
		# Apply damage to the Player (this will set health to negative)
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
		var player_center = global_position
		
		# Calculate the direction from Player center to ball
		var to_ball_direction = (ball_pos - player_center).normalized()
		
		# Simple reflection: reflect the velocity across the Player center
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
	var player_center = global_position
	
	# Calculate the direction from Player center to knife
	var to_knife_direction = (knife_pos - player_center).normalized()
	
	# Simple reflection: reflect the velocity across the Player center
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

# Headshot mechanics (same as GangMember)
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

func _calculate_velocity_damage(velocity_magnitude: float) -> int:
	"""Calculate damage based on ball velocity magnitude (same as GangMember)"""
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
	print("=== PLAYER VELOCITY DAMAGE CALCULATION ===")
	print("Raw velocity magnitude:", velocity_magnitude)
	print("Clamped velocity:", clamped_velocity)
	print("Damage percentage:", damage_percentage)
	print("Calculated damage:", damage)
	print("Final damage (int):", final_damage)
	print("=== END PLAYER VELOCITY DAMAGE CALCULATION ===")
	
	return final_damage

func _calculate_kill_dampening(ball_velocity: Vector2, overkill_damage: int) -> Vector2:
	"""Calculate velocity dampening when ball kills the Player (same as GangMember)"""
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
	print("=== PLAYER KILL DAMPENING CALCULATION ===")
	print("Overkill damage:", overkill_damage)
	print("Clamped overkill:", clamped_overkill)
	print("Dampening percentage:", dampening_percentage)
	print("Dampening factor:", dampening_factor)
	print("Original velocity magnitude:", ball_velocity.length())
	print("Dampened velocity magnitude:", dampened_velocity.length())
	print("=== END PLAYER KILL DAMPENING CALCULATION ===")
	
	return dampened_velocity

func _play_collision_sound() -> void:
	"""Play a sound effect when colliding with projectiles"""
	# Try to find an audio player in the course
	var course = get_tree().current_scene
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

func take_damage(amount: int, is_headshot: bool = false) -> void:
	"""Take damage and handle death if health reaches 0"""
	if not is_alive:
		print("Player is already dead, ignoring damage")
		return
	
	# Allow negative health for overkill calculations
	current_health = current_health - amount
	print("Player took", amount, "damage. Current health:", current_health, "/", max_health)
	
	# Play push sound when taking damage
	var push_sound = get_node_or_null("Push")
	if push_sound and push_sound is AudioStreamPlayer2D:
		push_sound.play()
		print("✓ Played push sound for damage")
	else:
		print("✗ Push sound not found or not AudioStreamPlayer2D")
	
	# Update the course's health bar
	var course = get_tree().current_scene
	if course and course.has_method("take_damage"):
		course.take_damage(amount)
		print("✓ Updated course health bar with", amount, "damage")
	
	# Flash appropriate effect based on damage type
	if is_headshot:
		flash_headshot()
	else:
		flash_damage()
	
	if current_health <= 0:
		print("Player health reached 0 - GAME OVER!")
		# You can add game over logic here
		is_alive = false
	else:
		print("Player survived with", current_health, "health")

func flash_headshot() -> void:
	"""Flash the Player with a special headshot effect"""
	var sprite = get_character_sprite()
	if not sprite:
		print("[Player.gd] flash_headshot: No character sprite for headshot flash!")
		return
	
	var original_modulate = sprite.modulate
	var tween = create_tween()
	# Flash with a bright gold color for headshots
	tween.tween_property(sprite, "modulate", Color(1, 0.84, 0, 1), 0.15)  # Bright gold
	tween.tween_property(sprite, "modulate", Color(1, 0.65, 0, 1), 0.1)   # Deeper gold
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)

func flash_damage():
	"""Flash the player red to indicate damage taken"""
	var sprite = get_character_sprite()
	if not sprite:
		print("[Player.gd] flash_damage: No character sprite for damage flash!")
		return
	
	if highlight_tween:
		highlight_tween.kill()
	
	highlight_tween = create_tween()
	# Flash red for 0.3 seconds, then return to normal
	highlight_tween.tween_property(sprite, "modulate", Color(1, 0, 0, 1), 0.1)
	highlight_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.2)

func get_character_sprite() -> Sprite2D:
	# First check direct children
	for child in get_children():
		if child is Sprite2D:
			return child
		elif child is Node2D:
			# Also check Node2D children in case the structure changes
			for grandchild in child.get_children():
				if grandchild is Sprite2D:
					return grandchild
	return null

func show_highlight():
	var sprite = get_character_sprite()
	if not sprite:
		print("[Player.gd] show_highlight: No character sprite for highlight!")
		return
	if highlight_tween:
		highlight_tween.kill()
	highlight_tween = create_tween()
	highlight_tween.tween_property(sprite, "modulate", Color(1, 1, 0, 0.6), 0.3)

func hide_highlight():
	var sprite = get_character_sprite()
	if not sprite:
		print("[Player.gd] hide_highlight: No character sprite for highlight!")
		return
	if highlight_tween:
		highlight_tween.kill()
	highlight_tween = create_tween()
	highlight_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.3)

func force_reset_highlight():
	var sprite = get_character_sprite()
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
		if highlight_tween:
			highlight_tween.kill()
	else:
		print("[Player.gd] force_reset_highlight: No character sprite to reset!")

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("player_clicked")

func setup(grid_size_: Vector2i, cell_size_: int, base_mobility_: int, obstacle_map_: Dictionary):
	grid_size = grid_size_
	cell_size = cell_size_
	base_mobility = base_mobility_
	obstacle_map = obstacle_map_
	
	# Create highlight sprite after setup is complete
	print("Setup complete, deferring highlight sprite creation...")
	call_deferred("create_highlight_sprite")

func set_grid_position(pos: Vector2i, ysort_objects: Array = [], shop_grid_pos: Vector2i = Vector2i.ZERO):
	grid_pos = pos
	var target_world_pos = Vector2(pos.x, pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Only use animated movement if animations are enabled
	if animations_enabled:
		_animate_movement_to_position(target_world_pos, ysort_objects, shop_grid_pos)
	else:
		# Instant movement during initialization
		self.position = target_world_pos
		update_z_index_for_ysort(ysort_objects, shop_grid_pos)

func _animate_movement_to_position(target_world_pos: Vector2, ysort_objects: Array = [], shop_grid_pos: Vector2i = Vector2i.ZERO) -> void:
	"""Animate the player's movement to the target position using a tween"""
	# Set moving state
	is_moving = true
	
	# Stop any existing movement tween
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
	
	# Check if this should be a jump animation (RooBoost effect)
	var should_jump = false
	var course = get_tree().current_scene
	if course and course.has_method("get_movement_controller"):
		var movement_controller = course.get_movement_controller()
		if movement_controller and movement_controller.has_method("get_selected_card"):
			var selected_card = movement_controller.get_selected_card()
			# Only apply RooBoost effect if we're in movement mode (i.e., a movement card is selected)
			if selected_card and course.next_movement_card_rooboost:
				should_jump = true
				print("✓ RooBoost effect detected - using jump animation for movement card:", selected_card.name)
	
	if should_jump:
		_animate_jump_to_position(target_world_pos, ysort_objects, shop_grid_pos)
	else:
		# Normal movement animation
		# Play footstep sound right before movement starts
		_play_footstep_sound_before_movement()
		
		# Create new tween for movement
		movement_tween = create_tween()
		movement_tween.set_trans(Tween.TRANS_QUAD)
		movement_tween.set_ease(Tween.EASE_OUT)
		
		# Start the movement animation
		movement_tween.tween_property(self, "position", target_world_pos, movement_duration)
		
		# Update Y-sorting during movement
		movement_tween.tween_callback(update_z_index_for_ysort.bind(ysort_objects, shop_grid_pos))
		
		# Update camera position during movement (every frame)
		movement_tween.tween_method(_update_camera_during_movement, 0.0, 1.0, movement_duration)
		
		# When movement completes
		movement_tween.tween_callback(_on_movement_completed)
		
		print("Started player movement animation to position: ", target_world_pos)

func _animate_jump_to_position(target_world_pos: Vector2, ysort_objects: Array = [], shop_grid_pos: Vector2i = Vector2i.ZERO) -> void:
	"""Animate the player's jump to the target position using a tween"""
	print("=== STARTING PLAYER JUMP ANIMATION ===")
	
	# Set jumping state
	is_jumping = true
	
	# Stop any existing jump tween
	if jump_tween and jump_tween.is_valid():
		jump_tween.kill()
	
	# Play BallHop sound right before jump starts
	if ballhop_sound and ballhop_sound.stream:
		ballhop_sound.play()
		print("✓ Playing BallHop sound for jump animation")
	
	# Get the character sprite for height animation
	var char_sprite = get_character_sprite()
	if not char_sprite:
		print("⚠ Character sprite not found for jump animation")
		return
	
	# Store original sprite position
	var original_sprite_pos = char_sprite.position
	
	# Create new tween for jump
	jump_tween = create_tween()
	jump_tween.set_trans(Tween.TRANS_QUAD)
	jump_tween.set_ease(Tween.EASE_OUT)
	
	# Animate horizontal movement (this moves both the player and shadow)
	jump_tween.parallel().tween_property(self, "position", target_world_pos, jump_duration)
	
	# Animate vertical jump (only the sprite moves up and down, shadow stays on ground)
	var jump_curve = jump_tween.parallel().tween_method(_update_jump_height, 0.0, 1.0, jump_duration)
	jump_curve.set_trans(Tween.TRANS_QUAD)
	jump_curve.set_ease(Tween.EASE_OUT)
	
	# Update Y-sorting during jump
	jump_tween.tween_callback(update_z_index_for_ysort.bind(ysort_objects, shop_grid_pos))
	
	# Update camera position during jump (every frame)
	jump_tween.tween_method(_update_camera_during_movement, 0.0, 1.0, jump_duration)
	
	# When jump completes
	jump_tween.tween_callback(_on_jump_completed)
	
	print("✓ Started player jump animation to position:", target_world_pos)
	print("✓ Jump height:", jump_height, "pixels")
	print("✓ Jump duration:", jump_duration, "seconds")
	print("✓ Shadow will stay on ground while sprite jumps")

func _update_jump_height(progress: float) -> void:
	"""Update the player's height during jump animation"""
	var char_sprite = get_character_sprite()
	if not char_sprite:
		return
	
	# Calculate jump height using a parabolic curve (up then down)
	var height_progress = 0.0
	if progress <= 0.5:
		# Going up (0.0 to 0.5)
		height_progress = progress * 2.0  # 0.0 to 1.0
	else:
		# Coming down (0.5 to 1.0)
		height_progress = (1.0 - progress) * 2.0  # 1.0 to 0.0
	
	# Apply height to sprite position only (shadow stays on ground)
	var jump_offset = jump_height * height_progress
	char_sprite.position.y = SPRITE_GROUND_Y - jump_offset  # Start and end at -43.72
	
	# Update shadow scale and opacity based on height (shadow stays on ground but changes appearance)
	if shadow_sprite:
		var min_shadow_scale = 0.5  # Smallest shadow at max height
		var max_shadow_scale = 1.0  # Full size on ground
		var min_shadow_alpha = 0.1  # Most transparent at max height
		var max_shadow_alpha = 0.4  # Most opaque on ground
		
		var shadow_scale = lerp(max_shadow_scale, min_shadow_scale, height_progress)
		var shadow_alpha = lerp(max_shadow_alpha, min_shadow_alpha, height_progress)
		
		# Keep shadow on ground but change its scale and opacity
		shadow_sprite.scale = Vector2(1.815, 0.756) * shadow_scale  # Use original shadow scale
		shadow_sprite.modulate = Color(0, 0, 0, shadow_alpha)  # Keep black color, change alpha
		shadow_sprite.position.y = -4  # Keep shadow at ground level (original position)
	
	# Check for collisions during jump (only when coming down)
	if progress > 0.5:
		check_jump_collisions()

func _on_jump_completed() -> void:
	"""Called when player jump animation completes"""
	print("=== PLAYER JUMP ANIMATION COMPLETED ===")
	
	is_jumping = false
	
	# Reset sprite position
	var char_sprite = get_character_sprite()
	if char_sprite:
		char_sprite.position.y = SPRITE_GROUND_Y  # Reset to grounded offset
	
	# Reset shadow to original state
	if shadow_sprite:
		shadow_sprite.scale = Vector2(1.815, 0.756)  # Reset to original shadow scale
		shadow_sprite.modulate = Color(0, 0, 0, 0.3)  # Reset to original black color and opacity
		shadow_sprite.position.y = -4  # Reset to original ground position
	
	# Update Y-sorting one final time
	update_z_index_for_ysort([], Vector2i.ZERO)
	
	# Smoothly tween camera to final position
	var course = get_tree().current_scene
	if course and course.has_method("smooth_camera_to_player"):
		course.smooth_camera_to_player()
	
	print("✓ Player jump animation completed")
	print("✓ Shadow reset to ground level")

func check_jump_collisions() -> void:
	"""Check for wall collisions and NPC landings during jump"""
	if not is_jumping:
		return
	
	var course = get_tree().current_scene
	if not course:
		return
	
	# Check for wall collisions using Area2D
	var area2d = _find_character_area2d()
	if area2d:
		var overlapping_areas = area2d.get_overlapping_areas()
		for area in overlapping_areas:
			var object = area.get_parent()
			if not object:
				continue
			
			# Check for wall collisions
			if object.has_method("_handle_wall_area_collision"):
				print("Jump collision with wall detected")
				_handle_jump_wall_collision(object)
				return
			
			# Check for NPC collisions
			if object.has_method("_handle_ball_collision") and (object.name.contains("GangMember") or object.name.contains("Police")):
				print("Jump landing on NPC detected")
				_handle_jump_npc_landing(object)
				return

func _handle_jump_wall_collision(wall: Node2D) -> void:
	"""Handle wall collision during jump - player bounces off wall"""
	print("=== HANDLING JUMP WALL COLLISION ===")
	
	# Calculate bounce direction (away from wall)
	var wall_center = wall.global_position
	var player_pos = global_position
	var bounce_direction = (player_pos - wall_center).normalized()
	
	# Calculate bounce distance (2 tiles away from wall)
	var bounce_distance = 96.0  # 2 tiles * 48 pixels
	var bounce_target = wall_center + (bounce_direction * bounce_distance)
	
	# Convert to grid position
	var grid_x = floor((bounce_target.x - cell_size / 2) / cell_size)
	var grid_y = floor((bounce_target.y - cell_size / 2) / cell_size)
	var bounce_grid_pos = Vector2i(grid_x, grid_y)
	
	# Validate grid position bounds (0 to grid_size-1 for both x and y)
	var course = get_tree().current_scene
	if course and "grid_size" in course:
		var grid_size = course.grid_size
		bounce_grid_pos.x = clamp(bounce_grid_pos.x, 0, grid_size.x - 1)
		bounce_grid_pos.y = clamp(bounce_grid_pos.y, 0, grid_size.y - 1)
		print("✓ Grid position clamped to valid bounds:", bounce_grid_pos)
	else:
		# Fallback bounds checking if course reference not available
		bounce_grid_pos.x = clamp(bounce_grid_pos.x, 0, 49)  # Default 50x50 grid
		bounce_grid_pos.y = clamp(bounce_grid_pos.y, 0, 49)
		print("✓ Grid position clamped to fallback bounds:", bounce_grid_pos)
	
	# Update player position and continue jump to bounce target
	grid_pos = bounce_grid_pos
	var bounce_world_pos = Vector2(bounce_grid_pos.x, bounce_grid_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Continue jump to bounce target
	if jump_tween and jump_tween.is_valid():
		jump_tween.kill()
	
	jump_tween = create_tween()
	jump_tween.tween_property(self, "position", bounce_world_pos, jump_duration * 0.5)  # Faster bounce
	jump_tween.tween_callback(_on_jump_completed)
	
	print("✓ Player bounced off wall to position:", bounce_grid_pos)

func _handle_jump_npc_landing(npc: Node2D) -> void:
	"""Handle landing on NPC during jump - player roof bounces off NPC"""
	print("=== HANDLING JUMP NPC LANDING ===")
	
	# Get the direction the player was jumping (from current position to target)
	var course = get_tree().current_scene
	if not course:
		print("⚠ No course reference found for NPC landing")
		return
	
	# Calculate the jump direction based on the player's movement
	var jump_direction = Vector2i.ZERO
	if jump_tween and jump_tween.is_valid():
		# Get the target position from the current jump
		var target_pos = position + (velocity if "velocity" in self else Vector2.ZERO)
		var direction = (target_pos - global_position).normalized()
		jump_direction = Vector2i(sign(direction.x), sign(direction.y))
	else:
		# Fallback: calculate direction from player to NPC center
		var npc_center = npc.global_position
		var player_pos = global_position
		var direction = (player_pos - npc_center).normalized()
		jump_direction = Vector2i(sign(direction.x), sign(direction.y))
	
	print("Jump direction:", jump_direction)
	
	# Get NPC's grid position
	var npc_grid_pos = Vector2i.ZERO
	if npc.has_method("get_grid_position"):
		npc_grid_pos = npc.get_grid_position()
	else:
		# Fallback: calculate NPC grid position from world position
		var npc_center = npc.global_position
		npc_grid_pos = Vector2i(floor((npc_center.x - cell_size / 2) / cell_size), floor((npc_center.y - cell_size / 2) / cell_size))
	
	print("NPC grid position:", npc_grid_pos)
	
	# Calculate ideal landing position (2 tiles behind NPC in jump direction)
	var ideal_landing_pos = npc_grid_pos + (jump_direction * 2)
	print("Ideal landing position:", ideal_landing_pos)
	
	# Try to find a valid landing position
	var final_landing_pos = _find_valid_landing_position(ideal_landing_pos, course)
	
	# Update player position and continue jump to landing target
	grid_pos = final_landing_pos
	var landing_world_pos = Vector2(final_landing_pos.x, final_landing_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Create a special roof bounce animation that aligns Feet with NPC TopHeight
	_animate_roof_bounce_to_position(landing_world_pos, npc)
	
	print("✓ Player roof bounced off NPC to position:", final_landing_pos)

func _animate_roof_bounce_to_position(target_world_pos: Vector2, npc: Node2D) -> void:
	"""Animate the player's roof bounce with Feet marker alignment"""
	print("=== STARTING ROOF BOUNCE ANIMATION ===")
	
	# Stop any existing jump tween
	if jump_tween and jump_tween.is_valid():
		jump_tween.kill()
	
	# Get the Feet marker
	var feet_marker = get_node_or_null("Feet")
	if not feet_marker:
		print("⚠ Feet marker not found, using normal bounce animation")
		# Fallback to normal bounce animation
		jump_tween = create_tween()
		jump_tween.tween_property(self, "position", target_world_pos, jump_duration * 0.5)
		jump_tween.tween_callback(_on_jump_completed)
		return
	
	# Get the NPC's TopHeight marker
	var npc_top_height = npc.get_node_or_null("TopHeight")
	if not npc_top_height:
		print("⚠ NPC TopHeight marker not found, using normal bounce animation")
		# Fallback to normal bounce animation
		jump_tween = create_tween()
		jump_tween.tween_property(self, "position", target_world_pos, jump_duration * 0.5)
		jump_tween.tween_callback(_on_jump_completed)
		return
	
	print("✓ Found Feet marker and NPC TopHeight marker")
	
	# Calculate the height difference to align Feet with TopHeight
	var feet_world_pos = feet_marker.global_position
	var npc_top_world_pos = npc_top_height.global_position
	var height_difference = npc_top_world_pos.y - feet_world_pos.y
	
	print("Feet world position:", feet_world_pos)
	print("NPC TopHeight world position:", npc_top_world_pos)
	print("Height difference to align:", height_difference)
	
	# Play BallHop sound for roof bounce
	if ballhop_sound and ballhop_sound.stream:
		ballhop_sound.play()
		print("✓ Playing BallHop sound for roof bounce")
	
	# Create roof bounce animation with vertical boost
	jump_tween = create_tween()
	jump_tween.set_trans(Tween.TRANS_QUAD)
	jump_tween.set_ease(Tween.EASE_OUT)
	
	# Phase 1: Move to NPC position and align Feet with TopHeight
	var npc_center = npc.global_position
	var bounce_duration = jump_duration * 0.5  # Faster bounce
	
	# Calculate the position where Feet will align with TopHeight
	var alignment_pos = npc_center
	alignment_pos.y += height_difference  # Adjust for height alignment
	
	print("Alignment position (Feet meets TopHeight):", alignment_pos)
	
	# Move to alignment position
	jump_tween.tween_property(self, "position", alignment_pos, bounce_duration * 0.4)
	
	# Phase 2: Add vertical boost (smaller than original jump)
	var boost_height = jump_height * 0.4  # 40% of original jump height
	var boost_duration = bounce_duration * 0.3
	
	# Calculate boost position (slightly above alignment position)
	var boost_pos = alignment_pos
	boost_pos.y -= boost_height
	
	print("Boost position (vertical boost):", boost_pos)
	print("Boost height:", boost_height, "pixels")
	
	# Animate vertical boost
	jump_tween.tween_property(self, "position", boost_pos, boost_duration)
	
	# Phase 3: Continue to final landing position
	jump_tween.tween_property(self, "position", target_world_pos, bounce_duration * 0.3).set_delay(bounce_duration * 0.7)
	
	# Animate character sprite during roof bounce
	var char_sprite = get_character_sprite()
	if char_sprite:
		# Animate sprite height during boost
		jump_tween.parallel().tween_method(_update_roof_bounce_height, 0.0, 1.0, bounce_duration)
	
	# Update Y-sorting during bounce
	jump_tween.tween_callback(update_z_index_for_ysort.bind([], Vector2i.ZERO))
	
	# Update camera position during bounce
	jump_tween.tween_method(_update_camera_during_movement, 0.0, 1.0, bounce_duration)
	
	# When bounce completes
	jump_tween.tween_callback(_on_jump_completed)
	
	print("✓ Roof bounce animation started - Feet will align with NPC TopHeight + vertical boost")

func _update_roof_bounce_height(progress: float) -> void:
	"""Update the player's height during roof bounce animation"""
	var char_sprite = get_character_sprite()
	if not char_sprite:
		return
	
	# Calculate boost height using a parabolic curve
	var height_progress = 0.0
	if progress <= 0.4:
		# Going up to alignment (0.0 to 0.4)
		height_progress = 0.0  # Stay at ground level
	elif progress <= 0.7:
		# Going up for boost (0.4 to 0.7)
		var boost_progress = (progress - 0.4) / 0.3  # 0.0 to 1.0
		height_progress = boost_progress
	else:
		# Coming down (0.7 to 1.0)
		var fall_progress = (progress - 0.7) / 0.3  # 0.0 to 1.0
		height_progress = 1.0 - fall_progress
	
	# Apply height to sprite position only (shadow stays on ground)
	var boost_offset = jump_height * 0.4 * height_progress  # 40% of original jump height
	char_sprite.position.y = SPRITE_GROUND_Y - boost_offset  # Start and end at -43.72
	
	# Update shadow scale and opacity based on height
	if shadow_sprite:
		var min_shadow_scale = 0.7  # Not as small as full jump
		var max_shadow_scale = 1.0  # Full size on ground
		var min_shadow_alpha = 0.2  # Not as transparent as full jump
		var max_shadow_alpha = 0.4  # Most opaque on ground
		
		var shadow_scale = lerp(max_shadow_scale, min_shadow_scale, height_progress)
		var shadow_alpha = lerp(max_shadow_alpha, min_shadow_alpha, height_progress)
		
		# Keep shadow on ground but change its scale and opacity
		shadow_sprite.scale = Vector2(1.815, 0.756) * shadow_scale
		shadow_sprite.modulate = Color(0, 0, 0, shadow_alpha)
		shadow_sprite.position.y = -4  # Keep shadow at ground level

func _find_valid_landing_position(ideal_pos: Vector2i, course: Node) -> Vector2i:
	"""Find a valid landing position, starting with ideal position and falling back to adjacent tiles"""
	var grid_size = course.grid_size if "grid_size" in course else Vector2i(50, 50)
	var obstacle_map = course.obstacle_map if "obstacle_map" in course else {}
	
	# First, try the ideal position
	if _is_position_valid_for_landing(ideal_pos, grid_size, obstacle_map):
		print("✓ Ideal landing position is valid:", ideal_pos)
		return ideal_pos
	
	print("⚠ Ideal landing position not valid, trying adjacent positions")
	
	# Try adjacent positions in order of preference (prioritizing the jump direction)
	var adjacent_positions = []
	
	# Add positions in the jump direction first (if we can determine it)
	var jump_direction = ideal_pos - Vector2i(floor(global_position.x / cell_size), floor(global_position.y / cell_size))
	if jump_direction != Vector2i.ZERO:
		# Normalize jump direction
		jump_direction.x = sign(jump_direction.x)
		jump_direction.y = sign(jump_direction.y)
		
		# Add positions in jump direction first
		for i in range(1, 4):  # Try 1-3 tiles in jump direction
			var pos = ideal_pos + (jump_direction * i)
			if _is_position_valid_for_landing(pos, grid_size, obstacle_map):
				adjacent_positions.append(pos)
	
	# Add all adjacent positions (up, right, down, left, diagonals)
	var directions = [
		Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),  # Cardinal directions
		Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(-1, 1)  # Diagonal directions
	]
	
	for direction in directions:
		var pos = ideal_pos + direction
		if _is_position_valid_for_landing(pos, grid_size, obstacle_map) and pos not in adjacent_positions:
			adjacent_positions.append(pos)
	
	# Return the first valid adjacent position, or the ideal position if none found
	if adjacent_positions.size() > 0:
		print("✓ Found valid adjacent landing position:", adjacent_positions[0])
		return adjacent_positions[0]
	else:
		print("⚠ No valid adjacent positions found, using ideal position with bounds clamping")
		# Clamp to bounds as last resort
		var clamped_pos = Vector2i(
			clamp(ideal_pos.x, 0, grid_size.x - 1),
			clamp(ideal_pos.y, 0, grid_size.y - 1)
		)
		return clamped_pos

func _is_position_valid_for_landing(pos: Vector2i, grid_size: Vector2i, obstacle_map: Dictionary) -> bool:
	"""Check if a position is valid for landing (within bounds and not blocked)"""
	# Check bounds
	if pos.x < 0 or pos.y < 0 or pos.x >= grid_size.x or pos.y >= grid_size.y:
		return false
	
	# Check if position is blocked by obstacle
	if obstacle_map.has(pos):
		var obstacle = obstacle_map[pos]
		if obstacle and obstacle.has_method("blocks") and obstacle.blocks():
			return false
	
	# Check if position is occupied by NPC
	var course = get_tree().current_scene
	if course and course.has_node("Entities"):
		var entities = course.get_node("Entities")
		if entities and entities.has_method("get_npcs"):
			var npcs = entities.get_npcs()
			for npc in npcs:
				if is_instance_valid(npc) and npc.has_method("get_grid_position"):
					if npc.get_grid_position() == pos:
						return false
	
	return true

func _update_camera_during_movement(progress: float) -> void:
	"""Update camera position during movement animation"""
	# Get the course reference to update camera
	var course = get_tree().current_scene
	if not course or not course.has_method("update_camera_to_player"):
		return
	
	# Call the course's camera update method
	course.update_camera_to_player()

func _on_movement_completed() -> void:
	"""Called when player movement animation completes"""
	is_moving = false
	print("Player movement animation completed")
	
	# Update Y-sorting one final time (with empty arrays as defaults)
	update_z_index_for_ysort([], Vector2i.ZERO)
	
	# Smoothly tween camera to final position
	var course = get_tree().current_scene
	if course and course.has_method("smooth_camera_to_player"):
		course.smooth_camera_to_player()

func update_z_index_for_ysort(ysort_objects: Array, shop_grid_pos: Vector2i = Vector2i.ZERO) -> void:
	"""Update player Y-sort using the simple global system"""
	# Use the global Y-sort system for characters
	Global.update_object_y_sort(self, "characters")
	
	# Special case: If player is on shop entrance tile, ensure they appear on top of the shop
	if shop_grid_pos != Vector2i.ZERO and grid_pos == shop_grid_pos:
		# Force player to appear above shop by setting a higher z_index
		# The shop typically has z_index around 1000-1100, so we'll set player to 1200+
		var current_z = z_index
		var shop_entrance_z = 1200  # Higher than typical shop z_index
		if current_z < shop_entrance_z:
			z_index = shop_entrance_z
			print("✓ Player z_index boosted to", z_index, "for shop entrance")

func start_movement_mode(card, movement_range_: int):
	selected_card = card
	movement_range = movement_range_
	is_movement_mode = true
	calculate_valid_movement_tiles()

func end_movement_mode():
	is_movement_mode = false
	selected_card = null
	valid_movement_tiles.clear()

func calculate_valid_movement_tiles():
	
	valid_movement_tiles.clear()
	var equipment_mobility = get_equipment_mobility_bonus()
	var total_range = movement_range + base_mobility + equipment_mobility
	
	# Special case for Dash card - show cross pattern (no diagonals)
	if selected_card and selected_card.name == "Dash":
		print("Dash card detected - showing cross pattern movement")
		var cross_positions = []
		
		# Add positions in cross pattern: up, down, left, right (no diagonals)
		for distance in range(1, total_range + 1):
			# Up
			var up_pos = Vector2i(grid_pos.x, grid_pos.y - distance)
			if up_pos.y >= 0:
				cross_positions.append(up_pos)
			
			# Down
			var down_pos = Vector2i(grid_pos.x, grid_pos.y + distance)
			if down_pos.y < grid_size.y:
				cross_positions.append(down_pos)
			
			# Left
			var left_pos = Vector2i(grid_pos.x - distance, grid_pos.y)
			if left_pos.x >= 0:
				cross_positions.append(left_pos)
			
			# Right
			var right_pos = Vector2i(grid_pos.x + distance, grid_pos.y)
			if right_pos.x < grid_size.x:
				cross_positions.append(right_pos)
		
		# Check obstacles for cross positions
		for pos in cross_positions:
			if obstacle_map.has(pos):
				var obstacle = obstacle_map[pos]
				if obstacle.has_method("blocks") and obstacle.blocks():
					continue
			valid_movement_tiles.append(pos)
		
		print("Total cross pattern tiles for Dash card:", valid_movement_tiles.size())
		return
	
	# Default movement pattern (diamond shape) for other movement cards
	for y in grid_size.y:
		for x in grid_size.x:
			var pos := Vector2i(x, y)
			if calculate_grid_distance(grid_pos, pos) <= total_range and pos != grid_pos:
				if obstacle_map.has(pos):
					var obstacle = obstacle_map[pos]
					if obstacle.has_method("blocks") and obstacle.blocks():
						continue
				valid_movement_tiles.append(pos)

func calculate_grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func can_move_to(pos: Vector2i) -> bool:
	return is_movement_mode and pos in valid_movement_tiles

func move_to_grid(pos: Vector2i):
	
	if can_move_to(pos):
		set_grid_position(pos)
		emit_signal("moved_to_tile", pos)
		print("Signal emitted, ending movement mode")
		end_movement_mode()
		print("Movement mode ended")
	else:
		print("Movement is invalid - cannot move to this position")
	print("=== END PLAYER.GD MOVE_TO_GRID DEBUG ===")

func _process(delta):
	# OPTIMIZED: Only update Y-sort when Player moves
	# Camera panning doesn't change Y-sort relationships in 2.5D perspective
	# No need to update Y-sort every frame or when camera moves
	
	# Handle mouse facing system
	_update_mouse_facing()
	
	# Handle swing animation based on height charge state
	_update_swing_animation()
	
	# Try to setup swing animation if not already done (in case character scene is added later)
	if not swing_animation and get_child_count() > 0:
		_setup_swing_animation()
	
	# Try to setup kick animation if not already done (in case character scene is added later)
	if not kick_sprite and get_child_count() > 0:
		_setup_kick_animation()
	
	# Try to setup punch animation if not already done (in case character scene is added later)
	if not punchb_animation and get_child_count() > 0:
		_setup_punchb_animation()

func _update_mouse_facing() -> void:
	"""Update player sprite to face the mouse direction when appropriate"""
	var sprite = get_character_sprite()
	if not sprite:
		return
	
	# Only face mouse when it's player's turn and not in launch charge mode or ball flying mode
	var should_face_mouse = (
		game_phase == "move" or 
		game_phase == "aiming" or 
		game_phase == "draw_cards" or
		game_phase == "ball_tile_choice"
	) and not is_charging and not is_charging_height and not is_in_launch_mode
	
	if not should_face_mouse:
		return
	
	# Get mouse position in world space
	if not camera:
		return
	
	var mouse_world_pos = camera.get_global_mouse_position()
	var player_world_pos = global_position
	
	# Calculate direction from player to mouse
	var direction = mouse_world_pos - player_world_pos
	
	# Only update if mouse is not too close to player (to prevent jittering)
	if direction.length() < 10.0:
		return
	
	# Determine if mouse is to the left or right of player
	var mouse_is_left = direction.x < 0
	
	# Update current facing direction
	current_facing_direction = Vector2i(-1, 0) if mouse_is_left else Vector2i(1, 0)
	
	# Flip the sprite horizontally based on mouse position
	# Assuming the default sprite faces right, so we flip when mouse is on the left
	sprite.flip_h = mouse_is_left
	
	# Update clothing sprites to match player sprite flip
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager and equipment_manager.has_method("update_all_clothing_flip"):
		equipment_manager.update_all_clothing_flip()

func get_current_facing_direction() -> Vector2i:
	"""Get the current facing direction of the player"""
	return current_facing_direction

func is_facing_left() -> bool:
	"""Check if the player is currently facing left"""
	return current_facing_direction.x < 0

func is_facing_right() -> bool:
	"""Check if the player is currently facing right"""
	return current_facing_direction.x > 0

func update_animation_facing(animation_sprite: Node) -> void:
	"""Update the facing direction of an animation sprite to match the player's facing direction"""
	if not animation_sprite:
		return
	
	# Apply the same flip as the main character sprite
	if animation_sprite is Sprite2D:
		animation_sprite.flip_h = is_facing_left()
	elif animation_sprite is AnimatedSprite2D:
		animation_sprite.flip_h = is_facing_left()
	
	print("Updated animation facing - Direction: ", current_facing_direction, ", Flip H: ", animation_sprite.flip_h)

# Ball collision methods - using advanced collision system

func _find_character_area2d() -> Area2D:
	"""Find the Area2D in the character scene"""
	for child in get_children():
		if child is Area2D:
			return child
		elif child is Node2D:
			# Check Node2D children
			for grandchild in child.get_children():
				if grandchild is Area2D:
					return grandchild
	return null

func set_game_phase(phase: String) -> void:
	"""Set the current game phase for mouse facing logic"""
	game_phase = phase

func set_launch_state(charging: bool, charging_height: bool) -> void:
	"""Set the launch charging state for mouse facing logic"""
	is_charging = charging
	is_charging_height = charging_height

func set_camera_reference(camera_ref: Camera2D) -> void:
	"""Set the camera reference for mouse position calculation"""
	camera = camera_ref

func disable_collision_shape() -> void:
	"""Disable the player's collision shape during launch mode"""
	# Find the character's Area2D and disable it
	var character_area = _find_character_area2d()
	if character_area:
		character_area.monitoring = false
		character_area.monitorable = false

func enable_collision_shape() -> void:
	"""Enable the player's collision shape after ball lands"""
	# Find the character's Area2D and enable it
	var character_area = _find_character_area2d()
	if character_area:
		character_area.monitoring = true
		character_area.monitorable = true

func set_launch_mode(launch_mode: bool) -> void:
	"""Set the launch mode state for mouse facing logic"""
	is_in_launch_mode = launch_mode

func get_equipment_mobility_bonus() -> int:
	"""Get the mobility bonus from equipped equipment"""
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager:
		return equipment_manager.get_mobility_bonus()
	return 0

func is_currently_moving() -> bool:
	"""Check if the player is currently moving"""
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
		print("Player movement stopped")

func enable_animations() -> void:
	"""Enable movement animations after player is properly placed on tee"""
	animations_enabled = true
	print("Player movement animations enabled")

func disable_animations() -> void:
	"""Disable movement animations (for debugging or special cases)"""
	animations_enabled = false
	print("Player movement animations disabled")

func are_animations_enabled() -> bool:
	"""Check if movement animations are currently enabled"""
	return animations_enabled

func push_back(target_pos: Vector2i, ysort_objects: Array = [], shop_grid_pos: Vector2i = Vector2i.ZERO) -> void:
	"""Push the player back to a new position with smooth animation"""
	var old_pos = grid_pos
	grid_pos = target_pos
	
	# Update world position
	var target_world_pos = Vector2(target_pos.x, target_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Only use animated pushback if animations are enabled
	if animations_enabled:
		_animate_pushback_to_position(target_world_pos, ysort_objects, shop_grid_pos)
	else:
		# Instant pushback during initialization
		self.position = target_world_pos
		update_z_index_for_ysort(ysort_objects, shop_grid_pos)
	
	print("Player pushed back from ", old_pos, " to ", target_pos)

func _animate_pushback_to_position(target_world_pos: Vector2, ysort_objects: Array = [], shop_grid_pos: Vector2i = Vector2i.ZERO) -> void:
	"""Animate the player's pushback to the target position using a tween"""
	# Set moving state
	is_moving = true
	
	# Stop any existing movement tween
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
	
	# Play footstep sound right before pushback starts
	_play_footstep_sound_before_movement()
	
	# Create new tween for pushback (slightly faster than normal movement)
	var pushback_duration = movement_duration * 0.7  # 70% of normal movement duration
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_QUAD)
	movement_tween.set_ease(Tween.EASE_OUT)
	
	# Start the pushback animation
	movement_tween.tween_property(self, "position", target_world_pos, pushback_duration)
	
	# Update Y-sorting during pushback
	movement_tween.tween_callback(update_z_index_for_ysort.bind(ysort_objects, shop_grid_pos))
	
	# Update camera position during pushback (every frame)
	movement_tween.tween_method(_update_camera_during_movement, 0.0, 1.0, pushback_duration)
	
	# When pushback completes
	movement_tween.tween_callback(_on_pushback_completed)
	
	print("Started player pushback animation to position: ", target_world_pos)

func _on_pushback_completed() -> void:
	"""Called when player pushback animation completes"""
	is_moving = false
	print("Player pushback animation completed")
	
	# Update Y-sorting one final time (with empty arrays as defaults)
	update_z_index_for_ysort([], Vector2i.ZERO)
	
	# CRITICAL: Update the course's player position reference
	var course = get_tree().current_scene
	if course and "player_grid_pos" in course:
		course.player_grid_pos = grid_pos
		print("Course player_grid_pos updated to:", course.player_grid_pos)
	
	# Update the course's player position reference
	if course and course.has_method("update_player_position"):
		course.update_player_position()
	
	# Update the attack handler's player position if it exists
	if course and course.has_method("get_attack_handler"):
		var attack_handler = course.get_attack_handler()
		if attack_handler and attack_handler.has_method("update_player_position"):
			attack_handler.update_player_position(grid_pos)
			print("Attack handler player position updated to:", grid_pos)
	
	# Emit moved signal to notify the course
	emit_signal("moved_to_tile", grid_pos)
	print("Emitted moved_to_tile signal for pushback position:", grid_pos)
	
	# Smoothly tween camera to final position
	if course and course.has_method("smooth_camera_to_player"):
		course.smooth_camera_to_player()

# Height and collision shape methods for collision system
func get_height() -> float:
	"""Get the height of this Player for collision detection"""
	return Global.get_object_height_from_marker(self)

func get_collision_radius() -> float:
	"""
	Get the collision radius for this Player.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 30.0  # Player collision radius

func handle_ball_collision(ball: Node2D) -> void:
	"""Handle collision with a ball - called by collision system"""
	_handle_ball_collision(ball)

# Returns the Y-sorting reference point (base of character's feet)
func get_y_sort_point() -> float:
	# Try to find Sprite2D/YSortPoint in character scene
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var ysort_point = sprite.get_node_or_null("YSortPoint")
		if ysort_point:
			return ysort_point.global_position.y
		else:
			# Sprite2D found but no YSortPoint child
			pass
	else:
		# No Sprite2D found
		pass
	
	# Search for character scene nodes (BennyChar, LaylaChar, etc.)
	for child in get_children():
		if child.name.ends_with("Char") or child.name.ends_with("Char.tscn"):
			# This is likely a character scene
			var char_sprite = child.get_node_or_null("Sprite2D")
			if char_sprite:
				var char_ysort_point = char_sprite.get_node_or_null("YSortPoint")
				if char_ysort_point:
					return char_ysort_point.global_position.y
				else:
					# Character scene found but no YSortPoint in Sprite2D
					pass
			else:
				# Character scene found but no Sprite2D
				pass
		elif child.name == "YSortPoint":
			# Direct YSortPoint child
			return child.global_position.y
		elif child.has_method("get_node_or_null"):
			# Search deeper for YSortPoint
			var nested = child.get_node_or_null("YSortPoint")
			if nested:
				return nested.global_position.y
	
	# Final fallback: use global_position.y with character offset
	return global_position.y + 37.0  # Character offset for Y-sorting

func set_ball_launch_position(launch_pos: Vector2) -> void:
	"""Set the ball launch position for collision delay calculation"""
	ball_launch_position = launch_pos
	print("Ball launch position set to:", launch_pos)

func start_ragdoll_animation(direction: Vector2, force: float) -> void:
	"""Start the ragdoll animation for the player (like GangMember)"""
	if is_ragdolling:
		print("Player is already ragdolling, ignoring new ragdoll request")
		return
	
	print("=== STARTING PLAYER RAGDOLL ANIMATION ===")
	print("Direction:", direction)
	print("Force:", force)
	
	is_ragdolling = true
	
	# Stop any current movement
	stop_movement()
	
	# Calculate landing position based on direction and force
	_calculate_ragdoll_landing_position(direction, force)
	
	# Start the ragdoll animation sequence AND movement simultaneously
	_start_ragdoll_sequence(direction, force)
	
	# Start the pushback movement immediately (in parallel with ragdoll animation)
	push_back(ragdoll_landing_position)

func _calculate_ragdoll_landing_position(direction: Vector2, force: float) -> void:
	"""Calculate where the player will land after the ragdoll animation - simple 2-tile pushback"""
	var current_grid_pos = grid_pos
	
	# For explosion pushback, always push back exactly 2 tiles in the direction
	var pushback_distance = 2  # Exactly 2 tiles like gang member system
	
	# Calculate pushback direction as grid coordinates
	var pushback_direction = Vector2i(sign(direction.x), sign(direction.y))
	if pushback_direction == Vector2i.ZERO:
		pushback_direction = Vector2i(1, 0)  # Default to right if no clear direction
	
	# Calculate target grid position (2 tiles away)
	var target_grid_pos = current_grid_pos + (pushback_direction * pushback_distance)
	
	# Basic bounds checking - ensure position is within reasonable grid bounds
	if target_grid_pos.x < 0 or target_grid_pos.y < 0 or target_grid_pos.x > 100 or target_grid_pos.y > 100:
		print("Target position out of bounds, using current position")
		target_grid_pos = current_grid_pos
	
	ragdoll_landing_position = target_grid_pos
	
	print("Current grid position:", current_grid_pos)
	print("Pushback direction:", pushback_direction)
	print("Target grid position:", ragdoll_landing_position)
	print("Pushback distance:", ragdoll_landing_position.distance_to(current_grid_pos), "tiles")

func _start_ragdoll_sequence(direction: Vector2, force: float) -> void:
	"""Start the ragdoll animation sequence - visual effect only, movement handled by push_back"""
	print("=== STARTING RAGDOLL SEQUENCE ===")
	
	# Stop any existing ragdoll tween
	if ragdoll_tween and ragdoll_tween.is_valid():
		ragdoll_tween.kill()
	
	# Create new ragdoll tween for visual effects only
	ragdoll_tween = create_tween()
	ragdoll_tween.set_parallel(true)
	
	# Phase 1: Quick tilt backward (visual effect)
	var tilt_duration = ragdoll_duration * 0.3  # 30% of total time
	var tilt_angle = -30.0  # Tilt backward 30 degrees (less than gang member)
	ragdoll_tween.tween_property(self, "rotation_degrees", tilt_angle, tilt_duration)
	ragdoll_tween.set_trans(Tween.TRANS_QUAD)
	ragdoll_tween.set_ease(Tween.EASE_OUT)
	
	# Phase 2: Return to normal rotation
	var return_duration = ragdoll_duration * 0.7  # 70% of total time
	ragdoll_tween.tween_property(self, "rotation_degrees", 0.0, return_duration).set_delay(tilt_duration)
	ragdoll_tween.set_trans(Tween.TRANS_QUAD)
	ragdoll_tween.set_ease(Tween.EASE_IN)
	
	# Phase 3: Complete ragdoll and trigger movement
	ragdoll_tween.tween_callback(_on_ragdoll_complete).set_delay(ragdoll_duration)
	
	print("✓ Ragdoll visual animation started (movement will be handled separately)")

func _on_ragdoll_complete() -> void:
	"""Called when the ragdoll animation is complete - movement is handled separately"""
	print("=== PLAYER RAGDOLL VISUAL ANIMATION COMPLETE ===")
	
	is_ragdolling = false
	
	print("✓ Player ragdoll visual animation complete (movement handled separately)")

func stop_ragdoll() -> void:
	"""Stop the ragdoll animation if it's currently running"""
	if is_ragdolling and ragdoll_tween and ragdoll_tween.is_valid():
		ragdoll_tween.kill()
		is_ragdolling = false
		print("✓ Player ragdoll animation stopped")

func is_currently_ragdolling() -> bool:
	"""Check if the player is currently ragdolling"""
	return is_ragdolling

# Swing animation methods
func _setup_swing_animation() -> void:
	"""Setup the swing animation system"""
	
	# Find the swing animation node in the character scene
	for child in get_children():
		if child.has_method("start_swing_animation"):
			swing_animation = child
			break
		elif child is Node2D:
			# Check Node2D children (this is where the character scene nodes are)
			for grandchild in child.get_children():
				if grandchild.has_method("start_swing_animation"):
					swing_animation = grandchild
					break
				elif grandchild is Node2D:
					# Check even deeper for nested character scenes
					for great_grandchild in grandchild.get_children():
						if great_grandchild.has_method("start_swing_animation"):
							swing_animation = great_grandchild
							break

func _update_swing_animation() -> void:
	# Check if we're in weapon mode (knife, grenade, or spear) - don't play swing animation for weapons
	var course = get_tree().current_scene
	if course and course.has_method("get_launch_manager"):
		var launch_manager = course.get_launch_manager()
		if launch_manager and (launch_manager.is_knife_mode or launch_manager.is_grenade_mode or launch_manager.is_spear_mode):
			# Don't play swing animation for weapons
			return
	
	# Check if we're using GrenadeLauncherClubCard - don't play swing animation for this club
	if course and course.has_method("get_launch_manager"):
		var launch_manager = course.get_launch_manager()
		if launch_manager and launch_manager.selected_club == "GrenadeLauncherClubCard":
			# Don't play swing animation for GrenadeLauncherClubCard
			return
	
	# Check if height charge state changed
	if is_charging_height != previous_charging_height:
		if is_charging_height:
			# Height charge started - start swing animation
			start_swing_animation()  # Use our updated method that handles facing
		else:
			# Height charge stopped - stop swing animation
			swing_animation.stop_swing_animation()
		
		# Update previous state
		previous_charging_height = is_charging_height

func start_swing_animation() -> void:
	"""Manually start the swing animation"""
	if swing_animation:
		# Update the swing animation facing before starting
		var swing_sprite = swing_animation.get_node_or_null("SwingSprite")
		if swing_sprite:
			update_animation_facing(swing_sprite)
		swing_animation.start_swing_animation()

func stop_swing_animation() -> void:
	"""Manually stop the swing animation"""
	if swing_animation:
		swing_animation.stop_swing_animation()

func is_swinging() -> bool:
	"""Check if currently performing a swing animation"""
	if swing_animation:
		return swing_animation.is_currently_swinging()
	return false

# Kick animation methods
func _setup_kick_animation() -> void:
	"""Setup the kick animation system"""
	# Try to find the kick sprite using a recursive search
	kick_sprite = _find_kick_sprite_recursive(self)

func _find_kick_sprite_recursive(node: Node) -> Sprite2D:
	"""Recursively search for the BennyKick sprite in the node tree"""
	for child in node.get_children():
		if child.name == "BennyKick" and child is Sprite2D:
			return child
		elif child is Node2D:
			# Recursively search in Node2D children
			var result = _find_kick_sprite_recursive(child)
			if result:
				return result
	return null

func start_kick_animation() -> void:
	"""Start the kick animation - switch to kick sprite"""
	if is_kicking:
		return
	
	is_kicking = true
	
	# Get the normal character sprite
	var normal_sprite = get_character_sprite()
	if not normal_sprite or not kick_sprite:
		return
	
	# Update the kick sprite facing before showing it
	update_animation_facing(kick_sprite)
	
	# Hide the normal sprite and show the kick sprite
	normal_sprite.visible = false
	kick_sprite.visible = true
	
	# Start the kick animation timer
	if kick_tween and kick_tween.is_valid():
		kick_tween.kill()
	
	kick_tween = create_tween()
	kick_tween.tween_callback(_on_kick_animation_complete).set_delay(kick_duration)

func _on_kick_animation_complete() -> void:
	"""Called when the kick animation completes"""
	# Get the normal character sprite
	var normal_sprite = get_character_sprite()
	if normal_sprite and kick_sprite:
		# Switch back to normal sprite
		kick_sprite.visible = false
		normal_sprite.visible = true
	
	is_kicking = false

func stop_kick_animation() -> void:
	"""Stop the kick animation if it's currently running"""
	if is_kicking:
		# Get the normal character sprite
		var normal_sprite = get_character_sprite()
		if normal_sprite and kick_sprite:
			# Switch back to normal sprite
			kick_sprite.visible = false
			normal_sprite.visible = true
		
		# Stop the tween
		if kick_tween and kick_tween.is_valid():
			kick_tween.kill()
		
		is_kicking = false

func is_currently_kicking() -> bool:
	"""Check if currently performing a kick animation"""
	return is_kicking

# PunchB animation methods
func _setup_punchb_animation() -> void:
	"""Setup the PunchB animation system"""
	
	# Find the BennyPunch sprite using a recursive search
	punchb_animation = _find_punch_sprite_recursive(self)
	
	# Fallback: try to find any AnimatedSprite2D with "Punch" animation
	if not punchb_animation:
		punchb_animation = _find_punch_animation_fallback(self)

func _find_punch_sprite_recursive(node: Node) -> AnimatedSprite2D:
	"""Recursively search for the BennyPunch sprite in the node tree"""
	
	for child in node.get_children():
		if child.name == "BennyPunch" and child is AnimatedSprite2D:
			return child
		elif child is Node2D:
			# Recursively search in Node2D children
			var result = _find_punch_sprite_recursive(child)
			if result:
				return result
	
	return null

func _find_punch_animation_fallback(node: Node) -> AnimatedSprite2D:
	"""Fallback: find any AnimatedSprite2D that has a "Punch" animation"""
	
	for child in node.get_children():
		if child is AnimatedSprite2D:
			if child.sprite_frames and child.sprite_frames.has_animation("Punch"):
				return child
		elif child is Node2D:
			# Recursively search in Node2D children
			var result = _find_punch_animation_fallback(child)
			if result:
				return result
	
	return null

func start_punchb_animation() -> void:
	"""Start the PunchB animation - play the punch animation"""
	
	if is_punching:
		return
	
	is_punching = true
	
	# Get the normal character sprite
	var normal_sprite = get_character_sprite()
	if not normal_sprite:
		return
	if not punchb_animation:
		return
	
	# Update the punch animation facing before showing it
	update_animation_facing(punchb_animation)
	
	# Hide the normal sprite and show the animated sprite
	normal_sprite.visible = false
	punchb_animation.visible = true
	
	# Play the punch animation
	punchb_animation.play("Punch")
	
	# Start the punch animation timer
	if punchb_tween and punchb_tween.is_valid():
		punchb_tween.kill()
	
	punchb_tween = create_tween()
	punchb_tween.tween_callback(_on_punchb_animation_complete).set_delay(punchb_duration)

func _on_punchb_animation_complete() -> void:
	"""Called when the PunchB animation completes"""
	
	# Get the normal character sprite
	var normal_sprite = get_character_sprite()
	if normal_sprite and punchb_animation:
		# Stop the animation and hide the animated sprite
		punchb_animation.stop()
		punchb_animation.visible = false
		# Show the normal sprite
		normal_sprite.visible = true
	
	is_punching = false

func stop_punchb_animation() -> void:
	"""Stop the PunchB animation if it's currently running"""
	if is_punching:
		# Get the normal character sprite
		var normal_sprite = get_character_sprite()
		if normal_sprite and punchb_animation:
			# Stop the animation and hide the animated sprite
			punchb_animation.stop()
			punchb_animation.visible = false
			# Show the normal sprite
			normal_sprite.visible = true
		
		# Stop the tween
		if punchb_tween and punchb_tween.is_valid():
			punchb_tween.kill()
		
		is_punching = false

func is_currently_punching() -> bool:
	"""Check if currently performing a PunchB animation"""
	return is_punching

# Player movement animation for PunchB attacks
func animate_to_position(target_grid_pos: Vector2i, callback: Callable = Callable()) -> void:
	"""Animate player movement to a target grid position"""
	
	# Calculate world position from grid position (same as set_grid_position)
	var target_world_pos = Vector2(target_grid_pos.x, target_grid_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Use faster animation for PunchB attacks (3x faster)
	var animation_duration = movement_duration / 3.0
	
	# Create movement tween
	var movement_tween = create_tween()
	movement_tween.tween_property(self, "position", target_world_pos, animation_duration)
	movement_tween.set_trans(Tween.TRANS_SINE)
	movement_tween.set_ease(Tween.EASE_OUT)
	
	# Update grid position immediately for collision detection
	grid_pos = target_grid_pos
	
	# Call callback when animation completes
	if callback.is_valid():
		movement_tween.tween_callback(callback)

func _setup_jump_animation() -> void:
	"""Setup the jump animation system"""
	
	# Find the shadow sprite in the character scene
	shadow_sprite = _find_shadow_sprite_recursive(self)
	
	# Find the BallHop sound
	ballhop_sound = get_node_or_null("BallHop")
	
	if shadow_sprite:
		# Ensure shadow is black (in case it was modified elsewhere)
		shadow_sprite.modulate = Color(0, 0, 0, 0.3)  # Semi-transparent black

func _find_shadow_sprite_recursive(node: Node) -> Sprite2D:
	"""Recursively search for the Shadow sprite in the node tree"""
	for child in node.get_children():
		if child.name == "Shadow" and child is Sprite2D:
			return child
		elif child is Node2D:
			# Recursively search in Node2D children
			var result = _find_shadow_sprite_recursive(child)
			if result:
				return result
	return null



func _setup_footstep_sounds() -> void:
	"""Setup the footstep sound system"""
	
	# Find the footstep sound nodes
	footsteps_grass_sound = get_node_or_null("FootstepsGrass")
	footsteps_snow_sound = get_node_or_null("FootstepsSnow")

func _play_footstep_sound_before_movement() -> void:
	"""Play footstep sound right before movement starts"""
	if not footstep_sound_enabled:
		return
	
	# Get the current tile type at the player's position
	var tile_type = _get_current_tile_type()
	
	# Play appropriate footstep sound based on terrain
	if _is_grass_tile(tile_type):
		_play_grass_footstep()
	elif _is_ice_or_sand_tile(tile_type):
		_play_snow_footstep()
	
	# Update the last footstep time to prevent rapid successive sounds
	last_footstep_time = Time.get_ticks_msec() / 1000.0

func _play_footstep_sounds_during_movement(progress: float) -> void:
	"""Play footstep sounds during movement animation"""
	if not footstep_sound_enabled:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	if current_time - last_footstep_time < footstep_interval:
		return
	
	# Get the current tile type at the player's position
	var tile_type = _get_current_tile_type()
	
	# Play appropriate footstep sound based on terrain
	if _is_grass_tile(tile_type):
		_play_grass_footstep()
	elif _is_ice_or_sand_tile(tile_type):
		_play_snow_footstep()
	
	last_footstep_time = current_time

func _get_current_tile_type() -> String:
	"""Get the tile type at the player's current position"""
	var course = get_tree().current_scene
	if not course or not course.has_node("MapManager"):
		return "Base"  # Default to base grass
	
	var map_manager = course.get_node("MapManager")
	if not map_manager or not map_manager.has_method("get_tile_type"):
		return "Base"  # Default to base grass
	
	# Convert player position to grid coordinates
	var tile_x = int(floor(global_position.x / cell_size))
	var tile_y = int(floor(global_position.y / cell_size))
	
	# Check bounds
	if tile_x < 0 or tile_y < 0 or tile_x >= map_manager.grid_width or tile_y >= map_manager.grid_height:
		return "Base"  # Default to base grass for out of bounds
	
	return map_manager.get_tile_type(tile_x, tile_y)

func _is_grass_tile(tile_type: String) -> bool:
	"""Check if a tile type is considered grass (Green, Rough, Fairway, Base)"""
	return tile_type in ["G", "R", "F", "Base"]

func _is_ice_or_sand_tile(tile_type: String) -> bool:
	"""Check if a tile type is ice or sand"""
	return tile_type in ["Ice", "S"]

func _play_grass_footstep() -> void:
	"""Play grass footstep sound"""
	if footsteps_grass_sound and footsteps_grass_sound.stream:
		footsteps_grass_sound.play()
		print("✓ Played grass footstep sound")

func _play_snow_footstep() -> void:
	"""Play snow footstep sound (for ice and sand)"""
	if footsteps_snow_sound and footsteps_snow_sound.stream:
		footsteps_snow_sound.play()
		print("✓ Played snow footstep sound")

func enable_footstep_sounds() -> void:
	"""Enable footstep sound effects"""
	footstep_sound_enabled = true
	print("✓ Footstep sounds enabled")

func disable_footstep_sounds() -> void:
	"""Disable footstep sound effects"""
	footstep_sound_enabled = false
	print("✓ Footstep sounds disabled")

func set_footstep_interval(interval: float) -> void:
	"""Set the interval between footstep sounds during movement"""
	footstep_interval = max(0.1, interval)  # Minimum 0.1 seconds
	print("✓ Footstep interval set to:", footstep_interval, "seconds")

# Meditation system methods
func _setup_meditation_system() -> void:
	"""Setup the meditation system"""
	print("=== SETTING UP PLAYER MEDITATION SYSTEM ===")
	# Find the BennyMeditateSprite using a recursive search
	meditate_sprite = _find_meditate_sprite_recursive(self)
	
	if meditate_sprite:
		print("✓ Meditation sprite found:", meditate_sprite.name)
		print("✓ Meditation sprite visible:", meditate_sprite.visible)
		print("✓ Meditation sprite position:", meditate_sprite.position)
	else:
		print("⚠ Meditation sprite not found")
		print("⚠ This will prevent meditation from working!")
	
	print("=== MEDITATION SYSTEM SETUP COMPLETE ===")

func setup_meditation_after_character() -> void:
	"""Setup the meditation system after the character scene is added"""
	print("=== SETTING UP MEDITATION SYSTEM AFTER CHARACTER ADDED ===")
	_setup_meditation_system()
	print("=== MEDITATION SYSTEM SETUP AFTER CHARACTER COMPLETE ===")

func _find_meditate_sprite_recursive(node: Node) -> Sprite2D:
	"""Recursively search for the BennyMeditateSprite in the node tree"""
	print("Searching for BennyMeditateSprite in node:", node.name, "Type:", node.get_class())
	for child in node.get_children():
		print("Checking child:", child.name, "Type:", child.get_class())
		if child.name == "BennyMeditateSprite" and child is Sprite2D:
			print("✓ Found BennyMeditateSprite:", child.name)
			return child
		elif child is Node2D:
			# Recursively search in Node2D children
			var result = _find_meditate_sprite_recursive(child)
			if result:
				return result
	print("No BennyMeditateSprite found in node:", node.name)
	return null

func start_meditation() -> void:
	"""Start the meditation state - switch to meditate sprite and heal player"""
	print("=== STARTING PLAYER MEDITATION ===")
	
	if is_meditating:
		print("⚠ Player is already meditating, ignoring start request")
		return
	
	print("✓ Setting meditation state to true")
	is_meditating = true
	
	# Get the normal character sprite
	var normal_sprite = get_character_sprite()
	print("✓ Normal sprite found:", normal_sprite != null)
	if normal_sprite:
		print("✓ Normal sprite visible:", normal_sprite.visible)
		print("✓ Normal sprite modulate:", normal_sprite.modulate)
	
	print("✓ Meditate sprite found:", meditate_sprite != null)
	if meditate_sprite:
		print("✓ Meditate sprite visible:", meditate_sprite.visible)
		print("✓ Meditate sprite modulate:", meditate_sprite.modulate)
		print("✓ Meditate sprite position:", meditate_sprite.position)
	
	if not normal_sprite:
		print("⚠ Normal sprite not found!")
		return
	if not meditate_sprite:
		print("⚠ Meditate sprite not found!")
		return
	
	# Update the meditate sprite facing before showing it
	print("✓ Updating meditation sprite facing")
	update_animation_facing(meditate_sprite)
	
	# Hide the normal sprite and show the meditate sprite
	print("✓ Hiding normal sprite and showing meditate sprite")
	normal_sprite.visible = false
	meditate_sprite.visible = true
	
	# Verify the sprite change
	print("✓ After sprite change - Normal sprite visible:", normal_sprite.visible)
	print("✓ After sprite change - Meditate sprite visible:", meditate_sprite.visible)
	
	# Heal the player
	print("✓ Healing player by", heal_amount, "health")
	heal_player(heal_amount)
	
	# Play meditation sound
	print("✓ Playing meditation sound")
	_play_meditation_sound()
	
	# Create heal effect particles
	print("✓ Creating heal effect particles")
	_create_heal_effect()
	
	# Start the meditation timer
	if meditation_tween and meditation_tween.is_valid():
		meditation_tween.kill()
	
	meditation_tween = create_tween()
	meditation_tween.tween_callback(_on_meditation_complete).set_delay(meditation_duration)
	
	print("✓ Meditation timer started for", meditation_duration, "seconds")
	print("✓ Meditation started successfully - healing", heal_amount, "health")

func _on_meditation_complete() -> void:
	"""Called when the meditation completes"""
	print("=== PLAYER MEDITATION COMPLETE ===")
	
	# Get the normal character sprite
	var normal_sprite = get_character_sprite()
	if normal_sprite and meditate_sprite:
		# Switch back to normal sprite
		meditate_sprite.visible = false
		normal_sprite.visible = true
	
	is_meditating = false
	print("✓ Meditation completed - returned to normal sprite")

func stop_meditation() -> void:
	"""Stop the meditation if it's currently running"""
	if is_meditating:
		# Get the normal character sprite
		var normal_sprite = get_character_sprite()
		if normal_sprite and meditate_sprite:
			# Switch back to normal sprite
			meditate_sprite.visible = false
			normal_sprite.visible = true
		
		# Stop the tween
		if meditation_tween and meditation_tween.is_valid():
			meditation_tween.kill()
		
		is_meditating = false
		print("✓ Meditation stopped")

func is_currently_meditating() -> bool:
	"""Check if currently in meditation state"""
	return is_meditating

func heal_player(amount: int) -> void:
	"""Heal the player by the specified amount"""
	var old_health = current_health
	current_health = min(current_health + amount, max_health)
	var actual_heal = current_health - old_health
	
	print("Player healed by", actual_heal, "health. Current health:", current_health, "/", max_health)
	
	# Update the course's health bar
	var course = get_tree().current_scene
	if course and course.has_method("heal_player"):
		course.heal_player(actual_heal)
		print("✓ Updated course health bar with", actual_heal, "healing")

func _play_meditation_sound() -> void:
	"""Play the meditation sound effect"""
	# Try to find a bonfire with meditation sound
	var bonfires = get_tree().get_nodes_in_group("interactables")
	for bonfire in bonfires:
		if bonfire.name == "Bonfire" and bonfire.has_node("Meditate"):
			var meditate_sound = bonfire.get_node("Meditate")
			if meditate_sound and meditate_sound.stream:
				meditate_sound.play()
				print("✓ Playing meditation sound from bonfire")
				return
	
	# Fallback: create a temporary audio player
	var temp_audio = AudioStreamPlayer2D.new()
	var sound_file = load("res://Sounds/Meditate.mp3")
	if sound_file:
		temp_audio.stream = sound_file
		temp_audio.volume_db = -5.0  # Slightly quieter
		add_child(temp_audio)
		temp_audio.play()
		# Remove the audio player after it finishes
		temp_audio.finished.connect(func(): temp_audio.queue_free())
		print("✓ Playing meditation sound from fallback")

func _create_heal_effect() -> void:
	"""Create the heal effect particle system"""
	var heal_effect_scene = load("res://Particles/HealEffect.tscn")
	if heal_effect_scene:
		var heal_effect = heal_effect_scene.instantiate()
		
		# Position the heal effect relative to the BennyMeditateSprite if available
		if meditate_sprite and meditate_sprite.visible:
			# Use the meditate sprite's global position for the heal effect
			heal_effect.position = meditate_sprite.global_position
			print("✓ Created heal effect at BennyMeditateSprite position")
		else:
			# Fallback to player position if meditate sprite not available
			heal_effect.position = global_position
			print("✓ Created heal effect at player position (fallback)")
		
		get_tree().current_scene.add_child(heal_effect)
	else:
		print("⚠ HealEffect scene not found")

func get_grid_position() -> Vector2i:
	return grid_pos
