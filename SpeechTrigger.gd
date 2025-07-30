extends Node2D

# SpeechTrigger - A component that can be attached to any object to trigger speech
# This makes it easy to add speech triggers to characters, NPCs, objects, or locations

@export var speech_id: String = ""
@export var trigger_on_ready: bool = false
@export var trigger_on_area_entered: bool = false
@export var trigger_on_interaction: bool = false
@export var trigger_on_custom_signal: String = ""
@export var auto_trigger_delay: float = 0.0
@export var repeatable: bool = false
@export var trigger_condition: String = ""  # Custom condition check

# Internal state
var has_triggered: bool = false
var area2d: Area2D
var collision_shape: CollisionShape2D

func _ready():
	# Set up trigger based on configuration
	if trigger_on_ready:
		if auto_trigger_delay > 0:
			await get_tree().create_timer(auto_trigger_delay).timeout
		trigger_speech()
	
	if trigger_on_area_entered:
		setup_area_trigger()
	
	if trigger_on_interaction:
		setup_interaction_trigger()
	
	if trigger_on_custom_signal != "":
		setup_custom_signal_trigger()

# Setup area-based trigger
func setup_area_trigger():
	"""Setup trigger that activates when player enters area"""
	area2d = Area2D.new()
	add_child(area2d)
	
	collision_shape = CollisionShape2D.new()
	area2d.add_child(collision_shape)
	
	# Set up collision shape (default to a reasonable size)
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 100)
	collision_shape.shape = shape
	
	# Connect area signals
	area2d.body_entered.connect(_on_area_entered)
	area2d.area_entered.connect(_on_area_entered)

# Setup interaction trigger
func setup_interaction_trigger():
	"""Setup trigger that activates on interaction (key press, etc.)"""
	# This can be customized based on your interaction system
	# For now, we'll use a simple timer-based approach
	var interaction_timer = Timer.new()
	interaction_timer.wait_time = 0.1
	interaction_timer.timeout.connect(_check_for_interaction)
	add_child(interaction_timer)
	interaction_timer.start()

# Setup custom signal trigger
func setup_custom_signal_trigger():
	"""Setup trigger that activates on a custom signal"""
	# Connect to the specified signal from the parent
	if get_parent().has_signal(trigger_on_custom_signal):
		get_parent().connect(trigger_on_custom_signal, _on_custom_signal_triggered)

# Trigger the speech
func trigger_speech():
	"""Trigger the speech if conditions are met"""
	if not repeatable and has_triggered:
		return
	
	if not check_trigger_condition():
		return
	
	# Get the speech manager
	var speech_manager = get_node_or_null("/root/SpeechManager")
	if not speech_manager:
		print("Warning: SpeechManager not found!")
		return
	
	# Determine the speaker (usually the parent of this trigger)
	var speaker = get_parent()
	if not speaker:
		speaker = self
	
	# Trigger the speech
	if speech_manager.trigger_speech(speech_id, speaker):
		has_triggered = true

# Check custom trigger condition
func check_trigger_condition() -> bool:
	"""Check if the trigger condition is met"""
	if trigger_condition == "":
		return true
	
	# You can add custom condition logic here
	# For example, check game state, character position, etc.
	
	# Example conditions:
	match trigger_condition:
		"player_on_tee":
			# Check if player is on tee position
			return check_player_on_tee()
		"first_time":
			# Check if this is the first time
			return not has_triggered
		"character_specific":
			# Check if specific character is selected
			return check_character_condition()
		_:
			return true

# Example condition checks
func check_player_on_tee() -> bool:
	"""Check if player is on tee position"""
	# This would need to be implemented based on your game's logic
	return true

func check_character_condition() -> bool:
	"""Check character-specific conditions"""
	# This would need to be implemented based on your game's logic
	return true

# Area trigger callbacks
func _on_area_entered(body_or_area: Node):
	"""Called when something enters the trigger area"""
	if body_or_area.name == "Player1" or "Player" in body_or_area.name:
		trigger_speech()

# Interaction trigger callback
func _check_for_interaction():
	"""Check for interaction input"""
	# This can be customized based on your input system
	if Input.is_action_just_pressed("interact"):
		trigger_speech()

# Custom signal trigger callback
func _on_custom_signal_triggered():
	"""Called when the custom signal is emitted"""
	trigger_speech()

# Public function to manually trigger speech
func manual_trigger():
	"""Manually trigger the speech"""
	trigger_speech()

# Reset trigger state
func reset_trigger():
	"""Reset the trigger state (useful for repeatable triggers)"""
	has_triggered = false

# Set speech ID at runtime
func set_speech_id(new_speech_id: String):
	"""Set the speech ID at runtime"""
	speech_id = new_speech_id 