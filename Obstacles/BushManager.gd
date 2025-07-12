extends Node
class_name BushManager

# Import BushData for bush variations
const BushData = preload("res://Obstacles/BushData.gd")

# Array of all available bush variations
var bush_variations: Array[BushData] = []

func _ready():
	_load_bush_variations()

func _load_bush_variations():
	"""Load all bush variations from the BushVariations folder"""
	var dir = DirAccess.open("res://Obstacles/BushVariations")
	if not dir:
		print("✗ ERROR: Could not open BushVariations directory")
		return
	
	# Load all .tres files in the BushVariations folder
	for file in dir.get_files():
		if file.ends_with(".tres"):
			var bush_data = load("res://Obstacles/BushVariations/" + file) as BushData
			if bush_data:
				bush_variations.append(bush_data)
				print("✓ Loaded bush variation:", bush_data.name)
			else:
				print("✗ Failed to load bush variation from:", file)
	
	print("✓ Loaded", bush_variations.size(), "bush variations")

func get_random_bush_data() -> BushData:
	"""Get a random bush variation based on rarity weights"""
	if bush_variations.is_empty():
		print("✗ No bush variations loaded!")
		return null
	
	# Calculate total weight
	var total_weight = 0.0
	for bush_data in bush_variations:
		total_weight += bush_data.rarity
	
	# Generate random value
	var random_value = randf() * total_weight
	
	# Select bush based on weight
	var current_weight = 0.0
	for bush_data in bush_variations:
		current_weight += bush_data.rarity
		if random_value <= current_weight:
			return bush_data
	
	# Fallback to first bush
	return bush_variations[0]

func get_bush_variation_by_name(name: String) -> BushData:
	"""Get a specific bush variation by name"""
	for bush_data in bush_variations:
		if bush_data.name == name:
			return bush_data
	return null

func get_bush_variations_by_season(season: String) -> Array[BushData]:
	"""Get all bush variations for a specific season"""
	var seasonal_bushes: Array[BushData] = []
	for bush_data in bush_variations:
		if bush_data.is_seasonal_variant(season):
			seasonal_bushes.append(bush_data)
	return seasonal_bushes

func get_random_bush_data_for_season(season: String) -> BushData:
	"""Get a random bush variation for a specific season"""
	var seasonal_bushes = get_bush_variations_by_season(season)
	if seasonal_bushes.is_empty():
		# Fallback to any bush if no seasonal variants found
		return get_random_bush_data()
	
	# Calculate total weight for seasonal bushes
	var total_weight = 0.0
	for bush_data in seasonal_bushes:
		total_weight += bush_data.rarity
	
	# Generate random value
	var random_value = randf() * total_weight
	
	# Select bush based on weight
	var current_weight = 0.0
	for bush_data in seasonal_bushes:
		current_weight += bush_data.rarity
		if random_value <= current_weight:
			return bush_data
	
	# Fallback to first seasonal bush
	return seasonal_bushes[0]

func get_all_bush_variations() -> Array[BushData]:
	"""Get all available bush variations"""
	return bush_variations.duplicate()

func get_dense_bushes() -> Array[BushData]:
	"""Get all dense bush variations"""
	var dense_bushes: Array[BushData] = []
	for bush_data in bush_variations:
		if bush_data.is_dense:
			dense_bushes.append(bush_data)
	return dense_bushes

func get_sparse_bushes() -> Array[BushData]:
	"""Get all sparse (non-dense) bush variations"""
	var sparse_bushes: Array[BushData] = []
	for bush_data in bush_variations:
		if not bush_data.is_dense:
			sparse_bushes.append(bush_data)
	return sparse_bushes 
