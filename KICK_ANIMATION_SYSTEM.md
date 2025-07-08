# Kick Animation System

## Overview

The kick animation system provides visual feedback when the player performs a kick attack using the Kick card. It switches to the BennyKick sprite for a brief animation and then returns to the normal character sprite.

## Components

### 1. BennyKick Sprite
- **Location**: `res://Characters/BennyKick.png`
- **Scene Integration**: Added to `BennyChar.tscn` as a child node named "BennyKick"
- **Default State**: Hidden (visible = false)
- **Purpose**: Shows the kicking pose when a kick attack is performed

### 2. Player.gd Kick Animation System
The Player script has been enhanced with kick animation support:
- **Variables**: `kick_sprite`, `is_kicking`, `kick_duration`, `kick_tween`
- **Setup**: `_setup_kick_animation()` - Finds the kick sprite in the character scene
- **Animation**: `start_kick_animation()` - Switches to kick sprite and starts timer
- **Completion**: `_on_kick_animation_complete()` - Switches back to normal sprite
- **Control**: `stop_kick_animation()` - Manually stop animation if needed

### 3. AttackHandler.gd Integration
The AttackHandler has been updated to trigger kick animations:
- **Signal**: `kick_attack_performed` - Emitted when a kick attack is executed
- **Trigger Points**: 
  - `perform_attack()` - When attacking NPCs with Kick card
  - `perform_kickb_attack_on_oil_drum()` - When kicking oil drums

### 4. Course Integration
The course script connects the kick attack signal:
- **Connection**: `attack_handler.kick_attack_performed.connect(_on_kick_attack_performed)`
- **Handler**: `_on_kick_attack_performed()` - Calls `player.start_kick_animation()`

## How It Works

### Automatic Triggering
1. When a player uses a Kick card to attack an NPC or oil drum
2. The AttackHandler emits the `kick_attack_performed` signal
3. The course script receives the signal and calls `player.start_kick_animation()`
4. The Player script switches from normal sprite to BennyKick sprite
5. After 0.5 seconds, the animation completes and switches back to normal sprite

### Animation Flow
1. **Normal State**: Character shows normal BennyChar sprite
2. **Kick Triggered**: Kick attack performed (NPC attack or oil drum kick)
3. **Animation Start**: Normal sprite hidden, BennyKick sprite shown
4. **Animation Duration**: 0.5 seconds (configurable via `kick_duration`)
5. **Animation Complete**: BennyKick sprite hidden, normal sprite shown again

### Character Scene Structure
```
BennyChar (Node2D)
├── Sprite2D (normal character sprite)
├── BennyKick (Sprite2D - kick animation sprite)
├── SwingAnimation (Node2D - swing animation system)
└── ... (other nodes)
```

## Testing

### Test Scene
- **File**: `test_kick_animation.tscn`
- **Script**: `test_kick_animation.gd`
- **Usage**: Click "Test Kick Animation" button to manually trigger kick animation

### Manual Testing
1. Load the test scene
2. Click the test button
3. Observe the character switching to kick pose for 0.5 seconds
4. Verify the character returns to normal pose

### In-Game Testing
1. Start a round with Benny character
2. Draw a Kick card
3. Use the Kick card to attack an NPC or oil drum
4. Observe the kick animation playing automatically

## Configuration

### Animation Duration
- **Default**: 0.5 seconds
- **Location**: `Characters/Player.gd` - `kick_duration` variable
- **Modification**: Change the value to adjust animation length

### Sprite Detection
The system automatically finds the BennyKick sprite by:
1. Searching direct children of Player node
2. Searching children of Node2D children (character scenes)
3. Searching deeper nested character scenes

## Future Enhancements

### Multi-Character Support
- Add kick sprites for Layla and Clark characters
- Modify sprite detection to work with all character types
- Character-specific kick animations

### Enhanced Animation
- Add multiple kick animation frames
- Implement directional kick animations (left/right)
- Add kick sound effects integration

### Performance Optimization
- Preload kick sprites for faster switching
- Add animation pooling for multiple rapid kicks
- Optimize sprite visibility changes 