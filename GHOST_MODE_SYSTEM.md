# GhostMode Card System

## Overview

The GhostMode card is a new PlayerEffect card that allows the player to become temporarily invisible to NPCs and gain a ghost-like appearance. When used, the player's character sprite becomes semi-transparent and NPCs will ignore the player as if they don't exist.

## Card Details

### GhostMode Card
- **Name**: GhostMode
- **Effect Type**: PlayerEffect
- **Effect Strength**: 1
- **Level**: 1 (can be upgraded to Level 2)
- **Max Level**: 2
- **Upgrade Cost**: 100 coins
- **Price**: 150 coins
- **Default Tier**: 2 (Medium-tier card)
- **Image**: `res://Cards/GhostMode.png`

### Effect Duration
GhostMode lasts until the player starts their next turn. This means:
- The effect persists through the World Turn (NPC turns)
- The effect is automatically deactivated when the player draws cards for their next shot
- This provides strategic timing - players can use it to avoid NPCs during their turn, then have it persist through the dangerous World Turn phase

## How It Works

### 1. Card Activation
When the GhostMode card is played:
1. **Sound Effect**: Plays `res://Sounds/CoolSound.mp3`
2. **Visual Effect**: Player sprite animates to 40% opacity over 0.5 seconds
3. **NPC Ignoring**: All NPCs (except squirrels) will ignore the player during their turns

### 2. Visual Effects
- **Player Transparency**: Character sprite becomes 40% opaque (60% transparent)
- **Smooth Animation**: Uses Tween with SINE transition and EASE_OUT easing
- **Restoration**: When deactivated, sprite animates back to 100% opacity

### 3. NPC Behavior Changes
During ghost mode, NPCs will:
- **Police**: Return to patrol state, ignore player completely
- **GangMembers**: Return to patrol state, ignore player completely  
- **ZombieGolfers**: Return to patrol state, ignore player completely
- **Squirrels**: Continue normal behavior (they detect golf balls, not players)

### 4. Deactivation
GhostMode is automatically deactivated when:
- The player starts their next turn (draws cards for shot)
- The sprite animates back to full opacity over 0.5 seconds

## Implementation Details

### CardEffectHandler Integration
- Added `handle_player_effect()` function for PlayerEffect cards
- Added `_handle_ghost_mode_effect()` for specific GhostMode handling
- Added `play_ghost_mode_sound()` for sound effect playback

### Course Integration
- Added `ghost_mode_active` boolean flag
- Added `ghost_mode_tween` for animation management
- Added `activate_ghost_mode()` and `deactivate_ghost_mode()` methods
- Added `is_ghost_mode_active()` for status checking

### NPC Integration
Each NPC type has been updated to check for ghost mode:
- **Police**: `_check_player_vision()` checks ghost mode before vision detection
- **GangMember**: `_check_player_vision()` checks ghost mode before vision detection
- **ZombieGolfer**: `_check_player_vision()` checks ghost mode before vision detection
- All NPCs have `_find_course_script()` method to access course state

### Turn Management Integration
- Ghost mode is deactivated in `draw_cards_for_shot()` when starting a new player turn
- NPC turn sequence checks ghost mode in `get_visible_npcs_by_priority()`
- Ghost mode persists through World Turn phase

## Usage Strategy

### Strategic Timing
- **Defensive Use**: Activate before ending turn to avoid NPCs during World Turn
- **Escape Use**: Use when surrounded by NPCs to safely move away
- **Stealth Use**: Use to pass through NPC patrols without detection

### Limitations
- **Squirrels**: Still detect and interact with golf balls normally
- **Duration**: Limited to one turn cycle
- **Visual**: Player remains visible but transparent
- **Sound**: Plays distinctive sound effect (may alert players to usage)

## Testing

### Test Scene
Run `test_ghost_mode.tscn` to verify:
- Card resource loads correctly
- Sound file exists
- Card image exists

### In-Game Testing
1. Add GhostMode card to deck or purchase from shop
2. Use card during player turn
3. Verify player becomes transparent
4. End turn and observe NPCs ignoring player during World Turn
5. Start next turn and verify ghost mode deactivates

## Future Enhancements

### Potential Improvements
- **Visual Effects**: Add ghost particles or trail effects
- **Sound Variations**: Different sounds for activation/deactivation
- **Duration Modifiers**: Equipment or upgrades that extend ghost mode duration
- **Partial Immunity**: Some NPCs could still detect ghost mode player
- **Stealth Mechanics**: Ghost mode could affect other game systems

### Technical Improvements
- **Performance**: Optimize NPC vision checks during ghost mode
- **Memory**: Ensure proper cleanup of ghost mode state
- **Persistence**: Save/load ghost mode state in game saves
- **Debug**: Add debug indicators for ghost mode status 