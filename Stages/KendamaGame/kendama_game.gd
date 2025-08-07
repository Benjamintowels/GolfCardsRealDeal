extends Node2D

# Basic Kendama game where you have to yank the Ken upwards and it will pull the Dama ball up into the air with gravity.

@onready var ken = $Ken
@onready var dama = $Dama
@onready var return_button = $UI/ReturnButton
@onready var spike_counter = $UI/SpikeCounter
@onready var status_label = $UI/StatusLabel
@onready var spike_sound = $SpikeSound
@onready var wall_sound = $WallSound

# String physics parameters
var string_length = 200.0  # Maximum distance between Ken and Dama
var string_tension = 0.8   # How much the string pulls (0-1)
var gravity = 980.0        # Gravity strength
var damping = 0.98         # Air resistance

# Spike detection
var spike_cooldown = 0.5  # Time between spikes
var last_spike_time = 0.0
var spike_count = 0
var spike_effect_timer = 0.0

# Physics-based spike system
var dama_is_on_tip = false
var tip_landing_offset = Vector2(0, -73)  # Offset from Ken center to tip position
var tip_landing_threshold = 25.0  # How close Dama needs to be to land on tip
var tip_balance_threshold = 15.0  # How much the Dama can tilt before falling off
var tip_velocity_threshold = 200.0  # Maximum velocity for staying on tip

# Mouse tracking
var last_mouse_pos = Vector2.ZERO
var mouse_velocity = Vector2.ZERO

# Area2D for physics
@onready var ken_area = ken.get_node("Area2D")
@onready var dama_area = dama.get_node("DamaArea")

func _ready():
	# Store pre-round experience values for Final Score Display animation
	var file_level_manager = FileLevelManager
	if file_level_manager:
		file_level_manager.store_pre_round_values()
		print("Pre-round experience values stored for kendama game animation")
	
	# Set initial positions
	ken.position = Vector2(640, 360)  # Center of screen
	dama.position = Vector2(640, 600)  # Below the Ken
	
	# Initialize mouse position
	last_mouse_pos = get_global_mouse_position()
	
	# Connect return button
	return_button.pressed.connect(_on_return_button_pressed)

func _process(delta):
	# Update mouse velocity
	var current_mouse_pos = get_global_mouse_position()
	mouse_velocity = (current_mouse_pos - last_mouse_pos) / delta
	last_mouse_pos = current_mouse_pos
	
	# Move Ken based on mouse movement
	ken.position = current_mouse_pos
	
	# Apply string physics to Dama
	_apply_string_physics(delta)
	
	# Update spike effect timer
	if spike_effect_timer > 0:
		spike_effect_timer -= delta

# All physics interactions are now handled by Godot's built-in collision system via KenArea and DamaArea
# No manual collision checks are needed for wall bounces or reflections
# Only spike detection and sound logic remain custom

func _apply_string_physics(delta):
	# Don't apply string physics if Dama is on tip
	if dama_is_on_tip:
		return
		
	# Calculate distance between Ken and Dama
	var distance = ken.position.distance_to(dama.position)
	
	# If distance exceeds string length, apply tension force
	if distance > string_length:
		var direction = (ken.position - dama.position).normalized()
		var tension_force = direction * string_tension * (distance - string_length) * 1000
		
		# Apply tension force to Dama's velocity
		dama.velocity += tension_force * delta

func _handle_spike(delta):
	var current_time = Time.get_time_dict_from_system()["second"]
	if current_time - last_spike_time > spike_cooldown:
		spike_count += 1
		last_spike_time = current_time
		spike_effect_timer = 0.3  # Visual effect duration
		print("SPIKE! Count: ", spike_count)
		
		# Update spike counter display
		spike_counter.text = "Spikes: " + str(spike_count)
		
		# Play spike sound
		spike_sound.play()
		
		# Start physics-based tip interaction
		_start_tip_interaction()

func _start_tip_interaction():
	dama_is_on_tip = true
	# Tell Dama it's on tip
	dama.set_on_tip(true)
	# Update status
	status_label.text = "Status: On Tip"
	print("Dama landed on tip!")

func _check_tip_detachment(delta):
	var tip_position = ken.position + tip_landing_offset
	
	# Apply physics-based tip interaction
	_apply_tip_physics(delta)
	
	# Check if Dama should fall off based on physics
	if _should_dama_fall_off():
		_detach_dama_from_tip()

func _apply_tip_physics(delta):
	var tip_position = ken.position + tip_landing_offset
	
	# Calculate distance from tip
	var distance_to_tip = dama.position.distance_to(tip_position)
	
	# If Dama is close to tip, apply physics-based interaction
	if distance_to_tip < tip_landing_threshold:
		var direction_to_tip = (tip_position - dama.position).normalized()
		
		# Calculate how much the Dama is "sitting" on the tip
		var tip_support_factor = 1.0 - (distance_to_tip / tip_landing_threshold)
		
		# Apply centering force (stronger when closer to tip)
		var centering_force = direction_to_tip * 800.0 * tip_support_factor
		dama.velocity += centering_force * delta
		
		# Apply friction/damping based on how well the Dama is balanced
		var friction = 0.98 - (0.03 * tip_support_factor)  # More friction when better balanced
		dama.velocity *= friction
		
		# Reduce gravity effect based on how well balanced the Dama is
		var gravity_reduction = 0.2 + (0.5 * tip_support_factor)  # Less gravity when better balanced
		dama.velocity.y += gravity * delta * gravity_reduction
		
		# Apply Ken's movement to Dama (but with some lag for realism)
		var ken_movement = ken.position - last_mouse_pos
		dama.velocity += ken_movement * 0.3  # Dama follows Ken's movement
	else:
		# Dama is too far from tip, let it fall naturally
		dama.velocity.y += gravity * delta

func _should_dama_fall_off():
	var tip_position = ken.position + tip_landing_offset
	var distance_to_tip = dama.position.distance_to(tip_position)
	
	# Check if Dama is too far from tip
	if distance_to_tip > tip_landing_threshold:
		return true
	
	# Check if Dama's velocity is too high (will slide off)
	if dama.velocity.length() > tip_velocity_threshold:
		return true
	
	# Check if Ken is moving down too fast
	var ken_velocity = (ken.position - last_mouse_pos) / (1.0/60.0)  # Assuming 60 FPS
	if ken_velocity.y > tip_velocity_threshold:
		return true
	
	return false

func _detach_dama_from_tip():
	dama_is_on_tip = false
	# Tell Dama it's no longer on tip
	dama.set_on_tip(false)
	# Update status
	status_label.text = "Status: Free"
	print("Dama fell off tip!")

func _on_dama_hole_entered(body):
	# Ken tip entered the Dama hole - this is a spike attempt
	if not dama_is_on_tip:
		_handle_spike(1.0/60.0)  # Pass delta time

func _on_return_button_pressed():
	# Return to main menu
	get_tree().change_scene_to_file("res://Main.tscn") 

func _draw():
	# Draw the string between Ken and Dama
	if ken and dama:
		var string_color = Color.WHITE
		if spike_effect_timer > 0:
			# Flash the string when spike happens
			string_color = Color.YELLOW
		elif dama_is_on_tip:
			# Green string when Dama is on tip
			string_color = Color.GREEN
		else:
			# Check if Dama is close to tip for visual feedback
			var tip_position = ken.position + tip_landing_offset
			var distance_to_tip = dama.position.distance_to(tip_position)
			if distance_to_tip < tip_landing_threshold * 1.5:
				string_color = Color.ORANGE  # Orange when close to tip
		draw_line(ken.position, dama.position, string_color, 2.0) 
