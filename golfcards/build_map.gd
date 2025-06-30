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
	print("Clearing existing objects...")
	var objects_removed = 0
	for child in obstacle_layer.get_children():
		child.queue_free()
		objects_removed += 1
	print("Removed", objects_removed, "objects from obstacle_layer")
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
			if is_tree or is_shop or is_pin:
				keys_to_remove.append(pos)
	for pos in keys_to_remove:
		obstacle_map.erase(pos)
	print("Removed", keys_to_remove.size(), "object entries from obstacle_map")
	var ysort_count = ysort_objects.size()
	ysort_objects.clear()
	placed_objects.clear()
	print("Cleared", ysort_count, "ysort objects")
	print("Objects cleared. Remaining obstacles:", obstacle_map.size())

func is_valid_position_for_object(pos: Vector2i, layout: Array) -> bool:
	if pos.y < 0 or pos.y >= layout.size() or pos.x < 0 or pos.x >= layout[0].size():
		return false
	var tile_type = layout[pos.y][pos.x]
	if tile_type in ["F", "Tee", "G", "W", "S", "P"]:
		return false
	if tile_type in ["W", "S", "P"]:
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

func get_random_positions_for_objects(layout: Array, num_trees: int = 8, include_shop: bool = true) -> Dictionary:
	var positions = {
		"trees": [],
		"shop": Vector2i.ZERO
	}
	randomize()
	random_seed_value = current_hole * 1000 + randi()
	seed(random_seed_value)
	var valid_positions: Array = []
	for y in layout.size():
		for x in layout[y].size():
			var pos = Vector2i(x, y)
			if is_valid_position_for_object(pos, layout):
				valid_positions.append(pos)
	if include_shop and valid_positions.size() > 0:
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
	return positions

func build_map_from_layout_with_randomization(layout: Array) -> void:
	print("=== BUILD MAP WITH RANDOMIZATION DEBUG ===")
	print("Building map with randomization for hole", current_hole + 1)
	print("Current hole variable:", current_hole)
	print("Layout size:", layout.size(), "x", layout[0].size() if layout.size() > 0 else "empty")
	randomize()
	print("About to clear existing objects...")
	clear_existing_objects()
	build_map_from_layout_base(layout)
	var object_positions = get_random_positions_for_objects(layout, 8, true)
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
				pin.name = "Pin"
				pin.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
				pin.z_index = 1000
				if pin.has_meta("grid_position") or "grid_position" in pin:
					pin.set("grid_position", pin_pos)
				pin.set_meta("card_effect_handler", card_effect_handler)
				obstacle_layer.add_child(pin)
				if pin.has_signal("hole_in_one"):
					pin.hole_in_one.connect(_on_hole_in_one)
				if pin.has_signal("pin_flag_hit"):
					pin.pin_flag_hit.connect(_on_pin_flag_hit)
				ysort_objects.append({"node": pin, "grid_pos": pin_pos})
				update_all_ysort_z_indices()

func place_objects_at_positions(object_positions: Dictionary, layout: Array) -> void:
	print("Placing objects at positions:", object_positions)
	for tree_pos in object_positions.trees:
		var scene: PackedScene = object_scene_map["T"]
		if scene == null:
			push_error("🚫 Tree scene is null")
			continue
		var tree: Node2D = scene.instantiate() as Node2D
		if tree == null:
			push_error("❌ Tree instantiation failed at (%d,%d)" % [tree_pos.x, tree_pos.y])
			continue
		var world_pos: Vector2 = Vector2(tree_pos.x, tree_pos.y) * cell_size
		tree.position = world_pos + Vector2(cell_size / 2, cell_size / 2)
		if tree.has_meta("grid_position") or "grid_position" in tree:
			tree.set("grid_position", tree_pos)
		else:
			push_warning("⚠️ Tree missing 'grid_position'. Type: %s" % tree.get_class())
		ysort_objects.append({"node": tree, "grid_pos": tree_pos})
		obstacle_layer.add_child(tree)
		if tree.has_method("blocks") and tree.blocks():
			obstacle_map[tree_pos] = tree
	print("Placed", object_positions.trees.size(), "trees")
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
				ysort_objects.append({"node": shop, "grid_pos": object_positions.shop})
				obstacle_layer.add_child(shop)
				shop_grid_pos = object_positions.shop
				var right_of_shop_pos = object_positions.shop + Vector2i(1, 0)
				var blocker_scene = preload("res://Obstacles/InvisibleBlocker.tscn")
				var blocker = blocker_scene.instantiate()
				var blocker_world_pos = Vector2(right_of_shop_pos.x, right_of_shop_pos.y) * cell_size
				blocker.position = blocker_world_pos + Vector2(cell_size / 2, cell_size / 2)
				obstacle_layer.add_child(blocker)
				obstacle_map[right_of_shop_pos] = blocker
	update_all_ysort_z_indices() 

# --- Stubs for signals and utility functions to avoid linter errors ---
func _on_hole_in_one():
	pass

func _on_pin_flag_hit():
	pass

func update_all_ysort_z_indices():
	pass 