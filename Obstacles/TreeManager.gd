extends Node
class_name TreeManager

# Import TreeData for tree variations
const TreeData = preload("res://Obstacles/TreeData.gd")

# Array of all available tree variations
var tree_variations: Array[TreeData] = []

func _ready():
	_load_tree_variations()

func _load_tree_variations():
	"""Load all tree variations from the TreeVariations folder"""
	var dir = DirAccess.open("res://Obstacles/TreeVariations")
	if not dir:
		print("✗ ERROR: Could not open TreeVariations directory")
		return
	
	# Load all .tres files in the TreeVariations folder
	for file in dir.get_files():
		if file.ends_with(".tres"):
			var tree_data = load("res://Obstacles/TreeVariations/" + file) as TreeData
			if tree_data:
				tree_variations.append(tree_data)
				print("✓ Loaded tree variation:", tree_data.name)
			else:
				print("✗ Failed to load tree variation from:", file)
	
	print("✓ Loaded", tree_variations.size(), "tree variations")

func get_random_tree_data() -> TreeData:
	"""Get a random tree variation based on rarity weights"""
	if tree_variations.is_empty():
		print("✗ No tree variations loaded!")
		return null
	
	# Calculate total weight
	var total_weight = 0.0
	for tree_data in tree_variations:
		total_weight += tree_data.rarity
	
	# Generate random value
	var random_value = randf() * total_weight
	
	# Select tree based on weight
	var current_weight = 0.0
	for tree_data in tree_variations:
		current_weight += tree_data.rarity
		if random_value <= current_weight:
			return tree_data
	
	# Fallback to first tree
	return tree_variations[0]

func get_tree_variation_by_name(name: String) -> TreeData:
	"""Get a specific tree variation by name"""
	for tree_data in tree_variations:
		if tree_data.name == name:
			return tree_data
	return null

func get_all_tree_variations() -> Array[TreeData]:
	"""Get all available tree variations"""
	return tree_variations.duplicate() 