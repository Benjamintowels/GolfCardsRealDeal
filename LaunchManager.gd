extends Node
class_name LaunchManager

# Launch variables
var golf_ball: Node2D = null
var power_meter: Control = null
var height_meter: Control = null
var launch_power := 0.0
var launch_height := 0.0
var launch_direction := Vector2.ZERO
var is_charging := false
var is_charging_height := false

# Launch constants
const MAX_LAUNCH_POWER := 1200.0
const MIN_LAUNCH_POWER := 300.0
const POWER_CHARGE_RATE := 300.0 # units per second
const MAX_LAUNCH_HEIGHT := 2000.0  # Increased for better arc
const MIN_LAUNCH_HEIGHT := 500.0  # Increased minimum height
const HEIGHT_CHARGE_RATE := 1000.0 # Increased charge rate for faster height charging
const HEIGHT_SWEET_SPOT_MIN := 0.3 # 30% of max height - lower sweet spot for better arc
const HEIGHT_SWEET_SPOT_MAX := 0.5 # 50% of max height - narrower sweet spot

# Charge time variables
var charge_time := 0.0  # Time spent charging (in seconds)
var max_charge_time := 3.0  # Maximum time to fully charge (varies by distance)

# Spin variables
var original_aim_mouse_pos: Vector2 = Vector2.ZERO
var launch_spin: float = 0.0
var current_charge_mouse_pos: Vector2 = Vector2.ZERO

# Power calculation variables
var power_for_target := 0.0
var max_power_for_bar := 0.0

# References (to be set by parent)
var camera_container: Control
var ui_layer: Node
var player_node: Node2D
var cell_size: int
var chosen_landing_spot: Vector2
var selected_club: String
var club_data: Dictionary
var player_stats: Dictionary
var card_effect_handler: Node
var camera: Camera2D

# Signals
signal ball_launched(ball: Node2D)
signal launch_phase_entered
signal launch_phase_exited

func _ready():
	pass

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
	
	if is_charging_height:
		launch_height = min(launch_height + HEIGHT_CHARGE_RATE * delta, MAX_LAUNCH_HEIGHT)
		if height_meter:
			var meter_fill = height_meter.get_node_or_null("MeterFill")
			var value_label = height_meter.get_node_or_null("HeightValue")
			var height_percentage = (launch_height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
			height_percentage = clamp(height_percentage, 0.0, 1.0)
			
			if meter_fill:
				# Update the height of the meter fill instead of scaling
				var max_height = 300.0  # Height of the meter background
				meter_fill.size.y = height_percentage * max_height
				# Keep the position at the bottom
				meter_fill.position.y = 330 - meter_fill.size.y
			if value_label:
				value_label.text = str(int(launch_height))

func enter_launch_phase() -> void:
	"""Enter the launch phase for taking a shot"""
	emit_signal("launch_phase_entered")
	charge_time = 0.0
	original_aim_mouse_pos = camera.get_global_mouse_position()
	show_power_meter()
	
	# Set max_charge_time based on club and distance
	max_charge_time = 1.0  # Default charge time (reduced from 3.0)
	if chosen_landing_spot != Vector2.ZERO and selected_club in club_data:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var distance_to_target = player_center.distance_to(chosen_landing_spot)
		var club_max = club_data[selected_club]["max_distance"] if selected_club in club_data else MAX_LAUNCH_POWER
		# Adjust charge time based on distance - longer distance = shorter charge time
		var distance_factor = distance_to_target / club_max
		max_charge_time = 1.5 - (distance_factor * 1.0)  # 1.5-0.5 seconds based on distance (much faster!)
		max_charge_time = clamp(max_charge_time, 0.3, 1.5)  # Minimum 0.3 seconds, maximum 1.5 seconds
	
	var is_putting = club_data.get(selected_club, {}).get("is_putter", false)
	if not is_putting:
		show_height_meter()
		launch_height = MIN_LAUNCH_HEIGHT
	else:
		launch_height = 0.0
	
	var scaled_min_power = power_meter.get_meta("scaled_min_power", MIN_LAUNCH_POWER)
	launch_power = scaled_min_power
	
	if chosen_landing_spot != Vector2.ZERO:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var distance_to_target = player_center.distance_to(chosen_landing_spot)
	
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var tween := get_tree().create_tween()
	tween.tween_property(camera, "position", player_center, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Spin indicator removed
	pass

func exit_launch_phase() -> void:
	"""Exit the launch phase"""
	emit_signal("launch_phase_exited")
	hide_power_meter()
	hide_height_meter()
	is_charging = false
	is_charging_height = false

func launch_golf_ball(direction: Vector2, charged_power: float, height: float):
	# Check if scramble effect is active
	if card_effect_handler and card_effect_handler.is_scramble_active():
		# Clear any existing golf ball before launching scramble balls
		if golf_ball and is_instance_valid(golf_ball):
			golf_ball.queue_free()
			golf_ball = null
		
		# Calculate final power for scramble balls
		var time_percent = charge_time / max_charge_time
		time_percent = clamp(time_percent, 0.0, 1.0)
		var actual_power = 0.0
		
		if chosen_landing_spot != Vector2.ZERO:
			var player_sprite = player_node.get_node_or_null("Sprite2D")
			var player_size = player_sprite.texture.get_size() * player_sprite.scale if player_sprite and player_sprite.texture else Vector2(cell_size, cell_size)
			var player_center = player_node.global_position + player_size / 2
			var distance_to_target = player_center.distance_to(chosen_landing_spot)
			var reference_distance = 1200.0
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
				var overcharge_bonus = ((time_percent - 0.75) / 0.25) * (0.25 * 800.0) # max_shot_distance
				actual_power = power_for_target + overcharge_bonus
		else:
			actual_power = time_percent * MAX_LAUNCH_POWER
		
		var height_percentage = (height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
		height_percentage = clamp(height_percentage, 0.0, 1.0)
		var height_resistance_multiplier = 1.0
		if height_percentage > HEIGHT_SWEET_SPOT_MAX:
			var excess_height = height_percentage - HEIGHT_SWEET_SPOT_MAX
			var max_excess = 1.0 - HEIGHT_SWEET_SPOT_MAX
			var resistance_factor = excess_height / max_excess
			height_resistance_multiplier = 1.0 - (resistance_factor * 0.5)
		
		var final_power = actual_power * height_resistance_multiplier
		var strength_modifier = player_stats.get("strength", 0)
		if strength_modifier != 0:
			var strength_multiplier = 1.0 + (strength_modifier * 0.1)
			final_power *= strength_multiplier
		
		card_effect_handler.launch_scramble_balls(direction, final_power, height, launch_spin)
		hide_power_meter()
		var is_putting = club_data.get(selected_club, {}).get("is_putter", false)
		if not is_putting:
			hide_height_meter()
		return
	
	var player_sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = player_sprite.texture.get_size() * player_sprite.scale if player_sprite and player_sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2

	var launch_direction = (chosen_landing_spot - player_center).normalized() if chosen_landing_spot != Vector2.ZERO else Vector2.ZERO

	var time_percent = charge_time / max_charge_time
	time_percent = clamp(time_percent, 0.0, 1.0)
	var actual_power = 0.0
	if chosen_landing_spot != Vector2.ZERO:
		var distance_to_target = player_center.distance_to(chosen_landing_spot)
		var reference_distance = 1200.0  # Driver's max distance as reference
		var distance_factor = distance_to_target / reference_distance
		var ball_physics_factor = 0.8 + (distance_factor * 0.4)  # Reduced from 1.2 to 0.4 (0.8 to 1.2)
		var base_power_per_distance = 0.6 + (distance_factor * 0.2)  # Reduced from 0.8 to 0.2 (0.6 to 0.8)
		
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
			var base_putter_power = 300.0  # Base power for putters
			actual_power = time_percent * base_putter_power
		elif time_percent <= 0.75:
			actual_power = (time_percent / 0.75) * power_for_target
			var trailoff_forgiveness = club_data[selected_club].get("trailoff_forgiveness", 0.5) if selected_club in club_data else 0.5
			var undercharge_factor = 1.0 - (time_percent / 0.75)  # 0.0 to 1.0
			var trailoff_penalty = undercharge_factor * (1.0 - trailoff_forgiveness)
			actual_power = actual_power * (1.0 - trailoff_penalty)
		else:
			var overcharge_bonus = ((time_percent - 0.75) / 0.25) * (0.25 * 800.0) # max_shot_distance
			actual_power = power_for_target + overcharge_bonus
	else:
		actual_power = time_percent * MAX_LAUNCH_POWER

	var aim_deviation = current_charge_mouse_pos - original_aim_mouse_pos
	var launch_dir_perp = Vector2(-launch_direction.y, launch_direction.x) # Perpendicular to launch direction
	var spin_strength = aim_deviation.dot(launch_dir_perp)
	launch_spin = clamp(spin_strength * 1.0, -800, 800)  # Increased from 0.1 to 1.0 and max from 200 to 800
	var spin_abs = abs(spin_strength)
	var spin_strength_category = 0  # 0=green, 1=yellow, 2=red
	if spin_abs > 120:
		spin_strength_category = 2  # Red - high spin
	elif spin_abs > 48:
		spin_strength_category = 1  # Yellow - medium spin
	else:
		spin_strength_category = 0  # Green - low spin

	var height_percentage = (height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
	height_percentage = clamp(height_percentage, 0.0, 1.0)

	var height_resistance_multiplier = 1.0
	if height_percentage > HEIGHT_SWEET_SPOT_MAX:  # Above 50% height
		var excess_height = height_percentage - HEIGHT_SWEET_SPOT_MAX
		var max_excess = 1.0 - HEIGHT_SWEET_SPOT_MAX  # 0.5 (from 50% to 100%)
		var resistance_factor = excess_height / max_excess  # 0.0 to 1.0
		height_resistance_multiplier = 1.0 - (resistance_factor * 0.5)  # Reduce power by up to 50%

	var final_power = actual_power * height_resistance_multiplier
	
	var strength_modifier = player_stats.get("strength", 0)
	if strength_modifier != 0:
		var strength_multiplier = 1.0 + (strength_modifier * 0.1)
		final_power *= strength_multiplier

	if golf_ball:
		golf_ball.queue_free()
	golf_ball = preload("res://GolfBall.tscn").instantiate()
	var ball_area = golf_ball.get_node_or_null("Area2D")
	if ball_area:
		ball_area.collision_layer = 1
		ball_area.collision_mask = 1  # Collide with layer 1 (trees)
	
	var ball_setup_player_sprite = player_node.get_node_or_null("Sprite2D")
	var ball_setup_player_size = ball_setup_player_sprite.texture.get_size() * ball_setup_player_sprite.scale if ball_setup_player_sprite and ball_setup_player_sprite.texture else Vector2(cell_size, cell_size)
	var ball_setup_player_center = player_node.global_position + ball_setup_player_size / 2

	var ball_position_offset = Vector2(0, -cell_size * 0.5)
	ball_setup_player_center += ball_position_offset

	var ball_local_position = ball_setup_player_center - camera_container.global_position
	golf_ball.position = ball_local_position
	golf_ball.cell_size = cell_size
	# golf_ball.map_manager = map_manager  # This will be set by parent
	camera_container.add_child(golf_ball)  # Add to camera container instead of main scene
	golf_ball.add_to_group("balls")  # Add to group for collision detection
	
	# update_ball_y_sort(golf_ball)  # This will be called by parent
	var shadow = golf_ball.get_node_or_null("Shadow")
	var ball_sprite = golf_ball.get_node_or_null("Sprite2D")
	# play_swing_sound(final_power)  # This will be called by parent
	golf_ball.chosen_landing_spot = chosen_landing_spot
	golf_ball.club_info = club_data[selected_club] if selected_club in club_data else {}
	var is_putting = club_data.get(selected_club, {}).get("is_putter", false)
	golf_ball.is_putting = is_putting
	golf_ball.time_percentage = time_percent
	# Card effects will be handled by parent
	
	golf_ball.launch(launch_direction, final_power, height, launch_spin, spin_strength_category)  # Pass spin strength category
	# Signal connections will be handled by parent
	
	emit_signal("ball_launched", golf_ball)

func show_power_meter():
	if power_meter:
		power_meter.queue_free()
	
	power_for_target = MIN_LAUNCH_POWER  # Default if no target
	max_power_for_bar = MAX_LAUNCH_POWER  # Default
	
	if chosen_landing_spot != Vector2.ZERO and selected_club in club_data:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var distance_to_target = player_center.distance_to(chosen_landing_spot)
		var club_max = club_data[selected_club]["max_distance"] if selected_club in club_data else MAX_LAUNCH_POWER
		power_for_target = min(distance_to_target, club_max)
		max_power_for_bar = club_max
	
	power_meter = Control.new()
	power_meter.name = "PowerMeter"
	power_meter.size = Vector2(350, 80)
	power_meter.position = Vector2(396.49, 558.7)  # Center of screen for testing
	ui_layer.add_child(power_meter)
	power_meter.z_index = 200
	
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.size = power_meter.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(background)
	
	var title_label := Label.new()
	title_label.text = "POWER"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.position = Vector2(10, 5)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(title_label)
	
	var meter_bg := ColorRect.new()
	meter_bg.color = Color(0.3, 0.3, 0.3, 1.0)
	meter_bg.size = Vector2(300, 30)
	meter_bg.position = Vector2(10, 30)
	meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(meter_bg)
	
	var sweet_spot := ColorRect.new()
	sweet_spot.color = Color(0, 1, 0, 0.5)
	sweet_spot.size = Vector2(60, 30)
	sweet_spot.position = Vector2(10 + 180, 30)  # 60% of 300
	sweet_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(sweet_spot)
	
	var meter_fill := ColorRect.new()
	meter_fill.color = Color(1, 0, 0, 1.0)
	meter_fill.size = Vector2(0, 30)  # Start with zero width, will be updated in _process
	meter_fill.position = Vector2(10, 30)
	meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_fill.name = "MeterFill"
	power_meter.add_child(meter_fill)
	
	var value_label := Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.position = Vector2(320, 30)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.name = "PowerValue"
	power_meter.add_child(value_label)
	
	var min_label := Label.new()
	min_label.text = "MIN"
	min_label.add_theme_font_size_override("font_size", 12)
	min_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	min_label.position = Vector2(10, 65)
	min_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(min_label)
	
	var max_label := Label.new()
	max_label.text = "MAX"
	max_label.add_theme_font_size_override("font_size", 12)
	max_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	max_label.position = Vector2(280, 65)
	max_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_meter.add_child(max_label)
	
	power_meter.set_meta("max_power_for_bar", max_power_for_bar)
	power_meter.set_meta("power_for_target", power_for_target)
	power_meter.set_meta("scaled_min_power", MIN_LAUNCH_POWER)

func hide_power_meter():
	if power_meter:
		power_meter.queue_free()
		power_meter = null

func show_height_meter():
	if height_meter:
		height_meter.queue_free()
	
	height_meter = Control.new()
	height_meter.name = "HeightMeter"
	height_meter.size = Vector2(80, 350)
	height_meter.position = Vector2(335.5, 206.5)  # Center of screen for testing
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
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.position = Vector2(10, 340)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.name = "HeightValue"
	height_meter.add_child(value_label)

func hide_height_meter():
	if height_meter:
		height_meter.queue_free()
		height_meter = null

# Spin indicator functions removed

func handle_input(event: InputEvent) -> bool:
	"""Handle input events for launch mechanics. Returns true if event was handled."""
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not is_charging and not is_charging_height:
					is_charging = true
					charge_time = 0.0
					current_charge_mouse_pos = camera.get_global_mouse_position()
					return true
			else:
				if is_charging:
					is_charging = false
					var is_putting = club_data.get(selected_club, {}).get("is_putter", false)
					if not is_putting:
						is_charging_height = true
						launch_height = MIN_LAUNCH_HEIGHT
					else:
						launch_golf_ball(launch_direction, 0.0, launch_height)
						hide_power_meter()
					return true
				elif is_charging_height:
					is_charging_height = false
					# Don't reset launch_height here - keep the charged value
					launch_golf_ball(launch_direction, 0.0, launch_height)
					hide_power_meter()
					hide_height_meter()
					return true
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Cancel launch phase
			is_charging = false
			is_charging_height = false
			hide_power_meter()
			hide_height_meter()
			return true
	
	elif event is InputEventMouseMotion:
		if is_charging or is_charging_height:
			current_charge_mouse_pos = camera.get_global_mouse_position()
			return true
	
	return false

# Spin indicator visibility function removed

func cleanup():
	"""Clean up launch manager resources"""
	if golf_ball and is_instance_valid(golf_ball):
		golf_ball.queue_free()
		golf_ball = null
	
	hide_power_meter()
	hide_height_meter() 
