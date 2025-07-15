# Swing Animation System

## Overview

The swing animation system provides visual feedback when the player starts charging height for a golf shot. It uses the `Swingserererer2.png` spritesheet to create a smooth swing animation that plays automatically when height charging begins.

## Components

### 1. SwingAnimation.gd
- **Location**: `res://Characters/SwingAnimation.gd`
- **Purpose**: Handles the spritesheet animation setup and playback
- **Features**:
  - Automatically detects frame count from spritesheet (3-6 frames)
  - Creates SpriteFrames resource dynamically
  - Manages animation states (IDLE, SWINGING, FINISHED)
  - Provides start/stop animation methods

### 2. Character Scene Updates
All character scenes have been updated to include the swing animation system:
- `BennyChar.tscn`
- `ClarkChar.tscn` 
- `LaylaChar.tscn`

Each scene now includes:
- `SwingAnimation` node with the SwingAnimation.gd script
- `SwingSprite` AnimatedSprite2D child node

### 3. Player.gd Integration
The Player script has been enhanced with swing animation support:
- Automatically detects swing animation system in character scenes
- Monitors `is_charging_height` state changes
- Triggers swing animation when height charging starts
- Stops animation when height charging stops

## How It Works

### Automatic Triggering
1. When the player starts charging power (`is_charging = true`), the swing animation automatically starts
2. When power charging stops (`is_charging = false`), the animation stops
3. The animation plays once and then hides the swing sprite

### Spritesheet Processing
The system automatically:
1. Loads the `Swingserererer2.png` spritesheet
2. Tries different frame counts (3, 4, 5, 6) to find the best fit
3. Creates individual frame textures using AtlasTexture
4. Sets up a SpriteFrames resource with 10 FPS playback
5. Falls back to single-frame if frame detection fails

### Animation States
- **IDLE**: No animation playing
- **SWINGING**: Animation is currently playing
- **FINISHED**: Animation completed, waiting to reset

## Usage

### Automatic Usage
The swing animation triggers automatically when:
- Player starts charging power (left-click and hold)
- Player stops charging power

### Manual Control
You can also manually control the animation:

```gdscript
# Start swing animation
player.start_swing_animation()

# Stop swing animation  
player.stop_swing_animation()

# Check if swinging
if player.is_swinging():
    print("Player is currently swinging")
```

## Testing

A test scene is provided at `test_swing_animation.tscn` with buttons to:
- Test the swing animation manually
- Stop the swing animation

## Technical Details

### Frame Detection Logic
The system uses reasonable frame width constraints (32-200 pixels) to determine the correct frame count from the spritesheet.

### Performance
- Animation only runs when needed (height charging)
- Spritesheet is loaded once and cached
- Animation automatically cleans up after completion

### Integration Points
- Integrates with LaunchManager's power charging system
- Works with all character types (Benny, Clark, Layla)
- Compatible with existing Player movement and collision systems

## Future Enhancements

Potential improvements:
- Add sound effects during swing
- Create different swing animations for different clubs
- Add swing power visual feedback
- Support for different swing speeds based on charge amount 