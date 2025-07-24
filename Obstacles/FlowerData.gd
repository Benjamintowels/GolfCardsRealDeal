extends Resource
class_name FlowerData

# Flower data resource for different flower variations
@export var name: String = "Default Flower"
@export var sprite_texture: Texture2D
@export var collision_radius: float = 24.0  # Smaller than bushes
@export var height: float = 55.0  # Slightly taller than bushes
@export var velocity_damping_factor: float = 0.7  # Less damping than bushes
@export var rustle_sound: AudioStream  # Flowers can have their own rustle sounds
@export var is_dense: bool = false  # Flowers are typically not dense
@export var wind_resistance: float = 0.8  # Less wind resistance than bushes
@export var rarity: float = 1.0  # Weight for random selection
@export var seasons: Array[String] = ["summer"]  # Which seasons this flower appears in

func get_collision_radius() -> float:
	return collision_radius

func get_height() -> float:
	return height

func get_velocity_damping_factor() -> float:
	return velocity_damping_factor

func get_rustle_sound() -> AudioStream:
	return rustle_sound

func is_seasonal_variant(season: String) -> bool:
	return seasons.has(season) 