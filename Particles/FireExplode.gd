extends AnimatedSprite2D

# Animation properties
var animation_duration: float = 1.0
var fade_start_time: float = 0.5
var on_complete_callback: Callable

func _ready():
	# Start the animation
	play("default")
	print("✓ FireExplode animation started")

func setup_and_play(position: Vector2, duration: float = 1.0, callback: Callable = Callable()):
	"""Setup the explosion and play it at the specified position"""
	animation_duration = duration
	fade_start_time = duration * 0.5
	on_complete_callback = callback
	
	# Position the explosion
	global_position = position
	
	# Start the animation sequence
	start_explosion_sequence()

func start_explosion_sequence():
	"""Start the explosion animation with fade-out effect"""
	print("✓ Starting FireExplode animation sequence")
	
	# Set up a timer to start the fade-out effect
	var fade_timer = get_tree().create_timer(fade_start_time)
	fade_timer.timeout.connect(_start_fade_out)
	
	# Set up a timer to complete the explosion
	var complete_timer = get_tree().create_timer(animation_duration)
	complete_timer.timeout.connect(_on_explosion_complete)

func _start_fade_out():
	"""Start the fade-out effect"""
	print("✓ Starting FireExplode fade-out effect")
	var fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(self, "modulate:a", 0.0, fade_start_time)

func _on_explosion_complete():
	"""Called when the explosion animation is complete"""
	print("✓ FireExplode animation completed")
	
	# Call the callback if provided
	if on_complete_callback.is_valid():
		on_complete_callback.call()
	
	# Remove self
	queue_free()
	print("✓ FireExplode removed from scene") 
