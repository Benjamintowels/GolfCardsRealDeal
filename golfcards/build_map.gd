extends Node

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
			else:
				print("ℹ️ Skipping unmapped tile code '%s' at (%d,%d)" % [tile_code, x, y])
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
				print("ℹ️ Skipping unmapped code '%s' at (%d,%d)" % [code, x, y]) 

# --- Clear all existing objects from the map ---
func clear_existing_objects() -> void:
	var objects_removed = 0
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
			
			if is_tree or is_shop or is_pin or is_oil_drum or is_stone_wall or is_boulder or is_police or is_zombie:
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

func get_random_positions_for_objects(layout: Array, num_trees: int = 8, include_shop: bool = true, num_gang_members: int = -1, num_oil_drums: int = -1, num_police: int = -1, num_zombies: int = -1) -> Dictionary:
	var positions = {
		"trees": [],
		"shop": Vector2i.ZERO,
		"gang_members": [],
		"oil_drums": [],
		"stone_walls": [],
		"boulders": [],
		"bushes": [],
		"police": [],
		"zombies": [],
		"squirrels": []
	}
	
	# Use difficulty tier spawning if parameters are -1 (default)
	var npc_counts = Global.get_difficulty_tier_npc_counts(current_hole)
	
	if num_gang_members == -1:
		num_gang_members = npc_counts.gang_members
	if num_oil_drums == -1:
		num_oil_drums = Global.get_turn_based_oil_drum_count()
	if num_police == -1:
		num_police = npc_counts.police
	if num_zombies == -1:
		num_zombies = npc_counts.zombies
	
	print("=== DIFFICULTY TIER SPAWNING ===")
	print("Global turn: ", Global.global_turn_count)
	print("Difficulty tier: ", Global.get_difficulty_tier())
	print("NPC counts: ", npc_counts)
	print("Gang members to spawn: ", num_gang_members)
	print("Police to spawn: ", num_police)
	print("Zombies to spawn: ", num_zombies)
	print("Oil drums to spawn: ", num_oil_drums)
	print("Current hole: ", current_hole)
	print("=== END DIFFICULTY TIER SPAWNING ===")
	
	randomize()
	random_seed_value = current_hole * 1000 + randi()
	seed(random_seed_value)
	
	# For hole 1, force shop placement near tees for testing
	if current_hole == 0 and include_shop:
		# Place shop at position (2, 4) which is near the tees at (5,5)-(7,7)
		# This puts the shop entrance at (2,4) with blocked tiles around it
		positions.shop = Vector2i(2, 4)
		placed_objects.append(positions.shop)
		print("✓ Shop forced to position (2,4) for hole 1 testing")
	
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
	print("=== PLACING SQUIRRELS AROUND TREES ===")
	print("Tree positions:", positions.trees)
	var squirrels_placed = 0
	var max_squirrels = npc_counts.squirrels
	
	# Get all valid positions within 5 tiles of any tree
	var squirrel_candidate_positions: Array = []
	for tree_pos in positions.trees:
		print("Checking positions around tree at:", tree_pos)
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
						print("  Added candidate position:", candidate_pos)
				else:
					print("  Rejected position:", candidate_pos, "tile type:", layout[candidate_pos.y][candidate_pos.x])
	
	print("Found", squirrel_candidate_positions.size(), "candidate positions for squirrels")
	
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
				print("  Rejected squirrel position:", squirrel_pos, "too close to:", placed_pos, "distance:", distance)
				break
		
		if valid:
			positions.squirrels.append(squirrel_pos)
			placed_objects.append(squirrel_pos)
			squirrels_placed += 1
			print("✓ Squirrel placed at position:", squirrel_pos)
		else:
			print("  Squirrel placement failed for position:", squirrel_pos)
		
		squirrel_candidate_positions.remove_at(squirrel_index)
	
	print("✓ Placed", squirrels_placed, "squirrels around trees")
	print("=== END PLACING SQUIRRELS ===")
	
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
	
	print("✓ Placed", boulders_placed, "boulders on remaining base tiles")
	
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
	
	print("✓ Placed", bushes_placed, "bushes on remaining base tiles")
	print("Bush positions:", positions.bushes)
	
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
	
	print("✓ Placed", zombies_placed, "zombies on sand tiles")
	
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
	
	# Place Stone Walls around map edges (only top and bottom, every other tile to prevent overlap)
	var edge_positions: Array = []
	var layout_width = layout[0].size()
	var layout_height = layout.size()
	
	# Add top edge only, every other tile to prevent overlap
	for x in range(0, layout_width, 2):  # Step by 2 to place every other tile
		# Top edge
		if layout[0][x] != "W":  # Don't place on water
			edge_positions.append(Vector2i(x, 0))
		# (Bottom edge removed)
	
	# Add stone walls to edge positions
	for wall_pos in edge_positions:
		positions.stone_walls.append(wall_pos)
		placed_objects.append(wall_pos)
	
	print("✓ Placed", positions.stone_walls.size(), "stone walls around map edges")
	
	return positions

func build_map_from_layout_with_randomization(layout: Array) -> void:
	randomize()
	clear_existing_objects()
	build_map_from_layout_base(layout)
	# Use difficulty tier spawning (-1 means use difficulty tier calculation)
	var object_positions = get_random_positions_for_objects(layout, 8, true, -1, -1, -1, -1)
	place_objects_at_positions(object_positions, layout)
	# position_camera_on_pin()  # This should be called from the main scene if needed

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
				print("ℹ️ Skipping unmapped tile code '%s' at (%d,%d)" % [tile_code, x, y])
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
				ysort_objects.append({"node": pin, "grid_pos": pin_pos})
				update_all_ysort_z_indices()

func place_objects_at_positions(object_positions: Dictionary, layout: Array) -> void:
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
	print("=== PLACING BOULDERS ===")
	print("Boulder positions:", object_positions.boulders)
	for boulder_pos in object_positions.boulders:
		var scene: PackedScene = object_scene_map["BOULDER"]
		if scene == null:
			push_error("🚫 Boulder scene is null")
			continue
		print("✓ Boulder scene loaded successfully")
		var boulder: Node2D = scene.instantiate() as Node2D
		if boulder == null:
			push_error("❌ Boulder instantiation failed at (%d,%d)" % [boulder_pos.x, boulder_pos.y])
			continue
		print("✓ Boulder instantiated successfully")
		var world_pos: Vector2 = Vector2(boulder_pos.x, boulder_pos.y) * cell_size
		boulder.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Always set the grid_position property unconditionally
		boulder.set_meta("grid_position", boulder_pos)
		print("✓ Set boulder grid_position to:", boulder_pos)
		
		# Add boulder to groups for smart optimization
		boulder.add_to_group("boulders")
		boulder.add_to_group("collision_objects")
		
		ysort_objects.append({"node": boulder, "grid_pos": boulder_pos})
		obstacle_layer.add_child(boulder)
		print("✓ Boulder placed at grid position:", boulder_pos, "world position:", world_pos)
		print("✓ Boulder name:", boulder.name)
		print("✓ Boulder grid_position property:", boulder.get_meta("grid_position") if boulder.get_meta("grid_position") != null else "null")
	print("=== END PLACING BOULDERS ===")
	
	# Place Bushes
	print("=== PLACING BUSHES ===")
	print("Bush positions:", object_positions.bushes)
	for bush_pos in object_positions.bushes:
		var scene: PackedScene = object_scene_map["BUSH"]
		if scene == null:
			push_error("🚫 Bush scene is null")
			continue
		print("✓ Bush scene loaded successfully")
		var bush: Node2D = scene.instantiate() as Node2D
		if bush == null:
			push_error("❌ Bush instantiation failed at (%d,%d)" % [bush_pos.x, bush_pos.y])
			continue
		print("✓ Bush instantiated successfully")
		print("✓ Bush script attached:", bush.get_script() != null)
		if bush.get_script():
			print("✓ Bush script path:", bush.get_script().resource_path)
		else:
			print("✗ Bush script is null!")
		var world_pos: Vector2 = Vector2(bush_pos.x, bush_pos.y) * cell_size
		bush.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Always set the grid_position property unconditionally
		bush.set_meta("grid_position", bush_pos)
		print("✓ Set bush grid_position to:", bush_pos)
		
		# Add bush to groups for smart optimization
		bush.add_to_group("bushes")
		bush.add_to_group("collision_objects")
		
		# Verify Area2D collision layers
		var bush_area = bush.get_node_or_null("BushArea2D")
		if bush_area:
			print("✓ Bush Area2D collision layer:", bush_area.collision_layer)
			print("✓ Bush Area2D collision mask:", bush_area.collision_mask)
		else:
			print("✗ Bush Area2D not found")
		
		ysort_objects.append({"node": bush, "grid_pos": bush_pos})
		obstacle_layer.add_child(bush)
		print("✓ Bush added to obstacle_layer")
		print("✓ Bush is in scene tree:", bush.is_inside_tree())
		print("✓ Bush placed at grid position:", bush_pos, "world position:", world_pos)
		print("✓ Bush name:", bush.name)
		print("✓ Bush grid_position property:", bush.get_meta("grid_position") if bush.get_meta("grid_position") != null else "null")
	print("=== END PLACING BUSHES ===")
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
				print("✓ Shop placed at grid position:", shop_grid_pos)
				
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
					print("✓ InvisibleBlocker placed at grid position:", blocker_pos)
	
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
		
		ysort_objects.append({"node": gang_member, "grid_pos": gang_pos})
		obstacle_layer.add_child(gang_member)
	
	# Place Police
	print("=== PLACING POLICE ===")
	print("Police positions:", object_positions.police)
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
		
		ysort_objects.append({"node": police, "grid_pos": police_pos})
		obstacle_layer.add_child(police)
		print("✓ Police placed at grid position:", police_pos)
	
	# Place Zombies
	print("=== PLACING ZOMBIES ===")
	print("Zombie positions:", object_positions.zombies)
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
		
		ysort_objects.append({"node": zombie, "grid_pos": zombie_pos})
		obstacle_layer.add_child(zombie)
		print("✓ ZombieGolfer placed at grid position:", zombie_pos)
	
	# Place Oil Drums
	print("=== PLACING OIL DRUMS ===")
	print("Oil drum positions:", object_positions.oil_drums)
	for oil_pos in object_positions.oil_drums:
		var scene: PackedScene = object_scene_map["OIL"]
		if scene == null:
			push_error("🚫 Oil Drum scene is null")
			continue
		print("✓ Oil Drum scene loaded successfully")
		var oil_drum: Node2D = scene.instantiate() as Node2D
		if oil_drum == null:
			push_error("❌ Oil Drum instantiation failed at (%d,%d)" % [oil_pos.x, oil_pos.y])
			continue
		print("✓ Oil Drum instantiated successfully")
		var world_pos: Vector2 = Vector2(oil_pos.x, oil_pos.y) * cell_size
		oil_drum.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Always set the grid_position property unconditionally
		oil_drum.set_meta("grid_position", oil_pos)
		print("✓ Set oil drum grid_position to:", oil_pos)
		
		# Add oil drum to groups for smart optimization
		oil_drum.add_to_group("interactables")
		oil_drum.add_to_group("collision_objects")
		
		ysort_objects.append({"node": oil_drum, "grid_pos": oil_pos})
		obstacle_layer.add_child(oil_drum)
		print("✓ Oil Drum placed at grid position:", oil_pos, "world position:", world_pos)
		print("✓ Oil Drum name:", oil_drum.name)
		print("✓ Oil Drum grid_position property:", oil_drum.get_meta("grid_position") if oil_drum.get_meta("grid_position") != null else "null")
		print("✓ Oil Drum has meta grid_position:", oil_drum.has_meta("grid_position"))
		if oil_drum.has_meta("grid_position"):
			print("✓ Oil Drum meta grid_position:", oil_drum.get_meta("grid_position"))
	print("=== END PLACING OIL DRUMS ===")
	
	# Place Stone Walls
	print("=== PLACING STONE WALLS ===")
	print("Stone wall positions:", object_positions.stone_walls)
	for wall_pos in object_positions.stone_walls:
		var scene: PackedScene = object_scene_map["WALL"]
		if scene == null:
			push_error("🚫 StoneWall scene is null")
			continue
		print("✓ StoneWall scene loaded successfully")
		var stone_wall: Node2D = scene.instantiate() as Node2D
		if stone_wall == null:
			push_error("❌ StoneWall instantiation failed at (%d,%d)" % [wall_pos.x, wall_pos.y])
			continue
		print("✓ StoneWall instantiated successfully")
		var world_pos: Vector2 = Vector2(wall_pos.x, wall_pos.y) * cell_size
		stone_wall.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Always set the grid_position property unconditionally
		stone_wall.set_meta("grid_position", wall_pos)
		print("✓ Set stone wall grid_position to:", wall_pos)
		
		# Add stone wall to groups for smart optimization
		stone_wall.add_to_group("obstacles")
		stone_wall.add_to_group("collision_objects")
		stone_wall.add_to_group("rectangular_obstacles")  # Add to rectangular_obstacles group for rolling collision detection
		
		ysort_objects.append({"node": stone_wall, "grid_pos": wall_pos})
		obstacle_layer.add_child(stone_wall)
		if stone_wall.has_method("blocks") and stone_wall.blocks():
			obstacle_map[wall_pos] = stone_wall
		print("✓ StoneWall placed at grid position:", wall_pos, "world position:", world_pos)
		print("✓ StoneWall name:", stone_wall.name)
		print("✓ StoneWall grid_position property:", stone_wall.get_meta("grid_position") if stone_wall.get_meta("grid_position") != null else "null")
	print("=== END PLACING STONE WALLS ===")
	
	# Place Squirrels
	print("=== PLACING SQUIRRELS ===")
	print("Squirrel positions:", object_positions.squirrels)
	print("Squirrel scene map key exists:", "SQUIRREL" in object_scene_map)
	if "SQUIRREL" in object_scene_map:
		print("Squirrel scene:", object_scene_map["SQUIRREL"])
	
	for squirrel_pos in object_positions.squirrels:
		var scene: PackedScene = object_scene_map["SQUIRREL"]
		if scene == null:
			push_error("🚫 Squirrel scene is null")
			continue
		print("✓ Squirrel scene loaded successfully")
		var squirrel: Node2D = scene.instantiate() as Node2D
		if squirrel == null:
			push_error("❌ Squirrel instantiation failed at (%d,%d)" % [squirrel_pos.x, squirrel_pos.y])
			continue
		print("✓ Squirrel instantiated successfully")
		var world_pos: Vector2 = Vector2(squirrel_pos.x, squirrel_pos.y) * cell_size
		squirrel.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		
		# Set the grid_position property
		squirrel.set_meta("grid_position", squirrel_pos)
		print("✓ Set squirrel grid_position to:", squirrel_pos)
		
		# Setup the Squirrel
		if squirrel.has_method("setup"):
			squirrel.setup(squirrel_pos, cell_size)
		
		# Add squirrel to groups for smart optimization
		squirrel.add_to_group("squirrels")
		squirrel.add_to_group("collision_objects")
		squirrel.add_to_group("npcs")
		
		ysort_objects.append({"node": squirrel, "grid_pos": squirrel_pos})
		obstacle_layer.add_child(squirrel)
		print("✓ Squirrel placed at grid position:", squirrel_pos, "world position:", world_pos)
		print("✓ Squirrel name:", squirrel.name)
		print("✓ Squirrel grid_position property:", squirrel.get_meta("grid_position") if squirrel.get_meta("grid_position") != null else "null")
	print("=== END PLACING SQUIRRELS ===")
	
	update_all_ysort_z_indices() 

# --- Signal handlers that forward to course_1.gd ---
# Note: Signals are now connected directly to parent methods

func _on_pin_flag_hit(ball: Node2D):
	# Forward the signal to course_1.gd
	if get_parent() and get_parent().has_method("_on_pin_flag_hit"):
		get_parent()._on_pin_flag_hit(ball)

func update_all_ysort_z_indices():
	"""Update z_index for all objects using the simple global Y-sort system"""
	# Use the global Y-sort system for all objects
	Global.update_all_objects_y_sort(ysort_objects) 
