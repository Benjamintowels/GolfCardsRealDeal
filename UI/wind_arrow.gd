extends Node2D

# Wind arrow visual indicator for weather system
# Displays current wind direction and intensity

const WeatherManager = preload("res://WeatherManager.gd")

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

# Weather manager reference
var weather_manager: WeatherManager = null

func _ready():
	# Try multiple ways to find the weather manager
	weather_manager = get_node_or_null("/root/WeatherManager")
	if not weather_manager:
		# Try to find it in the current scene
		weather_manager = get_tree().get_first_node_in_group("weather_manager")
	if not weather_manager:
		# Try to find it by searching the entire scene tree
		weather_manager = find_weather_manager_in_tree(get_tree().root)
	
	if weather_manager:
		# Connect to wind changed signal
		if not weather_manager.wind_changed.is_connected(_on_wind_changed):
			weather_manager.wind_changed.connect(_on_wind_changed)
		
		# Update display with current wind
		var direction = weather_manager.get_wind_direction()
		var intensity = weather_manager.get_wind_intensity()
		update_wind_display(direction, intensity)
	else:
		# Try again after a short delay in case WeatherManager is created later
		await get_tree().create_timer(1.0).timeout
		_retry_weather_manager_connection()

func _retry_weather_manager_connection():
	"""Retry connecting to WeatherManager after a delay"""
	weather_manager = get_node_or_null("/root/WeatherManager")
	if not weather_manager:
		weather_manager = get_tree().get_first_node_in_group("weather_manager")
	if not weather_manager:
		weather_manager = find_weather_manager_in_tree(get_tree().root)
	
	if weather_manager:
		# Connect to wind changed signal
		if not weather_manager.wind_changed.is_connected(_on_wind_changed):
			weather_manager.wind_changed.connect(_on_wind_changed)
		
		# Update display with current wind
		var direction = weather_manager.get_wind_direction()
		var intensity = weather_manager.get_wind_intensity()
		update_wind_display(direction, intensity)

func find_weather_manager_in_tree(node: Node) -> WeatherManager:
	"""Recursively search for WeatherManager in the scene tree"""
	if node is WeatherManager:
		return node
	
	for child in node.get_children():
		var result = find_weather_manager_in_tree(child)
		if result:
			return result
	
	return null

func _on_wind_changed(direction: Vector2, intensity: float):
	"""Called when wind conditions change"""
	update_wind_display(direction, intensity)

func update_wind_display(direction: Vector2, intensity: float):
	"""Update the visual display of wind information"""
	# Rotate sprite to face wind direction
	if sprite:
		var angle = atan2(direction.y, direction.x)
		sprite.rotation = angle
	
	# Update label with wind intensity
	if label:
		if intensity < 0.1:
			label.text = "No wind"
		else:
			label.text = "%.0f mph" % intensity
