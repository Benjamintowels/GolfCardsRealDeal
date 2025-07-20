# Watch Individual Mode System

## Overview

The Watch equipment has been updated to provide a different gameplay experience. Instead of enabling "together mode" (which is now the default), the Watch now enables "individual mode" where NPCs take their turns one at a time for better player control.

## Changes Made

### 1. Default Behavior Change
- **WorldTurnManager**: Changed `together_mode_enabled` default from `false` to `true`
- **Result**: NPCs now execute their turns simultaneously in a priority cascade by default
- **Benefit**: Faster, more dynamic world turns as the default experience

### 2. Watch Equipment Update
- **Equipment Type**: Changed from `"together_mode"` to `"individual_mode"`
- **Description**: Updated to reflect new functionality
- **Effect**: When equipped, makes NPCs take individual turns instead of together mode
- **Benefit**: Provides player control over turn timing when needed

### 3. EquipmentManager Enhancements
- **New Effect**: Added `"individual_mode"` buff type handling
- **Functions**: 
  - `_apply_individual_mode_effect()` - Enables individual mode
  - `_remove_individual_mode_effect()` - Disables individual mode
  - `has_watch()` - Helper function to check if Watch is equipped

### 4. WorldTurnManager Updates
- **Message Display**: Shows "World Turn - Individual" when individual mode is active
- **Default State**: Together mode is now the default behavior

## Gameplay Impact

### Default Experience (No Watch)
- NPCs execute turns simultaneously in priority groups
- Faster world turns with cascade effect
- More chaotic, dynamic gameplay
- Priority order: Squirrels → Zombies → Gang Members → Police

### With Watch Equipped
- NPCs take turns one at a time
- Slower but more controlled world turns
- Better for strategic planning
- Camera focuses on each NPC individually

## Technical Implementation

### Equipment Data
```gdscript
# Watch.tres
buff_type = "individual_mode"
description = "Makes NPCs take individual turns for better control."
```

### EquipmentManager Functions
```gdscript
func _apply_individual_mode_effect(equipment: EquipmentData):
    # Disables together mode (enables individual mode)
    world_turn_manager.set_together_mode(false)

func _remove_individual_mode_effect(equipment: EquipmentData):
    # Re-enables together mode (disables individual mode)
    world_turn_manager.set_together_mode(true)
```

### WorldTurnManager Default
```gdscript
var together_mode_enabled: bool = true  # Default to together mode
```

## Testing

### Test Scene
Use `test_watch_individual_mode.tscn` to test the functionality:

1. **Keyboard Controls**:
   - `T` - Toggle together mode manually
   - `W` - Test Watch equipment effect
   - `D` - Debug current state

2. **Expected Behavior**:
   - Default: Together mode enabled
   - With Watch: Individual mode enabled
   - Without Watch: Together mode enabled

### Integration Testing
1. Start a game without Watch equipped
2. Verify NPCs move simultaneously (together mode)
3. Equip Watch from shop
4. Verify NPCs take individual turns
5. Unequip Watch
6. Verify return to together mode

## Backward Compatibility

- All existing save files will work with the new system
- The Watch equipment will automatically apply the new effect
- No changes needed to existing NPC scripts
- WorldTurnManager maintains all existing functionality

## Future Considerations

- Consider adding visual indicators for current mode
- Could add more equipment that affects turn behavior
- Might want to add settings to remember player preference
- Could add different individual mode variants (e.g., "slow individual", "fast individual") 