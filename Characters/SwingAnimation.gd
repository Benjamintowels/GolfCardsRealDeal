extends Node2D

# Swing animation controller
var swing_sprite: AnimatedSprite2D
var animation_player: AnimationPlayer
var player_sprite: Sprite2D  # Reference to the normal player sprite
var is_swinging: bool = false
var swing_duration: float = 0.5  # Duration of the swing animation
var swing_tween: Tween

# Animation states
enum SwingState { IDLE, SWINGING, FINISHED }
var current_state: SwingState = SwingState.IDLE

func _ready():
	print("=== SWING ANIMATION _READY CALLED ===")
	print("=== SWING ANIMATION _READY ===")
	# Find the swing sprite
	swing_sprite = get_node_or_null("SwingSprite")
	if not swing_sprite:
		print("⚠ SwingSprite not found!")
		print("Available children:", get_children())
		return
	
	print("✓ Found SwingSprite:", swing_sprite)
	
	# Find the animation player - try different paths
	animation_player = get_node_or_null("../AnimatedSprite2D/AnimationPlayer")
	if not animation_player:
		print("⚠ AnimationPlayer not found at ../AnimatedSprite2D/AnimationPlayer")
		# Try alternative path
		animation_player = get_node_or_null("../../AnimatedSprite2D/AnimationPlayer")
		if not animation_player:
			print("⚠ AnimationPlayer not found at ../../AnimatedSprite2D/AnimationPlayer")
			# Try finding it by searching
			var search_result = find_parent("BennyChar").get_node_or_null("AnimatedSprite2D/AnimationPlayer")
			if search_result:
				animation_player = search_result
				print("✓ Found AnimationPlayer via search")
			else:
				print("✗ AnimationPlayer not found anywhere!")
				return
	
	print("✓ Found AnimationPlayer:", animation_player)
	print("✓ AnimationPlayer has animations:", animation_player.get_animation_list())
	
	# Find the normal player sprite (it's a sibling of this SwingAnimation node)
	player_sprite = get_node_or_null("../Sprite2D")
	if not player_sprite:
		print("⚠ Player Sprite2D not found!")
		return
	
	print("✓ Found Player Sprite2D:", player_sprite)
	
	# Connect to animation finished signal
	if animation_player.animation_finished.is_connected(_on_swing_animation_finished):
		animation_player.animation_finished.disconnect(_on_swing_animation_finished)
	animation_player.animation_finished.connect(_on_swing_animation_finished)
	
	print("✓ Swing animation system ready")

func start_swing_animation():
	"""Start the swing animation when height charge begins"""
	print("=== STARTING SWING ANIMATION ===")
	print("Current state:", current_state)
	print("Is swinging:", is_swinging)
	
	if is_swinging:
		print("Already swinging, ignoring new swing request")
		return
	
	is_swinging = true
	current_state = SwingState.SWINGING
	
	# Hide the normal player sprite and show the swing sprite
	if swing_sprite and animation_player and player_sprite:
		print("✓ All sprites found, switching to swing animation")
		
		# Hide the normal player sprite
		player_sprite.visible = false
		print("✓ Player sprite hidden")
		
		# Show the swing sprite and play animation
		swing_sprite.visible = true
		print("✓ SwingSprite made visible")
		
		# Reset the swing sprite to frame 0
		swing_sprite.frame = 0
		print("✓ SwingSprite frame reset to 0")
		
		# Play the animation
		animation_player.play("Swing")
		print("✓ Swing animation started")
		print("✓ SwingSprite visible:", swing_sprite.visible)
		print("✓ AnimationPlayer playing:", animation_player.is_playing())
		print("✓ AnimationPlayer current animation:", animation_player.current_animation)
		
		# Force the SwingAnimation node to be visible so the SwingSprite can be seen
		self.visible = true
		print("✓ SwingAnimation node made visible")
	else:
		print("✗ Required sprites not found!")
		print("  SwingSprite:", swing_sprite)
		print("  AnimationPlayer:", animation_player)
		print("  PlayerSprite:", player_sprite)

func stop_swing_animation():
	"""Stop the swing animation"""
	print("=== STOPPING SWING ANIMATION ===")
	if not is_swinging:
		print("Not currently swinging, ignoring stop request")
		return
	
	is_swinging = false
	current_state = SwingState.IDLE
	
	if swing_sprite and animation_player and player_sprite:
		animation_player.stop()
		swing_sprite.visible = false
		player_sprite.visible = true  # Show the normal player sprite again
		self.visible = false  # Hide the SwingAnimation node
		print("✓ Swing animation stopped, player sprite restored")
	else:
		print("✗ Required sprites not found!")

func _on_swing_animation_finished():
	"""Called when the swing animation completes"""
	print("=== SWING ANIMATION FINISHED ===")
	current_state = SwingState.FINISHED
	
	# Hide the swing sprite and show the normal player sprite
	if swing_sprite and player_sprite:
		swing_sprite.visible = false
		player_sprite.visible = true
		self.visible = false  # Hide the SwingAnimation node
		print("✓ Animation finished, switched back to normal player sprite")
	
	# Reset state after a short delay
	var timer = get_tree().create_timer(0.1)
	await timer.timeout
	
	is_swinging = false
	current_state = SwingState.IDLE
	print("✓ Swing animation reset to idle")

func is_currently_swinging() -> bool:
	"""Check if currently performing a swing animation"""
	return is_swinging

func get_swing_state() -> SwingState:
	"""Get the current swing state"""
	return current_state 
