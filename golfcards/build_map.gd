extends Node

func _ready():
	print("🔧 BUILD_MAP.GD LOADED!")

# Handles building the grid and map for a course

var tile_scene_map := {}
var object_scene_map := {}
var object_to_tile_mapping := {}
var cell_size: int = 48
var obstacle_layer: Node = null
var obstacle_map: Dictionary = {}
var ysort_objects: Array = []

# --- Additional variables for randomization and placement ---
var random_seed_value: int = 0
var placed_objects: Array = []
var shop_grid_pos := Vector2i(2, 6)
var current_hole: int = 0
var card_effect_handler = null
var suitcase_grid_pos := Vector2i.ZERO  # Track SuitCase position

func setup(tile_scene_map_: Dictionary, object_scene_map_: Dictionary, object_to_tile_mapping_: Dictionary, cell_size_: int, obstacle_layer_: Node, obstacle_map_: Dictionary, ysort_objects_: Array) -> void:
	tile_scene_map = tile_scene_map_
	object_scene_map = object_scene_map_
	object_to_tile_mapping = object_to_tile_mapping_
	cell_size = cell_size_
	obstacle_layer = obstacle_layer_
	obstacle_map = obstacle_map_
	ysort_objects = ysort_objects_

func build_map_from_layout(layout: Array) -> void:
	obstacle_map.clear()
	ysort_objects.clear()
	for y in layout.size():
		for x in layout[y].size():
			var code: String = layout[y][x]
			var pos: Vector2i = Vector2i(x, y)
			var world_pos: Vector2 = Vector2(x, y) * cell_size

			var tile_code: String = code
			if object_scene_map.has(code):
				tile_code = object_to_tile_mapping[code]
				var scene: PackedScene = tile_scene_map[tile_code]
				if scene == null:
					push_error("🚫 Tile scene for code '%s' is null at (%d,%d)" % [tile_code, x, y])
					continue
				var tile: Node2D = scene.instantiate() as Node2D
				if tile == null:
					push_error("❌ Tile instantiation failed for '%s' at (%d,%d)" % [tile_code, x, y])
					continue
				tile.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
				tile.z_index = -5
				var sprite: Sprite2D = tile.get_node_or_null("Sprite2D")
				if sprite and sprite.texture:
					var texture_size: Vector2 = sprite.texture.get_size()
					if texture_size.x > 0 and texture_size.y > 0:
						var scale_x = cell_size / texture_size.x
						var scale_y = cell_size / texture_size.y
						sprite.scale = Vector2(scale_x, scale_y)
				if tile.has_meta("grid_position") or "grid_position" in tile:
					tile.set("grid_position", pos)
				else:
					push_warning("⚠️ Tile missing 'grid_position'. Type: %s" % tile.get_class())
				obstacle_layer.add_child(tile)
				obstacle_map[pos] = tile
			elif not tile_scene_map.has(code):
				pass
	for y in layout.size():
		for x in layout[y].size():
			var code: String = layout[y][x]
			var pos: Vector2i = Vector2i(x, y)
			var world_pos: Vector2 = Vector2(x, y) * cell_size
			if object_scene_map.has(code):
				var scene: PackedScene = object_scene_map[code]
				if scene == null:
					push_error("🚫 Object scene for code '%s' is null at (%d,%d)" % [code, x, y])
					continue
				var object: Node2D = scene.instantiate() as Node2D
				if object == null:
					push_error("❌ Object instantiation failed for '%s' at (%d,%d)" % [code, x, y])
					continue
				object.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
				if object.has_meta("grid_position") or "grid_position" in object:
					object.set("grid_position", pos)
				else:
					push_warning("⚠️ Object missing 'grid_position'. Type: %s" % object.get_class())
				ysort_objects.append({"node": object, "grid_pos": pos})
				obstacle_layer.add_child(object)
				if object.has_method("blocks") and object.blocks():
					obstacle_map[pos] = object
			elif not tile_scene_map.has(code):
				pass
	
	# Place TreeLineVert borders
	place_treeline_vert_borders(layout)

# --- Clear all existing objects from the map ---
func clear_existing_objects() -> void:
	var objects_removed = 0
	
	# Check if obstacle_layer exists
	if not obstacle_layer:
		print("WARNING: obstacle_layer is null in clear_existing_objects()")
		return
	
	for child in obstacle_layer.get_children():
		child.queue_free()
		objects_removed += 1
	var keys_to_remove: Array = []
	for pos in obstacle_map.keys():
		var obstacle = obstacle_map[pos]
		if obstacle:
			var is_tree = obstacle.name == "Tree" or obstacle.has_method("_on_area_entered") and "Tree" in str(obstacle.get_script())
			var is_shop = obstacle.name == "Shop" or obstacle.name == "ShopExterior"
			var is_pin = false
			if obstacle.has_method("_on_area_entered"):
				var script_path = str(obstacle.get_script())
				is_pin = "Pin" in script_path or obstacle.name == "Pin" or "Pin.gd" in script_path
				if obstacle.has_signal("hole_in_one"):
					is_pin = true
			# Check for oil drums by name or script
			var is_oil_drum = obstacle.name == "OilDrum" or (obstacle.get_script() and "oil_drum.gd" in str(obstacle.get_script().get_path()))
			# Check for stone walls by name or script
			var is_stone_wall = obstacle.name == "StoneWall" or (obstacle.get_script() and "StoneWall.gd" in str(obstacle.get_script().get_path()))
			# Check for boulders by name or script
			var is_boulder = obstacle.name == "Boulder" or (obstacle.get_script() and "boulder.gd" in str(obstacle.get_script().get_path()))
			# Check for police by name or script
			var is_police = obstacle.name == "Police" or (obstacle.get_script() and "police.gd" in str(obstacle.get_script().get_path()))
			# Check for zombies by name or script
			var is_zombie = obstacle.name == "ZombieGolfer" or (obstacle.get_script() and "ZombieGolfer.gd" in str(obstacle.get_script().get_path()))
			# Check for bonfires by name or script
			var is_bonfire = obstacle.name == "Bonfire" or (obstacle.get_script() and "bonfire.gd" in str(obstacle.get_script().get_path()))
			# Check for generator switches by name or script
			var is_generator_switch = obstacle.name == "GeneratorSwitch" or (obstacle.get_script() and "generator_switch.gd" in str(obstacle.get_script().get_path()))
			
			if is_tree or is_shop or is_pin or is_oil_drum or is_stone_wall or is_boulder or is_police or is_zombie or is_bonfire or is_generator_switch:
				keys_to_remove.append(pos)
	for pos in keys_to_remove:
		obstacle_map.erase(pos)
	ysort_objects.clear()
	placed_objects.clear()

func is_valid_position_for_object(pos: Vector2i, layout: Array) -> bool:
	if pos.y < 0 or pos.y >= layout.size() or pos.x < 0 or pos.x >= layout[0].size():
		return false
	var tile_type = layout[pos.y][pos.x]
	# Only allow placement on Base tiles (basic grass), not on fairway (F) or special tiles
	if tile_type != "Base":
		return false
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var check_x = pos.x + dx
			var check_y = pos.y + dy
			if check_x >= 0 and check_y >= 0 and check_y < layout.size() and check_x < layout[check_y].size():
				if layout[check_y][check_x] == "G":
					return false
	for placed_pos in placed_objects:
		var distance = max(abs(pos.x - placed_pos.x), abs(pos.y - placed_pos.y))
		if distance < 8:
			return false
	return true

func is_valid_position_for_squirrel(pos: Vector2i, layout: Array) -> bool:
	"""Check if a position is valid for Squirrel placement (more lenient than other objects)"""
	if pos.y < 0 or pos.y >= layout.size() or pos.x < 0 or pos.x >= layout[0].size():
		return false
	var tile_type = layout[pos.y][pos.x]
	# Allow placement on base tiles, fairway (F), and rough (R), but not on special tiles
	if tile_type in ["Tee", "G", "W", "S", "P"]:
		return false
	# Don't check for green tiles nearby (Squirrels can be closer to greens)
	# Only check spacing from other placed objects
	for placed_pos in placed_objects:
		var distance = max(abs(pos.x - placed_pos.x), abs(pos.y - placed_pos.y))
		if distance < 3:  # Minimum spacing between squirrels and other objects
			return false
	return true

func is_valid_position_for_generator_strict(pos: Vector2i, layout: Array, placed_objects: Array) -> bool:
	"""Check if a position is valid for generator switch placement (strict rules)"""
	if pos.y < 0 or pos.y >= layout.size() or pos.x < 0 or pos.x >= layout[0].size():
		return false
	var tile_type = layout[pos.y][pos.x]
	# Only allow placement on Base tiles, not on special tiles
	if tile_type != "Base":
		return false
	
	# Check for minimum spacing from other placed objects
	for placed_pos in placed_objects:
		var distance = max(abs(pos.x - placed_pos.x), abs(pos.y - placed_pos.y))
		if distance < 4:  # Minimum 4 tiles from other objects
			return false
	
	# Rule 2: Must be at least 2 tiles away from trees
	# Rule 4: Must be at least 2 tiles away from tees
	for dy in range(-2, 3):  # Check 2 tiles in all directions
		for dx in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			var check_x = pos.x + dx
			var check_y = pos.y + dy
			if check_x >= 0 and check_y >= 0 and check_y < layout.size() and check_x < layout[check_y].size():
				var check_tile = layout[check_y][check_x]
				# Don't place too close to trees specifically
				if check_tile == "T":  # Tree tile
					var dist = max(abs(dx), abs(dy))
					if dist < 2:  # Must be at least 2 tiles from trees
						return false
				# Don't place too close to tees
				elif check_tile == "Tee":  # Tee tile
					var dist = max(abs(dx), abs(dy))
					if dist < 2:  # Must be at least 2 tiles from tees
						return false
				# Also avoid other obstacles
				elif check_tile in ["W", "S", "P"]:  # Water, Sand, Pin
					var dist = max(abs(dx), abs(dy))
					if dist < 3:  # Minimum 3 tiles from other obstacles
						return false
	
	return true

func is_valid_position_for_generator(pos: Vector2i, layout: Array, placed_objects: Array) -> bool:
	"""Check if a position is valid for generator switch placement (extra safety checks)"""
	if pos.y < 0 or pos.y >= layout.size() or pos.x < 0 or pos.x >= layout[0].size():
		return false
	var tile_type = layout[pos.y][pos.x]
	# Only allow placement on Base tiles, not on special tiles
	if tile_type != "Base":
		return false
	
	# Check for minimum spacing from other placed objects (extra safety)
	for placed_pos in placed_objects:
		var distance = max(abs(pos.x - placed_pos.x), abs(pos.y - placed_pos.y))
		if distance < 6:  # Larger minimum spacing for generator
			return false
	
	# Check for minimum spacing from trees, water, and other obstacles
	for dy in range(-3, 4):  # Check 3 tiles in all directions
		for dx in range(-3, 4):
			if dx == 0 and dy == 0:
				continue
			var check_x = pos.x + dx
			var check_y = pos.y + dy
			if check_x >= 0 and check_y >= 0 and check_y < layout.size() and check_x < layout[check_y].size():
				var check_tile = layout[check_y][check_x]
				# Don't place too close to trees, water, or other obstacles
				if check_tile in ["T", "W", "S", "P"]:
					var dist = max(abs(dx), abs(dy))
					if dist < 3:  # Minimum 3 tiles from obstacles
						return false
	
	return true

func find_safe_generator_position_strict(layout: Array, placed_objects: Array) -> Vector2i:
	"""Find a safe position for the generator switch using strict rules"""
	var safe_positions = []
	
	# Look for safe positions on the left side of the course
	for y in range(2, layout.size() - 2):  # Avoid edges
		for x in range(2, min(10, layout[0].size() - 2)):  # Left side, max 10 tiles from edge
			var test_pos = Vector2i(x, y)
			if is_valid_position_for_generator_strict(test_pos, layout, placed_objects):
				safe_positions.append(test_pos)
	
	if safe_positions.size() > 0:
		# Choose the leftmost safe position
		var best_pos = safe_positions[0]
		for pos in safe_positions:
			if pos.x < best_pos.x:
				best_pos = pos
		return best_pos
	
	# Ultimate fallback: middle of the course
	return Vector2i(2, layout.size() / 2)

func find_safe_generator_position(layout: Array, placed_objects: Array) -> Vector2i:
	"""Find a safe position for the generator switch on the left side of the course"""
	var left_side_positions = []
	
	# Look for safe positions on the left side of the course
	for y in range(2, layout.size() - 2):  # Avoid edges
		for x in range(2, min(8, layout[0].size() - 2)):  # Left side, max 8 tiles from edge
			var test_pos = Vector2i(x, y)
			if is_valid_position_for_generator(test_pos, layout, placed_objects):
				left_side_positions.append(test_pos)
	
	if left_side_positions.size() > 0:
		# Choose the leftmost safe position
		var best_pos = left_side_positions[0]
		for pos in left_side_positions:
			if pos.x < best_pos.x:
				best_pos = pos
		return best_pos
	
	# Ultimate fallback: middle of the course
	return Vector2i(2, layout.size() / 2)

func is_valid_position_for_bonfire(pos: Vector2i, layout: Array) -> bool:
	if pos.y < 0 or pos.y >= layout.size() or pos.x < 0 or pos.x >= layout[0].size():
		return false
	var tile_type = layout[pos.y][pos.x]
	if tile_type != "Base":
		return false

	# Require at least one rough tile within 2 tiles
	var found_rough = false
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			var check_x = pos.x + dx
			var check_y = pos.y + dy
			if check_x >= 0 and check_y >= 0 and check_y < layout.size() and check_x < layout[check_y].size():
				if layout[check_y][check_x] == "R":
					found_rough = true
					break
		if found_rough:
			break
	if not found_rough:
		return false

	# Require at least 1 tile away from other placed objects (allow adjacent)
	for placed_pos in placed_objects:
		var distance = max(abs(pos.x - placed_pos.x), abs(pos.y - placed_pos.y))
		if distance < 1:
			return false

	return true

func should_place_suitcase() -> bool:
	"""Check if SuitCase should be placed on the current hole (every 6 holes)"""
	# Place SuitCase on holes 6, 12, 18, etc. (every 6th hole)
	return (current_hole + 1) % 6 == 0

func get_valid_fairway_positions(layout: Array) -> Array:
	"""Get all valid fairway positions for SuitCase placement"""
	var fairway_positions: Array = []
	
	for y in layout.size():
		for x in layout[y].size():
			var pos = Vector2i(x, y)
			if layout[y][x] == "F":  # Fairway tile
				# Check spacing from other placed objects
				var valid = true
				for placed_pos in placed_objects:
					var distance = max(abs(pos.x - placed_pos.x), abs(pos.y - placed_pos.y))
					if distance < 4:  # Minimum 4 tiles away from other objects
						valid = false
						break
				
				if valid:
					fairway_positions.append(pos)
	
	return fairway_positions

func get_random_positions_for_objects(layout: Array, num_trees: int = 8, include_shop: bool = true, num_gang_members: int = -1, num_oil_drums: int = -1, num_police: int = -1, num_zombies: int = -1, puzzle_type: String = "score") -> Dictionary:
	var positions = {
		"trees": [],
		"shop": Vector2i.ZERO,
		"gang_members": [],
		"oil_drums": [],
		"stone_walls": [],
		"boulders": [],
		"bushes": [],
		"grass": [],
		"police": [],
		"zombies": [],
		"squirrels": [],
		"bonfires": [],
		"suitcase": Vector2i.ZERO,
		"wraiths": [],
		"generator_switches": []
	}
	
	# Use difficulty tier spawning if parameters are -1 (default)
	var npc_counts = Global.get_difficulty_tier_npc_counts(current_hole)
	
	# Apply puzzle type modifications to NPC counts
	match puzzle_type:
		"score":
			# Score puzzle: Only squirrels spawn
			num_gang_members = 0
			num_police = 0
			num_zombies = 0
			print("🎯 PUZZLE TYPE: Score puzzle - only squirrels will spawn")
			
		"mob":
			# Mob puzzle: Double the normal NPCs
			num_gang_members = npc_counts.gang_members * 2
			num_police = npc_counts.police * 2
			num_zombies = npc_counts.zombies * 2
			print("🎯 PUZZLE TYPE: Mob puzzle - doubling NPC counts")
			
		"generator", "miniboss":
			# Generator and Miniboss puzzles: Use normal difficulty tier
			print("🎯 PUZZLE TYPE: ", puzzle_type, " puzzle - using normal difficulty tier")
			
		_:
			print("🎯 PUZZLE TYPE: Unknown puzzle type '", puzzle_type, "', using default")
	
	if num_gang_members == -1:
		num_gang_members = npc_counts.gang_members
	if num_oil_drums == -1:
		num_oil_drums = Global.get_turn_based_oil_drum_count()
	if num_police == -1:
		num_police = npc_counts.police
	if num_zombies == -1:
		num_zombies = npc_counts.zombies
	
	randomize()
	random_seed_value = current_hole * 1000 + randi()
	seed(random_seed_value)
	
	# For hole 1, force shop placement near tees for testing
	if current_hole == 0 and include_shop:
		# Place shop at position (2, 4) which is near the tees at (5,5)-(7,7)
		# This puts the shop entrance at (2,4) with blocked tiles around it
		positions.shop = Vector2i(2, 4)
		placed_objects.append(positions.shop)
	
	# Get valid positions for trees and other objects
	var valid_positions: Array = []
	for y in layout.size():
		for x in layout[y].size():
			var pos = Vector2i(x, y)
			if is_valid_position_for_object(pos, layout):
				valid_positions.append(pos)
	
	# Handle shop placement for non-hole-1 cases
	if current_hole != 0 and include_shop and valid_positions.size() > 0:
		var shop_index = randi() % valid_positions.size()
		positions.shop = valid_positions[shop_index]
		placed_objects.append(positions.shop)
		valid_positions.remove_at(shop_index)
	
	var trees_placed = 0
	while trees_placed < num_trees and valid_positions.size() > 0:
		var tree_index = randi() % valid_positions.size()
		var tree_pos = valid_positions[tree_index]
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(tree_pos.x - placed_pos.x), abs(tree_pos.y - placed_pos.y))
			if distance < 8:
				valid = false
				break
		if valid:
			positions.trees.append(tree_pos)
			placed_objects.append(tree_pos)
			trees_placed += 1
		valid_positions.remove_at(tree_index)
	
	# Place Squirrels around trees (5 tiles radius, based on difficulty tier)
	var squirrels_placed = 0
	var max_squirrels = npc_counts.squirrels
	
	# Get all valid positions within 5 tiles of any tree
	var squirrel_candidate_positions: Array = []
	for tree_pos in positions.trees:
		for dy in range(-5, 6):  # -5 to +5 inclusive
			for dx in range(-5, 6):  # -5 to +5 inclusive
				var candidate_pos = tree_pos + Vector2i(dx, dy)
				
				# Check if position is within map bounds
				if candidate_pos.y < 0 or candidate_pos.y >= layout.size() or candidate_pos.x < 0 or candidate_pos.x >= layout[0].size():
					continue
				
				# Check if position is valid for Squirrel placement (more lenient than other objects)
				if is_valid_position_for_squirrel(candidate_pos, layout):
					# Check if not already in candidate list
					if candidate_pos not in squirrel_candidate_positions:
						squirrel_candidate_positions.append(candidate_pos)
	
	
	# Randomly select positions for squirrels
	while squirrels_placed < max_squirrels and squirrel_candidate_positions.size() > 0:
		var squirrel_index = randi() % squirrel_candidate_positions.size()
		var squirrel_pos = squirrel_candidate_positions[squirrel_index]
		
		# Check spacing from other placed objects
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(squirrel_pos.x - placed_pos.x), abs(squirrel_pos.y - placed_pos.y))
			if distance < 3:  # Minimum spacing between squirrels and other objects
				valid = false
				break
		
		if valid:
			positions.squirrels.append(squirrel_pos)
			placed_objects.append(squirrel_pos)
			squirrels_placed += 1
		
		squirrel_candidate_positions.remove_at(squirrel_index)
	
	# Place Boulders on remaining base tiles (after trees)
	var num_boulders = 4  # Place 4 boulders per hole
	var boulders_placed = 0
	while boulders_placed < num_boulders and valid_positions.size() > 0:
		var boulder_index = randi() % valid_positions.size()
		var boulder_pos = valid_positions[boulder_index]
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(boulder_pos.x - placed_pos.x), abs(boulder_pos.y - placed_pos.y))
			if distance < 6:  # Slightly closer spacing than trees
				valid = false
				break
		if valid:
			positions.boulders.append(boulder_pos)
			placed_objects.append(boulder_pos)
			boulders_placed += 1
		valid_positions.remove_at(boulder_index)
	
	# Place Generator Switches on fairway tiles (for testing, just place 1 on hole 1)
	var num_generator_switches = 1 if current_hole == 0 else 0  # Only place 1 on hole 1 for testing
	var generator_switches_placed = 0
	
	# Get fairway positions for generator switches
	var generator_fairway_positions: Array = []
	for y in layout.size():
		for x in layout[y].size():
			if layout[y][x] == "F":  # Fairway tiles
				generator_fairway_positions.append(Vector2i(x, y))
	
	while generator_switches_placed < num_generator_switches and generator_fairway_positions.size() > 0:
		var generator_index = randi() % generator_fairway_positions.size()
		var generator_pos = generator_fairway_positions[generator_index]
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(generator_pos.x - placed_pos.x), abs(generator_pos.y - placed_pos.y))
			if distance < 8:  # Same spacing as trees
				valid = false
				break
		if valid:
			positions.generator_switches.append(generator_pos)
			placed_objects.append(generator_pos)
			generator_switches_placed += 1
		generator_fairway_positions.remove_at(generator_index)
	
	# Generator puzzle configuration - triggered by puzzle type
	if puzzle_type == "generator":
		# Find fairway positions to create a proper barrier
		var fairway_positions: Array = []
		for y in layout.size():
			for x in layout[y].size():
				if layout[y][x] == "F":  # Fairway tile
					fairway_positions.append(Vector2i(x, y))
		
		# Find tee positions for generator placement
		var tee_positions: Array = []
		for y in layout.size():
			for x in layout[y].size():
				if layout[y][x] == "Tee":  # Tee tile
					tee_positions.append(Vector2i(x, y))
		
		# Dynamically calculate generator position using specific rules
		var generator_pos = Vector2i.ZERO
		if tee_positions.size() > 0:
			# Find the topmost tee position (highest Y value = top of screen)
			var top_tee = tee_positions[0]
			for tee_pos in tee_positions:
				if tee_pos.y < top_tee.y:  # Lower Y = higher on screen
					top_tee = tee_pos
			
			# Rule 1: Generator must be on a row above the top tee row
			var target_row = top_tee.y - 1  # One row above the top tee
			
			# Calculate the middle column of the fairway for pylon placement reference
			var fairway_middle_x = 0
			if fairway_positions.size() > 0:
				var min_x = fairway_positions[0].x
				var max_x = fairway_positions[0].x
				for pos in fairway_positions:
					min_x = min(min_x, pos.x)
					max_x = max(max_x, pos.x)
				fairway_middle_x = (min_x + max_x) / 2
			else:
				fairway_middle_x = layout[0].size() / 2
			
			# Rule 2: Must be at least 2 tiles away from trees
			# Rule 3: Must be on the LEFT side of the fairway (tee side)
			var potential_positions = []
			var max_generator_x = fairway_middle_x - 2  # Must be left of fairway middle
			
			for x in range(2, max_generator_x):  # Only check positions left of fairway middle
				var test_pos = Vector2i(x, target_row)
				if is_valid_position_for_generator_strict(test_pos, layout, placed_objects):
					potential_positions.append(test_pos)
			
			if potential_positions.size() > 0:
				# Choose the rightmost position among valid positions (closest to fairway but still on tee side)
				generator_pos = potential_positions[0]
				for pos in potential_positions:
					if pos.x > generator_pos.x:
						generator_pos = pos
			else:
				# Try the row above that if no valid positions found
				target_row = top_tee.y - 2
				for x in range(2, max_generator_x):
					var test_pos = Vector2i(x, target_row)
					if is_valid_position_for_generator_strict(test_pos, layout, placed_objects):
						potential_positions.append(test_pos)
				
				if potential_positions.size() > 0:
					generator_pos = potential_positions[0]
					for pos in potential_positions:
						if pos.x > generator_pos.x:
							generator_pos = pos
				else:
					# Ultimate fallback: find any safe position on the left side
					generator_pos = find_safe_generator_position_strict(layout, placed_objects)
		else:
			# Fallback: find any safe position
			generator_pos = find_safe_generator_position_strict(layout, placed_objects)
		
		# Dynamically calculate pylon positions to create a vertical barrier
		var pylon_positions: Array = []
		
		if fairway_positions.size() > 0:
			# For angled fairways, we need to find strategic points along the fairway path
			# Find the middle of the fairway horizontally
			var min_x = fairway_positions[0].x
			var max_x = fairway_positions[0].x
			for pos in fairway_positions:
				min_x = min(min_x, pos.x)
				max_x = max(max_x, pos.x)
			
			var middle_x = (min_x + max_x) / 2
			
			# Find the vertical range of the fairway
			var min_y = fairway_positions[0].y
			var max_y = fairway_positions[0].y
			for pos in fairway_positions:
				min_y = min(min_y, pos.y)
				max_y = max(max_y, pos.y)
			
			# For angled fairways, find the actual fairway positions at the middle X coordinate
			# Use a wider range to account for angled fairways
			var fairway_at_middle_x: Array = []
			for pos in fairway_positions:
				# Check if position is within 2 tiles of the middle X (for angled fairways)
				if abs(pos.x - middle_x) <= 2:
					fairway_at_middle_x.append(pos)
			
			# If we found fairway positions near the middle X, use those for pylon placement
			if fairway_at_middle_x.size() > 0:
				var min_fairway_y = fairway_at_middle_x[0].y
				var max_fairway_y = fairway_at_middle_x[0].y
				for pos in fairway_at_middle_x:
					min_fairway_y = min(min_fairway_y, pos.y)
					max_fairway_y = max(max_fairway_y, pos.y)
				
				# Place pylons above and below the fairway at the middle column
				var pylon1_y = max(1, min_fairway_y - 2)  # Above fairway
				var pylon2_y = min(layout.size() - 2, max_fairway_y + 2)  # Below fairway
				
				pylon_positions.append(Vector2i(middle_x, pylon1_y))
				pylon_positions.append(Vector2i(middle_x, pylon2_y))
			else:
				# Fallback: use the original logic for straight fairways
				var pylon1_y = max(1, min_y - 2)  # Above fairway
				var pylon2_y = min(layout.size() - 2, max_y + 2)  # Below fairway
				
				pylon_positions.append(Vector2i(middle_x, pylon1_y))
				pylon_positions.append(Vector2i(middle_x, pylon2_y))
		else:
			# Fallback: place pylons in the middle of the course
			var middle_x = layout[0].size() / 2
			pylon_positions.append(Vector2i(middle_x, 2))
			pylon_positions.append(Vector2i(middle_x, layout.size() - 3))
		
		positions["generator_puzzle"] = {
			"generator_pos": generator_pos,
			"pylon_positions": pylon_positions
		}
		print("🔧 RANDOM PLACEMENT: Added generator_puzzle data for current hole")
		print("  - Generator at:", generator_pos)
		print("  - Pylons at:", pylon_positions)
	
	# Place Bushes on remaining base tiles (after boulders)
	var num_bushes = 6  # Place 6 bushes per hole
	var bushes_placed = 0
	while bushes_placed < num_bushes and valid_positions.size() > 0:
		var bush_index = randi() % valid_positions.size()
		var bush_pos = valid_positions[bush_index]
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(bush_pos.x - placed_pos.x), abs(bush_pos.y - placed_pos.y))
			if distance < 4:  # Closer spacing than boulders
				valid = false
				break
		if valid:
			positions.bushes.append(bush_pos)
			placed_objects.append(bush_pos)
			bushes_placed += 1
		valid_positions.remove_at(bush_index)
	
	# Place Grass ONLY on base tiles that are adjacent to rough tiles (transition zones)
	# PERFORMANCE: Adjust this number based on desired density vs performance
	var num_grass = 30  # Place 30 grass patches per hole (moderate performance impact)
	# Options: 8-12 (very performant), 15-20 (performant), 25-30 (moderate), 50+ (may impact performance)
	
	# Find ONLY base tiles that are adjacent to rough tiles
	var rough_adjacent_positions: Array = []
	
	for pos in valid_positions:
		var is_adjacent_to_rough = false
		# Check all 8 adjacent tiles (including diagonals)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue  # Skip the current tile
				var check_pos = pos + Vector2i(dx, dy)
				# Check if the adjacent position is within map bounds
				if check_pos.y >= 0 and check_pos.y < layout.size() and check_pos.x >= 0 and check_pos.x < layout[0].size():
					if layout[check_pos.y][check_pos.x] == "R":  # Rough tile
						is_adjacent_to_rough = true
						break
			if is_adjacent_to_rough:
				break
		
		if is_adjacent_to_rough:
			rough_adjacent_positions.append(pos)
	
	# Place grass ONLY on rough-adjacent tiles
	var grass_placed = 0
	var positions_to_check = rough_adjacent_positions.duplicate()  # Only rough-adjacent tiles
	
	while grass_placed < num_grass and positions_to_check.size() > 0:
		var grass_index = randi() % positions_to_check.size()
		var grass_pos = positions_to_check[grass_index]
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(grass_pos.x - placed_pos.x), abs(grass_pos.y - placed_pos.y))
			if distance < 3:  # Closer spacing than bushes for more grass coverage
				valid = false
				break
		if valid:
			positions.grass.append(grass_pos)
			placed_objects.append(grass_pos)
			grass_placed += 1
		positions_to_check.remove_at(grass_index)
	
	# Place GangMembers on green tiles
	var green_positions: Array = []
	for y in layout.size():
		for x in layout[y].size():
			if layout[y][x] == "G":
				green_positions.append(Vector2i(x, y))
	var gang_members_placed = 0
	while gang_members_placed < num_gang_members and green_positions.size() > 0:
		var gang_index = randi() % green_positions.size()
		var gang_pos = green_positions[gang_index]
		positions.gang_members.append(gang_pos)
		placed_objects.append(gang_pos)
		gang_members_placed += 1
		green_positions.remove_at(gang_index)
	
	# Place Police on rough tiles (R)
	var rough_positions: Array = []
	for y in layout.size():
		for x in layout[y].size():
			if layout[y][x] == "R":
				rough_positions.append(Vector2i(x, y))
	var police_placed = 0
	while police_placed < num_police and rough_positions.size() > 0:
		var police_index = randi() % rough_positions.size()
		var police_pos = rough_positions[police_index]
		positions.police.append(police_pos)
		placed_objects.append(police_pos)
		police_placed += 1
		rough_positions.remove_at(police_index)
	
	# Place Zombies on sand tiles (S)
	var sand_positions: Array = []
	for y in layout.size():
		for x in layout[y].size():
			if layout[y][x] == "S":
				sand_positions.append(Vector2i(x, y))
	var zombies_placed = 0
	while zombies_placed < num_zombies and sand_positions.size() > 0:
		var zombie_index = randi() % sand_positions.size()
		var zombie_pos = sand_positions[zombie_index]
		positions.zombies.append(zombie_pos)
		placed_objects.append(zombie_pos)
		zombies_placed += 1
		sand_positions.remove_at(zombie_index)
	
	# Place Wraith on green tiles for holes 9 and 18 (boss encounters)
	var wraith_green_positions = green_positions.duplicate()
	var num_wraiths = npc_counts.wraiths if "wraiths" in npc_counts else 0
	if num_wraiths > 0:
		var wraiths_placed = 0
		while wraiths_placed < num_wraiths and wraith_green_positions.size() > 0:
			var wraith_index = randi() % wraith_green_positions.size()
			var wraith_pos = wraith_green_positions[wraith_index]
			positions.wraiths.append(wraith_pos)
			placed_objects.append(wraith_pos)
			wraiths_placed += 1
			wraith_green_positions.remove_at(wraith_index)
	
	# Place Oil Drums on fairway tiles
	var fairway_positions: Array = []
	for y in layout.size():
		for x in layout[y].size():
			if layout[y][x] == "F":
				fairway_positions.append(Vector2i(x, y))
	var oil_drums_placed = 0
	while oil_drums_placed < num_oil_drums and fairway_positions.size() > 0:
		var oil_index = randi() % fairway_positions.size()
		var oil_pos = fairway_positions[oil_index]
		
		# Check spacing from other placed objects
		var valid = true
		for placed_pos in placed_objects:
			var distance = max(abs(oil_pos.x - placed_pos.x), abs(oil_pos.y - placed_pos.y))
			if distance < 6:  # Slightly closer spacing than trees
				valid = false
				break
		
		if valid:
			positions.oil_drums.append(oil_pos)
			placed_objects.append(oil_pos)
			oil_drums_placed += 1
		
		fairway_positions.remove_at(oil_index)
	
	# Place SuitCase on fairway tiles (every 6 holes)
	if should_place_suitcase():
		var suitcase_fairway_positions = get_valid_fairway_positions(layout)
		
		if suitcase_fairway_positions.size() > 0:
			var suitcase_index = randi() % suitcase_fairway_positions.size()
			positions.suitcase = suitcase_fairway_positions[suitcase_index]
			placed_objects.append(positions.suitcase)
	
	# Place Stone Walls around map edges (only top and bottom, every other tile to prevent overlap)
	var edge_positions: Array = []
	var layout_width = layout[0].size()
	var layout_height = layout.size()
	
	# Add top edge only, every other tile to prevent overlap
	for x in range(0, layout_width, 2):  # Step by 2 to place every other tile
		# Top edge
		if layout[0][x] != "W":  # Don't place on water
			edge_positions.append(Vector2i(x, 0))
	
	# Add stone walls to edge positions
	for wall_pos in edge_positions:
		positions.stone_walls.append(wall_pos)
		placed_objects.append(wall_pos)
	
	# Place Bonfires every other hole (hole 2, 4, 6, 8, etc.)
	if (current_hole + 1) % 2 == 0:  # Even holes (2, 4, 6, 8, etc.)
		var bonfire_candidate_positions: Array = []
		for y in layout.size():
			for x in layout[y].size():
				var pos = Vector2i(x, y)
				if is_valid_position_for_bonfire(pos, layout):
					bonfire_candidate_positions.append(pos)
		
		if bonfire_candidate_positions.size() > 0:
			var bonfire_index = randi() % bonfire_candidate_positions.size()
			var bonfire_pos = bonfire_candidate_positions[bonfire_index]
			
			var valid = true
			for placed_pos in placed_objects:
				var distance = max(abs(bonfire_pos.x - placed_pos.x), abs(bonfire_pos.y - placed_pos.y))
				if distance < 1:  # Allow adjacent placement (minimum 1 tile away)
					valid = false
					break
			
			if valid:
				positions.bonfires.append(bonfire_pos)
				placed_objects.append(bonfire_pos)
	
	# Miniboss puzzle configuration - triggered by puzzle type
	if puzzle_type == "miniboss":
		print("🗡️ MINIBOSS PUZZLE: Setting up miniboss puzzle for hole", current_hole + 1)
		
		# Find fairway positions for miniboss placement
		var miniboss_fairway_positions: Array = []
		for y in layout.size():
			for x in layout[y].size():
				if layout[y][x] == "F":  # Fairway tile
					miniboss_fairway_positions.append(Vector2i(x, y))
		
		if miniboss_fairway_positions.size() > 0:
			# Place miniboss on a fairway tile (not too close to pin)
			var miniboss_pos = Vector2i.ZERO
			var valid_miniboss_positions: Array = []
			
			for fairway_pos in miniboss_fairway_positions:
				var valid = true
				# Check spacing from other placed objects
				for placed_pos in placed_objects:
					var distance = max(abs(fairway_pos.x - placed_pos.x), abs(fairway_pos.y - placed_pos.y))
					if distance < 4:  # Minimum 4 tiles away from other objects
						valid = false
						break
				
				# Check distance from any green tile (don't place too close to potential pin areas)
				if valid:
					var too_close_to_green = false
					for y in layout.size():
						for x in layout[y].size():
							if layout[y][x] == "G":  # Green tile
								var distance_to_green = max(abs(fairway_pos.x - x), abs(fairway_pos.y - y))
								if distance_to_green < 3:  # At least 3 tiles from any green
									too_close_to_green = true
									break
						if too_close_to_green:
							break
					if too_close_to_green:
						valid = false
				
				if valid:
					valid_miniboss_positions.append(fairway_pos)
			
			if valid_miniboss_positions.size() > 0:
				# Choose a random valid position for miniboss
				var miniboss_index = randi() % valid_miniboss_positions.size()
				miniboss_pos = valid_miniboss_positions[miniboss_index]
				
				positions["miniboss_puzzle"] = {
					"miniboss_pos": miniboss_pos
				}
				
				print("🗡️ MINIBOSS PUZZLE: Miniboss at", miniboss_pos, "Dome will be placed at actual pin position")
			else:
				print("❌ MINIBOSS PUZZLE: No valid miniboss positions found")
		else:
			print("❌ MINIBOSS PUZZLE: No fairway or pin positions found")
	
	return positions

func place_treeline_vert_borders(layout: Array) -> void:
	"""Place TreeLineVert scene on the left border of the map"""
	# Load the TreeLineVert scene
	var treeline_scene = load("res://Backgrounds/TreeLineVert.tscn")
	if not treeline_scene:
		push_error("🚫 TreeLineVert scene not found")
		return
	
	# Calculate map dimensions
	var layout_width = layout[0].size()
	var layout_height = layout.size()
	var map_width = layout_width * cell_size
	var map_height = layout_height * cell_size
	
	# Create left border TreeLineVert
	var left_treeline = treeline_scene.instantiate() as Node2D
	if not left_treeline:
		push_error("❌ Failed to instantiate left TreeLineVert scene")
		return
	
	left_treeline.z_index = 5  # Higher z-index to appear in front of map tiles (-5)
	left_treeline.position = Vector2(-cell_size, map_height / 2)  # Left edge, centered vertically
	
	# Add to obstacle layer
	obstacle_layer.add_child(left_treeline)
	
	print("✓ TreeLineVert border placed - Left at (-48, ", map_height / 2, ")")
	print("✓ Using TreeLineVert.tscn scene file for better alignment control")

func build_map_from_layout_with_randomization(layout: Array, hole_index: int = -1, puzzle_type: String = "score") -> void:
	# Update current_hole if hole_index is provided
	if hole_index >= 0:
		current_hole = hole_index
	
	print("🎯 PUZZLE TYPE: Building map with puzzle type '", puzzle_type, "' for hole", current_hole + 1)
	
	randomize()
	clear_existing_objects()
	build_map_from_layout_base(layout)
	
	# Apply puzzle type-specific logic
	apply_puzzle_type_configuration(puzzle_type)
	
	# Use difficulty tier spawning (-1 means use difficulty tier calculation)
	var object_positions = get_random_positions_for_objects(layout, 8, true, -1, -1, -1, -1, puzzle_type)
	place_objects_at_positions(object_positions, layout)
	# Place TreeLineVert borders
	place_treeline_vert_borders(layout)
	# position_camera_on_pin()  # This should be called from the main scene if needed

func apply_puzzle_type_configuration(puzzle_type: String) -> void:
	"""Apply puzzle type-specific configuration to the current hole"""
	
	print("🎯 PUZZLE TYPE: Applying configuration for '", puzzle_type, "'")
	
	match puzzle_type:
		"score":
			# Score puzzle: Only squirrels spawn (handled by normal difficulty tier)
			print("🎯 PUZZLE TYPE: Score puzzle - standard difficulty tier spawning")
			
		"generator":
			# Generator puzzle: Force generator puzzle on this hole
			print("🎯 PUZZLE TYPE: Generator puzzle - will be applied during object placement")
			# The generator puzzle logic is already in get_random_positions_for_objects
			# We just need to ensure it's triggered for this hole
			
		"mob":
			# Mob puzzle: Double the normal NPCs
			print("🎯 PUZZLE TYPE: Mob puzzle - doubling NPC counts")
			# This will be handled by modifying the difficulty tier calculation
			
		"miniboss":
			# Miniboss puzzle: Force miniboss puzzle on this hole
			print("🎯 PUZZLE TYPE: Miniboss puzzle - will be applied during object placement")
			# The miniboss puzzle logic is already in get_random_positions_for_objects
			# We just need to ensure it's triggered for this hole
			
		_:
			print("🎯 PUZZLE TYPE: Unknown puzzle type '", puzzle_type, "', using default")

func build_map_from_layout_base(layout: Array, place_pin: bool = true) -> void:
	obstacle_map.clear()
	for y in layout.size():
		for x in layout[y].size():
			var code: String = layout[y][x]
			var pos: Vector2i = Vector2i(x, y)
			var world_pos: Vector2 = Vector2(x, y) * cell_size
			var tile_code: String = code
			if object_scene_map.has(code) and code != "P":
				tile_code = object_to_tile_mapping[code]
			if tile_scene_map.has(tile_code):
				var scene: PackedScene = tile_scene_map[tile_code]
				if scene == null:
					push_error("🚫 Tile scene for code '%s' is null at (%d,%d)" % [tile_code, x, y])
					continue
				var tile: Node2D = scene.instantiate() as Node2D
				if tile == null:
					push_error("❌ Tile instantiation failed for '%s' at (%d,%d)" % [tile_code, x, y])
					continue
				tile.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
				tile.z_index = -5
				var sprite: Sprite2D = tile.get_node_or_null("Sprite2D")
				if sprite and sprite.texture:
					var texture_size: Vector2 = sprite.texture.get_size()
					if texture_size.x > 0 and texture_size.y > 0:
						var scale_x = cell_size / texture_size.x
						var scale_y = cell_size / texture_size.y
						sprite.scale = Vector2(scale_x, scale_y)
				if tile.has_meta("grid_position") or "grid_position" in tile:
					tile.set("grid_position", pos)
				else:
					push_warning("⚠️ Tile missing 'grid_position'. Type: %s" % tile.get_class())
				obstacle_layer.add_child(tile)
				obstacle_map[pos] = tile
			else:
				pass
	if place_pin:
		randomize()
		random_seed_value = current_hole * 1000 + randi()
		seed(random_seed_value)
		var green_positions: Array = []
		var green_inner_positions: Array = []
		for y in layout.size():
			for x in layout[y].size():
				if layout[y][x] == "G":
					green_positions.append(Vector2i(x, y))
		for pos in green_positions:
			var x = pos.x
			var y = pos.y
			var is_edge = false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx = x + dx
					var ny = y + dy
					if nx < 0 or ny < 0 or ny >= layout.size() or nx >= layout[ny].size():
						is_edge = true
					elif layout[ny][nx] != "G":
						is_edge = true
			if not is_edge:
				green_inner_positions.append(pos)
		var pin_pos = Vector2i.ZERO
		if green_inner_positions.size() > 0:
			pin_pos = green_inner_positions[randi() % green_inner_positions.size()]
		elif green_positions.size() > 0:
			pin_pos = green_positions[randi() % green_positions.size()]
		else:
			for y in layout.size():
				for x in layout[y].size():
					if layout[y][x] == "G":
						pin_pos = Vector2i(x, y)
						break
				if pin_pos != Vector2i.ZERO:
					break
		if pin_pos != Vector2i.ZERO:
			var world_pos: Vector2 = Vector2(pin_pos.x, pin_pos.y) * cell_size
			var scene: PackedScene = object_scene_map["P"]
			if scene != null:
				var pin: Node2D = scene.instantiate() as Node2D
				pin.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
				# Let the global Y-sort system handle z_index
				if pin.has_meta("grid_position") or "grid_position" in pin:
					pin.set("grid_position", pin_pos)
				pin.set_meta("card_effect_handler", card_effect_handler)
				
				# Add pin to groups for smart optimization
				pin.add_to_group("pins")
				pin.add_to_group("collision_objects")
				
				obstacle_layer.add_child(pin)
				# Set the name AFTER adding to scene to prevent Godot from renaming it
				pin.name = "Pin" + str(current_hole + 1)
				# Connect pin signals
				if pin.has_signal("hole_in_one"):
					# Disconnect any existing connections first
					if pin.hole_in_one.get_connections().size() > 0:
						for conn in pin.hole_in_one.get_connections():
							pin.hole_in_one.disconnect(conn.callable)
					
					# Connect directly to parent's method
					if get_parent() and get_parent().has_method("_on_hole_in_one"):
						pin.hole_in_one.connect(Callable(get_parent(), "_on_hole_in_one"))
				if pin.has_signal("pin_flag_hit"):
					pin.pin_flag_hit.connect(_on_pin_flag_hit)
				if pin.has_signal("gimme_triggered"):
					# Connect gimme signal to parent's method
					if get_parent() and get_parent().has_method("_on_gimme_triggered"):
						pin.gimme_triggered.connect(Callable(get_parent(), "_on_gimme_triggered"))
				if pin.has_signal("gimme_ball_exited"):
					# Connect gimme ball exited signal to parent's method
					if get_parent() and get_parent().has_method("_on_gimme_ball_exited"):
						pin.gimme_ball_exited.connect(Callable(get_parent(), "_on_gimme_ball_exited"))
				ysort_objects.append({"node": pin, "grid_pos": pin_pos})
				update_all_ysort_z_indices()
				
				# Set the global pin position for gimme mechanic
				Global.saved_pin_position = pin_pos
				print("Pin placed at grid position:", pin_pos, " - Global.saved_pin_position set to:", Global.saved_pin_position)

func place_objects_at_positions(object_positions: Dictionary, layout: Array) -> void:
	"""Place objects at specific positions on the map"""
	
	print("🔧 PLACE_OBJECTS_AT_POSITIONS CALLED!")
	print("🔍 Object positions keys:", object_positions.keys())
	print("🔍 Object positions size:", object_positions.size())
	
	# Get TreeManager for random tree variations
	var tree_manager = get_node_or_null("/root/TreeManager")
	if not tree_manager:
		# Create TreeManager if it doesn't exist
		var TreeManager = preload("res://Obstacles/TreeManager.gd")
		tree_manager = TreeManager.new()
		get_tree().root.add_child(tree_manager)
		tree_manager.name = "TreeManager"
	
	for tree_pos in object_positions.trees:
		var scene: PackedScene = object_scene_map["T"]
		if scene == null:
			push_error("🚫 Tree scene is null")
			continue
		var tree: Node2D = scene.instantiate() as Node2D
		if tree == null:
			push_error("❌ Tree instantiation failed at (%d,%d)" % [tree_pos.x, tree_pos.y])
			continue
		
		# Apply random tree variation
		var tree_data = tree_manager.get_random_tree_data()
		if tree_data and tree.has_method("set_tree_data"):
			tree.set_tree_data(tree_data)
		elif tree_data and "tree_data" in tree:
			tree.tree_data = tree_data
		
		var world_pos: Vector2 = Vector2(tree_pos.x, tree_pos.y) * cell_size
		tree.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		if tree.has_meta("grid_position") or "grid_position" in tree:
			tree.set("grid_position", tree_pos)
		else:
			push_warning("⚠️ Tree missing 'grid_position'. Type: %s" % tree.get_class())
		
		# Add tree to groups for smart optimization
		tree.add_to_group("trees")
		tree.add_to_group("collision_objects")
		
		ysort_objects.append({"node": tree, "grid_pos": tree_pos})
		obstacle_layer.add_child(tree)
		if tree.has_method("blocks") and tree.blocks():
			obstacle_map[tree_pos] = tree
	
	# Place Boulders
	for boulder_pos in object_positions.boulders:
		var scene: PackedScene = object_scene_map["BOULDER"]
		if scene == null:
			push_error("🚫 Boulder scene is null")
			continue
		var boulder: Node2D = scene.instantiate() as Node2D
		if boulder == null:
			push_error("❌ Boulder instantiation failed at (%d,%d)" % [boulder_pos.x, boulder_pos.y])
			continue
		var world_pos: Vector2 = Vector2(boulder_pos.x, boulder_pos.y) * cell_size
		boulder.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Always set the grid_position property unconditionally
		boulder.set_meta("grid_position", boulder_pos)
		
		# Add boulder to groups for smart optimization
		boulder.add_to_group("boulders")
		boulder.add_to_group("collision_objects")
		
		ysort_objects.append({"node": boulder, "grid_pos": boulder_pos})
		obstacle_layer.add_child(boulder)
	
	# Place Generator Switches
	for generator_pos in object_positions.generator_switches:
		var scene: PackedScene = object_scene_map["GENERATOR"]
		if scene == null:
			push_error("🚫 GeneratorSwitch scene is null")
			continue
		var generator_switch: Node2D = scene.instantiate() as Node2D
		if generator_switch == null:
			push_error("❌ GeneratorSwitch instantiation failed at (%d,%d)" % [generator_pos.x, generator_pos.y])
			continue
		var world_pos: Vector2 = Vector2(generator_pos.x, generator_pos.y) * cell_size
		generator_switch.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Always set the grid_position property unconditionally
		generator_switch.set_meta("grid_position", generator_pos)
		
		# Add generator switch to groups for smart optimization
		generator_switch.add_to_group("generator_switches")
		generator_switch.add_to_group("collision_objects")
		
		ysort_objects.append({"node": generator_switch, "grid_pos": generator_pos})
		obstacle_layer.add_child(generator_switch)
	
	# Place Bushes
	
	# Get BushManager for random bush variations
	var bush_manager = get_node_or_null("/root/BushManager")
	if not bush_manager:
		# Create BushManager if it doesn't exist
		var BushManager = preload("res://Obstacles/BushManager.gd")
		bush_manager = BushManager.new()
		get_tree().root.add_child(bush_manager)
		bush_manager.name = "BushManager"
	
	for bush_pos in object_positions.bushes:
		var scene: PackedScene = object_scene_map["BUSH"]
		if scene == null:
			push_error("🚫 Bush scene is null")
			continue
		var bush: Node2D = scene.instantiate() as Node2D
		if bush == null:
			push_error("❌ Bush instantiation failed at (%d,%d)" % [bush_pos.x, bush_pos.y])
			continue
		if bush.get_script():
			pass
		else:
			push_error("❌ Bush script is null!")
		
		# Store bush data for later application (after adding to scene tree)
		var bush_data = bush_manager.get_random_bush_data()
		
		var world_pos: Vector2 = Vector2(bush_pos.x, bush_pos.y) * cell_size
		bush.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Always set the grid_position property unconditionally
		bush.set_meta("grid_position", bush_pos)
		
		# Add bush to groups for smart optimization
		bush.add_to_group("bushes")
		bush.add_to_group("collision_objects")
		
		# Verify Area2D collision layers
		
		ysort_objects.append({"node": bush, "grid_pos": bush_pos})
		obstacle_layer.add_child(bush)
		
		# Apply bush variety after adding to scene tree
		if bush_data:
			# Use call_deferred to ensure the bush is fully in the scene tree
			bush.call_deferred("set_bush_data", bush_data)
		else:
			push_error("❌ No bush data available")
	
	# Place Grass
	
	# Get GrassManager for random grass variations
	var grass_manager = get_node_or_null("/root/GrassManager")
	if not grass_manager:
		# Create GrassManager if it doesn't exist
		var GrassManager = preload("res://Obstacles/GrassManager.gd")
		grass_manager = GrassManager.new()
		get_tree().root.add_child(grass_manager)
		grass_manager.name = "GrassManager"
	
	for grass_pos in object_positions.grass:
		var scene: PackedScene = object_scene_map["GRASS"]
		if scene == null:
			push_error("🚫 Grass scene is null")
			continue
		var grass: Node2D = scene.instantiate() as Node2D
		if grass == null:
			push_error("❌ Grass instantiation failed at (%d,%d)" % [grass_pos.x, grass_pos.y])
			continue
		
		# Store grass data for later application (after adding to scene tree)
		var grass_data = grass_manager.get_random_grass_data()
		
		var world_pos: Vector2 = Vector2(grass_pos.x, grass_pos.y) * cell_size
		grass.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Always set the grid_position property unconditionally
		grass.set_meta("grid_position", grass_pos)
		
		# Add grass to groups for smart optimization
		grass.add_to_group("grass_elements")
		grass.add_to_group("visual_objects")
		
		ysort_objects.append({"node": grass, "grid_pos": grass_pos})
		obstacle_layer.add_child(grass)
		
		# Apply grass variety after adding to scene tree
		if grass_data:
			# Use call_deferred to ensure the grass is fully in the scene tree
			grass.call_deferred("set_grass_data", grass_data)
	
	if object_positions.shop != Vector2i.ZERO:
		var scene: PackedScene = object_scene_map["SHOP"]
		if scene == null:
			push_error("🚫 Shop scene is null")
		else:
			var shop: Node2D = scene.instantiate() as Node2D
			if shop == null:
				push_error("❌ Shop instantiation failed at (%d,%d)" % [object_positions.shop.x, object_positions.shop.y])
			else:
				var world_pos: Vector2 = Vector2(object_positions.shop.x, object_positions.shop.y) * cell_size
				shop.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
				if shop.has_meta("grid_position") or "grid_position" in shop:
					shop.set("grid_position", object_positions.shop)
				
				# Add shop to groups for smart optimization
				shop.add_to_group("rectangular_obstacles")
				shop.add_to_group("collision_objects")
				
				ysort_objects.append({"node": shop, "grid_pos": object_positions.shop})
				obstacle_layer.add_child(shop)
				shop_grid_pos = object_positions.shop
				
				# Place InvisibleBlockers around the shop entrance
				# 1 blocked tile to the left of entrance
				var left_of_shop_pos = object_positions.shop + Vector2i(-1, 0)
				# 3 blocked tiles to the right of entrance
				var right1_of_shop_pos = object_positions.shop + Vector2i(1, 0)
				var right2_of_shop_pos = object_positions.shop + Vector2i(2, 0)
				var right3_of_shop_pos = object_positions.shop + Vector2i(3, 0)
				
				# Create and place blockers in the shop row only
				var blocker_positions = [left_of_shop_pos, right1_of_shop_pos, right2_of_shop_pos, right3_of_shop_pos]
				var blocker_scene = preload("res://Obstacles/InvisibleBlocker.tscn")
				
				for blocker_pos in blocker_positions:
					var blocker = blocker_scene.instantiate()
					var blocker_world_pos = Vector2(blocker_pos.x, blocker_pos.y) * cell_size
					blocker.position = blocker_world_pos + Vector2(cell_size / 2, cell_size / 2)
					
					# Set the blocker's grid position metadata
					blocker.set_meta("grid_position", blocker_pos)
					
					# Add blocker to groups for consistency
					blocker.add_to_group("obstacles")
					blocker.add_to_group("collision_objects")
					
					obstacle_layer.add_child(blocker)
					obstacle_map[blocker_pos] = blocker
	
	# Place GangMembers
	for gang_pos in object_positions.gang_members:
		var scene: PackedScene = object_scene_map["GANG"]
		if scene == null:
			push_error("🚫 GangMember scene is null")
			continue
		var gang_member: Node2D = scene.instantiate() as Node2D
		if gang_member == null:
			push_error("❌ GangMember instantiation failed at (%d,%d)" % [gang_pos.x, gang_pos.y])
			continue
		var world_pos: Vector2 = Vector2(gang_pos.x, gang_pos.y) * cell_size
		gang_member.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		# Let the global Y-sort system handle z_index
		if gang_member.has_meta("grid_position") or "grid_position" in gang_member:
			gang_member.set("grid_position", gang_pos)
		else:
			push_warning("⚠️ GangMember missing 'grid_position'. Type: %s" % gang_member.get_class())
		
		# Setup the GangMember with random type
		var gang_types = ["default", "variant1", "variant2"]
		var random_type = gang_types[randi() % gang_types.size()]
		if gang_member.has_method("setup"):
			gang_member.setup(random_type, gang_pos, cell_size)
		
		# Add gang member to groups for smart optimization
		gang_member.add_to_group("gang_members")
		gang_member.add_to_group("collision_objects")
		gang_member.add_to_group("NPC")  # Add to NPC group for attack system
		
		ysort_objects.append({"node": gang_member, "grid_pos": gang_pos})
		obstacle_layer.add_child(gang_member)
	
	# Place Police
	for police_pos in object_positions.police:
		var scene: PackedScene = object_scene_map["POLICE"]
		if scene == null:
			push_error("🚫 Police scene is null")
			continue
		var police: Node2D = scene.instantiate() as Node2D
		if police == null:
			push_error("❌ Police instantiation failed at (%d,%d)" % [police_pos.x, police_pos.y])
			continue
		var world_pos: Vector2 = Vector2(police_pos.x, police_pos.y) * cell_size
		police.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		# Let the global Y-sort system handle z_index
		if police.has_meta("grid_position") or "grid_position" in police:
			police.set("grid_position", police_pos)
		else:
			push_warning("⚠️ Police missing 'grid_position'. Type: %s" % police.get_class())
		
		# Setup the Police
		if police.has_method("setup"):
			police.setup(police_pos, cell_size)
		
		# Add police to groups for smart optimization
		police.add_to_group("police")
		police.add_to_group("collision_objects")
		police.add_to_group("NPC")  # Add to NPC group for attack system
		
		ysort_objects.append({"node": police, "grid_pos": police_pos})
		obstacle_layer.add_child(police)
	
	# Place Zombies
	for zombie_pos in object_positions.zombies:
		var scene: PackedScene = object_scene_map["ZOMBIE"]
		if scene == null:
			push_error("🚫 ZombieGolfer scene is null")
			continue
		var zombie: Node2D = scene.instantiate() as Node2D
		if zombie == null:
			push_error("❌ ZombieGolfer instantiation failed at (%d,%d)" % [zombie_pos.x, zombie_pos.y])
			continue
		var world_pos: Vector2 = Vector2(zombie_pos.x, zombie_pos.y) * cell_size
		zombie.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		# Let the global Y-sort system handle z_index
		if zombie.has_meta("grid_position") or "grid_position" in zombie:
			zombie.set("grid_position", zombie_pos)
		else:
			push_warning("⚠️ ZombieGolfer missing 'grid_position'. Type: %s" % zombie.get_class())
		
		# Setup the ZombieGolfer with random type
		var zombie_types = ["default", "variant1", "variant2"]
		var random_type = zombie_types[randi() % zombie_types.size()]
		if zombie.has_method("setup"):
			zombie.setup(random_type, zombie_pos, cell_size)
		
		# Add zombie to groups for smart optimization
		zombie.add_to_group("zombies")
		zombie.add_to_group("collision_objects")
		zombie.add_to_group("NPC")  # Add to NPC group for attack system
		
		ysort_objects.append({"node": zombie, "grid_pos": zombie_pos})
		obstacle_layer.add_child(zombie)
	
	# Place Wraiths (Boss encounters)
	for wraith_pos in object_positions.wraiths:
		var scene: PackedScene = object_scene_map["WRAITH"]
		if scene == null:
			push_error("🚫 Wraith scene is null")
			continue
		var wraith: Node2D = scene.instantiate() as Node2D
		if wraith == null:
			push_error("❌ Wraith instantiation failed at (%d,%d)" % [wraith_pos.x, wraith_pos.y])
			continue
		var world_pos: Vector2 = Vector2(wraith_pos.x, wraith_pos.y) * cell_size
		wraith.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		# Let the global Y-sort system handle z_index
		if wraith.has_meta("grid_position") or "grid_position" in wraith:
			wraith.set("grid_position", wraith_pos)
		else:
			push_warning("⚠️ Wraith missing 'grid_position'. Type: %s" % wraith.get_class())
		
		# Setup the Wraith with default type
		if wraith.has_method("setup"):
			wraith.setup("default", wraith_pos, cell_size)
		
		# Add wraith to groups for smart optimization
		wraith.add_to_group("bosses")
		wraith.add_to_group("collision_objects")
		wraith.add_to_group("NPC")  # Add to NPC group for attack system
		
		ysort_objects.append({"node": wraith, "grid_pos": wraith_pos})
		obstacle_layer.add_child(wraith)
	
	# Place Oil Drums
	for oil_pos in object_positions.oil_drums:
		var scene: PackedScene = object_scene_map["OIL"]
		if scene == null:
			push_error("🚫 Oil Drum scene is null")
			continue
		var oil_drum: Node2D = scene.instantiate() as Node2D
		if oil_drum == null:
			push_error("❌ Oil Drum instantiation failed at (%d,%d)" % [oil_pos.x, oil_pos.y])
			continue
		var world_pos: Vector2 = Vector2(oil_pos.x, oil_pos.y) * cell_size
		oil_drum.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Always set the grid_position property unconditionally
		oil_drum.set_meta("grid_position", oil_pos)
		
		# Add oil drum to groups for smart optimization
		oil_drum.add_to_group("interactables")
		oil_drum.add_to_group("collision_objects")
		
		ysort_objects.append({"node": oil_drum, "grid_pos": oil_pos})
		obstacle_layer.add_child(oil_drum)
	
	# Place Stone Walls
	for wall_pos in object_positions.stone_walls:
		var scene: PackedScene = object_scene_map["WALL"]
		if scene == null:
			push_error("🚫 StoneWall scene is null")
			continue
		var stone_wall: Node2D = scene.instantiate() as Node2D
		if stone_wall == null:
			push_error("❌ StoneWall instantiation failed at (%d,%d)" % [wall_pos.x, wall_pos.y])
			continue
		var world_pos: Vector2 = Vector2(wall_pos.x, wall_pos.y) * cell_size
		stone_wall.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Always set the grid_position property unconditionally
		stone_wall.set_meta("grid_position", wall_pos)
		
		# Add stone wall to groups for smart optimization
		stone_wall.add_to_group("obstacles")
		stone_wall.add_to_group("collision_objects")
		stone_wall.add_to_group("rectangular_obstacles")  # Add to rectangular_obstacles group for rolling collision detection
		
		ysort_objects.append({"node": stone_wall, "grid_pos": wall_pos})
		obstacle_layer.add_child(stone_wall)
		if stone_wall.has_method("blocks") and stone_wall.blocks():
			obstacle_map[wall_pos] = stone_wall
	
	# Place Squirrels
	if "SQUIRREL" in object_scene_map:
		for squirrel_pos in object_positions.squirrels:
			var scene: PackedScene = object_scene_map["SQUIRREL"]
			if scene == null:
				push_error("🚫 Squirrel scene is null")
				continue
			var squirrel: Node2D = scene.instantiate() as Node2D
			if squirrel == null:
				push_error("❌ Squirrel instantiation failed at (%d,%d)" % [squirrel_pos.x, squirrel_pos.y])
				continue
			var world_pos: Vector2 = Vector2(squirrel_pos.x, squirrel_pos.y) * cell_size
			squirrel.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
			
			# Set the grid_position property
			squirrel.set_meta("grid_position", squirrel_pos)
			
			# Setup the Squirrel
			if squirrel.has_method("setup"):
				squirrel.setup(squirrel_pos, cell_size)
			
			# Add squirrel to groups for smart optimization
			squirrel.add_to_group("squirrels")
			squirrel.add_to_group("collision_objects")
			squirrel.add_to_group("NPC")  # Add to NPC group for attack system
			
			ysort_objects.append({"node": squirrel, "grid_pos": squirrel_pos})
			obstacle_layer.add_child(squirrel)
	
	# Place Bonfires
	for bonfire_pos in object_positions.bonfires:
		var scene: PackedScene = object_scene_map["BONFIRE"]
		if scene == null:
			push_error("🚫 Bonfire scene is null")
			continue
		var bonfire: Node2D = scene.instantiate() as Node2D
		if bonfire == null:
			push_error("❌ Bonfire instantiation failed at (%d,%d)" % [bonfire_pos.x, bonfire_pos.y])
			continue
		var world_pos: Vector2 = Vector2(bonfire_pos.x, bonfire_pos.y) * cell_size
		bonfire.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Always set the grid_position property unconditionally
		bonfire.set_meta("grid_position", bonfire_pos)
		
		# Add bonfire to groups for smart optimization
		bonfire.add_to_group("interactables")
		bonfire.add_to_group("collision_objects")
		
		ysort_objects.append({"node": bonfire, "grid_pos": bonfire_pos})
		obstacle_layer.add_child(bonfire)
	
	# Place Generator Puzzle System
	_place_generator_puzzle_system(object_positions, layout)
	
	# Place Miniboss Puzzle System
	_place_miniboss_puzzle_system(object_positions, layout)
	
	# Place SuitCase
	if object_positions.suitcase != Vector2i.ZERO:
		var scene: PackedScene = object_scene_map["SUITCASE"]
		if scene == null:
			push_error("🚫 SuitCase scene is null")
		else:
			var suitcase: Node2D = scene.instantiate() as Node2D
			if suitcase == null:
				push_error("❌ SuitCase instantiation failed at (%d,%d)" % [object_positions.suitcase.x, object_positions.suitcase.y])
			else:
				var world_pos: Vector2 = Vector2(object_positions.suitcase.x, object_positions.suitcase.y) * cell_size
				suitcase.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
				if suitcase.has_meta("grid_position") or "grid_position" in suitcase:
					suitcase.set("grid_position", object_positions.suitcase)
				
				# Add suitcase to groups for smart optimization
				suitcase.add_to_group("interactables")
				suitcase.add_to_group("collision_objects")
				
				ysort_objects.append({"node": suitcase, "grid_pos": object_positions.suitcase})
				obstacle_layer.add_child(suitcase)
				suitcase_grid_pos = object_positions.suitcase
				
				# Connect to SuitCase signal
				if suitcase.has_signal("suitcase_reached"):
					if get_parent() and get_parent().has_method("_on_suitcase_reached"):
						suitcase.suitcase_reached.connect(Callable(get_parent(), "_on_suitcase_reached"))
	
	update_all_ysort_z_indices() 

# --- Signal handlers that forward to course_1.gd ---
# Note: Signals are now connected directly to parent methods

func _on_pin_flag_hit(ball: Node2D):
	# Forward the signal to course_1.gd
	if get_parent() and get_parent().has_method("_on_pin_flag_hit"):
		get_parent()._on_pin_flag_hit(ball)

func get_suitcase_position() -> Vector2i:
	"""Get the SuitCase position for the course"""
	return suitcase_grid_pos

func update_all_ysort_z_indices():
	"""Update z_index for all objects using the simple global Y-sort system"""
	# Use the global Y-sort system for all objects
	Global.update_all_objects_y_sort(ysort_objects)

func _place_generator_puzzle_system(object_positions: Dictionary, layout: Array):
	"""Place the generator puzzle system with generator switch, pylons, and force fields"""
	
	print("🔧 GENERATOR PUZZLE PLACEMENT FUNCTION CALLED!")
	print("🔧 GENERATOR PUZZLE PLACEMENT FUNCTION CALLED!")
	print("🔧 GENERATOR PUZZLE PLACEMENT FUNCTION CALLED!")
	print("=== GENERATOR PUZZLE PLACEMENT START ===")
	print("🔍 Object positions keys:", object_positions.keys())
	print("🔍 Object positions size:", object_positions.size())
	
	# Check if we have generator puzzle data
	if not "generator_puzzle" in object_positions:
		print("❌ No generator_puzzle data found in object_positions")
		print("🔍 Available keys:", object_positions.keys())
		return
	
	var puzzle_data = object_positions.generator_puzzle
	print("✓ Generator puzzle data found:", puzzle_data)
	
	if not puzzle_data.has("generator_pos") or not puzzle_data.has("pylon_positions"):
		print("❌ Missing required puzzle data - generator_pos or pylon_positions")
		return
	
	# Place Generator Switch
	var generator_pos = puzzle_data.generator_pos
	print("✓ Placing generator switch at:", generator_pos)
	
	var scene: PackedScene = object_scene_map["GENERATOR"]
	if scene == null:
		push_error("🚫 GeneratorSwitch scene is null")
		return
	
	var generator: Node2D = scene.instantiate() as Node2D
	if generator == null:
		push_error("❌ GeneratorSwitch instantiation failed at (%d,%d)" % [generator_pos.x, generator_pos.y])
		return
	
	var world_pos: Vector2 = Vector2(generator_pos.x, generator_pos.y) * cell_size
	generator.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
	
	# Set the grid_position property
	generator.set_meta("grid_position", generator_pos)
	
	# Add generator to groups for smart optimization
	generator.add_to_group("interactables")
	generator.add_to_group("collision_objects")
	generator.add_to_group("generator_switches")
	
	ysort_objects.append({"node": generator, "grid_pos": generator_pos})
	obstacle_layer.add_child(generator)
	
	# Place Pylons
	var pylon_positions = puzzle_data.pylon_positions
	print("✓ Placing pylons at positions:", pylon_positions)
	
	var pylons: Array[Node2D] = []
	
	for pylon_pos in pylon_positions:
		print("  - Attempting to place pylon at:", pylon_pos)
		var pylon_scene: PackedScene = object_scene_map["PYLON"]
		print("  - Pylon scene loaded:", pylon_scene != null)
		if pylon_scene == null:
			push_error("🚫 Pylon scene is null")
			print("❌ Pylon scene is null - check object_scene_map")
			continue
		
		var pylon: Node2D = pylon_scene.instantiate() as Node2D
		print("  - Pylon instantiated:", pylon != null)
		if pylon == null:
			push_error("❌ Pylon instantiation failed at (%d,%d)" % [pylon_pos.x, pylon_pos.y])
			continue
		
		var pylon_world_pos: Vector2 = Vector2(pylon_pos.x, pylon_pos.y) * cell_size
		pylon.position = pylon_world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Set the grid_position property
		pylon.set_meta("grid_position", pylon_pos)
		
		# Add pylon to groups for smart optimization
		pylon.add_to_group("interactables")
		pylon.add_to_group("collision_objects")
		pylon.add_to_group("pylons")
		
		ysort_objects.append({"node": pylon, "grid_pos": pylon_pos})
		obstacle_layer.add_child(pylon)
		pylons.append(pylon)
		print("  ✓ Pylon placed successfully at:", pylon_pos)
		print("    - Pylon position:", pylon.position)
		print("    - Pylon global position:", pylon.global_position)
		print("    - Pylon visible:", pylon.visible)
		print("    - Obstacle layer children count:", obstacle_layer.get_child_count())
	
	# Create Force Fields between Pylons
	var fields: Array[Node2D] = []
	print("✓ Creating force fields between", pylons.size(), "pylons")
	
	if pylons.size() >= 2:
		# Determine if pylons are on same row or same column
		var pylon1 = pylons[0]
		var pylon2 = pylons[1]
		var pylon1_pos = pylon1.get_meta("grid_position")
		var pylon2_pos = pylon2.get_meta("grid_position")
		
		var is_same_row = pylon1_pos.y == pylon2_pos.y
		var is_same_column = pylon1_pos.x == pylon2_pos.x
		
		if is_same_column:
			print("  - Creating vertical field between pylons")
			# Create Vertical Field
			var field_scene: PackedScene = object_scene_map["VERTICAL_FIELD"]
			if field_scene != null:
				var field: Node2D = field_scene.instantiate() as Node2D
				if field != null:
					# Position field between pylons
					var field_world_pos = (pylon1.position + pylon2.position) / 2.0
					field.position = field_world_pos
					print("  - Field positioned at:", field_world_pos)
					print("  - Field global position after positioning:", field.global_position)
					
					# Setup the field
					if field.has_method("setup_field"):
						field.setup_field(pylon1, pylon2)
						print("  - Field global position after setup:", field.global_position)
					
					# Add field to groups
					field.add_to_group("interactables")
					field.add_to_group("collision_objects")
					field.add_to_group("force_fields")
					
					# Add to ysort (use average grid position)
					var avg_grid_pos = (pylon1_pos + pylon2_pos) / 2
					ysort_objects.append({"node": field, "grid_pos": avg_grid_pos})
					obstacle_layer.add_child(field)
					fields.append(field)
					
					# Connect pylons to field
					if pylon1.has_method("connect_to_field"):
						pylon1.connect_to_field(field)
					if pylon2.has_method("connect_to_field"):
						pylon2.connect_to_field(field)
		
		elif is_same_row:
			print("  - Creating horizontal field between pylons")
			# Create Horizontal Field
			var field_scene: PackedScene = object_scene_map["HORIZONTAL_FIELD"]
			if field_scene != null:
				var field: Node2D = field_scene.instantiate() as Node2D
				if field != null:
					# Position field between pylons
					var field_world_pos = (pylon1.position + pylon2.position) / 2.0
					field.position = field_world_pos
					
					# Setup the field
					if field.has_method("setup_field"):
						field.setup_field(pylon1, pylon2)
					
					# Add field to groups
					field.add_to_group("interactables")
					field.add_to_group("collision_objects")
					field.add_to_group("force_fields")
					
					# Add to ysort (use average grid position)
					var avg_grid_pos = (pylon1_pos + pylon2_pos) / 2
					ysort_objects.append({"node": field, "grid_pos": avg_grid_pos})
					obstacle_layer.add_child(field)
					fields.append(field)
					
					# Connect pylons to field
					if pylon1.has_method("connect_to_field"):
						pylon1.connect_to_field(field)
					if pylon2.has_method("connect_to_field"):
						pylon2.connect_to_field(field)
	
	# Connect generator to pylons and fields
	if generator.has_method("connect_to_pylons"):
		generator.connect_to_pylons(pylons)
	if generator.has_method("connect_to_fields"):
		generator.connect_to_fields(fields)
	
	print("=== GENERATOR PUZZLE PLACEMENT COMPLETE ===")
	print("  - Generator switch placed")
	print("  - Pylons placed:", pylons.size())
	print("  - Fields created:", fields.size()) 

func _place_miniboss_puzzle_system(object_positions: Dictionary, layout: Array):
	"""Place the miniboss puzzle system with miniboss and force field dome"""
	
	print("🗡️ MINIBOSS PUZZLE PLACEMENT FUNCTION CALLED!")
	print("=== MINIBOSS PUZZLE PLACEMENT START ===")
	print("🔍 Object positions keys:", object_positions.keys())
	print("🔍 Object positions size:", object_positions.size())
	
	# Check if we have miniboss puzzle data
	if not "miniboss_puzzle" in object_positions:
		print("❌ No miniboss_puzzle data found in object_positions")
		print("🔍 Available keys:", object_positions.keys())
		return
	
	var puzzle_data = object_positions.miniboss_puzzle
	print("✓ Miniboss puzzle data found:", puzzle_data)
	
	if not puzzle_data.has("miniboss_pos"):
		print("❌ Missing required puzzle data - miniboss_pos")
		return
	
	# Place Miniboss (Wraith)
	var miniboss_pos = puzzle_data.miniboss_pos
	print("✓ Placing miniboss at:", miniboss_pos)
	
	var miniboss_scene: PackedScene = object_scene_map["WRAITH"]
	if miniboss_scene == null:
		push_error("🚫 Wraith scene is null")
		return
	
	var miniboss: Node2D = miniboss_scene.instantiate() as Node2D
	if miniboss == null:
		push_error("❌ Wraith instantiation failed at (%d,%d)" % [miniboss_pos.x, miniboss_pos.y])
		return
	
	var miniboss_world_pos: Vector2 = Vector2(miniboss_pos.x, miniboss_pos.y) * cell_size
	miniboss.position = miniboss_world_pos + Vector2(cell_size / 2, cell_size / 2)
	
	# Set the grid_position property
	miniboss.set_meta("grid_position", miniboss_pos)
	
	# Setup the Wraith with default type (CRUCIAL for proper initialization)
	if miniboss.has_method("setup"):
		miniboss.setup("default", miniboss_pos, cell_size)
		print("✓ Miniboss setup called with position:", miniboss_pos, "cell_size:", cell_size)
		print("✓ Miniboss grid_position after setup:", miniboss.get_grid_position() if miniboss.has_method("get_grid_position") else "N/A")
		print("✓ Miniboss world position after setup:", miniboss.position)
	else:
		push_warning("⚠️ Miniboss missing 'setup' method")
	
	# Add miniboss to groups for smart optimization
	miniboss.add_to_group("NPC")
	miniboss.add_to_group("collision_objects")
	miniboss.add_to_group("bosses")
	miniboss.add_to_group("miniboss")
	
	ysort_objects.append({"node": miniboss, "grid_pos": miniboss_pos})
	obstacle_layer.add_child(miniboss)
	
	# Place Force Field Dome at the ACTUAL pin position
	var actual_pin_pos = Global.saved_pin_position
	if actual_pin_pos == Vector2i.ZERO:
		# Fallback to the calculated position if Global.saved_pin_position is not set
		actual_pin_pos = puzzle_data.get("dome_pos", Vector2i.ZERO)
		print("⚠️ Using fallback dome position:", actual_pin_pos)
	else:
		print("✓ Using actual pin position for dome:", actual_pin_pos)
	
	print("✓ Placing force field dome at:", actual_pin_pos)
	
	var dome_scene: PackedScene = object_scene_map["FORCE_FIELD_DOME"]
	if dome_scene == null:
		push_error("🚫 ForceFieldDome scene is null")
		return
	
	var dome: Node2D = dome_scene.instantiate() as Node2D
	if dome == null:
		push_error("❌ ForceFieldDome instantiation failed at (%d,%d)" % [actual_pin_pos.x, actual_pin_pos.y])
		return
	
	var dome_world_pos: Vector2 = Vector2(actual_pin_pos.x, actual_pin_pos.y) * cell_size
	dome.position = dome_world_pos + Vector2(cell_size / 2, cell_size / 2)
	
	# Set the grid_position property
	dome.set_meta("grid_position", actual_pin_pos)
	
	# Add dome to groups for smart optimization
	dome.add_to_group("interactables")
	dome.add_to_group("collision_objects")
	dome.add_to_group("force_field_dome")
	
	ysort_objects.append({"node": dome, "grid_pos": actual_pin_pos})
	obstacle_layer.add_child(dome)
	
	# Connect miniboss reference to dome
	if dome.has_method("set_miniboss_reference"):
		dome.set_miniboss_reference(miniboss)
		print("✓ Miniboss reference connected to force field dome")
		
		# Connect Wraith death signal to dome deactivation
		if miniboss.has_signal("died"):
			miniboss.died.connect(dome.deactivate_dome)
			print("✓ Wraith death signal connected to dome deactivation")
		else:
			# Fallback: connect to tree_exited signal (when Wraith is queue_free'd)
			miniboss.tree_exited.connect(dome.deactivate_dome)
			print("✓ Wraith tree_exited signal connected to dome deactivation")
	
	print("=== MINIBOSS PUZZLE PLACEMENT COMPLETE ===")
	print("  - Miniboss (Wraith) placed at:", miniboss_pos)
	print("  - Force field dome placed at:", actual_pin_pos, "(actual pin position)")
	print("  - Miniboss reference connected to dome")
