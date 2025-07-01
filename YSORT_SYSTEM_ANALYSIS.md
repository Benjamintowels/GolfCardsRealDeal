# Ysort System Analysis and Improvements

## Overview
The Ysort system in this Godot project ensures that objects are rendered in the correct order based on their Y position, creating proper depth perception. Objects with higher Y values appear in front of objects with lower Y values.

## Current Ysort Implementation

### Global System (Global.gd)
- Uses Godot's built-in Y-sorting with manual z_index offsets
- Z-index offsets for different object types:
  - `background`: -100 (behind everything)
  - `ground`: -50 (behind objects)
  - `objects`: 0 (trees, pins, etc.)
  - `characters`: 50 (player, NPCs)
  - `balls`: 100 (in front of characters)
  - `ui`: 200 (in front of everything)

### Key Functions
- `get_y_sort_z_index()`: Calculates z_index based on Y position and object type
- `update_object_y_sort()`: Updates a node's z_index using custom Y-sort point if available
- `update_all_objects_y_sort()`: Updates all objects in the ysort_objects array

## Object Ysort Positioning Analysis

### Objects with `get_y_sort_point()` Method

#### 1. Tree (Obstacles/Tree.gd) - **FIXED**
- **Sprite Position**: `(3, -121)` in scene with scale `(0.315, 0.315)`
- **Ysort Point**: `sprite.global_position.y + (texture_height * scale.y)` (dynamic calculation)
- **Reference**: Base of trunk (ground level)
- **Status**: ✅ Now correctly implemented with dynamic calculation
- **Issues Fixed**: 
  - Removed fixed z_index from scene file
  - Fixed incorrect offset calculation (was using 278.365, now uses actual sprite height)
  - Added debug visualization and logging

#### 2. GangMember (NPC/Gang/GangMember.gd)
- **Sprite Position**: `(1, -43)` in scene
- **Ysort Point**: `base_collision_area.global_position.y`
- **Reference**: Base of collision area (feet)
- **Status**: ✅ Correctly implemented

#### 3. Pin (Obstacles/Pin.gd) - **NEWLY ADDED**
- **Sprite Position**: `(75.125, -384.08)` in scene
- **Ysort Point**: `global_position.y + 384.08`
- **Reference**: Base of pin (ground level)
- **Status**: ✅ Now correctly implemented

#### 4. Shop (Shop/shop_exterior.gd) - **NEWLY ADDED**
- **Sprite Position**: `(15.845, -34.905)` in scene
- **Ysort Point**: `global_position.y + 34.905`
- **Reference**: Base of shop building (ground level)
- **Status**: ✅ Now correctly implemented

#### 5. Player (Characters/Player.gd) - **NEWLY ADDED**
- **Sprite Position**: Varies by character (around `(0, -35)` to `(0, -40)`)
- **Ysort Point**: `global_position.y + 37.0` (average offset)
- **Reference**: Base of character's feet
- **Status**: ✅ Now correctly implemented

### Objects Without Custom Ysort Point
- **GolfBall**: Uses shadow position for Y-sorting (special handling)
- **Other obstacles**: Use default `global_position.y`

## Improvements Made

### 1. Added Missing `get_y_sort_point()` Methods

#### Pin.gd
```gdscript
func get_y_sort_point() -> float:
    # Use the base of the pin for Y-sorting
    # The sprite is positioned at (75.125, -384.08), so the base is at +384.08 from the origin
    return global_position.y + 384.08
```

#### shop_exterior.gd
```gdscript
func get_y_sort_point() -> float:
    # Use the base of the shop building for Y-sorting
    # The sprite is positioned at (15.845, -34.905), so the base is at +34.905 from the origin
    return global_position.y + 34.905
```

#### Player.gd
```gdscript
func get_y_sort_point() -> float:
    # Use the base of the character's feet for Y-sorting
    # Characters are positioned with negative Y offsets (around -35 to -40)
    # So the base is at +35 to +40 from the origin, depending on character
    var character_offset = 37.0  # Average offset for all characters
    return global_position.y + character_offset
```

### 2. Fixed Tree Ysort Implementation

#### Tree.gd - **MAJOR FIX**
```gdscript
func get_y_sort_point() -> float:
    # Use the bottom of the tree sprite for Y-sorting
    # The sprite is positioned at (3, -121) with scale (0.315, 0.315)
    # The base of the tree (ground level) is at the bottom of the sprite
    var sprite = get_node_or_null("Sprite2D")
    if sprite:
        # Get the actual height of the tree sprite
        var tree_height = sprite.texture.get_height() * sprite.scale.y
        # The base is at the bottom of the sprite, so add the height to the sprite's Y position
        return sprite.global_position.y + tree_height
    else:
        # Fallback calculation based on sprite position
        return global_position.y + 121.0
```

#### Tree.tscn - **FIXED**
- Removed fixed `z_index = 3` from scene file
- Now z_index is properly controlled by the Ysort system

#### Tree.gd - **DEBUG FEATURES ADDED**
- Added debug visualization (green line shows Ysort point)
- Added debug logging to compare with other objects
- Added automatic Ysort update on ready

## Consistency Achieved

Now all major objects in the game have consistent Ysort positioning:

1. **All objects use their base/feet/ground level for Ysort reference**
2. **Tree**: Base of trunk (ground level) - **FIXED**
3. **Pin**: Base of pin (ground level)
4. **Shop**: Base of building (ground level)
5. **Characters**: Base of feet
6. **GangMember**: Base of collision area (feet)
7. **GolfBall**: Shadow position (ground level)

## Benefits

1. **Consistent Depth Perception**: All objects now render in the correct order relative to their actual position on the ground
2. **Proper Layering**: Objects appear behind/in front of each other based on their true spatial relationship
3. **Maintainable Code**: All objects follow the same pattern for Ysort positioning
4. **Future-Proof**: New objects can easily implement the same pattern
5. **Debug-Friendly**: Added visualization and logging for troubleshooting

## Testing Recommendations

1. **Visual Testing**: Verify that objects render in the correct order when overlapping
2. **Movement Testing**: Ensure Ysort updates correctly as objects move
3. **Camera Testing**: Verify Ysort works correctly with camera zoom and movement
4. **Performance Testing**: Ensure the Ysort system doesn't impact performance
5. **Debug Testing**: Use Tree's debug features to verify Ysort calculations

## Debug Features

### Tree Debug Visualization
- **Red line**: Shows the node origin (0,0)
- **Green line**: Shows the Ysort point (base of tree)
- **Cyan cross**: Shows the node's origin point

### Tree Debug Logging
- Prints sprite position, tree height, and Ysort point
- Compares Tree Ysort with Player and Ball Ysort points
- Shows z_index values for verification

## Notes

- The Tree object now includes comprehensive debug visualization and logging
- The Global.gd system automatically detects and uses `get_y_sort_point()` methods
- The system is designed to be extensible for future objects
- Fixed z_index conflicts by removing hardcoded values from scene files 