extends Node
class_name MapManager

var level_layout: Array = []
var grid_width: int
var grid_height: int

# Scorched tiles tracking
var scorched_tiles: Array[Vector2i] = []

# Ice tiles tracking
var ice_tiles: Array[Vector2i] = []

# This gets called by the main scene (Course1)
func load_map_data(data: Array) -> void:
	level_layout = data
	grid_height = level_layout.size()
	grid_width = level_layout[0].size()
	scorched_tiles.clear()  # Reset scorched tiles for new map
	ice_tiles.clear()  # Reset ice tiles for new map
	print("Map loaded:", grid_width, "x", grid_height)

func get_tile_type(x: int, y: int) -> String:
	if y >= 0 and y < grid_height and x >= 0 and x < grid_width:
		var base_tile = level_layout[y][x]
		
		# Check if this tile has been iced (ice takes priority over scorched)
		if Vector2i(x, y) in ice_tiles:
			return "Ice"
		
		# Check if this tile has been scorched
		if Vector2i(x, y) in scorched_tiles:
			return "Scorched"
		
		return base_tile
	return ""

func is_tile_of_type(x: int, y: int, tile_type: String) -> bool:
	return get_tile_type(x, y) == tile_type

func set_tile_scorched(x: int, y: int) -> void:
	"""Mark a tile as scorched (burned by fire)"""
	var tile_pos = Vector2i(x, y)
	if tile_pos not in scorched_tiles:
		scorched_tiles.append(tile_pos)
		print("Tile scorched at:", tile_pos)

func is_tile_scorched(x: int, y: int) -> bool:
	"""Check if a tile is scorched"""
	return Vector2i(x, y) in scorched_tiles

func get_scorched_tiles() -> Array[Vector2i]:
	"""Get all scorched tile positions"""
	return scorched_tiles

func set_tile_iced(x: int, y: int) -> void:
	"""Mark a tile as iced (frozen by ice)"""
	var tile_pos = Vector2i(x, y)
	if tile_pos not in ice_tiles:
		ice_tiles.append(tile_pos)
		print("Tile iced at:", tile_pos)

func is_tile_iced(x: int, y: int) -> bool:
	"""Check if a tile is iced"""
	return Vector2i(x, y) in ice_tiles

func get_ice_tiles() -> Array[Vector2i]:
	"""Get all ice tile positions"""
	return ice_tiles

# Converts a world position (Vector2) to a grid tile position (Vector2i)
func world_to_map(world_pos: Vector2) -> Vector2i:
	var cell_size = 48  # Adjust if your grid uses a different size
	return Vector2i(int(floor(world_pos.x / cell_size)), int(floor(world_pos.y / cell_size)))

# ===== ENVIRONMENT TILE MANAGEMENT =====

func advance_fire_tiles() -> void:
	"""Advance all fire tiles to the next turn"""
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	for fire_tile in fire_tiles:
		if is_instance_valid(fire_tile) and fire_tile.has_method("advance_turn"):
			fire_tile.advance_turn()
	print("Advanced fire tiles to next turn")

func advance_ice_tiles() -> void:
	"""Advance all ice tiles to the next turn"""
	var ice_tiles = get_tree().get_nodes_in_group("ice_tiles")
	for ice_tile in ice_tiles:
		if is_instance_valid(ice_tile) and ice_tile.has_method("advance_turn"):
			ice_tile.advance_turn()
	print("Advanced ice tiles to next turn")

func highlight_tee_tiles() -> void:
	"""Highlight all tee tiles on the map"""
	var course = get_parent()
	if not course or not course.has_node("GridManager"):
		print("ERROR: Could not find GridManager for tee highlighting")
		return
	
	var grid_manager = course.get_node("GridManager")
	
	# Clear all highlights first
	for y in grid_manager.get_grid_size().y:
		for x in grid_manager.get_grid_size().x:
			grid_manager.get_grid_tiles()[y][x].get_node("Highlight").visible = false
	
	# Highlight tee tiles
	for y in grid_manager.get_grid_size().y:
		for x in grid_manager.get_grid_size().x:
			if get_tile_type(x, y) == "Tee":
				grid_manager.get_grid_tiles()[y][x].get_node("Highlight").visible = true
				# Change highlight color to blue for tee tiles
				var highlight = grid_manager.get_grid_tiles()[y][x].get_node("Highlight")
				highlight.color = Color(0, 0.5, 1, 0.6)  # Blue with transparency

func exit_movement_mode() -> void:
	"""Exit movement mode and clean up related systems"""
	var course = get_parent()
	if not course:
		print("ERROR: Could not find course for movement mode exit")
		return
	
	# Exit movement controller
	if course.movement_controller:
		course.movement_controller.exit_movement_mode()
	
	# Exit attack handler if in attack mode
	if course.attack_handler and course.attack_handler.is_in_attack_mode():
		course.attack_handler.exit_attack_mode()
	
	# Exit weapon handler if in weapon mode
	if course.weapon_handler and course.weapon_handler.is_in_weapon_mode():
		course.weapon_handler.exit_weapon_mode()
	
	# Update deck display
	if course.ui_manager:
		course.ui_manager.update_deck_display()
