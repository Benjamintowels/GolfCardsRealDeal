extends Node
class_name Map3DManager

# Map3DManager - Handles 3D map layouts and hole data
# Optimized for 3D space with efficient map loading

signal map_loaded(map_name: String)
signal hole_completed(hole_number: int)

# Map data
var current_map_layout: Array = []
var current_hole: int = 1
var total_holes: int = 18
var grid_width: int = 50
var grid_height: int = 50

# Hole positions
var hole_positions: Array[Vector2i] = []
var player_start_positions: Array[Vector2i] = []

func _ready():
	print("✓ Map3DManager initialized")

func load_initial_map() -> Array:
	"""Load the initial map layout"""
	current_hole = 1
	return _load_hole_layout(current_hole)

func load_next_hole() -> Array:
	"""Load the next hole layout"""
	current_hole += 1
	
	if current_hole > total_holes:
		print("✓ All holes completed!")
		return []
	
	print("✓ Loading hole", current_hole)
	return _load_hole_layout(current_hole)

func _load_hole_layout(hole_number: int) -> Array:
	"""Load a specific hole layout from the Maps directory"""
	
	# Try to load the hole layout script
	var hole_layout_path = "res://Maps/Hole" + str(hole_number) + "Layout.gd"
	var hole_layout_script = load(hole_layout_path)
	
	if hole_layout_script:
		# Create an instance of the hole layout
		var hole_layout_instance = hole_layout_script.new()
		
		# Get the layout data
		var layout_data = hole_layout_instance.LAYOUT
		
		# Convert the layout to our format
		var converted_layout = _convert_layout_to_3d_format(layout_data)
		
		current_map_layout = converted_layout
		_update_hole_data()
		
		map_loaded.emit("hole_" + str(hole_number))
		print("✓ Loaded hole layout", hole_number)
		return converted_layout
	else:
		print("⚠ Could not load hole layout", hole_number, ", using fallback")
		return _create_sample_layout()

func _convert_layout_to_3d_format(layout_data: Array) -> Array:
	"""Convert the hole layout format to 3D format"""
	var converted_layout = []
	
	for y in range(layout_data.size()):
		var row = []
		for x in range(layout_data[y].size()):
			var tile_type = layout_data[y][x]
			
			# Convert tile types to our 3D format
			match tile_type:
				"Tee":  # Tee box - player start
					row.append("P")
				"F":   # Fairway
					row.append("F")
				"G":   # Green
					row.append("G")
				"R":   # Rough
					row.append("R")
				"S":   # Sand
					row.append("S")
				"W":   # Water
					row.append("W")
				"Base": # Base/grass
					row.append("B")
				_:     # Default to grass
					row.append("B")
		
		converted_layout.append(row)
	
	# Add hole at the end of the fairway (find the last green tile)
	_find_and_add_hole(converted_layout)
	
	print("✓ Converted layout size:", converted_layout.size(), "x", converted_layout[0].size() if converted_layout.size() > 0 else 0)
	return converted_layout

func _find_and_add_hole(layout: Array):
	"""Find a good spot for the hole and add it"""
	# Look for green tiles (G) near the end of the layout
	for y in range(layout.size() - 1, max(0, layout.size() - 10), -1):
		for x in range(layout[y].size()):
			if layout[y][x] == "G":
				# Check if this is a good spot (not too close to edges)
				if x > 5 and x < layout[y].size() - 5:
					layout[y][x] = "H"  # Add hole
					print("✓ Added hole at position", x, y)
					return
	
	# Fallback: add hole at center of last few rows
	var center_x = layout[0].size() / 2
	for y in range(layout.size() - 1, max(0, layout.size() - 5), -1):
		if layout[y][center_x] == "G":
			layout[y][center_x] = "H"
			print("✓ Added fallback hole at center")
			return

func _create_sample_layout() -> Array:
	"""Create a sample layout for testing"""
	var layout = []
	
	for y in range(grid_height):
		var row = []
		for x in range(grid_width):
			if x == 0 or x == grid_width - 1 or y == 0 or y == grid_height - 1:
				row.append("T")  # Trees on borders
			elif x == 25 and y == 25:
				row.append("P")  # Player start
			elif x == 45 and y == 45:
				row.append("H")  # Hole
			else:
				row.append("G")  # Grass
		layout.append(row)
	
	current_map_layout = layout
	_update_hole_data()
	
	map_loaded.emit("hole_" + str(current_hole))
	return layout

func _update_hole_data():
	"""Update hole and player start positions from current layout"""
	hole_positions.clear()
	player_start_positions.clear()
	
	for y in range(current_map_layout.size()):
		for x in range(current_map_layout[y].size()):
			var code = current_map_layout[y][x]
			match code:
				"H":  # Hole
					hole_positions.append(Vector2i(x, y))
				"P":  # Player start
					player_start_positions.append(Vector2i(x, y))

func get_pin_position() -> Vector3:
	"""Get the pin position in 3D world coordinates"""
	if hole_positions.size() > 0:
		var grid_pos = hole_positions[0]
		return _grid_to_world_position(grid_pos)
	return Vector3.ZERO

func get_hole_positions() -> Array[Vector2i]:
	"""Get all hole positions"""
	return hole_positions

func get_player_start_position() -> Vector2i:
	"""Get the player start position"""
	if player_start_positions.size() > 0:
		return player_start_positions[0]
	return Vector2i(25, 25)  # Default center position

func get_current_hole() -> int:
	"""Get current hole number"""
	return current_hole

func get_total_holes() -> int:
	"""Get total number of holes"""
	return total_holes

func _grid_to_world_position(grid_pos: Vector2i) -> Vector3:
	"""Convert grid position to 3D world position"""
	var cell_size = 48
	var world_x = grid_pos.x * cell_size - (grid_width * cell_size) / 2
	var world_z = grid_pos.y * cell_size - (grid_height * cell_size) / 2
	return Vector3(world_x, 0, world_z)

# Public API
func get_map_info() -> Dictionary:
	"""Get current map information"""
	return {
		"current_hole": current_hole,
		"total_holes": total_holes,
		"grid_size": Vector2i(grid_width, grid_height),
		"hole_positions": hole_positions,
		"player_start_positions": player_start_positions
	} 