extends Node
class_name ObjectPlacement3DManager

# ObjectPlacement3DManager - Handles proper 3D object placement rules
# Based on the 2D system's sophisticated placement logic

# Import the rules resource class
const ObjectPlacementRules = preload("res://3D/ObjectPlacementRules.gd")

signal objects_placed(object_count: int)

# Placement rules for different object types
var placement_rules = {}

# Optional rules resource
var rules_resource: ObjectPlacementRules = null

# Current placement state
var placed_objects: Array[Vector2i] = []
var current_hole: int = 1

func _ready():
	print("✓ ObjectPlacement3DManager initialized")
	
	# Try to load rules from resource file
	_load_rules_from_resource()
	
	# Set default rules if resource loading failed
	if placement_rules.is_empty():
		_set_default_rules()

func _load_rules_from_resource():
	"""Load placement rules from resource file"""
	var rules_path = "res://3D/ObjectPlacementRules.tres"
	rules_resource = load(rules_path)
	
	if rules_resource:
		placement_rules = rules_resource.get_all_rules()
		print("✓ Loaded placement rules from resource file")
	else:
		print("⚠ Could not load placement rules from resource file, using defaults")

func _set_default_rules():
	"""Set default placement rules if resource loading fails"""
	placement_rules = {
		"pin": {
			"allowed_tiles": ["G"],  # Only on green tiles
			"min_spacing": 8,
			"max_per_hole": 2,
			"avoid_tiles": ["T", "P", "W", "S"],  # Avoid trees, tees, water, sand
			"height": 1.0,
			"pixel_size": 0.08
		},
		"boulder": {
			"allowed_tiles": ["Base", "B"],  # Only on base grass tiles
			"min_spacing": 6,
			"max_per_hole": 5,
			"avoid_tiles": ["T", "P", "G", "W", "S", "F", "R"],  # Avoid all special tiles
			"height": 0.3,
			"pixel_size": 0.12
		},
		"tree": {
			"allowed_tiles": ["Base", "B"],  # Only on base grass tiles
			"min_spacing": 8,
			"max_per_hole": 10,
			"avoid_tiles": ["T", "P", "G", "W", "S", "F", "R"],  # Avoid all special tiles
			"height": 0.8,
			"pixel_size": 0.15
		}
	}
	print("✓ Set default placement rules")

func setup(hole_number: int):
	"""Setup the placement manager for a specific hole"""
	current_hole = hole_number
	placed_objects.clear()
	print("✓ ObjectPlacement3DManager setup for hole", current_hole)

func get_random_object_positions(layout: Array) -> Dictionary:
	"""Get random positions for all object types based on proper placement rules"""
	
	print("🎲 Calculating random object positions for hole", current_hole)
	
	# Set random seed for consistent placement
	randomize()
	var random_seed_value = current_hole * 1000 + randi()
	seed(random_seed_value)
	
	var positions = {
		"pins": [],
		"boulders": [],
		"trees": []
	}
	
	# Get valid positions for each object type
	var pin_positions = _get_valid_positions_for_object_type("pin", layout)
	var boulder_positions = _get_valid_positions_for_object_type("boulder", layout)
	var tree_positions = _get_valid_positions_for_object_type("tree", layout)
	
	# Place pins (1-2 per hole)
	var num_pins = randi_range(1, placement_rules.pin.max_per_hole)
	positions.pins = _place_objects_randomly("pin", pin_positions, num_pins)
	
	# Place boulders (3-5 per hole)
	var num_boulders = randi_range(3, placement_rules.boulder.max_per_hole)
	positions.boulders = _place_objects_randomly("boulder", boulder_positions, num_boulders)
	
	# Place trees (6-10 per hole)
	var num_trees = randi_range(6, placement_rules.tree.max_per_hole)
	positions.trees = _place_objects_randomly("tree", tree_positions, num_trees)
	
	print("✅ Calculated positions:", positions)
	return positions

func _get_valid_positions_for_object_type(object_type: String, layout: Array) -> Array:
	"""Get valid positions for a specific object type based on placement rules"""
	
	var rules = placement_rules[object_type]
	var valid_positions = []
	
	for y in range(layout.size()):
		for x in range(layout[y].size()):
			var pos = Vector2i(x, y)
			var tile_type = layout[y][x]
			
			# Check if tile type is allowed
			if tile_type in rules.allowed_tiles:
				# Check if position meets all placement criteria
				if _is_position_valid_for_object_type(pos, object_type, layout):
					valid_positions.append(pos)
	
	print("📊 Found", valid_positions.size(), "valid positions for", object_type)
	return valid_positions

func _is_position_valid_for_object_type(pos: Vector2i, object_type: String, layout: Array) -> bool:
	"""Check if a position is valid for a specific object type"""
	
	var rules = placement_rules[object_type]
	
	# Basic bounds checking
	if pos.y < 0 or pos.y >= layout.size() or pos.x < 0 or pos.x >= layout[0].size():
		return false
	
	# Check tile type
	var tile_type = layout[pos.y][pos.x]
	if tile_type not in rules.allowed_tiles:
		return false
	
	# Check spacing from other placed objects
	for placed_pos in placed_objects:
		var distance = max(abs(pos.x - placed_pos.x), abs(pos.y - placed_pos.y))
		if distance < rules.min_spacing:
			return false
	
	# Check for nearby tiles to avoid
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var check_x = pos.x + dx
			var check_y = pos.y + dy
			if check_x >= 0 and check_y >= 0 and check_y < layout.size() and check_x < layout[check_y].size():
				var check_tile = layout[check_y][check_x]
				if check_tile in rules.avoid_tiles:
					var dist = max(abs(dx), abs(dy))
					if dist < 2:  # Must be at least 2 tiles from avoided tiles
						return false
	
	# Special rules for specific object types
	match object_type:
		"pin":
			# Pins should be on green tiles and not too close to edges
			if pos.x < 3 or pos.x >= layout[0].size() - 3 or pos.y < 3 or pos.y >= layout.size() - 3:
				return false
		"boulder":
			# Boulders should avoid edges and be on base tiles only
			if pos.x < 2 or pos.x >= layout[0].size() - 2 or pos.y < 2 or pos.y >= layout.size() - 2:
				return false
		"tree":
			# Trees should avoid edges and be on base tiles only
			if pos.x < 2 or pos.x >= layout[0].size() - 2 or pos.y < 2 or pos.y >= layout.size() - 2:
				return false
	
	return true

func _place_objects_randomly(object_type: String, valid_positions: Array, count: int) -> Array:
	"""Place objects randomly from valid positions"""
	
	var positions = []
	var positions_to_check = valid_positions.duplicate()
	
	for i in range(count):
		if positions_to_check.size() == 0:
			break
		
		var index = randi() % positions_to_check.size()
		var pos = positions_to_check[index]
		
		# Check final spacing from other placed objects
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(pos.x - placed_pos.x), abs(pos.y - placed_pos.y))
			if distance < placement_rules[object_type].min_spacing:
				valid = false
				break
		
		if valid:
			positions.append(pos)
			placed_objects.append(pos)
		
		positions_to_check.remove_at(index)
	
	print("✅ Placed", positions.size(), object_type, "objects")
	return positions

func create_3d_object(object_type: String, grid_pos: Vector2i, obstacle_container: Node3D) -> Node3D:
	"""Create a 3D object with billboard sprite"""
	
	var rules = placement_rules[object_type]
	var world_pos = _grid_to_world_position(grid_pos)
	
	# Load appropriate texture
	var texture_path = _get_texture_path_for_object_type(object_type)
	var texture = load(texture_path)
	
	if not texture:
		print("⚠ Could not load texture for", object_type, ":", texture_path)
		return null
	
	var sprite_3d = Sprite3D.new()
	sprite_3d.texture = texture
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite_3d.pixel_size = rules.pixel_size
	sprite_3d.position = world_pos
	sprite_3d.position.y = rules.height
	
	# Add random rotation for variety
	sprite_3d.rotation_degrees.y = randf_range(0, 360)
	
	# Add metadata
	sprite_3d.set_meta("object_type", object_type)
	sprite_3d.set_meta("grid_position", grid_pos)
	sprite_3d.set_meta("is_random_object", true)
	
	obstacle_container.add_child(sprite_3d)
	print("✓ Created", object_type, "at", grid_pos)
	
	return sprite_3d

func _get_texture_path_for_object_type(object_type: String) -> String:
	"""Get the texture path for an object type"""
	match object_type:
		"pin":
			return "res://Obstacles/Pin.png"
		"boulder":
			return "res://Obstacles/Boulder.png"
		"tree":
			return "res://Obstacles/Tree.png"
		_:
			return "res://Obstacles/Tree.png"  # Default fallback

func _grid_to_world_position(grid_pos: Vector2i) -> Vector3:
	"""Convert grid position to 3D world position"""
	# Use the same coordinate system as the Course3DManager
	var tile_size = 64  # Match the tile size used in ground plane creation
	var grid_size = Vector2i(50, 50)  # Default fallback
	
	# Try to get actual layout dimensions from the course manager
	var course_manager = get_parent()
	if course_manager and course_manager.has_method("get_current_layout"):
		var layout = course_manager.get_current_layout()
		if layout.size() > 0:
			grid_size = Vector2i(layout[0].size(), layout.size())
	
	var world_x = grid_pos.x * tile_size - (grid_size.x * tile_size) / 2
	var world_z = grid_pos.y * tile_size - (grid_size.y * tile_size) / 2
	return Vector3(world_x, 0, world_z)

# Public API
func get_placement_rules() -> Dictionary:
	"""Get the current placement rules"""
	return placement_rules

func set_placement_rules(new_rules: Dictionary):
	"""Set new placement rules"""
	placement_rules = new_rules

func get_placed_objects() -> Array[Vector2i]:
	"""Get all placed object positions"""
	return placed_objects

func clear_placed_objects():
	"""Clear the placed objects list"""
	placed_objects.clear() 