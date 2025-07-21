extends CharacterBody2D

# BossEye NPC - handles BossEye-specific functions
# Integrates with the Entities system for turn management

signal turn_completed

@onready var sprite: Sprite2D = $BossEyeSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var base_collision_area: Area2D = $BaseCollisionArea

var grid_position: Vector2i
var cell_size: int = 48
var entities_manager: Node

# BossEye specific properties
var boss_eye_type: String = "default"
var movement_range: int = 0  # BossEye doesn't move
var vision_range: int = 15
var current_action: String = "idle"

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

# Collision and height properties
# base_collision_area is already declared above

# Health bar
var boss_health_bar: Control = null

# State Machine
enum State {IDLE, ATTACKING, DEAD}
var current_state: State = State.IDLE

func _ready():
	# Set up collision detection
	if base_collision_area:
		base_collision_area.body_entered.connect(_on_body_entered)
		base_collision_area.body_exited.connect(_on_body_exited)
	
	# Store original modulate for freeze effects
	original_modulate = sprite.modulate
	
	# Initialize flash tween
	flash_tween = create_tween()
	flash_tween.set_loops()
	
	# Find the BossHealthBar in the UI layer
	var ui_layer = get_tree().get_root().get_node_or_null("Course1/UILayer")
	if ui_layer:
		boss_health_bar = ui_layer.get_node_or_null("BossHealthBar")
		if boss_health_bar:
			boss_health_bar.visible = true
			boss_health_bar.get_node("BossName").text = "Docculus the Brave"
			update_boss_health_bar()
	
	print("BossEye: Initialized with health:", current_health)

func _on_body_entered(body):
	# Handle ball collision
	if body.name == "GolfBall":
		print("BossEye: Ball collision detected")
		# Add ball collision logic here

func _on_body_exited(body):
	# Handle ball exit
	if body.name == "GolfBall":
		print("BossEye: Ball exited collision area")

func take_turn():
	"""Take the BossEye's turn"""
	print("BossEye taking turn")
	# Add boss turn logic here
	# For now, just complete the turn immediately
	turn_completed.emit()

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
	
	# Flash red when taking damage
	flash_red()
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
	flash_tween.set_loops()
	
	# Flash red for 0.2 seconds, then return to normal
	flash_tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	flash_tween.tween_property(sprite, "modulate", original_modulate, 0.1)
	
	# Stop the tween after one cycle
	await flash_tween.finished
	is_flashing = false
