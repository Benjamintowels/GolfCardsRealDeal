extends Node2D

var meter_bg: ColorRect
var sweet_spot: ColorRect
var meter_fill: ColorRect
var current_height: float = 0.0
var max_height: float = 100.0
var sweet_spot_min: float = 0.3  # 30% of max
var sweet_spot_max: float = 0.5  # 50% of max

func _ready():
	# Create meter background
	meter_bg = ColorRect.new()
	meter_bg.color = Color(0.3, 0.3, 0.3, 0.8)
	meter_bg.size = Vector2(8, 60)
	meter_bg.position = Vector2(-4, -30)  # Center on the Node2D
	meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(meter_bg)
	
	# Create sweet spot indicator
	sweet_spot = ColorRect.new()
	sweet_spot.color = Color(0, 1, 0, 0.6)
	sweet_spot.size = Vector2(8, 12)  # 20% of 60 pixels
	sweet_spot.position = Vector2(-4, -30 + 18)  # 30% of 60 = 18 pixels from top
	sweet_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sweet_spot)
	
	# Create meter fill
	meter_fill = ColorRect.new()
	meter_fill.color = Color(0, 0, 1, 0.9)
	meter_fill.size = Vector2(8, 0)
	meter_fill.position = Vector2(-4, 30)  # Start from bottom
	meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(meter_fill)
	
	# Show the background and sweet spot by default, but hide the fill
	visible = true
	meter_fill.visible = false

func update_height(height: float, max_h: float = 100.0):
	current_height = height
	max_height = max_h
	
	# Update sweet spot position based on max height
	var sweet_spot_height = 12.0  # 20% of meter height
	var sweet_spot_start = (sweet_spot_min * 60.0) - 30.0  # Convert to local coordinates
	sweet_spot.position.y = sweet_spot_start
	
	# Update meter fill (grows from bottom up)
	var fill_height = (height / max_height) * 60.0
	meter_fill.size.y = fill_height
	meter_fill.position.y = 30 - fill_height  # Position from bottom
	
	# Show the fill when height is being charged
	meter_fill.visible = height > 0.0

func hide_meter():
	meter_fill.visible = false
	current_height = 0.0
	meter_fill.size.y = 0 