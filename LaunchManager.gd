extends Node
class_name LaunchManager

# Launch variables
var golf_ball: Node2D = null
var throwing_knife: Node2D = null
# Meter variables removed - now using player's meter system
var launch_power := 0.0
var launch_height := 0.0
var launch_direction := Vector2.ZERO
var is_charging := false
var is_charging_height := false
var is_knife_mode := false  # Track if we're launching a knife instead of a ball
var is_grenade_mode := false  # Track if we're launching a grenade instead of a ball
var is_spear_mode := false  # Track if we're launching a spear instead of a ball

# Vertical parallax effect variables
var vertical_parallax_active := false
var world_grid_container: Control = null  # Reference to the grid container
var obstacle_layer: Control = null  # Reference to the obstacle layer (contains tiles and objects)
var background_manager: Node = null  # Reference to background manager
var vertical_squish_factor := 1.0  # Current Y scaling (1.0 = normal, 0.7 = squished)
var background_compression_factor := 1.0  # How much to compress background layers
var sprite_compensation_factor := 1.0  # How much to scale sprites to compensate (1.0 = normal, 1.5 = compensated)
var vertical_parallax_tween: Tween = null
var original_camera_container_position: Vector2 = Vector2.ZERO  # Store original position to restore later

# Launch constants
const MAX_LAUNCH_POWER := 1200.0
const MIN_LAUNCH_POWER := 300.0
const POWER_CHARGE_RATE := 300.0 # units per second
const MAX_LAUNCH_HEIGHT := 480.0   # 10 cells (48 * 10) for pixel perfect system
const MIN_LAUNCH_HEIGHT := 0.0   # Allow for ground-level shots (was 144.0)
const HEIGHT_CHARGE_RATE := 600.0  # Adjusted for pixel perfect system (was 1000.0)
const HEIGHT_SWEET_SPOT_MIN := 0.3 # 30% of max height - lower sweet spot for better arc
const HEIGHT_SWEET_SPOT_MAX := 0.5 # 50% of max height - narrower sweet spot

# Vertical parallax constants
const VERTICAL_SQUISH_MIN := 0.7  # Minimum Y scaling (30% squish)
const BACKGROUND_COMPRESSION_MIN := 0.6  # How much to compress background layers
const SPRITE_COMPENSATION_MAX := 1.5  # Maximum sprite compensation (50% scale up)
const VERTICAL_PARALLAX_DURATION := 1.2  # Duration of transition in seconds (increased for smoother animation)

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
var selected_club: String:
	set(value):
		if selected_club != value:
			print("LaunchManager: selected_club changed from '", selected_club, "' to '", value, "'")
		selected_club = value
var club_data: Dictionary
var player_stats: Dictionary
var card_effect_handler: Node
var camera: Camera2D

# Signals
signal ball_launched(ball: Node2D)
signal launch_phase_entered
signal launch_phase_exited
signal charging_state_changed(charging: bool, charging_height: bool)
signal vertical_parallax_activated
signal vertical_parallax_deactivated
signal vertical_parallax_animation_complete

# Add this variable to track if this is a tee shot

# Ball state tracking
var ball_in_flight := false
var previous_golf_ball: Node2D = null  # Store golf ball reference when entering knife mode
var grenade: Node2D = null  # Store grenade reference
var grenade_explosion_in_progress := false  # Track if grenade explosion is in progress

func _ready():
	pass

func _process(delta: float):
	if is_charging:
		charge_time = min(charge_time + delta, max_charge_time)
		
		# Update player's power meter
		if player_node and player_node.has_method("update_power_meter"):
			var time_percent = charge_time / max_charge_time
			time_percent = clamp(time_percent, 0.0, 1.0)
			
			# Calculate current power based on club data
			var scaled_min_power = MIN_LAUNCH_POWER
			var scaled_max_power = MAX_LAUNCH_POWER
			if chosen_landing_spot != Vector2.ZERO and selected_club in club_data:
				var club_max = club_data[selected_club]["max_distance"]
				scaled_max_power = club_max
			
			var current_power = scaled_min_power + (time_percent * (scaled_max_power - scaled_min_power))
			player_node.update_power_meter(current_power, scaled_max_power)
	
	if is_charging_height:
		launch_height = min(launch_height + HEIGHT_CHARGE_RATE * delta, MAX_LAUNCH_HEIGHT)
		
		# Update player's height meter
		if player_node and player_node.has_method("update_height_meter"):
			player_node.update_height_meter(launch_height, MAX_LAUNCH_HEIGHT)

func enter_launch_phase() -> void:
	"""Enter the launch phase for taking a shot"""
	emit_signal("launch_phase_entered")
	charge_time = 0.0
	original_aim_mouse_pos = camera.get_global_mouse_position()
	
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
		launch_height = 0.0  # Start at ground level for low shots (was MIN_LAUNCH_HEIGHT)
	else:
		launch_height = 0.0
	
	launch_power = MIN_LAUNCH_POWER
	
	if chosen_landing_spot != Vector2.ZERO:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var distance_to_target = player_center.distance_to(chosen_landing_spot)
	
	# Camera positioning is now handled by the vertical parallax effect
	# No additional camera tween to avoid conflicts
	
	# Spin indicator removed
	pass

func exit_launch_phase() -> void:
	"""Exit the launch phase"""
	emit_signal("launch_phase_exited")
	
	# Hide player meters
	if player_node and player_node.has_method("hide_power_meter"):
		player_node.hide_power_meter()
	if player_node and player_node.has_method("hide_height_meter"):
		player_node.hide_height_meter()
	
	is_charging = false
	is_charging_height = false
	is_knife_mode = false  # Reset knife mode
	is_grenade_mode = false  # Reset grenade mode
	is_spear_mode = false  # Reset spear mode
	
	# REMOVED: No longer deactivating vertical parallax when exiting launch phase
	# Since we're not activating it during normal launches anymore
	
	# Reset ball in flight state when exiting launch phase
	set_ball_in_flight(false)

func enter_knife_mode() -> void:
	"""Enter knife throwing mode"""
	is_knife_mode = true
	selected_club = "ThrowingKnife"  # Use ThrowingKnife club stats for knife throwing
	
	# Store the current golf ball reference before entering knife mode
	previous_golf_ball = golf_ball
	
	# Create character-specific throwing knife data based on strength
	var character_strength = player_stats.get("strength", 0)
	var base_max_distance = 300.0  # Base distance for strength 0 (Benny)
	var strength_multiplier = 1.0 + (character_strength * 0.25)  # +25% per strength point
	var max_distance = base_max_distance * strength_multiplier
	
	# Set up character-specific throwing knife data
	club_data = {
		"ThrowingKnife": {
			"max_distance": max_distance,
			"min_distance": 200.0,
			"trailoff_forgiveness": 0.8,
			"is_putter": false
		}
	}
	
	enter_launch_phase()

func exit_knife_mode() -> void:
	"""Exit knife throwing mode"""
	is_knife_mode = false
	
	# Restore golf ball reference from stored reference or find one in scene
	if previous_golf_ball and is_instance_valid(previous_golf_ball):
		golf_ball = previous_golf_ball
	else:
		# Fallback: find any valid ball in the scene
		var balls = get_tree().get_nodes_in_group("balls")
		for ball in balls:
			if is_instance_valid(ball):
				golf_ball = ball
				break
	previous_golf_ball = null

func enter_spear_mode() -> void:
	"""Enter spear throwing mode"""
	is_spear_mode = true
	selected_club = "SpearCard"  # Use SpearCard club stats for spear throwing
	
	# Store the current golf ball reference before entering spear mode
	previous_golf_ball = golf_ball
	
	# Create character-specific spear data based on strength
	var character_strength = player_stats.get("strength", 0)
	var base_max_distance = 350.0  # Base distance for strength 0 (Benny) - spears go further than knives
	var strength_multiplier = 1.0 + (character_strength * 0.25)  # +25% per strength point
	var max_distance = base_max_distance * strength_multiplier
	
	# Set up character-specific spear data
	club_data = {
		"SpearCard": {
			"max_distance": max_distance,
			"min_distance": 250.0,
			"trailoff_forgiveness": 0.8,
			"is_putter": false
		}
	}
	
	enter_launch_phase()

func exit_spear_mode() -> void:
	"""Exit spear throwing mode"""
	is_spear_mode = false
	
	# Clear spear reference (reuses throwing_knife variable)
	throwing_knife = null
	
	# Restore golf ball reference from stored reference or find one in scene
	if previous_golf_ball and is_instance_valid(previous_golf_ball):
		golf_ball = previous_golf_ball
	else:
		# Fallback: find any valid ball in the scene
		var balls = get_tree().get_nodes_in_group("balls")
		for ball in balls:
			if is_instance_valid(ball):
				golf_ball = ball
				break
	previous_golf_ball = null
	
	# Exit launch phase to return to normal game state
	exit_launch_phase()

func enter_grenade_mode() -> void:
	"""Enter grenade throwing mode"""
	is_grenade_mode = true
	selected_club = "GrenadeCard"  # Use GrenadeCard club stats for grenade throwing
	print("LaunchManager: enter_grenade_mode - selected_club:", selected_club, " is_grenade_mode:", is_grenade_mode)
	
	# Store the current golf ball reference before entering grenade mode
	previous_golf_ball = golf_ball
	
	# Create character-specific grenade data based on strength
	var character_strength = player_stats.get("strength", 0)
	var base_max_distance = 400.0  # Base distance for strength 0 (Benny)
	var strength_multiplier = 1.0 + (character_strength * 0.25)  # +25% per strength point
	var max_distance = base_max_distance * strength_multiplier
	
	# Set up character-specific grenade data
	club_data = {
		"GrenadeCard": {
			"max_distance": max_distance,
			"min_distance": 200.0,
			"trailoff_forgiveness": 0.8,
			"is_putter": false
		}
	}
	print("LaunchManager: enter_grenade_mode - club_data:", club_data)
	
	enter_launch_phase()

func exit_grenade_mode() -> void:
	"""Exit grenade throwing mode"""
	is_grenade_mode = false
	
	# Restore golf ball reference from stored reference or find one in scene
	if previous_golf_ball and is_instance_valid(previous_golf_ball):
		golf_ball = previous_golf_ball
	else:
		# Fallback: find any valid ball in the scene
		var balls = get_tree().get_nodes_in_group("balls")
		for ball in balls:
			if is_instance_valid(ball):
				golf_ball = ball
				break
	previous_golf_ball = null
	throwing_knife = null
	grenade = null  # Clear grenade reference when exiting grenade mode
	
	# Only exit launch phase if we're not in the middle of a grenade explosion
	# The explosion handler will manage the game phase transition
	if not grenade_explosion_in_progress:
		exit_launch_phase()

func launch_golf_ball(launch_direction: Vector2, final_power: float, height: float, launch_spin: float = 0.0, spin_strength_category: int = 0):
	"""Launch the golf ball with the specified parameters"""
	
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
	
	# Launch the ball
	golf_ball.launch(launch_direction, final_power, height, launch_spin, spin_strength_category)
	
	# Set ball in flight state
	set_ball_in_flight(true)
	
	# Store reference and emit signal
	self.golf_ball = golf_ball
	emit_signal("ball_launched", golf_ball)
	
	# Exit launch phase to transition to ball flying phase
	exit_launch_phase()

func launch_throwing_knife(launch_direction: Vector2, final_power: float, height: float, launch_spin: float = 0.0, spin_strength_category: int = 0):
	"""Launch the throwing knife with the specified parameters"""
	golf_ball = null
	var existing_knife = null
	var knives = get_tree().get_nodes_in_group("knives")
	
	# Find an available knife in the scene (not landed)
	for knife in knives:
		if is_instance_valid(knife):
			# Check if this knife is available (not landed)
			var is_available = false
			if knife.has_method("is_in_flight"):
				is_available = knife.is_in_flight()
			elif "landed_flag" in knife:
				is_available = not knife.landed_flag
			else:
				# If we can't determine if it's landed, assume it's available
				is_available = true
			
			if is_available:
				existing_knife = knife
				break

	if not existing_knife:
		# Create a new knife instance
		var throwing_knife_scene = preload("res://Weapons/ThrowingKnife.tscn")
		existing_knife = throwing_knife_scene.instantiate()
		
		# Add knife to groups for smart optimization
		existing_knife.add_to_group("knives")
		existing_knife.add_to_group("collision_objects")
		
		# Add to the CameraContainer like golf balls
		if card_effect_handler and card_effect_handler.course:
			var camera_container = card_effect_handler.course.get_node_or_null("CameraContainer")
			if camera_container:
				camera_container.add_child(existing_knife)
				existing_knife.global_position = player_node.global_position
			else:
				# Fallback to course if CameraContainer not found
				card_effect_handler.course.add_child(existing_knife)
				existing_knife.global_position = player_node.global_position
		else:
			return

	# Use the existing knife
	throwing_knife = existing_knife

	# Set knife properties using character-specific throwing knife stats
	var knife_club_info = club_data.get("ThrowingKnife", {
		"max_distance": 300.0,
		"min_distance": 200.0,
		"trailoff_forgiveness": 0.8
	})
	throwing_knife.chosen_landing_spot = chosen_landing_spot
	throwing_knife.set_club_info(knife_club_info)

	# Calculate time percentage for the knife
	var time_percent = charge_time / max_charge_time
	time_percent = clamp(time_percent, 0.0, 1.0)
	throwing_knife.set_time_percentage(time_percent)

	# Calculate correct launch direction from knife to target
	var direction = (chosen_landing_spot - throwing_knife.global_position).normalized()
	
	# Launch the knife
	throwing_knife.launch(direction, final_power, height, launch_spin, spin_strength_category)

	# Set ball in flight state (reusing the same system)
	set_ball_in_flight(true)

	# Store reference and emit signal
	self.throwing_knife = throwing_knife
	emit_signal("ball_launched", throwing_knife)  # Reuse ball_launched signal for compatibility
	
	# Exit launch phase to transition to ball flying phase
	exit_launch_phase()

func launch_grenade(launch_direction: Vector2, final_power: float, height: float, launch_spin: float = 0.0, spin_strength_category: int = 0):
	"""Launch the grenade with the specified parameters"""
	print("LaunchManager: launch_grenade called with power:", final_power, " height:", height, " direction:", launch_direction)
	golf_ball = null
	var existing_grenade = null
	var grenades = get_tree().get_nodes_in_group("grenades")
	
	# Find an available grenade in the scene (not landed)
	for grenade in grenades:
		if is_instance_valid(grenade):
			# Check if this grenade is available (not landed)
			var is_available = false
			if grenade.has_method("is_in_flight"):
				is_available = grenade.is_in_flight()
			elif "landed_flag" in grenade:
				is_available = not grenade.landed_flag
			else:
				# If we can't determine if it's landed, assume it's available
				is_available = true
			
			if is_available:
				existing_grenade = grenade
				break

	if not existing_grenade:
		# Create a new grenade instance
		var grenade_scene = preload("res://Weapons/Grenade.tscn")
		existing_grenade = grenade_scene.instantiate()
		
		# Add grenade to groups for smart optimization
		existing_grenade.add_to_group("grenades")
		existing_grenade.add_to_group("collision_objects")
		
		# Add to the CameraContainer like golf balls
		if card_effect_handler and card_effect_handler.course:
			var camera_container = card_effect_handler.course.get_node_or_null("CameraContainer")
			if camera_container:
				camera_container.add_child(existing_grenade)
				# Position at player center like golf ball
				var sprite = player_node.get_node_or_null("Sprite2D")
				var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
				var player_center = player_node.global_position + player_size / 2
				existing_grenade.global_position = player_center
			else:
				# Fallback to course if CameraContainer not found
				card_effect_handler.course.add_child(existing_grenade)
				# Position at player center like golf ball
				var sprite = player_node.get_node_or_null("Sprite2D")
				var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
				var player_center = player_node.global_position + player_size / 2
				existing_grenade.global_position = player_center
		else:
			return

	# Use the existing grenade
	self.grenade = existing_grenade

	# Set grenade properties using character-specific grenade stats
	var grenade_club_info = club_data.get("GrenadeCard", {
		"max_distance": 400.0,
		"min_distance": 200.0,
		"trailoff_forgiveness": 0.8
	})
	self.grenade.chosen_landing_spot = chosen_landing_spot
	self.grenade.set_club_info(grenade_club_info)
	
	# Set cell_size and map_manager like golf ball
	if card_effect_handler and card_effect_handler.course:
		self.grenade.cell_size = card_effect_handler.course.cell_size
		self.grenade.map_manager = card_effect_handler.course.map_manager

	# Calculate time percentage for the grenade
	var time_percent = charge_time / max_charge_time
	time_percent = clamp(time_percent, 0.0, 1.0)
	self.grenade.set_time_percentage(time_percent)

	# Calculate correct launch direction from player center to target
	var sprite = player_node.get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center = player_node.global_position + player_size / 2
	var direction = (chosen_landing_spot - player_center).normalized()
	
	# Launch the grenade
	self.grenade.launch(direction, final_power, height, launch_spin, spin_strength_category)

	# Set ball in flight state (reusing the same system)
	set_ball_in_flight(true)

	# Store reference and emit signal
	emit_signal("ball_launched", self.grenade)  # Reuse ball_launched signal for compatibility
	
	# Exit launch phase to transition to ball flying phase
	exit_launch_phase()

func launch_spear(launch_direction: Vector2, final_power: float, height: float, launch_spin: float = 0.0, spin_strength_category: int = 0):
	"""Launch the spear with the specified parameters"""
	golf_ball = null
	var existing_spear = null
	var spears = get_tree().get_nodes_in_group("spears")
	
	# Find an available spear in the scene (not landed)
	for spear in spears:
		if is_instance_valid(spear):
			# Check if this spear is available (not landed)
			var is_available = false
			if spear.has_method("is_in_flight"):
				is_available = spear.is_in_flight()
			elif "landed_flag" in spear:
				is_available = not spear.landed_flag
			else:
				# If we can't determine if it's landed, assume it's available
				is_available = true
			
			if is_available:
				existing_spear = spear
				break

	if not existing_spear:
		# Create a new spear instance
		var spear_scene = preload("res://Weapons/Spear.tscn")
		existing_spear = spear_scene.instantiate()
		
		# Add spear to groups for smart optimization
		existing_spear.add_to_group("spears")
		existing_spear.add_to_group("collision_objects")
		
		# Add to the CameraContainer like golf balls
		if card_effect_handler and card_effect_handler.course:
			var camera_container = card_effect_handler.course.get_node_or_null("CameraContainer")
			if camera_container:
				camera_container.add_child(existing_spear)
				existing_spear.global_position = player_node.global_position
			else:
				# Fallback to course if CameraContainer not found
				card_effect_handler.course.add_child(existing_spear)
				existing_spear.global_position = player_node.global_position
		else:
			return

	# Use the existing spear
	throwing_knife = existing_spear  # Reuse throwing_knife variable for spear

	# Set spear properties using character-specific spear stats
	var spear_club_info = club_data.get("SpearCard", {
		"max_distance": 350.0,
		"min_distance": 250.0,
		"trailoff_forgiveness": 0.8
	})
	throwing_knife.chosen_landing_spot = chosen_landing_spot
	throwing_knife.set_club_info(spear_club_info)

	# Calculate time percentage for the spear
	var time_percent = charge_time / max_charge_time
	time_percent = clamp(time_percent, 0.0, 1.0)
	throwing_knife.set_time_percentage(time_percent)

	# Calculate correct launch direction from spear to target
	var direction = (chosen_landing_spot - throwing_knife.global_position).normalized()
	print("Spear launch - chosen_landing_spot: ", chosen_landing_spot, " spear_position: ", throwing_knife.global_position)
	print("Spear launch - direction: ", direction, " power: ", final_power, " height: ", height)
	
	# Launch the spear
	throwing_knife.launch(direction, final_power, height, launch_spin, spin_strength_category)

	# Set ball in flight state (reusing the same system)
	set_ball_in_flight(true)

	# Store reference and emit signal
	self.throwing_knife = throwing_knife
	emit_signal("ball_launched", throwing_knife)  # Reuse ball_launched signal for compatibility
	
	# Exit launch phase to transition to ball flying phase
	exit_launch_phase()

# Meter functions removed - now using player's meter system

# Spin indicator functions removed

func handle_input(event: InputEvent) -> bool:
	"""Handle input events for launch mechanics. Returns true if event was handled."""
	
	# Check if a ball is available for launch - if not, don't allow new launches
	if not is_ball_available_for_launch():
		return false
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not is_charging and not is_charging_height:
					is_charging = true
					charge_time = 0.0
					current_charge_mouse_pos = camera.get_global_mouse_position()
					emit_signal("charging_state_changed", is_charging, is_charging_height)
					return true
			else:
				if is_charging:
					is_charging = false
					var is_putting = club_data.get(selected_club, {}).get("is_putter", false)
					print("LaunchManager: Power charging finished. is_putting:", is_putting, " selected_club:", selected_club, " is_grenade_mode:", is_grenade_mode)
					if not is_putting:
						print("LaunchManager: Transitioning to height charging")
						is_charging_height = true
						launch_height = 0.0
					else:
						print("LaunchManager: Launching immediately (putter)")
						# Calculate final power and launch the projectile
						var final_power = calculate_final_power()
						launch_direction = calculate_launch_direction()
						if is_knife_mode:
							launch_throwing_knife(launch_direction, final_power, launch_height)
						elif is_grenade_mode:
							launch_grenade(launch_direction, final_power, launch_height)
						elif is_spear_mode:
							launch_spear(launch_direction, final_power, launch_height)
						else:
							launch_golf_ball(launch_direction, final_power, launch_height)
						# Hide player meters
						if player_node and player_node.has_method("hide_power_meter"):
							player_node.hide_power_meter()
					emit_signal("charging_state_changed", is_charging, is_charging_height)
					return true
				elif is_charging_height:
					is_charging_height = false
					print("LaunchManager: Height charging finished. Final height:", launch_height, " is_grenade_mode:", is_grenade_mode)
					# Don't reset launch_height here - keep the charged value
					# Calculate final power and launch the projectile
					var final_power = calculate_final_power()
					launch_direction = calculate_launch_direction()
					if is_knife_mode:
						print("LaunchManager: Launching throwing knife")
						launch_throwing_knife(launch_direction, final_power, launch_height)
					elif is_grenade_mode:
						print("LaunchManager: Launching grenade")
						launch_grenade(launch_direction, final_power, launch_height)
					elif is_spear_mode:
						print("LaunchManager: Launching spear")
						launch_spear(launch_direction, final_power, launch_height)
					else:
						print("LaunchManager: Launching golf ball")
						launch_golf_ball(launch_direction, final_power, launch_height)
					# Hide player meters
					if player_node and player_node.has_method("hide_power_meter"):
						player_node.hide_power_meter()
					if player_node and player_node.has_method("hide_height_meter"):
						player_node.hide_height_meter()
					emit_signal("charging_state_changed", is_charging, is_charging_height)
					return true
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Cancel launch phase
			is_charging = false
			is_charging_height = false
			# Hide player meters
			if player_node and player_node.has_method("hide_power_meter"):
				player_node.hide_power_meter()
			if player_node and player_node.has_method("hide_height_meter"):
				player_node.hide_height_meter()
			emit_signal("charging_state_changed", is_charging, is_charging_height)
			return true
	
	elif event is InputEventMouseMotion:
		if is_charging or is_charging_height:
			current_charge_mouse_pos = camera.get_global_mouse_position()
			return true
	
	return false

# Spin indicator visibility function removed

func calculate_launch_direction() -> Vector2:
	"""Calculate the launch direction based on the chosen landing spot or mouse position"""
	# Get the projectile's actual position for direction calculation
	var projectile_position = Vector2.ZERO
	
	if is_knife_mode:
		# For knives, check knife instances
		var knives = get_tree().get_nodes_in_group("knives")
		for knife in knives:
			if is_instance_valid(knife):
				projectile_position = knife.global_position
				break
	elif is_grenade_mode:
		# For grenades, check grenade instances
		var grenades = get_tree().get_nodes_in_group("grenades")
		for grenade in grenades:
			if is_instance_valid(grenade):
				projectile_position = grenade.global_position
				break
	elif is_spear_mode:
		# For spears, check spear instances
		var spears = get_tree().get_nodes_in_group("spears")
		for spear in spears:
			if is_instance_valid(spear):
				projectile_position = spear.global_position
				break
	else:
		# For balls, check ball instances
		var balls = get_tree().get_nodes_in_group("balls")
		for ball in balls:
			if is_instance_valid(ball):
				projectile_position = ball.global_position
				break
	
	# Fallback to player center if no projectile found
	if projectile_position == Vector2.ZERO:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		projectile_position = player_node.global_position + player_size / 2
	
	if chosen_landing_spot != Vector2.ZERO:
		# Use direction to the chosen landing spot
		return (chosen_landing_spot - projectile_position).normalized()
	else:
		# Use direction from projectile to mouse position
		var mouse_pos = camera.get_global_mouse_position()
		return (mouse_pos - projectile_position).normalized()

func calculate_final_power() -> float:
	"""Calculate the final power based on charge time and target distance"""
	var time_percent = charge_time / max_charge_time
	time_percent = clamp(time_percent, 0.0, 1.0)
	var actual_power = 0.0
	
	if chosen_landing_spot != Vector2.ZERO:
		var sprite = player_node.get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center = player_node.global_position + player_size / 2
		var distance_to_target = player_center.distance_to(chosen_landing_spot)
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
	var height_percentage = launch_height / MAX_LAUNCH_HEIGHT  # Simplified calculation for 0.0 to MAX_LAUNCH_HEIGHT range
	height_percentage = clamp(height_percentage, 0.0, 1.0)
	var height_resistance_multiplier = 1.0
	if height_percentage > HEIGHT_SWEET_SPOT_MAX:
		var excess_height = height_percentage - HEIGHT_SWEET_SPOT_MAX
		var max_excess = 1.0 - HEIGHT_SWEET_SPOT_MAX
		var resistance_factor = excess_height / max_excess
		height_resistance_multiplier = 1.0 - (resistance_factor * 0.5)
	
	var final_power = actual_power * height_resistance_multiplier
	
	# Apply strength modifier
	var strength_modifier = player_stats.get("strength", 0)
	if strength_modifier != 0:
		var strength_multiplier = 1.0 + (strength_modifier * 0.1)
		final_power *= strength_multiplier
	
	return final_power

func is_ball_in_flight() -> bool:
	"""Check if there's a ball or knife currently in flight"""
	# Check if we have a golf ball reference and it's in flight
	if golf_ball and is_instance_valid(golf_ball):
		if golf_ball.has_method("is_in_flight"):
			return golf_ball.is_in_flight()
		elif "in_flight" in golf_ball:
			return golf_ball.in_flight
		elif golf_ball.has_method("get_velocity"):
			var velocity = golf_ball.get_velocity()
			return velocity.length() > 0.1  # Ball is moving
		elif "velocity" in golf_ball:
			var velocity = golf_ball.velocity
			return velocity.length() > 0.1  # Ball is moving
	
	# Check if we have a throwing knife reference and it's in flight
	if throwing_knife and is_instance_valid(throwing_knife):
		if throwing_knife.has_method("is_in_flight"):
			return throwing_knife.is_in_flight()
		elif throwing_knife.has_method("get_velocity"):
			var velocity = throwing_knife.get_velocity()
			return velocity.length() > 0.1  # Knife is moving
		elif "velocity" in throwing_knife:
			var velocity = throwing_knife.velocity
			return velocity.length() > 0.1  # Knife is moving
	
	# Check if we have a grenade reference and it's in flight
	if grenade and is_instance_valid(grenade):
		if grenade.has_method("is_in_flight"):
			return grenade.is_in_flight()
		elif grenade.has_method("get_velocity"):
			var velocity = grenade.get_velocity()
			return velocity.length() > 0.1  # Grenade is moving
		elif "velocity" in grenade:
			var velocity = grenade.velocity
			return velocity.length() > 0.1  # Grenade is moving
	
	# Also check for any balls in the scene that might be in flight
	var balls = get_tree().get_nodes_in_group("balls")
	for ball in balls:
		if is_instance_valid(ball):
			if ball.has_method("is_in_flight"):
				if ball.is_in_flight():
					return true
			elif "in_flight" in ball:
				if ball.in_flight:
					return true
			elif ball.has_method("get_velocity"):
				var velocity = ball.get_velocity()
				if velocity.length() > 0.1:
					return true
			elif "velocity" in ball:
				var velocity = ball.velocity
				if velocity.length() > 0.1:
					return true
	
	# Also check for any knives in the scene that might be in flight
	var knives = get_tree().get_nodes_in_group("knives")
	for knife in knives:
		if is_instance_valid(knife):
			if knife.has_method("is_in_flight"):
				if knife.is_in_flight():
					return true
			elif knife.has_method("get_velocity"):
				var velocity = knife.get_velocity()
				if velocity.length() > 0.1:
					return true
			elif "velocity" in knife:
				var velocity = knife.velocity
				if velocity.length() > 0.1:
					return true
	
	# Also check for any grenades in the scene that might be in flight
	var grenades = get_tree().get_nodes_in_group("grenades")
	for grenade in grenades:
		if is_instance_valid(grenade):
			if grenade.has_method("is_in_flight"):
				if grenade.is_in_flight():
					return true
			elif grenade.has_method("get_velocity"):
				var velocity = grenade.get_velocity()
				if velocity.length() > 0.1:
					return true
			elif "velocity" in grenade:
				var velocity = grenade.velocity
				if velocity.length() > 0.1:
					return true
	
	return false

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
	
	# Check if we have a throwing knife reference
	if throwing_knife and is_instance_valid(throwing_knife):
		if throwing_knife.has_method("is_in_flight"):
			if throwing_knife.is_in_flight():
				return false  # Knife is in flight, not available
		elif throwing_knife.has_method("get_velocity"):
			var velocity = throwing_knife.get_velocity()
			if velocity.length() > 0.1:
				return false  # Knife is moving, not available
		elif "velocity" in throwing_knife:
			var velocity = throwing_knife.velocity
			if velocity.length() > 0.1:
				return false  # Knife is moving, not available
	
	# Check if we have a grenade reference
	if grenade and is_instance_valid(grenade):
		if grenade.has_method("is_in_flight"):
			if grenade.is_in_flight():
				return false  # Grenade is in flight, not available
		elif grenade.has_method("get_velocity"):
			var velocity = grenade.get_velocity()
			if velocity.length() > 0.1:
				return false  # Grenade is moving, not available
		elif "velocity" in grenade:
			var velocity = grenade.velocity
			if velocity.length() > 0.1:
				return false  # Grenade is moving, not available
	
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
	
	# Also check for any knives in the scene
	var knives = get_tree().get_nodes_in_group("knives")
	for knife in knives:
		if is_instance_valid(knife):
			if knife.has_method("is_in_flight"):
				if knife.is_in_flight():
					return false  # Knife is in flight, not available
			elif knife.has_method("get_velocity"):
				var velocity = knife.get_velocity()
				if velocity.length() > 0.1:
					return false  # Knife is moving, not available
			elif "velocity" in knife:
				var velocity = knife.velocity
				if velocity.length() > 0.1:
					return false  # Knife is moving, not available
	
	# Also check for any grenades in the scene
	var grenades = get_tree().get_nodes_in_group("grenades")
	for grenade in grenades:
		if is_instance_valid(grenade):
			if grenade.has_method("is_in_flight"):
				if grenade.is_in_flight():
					return false  # Grenade is in flight, not available
			elif grenade.has_method("get_velocity"):
				var velocity = grenade.get_velocity()
				if velocity.length() > 0.1:
					return false  # Grenade is moving, not available
			elif "velocity" in grenade:
				var velocity = grenade.velocity
				if velocity.length() > 0.1:
					return false  # Grenade is moving, not available
	
	return true  # No balls, knives, or grenades are in flight or landed, so launch is available

func set_ball_in_flight(in_flight: bool) -> void:
	"""Set the ball in flight state"""
	ball_in_flight = in_flight
	print("Ball in flight state set to: ", in_flight)

# Vertical parallax effect methods
func setup_vertical_parallax(grid_container: Control, obstacle_layer_node: Control, bg_manager: Node) -> void:
	"""Setup references for vertical parallax effect"""
	world_grid_container = grid_container
	obstacle_layer = obstacle_layer_node
	background_manager = bg_manager
	# camera_container is already set by the course
	print("✓ Vertical parallax setup complete")

func activate_vertical_parallax() -> void:
	"""Activate the vertical parallax effect during shot charging"""
	if vertical_parallax_active:
		return
	
	vertical_parallax_active = true
	vertical_parallax_activated.emit()
	
	# Store original camera container position
	if camera_container:
		original_camera_container_position = camera_container.position
	
	# Start the transition to squished state (squish world, compensate sprites)
	_animate_vertical_parallax(VERTICAL_SQUISH_MIN, BACKGROUND_COMPRESSION_MIN, SPRITE_COMPENSATION_MAX)

func deactivate_vertical_parallax() -> void:
	"""Deactivate the vertical parallax effect"""
	if not vertical_parallax_active:
		return
	
	vertical_parallax_active = false
	vertical_parallax_deactivated.emit()
	
	# Return to normal state
	_animate_vertical_parallax(1.0, 1.0, 1.0)

func _animate_vertical_parallax(target_squish: float, target_compression: float, target_sprite_compensation: float) -> void:
	"""Animate the vertical parallax transition"""
	# Kill any existing tween
	if vertical_parallax_tween:
		vertical_parallax_tween.kill()
	
	vertical_parallax_tween = get_tree().create_tween()
	vertical_parallax_tween.set_trans(Tween.TRANS_QUINT)
	vertical_parallax_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Animate the squish factor
	vertical_parallax_tween.tween_method(
		_update_vertical_parallax,
		vertical_squish_factor,
		target_squish,
		VERTICAL_PARALLAX_DURATION
	)
	
	# Animate the background compression
	vertical_parallax_tween.parallel().tween_method(
		_update_background_compression,
		background_compression_factor,
		target_compression,
		VERTICAL_PARALLAX_DURATION
	)
	
	# Animate the sprite compensation
	vertical_parallax_tween.parallel().tween_method(
		_update_sprite_compensation,
		sprite_compensation_factor,
		target_sprite_compensation,
		VERTICAL_PARALLAX_DURATION
	)
	
	# Connect to tween completion to emit signal
	vertical_parallax_tween.finished.connect(_on_vertical_parallax_animation_complete)

func _update_vertical_parallax(squish_factor: float) -> void:
	"""Update the vertical squish effect on the world grid"""
	vertical_squish_factor = squish_factor
	
	if obstacle_layer:
		# Apply Y scaling to the obstacle layer (contains tiles and objects)
		obstacle_layer.scale.y = squish_factor
	
	if world_grid_container:
		# Apply Y scaling to the grid container (contains the player)
		world_grid_container.scale.y = squish_factor

func _update_background_compression(compression_factor: float) -> void:
	"""Update the background layer compression"""
	background_compression_factor = compression_factor
	
	if background_manager and background_manager.has_method("adjust_layer_position"):
		# Move background layers closer to TreeLine1 during shot view
		var compression_offset = (1.0 - compression_factor) * 500.0  # Move up to 500 pixels closer
		
		# Adjust all background layers except Sky with specific Y positions
		background_manager.adjust_layer_position("TreeLine", Vector2(0, -910.77 + compression_offset))
		background_manager.adjust_layer_position("TreeLine2", Vector2(0, -936.145 + compression_offset))
		background_manager.adjust_layer_position("TreeLine3", Vector2(0, -990.785 + compression_offset))
		background_manager.adjust_layer_position("Hill", Vector2(0, -826.915 + compression_offset))
		background_manager.adjust_layer_position("DistantHill", Vector2(0, -1027.225 + compression_offset))
		background_manager.adjust_layer_position("City", Vector2(0, -925.485 + compression_offset))
		background_manager.adjust_layer_position("Clouds", Vector2(0, -1700.0 + compression_offset))
		background_manager.adjust_layer_position("Mountains", Vector2(0, -987.625 + compression_offset))
		background_manager.adjust_layer_position("Horizon", Vector2(0, 3122.71 + compression_offset))
		background_manager.adjust_layer_position("Foreground", Vector2(0, -720 + compression_offset))
		

func _update_sprite_compensation(compensation_factor: float) -> void:
	"""Update the sprite compensation scaling for objects and NPCs"""
	sprite_compensation_factor = compensation_factor
	
	# Find and scale all relevant objects and NPCs
	var objects_to_scale = []
	
	# Add objects from obstacle layer (trees, pins, gang members, police, boulders, oil drums, shops)
	if obstacle_layer:
		for child in obstacle_layer.get_children():
			if is_instance_valid(child) and child is Node2D:
				objects_to_scale.append(child)
	
	# Add player from grid container
	if world_grid_container:
		for child in world_grid_container.get_children():
			if is_instance_valid(child) and child is Node2D and child.name == "Player":
				objects_to_scale.append(child)
	
	# Apply compensation scaling to all objects
	for obj in objects_to_scale:
		if is_instance_valid(obj):
			obj.scale.y = compensation_factor

func _on_vertical_parallax_animation_complete() -> void:
	"""Called when vertical parallax animation completes"""
	vertical_parallax_animation_complete.emit()
	print("✓ Vertical parallax animation complete")

func cleanup():
	"""Clean up launch manager resources"""
	if golf_ball and is_instance_valid(golf_ball):
		golf_ball.queue_free()
		golf_ball = null
	
	# Hide player meters
	if player_node and player_node.has_method("hide_power_meter"):
		player_node.hide_power_meter()
	if player_node and player_node.has_method("hide_height_meter"):
		player_node.hide_height_meter() 
