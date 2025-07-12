extends Resource
class_name BushData

# Bush data resource for different bush variations
@export var name: String = "Default Bush"
@export var sprite_texture: Texture2D
@export var collision_radius: float = 38.0
@export var height: float = 47.0
@export var velocity_damping_factor: float = 0.6
@export var leaves_rustle_sound: AudioStream
@export var is_dense: bool = true
@export var wind_resistance: float = 1.0
@export var rarity: float = 1.0  # Weight for random selection
@export var seasons: Array[String] = ["summer"]  # Which seasons this bush appears in

func get_collision_radius() -> float:
	return collision_radius

func get_height() -> float:
	return height

func get_velocity_damping_factor() -> float:
	return velocity_damping_factor

func get_leaves_rustle_sound() -> AudioStream:
	return leaves_rustle_sound

func is_seasonal_variant(season: String) -> bool:
	return seasons.has(season)
