extends Sprite2D

#use for icespear

# Audio players
@onready var ice_whoosh_sound: AudioStreamPlayer2D = $IceWhoosh

# Animation properties
var target_position: Vector2
var travel_duration: float = 1.0
var on_reach_target_callback: Callable

func _ready():
	# Ice spear is ready
	print("✓ IceSpear animation started")

func setup_and_launch(start_pos: Vector2, end_pos: Vector2, duration: float = 1.0, callback: Callable = Callable()):
	"""Setup the ice spear and launch it to the target position"""
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
	
	print("Ice spear attacking in direction:", "horizontal" if is_horizontal else "vertical", "flip_h:", flip_h, "rotation:", rotation)
	print("Ice spear starting from chest position:", global_position)
	
	# Play sounds
	if ice_whoosh_sound:
		ice_whoosh_sound.play()
		print("✓ Playing IceWhoosh sound")
	
	# Start travel animation
	start_travel_animation()

func start_travel_animation():
	"""Animate the ice spear traveling to the target position"""
	print("✓ Starting ice spear tween animation")
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_position, travel_duration)
	tween.tween_callback(_on_reach_target)

func _on_reach_target():
	"""Called when the ice spear reaches its target"""
	print("✓ Ice spear reached target position")
	
	# Call the callback if provided
	if on_reach_target_callback.is_valid():
		on_reach_target_callback.call()
	
	# Remove self
	queue_free()
	print("✓ Ice spear removed from scene")
