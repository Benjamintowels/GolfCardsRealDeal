extends Node

# Grid and tile management
var grid_size := Vector2i(50, 50)
var cell_size: int = 48
var grid_tiles = []
var grid_container: Control
var camera_container: Control

# Flashlight effect variables
var flashlight_radius := 150.0
var mouse_world_pos := Vector2.ZERO
var player_flashlight_center := Vector2.ZERO

# Camera offset for grid positioning
var camera_offset := Vector2.ZERO

# Signal for tile interactions
signal tile_mouse_entered(x: int, y: int)
signal tile_mouse_exited(x: int, y: int)
signal tile_input(event: InputEvent, x: int, y: int)

func setup(grid_size_param: Vector2i, cell_size_param: int, camera_container_param: Control) -> void:
	"""Initialize the grid manager with parameters"""
	grid_size = grid_size_param
	cell_size = cell_size_param
	camera_container = camera_container_param
	
	create_grid()

func create_grid() -> void:
	"""Create the main grid container and all tiles"""
	grid_container = Control.new()
	grid_container.name = "GridContainer"
	grid_container.z_index = -1  # Set grid overlay to appear behind other elements
	camera_container.add_child(grid_container)

	var total_size := Vector2(grid_size.x, grid_size.y) * cell_size
	grid_container.size = total_size
	camera_offset = (get_viewport().get_visible_rect().size - total_size) / 2
	camera_container.position = camera_offset

	for y in grid_size.y:
		grid_tiles.append([])
		for x in grid_size.x:
			var tile := create_grid_tile(x, y)
			grid_tiles[y].append(tile)
			grid_container.add_child(tile)

func create_grid_tile(x: int, y: int) -> Control:
	"""Create a single grid tile with highlighting and interaction"""
	var tile := Control.new()
	tile.name = "Tile_%d_%d" % [x, y]
	tile.position = Vector2(x, y) * cell_size
	tile.size = Vector2(cell_size, cell_size)
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.z_index = -100  # Set tiles to appear behind highlights but above ground

	var drawer := Control.new()
	drawer.name = "TileDrawer"
	drawer.size = tile.size
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.draw.connect(_draw_tile.bind(drawer, x, y))
	tile.add_child(drawer)

	var red := ColorRect.new()
	red.name = "Highlight"
	red.size = tile.size
	red.color = Color(1, 0, 0, 0.3)
	red.visible = false
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	red.z_index = 100  # High z_index to appear above land tiles
	tile.add_child(red)

	var green := ColorRect.new()
	green.name = "MovementHighlight"
	green.size = tile.size
	green.color = Color(0, 1, 0, 0.4)
	green.visible = false
	green.mouse_filter = Control.MOUSE_FILTER_IGNORE
	green.z_index = 100  # High z_index to appear above land tiles
	tile.add_child(green)

	var orange := ColorRect.new()
	orange.name = "AttackHighlight"
	orange.size = tile.size
	orange.color = Color(1, 0.2, 0, 0.8)  # Bright red-orange with high opacity
	orange.visible = false
	orange.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orange.z_index = 2000  # Very high z_index to ensure visibility above everything
	tile.add_child(orange)

	tile.mouse_entered.connect(_on_tile_mouse_entered.bind(x, y))
	tile.mouse_exited.connect(_on_tile_mouse_exited.bind(x, y))
	tile.gui_input.connect(_on_tile_input.bind(x, y))
	return tile

func _draw_tile(drawer: Control, x: int, y: int) -> void:
	"""Draw the flashlight effect on tiles"""
	var tile_screen_pos := Vector2(x, y) * cell_size + Vector2(cell_size / 2, cell_size / 2) + camera_container.position
	var dist := tile_screen_pos.distance_to(player_flashlight_center)
	if dist <= flashlight_radius:
		var alpha: float = clamp(1.0 - (dist / flashlight_radius), 0.0, 1.0)
		drawer.draw_rect(Rect2(Vector2.ZERO, drawer.size), Color(0.1, 0.1, 0.1, alpha * 0.3), true)
		drawer.draw_rect(Rect2(Vector2.ZERO, drawer.size), Color(0.5, 0.5, 0.5, alpha * 0.8), false, 1.0)

func _on_tile_mouse_entered(x: int, y: int) -> void:
	"""Handle mouse entering a tile"""
	tile_mouse_entered.emit(x, y)

func _on_tile_mouse_exited(x: int, y: int) -> void:
	"""Handle mouse exiting a tile"""
	tile_mouse_exited.emit(x, y)

func _on_tile_input(event: InputEvent, x: int, y: int) -> void:
	"""Handle input on a tile"""
	tile_input.emit(event, x, y)

func update_flashlight_center(center: Vector2) -> void:
	"""Update the flashlight center position"""
	player_flashlight_center = center

func get_grid_tile(x: int, y: int) -> Control:
	"""Get a specific grid tile by coordinates"""
	if y >= 0 and y < grid_tiles.size() and x >= 0 and x < grid_tiles[y].size():
		return grid_tiles[y][x]
	return null

func get_grid_container() -> Control:
	"""Get the grid container for adding other elements"""
	return grid_container

func get_camera_container() -> Control:
	"""Get the camera container"""
	return camera_container

func get_camera_offset() -> Vector2:
	"""Get the camera offset"""
	return camera_offset

func get_grid_size() -> Vector2i:
	"""Get the grid size"""
	return grid_size

func get_cell_size() -> int:
	"""Get the cell size"""
	return cell_size

func get_grid_tiles() -> Array:
	"""Get the grid tiles array"""
	return grid_tiles

func set_flashlight_radius(radius: float) -> void:
	"""Set the flashlight radius"""
	flashlight_radius = radius

func get_flashlight_radius() -> float:
	"""Get the flashlight radius"""
	return flashlight_radius 