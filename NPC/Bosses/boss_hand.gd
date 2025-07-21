extends Node2D

# BossHand: Appendage of BossEye

@export var max_health: int = 50
var current_health: int = 50
var is_alive: bool = true
var boss_eye: Node = null # Set by BossEye after instancing
var original_position: Vector2
var original_local_position: Vector2

@onready var base_collision_area: Area2D = $BaseCollisionArea
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var push_sound: AudioStreamPlayer2D = $Push
@onready var smash_sound: AudioStreamPlayer2D = $Smash
@onready var boss_hand_sprite: Sprite2D = $BossHandSprite
@onready var boss_hand_fist: Sprite2D = $BossHandFist
@onready var boss_hand_flat: Sprite2D = $BossHandFlat

# Height for ball collision (lower than BossEye)
var height: int = 200

func _ready():
	current_health = max_health
	# Set default sprite visibility
	if boss_hand_sprite:
		boss_hand_sprite.visible = true
	if boss_hand_fist:
		boss_hand_fist.visible = false
	if boss_hand_flat:
		boss_hand_flat.visible = false
	if base_collision_area:
		base_collision_area.body_entered.connect(_on_body_entered)
	# Play idle animation if it exists
	if animation_player and animation_player.has_animation("hand_float"):
		animation_player.play("hand_float")

func _on_body_entered(body):
	if body.name == "GolfBall":
		var ball_velocity = Vector2.ZERO
		if body.has_method("get_velocity"):
			ball_velocity = body.get_velocity()
		elif "velocity" in body:
			ball_velocity = body.velocity
		var damage = _calculate_velocity_damage(ball_velocity.length())
		take_damage(damage)

func take_damage(amount: int):
	if not is_alive:
		return
	current_health -= amount
	if push_sound:
		push_sound.play()
	if boss_eye and boss_eye.has_method("take_damage"):
		boss_eye.take_damage(amount)
	if current_health <= 0:
		is_alive = false
		hide()
		queue_free()

func _calculate_velocity_damage(velocity_magnitude: float) -> int:
	const MIN_VELOCITY = 25.0
	const MAX_VELOCITY = 1200.0
	var clamped_velocity = clamp(velocity_magnitude, MIN_VELOCITY, MAX_VELOCITY)
	var damage_percentage = (clamped_velocity - MIN_VELOCITY) / (MAX_VELOCITY - MIN_VELOCITY)
	var damage = 1 + (damage_percentage * 20) # Max 21 damage for hand
	return int(damage)

func animate_attack(target_pos: Vector2, after_attack_func: Callable) -> void:
	# Show fist, hide default hand
	if boss_hand_sprite:
		boss_hand_sprite.visible = false
	if boss_hand_fist:
		boss_hand_fist.visible = true
	# 1. Print parent type and name
	var parent = get_parent()
	print("[BossHand DEBUG] Parent type:", typeof(parent), " name:", parent.name)
	# 2. Print current global and local position
	print("[BossHand DEBUG] Current global_position:", global_position, " position:", position)
	# 3. Print world target and computed local target
	var local_target = null
	if parent.has_method("to_local"):
		local_target = parent.to_local(target_pos)
	else:
		local_target = target_pos # fallback, will be wrong if parent is not Node2D
	print("[BossHand DEBUG] Target world_pos:", target_pos, " computed local:", local_target)
	# 4. Print the intended world position for ElementalCircle
	print("[BossHand DEBUG] ElementalCircle intended world_pos:", target_pos)
	# Tween to target, play hand_smash, then return, then call after_attack_func
	var tween = create_tween()
	tween.tween_property(self, "position", local_target, 0.25)
	tween.tween_callback(Callable(self, "_play_hand_smash_animation")).set_delay(0.01)
	tween.tween_callback(Callable(self, "_after_attack_sequence").bind(after_attack_func)).set_delay(1.5)

func _play_hand_smash_animation():
	if animation_player.has_animation("hand_smash"):
		animation_player.play("hand_smash")
	# Play Smash sound 1 second after animation starts
	if smash_sound:
		var tween = create_tween()
		tween.tween_callback(Callable(smash_sound, "play")).set_delay(1.0)

func _after_attack_sequence(after_attack_func: Callable):
	# Hide fist, show default hand
	if boss_hand_sprite:
		boss_hand_sprite.visible = true
	if boss_hand_fist:
		boss_hand_fist.visible = false
	# Print original local position before returning
	print("[BossHand DEBUG] Returning to original_local_position:", original_local_position)
	var tween = create_tween()
	tween.tween_property(self, "position", original_local_position, 0.25)
	tween.tween_callback(after_attack_func)
	# Resume idle animation if still alive
	if is_alive and animation_player and animation_player.has_animation("hand_float"):
		animation_player.play("hand_float")

# Add a setter for original_position
func set_original_position():
	# Store local position instead of global
	original_local_position = position
