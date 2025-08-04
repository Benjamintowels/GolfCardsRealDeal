# Progression System Documentation

## Overview

The Progression System is a comprehensive save file and progression tracking system that manages all aspects of player advancement in GolfCards. It's designed to be modular, efficient, and easily extensible.

## System Architecture

### 1. SaveFileManager (Global Singleton)
- **Location**: `SaveFileManager.gd`
- **Purpose**: Central manager for all progression tracking
- **Autoload**: Added to project.godot as "SaveFileManager"

### 2. SaveFileSelectionDialog
- **Location**: `SaveFileSelectionDialog.gd` + `.tscn`
- **Purpose**: UI for selecting/creating save files
- **Features**: 3 save slots, character selection for new games

### 3. CharacterSelection
- **Location**: `CharacterSelection.gd`
- **Purpose**: Character selection component for new saves
- **Features**: Shows character stats and handles selection

## Progression Modules

### 1. CHARACTER PROGRESSION
Tracks individual character advancement and unlocks.

#### Default State:
- **Unlocked Characters**: 2 (Layla + Benny)
- **Character Levels**: All start at Level 1
- **Experience**: All start at 0

#### API Functions:
```gdscript
# Unlock a character
SaveFileManager.unlock_character(character_id)

# Add experience to character
SaveFileManager.add_character_exp(character_id, exp_amount)

# Get character level
SaveFileManager.get_character_level(character_id)

# Check if character is unlocked
SaveFileManager.is_character_unlocked(character_id)
```

#### Integration Example:
```gdscript
# In course_1.gd after completing a hole
var save_file_manager = get_node("/root/SaveFileManager")
if save_file_manager:
    # Add experience to current character
    save_file_manager.add_character_exp(Global.selected_character, 5)
    
    # Check for level up (handled automatically)
    var level = save_file_manager.get_character_level(Global.selected_character)
    print("Character level: ", level)
```

### 2. CONTENT UNLOCK SYSTEM
Manages unlocked decks, equipment, maps, and checkpoints.

#### Default State:
- **Decks**: ["starter"]
- **Equipment**: []
- **Maps**: ["golf_island"]
- **Checkpoints**: Only front_9_unlocked on golf_island

#### API Functions:
```gdscript
# Unlock content
SaveFileManager.unlock_deck(deck_name)
SaveFileManager.unlock_equipment(equipment_name)
SaveFileManager.unlock_map(map_name)
SaveFileManager.unlock_map_checkpoint(map_name, checkpoint)

# Check unlocks
SaveFileManager.is_deck_unlocked(deck_name)
SaveFileManager.is_equipment_unlocked(equipment_name)
SaveFileManager.is_map_unlocked(map_name)
```

#### Integration Example:
```gdscript
# In Main.gd to update UI based on unlocks
func _update_progression_ui():
    var save_file_manager = get_node("/root/SaveFileManager")
    
    # Show/hide buttons based on unlocks
    if save_file_manager.is_deck_unlocked("fighter"):
        fighter_deck_button.visible = true
    
    if save_file_manager.is_map_unlocked("desert_course"):
        desert_course_button.visible = true
```

### 3. GAMEPLAY TRACKING SYSTEM
Tracks scores, grades, and gameplay statistics.

#### Tracked Data:
- Golf scores (front_9, back_9, full_18)
- Puzzle scores (bounce_room, damage_round, etc.)
- Round grades (F to SS+)
- General stats (holes played, damage dealt/taken, etc.)

#### API Functions:
```gdscript
# Add scores
SaveFileManager.add_golf_score(round_type, score)
SaveFileManager.add_puzzle_score(puzzle_type, score)
SaveFileManager.set_round_grade(round_type, grade)
```

#### Integration Example:
```gdscript
# In course_1.gd after completing a round
func complete_round():
    var save_file_manager = get_node("/root/SaveFileManager")
    if save_file_manager:
        # Add golf score
        save_file_manager.add_golf_score("front_9", total_score)
        
        # Calculate and set grade
        var grade = calculate_round_grade()
        save_file_manager.set_round_grade("front_9", grade)
        
        # Add puzzle score if applicable
        if game_state_manager.get_current_puzzle_type() == "bounce_room":
            save_file_manager.add_puzzle_score("bounce_room", bounce_count)
```

### 4. STORY/QUEST PROGRESSION SYSTEM
Manages story flags and NPC questlines.

#### Default State:
- **Story Flags**: Most start as false
- **NPC Quests**: Modular system starting with golfsmith

#### API Functions:
```gdscript
# Set story flags
SaveFileManager.set_story_flag(flag_name, value)

# NPC quest progress
SaveFileManager.set_npc_quest_progress(npc_name, progress)

# Get values
SaveFileManager.get_story_flag(flag_name)
SaveFileManager.get_npc_quest_progress(npc_name)
```

#### Integration Example:
```gdscript
# In shop interactions
func _on_shop_entered():
    var save_file_manager = get_node("/root/SaveFileManager")
    if save_file_manager:
        # Mark golfsmith as met
        save_file_manager.set_story_flag("met_golfsmith", true)
        
        # Progress golfsmith quest
        var current_progress = save_file_manager.get_npc_quest_progress("golfsmith")
        save_file_manager.set_npc_quest_progress("golfsmith", current_progress + 25)
```

### 5. CLUBHOUSE PROGRESSION SYSTEM
Manages ClubHouse level, decor, and equipment storage.

#### Default State:
- **Level**: 1
- **Experience**: 0
- **Equipment Table**: Locked
- **Equipment Storage**: Empty

#### API Functions:
```gdscript
# Add experience (always progresses)
SaveFileManager.add_clubhouse_exp(exp_amount)

# Unlock features
SaveFileManager.unlock_clubhouse_equipment_table()
SaveFileManager.add_clubhouse_equipment(equipment_name)

# Get values
SaveFileManager.get_clubhouse_level()
SaveFileManager.is_equipment_table_unlocked()
```

#### Integration Example:
```gdscript
# In course_1.gd after any gameplay
func add_progression_exp():
    var save_file_manager = get_node("/root/SaveFileManager")
    if save_file_manager:
        # ClubHouse always gets experience
        save_file_manager.add_clubhouse_exp(10)
        
        # Unlock equipment table at level 3
        if save_file_manager.get_clubhouse_level() >= 3:
            save_file_manager.unlock_clubhouse_equipment_table()
```

## Integration with Existing Systems

### 1. LoadingScreen Integration
The LoadingScreen now shows save file selection after loading:

```gdscript
# In LoadingScreen.gd
func _on_loading_complete():
    show_save_file_selection()

func show_save_file_selection():
    var save_dialog_scene = preload("res://SaveFileSelectionDialog.tscn")
    var save_dialog = save_dialog_scene.instantiate()
    add_child(save_dialog)
    
    save_dialog.save_file_selected.connect(_on_save_file_selected)
    save_dialog.new_game_requested.connect(_on_new_game_requested)
```

### 2. Main Menu Integration
Main.gd now updates UI based on progression:

```gdscript
# In Main.gd
func update_ui_from_save_data():
    var save_file_manager = get_node("/root/SaveFileManager")
    if save_file_manager:
        # Update character unlocks
        character1_button.visible = save_file_manager.is_character_unlocked(1)
        character2_button.visible = save_file_manager.is_character_unlocked(2)
        character3_button.visible = save_file_manager.is_character_unlocked(3)
        
        # Update progression-based buttons
        if save_file_manager.get_story_flag("completed_front_9"):
            start_back_9_button.visible = true
```

### 3. Course Integration
course_1.gd tracks gameplay progression:

```gdscript
# In course_1.gd
func complete_hole():
    var save_file_manager = get_node("/root/SaveFileManager")
    if save_file_manager:
        # Always add ClubHouse experience
        save_file_manager.add_clubhouse_exp(10)
        
        # Add character experience
        save_file_manager.add_character_exp(Global.selected_character, 5)
        
        # Track story progression
        if game_state_manager.get_current_hole_index() == 8:
            save_file_manager.set_story_flag("completed_front_9", true)
        
        # Save game
        save_file_manager.save_current_game()
```

## Event System

The progression system automatically triggers events based on flags:

### Story Events
- `first_time_playing`: Triggers intro speech
- `met_golfsmith`: Triggers golfsmith introduction
- `completed_front_9`: Triggers front 9 completion speech
- `defeated_first_boss`: Triggers boss defeat speech
- `defeated_final_boss`: Triggers victory sequence

### Progression Events
- Character level ups
- Content unlocks
- ClubHouse level ups
- NPC quest milestones

## Save File Structure

Save files contain all progression data in a structured format:

```json
{
  "version": "1.0",
  "character_progression": {
    "unlocked_characters": 2,
    "character_levels": {"1": 1, "2": 1, "3": 1},
    "character_exp": {"1": 0, "2": 0, "3": 0}
  },
  "content_unlocks": {
    "unlocked_decks": ["starter"],
    "unlocked_equipment": [],
    "unlocked_maps": ["golf_island"],
    "map_checkpoints": {...}
  },
  "gameplay_stats": {
    "golf_scores": {...},
    "puzzle_scores": {...},
    "round_grades": {...}
  },
  "story_progression": {
    "first_time_playing": true,
    "npc_quests": {...}
  },
  "clubhouse_progression": {
    "clubhouse_level": 1,
    "clubhouse_exp": 0,
    "equipment_table_unlocked": false
  }
}
```

## Best Practices

### 1. Always Check for SaveFileManager
```gdscript
var save_file_manager = get_node("/root/SaveFileManager")
if save_file_manager:
    # Use progression functions
```

### 2. Save After Important Changes
```gdscript
# After any progression update
save_file_manager.save_current_game()
```

### 3. Use Signals for UI Updates
```gdscript
# Connect to progression updates
SaveFileManager.progression_updated.connect(_on_progression_updated)

func _on_progression_updated(category: String, key: String, value):
    # Update UI based on progression change
    match category:
        "character": update_character_ui()
        "content": update_content_ui()
        "story": update_story_ui()
```

### 4. Modular NPC Quest System
```gdscript
# Easy to add new NPCs
SaveFileManager.set_npc_quest_progress("new_npc", 50)
```

This system provides a solid foundation for tracking all aspects of player progression while maintaining modularity and extensibility for future features. 