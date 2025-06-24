extends Node
class_name MapManager

var level_layout: Array = []
var grid_width: int
var grid_height: int

# This gets called by the main scene (Course1)
func load_map_data(data: Array) -> void:
	level_layout = data
	grid_height = level_layout.size()
	grid_width = level_layout[0].size()
	print("Map loaded:", grid_width, "x", grid_height)

func get_tile_type(x: int, y: int) -> String:
	if y >= 0 and y < grid_height and x >= 0 and x < grid_width:
		return level_layout[y][x]
	return ""


func is_tile_of_type(x: int, y: int, tile_type: String) -> bool:
	return get_tile_type(x, y) == tile_type
