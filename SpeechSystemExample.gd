extends Node

# SpeechSystemExample - Demonstrates the elegant event-driven speech system
# This shows how easy it is to add new speeches without touching course_1.gd

func _ready():
	# Example 1: Add new speeches dynamically
	add_example_speeches()
	
	# Example 2: Add new event triggers
	add_example_triggers()
	
	# Example 3: Show how to trigger events from anywhere
	await get_tree().create_timer(1.0).timeout
	demonstrate_event_triggering()

# Add some example speeches to the system
func add_example_speeches():
	"""Add example speeches to demonstrate the system"""
	var speech_manager = get_node_or_null("/root/SpeechManager")
	if not speech_manager:
		print("SpeechManager not found!")
		return
	
	# Add character-specific speeches
	speech_manager.add_speech("benny_good_shot", "That's how you do it!", 2.5, "Benny")
	speech_manager.add_speech("layla_encouragement", "You've got this!", 2.0, "Layla")
	speech_manager.add_speech("clark_commentary", "Interesting approach...", 3.0, "Clark")
	
	# Add location-specific speeches
	speech_manager.add_speech("hole1_greeting", "Welcome to Hole 1!", 3.0, "Course")
	speech_manager.add_speech("shop_entrance", "Pro Shop - Best equipment in town!", 3.5, "Sign")
	
	# Add event-specific speeches
	speech_manager.add_speech("first_par", "Par! Not bad for a beginner.", 3.0, "Commentator")
	speech_manager.add_speech("birdie_celebration", "Birdie! Fantastic shot!", 2.5, "Commentator")

# Add example event triggers
func add_example_triggers():
	"""Add example event triggers to demonstrate the system"""
	var speech_event_manager = get_node_or_null("/root/SpeechEventManager")
	if not speech_event_manager:
		print("SpeechEventManager not found!")
		return
	
	# Add birdie celebration trigger
	speech_event_manager.add_speech_event("game_event_triggered", "birdie_celebration", "birdie_celebration")
	
	# Add par celebration trigger
	speech_event_manager.add_speech_event("game_event_triggered", "first_par", "first_par")
	
	# Add shop entrance trigger
	speech_event_manager.add_speech_event("player_entered_area", "shop_entrance", "shop_entrance")

# Demonstrate how to trigger events from anywhere
func demonstrate_event_triggering():
	"""Show how easy it is to trigger speech events"""
	var speech_event_manager = get_node_or_null("/root/SpeechEventManager")
	if not speech_event_manager:
		return
	
	# Get the player node (assuming it's named "Player1")
	var player = get_node_or_null("../Player1")
	if not player:
		# Try to find any player node
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Example 1: Trigger a birdie celebration
		speech_event_manager.trigger_game_event("birdie", Global.selected_character, player)
		
		# Example 2: Trigger a par celebration
		await get_tree().create_timer(4.0).timeout
		speech_event_manager.trigger_game_event("par", Global.selected_character, player)
		
		# Example 3: Trigger shop entrance
		await get_tree().create_timer(4.0).timeout
		speech_event_manager.trigger_player_entered_area("shop", Global.selected_character, player)

# Example: How to trigger speech from a character script
func trigger_character_speech_example():
	"""Example of how to trigger speech from a character script"""
	var speech_event_manager = get_node_or_null("/root/SpeechEventManager")
	if not speech_event_manager:
		return
	
	# Trigger a good shot reaction
	speech_event_manager.trigger_player_shot_ball("good", Global.selected_character, self)

# Example: How to trigger speech from an NPC script
func trigger_npc_speech_example():
	"""Example of how to trigger speech from an NPC script"""
	var speech_event_manager = get_node_or_null("/root/SpeechEventManager")
	if not speech_event_manager:
		return
	
	# Trigger NPC greeting when player approaches
	speech_event_manager.trigger_player_entered_area("npc_greeting", Global.selected_character, self)

# Example: How to trigger speech from an object script
func trigger_object_speech_example():
	"""Example of how to trigger speech from an object script"""
	var speech_event_manager = get_node_or_null("/root/SpeechEventManager")
	if not speech_event_manager:
		return
	
	# Trigger object interaction
	speech_event_manager.trigger_game_event("object_interaction", Global.selected_character, self)

# Example: How to add a completely new speech trigger
func add_new_speech_trigger_example():
	"""Example of how to add a new speech trigger dynamically"""
	var speech_manager = get_node_or_null("/root/SpeechManager")
	var speech_event_manager = get_node_or_null("/root/SpeechEventManager")
	
	if not speech_manager or not speech_event_manager:
		return
	
	# Step 1: Add the speech
	speech_manager.add_speech("hole_completion", "Hole complete! Great job!", 3.0, "Commentator")
	
	# Step 2: Add the trigger
	speech_event_manager.add_speech_event("game_event_triggered", "hole_completion", "hole_completion")
	
	# Step 3: Trigger it from anywhere
	speech_event_manager.trigger_game_event("hole_completion", Global.selected_character, self)

# Example: How to listen for speech events
func _on_speech_started(speech_id: String, speaker: Node):
	"""Called when a speech starts"""
	print("Speech started: ", speech_id, " by ", speaker.name)

func _on_speech_ended(speech_id: String, speaker: Node):
	"""Called when a speech ends"""
	print("Speech ended: ", speech_id, " by ", speaker.name)

# Connect to speech manager signals
func connect_to_speech_signals():
	"""Connect to speech manager signals"""
	var speech_manager = get_node_or_null("/root/SpeechManager")
	if speech_manager:
		speech_manager.speech_started.connect(_on_speech_started)
		speech_manager.speech_ended.connect(_on_speech_ended) 