extends Node2D

signal ice_tile_completed(tile_position: Vector2i)

var tile_position: Vector2i = Vector2i.ZERO
var current_turn: int = 0
var turns_to_ice: int = 2  # Show ice for 2 turns
var is_frozen: bool = false

# Visual elements
var frozen_overlay: ColorRect = null
var original_tile_sprite: Sprite2D = null  # Reference to the original tile sprite

# Audio
var ice_on_sound: AudioStreamPlayer2D

# Friction modification properties
const ICE_TILE_FRICTION: float = 0.15  # Low friction for ice tiles
var friction_applied: bool = false  # Track if friction has been applied

func _ready():
	# Add to ice_tiles group for friction detection
	add_to_group("ice_tiles")
	
	# Get audio reference
	ice_on_sound = get_node_or_null("Snow")
	
	# Play the ice sound when created
	if ice_on_sound and ice_on_sound.stream:
		ice_on_sound.play()
	
	# Find and store reference to the original tile sprite
	_find_original_tile_sprite()
	
	# Create frozen overlay (initially hidden)
	_create_frozen_overlay()
	
	# Start with light blue tint on the original tile sprite
	_show_ice_effect()
	
	# Set up Y-sorting to match player position + 1
	_update_y_sort()
	
	# Apply zero friction to this tile
	call_deferred("_apply_ice_friction")
	
	print("IceTile ready - z_index:", z_index, "position:", global_position, "tile_position:", tile_position)

func _find_original_tile_sprite():
	"""Find and store reference to the original tile sprite at this position"""
	# Find the course to access the obstacle map
	var course = get_tree().current_scene
	if not course:
		print("Could not find course for tile sprite reference")
		return
	
	# Check if course has obstacle_map
	if "obstacle_map" in course:
		var obstacle_map = course.obstacle_map
		if obstacle_map.has(tile_position):
			var tile = obstacle_map[tile_position]
			if tile and tile.has_node("Sprite2D"):
				original_tile_sprite = tile.get_node("Sprite2D")
				print("Found original tile sprite for frozen effect at:", tile_position)
			else:
				print("Tile at", tile_position, "does not have Sprite2D child")
		else:
			print("No tile found in obstacle_map at position:", tile_position)
	else:
		print("Course does not have obstacle_map property")

func _create_frozen_overlay():
	"""Create the frozen overlay (kept for compatibility but not used)"""
	frozen_overlay = ColorRect.new()
	frozen_overlay.name = "FrozenOverlay"
	frozen_overlay.size = Vector2(48, 48)  # Match tile size
	frozen_overlay.position = Vector2(-24, -24)  # Center on tile
	frozen_overlay.color = Color(0.7, 0.9, 1.0, 0.8)  # Light blue
	frozen_overlay.visible = false
	frozen_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frozen_overlay)

func _show_ice_effect():
	"""Apply light blue tint to the original tile sprite"""
	if original_tile_sprite:
		# Apply a more pronounced blue tint to simulate ice
		original_tile_sprite.modulate = Color(0.6, 0.8, 1.0, 1.0)  # More blue tint
		print("Applied ice effect to tile sprite at:", tile_position)
	else:
		print("No original tile sprite found for ice effect at:", tile_position)
		# Fallback to overlay if no tile sprite found
		if frozen_overlay:
			frozen_overlay.visible = true

func set_tile_position(pos: Vector2i):
	"""Set the tile position this ice tile represents"""
	tile_position = pos

func advance_turn():
	"""Advance the turn counter and handle state changes"""
	current_turn += 1
	
	if current_turn >= turns_to_ice and not is_frozen:
		# Time to transition to frozen state
		_transition_to_frozen()

func _transition_to_frozen():
	"""Transition from ice to frozen state"""
	is_frozen = true
	
	# For ice tiles, we don't need a transition since we're already showing the light blue tint
	# Just emit the completion signal
	ice_tile_completed.emit(tile_position)

func is_ice_active() -> bool:
	"""Check if the ice is still active (not frozen)"""
	return not is_frozen

func get_tile_position() -> Vector2i:
	"""Get the tile position this ice tile represents"""
	return tile_position

func _update_y_sort():
	"""Update Y-sorting to match player position + 1"""
	# Use the same Y-sorting logic as characters but add +1
	# Get the world position for this tile
	var world_position = global_position
	
	# Calculate base z_index the same way as characters
	var base_z_index = int(world_position.y) + 1000
	
	# Add character offset (0) + 1 for ice tiles
	var z_index = base_z_index + 0 + 1
	
	# Set the z_index
	self.z_index = z_index
	
	print("Ice tile Y-sort updated - position:", world_position, "z_index:", z_index)

func _apply_ice_friction():
	"""Apply zero friction to this tile"""
	if friction_applied:
		return  # Prevent multiple applications
	
	friction_applied = true
	
	# Notify the map manager that this tile is now an ice tile
	var map_manager = _find_map_manager()
	if map_manager and map_manager.has_method("set_tile_iced"):
		map_manager.set_tile_iced(tile_position.x, tile_position.y)
		print("Ice tile friction applied at position:", tile_position)

func _find_map_manager() -> Node:
	"""Find the map manager in the scene"""
	# Method 1: Try to get from course
	var course = get_tree().current_scene
	if course and course.has_node("MapManager"):
		return course.get_node("MapManager")
	
	# Method 2: Search scene tree for MapManager
	var scene_tree = get_tree()
	var all_nodes = scene_tree.get_nodes_in_group("")
	
	for node in all_nodes:
		if node.get_script() and node.get_script().resource_path.ends_with("MapManager.gd"):
			return node
	
	return null 