extends Resource
class_name SpeechTriggerConfig

# SpeechTriggerConfig - Configuration for a single speech trigger
# This makes it easy to define speech triggers in the inspector

@export var event_type: String = ""  # Type of event (e.g., "player_placed_on_tee")
@export var condition: String = ""   # Condition string (e.g., "hole_index == 0 and character_id == 2")
@export var speech_id: String = ""   # Speech ID to trigger
@export var enabled: bool = true     # Whether this trigger is enabled
@export var repeatable: bool = false # Whether this can trigger multiple times
@export var priority: int = 0        # Priority (higher numbers trigger first) 