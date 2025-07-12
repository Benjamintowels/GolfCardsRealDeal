extends Resource
class_name GrassData

# Grass data resource for different grass variations
@export var name: String = "Default Grass"
@export var sprite_texture: Texture2D
@export var rarity: float = 1.0  # Weight for random selection (higher = more common)
@export var description: String = "A grass patch"
@export var height: float = 15.0  # Height for Y-sorting
@export var seasons: Array[String] = ["summer"]  # Which seasons this grass appears in

func get_display_name() -> String:
	"""Get the display name for this grass variant"""
	return name

func get_height() -> float:
	"""Get the height of this grass for Y-sorting"""
	return height

func is_seasonal_variant(season: String) -> bool:
	"""Check if this grass variant appears in the given season"""
	return seasons.has(season) 