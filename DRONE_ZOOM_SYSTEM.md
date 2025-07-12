# Drone Zoom System

## Overview
The Drone equipment now provides enhanced camera zoom capabilities instead of mobility bonuses. When equipped, the drone allows for more generous zoom levels, while without it, zoom is restricted to more reasonable limits.

## How It Works

### Equipment Effect
- **Drone Equipped**: Zoom range of 0.5x to 3.0x (generous zoom)
- **No Drone**: Zoom range of 0.8x to 2.0x (reduced zoom)

### Implementation Details

#### EquipmentManager.gd
- Added `drone_zoom_enabled` boolean to track drone status
- Added `_apply_drone_zoom_effect()` and `_remove_drone_zoom_effect()` functions
- Added `_update_camera_zoom_limits()` to dynamically adjust camera zoom limits
- Added `_initialize_camera_zoom_limits()` to set initial zoom on game start
- Added helper methods: `has_drone()`, `is_drone_zoom_enabled()`, `force_update_camera_zoom()`

#### CameraZoom.gd
- Added dynamic zoom limit variables: `current_min_zoom` and `current_max_zoom`
- Modified `set_zoom_level()` to use dynamic limits instead of static ones
- Added `set_zoom_limits()` method to change zoom limits at runtime
- Zoom limits are automatically clamped when changed

#### Equipment Data
- Updated `Drone.tres` to use `buff_type = "drone_zoom"` instead of `"mobility"`
- Updated description to reflect new zoom capabilities

## Usage

### In Game
1. Equip the Drone equipment to enable generous zoom (0.5x - 3.0x)
2. Unequip the Drone to restrict zoom to reduced levels (0.8x - 2.0x)
3. Zoom limits are automatically applied when equipment changes

### Testing
Use the test scene `test_drone_zoom_system.tscn` to verify functionality:
- Press `1`: Add Drone equipment
- Press `2`: Remove Drone equipment  
- Press `3`: Test zoom limits
- Press `4`: Show current status

## Technical Notes

### Zoom Limits
- **With Drone**: 0.5x (zoomed out) to 3.0x (zoomed in)
- **Without Drone**: 0.8x (zoomed out) to 2.0x (zoomed in)

### Camera Integration
- The system automatically finds the `GameCamera` node in the scene
- Zoom limits are applied immediately when equipment changes
- Current zoom level is clamped to new limits if necessary

### Performance
- Zoom limit changes are smooth and use existing tween system
- No performance impact during normal gameplay
- Only updates when equipment changes

## Future Enhancements
- Could add visual drone indicator in UI
- Could add zoom level display
- Could add different zoom ranges for different drone types
- Could integrate with other camera effects (panning limits, etc.) 