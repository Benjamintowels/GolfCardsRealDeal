# Save File System Integration Guide

## Overview
The save file system integrates seamlessly with the existing ClubHouse scene (`Main.tscn`) to provide persistent progression tracking. The system handles save file selection, character unlocks, deck unlocks, and progression-based UI updates.

## System Architecture

### Core Components
1. **SaveFileManager** (Autoload Singleton) - Central save data management
2. **LoadingScreen** - Entry point with save file selection
3. **SaveFileSelectionDialog** - UI for save slot selection
4. **CharacterSelection** - UI for new game character selection
5. **Main.gd** (ClubHouse) - Integration point for save data
6. **DeckSelectionDialog** - Progression-based deck selection

## Flow Diagram

```
LoadingScreen
    ↓
SaveFileSelectionDialog
    ↓
[Existing Save] → Load Save Data → ClubHouse (Main.tscn)
    ↓
[New Save] → CharacterSelection → Create Save → ClubHouse (Main.tscn)
```

## Detailed Integration Points

### 1. LoadingScreen.gd
**Purpose**: Entry point that shows save file selection after loading

**Key Functions**:
- `on_loading_complete()` - Shows save file selection instead of going directly to Main
- `show_save_file_selection()` - Instantiates and displays SaveFileSelectionDialog
- `_on_save_file_selected()` - Loads existing save and transitions to ClubHouse
- `_on_new_game_requested()` - Creates new save and transitions to ClubHouse

**Integration**:
```gdscript
# After loading completes, show save selection
func on_loading_complete():
    show_save_file_selection()

# Handle existing save selection
func _on_save_file_selected(slot_id: int):
    var save_file_manager = get_node("/root/SaveFileManager")
    save_file_manager.load_save_file(slot_id)
    FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Main.tscn"), 0.5)

# Handle new game creation
func _on_new_game_requested(slot_id: int, character_id: int):
    var save_file_manager = get_node("/root/SaveFileManager")
    save_file_manager.create_new_save_file(slot_id, character_id)
    FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Main.tscn"), 0.5)
```

### 2. SaveFileSelectionDialog.gd
**Purpose**: UI for selecting save slots and creating new saves

**Key Functions**:
- `update_slot_displays()` - Shows save info for each slot
- `handle_slot_pressed()` - Handles slot selection logic
- `_on_character_selected()` - Creates new save with selected character

**Integration**:
```gdscript
# Show save info including ClubHouse level
func update_slot_display(slot_id: int, button: Button):
    var save_file_manager = get_node("/root/SaveFileManager")
    if save_info["exists"]:
        button.text = "Slot " + str(slot_id) + "\n" + \
                     save_info["character_name"] + "\n" + \
                     "ClubHouse Lv." + str(save_info["clubhouse_level"]) + "\n" + \
                     "Last: " + last_played
    else:
        button.text = "Slot " + str(slot_id) + "\n[Empty]\nCreate New Save File"
```

### 3. CharacterSelection.gd
**Purpose**: UI for selecting character when creating new save

**Key Functions**:
- `setup_character_info()` - Displays character stats
- `_on_character_selected()` - Emits character selection signal

**Integration**:
```gdscript
# Character selection emits signal to parent dialog
func _on_layla_selected():
    emit_signal("character_selected", 1)

func _on_benny_selected():
    emit_signal("character_selected", 2)

func _on_clark_selected():
    emit_signal("character_selected", 3)
```

### 4. Main.gd (ClubHouse Integration)
**Purpose**: Main ClubHouse scene that integrates with save data

**Key Functions**:
- `update_ui_from_save_data()` - Updates UI based on loaded save
- `_update_character_selection_ui()` - Shows/hides character buttons
- `_update_progression_ui()` - Updates progression-based UI elements

**Integration**:
```gdscript
func _ready():
    # Check save data and update UI accordingly
    update_ui_from_save_data()

func update_ui_from_save_data():
    var save_file_manager = get_node("/root/SaveFileManager")
    if not save_file_manager or save_file_manager.current_save_slot == 0:
        return
    
    var save_data = save_file_manager.current_save_data
    
    # Update character selection
    selected_character = save_data.get("character_id", 1)
    _update_character_selection_ui()
    
    # Update progression-based UI elements
    _update_progression_ui()

func _update_character_selection_ui():
    # Show/hide character buttons based on unlocks
    character1_button.visible = save_file_manager.is_character_unlocked(1)
    character2_button.visible = save_file_manager.is_character_unlocked(2)
    character3_button.visible = save_file_manager.is_character_unlocked(3)
    
    # Set correct character as selected
    match selected_character:
        1: character1_button.button_pressed = true
        2: character2_button.button_pressed = true
        3: character3_button.button_pressed = true
    
    # Update Benny selection flag
    benny_selected = (selected_character == 2)

func _update_progression_ui():
    # Show/hide buttons based on progression
    if save_file_manager.get_story_flag("completed_front_9"):
        start_back_9_button.visible = true
    
    if save_file_manager.get_story_flag("defeated_first_boss"):
        boss_room_button.visible = true
    
    # Update deck selection based on unlocks
    if deck_selection_dialog:
        deck_selection_dialog.update_available_decks()
```

### 5. DeckSelectionDialog.gd
**Purpose**: Progression-based deck selection

**Key Functions**:
- `update_available_decks()` - Shows/hides deck buttons based on unlocks
- `show_dialog()` - Displays deck selection dialog

**Integration**:
```gdscript
func update_available_decks():
    var save_file_manager = get_node("/root/SaveFileManager")
    if not save_file_manager:
        return
    
    # Show/hide deck buttons based on unlocks
    starter_deck_button.visible = save_file_manager.is_deck_unlocked("starter")
    fighter_deck_button.visible = save_file_manager.is_deck_unlocked("fighter")
    
    # Ensure at least starter deck is available
    if not starter_deck_button.visible and not fighter_deck_button.visible:
        starter_deck_button.visible = true
```

## Save Data Structure

### Default Values
```gdscript
# Character Progression
"unlocked_characters": 2,  # Benny only (default)
"character_levels": { 1: 1, 2: 1, 3: 1 }
"character_exp": { 1: 0, 2: 0, 3: 0 }

# Content Unlocks
"unlocked_decks": ["starter"]  # Only starter deck
"unlocked_equipment": []
"unlocked_maps": ["golf_island"]

# Story Progression
"first_time_playing": true
"completed_tutorial": false
"completed_front_9": false
"completed_back_9": false

# ClubHouse Progression
"clubhouse_level": 1
"clubhouse_exp": 0
```

### Character Unlock Logic
```gdscript
# unlocked_characters values:
0 = No characters unlocked
1 = Layla only
2 = Benny only (default)
3 = Layla + Benny
4 = All characters (Layla + Benny + Clark)
```

## Auto-Save Integration

### Character Selection Auto-Save
```gdscript
func _on_character1_selected():
    selected_character = 1
    benny_selected = false
    
    # Auto-save character selection
    var save_file_manager = get_node("/root/SaveFileManager")
    if save_file_manager and save_file_manager.current_save_slot > 0:
        save_file_manager.current_save_data["character_id"] = selected_character
        save_file_manager.save_current_game()
```

## Scene File Requirements

### Required .tscn Files
1. **SaveFileSelectionDialog.tscn** - Main save selection UI
2. **CharacterSelection.tscn** - Character selection for new games

### Node Structure
```
SaveFileSelectionDialog (Control)
├── Background (ColorRect)
├── VBoxContainer
│   ├── Title (Label)
│   ├── Slot1Button (Button)
│   ├── Slot2Button (Button)
│   ├── Slot3Button (Button)
│   └── BackButton (Button)
└── CharacterSelection (instance)

CharacterSelection (Control)
├── Background (ColorRect)
├── VBoxContainer
│   ├── Title (Label)
│   ├── HBoxContainer
│   │   ├── LaylaButton (Button)
│   │   ├── BennyButton (Button)
│   │   └── ClarkButton (Button)
│   └── BackButton (Button)
```

## Testing Checklist

### New Game Flow
- [ ] LoadingScreen completes and shows save selection
- [ ] Empty slots show "Create New Save File"
- [ ] Clicking empty slot shows character selection
- [ ] Character selection creates new save
- [ ] ClubHouse loads with only Benny unlocked
- [ ] Only "Starter Deck" available in deck selection

### Load Game Flow
- [ ] Existing saves show character name and ClubHouse level
- [ ] Clicking existing save loads save data
- [ ] ClubHouse shows correct unlocked content
- [ ] Character selection reflects save data
- [ ] Progression-based UI elements show/hide correctly

### Progression Integration
- [ ] Character unlocks update UI visibility
- [ ] Deck unlocks update deck selection
- [ ] Story flags control game mode buttons
- [ ] Auto-save works on character selection
- [ ] Save data persists between sessions

## Future Integration Points

### Equipment System
- Add equipment selection after deck selection
- Integrate with `equipment_table_unlocked` flag
- Show/hide equipment based on unlocks

### Map System
- Integrate map selection with `unlocked_maps`
- Show/hide map options based on progression
- Handle checkpoint unlocks

### NPC Quest System
- Integrate with `npc_quests` data
- Trigger speech based on quest progress
- Show/hide NPCs based on story flags

### ClubHouse Progression
- Integrate with `clubhouse_level` system
- Show decor upgrades based on level
- Handle perk selection system

## Troubleshooting

### Common Issues
1. **"Nonexistent function" errors** - Check if functions exist in target scripts
2. **Null reference errors** - Verify node paths in @onready variables
3. **Save data not loading** - Check if SaveFileManager is properly autoloaded
4. **UI not updating** - Ensure `update_ui_from_save_data()` is called in `_ready()`

### Debug Commands
```gdscript
# Check current save data
print(SaveFileManager.current_save_data)

# Check character unlocks
print(SaveFileManager.is_character_unlocked(1))
print(SaveFileManager.is_character_unlocked(2))
print(SaveFileManager.is_character_unlocked(3))

# Check deck unlocks
print(SaveFileManager.is_deck_unlocked("starter"))
print(SaveFileManager.is_deck_unlocked("fighter"))
```

This documentation provides a complete reference for how the save file system is wired together and how to extend it for future features. 