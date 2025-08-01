extends Node
class_name ForestBorderManager

# Forest border configuration
const TREE_SPACING: int = 64  # Increased spacing for better visual separation
const LEFT_BORDER_WIDTH: int = 15  # Number of tree columns on the left
const RIGHT_BORDER_WIDTH: int = 15  # Number of tree columns on the right

# Tree variations for visual variety
var tree_scene: PackedScene
var tree_instances: Array[Node2D] = []
var tree_textures: Array[Texture2D] = []

# References
var obstacle_layer: Node = null
var cell_size: int = 48

func setup(obstacle_layer_ref: Node, cell_size_param: int = 48) -> void:
	obstacle_layer = obstacle_layer_ref
	cell_size = cell_size_param
	
	# Load the TreeBG scene
	tree_scene = load("res://Obstacles/TreeBG.tscn")
	if not tree_scene:
		push_error("ForestBorderManager: TreeBG scene not found")
		return
	
	# Load different tree textures for variety
	load_tree_textures()
	
	print("ForestBorderManager: Setup complete")

func load_tree_textures() -> void:
	"""Load different tree textures for visual variety"""
	var tree1_texture = load("res://Obstacles/Tree.png")
	var tree2_texture = load("res://Obstacles/Tree2.png")
	var tree3_texture = load("res://Obstacles/Tree3.png")
	
	if tree1_texture:
		tree_textures.append(tree1_texture)
	if tree2_texture:
		tree_textures.append(tree2_texture)
	if tree3_texture:
		tree_textures.append(tree3_texture)
	
	print("ForestBorderManager: Loaded ", tree_textures.size(), " tree textures")

func create_forest_borders(map_width: int, map_height: int) -> void:
	"""Create forest borders on left and right edges of the map"""
	clear_existing_trees()
	
	var map_world_width = map_width * cell_size
	var map_world_height = map_height * cell_size
	
	print("ForestBorderManager: Creating forest borders for map size: ", map_width, "x", map_height)
	
	# Create left border
	create_border_trees(
		Vector2(-LEFT_BORDER_WIDTH * TREE_SPACING, 0),  # Start position
		LEFT_BORDER_WIDTH,  # Width in trees
		map_height,  # Height in trees (full map height)
		true  # Vertical border
	)
	
	# Create right border (start further to the right of the map edge)
	create_border_trees(
		Vector2(map_world_width + 280, 0),  # Start position (200 pixels beyond map edge)
		RIGHT_BORDER_WIDTH,  # Width in trees
		map_height,  # Height in trees (full map height)
		true  # Vertical border
	)
	
	print("ForestBorderManager: Created ", tree_instances.size(), " tree instances")

func create_border_trees(start_pos: Vector2, width_trees: int, height_trees: int, is_vertical: bool) -> void:
	"""Create trees in a grid pattern for a border section"""
	for x in width_trees:
		for y in height_trees:
			var tree_instance = tree_scene.instantiate() as Node2D
			if not tree_instance:
				push_error("ForestBorderManager: Failed to instantiate tree")
				continue
			
			# Calculate position
			var tree_pos: Vector2
			if is_vertical:
				tree_pos = start_pos + Vector2(x * TREE_SPACING, y * TREE_SPACING)
			else:
				tree_pos = start_pos + Vector2(x * TREE_SPACING, y * TREE_SPACING)
			
			# Add some randomness to make it look more natural
			var random_offset = Vector2(
				randf_range(-TREE_SPACING * 0.4, TREE_SPACING * 0.4),
				randf_range(-TREE_SPACING * 0.4, TREE_SPACING * 0.4)
			)
			tree_pos += random_offset
			
			# Set tree properties
			tree_instance.position = tree_pos
			
			# Set z-index based on Y position (lower Y = higher z-index for proper layering)
			var base_z_index = 1000
			var y_offset = int(tree_pos.y / TREE_SPACING) * 2  # Small increment per row
			tree_instance.z_index = base_z_index + y_offset
			
			# Randomize tree texture
			if tree_textures.size() > 0:
				var random_texture = tree_textures[randi() % tree_textures.size()]
				var sprite = tree_instance.get_node_or_null("Sprite2D")
				if sprite:
					sprite.texture = random_texture
			
			# Add some random scale variation
			var scale_variation = randf_range(0.8, 1.2)
			tree_instance.scale = Vector2(scale_variation, scale_variation)
			
			# Add to group for easy access
			tree_instance.add_to_group("forest_trees")
			
			# Add to obstacle layer
			obstacle_layer.add_child(tree_instance)
			tree_instances.append(tree_instance)

func clear_existing_trees() -> void:
	"""Remove all existing tree instances"""
	for tree in tree_instances:
		if is_instance_valid(tree):
			tree.queue_free()
	tree_instances.clear()
	print("ForestBorderManager: Cleared existing trees")

func trigger_pseudo3d_effect() -> void:
	"""Trigger pseudo3D animation on all forest trees"""
	for tree in tree_instances:
		if is_instance_valid(tree) and tree.has_method("play_pseudo3d_effect"):
			tree.play_pseudo3d_effect()
	print("ForestBorderManager: Triggered pseudo3D effect on ", tree_instances.size(), " trees")

func reverse_pseudo3d_effect() -> void:
	"""Reverse pseudo3D animation on all forest trees"""
	for tree in tree_instances:
		if is_instance_valid(tree) and tree.has_method("reverse_pseudo3d_effect"):
			tree.reverse_pseudo3d_effect()
	print("ForestBorderManager: Reversed pseudo3D effect on ", tree_instances.size(), " trees")

func get_tree_count() -> int:
	"""Get the total number of tree instances"""
	return tree_instances.size() 