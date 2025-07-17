extends Node

# Driving Range Launch Manager - Specialized for driving range minigame
signal ball_landed(tile: Vector2i)
signal ball_out_of_bounds
signal ball_launched(ball: Node2D)

@onready var power_meter: Control
@onready var camera: Camera2D
@onready var camera_container: Control
@onready var ui_layer: Control

# Ball and launch variables
var golf_ball: Node2D = null
var chosen_landing_spot: Vector2 = Vector2.ZERO
var selected_club: String = ""
var club_data: Dictionary = {}
var cell_size: int = 48
var map_manager: Node = null
var player_grid_pos: Vector2i = Vector2i(8, 0)  # Default tee position

# Launch state - using same mechanics as main LaunchManager
var launch_phase: String = "height_selection"  # height_selection, power_selection, launching
var selected_height: float = 0.0
var selected_power: float = 0.0
var ball_in_flight: bool = false

# Launch constants (same as main LaunchManager)
const MAX_LAUNCH_POWER := 1200.0
const MIN_LAUNCH_POWER := 300.0
const POWER_CHARGE_RATE := 300.0 # units per second
const MAX_LAUNCH_HEIGHT := 480.0   # 10 cells (48 * 10) for pixel perfect system
const MIN_LAUNCH_HEIGHT := 0.0   # Allow for ground-level shots
const HEIGHT_CHARGE_RATE := 600.0  # Adjusted for pixel perfect system
const HEIGHT_SWEET_SPOT_MIN := 0.3 # 30% of max height - lower sweet spot for better arc
const HEIGHT_SWEET_SPOT_MAX := 0.5 # 50% of max height - narrower sweet spot
const HEIGHT_SELECTION_SENSITIVITY := 2.0  # How sensitive mouse movement is for height selection

# Charge time variables
var charge_time := 0.0  # Time spent charging (in seconds)
var max_charge_time := 1.0  # Maximum time to fully charge

# Launch variables
var launch_power := 0.0
var launch_height := 0.0
var launch_direction := Vector2.ZERO
var is_charging := false
var is_charging_height := false
var is_selecting_height := false
var current_charge_mouse_pos: Vector2 = Vector2.ZERO

# Power calculation variables
var power_for_target := 0.0
var max_power_for_bar := 0.0

# Height meter reference
var height_meter: Control = null

# Height selection variables (keeping for fallback)
var height_buttons: Array[Button] = []
var height_options: Array[float] = [0.0, 25.0, 50.0, 75.0, 100.0, 125.0, 150.0, 175.0, 200.0]

# Power selection variables (keeping for fallback)
var power_buttons: Array[Button] = []
var power_options: Array[float] = [25.0, 50.0, 75.0, 100.0]

func _ready():
	print("DrivingRangeLaunchManager initialized")

func _process(delta: float):
	if is_charging:
		charge_time = min(charge_time + delta, max_charge_time)
		
		if power_meter:
			var meter_fill = power_meter.get_node_or_null("MeterFill")
			var value_label = power_meter.get_node_or_null("PowerValue")
			var time_percent = charge_time / max_charge_time
			time_percent = clamp(time_percent, 0.0, 1.0)
			
			if meter_fill:
				# Update the width of the meter fill instead of scaling
				var max_width = 300.0  # Width of the meter background
				meter_fill.size.x = time_percent * max_width
			if value_label:
				var scaled_min_power = power_meter.get_meta("scaled_min_power", MIN_LAUNCH_POWER)
				var scaled_max_power = power_meter.get_meta("max_power_for_bar", MAX_LAUNCH_POWER)
				var current_power = scaled_min_power + (time_percent * (scaled_max_power - scaled_min_power))
				value_label.text = str(int(current_power))
	
	elif is_charging_height:
		# Check if this club has a fixed height
		var fixed_height = club_data.get(selected_club, {}).get("fixed_height", -1.0)
		if fixed_height >= 0.0:
			# Don't charge height for clubs with fixed height
			launch_height = fixed_height
		else:
			# Get club-specific max height
			var club_max_height = club_data.get(selected_club, {}).get("max_height", MAX_LAUNCH_HEIGHT)
			launch_height = min(launch_height + HEIGHT_CHARGE_RATE * delta, club_max_height)
		
		if height_meter:
			var meter_fill = height_meter.get_node_or_null("MeterFill")
			var value_label = height_meter.get_node_or_null("HeightValue")
			
			# Get club-specific height range
			var club_min_height = club_data.get(selected_club, {}).get("min_height", 0.0)
			var club_max_height = club_data.get(selected_club, {}).get("max_height", MAX_LAUNCH_HEIGHT)
			
			# Calculate height percentage based on club's range
			var height_percentage = 0.0
			if club_max_height > club_min_height:
				height_percentage = (launch_height - club_min_height) / (club_max_height - club_min_height)
			height_percentage = clamp(height_percentage, 0.0, 1.0)
			
			if meter_fill:
				# Update the height of the meter fill instead of scaling
				var max_height = 300.0  # Height of the meter background
				meter_fill.size.y = height_percentage * max_height
				# Keep the position at the bottom
				meter_fill.position.y = 330 - meter_fill.size.y
			if value_label:
				value_label.text = str(int(launch_height))
	
	elif is_selecting_height:
		# Update height meter display during height selection phase
		if height_meter:
			var meter_fill = height_meter.get_node_or_null("MeterFill")
			var value_label = height_meter.get_node_or_null("HeightValue")
			
			# Get club-specific height range
			var club_min_height = club_data.get(selected_club, {}).get("min_height", 0.0)
			var club_max_height = club_data.get(selected_club, {}).get("max_height", MAX_LAUNCH_HEIGHT)
			
			# Calculate height percentage based on club's range
			var height_percentage = 0.0
			if club_max_height > club_min_height:
				height_percentage = (launch_height - club_min_height) / (club_max_height - club_min_height)
			height_percentage = clamp(height_percentage, 0.0, 1.0)
			
			if meter_fill:
				# Update the height of the meter fill
				var max_height = 300.0  # Height of the meter background
				meter_fill.size.y = height_percentage * max_height
				# Keep the position at the bottom
				meter_fill.position.y = 330 - meter_fill.size.y
			if value_label:
				value_label.text = str(int(launch_height))

func setup(camera_ref: Camera2D, camera_container_ref: Control, ui_layer_ref: Control, 
		   power_meter_ref: Control, map_manager_ref: Node, cell_size_val: int, player_pos: Vector2i):
	"""Setup the launch manager with required references"""
	camera = camera_ref
	camera_container = camera_container_ref
	ui_layer = ui_layer_ref
	power_meter = power_meter_ref
	map_manager = map_manager_ref
	cell_size = cell_size_val
	player_grid_pos = player_pos
	
	print("DrivingRangeLaunchManager setup complete")

func set_ball(ball: Node2D):
	"""Set the golf ball reference"""
	# Disconnect signals from previous ball if it exists
	if golf_ball and is_instance_valid(golf_ball):
		if golf_ball.has_signal("landed"):
			golf_ball.landed.disconnect(_on_ball_landed)
		if golf_ball.has_signal("out_of_bounds"):
			golf_ball.out_of_bounds.disconnect(_on_ball_out_of_bounds)
	
	golf_ball = ball
	print("Golf ball set in DrivingRangeLaunchManager")

func set_launch_parameters(landing_spot: Vector2, club: String, club_data_dict: Dictionary):
	"""Set the launch parameters"""
	chosen_landing_spot = landing_spot
	selected_club = club
	club_data = club_data_dict
	print("Launch parameters set - Club:", club, "Landing spot:", landing_spot)

func enter_launch_phase():
	"""Enter the launch phase - use same mechanics as main LaunchManager"""
	print("Entering Driving Range launch phase")
	launch_phase = "height_selection"
	charge_time = 0.0
	
	# Set max_charge_time based on club and distance
	max_charge_time = 1.0  # Default charge time
	if chosen_landing_spot != Vector2.ZERO and selected_club in club_data:
		var distance_to_target = chosen_landing_spot.length()  # Simplified for driving range
		var club_max = club_data[selected_club]["max_distance"] if selected_club in club_data else MAX_LAUNCH_POWER
		# Adjust charge time based on distance - longer distance = shorter charge time
		var distance_factor = distance_to_target / club_max
		max_charge_time = 1.5 - (distance_factor * 1.0)  # 1.5-0.5 seconds based on distance
		max_charge_time = clamp(max_charge_time, 0.3, 1.5)  # Minimum 0.3 seconds, maximum 1.5 seconds
	
	var is_putting = club_data.get(selected_club, {}).get("is_putter", false)
	var fixed_height = club_data.get(selected_club, {}).get("fixed_height", -1.0)
	
	if fixed_height >= 0.0:
		# This club has a fixed height
		launch_height = fixed_height
		# Start with power charging immediately for fixed height clubs
		show_power_meter()
		var scaled_min_power = power_meter.get_meta("scaled_min_power", MIN_LAUNCH_POWER)
		launch_power = scaled_min_power
	else:
		if not is_putting:
			# Start with height selection phase
			show_height_meter()
			# Start at club's min height instead of 0
			var club_min_height = club_data.get(selected_club, {}).get("min_height", 0.0)
			launch_height = club_min_height
			is_selecting_height = true
		else:
			# Putters start with power charging immediately
			launch_height = 0.0
			show_power_meter()
			var scaled_min_power = power_meter.get_meta("scaled_min_power", MIN_LAUNCH_POWER)
			launch_power = scaled_min_power

func show_power_meter():
	"""Show power meter for charging"""
	print("Showing power meter")
	
	# Configure power calculation variables
	power_for_target = MIN_LAUNCH_POWER  # Default if no target
	max_power_for_bar = MAX_LAUNCH_POWER  # Default
	
	if chosen_landing_spot != Vector2.ZERO and selected_club in club_data:
		var distance_to_target = chosen_landing_spot.length()  # Simplified for driving range
		var club_max = club_data[selected_club]["max_distance"] if selected_club in club_data else MAX_LAUNCH_POWER
		power_for_target = min(distance_to_target, club_max)
		max_power_for_bar = club_max
		print("DrivingRangeLaunchManager: show_power_meter - calculated power_for_target:", power_for_target, " max_power_for_bar:", max_power_for_bar)
	
	# Set initial launch power
	launch_power = MIN_LAUNCH_POWER
	
	# Configure the PowerMeter for launch phase
	if power_meter.has_method("set_sweet_spot_position"):
		# Set sweet spot to specific position X 297.0
		power_meter.set_sweet_spot_position(297.0)
	
	if power_meter.has_method("set_power_increment"):
		power_meter.set_power_increment(3.0)  # Faster speed for launch phase
	
	# Start the power meter
	power_meter.start_power_meter()
	
	power_meter.set_meta("max_power_for_bar", max_power_for_bar)
	power_meter.set_meta("power_for_target", power_for_target)
	power_meter.set_meta("scaled_min_power", MIN_LAUNCH_POWER)

func hide_power_meter():
	"""Hide power meter"""
	if power_meter:
		# Stop the power meter before removing it
		if power_meter.has_method("stop_power_meter"):
			power_meter.stop_power_meter()
		power_meter.visible = false

func show_height_meter():
	"""Show height meter for height selection"""
	print("Showing height meter")
	
	if height_meter:
		height_meter.queue_free()
	
	# Get club-specific height range
	var club_min_height = club_data.get(selected_club, {}).get("min_height", 0.0)
	var club_max_height = club_data.get(selected_club, {}).get("max_height", MAX_LAUNCH_HEIGHT)
	
	height_meter = Control.new()
	height_meter.name = "HeightMeter"
	height_meter.size = Vector2(80, 350)
	height_meter.position = Vector2(433.675, 139.06) # Position from main LaunchManager
	height_meter.scale = Vector2(0.57, 0.57) # Scale from main LaunchManager
	ui_layer.add_child(height_meter)
	height_meter.z_index = 200
	
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.size = height_meter.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(background)
	
	var title_label := Label.new()
	title_label.text = "HEIGHT"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.position = Vector2(10, 5)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(title_label)
	
	var meter_bg := ColorRect.new()
	meter_bg.color = Color(0.3, 0.3, 0.3, 1.0)
	meter_bg.size = Vector2(30, 300)
	meter_bg.position = Vector2(25, 30)
	meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(meter_bg)
	
	var sweet_spot := ColorRect.new()
	sweet_spot.color = Color(0, 1, 0, 0.5)
	sweet_spot.size = Vector2(30, 60)  # 60 pixels height
	sweet_spot.position = Vector2(25, 30 + 90)  # 30% of 300 = 90 pixels from top
	sweet_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(sweet_spot)
	
	var meter_fill := ColorRect.new()
	meter_fill.color = Color(0, 0, 1, 1.0)
	meter_fill.size = Vector2(30, 0)  # Start with zero height, will be updated in _process
	meter_fill.position = Vector2(25, 330)  # Start from bottom
	meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_fill.name = "MeterFill"
	height_meter.add_child(meter_fill)
	
	var value_label := Label.new()
	value_label.text = str(int(club_min_height))
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.position = Vector2(10, 340)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.name = "HeightValue"
	height_meter.add_child(value_label)
	
	# Add min and max labels
	var min_label := Label.new()
	min_label.text = str(int(club_min_height))
	min_label.add_theme_font_size_override("font_size", 10)
	min_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	min_label.position = Vector2(-15, 330)  # Position to the left of the meter
	min_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(min_label)
	
	var max_label := Label.new()
	max_label.text = str(int(club_max_height))
	max_label.add_theme_font_size_override("font_size", 10)
	max_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	max_label.position = Vector2(-15, 30)  # Position to the left of the meter at top
	max_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	height_meter.add_child(max_label)

func hide_height_meter():
	"""Hide height meter"""
	if height_meter:
		height_meter.queue_free()
		height_meter = null

func handle_input(event: InputEvent) -> bool:
	"""Handle input events for launch mechanics. Returns true if event was handled."""
	
	# Check if a ball is available for launch - if not, don't allow new launches
	if not is_ball_available_for_launch():
		return false
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_selecting_height:
					# Height selection phase: left click confirms height and starts power charging
					is_selecting_height = false
					hide_height_meter()
					show_power_meter()
					is_charging = true
					charge_time = 0.0
					current_charge_mouse_pos = camera.get_global_mouse_position()
					print("DrivingRangeLaunchManager: Height selection confirmed. Starting power charging.")
					return true
				elif not is_charging and not is_charging_height:
					# Start power charging (for putters or fixed height clubs)
					is_charging = true
					charge_time = 0.0
					current_charge_mouse_pos = camera.get_global_mouse_position()
					return true
			else:
				if is_charging:
					is_charging = false
					print("DrivingRangeLaunchManager: Power charging finished. Launching ball.")
					# Get power from PowerMeter if available, otherwise use calculated power
					var final_power = launch_power
					if power_meter and power_meter.has_method("get_current_power"):
						var power_percentage = power_meter.get_current_power()
						final_power = (power_percentage / 100.0) * max_power_for_bar
					else:
						final_power = calculate_final_power()
					
					launch_direction = calculate_launch_direction()
					launch_golf_ball(launch_direction, final_power, launch_height)
					hide_power_meter()
					return true
				elif is_charging_height:
					is_charging_height = false
					print("DrivingRangeLaunchManager: Height charging finished. Final height:", launch_height)
					# Get power from PowerMeter if available, otherwise use calculated power
					var final_power = launch_power
					if power_meter and power_meter.has_method("get_current_power"):
						var power_percentage = power_meter.get_current_power()
						final_power = (power_percentage / 100.0) * max_power_for_bar
					else:
						final_power = calculate_final_power()
					
					launch_direction = calculate_launch_direction()
					launch_golf_ball(launch_direction, final_power, launch_height)
					hide_power_meter()
					hide_height_meter()
					return true
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Cancel launch phase
			is_charging = false
			is_charging_height = false
			is_selecting_height = false
			hide_power_meter()
			hide_height_meter()
			return true
	
	elif event is InputEventMouseMotion:
		if is_selecting_height:
			# Handle height selection with mouse up/down movement
			var mouse_delta = event.relative
			var height_change = -mouse_delta.y * HEIGHT_SELECTION_SENSITIVITY  # Negative because up = higher height
			
			# Get club-specific height range
			var club_min_height = club_data.get(selected_club, {}).get("min_height", 0.0)
			var club_max_height = club_data.get(selected_club, {}).get("max_height", MAX_LAUNCH_HEIGHT)
			
			# Clamp height to club's specific range
			var old_height = launch_height
			launch_height = clamp(launch_height + height_change, club_min_height, club_max_height)
			
			return true
		elif is_charging or is_charging_height:
			current_charge_mouse_pos = camera.get_global_mouse_position()
			return true
	
	return false

func calculate_launch_direction() -> Vector2:
	"""Calculate the launch direction for driving range (always to the right)"""
	return Vector2.RIGHT

func calculate_final_power() -> float:
	"""Calculate the final power based on charge time and target distance"""
	var time_percent = charge_time / max_charge_time
	time_percent = clamp(time_percent, 0.0, 1.0)
	var actual_power = 0.0
	
	if chosen_landing_spot != Vector2.ZERO:
		var distance_to_target = chosen_landing_spot.length()  # Simplified for driving range
		var reference_distance = 1200.0  # Driver's max distance as reference
		var distance_factor = distance_to_target / reference_distance
		var ball_physics_factor = 0.8 + (distance_factor * 0.4)
		var base_power_per_distance = 0.6 + (distance_factor * 0.2)
		var base_power_for_target = distance_to_target * base_power_per_distance * ball_physics_factor
		
		var club_efficiency = 1.0
		if selected_club in club_data:
			var club_max = club_data[selected_club]["max_distance"]
			var efficiency_factor = 1200.0 / club_max
			club_efficiency = sqrt(efficiency_factor)
			club_efficiency = clamp(club_efficiency, 0.7, 1.5)
		
		var power_for_target = base_power_for_target * club_efficiency
		
		var is_putting = club_data.get(selected_club, {}).get("is_putter", false)
		if is_putting:
			var base_putter_power = 300.0
			actual_power = time_percent * base_putter_power
		elif time_percent <= 0.75:
			actual_power = (time_percent / 0.75) * power_for_target
			var trailoff_forgiveness = club_data[selected_club].get("trailoff_forgiveness", 0.5) if selected_club in club_data else 0.5
			var undercharge_factor = 1.0 - (time_percent / 0.75)
			var trailoff_penalty = undercharge_factor * (1.0 - trailoff_forgiveness)
			actual_power = actual_power * (1.0 - trailoff_penalty)
		else:
			var overcharge_bonus = ((time_percent - 0.75) / 0.25) * (0.25 * 800.0)
			actual_power = power_for_target + overcharge_bonus
	else:
		actual_power = time_percent * MAX_LAUNCH_POWER
	
	# Apply height resistance
	var club_max_height = club_data.get(selected_club, {}).get("max_height", MAX_LAUNCH_HEIGHT)
	var height_percentage = launch_height / club_max_height  # Use club-specific max height
	height_percentage = clamp(height_percentage, 0.0, 1.0)
	var height_resistance_multiplier = 1.0
	if height_percentage > HEIGHT_SWEET_SPOT_MAX:
		var excess_height = height_percentage - HEIGHT_SWEET_SPOT_MAX
		var max_excess = 1.0 - HEIGHT_SWEET_SPOT_MAX
		var resistance_factor = excess_height / max_excess
		height_resistance_multiplier = 1.0 - (resistance_factor * 0.5)
	
	var final_power = actual_power * height_resistance_multiplier
	
	return final_power

func launch_golf_ball(launch_direction: Vector2, final_power: float, height: float, launch_spin: float = 0.0, spin_strength_category: int = 0):
	"""Launch the golf ball with the specified parameters - using same method as main LaunchManager"""
	
	# Find the existing ball in the scene
	var existing_ball = null
	var balls = get_tree().get_nodes_in_group("balls")
	
	for ball in balls:
		if is_instance_valid(ball):
			existing_ball = ball
			break
	
	if not existing_ball:
		return
	
	# Use the existing ball
	golf_ball = existing_ball
	
	# Set ball properties
	golf_ball.chosen_landing_spot = chosen_landing_spot
	golf_ball.club_info = club_data[selected_club] if selected_club in club_data else {}
	var is_putting = club_data.get(selected_club, {}).get("is_putter", false)
	golf_ball.is_putting = is_putting
	
	# Calculate time percentage for the ball
	var time_percent = charge_time / max_charge_time
	time_percent = clamp(time_percent, 0.0, 1.0)
	golf_ball.time_percentage = time_percent
	
	# Connect to ball's landed signal
	if golf_ball.has_signal("landed"):
		golf_ball.landed.connect(_on_ball_landed)
	
	# Connect to ball's out_of_bounds signal
	if golf_ball.has_signal("out_of_bounds"):
		golf_ball.out_of_bounds.connect(_on_ball_out_of_bounds)
	
	# Launch the ball using the ball's launch method
	golf_ball.launch(launch_direction, final_power, height, launch_spin, spin_strength_category)
	
	# Set ball in flight state
	set_ball_in_flight(true)
	
	# Store reference
	self.golf_ball = golf_ball
	
	# Emit ball launched signal
	ball_launched.emit(golf_ball)
	
	# Exit launch phase to transition to ball flying phase
	exit_launch_phase()

func _on_ball_landed(tile: Vector2i):
	"""Handle ball landing - emit our own ball_landed signal"""
	print("DrivingRangeLaunchManager: Ball landed at tile:", tile)
	ball_landed.emit(tile)
	set_ball_in_flight(false)

func _on_ball_out_of_bounds():
	"""Handle ball going out of bounds - emit our own ball_out_of_bounds signal"""
	print("DrivingRangeLaunchManager: Ball went out of bounds.")
	ball_out_of_bounds.emit()
	set_ball_in_flight(false)

func exit_launch_phase():
	"""Exit the launch phase"""
	launch_phase = "complete"
	hide_power_meter()
	hide_height_meter()
	
	is_charging = false
	is_charging_height = false
	is_selecting_height = false

func is_ball_available_for_launch() -> bool:
	"""Check if there's a ball available for launching (not in flight and not landed)"""
	# First check the ball_in_flight variable - if true, ball is not available
	if ball_in_flight:
		return false
	
	# Check if we have a golf ball reference
	if golf_ball and is_instance_valid(golf_ball):
		if golf_ball.has_method("is_in_flight"):
			if golf_ball.is_in_flight():
				return false  # Ball is in flight, not available
		elif "landed_flag" in golf_ball:
			if golf_ball.landed_flag:
				return false  # Ball has landed, not available for launch
		elif "in_flight" in golf_ball:
			if golf_ball.in_flight:
				return false  # Ball is in flight, not available
		elif golf_ball.has_method("get_velocity"):
			var velocity = golf_ball.get_velocity()
			if velocity.length() > 0.1:
				return false  # Ball is moving, not available
		elif "velocity" in golf_ball:
			var velocity = golf_ball.velocity
			if velocity.length() > 0.1:
				return false  # Ball is moving, not available
	
	# Also check for any balls in the scene
	var balls = get_tree().get_nodes_in_group("balls")
	for ball in balls:
		if is_instance_valid(ball):
			if ball.has_method("is_in_flight"):
				if ball.is_in_flight():
					return false  # Ball is in flight, not available
			elif "landed_flag" in ball:
				if ball.landed_flag:
					return false  # Ball has landed, not available for launch
			elif "in_flight" in ball:
				if ball.in_flight:
					return false  # Ball is in flight, not available
			elif ball.has_method("get_velocity"):
				var velocity = ball.get_velocity()
				if velocity.length() > 0.1:
					return false  # Ball is moving, not available
			elif "velocity" in ball:
				var velocity = ball.velocity
				if velocity.length() > 0.1:
					return false  # Ball is moving, not available
	
	return true  # No balls are in flight or landed, so launch is available

func set_ball_in_flight(in_flight: bool):
	"""Set ball flight state"""
	ball_in_flight = in_flight

# Legacy functions for backward compatibility
func show_height_selection():
	"""Legacy height selection - now uses height meter"""
	enter_launch_phase()

func show_power_selection():
	"""Legacy power selection - now uses power meter"""
	# This is handled by the new system
	pass

func launch_ball():
	"""Legacy launch function - now uses launch_golf_ball"""
	# This is handled by the new system
	pass

func clear_launch_ui():
	"""Clear launch UI elements"""
	# Clear height selection
	for btn in height_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	height_buttons.clear()
	
	# Clear power selection
	for btn in power_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	power_buttons.clear()
	
	# Clear containers
	var height_container = ui_layer.get_node_or_null("HeightSelectionContainer")
	if height_container:
		height_container.queue_free()
	
	var power_container = ui_layer.get_node_or_null("PowerSelectionContainer")
	if power_container:
		power_container.queue_free()

func cleanup():
	"""Clean up the launch manager"""
	# Disconnect signals from ball if it exists
	if golf_ball and is_instance_valid(golf_ball):
		if golf_ball.has_signal("landed"):
			golf_ball.landed.disconnect(_on_ball_landed)
		if golf_ball.has_signal("out_of_bounds"):
			golf_ball.out_of_bounds.disconnect(_on_ball_out_of_bounds)
	
	clear_launch_ui()
	hide_power_meter()
	hide_height_meter()
	ball_in_flight = false
	launch_phase = "complete"
	
	print("DrivingRangeLaunchManager cleaned up") 