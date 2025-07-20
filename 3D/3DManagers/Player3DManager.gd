extends Node
class_name Player3DManager

# Player3DManager - Handles 3D player positioning, movement, and representation
# Optimized for 3D space with smooth movement and grid-based positioning

signal player_moved(new_position: Vector3)
signal player_ready
signal player_created

# Player references
var player_node: Node3D = null
var player_sprite: Sprite3D = null
var grid_manager: Grid3DManager = null
var map_manager: Node = null
var camera_manager: Node = null
var cell_size: int = 48

# Player state
var current_grid_position: Vector2i = Vector2i(25, 25)
var target_grid_position: Vector2i = Vector2i(25, 25)
var is_moving: bool = false
var movement_tween: Tween = null

# Character selection
var selected_character: int = 1
var character_textures = {
	1: "res://Characters/LaylaMid.png",
	2: "res://Characters/BennyMid.png", 
	3: "res://Characters/ClarkMid.png"
}

# Movement settings
var movement_speed: float = 2.0
var movement_height: float = 24.0  # Height above ground

func setup(grid_mgr: Grid3DManager, map_mgr: Node, camera_mgr: Node, cell_size_param: int):
	"""Initialize the 3D player system"""
	grid_manager = grid_mgr
	map_manager = map_mgr
	camera_manager = camera_mgr
	cell_size = cell_size_param
	
	# Set character from global selection
	selected_character = Global.selected_character if Global.has_method("get_selected_character") else 1
	
	print("✓ Player3DManager setup complete")

func create_player():
	"""Create the 3D player sprite"""
	
	# Create player node
	player_node = Node3D.new()
	player_node.name = "Player3D"
	
	# Create player sprite
	player_sprite = Sprite3D.new()
	player_sprite.name = "PlayerSprite3D"
	
	# Load character texture
	var texture_path = character_textures.get(selected_character, character_textures[1])
	var texture = load(texture_path)
	if texture:
		player_sprite.texture = texture
	else:
		print("⚠ Could not load character texture:", texture_path)
		# Create fallback texture
		player_sprite.texture = _create_fallback_texture()
	
	# Setup sprite properties
	player_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	player_sprite.pixel_size = 0.15  # Slightly larger than obstacles
	player_sprite.position.y = movement_height
	
	# Add sprite to player node
	player_node.add_child(player_sprite)
	
	# Position player at start position
	_set_player_position(current_grid_position)
	
	# Add to world
	if grid_manager and grid_manager.world_container:
		grid_manager.world_container.add_child(player_node)
	
	# Mark tile as occupied
	grid_manager.set_tile_occupied(current_grid_position, true, player_node)
	
	player_created.emit()
	print("✓ 3D Player created at position:", current_grid_position)

func _create_fallback_texture() -> Texture2D:
	"""Create a fallback texture if character texture fails to load"""
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLUE)  # Blue fallback color
	
	# Draw a simple player shape
	for x in range(16, 48):
		for y in range(16, 48):
			image.set_pixel(x, y, Color.WHITE)
	
	return ImageTexture.create_from_image(image)

func set_start_position(grid_pos: Vector2i):
	"""Set the player's start position"""
	current_grid_position = grid_pos
	target_grid_position = grid_pos
	
	if player_node:
		_set_player_position(grid_pos)

func _set_player_position(grid_pos: Vector2i):
	"""Set player position based on grid coordinates"""
	if not grid_manager:
		return
	
	var world_pos = grid_manager.get_tile_center_world_position(grid_pos)
	player_node.position = world_pos

func move_player(direction: Vector2i):
	"""Move player in the specified direction"""
	if is_moving:
		return
	
	var new_grid_pos = current_grid_position + direction
	
	# Check if new position is valid and not occupied
	if not grid_manager.is_valid_grid_position(new_grid_pos):
		print("⚠ Invalid move position:", new_grid_pos)
		return
	
	if grid_manager.is_tile_occupied(new_grid_pos):
		print("⚠ Position occupied:", new_grid_pos)
		return
	
	# Start movement
	_start_movement(new_grid_pos)

func _start_movement(new_grid_pos: Vector2i):
	"""Start smooth movement to new grid position"""
	is_moving = true
	target_grid_position = new_grid_pos
	
	# Mark old tile as unoccupied
	grid_manager.set_tile_occupied(current_grid_position, false)
	
	# Mark new tile as occupied
	grid_manager.set_tile_occupied(new_grid_pos, true, player_node)
	
	# Get world positions
	var start_pos = grid_manager.get_tile_center_world_position(current_grid_position)
	var end_pos = grid_manager.get_tile_center_world_position(new_grid_pos)
	
	# Create movement tween
	movement_tween = get_tree().create_tween()
	movement_tween.set_trans(Tween.TRANS_SINE)
	movement_tween.set_ease(Tween.EASE_OUT)
	
	# Add a small arc to the movement
	var mid_pos = (start_pos + end_pos) / 2
	mid_pos.y = movement_height + 10  # Slight jump during movement
	
	movement_tween.tween_property(player_node, "position", mid_pos, movement_speed / 2)
	movement_tween.tween_property(player_node, "position", end_pos, movement_speed / 2)
	
	# Connect completion signal
	movement_tween.finished.connect(_on_movement_complete)
	
	# Update current position
	current_grid_position = new_grid_pos
	
	print("✓ Player moving to:", new_grid_pos)

func _on_movement_complete():
	"""Called when movement tween completes"""
	is_moving = false
	movement_tween = null
	
	# Emit movement signal
	player_moved.emit(player_node.global_position)
	
	# Update camera
	if camera_manager and camera_manager.has_method("update_camera_to_player"):
		camera_manager.update_camera_to_player()
	
	print("✓ Player movement complete")

func reset_player_position():
	"""Reset player to start position"""
	if is_moving and movement_tween:
		movement_tween.kill()
		movement_tween = null
	
	is_moving = false
	_set_player_position(current_grid_position)

func get_player_position() -> Vector3:
	"""Get current player world position"""
	if player_node:
		return player_node.global_position
	return Vector3.ZERO

func get_player_grid_position() -> Vector2i:
	"""Get current player grid position"""
	return current_grid_position

func get_player_node() -> Node3D:
	"""Get the player node"""
	return player_node

func is_player_moving() -> bool:
	"""Check if player is currently moving"""
	return is_moving

func update(delta: float):
	"""Update player state (called by main manager)"""
	# Any per-frame updates can go here
	pass

# Public API
func set_character(character_id: int):
	"""Change player character"""
	if character_id in character_textures and player_sprite:
		var texture_path = character_textures[character_id]
		var texture = load(texture_path)
		if texture:
			player_sprite.texture = texture
			selected_character = character_id
			print("✓ Player character changed to:", character_id)

func get_character() -> int:
	"""Get current character ID"""
	return selected_character 