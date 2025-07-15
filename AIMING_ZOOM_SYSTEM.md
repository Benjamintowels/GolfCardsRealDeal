# Aiming Zoom System

## Overview
The Aiming Zoom System automatically zooms out the camera when entering aiming phase to provide better visibility for shot placement, and restores the previous zoom level when exiting aiming phase.

## How It Works

### Zoom Out on Aiming Entry
- **Trigger**: When `enter_aiming_phase()` is called
- **Behavior**: Camera zooms out by 30% from the default zoom position
- **Purpose**: Provides better field of view for aiming and shot placement
- **Storage**: Current zoom level is stored as metadata for later restoration

### Zoom Restoration on Aiming Exit
- **Trigger**: When exiting aiming phase (left click to launch or right click to cancel)
- **Behavior**: Camera zooms back to the level it was at before entering aiming phase
- **Purpose**: Returns to the player's preferred zoom level
- **Cleanup**: Stored zoom metadata is removed after restoration

## Implementation Details

### Key Functions

#### `enter_aiming_phase()` (Modified)
```gdscript
# Zoom out when entering aiming phase for better visibility
if camera and camera.has_method("set_zoom_level"):
    # Store current zoom to restore later
    if not has_meta("pre_aiming_zoom"):
        set_meta("pre_aiming_zoom", camera.get_current_zoom())
    
    # Calculate zoom out based on shot distance potential
    var base_zoom = camera.get_default_zoom_position()
    var zoom_out_factor = 0.3  # Zoom out by 30%
    var aiming_zoom = base_zoom - zoom_out_factor
    
    # Ensure we don't go below minimum zoom
    if camera.has_method("current_min_zoom"):
        aiming_zoom = max(aiming_zoom, camera.current_min_zoom)
    
    camera.set_zoom_level(aiming_zoom)
```

#### `restore_zoom_after_aiming()` (New)
```gdscript
func restore_zoom_after_aiming() -> void:
    """Restore camera zoom to the level it was at before entering aiming phase"""
    if camera and camera.has_method("set_zoom_level") and has_meta("pre_aiming_zoom"):
        var pre_aiming_zoom = get_meta("pre_aiming_zoom")
        camera.set_zoom_level(pre_aiming_zoom)
        # Remove the stored zoom level
        remove_meta("pre_aiming_zoom")
```

### Integration Points

#### Course Input Handling
- **Left Click**: Exits aiming → enters launch phase → restores zoom
- **Right Click**: Exits aiming → returns to move phase → restores zoom

#### Weapon Handler
- **Weapon Mode Exit**: Restores zoom when exiting weapon aiming modes
- **Compatibility**: Works with all weapon types (knife, grenade, shotgun, sniper)

#### Smart Performance Optimizer
- **Input Handling**: Restores zoom in optimized input processing
- **Performance**: Maintains smooth zoom transitions during optimization

## Zoom Calculation

### Zoom Out Factor
- **Base Calculation**: `default_zoom_position - 0.3`
- **Minimum Protection**: Never goes below camera's minimum zoom limit
- **Example**: If default zoom is 1.5, aiming zoom becomes 1.2

### Zoom Limits
- **Respects Equipment**: Works with drone zoom limits
- **Dynamic Adjustment**: Adapts to current zoom constraints
- **Smooth Transitions**: Uses existing tween system for smooth zoom changes

## Usage Examples

### Normal Golf Shot
1. Player clicks to enter aiming phase
2. Camera zooms out for better visibility
3. Player moves mouse to set landing spot
4. Player left-clicks to confirm shot
5. Camera zooms back to previous level
6. Launch phase begins

### Weapon Aiming
1. Player selects weapon card
2. Camera zooms out for aiming
3. Player aims weapon
4. Player fires or cancels
5. Camera zooms back to previous level
6. Returns to move phase

### Canceling Aiming
1. Player enters aiming phase
2. Camera zooms out
3. Player right-clicks to cancel
4. Camera zooms back to previous level
5. Returns to move phase

## Testing

### Test Scene
Use `test_aiming_zoom.tscn` to verify functionality:
- **Key 1**: Enter aiming phase
- **Key 2**: Exit aiming (left click simulation)
- **Key 3**: Exit aiming (right click simulation)
- **Key 4**: Show current status
- **Key 5**: Test complete zoom restoration cycle

### Test Verification
- ✓ Camera zooms out when entering aiming
- ✓ Pre-aiming zoom is stored correctly
- ✓ Camera zooms back when exiting aiming
- ✓ Zoom metadata is cleaned up properly
- ✓ Works with all exit methods (left click, right click, weapon exit)

## Technical Notes

### Metadata Storage
- **Key**: `"pre_aiming_zoom"`
- **Type**: Float (zoom level)
- **Lifecycle**: Set on aiming entry, removed on aiming exit
- **Scope**: Course instance metadata

### Camera Integration
- **Method Requirements**: `set_zoom_level()`, `get_current_zoom()`, `get_default_zoom_position()`
- **Optional Methods**: `current_min_zoom()` for limit protection
- **Compatibility**: Works with existing CameraZoom.gd system

### Performance Impact
- **Minimal**: Only affects zoom level during aiming phase
- **Smooth**: Uses existing tween system for transitions
- **Efficient**: Metadata cleanup prevents memory leaks

## Future Enhancements
- Could add configurable zoom out factor per club type
- Could add different zoom levels for different aiming distances
- Could integrate with player preferences for zoom behavior
- Could add visual indicators for zoom state changes 