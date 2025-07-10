extends Node2D

var meter_bg: ColorRect
var sweet_spot: ColorRect
var meter_fill: ColorRect
var current_power: float = 0.0
var max_power: float = 100.0
var sweet_spot_min: float = 0.6  # 60% of max
var sweet_spot_max: float = 0.8  # 80% of max

func _ready():
	# Create meter background
	meter_bg = ColorRect.new()
	meter_bg.color = Color(0.3, 0.3, 0.3, 0.8)
	meter_bg.size = Vector2(60, 8)
	meter_bg.position = Vector2(-30, -4)  # Center on the Node2D
	meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(meter_bg)
	
	# Create sweet spot indicator
	sweet_spot = ColorRect.new()
	sweet_spot.color = Color(0, 1, 0, 0.6)
	sweet_spot.size = Vector2(12, 8)  # 20% of 60 pixels
	sweet_spot.position = Vector2(-30 + 36, -4)  # 60% of 60 = 36 pixels from left
	sweet_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sweet_spot)
	
	# Create meter fill
	meter_fill = ColorRect.new()
	meter_fill.color = Color(1, 0, 0, 0.9)
	meter_fill.size = Vector2(0, 8)
	meter_fill.position = Vector2(-30, -4)
	meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(meter_fill)
	
	# Show the background and sweet spot by default, but hide the fill
	visible = true
	meter_fill.visible = false

func update_power(power: float, max_p: float = 100.0):
	current_power = power
	max_power = max_p
	
	# Update sweet spot position based on max power
	var sweet_spot_width = 12.0  # 20% of meter width
	var sweet_spot_start = (sweet_spot_min * 60.0) - 30.0  # Convert to local coordinates
	sweet_spot.position.x = sweet_spot_start
	
	# Update meter fill
	var fill_width = (power / max_power) * 60.0
	meter_fill.size.x = fill_width
	
	# Show the fill when power is being charged
	meter_fill.visible = power > 0.0

func hide_meter():
	meter_fill.visible = false
	current_power = 0.0
	meter_fill.size.x = 0 