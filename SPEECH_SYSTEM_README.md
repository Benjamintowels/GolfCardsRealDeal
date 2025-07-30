# Speech System Documentation

## Overview

The Speech System is a modular, easy-to-use dialogue system for your golf game. It allows you to easily add speech bubbles to any character, NPC, or object in your game with minimal setup.

## Components

### 1. SpeechManager (Global Singleton)
- **File**: `SpeechManager.gd`
- **Purpose**: Central manager for all speech functionality
- **Features**:
  - Stores all speech data
  - Manages active speech bubbles
  - Provides easy API for triggering speech
  - Handles speech bubble positioning and cleanup

### 2. SpeechBubble (Scene)
- **File**: `Dialog/SpeechBubble.tscn` + `Dialog/speech_bubble.gd`
- **Purpose**: Visual speech bubble that displays text and plays sound
- **Features**:
  - Auto-fades after specified duration
  - Plays speech sound effect
  - Follows speaker if they move
  - Self-cleaning (removes itself when done)

### 3. SpeechTrigger (Component)
- **File**: `SpeechTrigger.gd`
- **Purpose**: Easy-to-attach component for triggering speech
- **Features**:
  - Multiple trigger types (ready, area, interaction, custom signal)
  - Configurable conditions
  - Repeatable or one-time triggers

## Setup Instructions

### Step 1: Add SpeechManager to Project Settings

1. Open Project Settings
2. Go to AutoLoad tab
3. Add `SpeechManager.gd` as a singleton
4. Set the name as "SpeechManager"

### Step 2: Add SpeechBubble to Characters/NPCs

1. Open your character or NPC scene
2. Add the `SpeechBubble.tscn` as a child node
3. The speech bubble will default to invisible
4. It will automatically position itself above the speaker

### Step 3: Add Speech Data

You can add speech data in two ways:

#### Method 1: Edit SpeechManager.gd directly
```gdscript
# In SpeechManager.gd, add to SPEECH_DATA dictionary:
"my_speech_id": {
    "text": "Hello there!",
    "duration": 3.0,
    "character": "CharacterName"
}
```

#### Method 2: Add dynamically in code
```gdscript
# In any script:
var speech_manager = get_node("/root/SpeechManager")
speech_manager.add_speech("my_speech_id", "Hello there!", 3.0, "CharacterName")
```

## Usage Examples

### Basic Speech Triggering

```gdscript
# Trigger speech from any script
var speech_manager = get_node("/root/SpeechManager")
speech_manager.trigger_speech("greeting", self)
```

### Character-Specific Location Speech

```gdscript
# Trigger character-specific speech based on location
var character_name = "benny"  # or "layla", "clark"
var location = "hole1_tee"
speech_manager.trigger_character_speech(character_name, location, self)
```

### Using SpeechTrigger Component

1. **Add to Scene**: Add `SpeechTrigger.gd` as a child of your character/NPC/object
2. **Configure in Inspector**:
   - `speech_id`: The speech to trigger
   - `trigger_on_ready`: Trigger when scene loads
   - `trigger_on_area_entered`: Trigger when player enters area
   - `trigger_on_interaction`: Trigger on interaction input
   - `auto_trigger_delay`: Delay before triggering
   - `repeatable`: Whether it can trigger multiple times

### Example SpeechTrigger Setup

```gdscript
# In code setup
var trigger = SpeechTrigger.new()
trigger.speech_id = "greeting"
trigger.trigger_on_ready = true
trigger.auto_trigger_delay = 2.0
add_child(trigger)
```

## Speech Data Structure

Each speech entry has the following structure:

```gdscript
{
    "text": "The text to display",
    "duration": 3.0,  # How long to show the speech bubble
    "character": "CharacterName"  # Who is speaking (for organization)
}
```

## Pre-built Speech Examples

The system comes with several example speeches:

### Character-Specific
- `benny_hole1_tee`: "Let's do this!"
- `layla_hole1_tee`: "Let's break a record!"
- `clark_hole1_tee`: "Time to show them how it's done."

### Generic
- `greeting`: "Hello there!"
- `good_shot`: "Nice shot!"
- `bad_shot`: "Oops!"

### NPC
- `golfsmith_greeting`: "Welcome to the pro shop!"
- `police_warning`: "Keep it clean out there!"

## Advanced Features

### Custom Trigger Conditions

You can add custom conditions to SpeechTrigger:

```gdscript
# In SpeechTrigger.gd, extend check_trigger_condition():
func check_trigger_condition() -> bool:
    match trigger_condition:
        "player_on_tee":
            return check_player_on_tee()
        "first_time":
            return not has_triggered
        "character_specific":
            return Global.selected_character == 2  # Benny
    return true
```

### Listening to Speech Events

```gdscript
# Connect to speech manager signals
var speech_manager = get_node("/root/SpeechManager")
speech_manager.speech_started.connect(_on_speech_started)
speech_manager.speech_ended.connect(_on_speech_ended)

func _on_speech_started(speech_id: String, speaker: Node):
    print("Speech started: ", speech_id)

func _on_speech_ended(speech_id: String, speaker: Node):
    print("Speech ended: ", speech_id)
```

### Manual Speech Control

```gdscript
# Stop all active speech
speech_manager.stop_all_speech()

# Stop specific speech bubble
speech_manager.stop_speech_bubble(speech_bubble_node)

# Check if speech exists
if speech_manager.has_speech("my_speech_id"):
    speech_manager.trigger_speech("my_speech_id", self)
```

## Best Practices

1. **Naming Convention**: Use descriptive speech IDs like `character_location_event`
2. **Duration**: Keep speeches short (2-4 seconds) for good UX
3. **Positioning**: Speech bubbles automatically position above speakers
4. **Sound**: Each speech bubble plays the SpeechBoop sound automatically
5. **Cleanup**: Speech bubbles clean themselves up automatically

## Troubleshooting

### Speech not appearing
- Check that SpeechManager is added as AutoLoad
- Verify speech_id exists in SPEECH_DATA
- Ensure speaker node is valid

### Speech bubble positioning issues
- Check if speaker has proper height property
- Verify speaker position is being updated correctly

### Sound not playing
- Check that SpeechBoop.mp3 is properly imported
- Verify AudioStreamPlayer2D is set up in SpeechBubble scene

## Adding New Speeches

### Method 1: Event-Driven System (Recommended)

The most elegant way to add new speeches is through the event system:

1. **Add speech data** to `SpeechManager.gd`:
```gdscript
# In SpeechManager.gd SPEECH_DATA:
"benny_birdie": {
    "text": "Birdie! That's what I'm talking about!",
    "duration": 3.0,
    "character": "Benny"
}
```

2. **Add event trigger** to `SpeechEventManager.gd`:
```gdscript
# In SpeechEventManager.gd SPEECH_EVENTS:
"game_event_triggered": {
    "benny_birdie": {
        "condition": "event_name == 'birdie' and character_id == 2",
        "speech_id": "benny_birdie"
    }
}
```

3. **Trigger the event** from anywhere in your code:
```gdscript
# From any script:
var speech_event_manager = get_node("/root/SpeechEventManager")
speech_event_manager.trigger_game_event("birdie", Global.selected_character, player_node)
```

### Method 2: Configuration File (Most Flexible)

Create a `SpeechConfig.tres` resource file and edit it in the inspector:

1. Create a new `SpeechConfig` resource
2. Add `SpeechTriggerConfig` entries in the inspector
3. Set event_type, condition, and speech_id
4. The system automatically handles the rest

### Method 3: Dynamic Addition

Add speeches and triggers at runtime:
```gdscript
# Add speech
var speech_manager = get_node("/root/SpeechManager")
speech_manager.add_speech("benny_birdie", "Birdie! That's what I'm talking about!", 3.0, "Benny")

# Add trigger
var speech_event_manager = get_node("/root/SpeechEventManager")
speech_event_manager.add_speech_event("game_event_triggered", "benny_birdie", "benny_birdie")
```

## Benefits of This System

✅ **No code changes to course_1.gd** - Everything is modular  
✅ **Easy to add new speeches** - Just edit configuration  
✅ **Event-driven** - Clean separation of concerns  
✅ **Inspector-friendly** - Edit triggers visually  
✅ **Extensible** - Easy to add new event types  
✅ **Maintainable** - All speech logic in one place  

This system provides a solid foundation for adding story and character personality to your golf game! 