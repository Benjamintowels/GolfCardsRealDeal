extends Node
class_name Grid3DManager

# Grid3DManager - Handles 3D grid floor and grid-based positioning
# Optimized for 3D space with efficient grid operations

signal grid_created
signal tile_clicked(grid_position: Vector2i)

# Grid settings
var grid_size: Vector2i = Vector2i(50, 50)
var cell_size: int = 48
var grid_floor: MeshInstance3D = null
var world_container: Node3D = null

# Grid data
var grid_tiles: Array = []
var grid_material: StandardMaterial3D = null

func setup(grid_size_param: Vector2i, cell_size_param: int, world_container_param: Node3D):
	"""Initialize the 3D grid system"""
	grid_size = grid_size_param
	cell_size = cell_size_param
	world_container = world_container_param
	
	# Don't create grid floor here - it will be created by the layout texture
	_initialize_grid_data()
	
	grid_created.emit()
	print("✓ Grid3DManager setup complete")

# Grid floor creation removed - now handled by layout texture system

func _initialize_grid_data():
	"""Initialize grid data structure"""
	grid_tiles.clear()
	
	for y in range(grid_size.y):
		grid_tiles.append([])
		for x in range(grid_size.x):
			grid_tiles[y].append({
				"position": Vector2i(x, y),
				"world_position": grid_to_world_position(Vector2i(x, y)),
				"occupied": false,
				"object": null
			})

# Grid utility functions
func grid_to_world_position(grid_pos: Vector2i) -> Vector3:
	"""Convert grid position to 3D world position"""
	var world_x = grid_pos.x * cell_size - (grid_size.x * cell_size) / 2
	var world_z = grid_pos.y * cell_size - (grid_size.y * cell_size) / 2
	return Vector3(world_x, 0, world_z)

func world_to_grid_position(world_pos: Vector3) -> Vector2i:
	"""Convert 3D world position to grid position"""
	var grid_x = int((world_pos.x + (grid_size.x * cell_size) / 2) / cell_size)
	var grid_z = int((world_pos.z + (grid_size.y * cell_size) / 2) / cell_size)
	return Vector2i(grid_x, grid_z)

func update_floor_texture(new_texture: Texture2D):
	"""Update the grid floor with a new texture"""
	if grid_floor and grid_material:
		grid_material.albedo_texture = new_texture
		print("✓ Updated grid floor texture")

func is_valid_grid_position(grid_pos: Vector2i) -> bool:
	"""Check if a grid position is valid"""
	return grid_pos.x >= 0 and grid_pos.x < grid_size.x and grid_pos.y >= 0 and grid_pos.y < grid_size.y

func is_tile_occupied(grid_pos: Vector2i) -> bool:
	"""Check if a tile is occupied"""
	if not is_valid_grid_position(grid_pos):
		return true
	return grid_tiles[grid_pos.y][grid_pos.x].occupied

func set_tile_occupied(grid_pos: Vector2i, occupied: bool, object: Node3D = null):
	"""Set tile occupation status"""
	if not is_valid_grid_position(grid_pos):
		return
	
	grid_tiles[grid_pos.y][grid_pos.x].occupied = occupied
	grid_tiles[grid_pos.y][grid_pos.x].object = object

func get_tile_center_world_position(grid_pos: Vector2i) -> Vector3:
	"""Get the center world position of a grid tile"""
	var base_pos = grid_to_world_position(grid_pos)
	return Vector3(base_pos.x + cell_size / 2, 0, base_pos.z + cell_size / 2)

func get_adjacent_tiles(grid_pos: Vector2i) -> Array[Vector2i]:
	"""Get adjacent grid positions"""
	var adjacent: Array[Vector2i] = []
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	
	for direction in directions:
		var new_pos = grid_pos + direction
		if is_valid_grid_position(new_pos):
			adjacent.append(new_pos)
	
	return adjacent

func get_tiles_in_radius(grid_pos: Vector2i, radius: int) -> Array[Vector2i]:
	"""Get all tiles within a certain radius"""
	var tiles: Array[Vector2i] = []
	
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var check_pos = grid_pos + Vector2i(x, y)
			if is_valid_grid_position(check_pos):
				var distance = abs(x) + abs(y)  # Manhattan distance
				if distance <= radius:
					tiles.append(check_pos)
	
	return tiles

# Public API
func get_grid_size() -> Vector2i:
	return grid_size

func get_cell_size() -> int:
	return cell_size

func get_grid_floor() -> MeshInstance3D:
	return grid_floor

func highlight_tile(grid_pos: Vector2i, color: Color = Color.RED):
	"""Highlight a specific tile (for debugging/UI)"""
	# This could be implemented with a highlight overlay
	# For now, just print the position
	print("Highlighting tile:", grid_pos)

func clear_highlights():
	"""Clear all tile highlights"""
	# Implementation for clearing highlights
	pass 
