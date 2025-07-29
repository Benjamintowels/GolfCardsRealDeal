extends Node2D

# ElementalCircle: Handles elemental summon circle logic (Ice for now)

@onready var area2d: Area2D = $Area2D
@onready var ice_pulse: AudioStreamPlayer2D = $IcePulse
@onready var entrance_spark: AnimatedSprite2D = $EntranceSpark
@onready var entrance_element: Sprite2D = $EntranceElement
@onready var circle_sprite: Sprite2D = $ElementalCircleSprite
@onready var particles: GPUParticles2D = $GPUParticles2D

# Properties
var height: int = 300
var element: String = "ice" # For now, always ice
var turns_remaining: int = 4
var just_created: bool = true
var is_animating: bool = false  # Track animation state to prevent conflicts

const ICE_ELEMENT = preload("res://Elements/Ice.tres")

func _ready():
	add_to_group("Objects")
	add_to_group("elemental_circles")
	add_to_group("ysort_objects")  # Add to YSort system
	# Set height property (for ball collision logic)
	self.height = 300
	# Connect Area2D signals
	area2d.body_entered.connect(_on_body_entered)
	# Play IcePulse sound if element is ice
	if element == "ice":
		ice_pulse.play()
	# Animate entrance (stub for now)
	_animate_entrance()
	# Deal 25 damage to any character in area on creation
	_apply_initial_damage_to_characters()
	# Start particles (stub for now)
	particles.emitting = true
	# Initialize YSort
	update_ysort()
	# Remove Timer logic; turns are now advanced by advance_turn()

func get_y_sort_point() -> float:
	"""Get the Y-sort point for the elemental circle using the YSortPoint marker"""
	var ysort_point = particles.get_node_or_null("YSortPoint")
	if ysort_point:
		return ysort_point.global_position.y
	else:
		# Fallback to global position if no YSortPoint marker
		return global_position.y

func update_ysort():
	"""Update the elemental circle's Y-sort using the global system"""
	Global.update_object_y_sort(self, "objects")

func advance_turn():
	turns_remaining -= 1
	print("[ElementalCircle] advance_turn, turns_remaining:", turns_remaining)
	if turns_remaining <= 0:
		print("[ElementalCircle] queue_free called after turns expired")
		queue_free()

func _on_body_entered(body):
	# Ball logic
	if body.is_in_group("Ball"):
		# If ball is above height, do nothing
		if body.has_method("get_height") and body.get_height() > height:
			return
		# If ball would roof bounce, apply ice but do not bounce
		if body.has_method("would_roof_bounce") and body.would_roof_bounce(self):
			_apply_ice_to_ball(body)
			return
		# Normal collision: apply ice, prevent bounce/reflect
		_apply_ice_to_ball(body)
		# Prevent bounce/reflect (stub: actual logic may be in ball)
		if body.has_method("prevent_bounce"):
			body.prevent_bounce()
	# Character logic
	elif body.is_in_group("Character") and not just_created:
		_apply_damage_to_character(body, 10)

func _apply_initial_damage_to_characters():
	# Deal 25 damage to any character in area on creation
	for body in area2d.get_overlapping_bodies():
		if body.is_in_group("Character"):
			_apply_damage_to_character(body, 25)
	just_created = false

func _apply_damage_to_character(character, amount):
	if character.has_method("take_damage"):
		character.take_damage(amount)

func _apply_ice_to_ball(ball):
	if ball.has_method("set_element"):
		ball.set_element(ICE_ELEMENT)
		print("[ElementalCircle] Applied ICE element to ball.")
		_trigger_ball_interaction_animation()
		if ice_pulse:
			ice_pulse.play()

func _trigger_ball_interaction_animation():
	"""Trigger a quick animation when a ball interacts with the elemental circle"""
	# Only trigger if not already animating
	if not is_animating:
		is_animating = true
		entrance_spark.visible = true
		entrance_spark.play("default")
		
		# Show entrance element briefly
		entrance_element.visible = true
		
		# Wait for a shorter duration for ball interactions
		await get_tree().create_timer(0.4).timeout
		
		# Hide entrance spark
		entrance_spark.visible = false
		entrance_spark.stop()
		
		# Hide entrance element
		entrance_element.visible = false
		is_animating = false

func _animate_entrance():
	# Animate EntranceSpark and EntranceElement, then fade out
	# Only start if not already animating
	if is_animating:
		return
		
	is_animating = true
	# Start the entrance spark animation
	entrance_spark.visible = true
	entrance_spark.play("default")
	
	# Show entrance element
	entrance_element.visible = true
	
	# Wait for spark animation to complete (50 frames at 60 FPS = ~0.83 seconds)
	await get_tree().create_timer(0.8).timeout
	
	# Hide entrance spark
	entrance_spark.visible = false
	entrance_spark.stop()
	
	# Wait a bit more then hide entrance element
	await get_tree().create_timer(0.2).timeout
	entrance_element.visible = false
	is_animating = false
	# Only ElementalCircleSprite remains
