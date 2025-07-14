# Benny Arm Height Visual Effect System

## Overview

The Benny Arm Height system provides a visual effect during the SetHeight phase where Benny's arm rotates to face the mouse cursor, creating an intuitive aiming mechanism for height selection.

## Components

### 1. BennyArmHeightController.gd
- **Location**: `res://Characters/BennyArmHeightController.gd`
- **Purpose**: Controls the visual effect during SetHeight phase
- **Features**:
  - Shows BennyArmlessSprite during SetHeight phase
  - Places BennyArmHeight scene on top of the armless sprite
  - Rotates the arm to face mouse cursor (up to 90 degrees up or 0 degrees down)
  - Automatically activates/deactivates based on game phase

### 2. BennyArmHeight.tscn
- **Location**: `res://Characters/BennyArmHeight.tscn`
- **Purpose**: The arm sprite that rotates to face the mouse
- **Features**:
  - Origin point positioned at the rotation point (shoulder area)
  - Single sprite that rotates smoothly
  - Designed to align with BennyArmlessSprite

### 3. BennyChar.tscn Updates
The BennyChar scene has been updated to include:
- `BennyArmHeightController` node with the controller script
- Integration with the existing BennyArmlessSprite

### 4. Player.gd Integration
The Player script has been enhanced with arm height controller support:
- Automatically detects and sets up the arm height controller
- Activates the visual effect during SetHeight phase
- Manages camera and player references

## How It Works

### Automatic Activation
1. When the player enters the SetHeight phase (`is_selecting_height = true`), the arm height controller automatically activates
2. The BennyArmlessSprite becomes visible
3. The BennyArmHeight sprite appears and starts rotating to face the mouse
4. When the SetHeight phase ends, both sprites are hidden

### Mouse Tracking
The system tracks mouse movement and calculates the angle:
- Mouse up = arm points up (up to 90 degrees)
- Mouse down = arm points down (minimum 0 degrees, horizontal)
- Smooth rotation between these limits

### Rotation Limits
- **Maximum Up**: -90 degrees (90 degrees upward)
- **Maximum Down**: 0 degrees (horizontal)
- **Smooth Interpolation**: The arm smoothly rotates between these limits

## Integration with Launch System

### LaunchManager Integration
The system integrates with the existing LaunchManager:
- Detects `is_selecting_height` state changes
- Emits `charging_state_changed` signal during height selection
- Provides `get_selecting_height()` method for state queries

### Course Integration
The course_1.gd provides:
- `get_launch_manager()` method for accessing LaunchManager
- Proper signal handling for state changes
- Integration with existing mouse facing system

## Testing

### Test Scene
Use the `test_benny_arm_height.tscn` scene to test the system:
1. **Setup**: Scene includes BennyChar and Camera2D
2. **Controls**:
   - Move mouse up/down to see arm rotation
   - Press SPACE to toggle SetHeight phase
   - Press ESC to exit

### Expected Behavior
1. **Mouse Movement**: Arm should rotate smoothly to face mouse
2. **Phase Toggle**: Arm should appear/disappear with phase changes
3. **Rotation Limits**: Arm should not rotate beyond 90 degrees up or below horizontal

## Technical Details

### Positioning
The BennyArmHeight sprite is positioned at the same location as the BennyArmlessSprite, with its origin point at the rotation center (shoulder area).

### Performance
- Rotation updates only during SetHeight phase
- Debug output is throttled to prevent spam
- Efficient mouse position calculations

### State Management
The system properly manages state transitions:
- **Enter SetHeight**: Show sprites, start rotation
- **Exit SetHeight**: Hide sprites, stop rotation
- **Mouse Movement**: Update rotation angle

## Future Enhancements

Potential improvements for the system:
1. **Smooth Animation**: Add tweening for smoother rotation transitions
2. **Visual Feedback**: Add visual indicators for optimal height ranges
3. **Sound Effects**: Add audio feedback for rotation
4. **Multi-Character Support**: Extend to other characters with similar mechanics 