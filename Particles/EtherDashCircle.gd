extends Node2D

@onready var circle_sprite: Sprite2D = $CircleSprite
@onready var flame_sprite: Sprite2D = $FlameSprite
@onready var ether_dash_sound: AudioStreamPlayer2D = $EtherDash
@onready var flame_on_sound: AudioStreamPlayer2D = $FlameOn

var animation_tween: Tween

func _ready():
	# Start with circle visible, flame hidden
	circle_sprite.visible = true
	flame_sprite.visible = false
	
	# Set initial scale for flame
	flame_sprite.scale = Vector2.ZERO
	
	# Set proper z-index values
	# CircleSprite should be above ground layer but below characters
	circle_sprite.z_index = 50  # Above ground tiles (which are around -100) but below characters (which are around 100+)
	
	# FlameSprite should be at the very top layer
	flame_sprite.z_index = 2000  # Very high z-index to appear above everything
	
	# DEBUG: Print placement information
	print("=== ETHERDASH EFFECT PLACEMENT DEBUG ===")
	print("Visual position (global):", global_position)
	print("Grid position (calculated):", Vector2i(global_position.x / 48, global_position.y / 48))
	print("Z-index - Circle:", circle_sprite.z_index, "Flame:", flame_sprite.z_index)
	print("Circle visible:", circle_sprite.visible, "Flame visible:", flame_sprite.visible)
	print("Circle texture:", circle_sprite.texture, "Flame texture:", flame_sprite.texture)
	print("========================================")
	
	# Play the EtherDash sound
	if ether_dash_sound:
		ether_dash_sound.play()
	
	# Start the animation sequence after a small delay to ensure visibility
	await get_tree().process_frame
	start_animation_sequence()

func start_animation_sequence():
	# Stop any existing tween
	if animation_tween and animation_tween.is_valid():
		animation_tween.kill()
	
	animation_tween = create_tween()
	animation_tween.set_trans(Tween.TRANS_QUAD)
	animation_tween.set_ease(Tween.EASE_OUT)
	
	# Step 1: Ensure circle is visible and at full opacity
	animation_tween.tween_callback(func(): 
		circle_sprite.visible = true
		circle_sprite.modulate.a = 1.0
	)
	
	# Step 2: Show flame sprite and animate it growing
	animation_tween.tween_callback(func(): 
		flame_sprite.visible = true
		flame_sprite.modulate.a = 1.0
		# Play FlameOn sound when flame appears
		if flame_on_sound:
			flame_on_sound.play()
	)
	animation_tween.tween_property(flame_sprite, "scale", Vector2.ONE, 0.3)
	
	# Step 3: Fade out the flame
	animation_tween.tween_property(flame_sprite, "modulate:a", 0.0, 0.4)
	
	# Step 4: Hide flame sprite
	animation_tween.tween_callback(func(): flame_sprite.visible = false)
	
	# Step 5: Keep circle visible for longer, then fade it out
	animation_tween.tween_interval(0.5)  # Wait 0.5 seconds
	animation_tween.tween_property(circle_sprite, "modulate:a", 0.0, 0.6)
	
	# Step 6: Clean up the effect after animation completes
	animation_tween.tween_callback(queue_free)
