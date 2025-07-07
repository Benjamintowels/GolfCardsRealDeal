extends Node2D

signal fire_tile_completed(tile_position: Vector2i)

var tile_position: Vector2i = Vector2i.ZERO
var current_turn: int = 0
var turns_to_fire: int = 2  # Show fire for 2 turns
var is_scorched: bool = false

# Visual elements
var fire_sprites: Array[Sprite2D] = []
var scorched_overlay: ColorRect = null

# Audio
var flame_on_sound: AudioStreamPlayer2D

func _ready():
	# Set z_index to appear above ground tiles but below UI
	z_index = 50  # Much higher than ground tiles (-5) but below UI (100+)
	
	# Get references to fire sprites
	fire_sprites = [
		get_node_or_null("FireTileSprite"),
		get_node_or_null("FireTileSprite2"), 
		get_node_or_null("FireTileSprite3")
	]
	
	# Get audio reference
	flame_on_sound = get_node_or_null("FlameOn")
	
	# Play the flame sound when created
	if flame_on_sound and flame_on_sound.stream:
		flame_on_sound.play()
	
	# Create scorched overlay (initially hidden)
	_create_scorched_overlay()
	
	# Start with fire sprites visible
	_show_fire_sprites()
	
	print("FireTile ready - z_index:", z_index, "position:", global_position, "tile_position:", tile_position)

func _create_scorched_overlay():
	"""Create the scorched earth overlay"""
	scorched_overlay = ColorRect.new()
	scorched_overlay.name = "ScorchedOverlay"
	scorched_overlay.size = Vector2(48, 48)  # Match tile size
	scorched_overlay.position = Vector2(-24, -24)  # Center on tile
	scorched_overlay.color = Color(0.1, 0.05, 0.02, 0.8)  # Dark brown/black
	scorched_overlay.visible = false
	scorched_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scorched_overlay)

func _show_fire_sprites():
	"""Show the fire sprites with flickering effect"""
	for sprite in fire_sprites:
		if sprite:
			sprite.visible = true
			# Start flickering animation
			_start_fire_flicker(sprite)

func _start_fire_flicker(sprite: Sprite2D):
	"""Start flickering animation for a fire sprite"""
	var tween = create_tween()
	tween.set_loops()  # Loop forever
	tween.tween_property(sprite, "modulate:a", 0.3, 0.3)  # Fade to 30%
	tween.tween_property(sprite, "modulate:a", 1.0, 0.3)  # Fade back to 100%

func _hide_fire_sprites():
	"""Hide all fire sprites"""
	for sprite in fire_sprites:
		if sprite:
			sprite.visible = false

func set_tile_position(pos: Vector2i):
	"""Set the tile position this fire tile represents"""
	tile_position = pos

func advance_turn():
	"""Advance the turn counter and handle state changes"""
	current_turn += 1
	
	if current_turn >= turns_to_fire and not is_scorched:
		# Time to transition to scorched earth
		_transition_to_scorched()

func _transition_to_scorched():
	"""Transition from fire to scorched earth"""
	is_scorched = true
	
	# Fade out fire sprites
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5)  # Fade out over 0.5 seconds
	
	# After fade out, hide fire sprites and show scorched overlay
	await fade_tween.finished
	
	_hide_fire_sprites()
	modulate.a = 1.0  # Reset alpha
	
	# Show scorched overlay
	if scorched_overlay:
		scorched_overlay.visible = true
	
	# Emit signal that fire tile is complete
	fire_tile_completed.emit(tile_position)

func is_fire_active() -> bool:
	"""Check if the fire is still active (not scorched)"""
	return not is_scorched

func get_tile_position() -> Vector2i:
	"""Get the tile position this fire tile represents"""
	return tile_position
