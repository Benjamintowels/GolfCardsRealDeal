extends Resource
class_name SpeechConfig

# SpeechConfig - A configuration resource for easy speech trigger management
# This makes it incredibly easy to add new speeches without touching any code

@export var speech_triggers: Array[SpeechTriggerConfig] = []

# Example configuration - you can edit this in the inspector
func get_default_triggers() -> Array[SpeechTriggerConfig]:
	var triggers: Array[SpeechTriggerConfig] = []
	
	# Hole 1 tee speeches
	var hole1_benny = SpeechTriggerConfig.new()
	hole1_benny.event_type = "player_placed_on_tee"
	hole1_benny.condition = "hole_index == 0 and character_id == 2"
	hole1_benny.speech_id = "benny_hole1_tee"
	triggers.append(hole1_benny)
	
	var hole1_layla = SpeechTriggerConfig.new()
	hole1_layla.event_type = "player_placed_on_tee"
	hole1_layla.condition = "hole_index == 0 and character_id == 1"
	hole1_layla.speech_id = "layla_hole1_tee"
	triggers.append(hole1_layla)
	
	var hole1_clark = SpeechTriggerConfig.new()
	hole1_clark.event_type = "player_placed_on_tee"
	hole1_clark.condition = "hole_index == 0 and character_id == 3"
	hole1_clark.speech_id = "clark_hole1_tee"
	triggers.append(hole1_clark)
	
	# Shot reactions
	var good_shot = SpeechTriggerConfig.new()
	good_shot.event_type = "player_shot_ball"
	good_shot.condition = "shot_type == 'good'"
	good_shot.speech_id = "good_shot"
	triggers.append(good_shot)
	
	var bad_shot = SpeechTriggerConfig.new()
	bad_shot.event_type = "player_shot_ball"
	bad_shot.condition = "shot_type == 'bad'"
	bad_shot.speech_id = "bad_shot"
	triggers.append(bad_shot)
	
	return triggers 