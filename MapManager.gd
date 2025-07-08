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
