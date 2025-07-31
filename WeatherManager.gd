extends Node
class_name WeatherManager

# Weather system for golf game
# Handles wind factors and other weather effects

signal wind_changed(direction: Vector2, intensity: float)

# Wind factor properties
var wind_direction: Vector2 = Vector2.ZERO
var wind_intensity: float = 0.0  # 0-30 mph
var wind_force: Vector2 = Vector2.ZERO  # Calculated wind force vector

# Wind influence on projectiles
var wind_influence_factor: float = 0.2  # How much wind affects projectiles (0.0-1.0)

# Wind intensity ranges by hole set
var front_9_max_wind: float = 10.0  # Front 9 holes: 0-10 mph
var back_9_max_wind: float = 30.0   # Back 9 holes: 0-30 mph

# Weather state
var is_wind_active: bool = false

func _ready():
	# Initialize with no wind
	generate_new_wind_factor()

func generate_new_wind_factor(hole_index: int = -1):
	"""Generate a new random wind factor for the current hole"""
	randomize()
	
	# Random direction (0-360 degrees)
	var angle = randf() * TAU
	wind_direction = Vector2(cos(angle), sin(angle))
	
	# Determine wind intensity range based on hole set
	var max_wind_intensity: float
	if hole_index >= 0 and hole_index < 9:
		# Front 9 holes (0-8): 0-10 mph
		max_wind_intensity = front_9_max_wind
	else:
		# Back 9 holes (9-17): 0-30 mph
		max_wind_intensity = back_9_max_wind
	
	# Random intensity based on hole set
	wind_intensity = randf() * max_wind_intensity
	
	# Calculate wind force vector
	wind_force = wind_direction * wind_intensity
	
	is_wind_active = wind_intensity > 0.1  # Consider wind active if > 0.1 mph
	
	# Emit signal for UI updates
	emit_signal("wind_changed", wind_direction, wind_intensity)

func get_wind_direction() -> Vector2:
	"""Get the current wind direction as a normalized vector"""
	return wind_direction

func get_wind_intensity() -> float:
	"""Get the current wind intensity in mph"""
	return wind_intensity

func get_wind_force() -> Vector2:
	"""Get the calculated wind force vector"""
	return wind_force

func apply_wind_to_projectile(projectile_velocity: Vector2, delta: float) -> Vector2:
	"""Apply wind influence to a projectile's velocity"""
	if not is_wind_active:
		return projectile_velocity
	
	# Calculate wind effect based on intensity and influence factor
	# Make the effect much more dramatic by using a larger multiplier
	var wind_effect = wind_force * wind_influence_factor * delta * 10.0  # 10x multiplier for dramatic effect
	
	# Apply wind effect to projectile velocity
	var new_velocity = projectile_velocity + wind_effect
	
	return new_velocity

func is_wind_affecting_launches() -> bool:
	"""Check if wind is currently affecting launches"""
	return is_wind_active

func get_wind_description() -> String:
	"""Get a human-readable description of current wind conditions"""
	if not is_wind_active:
		return "No wind"
	
	var direction_text = ""
	var angle_degrees = rad_to_deg(atan2(wind_direction.y, wind_direction.x))
	
	# Convert angle to cardinal directions
	if angle_degrees >= -22.5 and angle_degrees < 22.5:
		direction_text = "East"
	elif angle_degrees >= 22.5 and angle_degrees < 67.5:
		direction_text = "Northeast"
	elif angle_degrees >= 67.5 and angle_degrees < 112.5:
		direction_text = "North"
	elif angle_degrees >= 112.5 and angle_degrees < 157.5:
		direction_text = "Northwest"
	elif angle_degrees >= 157.5 or angle_degrees < -157.5:
		direction_text = "West"
	elif angle_degrees >= -157.5 and angle_degrees < -112.5:
		direction_text = "Southwest"
	elif angle_degrees >= -112.5 and angle_degrees < -67.5:
		direction_text = "South"
	elif angle_degrees >= -67.5 and angle_degrees < -22.5:
		direction_text = "Southeast"
	
	return "%s wind at %.1f mph" % [direction_text, wind_intensity]

 