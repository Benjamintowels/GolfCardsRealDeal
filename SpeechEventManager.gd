extends Node

# SpeechEventManager - Handles speech triggers through events and signals
# This keeps all speech logic separate from the main course logic

signal player_placed_on_tee(hole_index: int, character_id: int, player_node: Node)
signal player_shot_ball(shot_type: String, character_id: int, player_node: Node)
signal player_entered_area(area_name: String, character_id: int, player_node: Node)
signal game_event_triggered(event_name: String, character_id: int, player_node: Node)

# Event definitions - easy to add new events
var SPEECH_EVENTS = {
	"player_placed_on_tee": {
		"hole1_benny": {
			"condition": "hole_index == 0 and character_id == 2",
			"speech_id": "benny_hole1_tee"
		},
		"hole1_layla": {
			"condition": "hole_index == 0 and character_id == 1", 
			"speech_id": "layla_hole1_tee"
		},
		"hole1_clark": {
			"condition": "hole_index == 0 and character_id == 3",
			"speech_id": "clark_hole1_tee"
		}
	},
	"player_shot_ball": {
		"good_shot": {
			"condition": "shot_type == 'good'",
			"speech_id": "good_shot"
		},
		"bad_shot": {
			"condition": "shot_type == 'bad'",
			"speech_id": "bad_shot"
		}
	},
	"player_entered_area": {
		"shop_entrance": {
			"condition": "area_name == 'shop'",
			"speech_id": "golfsmith_greeting"
		}
	}
}

func _ready():
	# Connect to our own signals to handle speech triggering
	player_placed_on_tee.connect(_on_player_placed_on_tee)
	player_shot_ball.connect(_on_player_shot_ball)
	player_entered_area.connect(_on_player_entered_area)
	game_event_triggered.connect(_on_game_event_triggered)

# Public functions to trigger events from anywhere
func trigger_player_placed_on_tee(hole_index: int, character_id: int, player_node: Node):
	"""Trigger when player is placed on tee"""
	emit_signal("player_placed_on_tee", hole_index, character_id, player_node)

func trigger_player_shot_ball(shot_type: String, character_id: int, player_node: Node):
	"""Trigger when player shoots the ball"""
	emit_signal("player_shot_ball", shot_type, character_id, player_node)

func trigger_player_entered_area(area_name: String, character_id: int, player_node: Node):
	"""Trigger when player enters a specific area"""
	emit_signal("player_entered_area", area_name, character_id, player_node)

func trigger_game_event(event_name: String, character_id: int, player_node: Node):
	"""Trigger a custom game event"""
	emit_signal("game_event_triggered", event_name, character_id, player_node)

# Event handlers
func _on_player_placed_on_tee(hole_index: int, character_id: int, player_node: Node):
	"""Handle player placed on tee event"""
	var event_key = "hole" + str(hole_index + 1) + "_" + get_character_name(character_id)
	check_and_trigger_speech("player_placed_on_tee", event_key, character_id, player_node)

func _on_player_shot_ball(shot_type: String, character_id: int, player_node: Node):
	"""Handle player shot ball event"""
	check_and_trigger_speech("player_shot_ball", shot_type, character_id, player_node)

func _on_player_entered_area(area_name: String, character_id: int, player_node: Node):
	"""Handle player entered area event"""
	check_and_trigger_speech("player_entered_area", area_name, character_id, player_node)

func _on_game_event_triggered(event_name: String, character_id: int, player_node: Node):
	"""Handle custom game event"""
	check_and_trigger_speech("game_event_triggered", event_name, character_id, player_node)

# Helper functions
func check_and_trigger_speech(event_type: String, event_key: String, character_id: int, player_node: Node):
	"""Check if speech should be triggered and trigger it"""
	if not SPEECH_EVENTS.has(event_type):
		return
	
	var events = SPEECH_EVENTS[event_type]
	if not events.has(event_key):
		return
	
	var event_data = events[event_key]
	var speech_id = event_data.speech_id
	
	# Get speech manager and trigger speech
	var speech_manager = get_node_or_null("/root/SpeechManager")
	if speech_manager and speech_manager.has_speech(speech_id):
		speech_manager.trigger_speech(speech_id, player_node)
		print("Triggered speech: ", speech_id, " for event: ", event_type, ":", event_key)

func get_character_name(character_id: int) -> String:
	"""Get character name from ID"""
	match character_id:
		1: return "layla"
		2: return "benny"
		3: return "clark"
		_: return "benny"

# Easy way to add new speech events
func add_speech_event(event_type: String, event_key: String, speech_id: String, condition: String = ""):
	"""Add a new speech event dynamically"""
	if not SPEECH_EVENTS.has(event_type):
		SPEECH_EVENTS[event_type] = {}
	
	SPEECH_EVENTS[event_type][event_key] = {
		"condition": condition,
		"speech_id": speech_id
	}
	print("Added speech event: ", event_type, ":", event_key, " -> ", speech_id) 