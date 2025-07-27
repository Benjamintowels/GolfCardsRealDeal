extends AnimatedSprite2D

# Audio players
@onready var flame_on_sound: AudioStreamPlayer2D = $FlameOn
@onready var in_air_sound: AudioStreamPlayer2D = $InAir
@onready var explode_sound: AudioStreamPlayer2D = $Explode

# Animation properties
var target_position: Vector2
var travel_duration: float = 1.0
var on_reach_target_callback: Callable

func _ready():
	# Start the animation
	play("default")
	print("✓ FireBallAttack animation started")

func setup_and_launch(start_pos: Vector2, end_pos: Vector2, duration: float = 1.0, callback: Callable = Callable()):
	"""Setup the fireball and launch it to the target position"""
	target_position = end_pos
	travel_duration = duration
	on_reach_target_callback = callback
	
	# Position at start with chest offset
	var chest_offset = Vector2(0, -40)  # Offset to appear from chest area
	global_position = start_pos + chest_offset
	
	# Set proper z-index to appear above ground but below UI
	z_index = 100
	
	# Calculate direction for sprite orientation
	var direction = target_position - global_position
	var is_horizontal = abs(direction.x) > abs(direction.y)
	var is_up = direction.y < 0
	
	# Set appropriate sprite orientation based on direction
	if is_horizontal:
		# For horizontal movement, flip the sprite if moving left
		flip_h = direction.x < 0
	else:
		# For vertical movement, rotate the sprite
		if is_up:
			# For upward movement, rotate 90 degrees counterclockwise
			rotation = -PI/2
		else:
			# For downward movement, rotate 90 degrees clockwise
			rotation = PI/2
	
	print("Fireball attacking in direction:", "horizontal" if is_horizontal else "vertical", "flip_h:", flip_h, "rotation:", rotation)
	print("Fireball starting from chest position:", global_position)
	
	# Play sounds
	if flame_on_sound:
		flame_on_sound.play()
		print("✓ Playing FlameOn sound")
	
	if in_air_sound:
		in_air_sound.play()
		print("✓ Playing InAir sound")
	
	# Start travel animation
	start_travel_animation()

func start_travel_animation():
	"""Animate the fireball traveling to the target position"""
	print("✓ Starting fireball tween animation")
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_position, travel_duration)
	tween.tween_callback(_on_reach_target)

func _on_reach_target():
	"""Called when the fireball reaches its target"""
	print("✓ Fireball reached target position")
	
	# Play explode sound
	if explode_sound:
		explode_sound.play()
		print("✓ Playing Explode sound")
	
	# Call the callback if provided
	if on_reach_target_callback.is_valid():
		on_reach_target_callback.call()
	
	# Remove self
	queue_free()
	print("✓ Fireball removed from scene") 