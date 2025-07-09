# Punch Animation System

## Overview

The punch animation system provides visual feedback when the player performs a PunchB attack. It uses the `BennyPunch.png` spritesheet to create a smooth punch animation that plays automatically when a PunchB attack is executed.

## Components

### 1. BennyPunch Spritesheet
- **Location**: `res://Characters/BennyPunch.png`
- **Scene Integration**: Configured in `BennyChar.tscn` as AtlasTexture frames
- **Animation**: 9-frame punch animation with 12 FPS playback
- **Purpose**: Shows the punching animation when a PunchB attack is performed

### 2. BennyChar Scene Setup
The BennyChar scene includes:
- **BennyPunch**: Dedicated AnimatedSprite2D node for punch animation
- **SpriteFrames**: Configured with 9 punch animation frames from the spritesheet
- **Animation**: "Punch" animation with 12 FPS playback speed

### 3. Player.gd Punch Animation System
The Player script has been enhanced with punch animation support:
- **Variables**: `punchb_animation`, `is_punching`, `punchb_duration`, `punchb_tween`
- **Setup**: `_setup_punchb_animation()` - Finds the AnimatedSprite2D in the character scene
- **Animation**: `start_punchb_animation()` - Plays the punch animation
- **Completion**: `_on_punchb_animation_complete()` - Stops animation and returns to normal sprite
- **Control**: `stop_punchb_animation()` - Manually stop animation if needed

### 4. AttackHandler.gd Integration
The AttackHandler has been updated to trigger punch animations:
- **Signal**: `punchb_attack_performed` - Emitted when a PunchB attack is executed
- **Trigger Points**: 
  - `perform_punchb_attack_immediate()` - When attacking NPCs with PunchB card
  - `perform_punchb_attack_on_oil_drum()` - When punching oil drums

### 5. Course Integration
The course script connects the punch attack signal:
- **Connection**: `attack_handler.punchb_attack_performed.connect(_on_punchb_attack_performed)`
- **Handler**: `_on_punchb_attack_performed()` - Calls `player.start_punchb_animation()`

## How It Works

### Automatic Triggering
1. When a player uses a PunchB card to attack an NPC or oil drum
2. **For adjacent targets**: The AttackHandler emits the `punchb_attack_performed` signal immediately
3. **For distant targets**: The AttackHandler emits the `punchb_attack_performed` signal when movement begins
4. The course script receives the signal and calls `player.start_punchb_animation()`
5. The Player script switches from normal sprite to AnimatedSprite2D
6. The punch animation plays for 0.5 seconds, then returns to normal sprite

### Animation Flow
1. **Normal State**: Character shows normal BennyChar sprite
2. **Punch Triggered**: PunchB attack performed (NPC attack or oil drum punch)
3. **Animation Start**: Normal sprite hidden, AnimatedSprite2D shown
4. **Animation Playback**: "Punch" animation plays at 12 FPS
5. **Movement Phase**: For distant targets, animation continues during player movement
6. **Animation Complete**: Animation stops, AnimatedSprite2D hidden, normal sprite shown again

### Character Scene Structure
```
BennyChar (Node2D)
├── Sprite2D (normal character sprite)
├── AnimatedSprite2D (swing animation)
│   └── AnimationPlayer
├── BennyKick (Sprite2D - kick animation sprite)
├── BennyPunch (AnimatedSprite2D - punch animation sprite)
├── SwingAnimation (Node2D - swing animation system)
└── ... (other nodes)
```

## Testing

### Test Scene
- **File**: `test_punch_animation.tscn`
- **Script**: `test_punch_animation.gd`
- **Usage**: Click "Test Punch Animation" button to manually trigger punch animation

### Manual Testing
1. Load the test scene
2. Click the test button
3. Observe the character playing the punch animation for 0.5 seconds
4. Verify the character returns to normal pose

### In-Game Testing
1. Start a round with Benny character
2. Draw a PunchB card
3. Use the PunchB card to attack an NPC or oil drum
4. Observe the punch animation playing automatically

## Configuration

### Animation Duration
- **Default**: 0.5 seconds
- **Location**: `Characters/Player.gd` - `punchb_duration` variable
- **Modification**: Change the value to adjust animation length

### Animation Speed
- **Default**: 12 FPS
- **Location**: `Characters/BennyChar.tscn` - SpriteFrames "Punch" animation
- **Modification**: Change the "speed" value in the SpriteFrames resource

### Sprite Detection
The system automatically finds the BennyPunch sprite by:
1. Searching for a node named "BennyPunch" that is an AnimatedSprite2D
2. Searching direct children of Player node
3. Searching children of Node2D children (character scenes)
4. Searching deeper nested character scenes

## Future Enhancements

### Multi-Character Support
- Add punch spritesheets for Layla and Clark characters
- Modify sprite detection to work with all character types
- Create character-specific punch animations

### Animation Variations
- Add different punch animations for different attack types
- Implement combo punch sequences
- Add impact effects during punch animation 