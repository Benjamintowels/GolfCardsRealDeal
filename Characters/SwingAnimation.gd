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
	# Find the swing sprite
	swing_sprite = get_node_or_null("SwingSprite")
	if not swing_sprite:
		print("⚠ SwingSprite not found!")
		print("Available children:", get_children())
		return
	
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
			else:
				print("✗ AnimationPlayer not found anywhere!")
				return
	
	# Find the normal player sprite (it's a sibling of this SwingAnimation node)
	player_sprite = get_node_or_null("../Sprite2D")
	if not player_sprite:
		print("⚠ Player Sprite2D not found!")
		return
	
	# Connect to animation finished signal
	if animation_player.animation_finished.is_connected(_on_swing_animation_finished):
		animation_player.animation_finished.disconnect(_on_swing_animation_finished)
	animation_player.animation_finished.connect(_on_swing_animation_finished)
	
	print("✓ Swing animation system ready")

func start_swing_animation():
	
	
	
	is_swinging = true
	current_state = SwingState.SWINGING
	
	# Hide the normal player sprite and show the swing sprite
	if swing_sprite and animation_player and player_sprite:

		# Hide the normal player sprite
		player_sprite.visible = false
		
		# Show the swing sprite and play animation
		swing_sprite.visible = true
		
		# Reset the swing sprite to frame 0
		swing_sprite.frame = 0
		
		# Play the animation
		animation_player.play("Swing")

		# Force the SwingAnimation node to be visible so the SwingSprite can be seen
		self.visible = true

func stop_swing_animation():
	"""Stop the swing animation"""
	
	is_swinging = false
	current_state = SwingState.IDLE
	
	if swing_sprite and animation_player and player_sprite:
		animation_player.stop()
		swing_sprite.visible = false
		player_sprite.visible = true  # Show the normal player sprite again
		self.visible = false  # Hide the SwingAnimation node

func _on_swing_animation_finished():
	"""Called when the swing animation completes"""
	current_state = SwingState.FINISHED
	
	# Hide the swing sprite and show the normal player sprite
	if swing_sprite and player_sprite:
		swing_sprite.visible = false
		player_sprite.visible = true
		self.visible = false  # Hide the SwingAnimation node

	# Reset state after a short delay
	var timer = get_tree().create_timer(0.1)
	await timer.timeout
	
	is_swinging = false
	current_state = SwingState.IDLE


func is_currently_swinging() -> bool:
	"""Check if currently performing a swing animation"""
	return is_swinging

func get_swing_state() -> SwingState:
	"""Get the current swing state"""
	return current_state 
