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

# Damage dealing properties
const FIRE_TILE_DAMAGE: int = 30  # Damage to objects on the fire tile
const ADJACENT_TILE_DAMAGE: int = 15  # Damage to objects on adjacent tiles
var damage_dealt: bool = false  # Track if damage has been dealt to prevent multiple applications

func _ready():
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
	
	# Set up Y-sorting to match player position + 1
	_update_y_sort()
	
	# Deal damage to objects on this tile and adjacent tiles
	call_deferred("_deal_fire_damage")
	
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

func _update_y_sort():
	"""Update Y-sorting to match player position + 1"""
	# Use the same Y-sorting logic as characters but add +1
	# Get the world position for this tile
	var world_position = global_position
	
	# Calculate base z_index the same way as characters
	var base_z_index = int(world_position.y) + 1000
	
	# Add character offset (0) + 1 for fire tiles
	var z_index = base_z_index + 0 + 1
	
	# Set the z_index
	self.z_index = z_index
	
	print("Fire tile Y-sort updated - position:", world_position, "z_index:", z_index)

func _deal_fire_damage():
	"""Deal damage to objects on the fire tile and adjacent tiles"""
	if damage_dealt:
		return  # Prevent multiple damage applications
	
	damage_dealt = true
	
	# Deal damage to objects on the fire tile
	_deal_damage_to_objects_at_position(tile_position, FIRE_TILE_DAMAGE)
	
	# Deal damage to objects on adjacent tiles
	var adjacent_positions = _get_adjacent_positions(tile_position)
	for adj_pos in adjacent_positions:
		_deal_damage_to_objects_at_position(adj_pos, ADJACENT_TILE_DAMAGE)
	
	print("Fire tile damage dealt at position:", tile_position)

func _get_adjacent_positions(pos: Vector2i) -> Array[Vector2i]:
	"""Get all adjacent positions to the given position"""
	var adjacent: Array[Vector2i] = []
	var directions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0),  # Left
		Vector2i(1, -1),  # Up-right
		Vector2i(1, 1),   # Down-right
		Vector2i(-1, 1),  # Down-left
		Vector2i(-1, -1)  # Up-left
	]
	
	for direction in directions:
		adjacent.append(pos + direction)
	
	return adjacent

func _deal_damage_to_objects_at_position(pos: Vector2i, damage: int):
	"""Deal damage to all objects with health at the given position"""
	# Find the course to access entities
	var course = get_tree().current_scene
	if not course:
		return
	
	# Check for player at this position
	if "player_grid_pos" in course:
		var player_grid_pos = course.player_grid_pos
		if player_grid_pos == pos:
			var player = course.get_node_or_null("Player")
			if player and player.has_method("take_damage"):
				player.take_damage(damage)
				print("Player took", damage, "fire damage at position:", pos)
	
	# Check for NPCs at this position
	var entities = course.get_node_or_null("Entities")
	if entities and entities.has_method("get_npcs"):
		var npcs = entities.get_npcs()
		for npc in npcs:
			if is_instance_valid(npc) and npc.has_method("get_grid_position"):
				if npc.get_grid_position() == pos:
					if npc.has_method("take_damage"):
						npc.take_damage(damage)
						print("NPC", npc.name, "took", damage, "fire damage at position:", pos)
	
	# Check for other objects with health (like oil drums)
	var interactables = get_tree().get_nodes_in_group("interactables")
	for interactable in interactables:
		if is_instance_valid(interactable) and interactable.has_method("get_grid_position"):
			if interactable.get_grid_position() == pos:
				if interactable.has_method("take_damage"):
					interactable.take_damage(damage)
					print("Object", interactable.name, "took", damage, "fire damage at position:", pos)
