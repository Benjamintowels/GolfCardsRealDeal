extends Control

@onready var power_bar: ProgressBar = $PowerBarContainer/PowerBar
@onready var sweet_spot_indicator: ColorRect = $PowerBarContainer/SweetSpotIndicator
@onready var power_label: Label = $PowerLabel

signal power_changed(power_value: float)
signal sweet_spot_hit

var current_power: float = 0.0
var max_power: float = 100.0
var sweet_spot_min: float = 70.0
var sweet_spot_max: float = 85.0
var is_active: bool = false
var is_preview_mode: bool = false
var power_increment: float = 2.0
var power_direction: int = 1  # 1 for increasing, -1 for decreasing

func _ready():
	# Initialize the power meter
	update_power_display()
	position_sweet_spot()
	
	# Set up the progress bar appearance
	power_bar.max_value = max_power
	power_bar.value = current_power
	
	# Hide initially
	visible = false

func _process(delta):
	if is_active and not is_preview_mode:
		update_power(delta)

func start_power_meter():
	is_active = true
	is_preview_mode = false
	current_power = 0.0
	power_direction = 1
	visible = true
	update_power_display()

func start_preview_mode():
	"""Start preview mode - shows sweet spot but doesn't animate power bar"""
	is_active = true
	is_preview_mode = true
	current_power = 0.0
	visible = true
	update_power_display()

func stop_power_meter():
	is_active = false
	visible = false
	power_changed.emit(current_power)
	
	# Check if sweet spot was hit
	if current_power >= sweet_spot_min and current_power <= sweet_spot_max:
		sweet_spot_hit.emit()

func update_power(delta):
	current_power += power_increment * power_direction * delta * 60  # 60 FPS compensation
	
	# Reverse direction at boundaries
	if current_power >= max_power:
		current_power = max_power
		power_direction = -1
	elif current_power <= 0:
		current_power = 0
		power_direction = 1
	
	update_power_display()

func update_power_display():
	if is_preview_mode:
		# In preview mode, show empty bar with sweet spot indicator
		power_bar.value = 0.0
		power_label.text = "---"
		power_bar.modulate = Color.WHITE  # Neutral color
	else:
		# Normal mode - show animated power bar
		power_bar.value = current_power
		power_label.text = str(int(current_power)) + "%"
		
		# Update color based on power level
		var color_ratio = current_power / max_power
		if color_ratio <= 0.5:
			power_bar.modulate = lerp(Color.GREEN, Color.YELLOW, color_ratio * 2)
		else:
			power_bar.modulate = lerp(Color.YELLOW, Color.RED, (color_ratio - 0.5) * 2)

func position_sweet_spot():
	# Position the sweet spot indicator based on the sweet spot range
	var sweet_spot_center = (sweet_spot_min + sweet_spot_max) / 2.0
	var sweet_spot_ratio = sweet_spot_center / max_power
	
	# Calculate position within the power bar container
	var container_width = $PowerBarContainer.size.x
	var sweet_spot_x = sweet_spot_ratio * container_width
	
	sweet_spot_indicator.position.x = sweet_spot_x - sweet_spot_indicator.size.x / 2

func set_sweet_spot_range(min_value: float, max_value: float):
	sweet_spot_min = min_value
	sweet_spot_max = max_value
	position_sweet_spot()

func set_sweet_spot_position(x_position: float):
	"""Set the sweet spot indicator to a specific X position"""
	sweet_spot_indicator.position.x = x_position - sweet_spot_indicator.size.x / 2

func set_power_increment(increment: float):
	power_increment = increment

func get_current_power() -> float:
	return current_power

func is_sweet_spot_hit() -> bool:
	return current_power >= sweet_spot_min and current_power <= sweet_spot_max 
