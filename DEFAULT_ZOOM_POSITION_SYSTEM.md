# Default Zoom Position System

## Overview
The Default Zoom Position System provides a consistent zoom level that the camera will always return to after player movement, regardless of any manual zoom adjustments made by the player.

## How It Works

### Default Zoom Position
- **Default Value**: 1.8x zoom (closer view)
- **Purpose**: Provides a consistent, optimal viewing distance after movement
- **Behavior**: Always zooms to this position after playing movement cards, regardless of current zoom level

### Key Features

#### Consistent Zoom Experience
- Player can manually zoom in/out using mouse wheel
- When a movement card is played, camera always zooms to the default position
- No matter how far the player has zoomed out, the "zoom in" effect will always go to the same position

#### Dynamic Adjustment
- Default zoom position can be changed at runtime
- Automatically respects current zoom limits (drone equipment, etc.)
- Can be adjusted based on game state or equipment

#### Smooth Transitions
- Uses existing tween system for smooth zoom transitions
- 1.2 second duration with sine easing for natural feel
- Avoids unnecessary tweens if already at default position

## Implementation Details

### CameraZoom.gd Changes
- Added `default_zoom_position` variable (default: 1.8)
- Modified `zoom_in_after_movement()` to always zoom to default position
- Added `set_default_zoom_position()` and `get_default_zoom_position()` methods
- Updated `reset_zoom()` to use default position
- Updated initialization to use default position

### Key Methods

#### `zoom_in_after_movement()`
```gdscript
func zoom_in_after_movement():
    """Smoothly zoom in to the default zoom position after player movement"""
    var zoom_target = clamp(default_zoom_position, current_min_zoom, current_max_zoom)
    
    if abs(target_zoom - zoom_target) > 0.01:
        target_zoom = zoom_target
        _start_zoom_tween()
```

#### `set_default_zoom_position(zoom_level: float)`
```gdscript
func set_default_zoom_position(zoom_level: float):
    """Set the default zoom position for the zoom in effect"""
    default_zoom_position = clamp(zoom_level, current_min_zoom, current_max_zoom)
```

## Usage Examples

### Basic Usage
The system works automatically - no additional code needed. When a player plays a movement card, the camera will automatically zoom to the default position.

### Changing Default Zoom Position
```gdscript
# Set a closer default zoom for more detailed view
camera.set_default_zoom_position(2.2)

# Set a wider default zoom for better overview
camera.set_default_zoom_position(1.4)
```

### Equipment-Based Adjustments
```gdscript
# Adjust default zoom based on equipment
if equipment_manager.has_drone():
    camera.set_default_zoom_position(2.0)  # Closer with drone
else:
    camera.set_default_zoom_position(1.6)  # Further without drone
```

## Testing

Use the test scene `test_drone_zoom_system.tscn`:
- Press `6`: Test default zoom position functionality
- Press `4`: Show current status including default zoom position

The test will:
1. Show current default zoom position
2. Manually adjust zoom to different level
3. Test zoom in after movement (should go to default)
4. Change default zoom position
5. Test zoom in after movement with new default

## Benefits

1. **Consistent Experience**: Players always get the same optimal view after movement
2. **Freedom of Manual Control**: Players can still zoom manually without affecting the movement zoom
3. **Flexible Configuration**: Default position can be adjusted for different game states
4. **Smooth Integration**: Works seamlessly with existing zoom and equipment systems

## Future Enhancements

- Could add different default positions for different movement card types
- Could integrate with difficulty settings
- Could add visual indicators when zooming to default position
- Could add different default positions for different course types 