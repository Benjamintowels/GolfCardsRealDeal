extends CharacterBody2D

# BossEye NPC - handles BossEye-specific functions
# Integrates with the Entities system for turn management

signal turn_completed

@onready var sprite: Sprite2D = $BossEyeSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var base_collision_area: Area2D = $BaseCollisionArea
@onready var push_sound: AudioStreamPlayer2D = $Push
@onready var move_sound: AudioStreamPlayer2D = $BossEyeMove
# Blink textures
@onready var boss_eye_closed: Texture2D = preload("res://NPC/Bosses/BossEyeClosed.png")
@onready var boss_eye_opening1: Texture2D = preload("res://NPC/Bosses/BossEyeOpening1.png")
@onready var boss_eye_opening2: Texture2D = preload("res://NPC/Bosses/BossEyeOpening2.png")
@onready var boss_eye_open: Texture2D = preload("res://NPC/Bosses/BossEye.png")
@onready var shadow: Sprite2D = $Shadow

var grid_position: Vector2i
var cell_size: int = 48
var entities_manager: Node

# BossEye specific properties
var boss_eye_type: String = "default"
var movement_range: int = 0  # BossEye doesn't move
var vision_range: int = 15
var current_action: String = "idle"
# Poise: BossEye cannot be knocked back by attacks
var poise: bool = true

# Health and damage properties
var max_health: int = 500
var current_health: int = 500
var is_alive: bool = true
var is_dead: bool = false

# Freeze effect properties
var is_frozen: bool = false
var freeze_turns_remaining: int = 0
var original_modulate: Color

# Damage flash effect properties
var is_flashing: bool = false
var flash_tween: Tween
# Blink effect flag
var is_blinking: bool = false

# Collision and height properties
# base_collision_area is already declared above

# Health bar
var boss_health_bar: Control = null

# State Machine
enum State {IDLE, ATTACKING, DEAD}
var current_state: State = State.IDLE

# Add BossHand references
var boss_hand_right: Node = null
var boss_hand_left: Node = null

# Poise ability: BossEye cannot be knocked back by any attack
func has_poise() -> bool:
	"""Return true if BossEye has Poise (cannot be knocked back)"""
	return poise

func _ready():
	# Set up collision detection
	if base_collision_area:
		base_collision_area.body_entered.connect(_on_body_entered)
		base_collision_area.body_exited.connect(_on_body_exited)
	
	# Setup HitBox for gun collision detection
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		hitbox.collision_layer = 2
		hitbox.collision_mask = 0
		hitbox.add_to_group("hitboxes")
	else:
		print("✗ ERROR: BossEye HitBox not found!")
	
	# Store original modulate for freeze effects
	original_modulate = sprite.modulate
	
	# Initialize flash tween
	flash_tween = create_tween()
	
	# Register with WorldTurnManager
	var course = get_tree().get_root().get_node_or_null("Course1")
	if course:
		var world_turn_manager = null
		var possible_paths = ["WorldTurnManager", "NPC/WorldTurnManager", "NPC/world_turn_manager"]
		for path in possible_paths:
			if course.has_node(path):
				world_turn_manager = course.get_node(path)
				break
		if world_turn_manager:
			world_turn_manager.register_npc(self)
			world_turn_manager.npc_turn_started.connect(_on_turn_started)
			world_turn_manager.npc_turn_ended.connect(_on_turn_ended)
	
	# Find the BossHealthBar in the UI layer
	var ui_layer = get_tree().get_root().get_node_or_null("Course1/UILayer")
	if ui_layer:
		boss_health_bar = ui_layer.get_node_or_null("BossHealthBar")
		if boss_health_bar:
			boss_health_bar.visible = true
			boss_health_bar.get_node("BossName").text = "Docculus the Brave"
			update_boss_health_bar()

	# Start idle float animation if it exists
	if animation_player.has_animation("idle_float"):
		animation_player.play("idle_float")

	# Instance and position BossHands to the right and left of BossEye
	if course:
		var obstacle_layer = course.get_node_or_null("CameraContainer/ObstacleLayer")
		if obstacle_layer:
			var boss_hand_scene = preload("res://NPC/Bosses/BossHand.tscn")
			# Right hand (attacking)
			boss_hand_right = boss_hand_scene.instantiate()
			obstacle_layer.add_child(boss_hand_right)
			boss_hand_right.global_position = global_position + Vector2(120, 0) # 120px to the right
			boss_hand_right.boss_eye = self
			if boss_hand_right.has_method("set_original_position"):
				boss_hand_right.set_original_position()
			# Left hand (idle, flipped)
			boss_hand_left = boss_hand_scene.instantiate()
			obstacle_layer.add_child(boss_hand_left)
			boss_hand_left.global_position = global_position + Vector2(-120, 0) # 120px to the left
			boss_hand_left.boss_eye = self
			if boss_hand_left.has_method("set_original_position"):
				boss_hand_left.set_original_position()
			# Flip the left hand horizontally
			if boss_hand_left.has_node("BossHandSprite"):
				boss_hand_left.get_node("BossHandSprite").flip_h = true
			if boss_hand_left.has_node("BossHandFist"):
				boss_hand_left.get_node("BossHandFist").flip_h = true
			if boss_hand_left.has_node("BossHandFlat"):
				boss_hand_left.get_node("BossHandFlat").flip_h = true
			# Only right hand attacks
			# boss_hand = boss_hand_right # This line is removed

	print("BossEye: Initialized with health:", current_health)

# Empty handlers for WorldTurnManager signals
func _on_turn_started(npc = null):
	pass

func _on_turn_ended(npc = null):
	pass

func _on_body_entered(body):
	# Handle ball collision
	if body.name == "GolfBall":
		print("BossEye: Ball collision detected")
		# Get velocity from GolfBall
		var ball_velocity = Vector2.ZERO
		if body.has_method("get_velocity"):
			ball_velocity = body.get_velocity()
		elif "velocity" in body:
			ball_velocity = body.velocity
		var damage = _calculate_velocity_damage(ball_velocity.length())
		print("BossEye: Calculated velocity-based damage:", damage)
		take_damage(damage)

func _on_body_exited(body):
	# Handle ball exit
	if body.name == "GolfBall":
		print("BossEye: Ball exited collision area")

func take_turn():
	"""Take the BossEye's turn (skip if dead or frozen, always emit turn_completed)"""
	if is_dead or is_frozen:
		turn_completed.emit()
		return
	print("BossEye taking turn")
	if move_sound:
		move_sound.play()

	# === SUMMON ELEMENTAL CIRCLE ATTACK ===
	var course = get_tree().get_root().get_node_or_null("Course1")
	if course and course.player_manager:
		var player_node = course.player_manager.get_player_node()
		if player_node:
			var player_grid_pos = course.player_manager.get_player_grid_pos()
			var offsets = []
			for dx in range(-3, 4):
				for dy in range(-3, 4):
					offsets.append(Vector2i(dx, dy))
			offsets.shuffle()

			# Pick the first valid offset and world_pos
			var chosen_offset = null
			var chosen_world_pos = null
			for offset in offsets:
				var target_grid = player_grid_pos + offset
				var cell_size = course.cell_size if "cell_size" in course else 48
				var world_pos = Vector2(target_grid.x * cell_size + cell_size/2, target_grid.y * cell_size + cell_size/2)
				chosen_offset = offset
				chosen_world_pos = world_pos
				break # Only pick one

			if chosen_world_pos != null:
				print("[BossEye] Summoning ElementalCircle at grid:", player_grid_pos + chosen_offset, "world_pos:", chosen_world_pos)
				# Animate BossHand attack sequence
				if boss_hand_right and boss_hand_right.is_alive:
					# Camera tracking logic (REMOVED - do not move camera during boss attack)
					# var camera_manager = course.camera_manager if "camera_manager" in course else null
					# if camera_manager:
					# 	# Move camera to BossHand before attack
					# 	camera_manager.create_camera_tween(boss_hand_right.global_position, 0.4)
					# 	# Tween camera to follow BossHand to target
					# 	await get_tree().create_timer(0.25).timeout
					# 	camera_manager.create_camera_tween(chosen_world_pos, 0.4)
					# Animate hand
					boss_hand_right.animate_attack(chosen_world_pos, func():
						# After attack, return camera to player (REMOVED)
						# if camera_manager and player_node:
						# 	camera_manager.create_camera_tween(player_node.global_position, 0.6)
						# This callback is after hand returns, but we want to create the ElementalCircle after 1s of hand_smash
						turn_completed.emit()
					)
					# Wait 1 second after hand_smash starts before creating the ElementalCircle
					await get_tree().create_timer(1.0).timeout
					# Instance the ElementalCircle
					var elemental_circle_scene = preload("res://Elements/ElementalCircle.tscn")
					var elemental_circle = elemental_circle_scene.instantiate()
					if "boss_eye_ref" in elemental_circle:
						elemental_circle.boss_eye_ref = self
					# Set position
					elemental_circle.position = chosen_world_pos
					# Add to CameraContainer/ObstacleLayer
					var obstacle_layer = course.get_node_or_null("CameraContainer/ObstacleLayer")
					if obstacle_layer:
						obstacle_layer.add_child(elemental_circle)
						print("[BossEye] Added ElementalCircle to CameraContainer/ObstacleLayer, child count:", obstacle_layer.get_child_count())
					else:
						print("[BossEye] ERROR: CameraContainer/ObstacleLayer not found! Adding to course root as fallback.")
						course.add_child(elemental_circle)
						print("[BossEye] Added ElementalCircle to course root, child count:", course.get_child_count())
					# Play entrance animation
					if elemental_circle.has_method("_animate_entrance"):
						elemental_circle._animate_entrance()
				else:
					# No hand, just play entrance
					var elemental_circle_scene = preload("res://Elements/ElementalCircle.tscn")
					var elemental_circle = elemental_circle_scene.instantiate()
					if "boss_eye_ref" in elemental_circle:
						elemental_circle.boss_eye_ref = self
					# Set position
						elemental_circle.position = chosen_world_pos
					# Add to CameraContainer/ObstacleLayer
					var obstacle_layer = course.get_node_or_null("CameraContainer/ObstacleLayer")
					if obstacle_layer:
						obstacle_layer.add_child(elemental_circle)
						print("[BossEye] Added ElementalCircle to CameraContainer/ObstacleLayer, child count:", obstacle_layer.get_child_count())
					else:
						print("[BossEye] ERROR: CameraContainer/ObstacleLayer not found! Adding to course root as fallback.")
						course.add_child(elemental_circle)
						print("[BossEye] Added ElementalCircle to course root, child count:", course.get_child_count())
					if elemental_circle.has_method("_animate_entrance"):
						elemental_circle._animate_entrance()
					turn_completed.emit()
			return # Prevent double emit

func get_grid_position() -> Vector2i:
	"""Get the current grid position"""
	return grid_position

func set_grid_position(pos: Vector2i):
	"""Set the grid position"""
	grid_position = pos

func is_alive_npc() -> bool:
	"""Check if the BossEye is alive"""
	return is_alive and not is_dead

func setup(boss_eye_pos: Vector2i, cell_size: int) -> void:
	"""Setup the BossEye with position and cell size"""
	grid_position = boss_eye_pos
	print("BossEye: Setup at position", boss_eye_pos)

func get_vision_range() -> int:
	"""Get the vision range"""
	return vision_range

func get_movement_range() -> int:
	"""Get the movement range"""
	return movement_range

func get_priority() -> int:
	"""Get the turn priority (higher = goes first)"""
	return 10  # High priority for boss

func update_boss_health_bar():
	if boss_health_bar:
		var health_bar_sprite = boss_health_bar.get_node("HealthBar")
		var percent = clamp(float(current_health) / float(max_health), 0, 1)
		# The default scale.x is 0.95, so multiply that by percent
		health_bar_sprite.scale.x = 0.95 * percent

func take_damage(amount: int):
	"""Take damage"""
	current_health -= amount
	print("BossEye took", amount, "damage. Health:", current_health)
	# Play push sound
	if push_sound:
		push_sound.play()
	# Flash red when taking damage
	flash_red()
	blink_eye()
	update_boss_health_bar()
	if current_health <= 0:
		die()

func die():
	"""Handle death"""
	is_alive = false
	is_dead = true
	current_state = State.DEAD
	print("BossEye defeated!")
	if boss_health_bar:
		boss_health_bar.visible = false
	turn_completed.emit()

func flash_red():
	"""Flash red when taking damage"""
	if is_flashing:
		return  # Don't start another flash if already flashing
	is_flashing = true
	# Stop any existing tween
	if flash_tween:
		flash_tween.kill()
	# Create new tween for flash effect
	flash_tween = create_tween()
	# Flash red for 0.2 seconds, then return to normal
	flash_tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	flash_tween.tween_property(sprite, "modulate", original_modulate, 0.1)
	# Wait for the tween to finish, then reset is_flashing
	await flash_tween.finished
	is_flashing = false

func blink_eye():
	if is_blinking or not sprite:
		return
	is_blinking = true
	sprite.texture = boss_eye_closed
	await get_tree().create_timer(0.08).timeout
	sprite.texture = boss_eye_opening1
	await get_tree().create_timer(0.06).timeout
	sprite.texture = boss_eye_opening2
	await get_tree().create_timer(0.06).timeout
	sprite.texture = boss_eye_open
	is_blinking = false

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
	return final_damage
