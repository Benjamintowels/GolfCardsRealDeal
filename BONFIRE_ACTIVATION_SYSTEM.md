# Bonfire Activation System

## Overview

The Bonfire Activation System allows bonfires to be activated through two methods:
1. **Fire Tile Activation**: When any tile adjacent to the bonfire (or the bonfire's own tile) catches fire
2. **Lighter Equipment Activation**: When a player with a Lighter equipped moves within range of an inactive bonfire

## Activation States

### Inactive State
- Shows only the `BonfireBaseSprite` (the base structure)
- No flame animation
- No sound effects
- Can be activated by fire or lighter

### Active State
- Shows animated flame sprites with flickering effects
- Plays activation sound (`FlameOn.mp3`)
- Flame has scale and opacity variations for realistic effect
- Cannot be activated again (already lit)

## Activation Methods

### 1. Fire Tile Activation

Bonfires automatically activate when:
- The tile the bonfire is on catches fire
- Any adjacent tile (8-directional) catches fire

**Implementation Details:**
- Checks for fire tiles in the `fire_tiles` group
- Uses `is_fire_active()` method to verify fire is still burning
- Monitors both the bonfire's own tile and all 8 adjacent tiles
- Activates immediately when fire is detected

**Code Location:**
```gdscript
func _check_for_nearby_fire():
    # Checks bonfire's tile and adjacent tiles for fire
    # Calls set_bonfire_active(true) when fire is found
```

### 2. Lighter Equipment Activation

When a player with Lighter equipment moves within range:
- Triggers a dialog asking "Light Bonfire?"
- Player can choose "Yes" or "No"
- "Yes" activates the bonfire
- "No" closes the dialog without activation

**Implementation Details:**
- Detects when player enters bonfire's collision area
- Checks if player has Lighter equipment via `EquipmentManager.has_lighter()`
- Shows custom dialog with Yes/No buttons
- Only shows dialog if bonfire is inactive

**Code Location:**
```gdscript
func handle_player_entered(player: Node2D):
    # Checks for Lighter equipment and shows dialog
```

## Equipment Integration

### Lighter Equipment
- **Equipment Name**: "Lighter"
- **Resource**: `res://Equipment/Lighter.tres`
- **Effect**: Allows manual bonfire activation
- **Detection**: `EquipmentManager.has_lighter()`

### Equipment Manager Methods
```gdscript
func has_lighter() -> bool:
    """Check if the player has Lighter equipment equipped"""
    for equipment in equipped_equipment:
        if equipment.name == "Lighter":
            return true
    return false
```

## Dialog System

### Lighter Dialog Features
- **Title**: "Light Bonfire?"
- **Message**: "You have a Lighter equipped.\nWould you like to light this bonfire?"
- **Buttons**: "Yes" and "No"
- **Styling**: Orange title, white text, dark background
- **Z-Index**: 1000 (appears above other UI)

### Dialog Implementation
```gdscript
func show_lighter_dialog():
    # Creates custom dialog with Yes/No buttons
    # Handles player choice and activates bonfire accordingly
```

## Visual Effects

### Flame Animation
- **Frames**: 3 flame textures with cycling animation
- **Speed**: 0.15 seconds between frame changes
- **Scale Variation**: ±10% scale oscillation
- **Opacity Variation**: ±20% opacity oscillation
- **Color**: Orange-red-yellow tint for realistic fire appearance

### Activation Effects
- **Sound**: Plays `FlameOn.mp3` when activated
- **Visual**: Flame sprite becomes visible with full animation
- **State**: Transitions from inactive to active state

## Technical Implementation

### Key Properties
```gdscript
var is_active: bool = false  # Current activation state
var cell_size: int = 48      # Tile size for grid calculations
var map_manager: Node = null # Reference to map manager
var lighter_dialog: Control = null  # Dialog reference
var lighter_dialog_active: bool = false  # Dialog state
```

### Grid Position System
```gdscript
func get_grid_position() -> Vector2i:
    """Get the grid position of the bonfire"""
    return Vector2i(floor(global_position.x / cell_size), floor(global_position.y / cell_size))
```

### Fire Detection
```gdscript
func _is_tile_on_fire(tile_pos: Vector2i) -> bool:
    """Check if a tile is currently on fire"""
    # Searches fire_tiles group for active fire at position
```

## Testing

### Test Scene
- **File**: `test_bonfire_activation.tscn`
- **Script**: `test_bonfire_activation.gd`
- **Purpose**: Verify all activation methods work correctly

### Test Controls
- **SPACE**: Test fire spreading near bonfire
- **L**: Give player Lighter equipment
- **R**: Remove Lighter equipment
- **P**: Move player near bonfire
- **F**: Create fire tile on bonfire's tile

### Test Scenarios
1. **Fire Activation**: Create fire tiles adjacent to bonfire
2. **Lighter Activation**: Give player Lighter and move near bonfire
3. **Dialog Testing**: Test Yes/No responses
4. **State Persistence**: Verify bonfire stays active once lit

## Integration Points

### Required Systems
- **MapManager**: For tile type checking
- **EquipmentManager**: For Lighter equipment detection
- **Fire Tile System**: For fire detection
- **UI Layer**: For dialog display

### Groups
- `visual_objects`: For Y-sorting
- `ysort_objects`: For Y-sorting
- `interactables`: For interaction detection

### Signals
- No custom signals (uses existing collision detection)

## Future Enhancements

### Potential Features
- **Deactivation**: Bonfire could be extinguished by water/ice
- **Rest Effects**: Active bonfires could provide healing/restoration
- **Multiple Flames**: Different flame types or intensities
- **Sound Variations**: Different sounds for activation vs. ambient
- **Particle Effects**: Additional fire particles or ember effects

### Code Extensions
- Add `set_bonfire_active(false)` for deactivation
- Implement rest/healing mechanics for active bonfires
- Add visual indicators for activation state
- Create different bonfire types with unique effects 