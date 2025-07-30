extends Node

# SpeechManager - Global singleton for managing all speech bubbles and dialogue
# This system allows easy addition of new speeches and triggers them based on game events

signal speech_started(speech_id: String, speaker: Node)
signal speech_ended(speech_id: String, speaker: Node)

# Speech data structure - easy to add new speeches
var SPEECH_DATA = {
	# Character-specific speeches
	"benny_hole1_tee": {
		"text": "Let's do this!",
		"duration": 3.0,
		"character": "Benny"
	},
	"layla_hole1_tee": {
		"text": "Let's break a record!",
		"duration": 3.0,
		"character": "Layla"
	},
	"clark_hole1_tee": {
		"text": "Time to show them how it's done.",
		"duration": 3.0,
		"character": "Clark"
	},
	
	# Generic speeches
	"greeting": {
		"text": "Hello there!",
		"duration": 2.5,
		"character": "Generic"
	},
	"good_shot": {
		"text": "Nice shot!",
		"duration": 2.0,
		"character": "Generic"
	},
	"bad_shot": {
		"text": "Oops!",
		"duration": 2.0,
		"character": "Generic"
	},
	
	# NPC speeches
	"golfsmith_greeting": {
		"text": "Welcome to the pro shop!",
		"duration": 3.0,
		"character": "Golfsmith"
	},
	"police_warning": {
		"text": "Keep it clean out there!",
		"duration": 3.0,
		"character": "Police"
	}
}

# Active speech bubbles
var active_speech_bubbles: Array[Node] = []

# Speech bubble scene reference
var speech_bubble_scene: PackedScene

func _ready():
	# Load the speech bubble scene
	speech_bubble_scene = preload("res://Dialog/SpeechBubble.tscn")
	
	# Make this a singleton
	process_mode = Node.PROCESS_MODE_ALWAYS

# Add a new speech to the system
func add_speech(speech_id: String, text: String, duration: float = 3.0, character: String = "Generic"):
	"""Add a new speech that can be triggered"""
	SPEECH_DATA[speech_id] = {
		"text": text,
		"duration": duration,
		"character": character
	}

# Trigger speech on a specific node (character, NPC, object)
func trigger_speech(speech_id: String, speaker: Node) -> bool:
	"""Trigger a speech bubble on a specific speaker node"""
	if not SPEECH_DATA.has(speech_id):
		print("Warning: Speech ID '", speech_id, "' not found!")
		return false
	
	var speech_info = SPEECH_DATA[speech_id]
	
	# Check if speaker already has an active speech bubble
	var existing_bubble = get_speech_bubble_for_speaker(speaker)
	if existing_bubble:
		# Stop the existing speech
		stop_speech_bubble(existing_bubble)
	
	# Create new speech bubble
	var speech_bubble = create_speech_bubble(speech_info, speaker)
	if speech_bubble:
		active_speech_bubbles.append(speech_bubble)
		emit_signal("speech_started", speech_id, speaker)
		return true
	
	return false

# Create a speech bubble instance
func create_speech_bubble(speech_info: Dictionary, speaker: Node) -> Node:
	"""Create and position a speech bubble for the speaker"""
	# Try to find existing speech bubble in the speaker's scene
	var existing_bubble = find_existing_speech_bubble(speaker)
	if existing_bubble:
		# Use the existing speech bubble
		existing_bubble.setup_speech(speech_info.text, speech_info.duration, speaker)
		return existing_bubble
	
	# Fallback: create new speech bubble if none exists
	if not speech_bubble_scene:
		print("Error: Speech bubble scene not loaded!")
		return null
	
	var speech_bubble = speech_bubble_scene.instantiate()
	
	# Add to the speaker's parent (usually the main scene)
	if speaker.get_parent():
		speaker.get_parent().add_child(speech_bubble)
	else:
		# Fallback to current scene
		get_tree().current_scene.add_child(speech_bubble)
	
	# Set up the speech bubble
	speech_bubble.setup_speech(speech_info.text, speech_info.duration, speaker)
	
	return speech_bubble

# Find existing speech bubble in the speaker's scene
func find_existing_speech_bubble(speaker: Node) -> Node:
	"""Find an existing speech bubble in the speaker's scene"""
	# Look for SpeechBubble in the speaker's children
	for child in speaker.get_children():
		if child.has_method("setup_speech"):
			return child
	
	# Look for SpeechBubble in the speaker's parent's children
	if speaker.get_parent():
		for child in speaker.get_parent().get_children():
			if child.has_method("setup_speech"):
				return child
	
	return null

# Position speech bubble above the speaker
func position_speech_bubble(speech_bubble: Node, speaker: Node):
	"""Position the speech bubble above the speaker"""
	var speaker_pos = speaker.global_position
	
	# Get speaker's height for proper positioning
	var speaker_height = 0
	if speaker.has_method("get_height"):
		speaker_height = speaker.get_height()
	elif "height" in speaker:
		speaker_height = speaker.height
	
	# Position above the speaker with some offset
	var bubble_offset = Vector2(37, -128 - speaker_height)  # X37, Y-128 as requested
	speech_bubble.global_position = speaker_pos + bubble_offset

# Get existing speech bubble for a speaker
func get_speech_bubble_for_speaker(speaker: Node) -> Node:
	"""Find if a speaker already has an active speech bubble"""
	for bubble in active_speech_bubbles:
		if bubble.get("speaker") == speaker:
			return bubble
	return null

# Stop a specific speech bubble
func stop_speech_bubble(speech_bubble: Node):
	"""Stop and remove a speech bubble"""
	if speech_bubble in active_speech_bubbles:
		active_speech_bubbles.erase(speech_bubble)
	
	if is_instance_valid(speech_bubble):
		speech_bubble.queue_free()

# Stop all speech bubbles
func stop_all_speech():
	"""Stop all active speech bubbles"""
	for bubble in active_speech_bubbles.duplicate():
		stop_speech_bubble(bubble)

# Trigger speech based on character and location
func trigger_character_speech(character_name: String, location: String, speaker: Node) -> bool:
	"""Convenience function to trigger character-specific location speeches"""
	var speech_id = character_name.to_lower() + "_" + location
	return trigger_speech(speech_id, speaker)

# Get all available speech IDs
func get_all_speech_ids() -> Array[String]:
	"""Get a list of all available speech IDs"""
	return SPEECH_DATA.keys()

# Get speech info by ID
func get_speech_info(speech_id: String) -> Dictionary:
	"""Get speech information by ID"""
	if SPEECH_DATA.has(speech_id):
		return SPEECH_DATA[speech_id]
	return {}

# Check if a speech exists
func has_speech(speech_id: String) -> bool:
	"""Check if a speech ID exists"""
	return SPEECH_DATA.has(speech_id) 