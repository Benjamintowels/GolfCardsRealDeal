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
	
	# Update label text
	label.text = speech_text
	
	# Show the speech bubble
	visible = true
	speech_bubble_sprite.visible = true
	label.visible = true
	
	# Play speech sound
	if speech_boop and speech_boop.stream:
		speech_boop.play()
	
	# Start fade timer
	fade_timer.start(speech_duration)

# Called when the fade timer expires
func _on_fade_timer_timeout():
	"""Handle the end of speech duration"""
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
