# Idle Zoom System

## Overview
The Idle Zoom System automatically zooms the camera into the player after 1 second of inactivity, providing a cinematic close-up effect when the game is idle. This creates a more engaging visual experience and draws attention to the player character.

## How It Works

### Idle Timer
- **Duration**: 1 second of inactivity
- **Trigger**: Starts after camera settles on player position
- **Reset**: Any camera activity resets the timer
- **Effect**: Smoothly zooms to maximum zoom level (3.0x) over 2 seconds

### Activation Conditions
The idle zoom timer starts automatically when:
- Camera finishes moving to player after movement
- Camera returns to player after aiming phase
- Camera returns to player after NPC interactions
- Camera settles after manual panning

### Reset Conditions
The idle zoom timer resets when:
- Camera moves to a new position
- User manually zooms with mouse wheel
- User pans the camera with middle mouse button
- Camera transitions to NPCs or other targets

### Disabled During
The idle zoom system is disabled during:
- Aiming phase (to avoid interference with aiming mechanics)
- Camera transitions to NPCs
- Active camera tweens or movements

## Implementation Details

### Key Components

#### CameraManager.gd
- **Idle Timer**: `Timer` node that tracks inactivity
- **Zoom Effect**: Smooth tween to maximum zoom level
- **State Management**: Tracks when idle zoom is active
- **Integration**: Hooks into existing camera functions

#### CameraZoom.gd
- **Manual Zoom Detection**: Detects mouse wheel input
- **Timer Reset**: Calls camera manager to reset idle timer
- **Zoom Limits**: Respects current zoom limits (drone equipment, etc.)

### Key Methods

#### `start_idle_zoom_timer()`
```gdscript
func start_idle_zoom_timer() -> void:
    """Start the idle zoom timer to track when camera should zoom in"""
    if not idle_zoom_timer:
        return
    
    # Don't start idle zoom during aiming phase
    if aiming_tracking_active:
        return
    
    # Don't start if already active
    if idle_zoom_active:
        return
    
    # Reset and start the timer
    idle_zoom_timer.stop()
    idle_zoom_timer.start()
```

#### `_start_idle_zoom_effect()`
```gdscript
func _start_idle_zoom_effect() -> void:
    """Start the idle zoom effect - smoothly zoom to maximum zoom"""
    idle_zoom_active = true
    
    # Get current zoom and target zoom
    var current_zoom = camera.get_current_zoom()
    var target_zoom = min(idle_zoom_target, camera.get_current_max_zoom())
    
    # Create smooth zoom tween over 2 seconds
    idle_zoom_tween = get_tree().create_tween()
    idle_zoom_tween.tween_method(func(zoom_level: float):
        camera.set_zoom_level(zoom_level)
    , current_zoom, target_zoom, 2.0)
```

#### `reset_idle_zoom_timer()`
```gdscript
func reset_idle_zoom_timer() -> void:
    """Reset the idle zoom timer (called when camera activity is detected)"""
    # Cancel any active idle zoom effect
    if idle_zoom_active:
        _cancel_idle_zoom_effect()
    
    # Restart the timer
    start_idle_zoom_timer()
```

## Configuration

### Settings
- **Idle Duration**: 1.0 seconds (configurable via `idle_zoom_duration`)
- **Target Zoom**: 3.0x zoom (configurable via `idle_zoom_target`)
- **Zoom Duration**: 2.0 seconds (hardcoded in tween)
- **Easing**: Sine transition with ease-in-out

### Integration Points
- **Player Movement**: Starts timer after movement completes
- **Aiming Phase**: Stops timer during aiming, restarts after
- **Camera Panning**: Resets timer on pan start/motion
- **Manual Zoom**: Resets timer on mouse wheel input
- **NPC Interactions**: Stops timer during transitions

## Testing

### Test Scene
Use `test_idle_zoom.tscn` to verify the system works correctly:
1. Run the test scene
2. Wait 1 second for idle zoom to activate
3. Move camera or zoom manually to test reset
4. Enter aiming phase to test disabled state

### Expected Behavior
- Camera zooms in smoothly after 1 second of inactivity
- Any camera activity resets the timer
- Aiming phase disables the system
- Manual zoom input resets the timer
- System respects zoom limits from equipment

## Future Enhancements

### Potential Improvements
- **Configurable Timing**: Make idle duration and zoom duration configurable
- **Zoom Level**: Allow different target zoom levels based on context
- **Visual Feedback**: Add subtle visual indicators when idle zoom is about to activate
- **Audio Cues**: Add optional audio feedback for idle zoom activation
- **Performance**: Optimize timer management for better performance

### Integration Ideas
- **Cutscene Mode**: Disable during cutscenes or important events
- **UI Interactions**: Disable when UI elements are being interacted with
- **Multiplayer**: Coordinate idle zoom across multiple players
- **Accessibility**: Add option to disable for accessibility reasons 