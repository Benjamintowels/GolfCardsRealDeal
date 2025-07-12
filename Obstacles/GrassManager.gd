extends Node
class_name GrassManager

# Import GrassData for grass variations
const GrassData = preload("res://Obstacles/GrassData.gd")

# Array of all available grass variations
var grass_variations: Array[GrassData] = []

func _ready():
	_load_grass_variations()

func _load_grass_variations():
	"""Load all grass variations from the GrassVariations folder"""
	var dir = DirAccess.open("res://Obstacles/GrassVariations")
	if not dir:
		print("✗ ERROR: Could not open GrassVariations directory")
		return
	
	# Load all .tres files in the GrassVariations folder
	for file in dir.get_files():
		if file.ends_with(".tres"):
			var grass_data = load("res://Obstacles/GrassVariations/" + file) as GrassData
			if grass_data:
				grass_variations.append(grass_data)
				print("✓ Loaded grass variation:", grass_data.name)
			else:
				print("✗ Failed to load grass variation from:", file)
	
	print("✓ Loaded", grass_variations.size(), "grass variations")

func get_random_grass_data() -> GrassData:
	"""Get a random grass variation based on rarity weights"""
	if grass_variations.is_empty():
		print("✗ No grass variations loaded!")
		return null
	
	# Calculate total weight
	var total_weight = 0.0
	for grass_data in grass_variations:
		total_weight += grass_data.rarity
	
	# Generate random value
	var random_value = randf() * total_weight
	
	# Select grass based on weight
	var current_weight = 0.0
	for grass_data in grass_variations:
		current_weight += grass_data.rarity
		if random_value <= current_weight:
			return grass_data
	
	# Fallback to first grass
	return grass_variations[0]

func get_grass_variation_by_name(name: String) -> GrassData:
	"""Get a specific grass variation by name"""
	for grass_data in grass_variations:
		if grass_data.name == name:
			return grass_data
	return null

func get_grass_variations_by_season(season: String) -> Array[GrassData]:
	"""Get all grass variations for a specific season"""
	var seasonal_grass: Array[GrassData] = []
	for grass_data in grass_variations:
		if grass_data.is_seasonal_variant(season):
			seasonal_grass.append(grass_data)
	return seasonal_grass

func get_random_grass_data_for_season(season: String) -> GrassData:
	"""Get a random grass variation for a specific season"""
	var seasonal_grass = get_grass_variations_by_season(season)
	if seasonal_grass.is_empty():
		# Fallback to any grass if no seasonal variants found
		return get_random_grass_data()
	
	# Calculate total weight for seasonal grass
	var total_weight = 0.0
	for grass_data in seasonal_grass:
		total_weight += grass_data.rarity
	
	# Generate random value
	var random_value = randf() * total_weight
	
	# Select grass based on weight
	var current_weight = 0.0
	for grass_data in seasonal_grass:
		current_weight += grass_data.rarity
		if random_value <= current_weight:
			return grass_data
	
	# Fallback to first seasonal grass
	return seasonal_grass[0]

func get_all_grass_variations() -> Array[GrassData]:
	"""Get all available grass variations"""
	return grass_variations.duplicate() 