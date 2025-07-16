# Dodge Card System

## Overview

The Dodge card system provides defensive capabilities to the player by allowing them to completely avoid the next instance of damage. When the Dodge card is played, the player gains dodge status, and when damage would be taken, the player performs a dodge animation with a light yellow hue effect instead, avoiding all damage.

## Components

### 1. DodgeCard
- **Location**: `res://Cards/DodgeCard.tres`
- **Effect Type**: "Dodge"
- **Effect Strength**: 1
- **Card Image**: `res://Cards/DodgeCard.png`
- **Purpose**: Activates the dodge system when played

### 2. Hue Effect System
- **Effect**: Light yellow hue applied to character sprite
- **Color**: `Color(1.0, 1.0, 0.8, 1.0)` - Light yellow tint
- **Purpose**: Visual indicator of dodge status and animation
- **Duration**: Applied during dodge animation and maintained until dodge mode ends

### 3. Dodge Sound System
- **Sound Node**: `res://Characters/Player1.tscn` - "Dodge" AudioStreamPlayer2D
- **Sound File**: `res://Sounds/WhooshCut.mp3` (temporary placeholder)
- **Purpose**: Plays dodge sound effect when dodge activates

### 4. Course Integration
The course script (`course_1.gd`) manages the dodge system:
- **Variables**: `dodge_mode_active`, `dodge_mode_tween`
- **Methods**: `activate_dodge_mode()`, `deactivate_dodge_mode()`, `trigger_dodge_animation()`, `is_dodge_mode_active()`
- **Hue Effects**: `animate_dodge_with_hue_effect()`, `restore_sprite_after_dodge()`

## How It Works

### Dodge Activation
1. **Card Played**: Player uses DodgeCard from hand or bag
2. **Sound Effect**: Plays `res://Sounds/WhooshCut.mp3`
3. **Mode Activation**: `course.activate_dodge_mode()` is called
4. **Card Discard**: Dodge card is discarded from hand

### Damage Avoidance
1. **Damage Taken**: Player would take damage from any source
2. **Dodge Check**: `course.take_damage()` checks if dodge is active
3. **Dodge Animation**: Instead of taking damage:
   - Plays dodge sound effect
   - Applies light yellow hue effect to character sprite
   - Animates player moving slightly out of the way
   - Returns to original position
   - Maintains hue effect until dodge mode ends
4. **Dodge Clear**: Dodge mode is automatically cleared at end of turn

### Dodge Clearing
1. **End of Turn**: Dodge is automatically cleared when player starts their next turn
2. **Visual Reset**: 
   - Clears light yellow hue effect from character sprite
   - Restores normal sprite appearance
3. **State Reset**: `dodge_mode_active = false`

## Implementation Details

### CardEffectHandler.gd
```gdscript
# Key methods:
func handle_dodge_effect(card: CardData)  # Handle Dodge card effect
func play_dodge_sound()  # Play dodge sound effect
```

### course_1.gd Dodge Methods
```gdscript
func activate_dodge_mode()  # Activate dodge system
func trigger_dodge_animation()  # Trigger dodge animation when damage avoided
func animate_dodge_with_hue_effect()  # Animate dodge with movement and hue effect
func restore_sprite_after_dodge()  # Restore sprite after dodge animation
func deactivate_dodge_mode()  # Deactivate dodge and clear hue effect
func is_dodge_mode_active()  # Check if dodge is active
```

### Damage Handling
```gdscript
func take_damage(amount: int) -> void:
    # Check if dodge mode is active - dodge the damage
    if dodge_mode_active:
        print("Dodge mode active - dodging damage!")
        trigger_dodge_animation()
        return
    # ... rest of damage handling
```

## Visual Elements

### Hue Effect System
- **Normal State**: Character sprite with no tint
- **Dodge Active**: Character sprite with light yellow hue effect
- **Dodge Animation**: Character moves with hue effect applied
- **Recovery**: Hue effect maintained until dodge mode ends

### Dodge Animation
- **Movement**: Player moves 20 pixels to the right over 0.3 seconds
- **Return**: Player moves back to original position over 0.3 seconds
- **Hue Effect**: Light yellow tint applied during movement and maintained
- **Total Duration**: 0.8 seconds including hue effect application
- **Smooth Animation**: Uses Tween with SINE transition and EASE_OUT/EASE_IN easing

## Integration Details

### 1. Rewards System
**File**: `RewardSelectionDialog.gd`
**Location**: Line 59 in `base_cards` array

```gdscript
preload("res://Cards/DodgeCard.tres"),
```

The DodgeCard is included in the rewards system and will appear as a random reward option after completing holes.

### 2. Shop System
**File**: `Shop/ShopInterior.gd`
**Location**: Line 145 in `available_cards` array

```gdscript
preload("res://Cards/DodgeCard.tres"),
```

The DodgeCard has been added to the shop's available cards and will randomly appear in shop inventories.

### 3. Starter Deck
**File**: `current_deck_manager.gd`
**Location**: Line 26 in `starter_deck` array

```gdscript
preload("res://Cards/DodgeCard.tres"),      # DodgeCard (for testing)
```

The DodgeCard has been added to the starter deck for immediate testing.

## Testing

### Test Scene
- **File**: `test_dodge_system.tscn`
- **Script**: `test_dodge_system.gd`
- **Usage**: Test dodge activation, damage avoidance, and clearing

### Manual Testing
1. Load the test scene
2. Check console output for integration status
3. Verify all systems show "✅ SUCCESS" messages

### In-Game Testing
1. Start a round with Benny character
2. Draw a DodgeCard
3. Use the DodgeCard to activate dodge
4. Take damage from enemies or hazards
5. Observe dodge animation and damage avoidance
6. Verify dodge clears at end of turn

## Configuration

### Dodge Animation
- **Movement Distance**: 20 pixels
- **Movement Duration**: 0.3 seconds each way
- **Total Animation Time**: 0.8 seconds
- **Location**: `course_1.gd` `animate_dodge_movement()`

### Hue Effect Configuration
The system applies hue effects by:
1. Getting the character sprite using `player_node.get_character_sprite()`
2. Applying light yellow tint: `Color(1.0, 1.0, 0.8, 1.0)`
3. Maintaining the effect until dodge mode is deactivated
4. Clearing the effect by restoring `Color.WHITE`

### Sound Configuration
- **Current Sound**: `res://Sounds/WhooshCut.mp3` (placeholder)
- **Location**: `res://Characters/Player1.tscn` - "Dodge" node
- **Future**: Should be replaced with dedicated dodge sound

## Status Effect Priority

The Dodge system integrates with other status effects:

1. **Vampire Mode**: Takes highest priority - heals instead of taking damage
2. **Dodge Mode**: Takes second priority - dodges damage completely
3. **Block Mode**: Takes lowest priority - absorbs damage to block points

This allows multiple defensive effects to coexist, with clear priority order.

## Future Enhancements

### Multi-Character Support
- Add dodge sprites for Layla and Clark characters
- Modify sprite detection to work with all character types
- Create character-specific dodge animations

### Dodge Variations
- Add different dodge types (side dodge, back dodge, etc.)
- Implement dodge direction based on damage source
- Add dodge counter system for multiple dodges

### Visual Effects
- Add dodge activation/deactivation animations
- Implement dodge damage visual feedback
- Add particle effects for dodge movement
- Add screen shake or other impact effects

### Sound Improvements
- Replace placeholder sound with dedicated dodge sound
- Add different sounds for different dodge types
- Implement spatial audio for dodge effects

## Recent Changes

### Hue Effect Implementation (Latest)
**Change**: Replaced sprite switching with hue effect system for cleaner implementation
**Benefits**:
- No sprite overlap issues during launch phase
- Simpler visual system using color tinting
- Works with all character sprites (not just Benny)
- Easier to maintain and extend

**Implementation**:
- `animate_dodge_with_hue_effect()` - Applies light yellow hue during dodge animation
- `restore_sprite_after_dodge()` - Maintains hue effect after animation
- `deactivate_dodge_mode()` - Clears hue effect when dodge ends
- Removed all sprite switching functions for dodge sprites

**Files Modified**:
- `course_1.gd` - Replaced sprite switching with hue effect system
- `DODGE_SYSTEM_README.md` - Updated documentation for new system

## Recent Fixes

### Issue 1: Dodge Sprite During Launch Phase
**Problem**: Dodge sprite was appearing on top of launch sprites during aiming/launch phase
**Solution**: Modified `BennyArmHeightController.gd` to check for dodge mode before switching sprites
**Files Modified**:
- `Characters/BennyArmHeightController.gd` - Added dodge mode check in `set_set_height_phase()`

### Issue 2: Sprite Not Facing Mouse
**Problem**: Dodge sprites were not flipping to face the mouse direction like other sprites
**Solution**: Added `update_dodge_sprite_flip()` function and integrated it with mouse facing system
**Files Modified**:
- `course_1.gd` - Added `update_dodge_sprite_flip()` function
- `course_1.gd` - Integrated dodge sprite flip updates in `_update_player_mouse_facing_state()`

### Issue 3: Push Sound Instead of Dodge Sound
**Problem**: When dodging damage, the Push sound was playing instead of the Dodge sound
**Solution**: Modified damage handling to check for dodge mode and play appropriate sound
**Files Modified**:
- `Characters/Player.gd` - Modified `take_damage()` to check for dodge mode
- `Characters/Player.gd` - Modified `_play_collision_sound()` to play dodge sound when dodging

## Troubleshooting

### Common Issues

1. **DodgeCard not appearing in rewards**:
   - Check `RewardSelectionDialog.gd` line 59
   - Verify DodgeCard.tres file exists

2. **DodgeCard not appearing in shop**:
   - Check `Shop/ShopInterior.gd` line 145
   - Verify shop scene is properly loaded

3. **DodgeCard not in starter deck**:
   - Check `current_deck_manager.gd` line 26
   - Verify CurrentDeckManager is properly initialized

4. **Dodge mechanics not working**:
   - Check `CardEffectHandler.gd` for dodge effect handling
   - Verify `course_1.gd` has dodge system methods
   - Ensure dodge mode variables are properly initialized

5. **Sprites not switching**:
   - Verify BennyChar.tscn has BennyDodge and BennyDodgeReady sprites
   - Check sprite visibility and positioning
   - Ensure Global.selected_character == 2 (Benny)

6. **Sound not playing**:
   - Check Player1.tscn has "Dodge" AudioStreamPlayer2D
   - Verify sound file path is correct

7. **Dodge sprite appears during launch**:
   - Check `BennyArmHeightController.gd` dodge mode check
   - Verify `is_dodge_mode_active()` function is working

8. **Dodge sprites not facing mouse**:
   - Check `update_dodge_sprite_flip()` function
   - Verify mouse facing system is calling the function

9. **Wrong sound plays when dodging**:
   - Check `Player.gd` dodge mode checks in `take_damage()` and `_play_collision_sound()`
   - Verify dodge sound is properly configured in Player1.tscn
   - Check audio settings and volume

### Debug Commands

Add these debug prints to verify integration:

```gdscript
# In RewardSelectionDialog.gd
print("Available cards:", base_cards.map(func(card): return card.name))

# In ShopInterior.gd
print("Shop cards:", available_cards.map(func(card): return card.name))

# In current_deck_manager.gd
print("Starter deck:", starter_deck.map(func(card): return card.name))

# In course_1.gd
print("Dodge mode active:", dodge_mode_active)
```

## Conclusion

The Dodge card system is now fully integrated into the game's reward, shop, and starter deck systems. Players can obtain it through rewards, purchase it in shops, and test it immediately from the starter deck. The dodge mechanics provide powerful defensive capabilities and add strategic depth to the card system, making it a valuable defensive option for players who prefer to avoid damage entirely rather than absorb it. 