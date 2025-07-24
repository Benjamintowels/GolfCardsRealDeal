extends Node
class_name FlowerManager

# Import FlowerData for flower variations
const FlowerData = preload("res://Obstacles/FlowerData.gd")

# Array of all available flower variations
var flower_variations: Array[FlowerData] = []

func _ready():
	_load_flower_variations()

func _load_flower_variations():
	"""Load all flower variations from the FlowerVariations folder"""
	var dir = DirAccess.open("res://Obstacles/FlowerVariations")
	if not dir:
		print("✗ ERROR: Could not open FlowerVariations directory")
		print("📁 Creating FlowerVariations directory...")
		# Try to create the directory
		var base_dir = DirAccess.open("res://Obstacles")
		if base_dir:
			base_dir.make_dir("FlowerVariations")
			print("✓ Created FlowerVariations directory")
		else:
			print("✗ Failed to create FlowerVariations directory")
		return
	
	# Load all .tres files in the FlowerVariations folder
	for file in dir.get_files():
		if file.ends_with(".tres"):
			var flower_data = load("res://Obstacles/FlowerVariations/" + file) as FlowerData
			if flower_data:
				flower_variations.append(flower_data)
				print("✓ Loaded flower variation:", flower_data.name)
			else:
				print("✗ Failed to load flower variation from:", file)
	
	# If no flower variations found, create a default one
	if flower_variations.is_empty():
		print("📁 No flower variations found, creating default sunflower...")
		_create_default_flower_data()
	
	print("✓ Loaded", flower_variations.size(), "flower variations")

func _create_default_flower_data():
	"""Create a default flower data if no variations are found"""
	var default_flower = FlowerData.new()
	default_flower.name = "Sunflower"
	default_flower.collision_radius = 24.0
	default_flower.height = 55.0
	default_flower.velocity_damping_factor = 0.7
	default_flower.is_dense = false
	default_flower.wind_resistance = 0.8
	default_flower.rarity = 1.0
	var seasons_array: Array[String] = ["summer"]
	default_flower.seasons = seasons_array
	
	# Try to load the sunflower texture
	var sunflower_texture = load("res://Obstacles/Flowers/Sunflower.png")
	if sunflower_texture:
		default_flower.sprite_texture = sunflower_texture
	
	# Try to load the rustle sound
	var rustle_sound = load("res://Sounds/LeavesRustle.mp3")
	if rustle_sound:
		default_flower.rustle_sound = rustle_sound
	
	flower_variations.append(default_flower)
	print("✓ Created default sunflower variation")

func get_random_flower_data() -> FlowerData:
	"""Get a random flower variation based on rarity weights"""
	if flower_variations.is_empty():
		print("✗ No flower variations loaded!")
		return null
	
	# Calculate total weight
	var total_weight = 0.0
	for flower_data in flower_variations:
		total_weight += flower_data.rarity
	
	# Generate random value
	var random_value = randf() * total_weight
	
	# Select flower based on weight
	var current_weight = 0.0
	for flower_data in flower_variations:
		current_weight += flower_data.rarity
		if random_value <= current_weight:
			return flower_data
	
	# Fallback to first flower
	return flower_variations[0]

func get_flower_variation_by_name(name: String) -> FlowerData:
	"""Get a specific flower variation by name"""
	for flower_data in flower_variations:
		if flower_data.name == name:
			return flower_data
	return null

func get_flower_variations_by_season(season: String) -> Array[FlowerData]:
	"""Get all flower variations for a specific season"""
	var seasonal_flowers: Array[FlowerData] = []
	for flower_data in flower_variations:
		if flower_data.is_seasonal_variant(season):
			seasonal_flowers.append(flower_data)
	return seasonal_flowers

func get_random_flower_data_for_season(season: String) -> FlowerData:
	"""Get a random flower variation for a specific season"""
	var seasonal_flowers = get_flower_variations_by_season(season)
	if seasonal_flowers.is_empty():
		# Fallback to any flower if no seasonal variants found
		return get_random_flower_data()
	
	# Calculate total weight for seasonal flowers
	var total_weight = 0.0
	for flower_data in seasonal_flowers:
		total_weight += flower_data.rarity
	
	# Generate random value
	var random_value = randf() * total_weight
	
	# Select flower based on weight
	var current_weight = 0.0
	for flower_data in seasonal_flowers:
		current_weight += flower_data.rarity
		if random_value <= current_weight:
			return flower_data
	
	# Fallback to first seasonal flower
	return seasonal_flowers[0]

func get_all_flower_variations() -> Array[FlowerData]:
	"""Get all available flower variations"""
	return flower_variations.duplicate()

func get_dense_flowers() -> Array[FlowerData]:
	"""Get all dense flower variations"""
	var dense_flowers: Array[FlowerData] = []
	for flower_data in flower_variations:
		if flower_data.is_dense:
			dense_flowers.append(flower_data)
	return dense_flowers

func get_sparse_flowers() -> Array[FlowerData]:
	"""Get all sparse (non-dense) flower variations"""
	var sparse_flowers: Array[FlowerData] = []
	for flower_data in flower_variations:
		if not flower_data.is_dense:
			sparse_flowers.append(flower_data)
	return sparse_flowers 
