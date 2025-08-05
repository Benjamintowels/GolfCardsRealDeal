extends Node2D

# SpeechBubble - A scene that can be added to Character scenes or NPCs etc
# that defaults to invisible and if triggered should appear and display the appropriate text

@onready var speech_bubble_sprite: Sprite2D = $SpeechBubbleSprite
@onready var label: Label = $Label
@onready var speech_boop: AudioStreamPlayer2D = $SpeechBoop

# Speech bubble properties
var speech_text: String = "Hello"
var speech_duration: float = 3.0
var speaker: Node = null
var fade_timer: Timer

func _ready():
	# Start invisible
	visible = false
	speech_bubble_sprite.visible = false
	label.visible = false
	
	# Create fade timer
	fade_timer = Timer.new()
	fade_timer.one_shot = true
	add_child(fade_timer)
	fade_timer.timeout.connect(_on_fade_timer_timeout)

# Setup speech bubble with text, duration, and speaker reference
func setup_speech(text: String, duration: float, speaker_node: Node):
	"""Setup the speech bubble with the given text and duration"""
	speech_text = text
	speech_duration = duration
	speaker = speaker_node
	
	# Process text to ensure it fits properly
	var processed_text = _process_text_for_bubble(text)
	
	# Update label text
	label.text = processed_text
	
	# Show the speech bubble
	visible = true
	speech_bubble_sprite.visible = true
	label.visible = true
	
	# Ensure parent is visible
	if get_parent():
		get_parent().visible = true
	
	# Only play SpeechBoop for Benny (Character2), not for Flippy
	# Flippy has his own character audio that plays separately
	if speech_boop and speech_boop.stream:
		# Check if this is Benny's speech bubble
		var is_benny = false
		if speaker_node and speaker_node.name == "Character2":
			is_benny = true
		
		if is_benny:
			speech_boop.play()
	
	# Start fade timer
	fade_timer.start(speech_duration)

func _process_text_for_bubble(text: String) -> String:
	"""Process text to ensure it fits properly in the speech bubble"""
	# Remove any existing line breaks and normalize spacing
	text = text.strip_edges()
	
	# For very long lines, we can add some manual line breaks to help with readability
	# The label will handle autowrapping, but we can assist with natural break points
	if text.length() > 60:
		# Look for natural break points like "and", "but", "or", etc.
		var break_points = [" and ", " but ", " or ", " so ", " well ", " uh ", " um ", " you ", " for ", " with "]
		for break_point in break_points:
			if text.contains(break_point):
				# Replace with line break to help with wrapping
				text = text.replace(break_point, "\n" + break_point.strip_edges())
				break
	
	return text

# Called when the fade timer expires
func _on_fade_timer_timeout():
	"""Handle the end of speech duration"""
	# Only auto-hide if duration is not very long (manual control)
	if speech_duration < 100.0:
		# Emit signal to SpeechManager
		var speech_manager = get_node_or_null("/root/SpeechManager")
		if speech_manager:
			speech_manager.emit_signal("speech_ended", "", speaker)
		
		# Hide the speech bubble
		visible = false
		speech_bubble_sprite.visible = false
		label.visible = false
		
		# Remove from active bubbles
		if speech_manager and self in speech_manager.active_speech_bubbles:
			speech_manager.active_speech_bubbles.erase(self)
	
	# Don't queue_free since this is an existing node in the scene
	# Just hide it and let it be reused

# Manual stop function
func stop_speech():
	"""Manually stop the speech bubble"""
	if fade_timer:
		fade_timer.stop()
	_on_fade_timer_timeout()

# Simple set_text function for compatibility
func set_text(text: String):
	"""Set the text of the speech bubble"""
	if label:
		label.text = text
		visible = true
		speech_bubble_sprite.visible = true
		label.visible = true
