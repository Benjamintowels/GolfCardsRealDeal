# Tree Cutting System

## Overview
The Tree Cutting System allows PowerBeam projectiles to cut trees into stumps and falling tops, creating a fun and dynamic gameplay mechanic.

## How It Works

### 1. PowerBeam Collision
- When a PowerBeam collides with a tree's `TrunkBaseArea`, it calls the tree's `take_damage()` method
- The tree checks if it's already cut to prevent multiple cuts
- If not cut, the tree initiates the cutting process

### 2. Tree Cutting Process
When a tree is cut, the following happens:

1. **Disable Default Components:**
   - Default `Sprite2D` (full tree sprite)
   - Default `TopHeight` marker
   - `LightOccluder2D`

2. **Enable Cut Components:**
   - `TreeStump` (remaining stump)
   - `TreeTop` (falling top section)

3. **Disable Hover Effect:**
   - Mouse detection areas are disabled
   - Transparency effect is turned off

4. **Update Collision System:**
   - Collision detection switches to use stump's `TopHeight` marker
   - Y-sorting updates to use `TreeTop`'s `YSortPoint`

### 3. Animation System
The `TreeTop` animates in two ways:

1. **Built-in Animation:** Uses `TreeTopAnimationPlayer` with "pop_off" animation
   - Handles scaling and sound effects
   - Animation duration: 0.6 seconds

2. **Random Movement Tween:** 
   - Random direction (0-360 degrees)
   - Random rotation (±45 degrees)
   - Movement distance: 100 pixels
   - Duration: 0.6 seconds (matches animation)

## Required Scene Structure

```
Tree (CharacterBody2D)
├── TreeStump (Sprite2D) - Initially hidden
│   └── TopHeight (Marker2D) - Reduced height for stump
├── TreeTop (Sprite2D) - Initially hidden
│   ├── TreeTopAnimationPlayer (AnimationPlayer)
│   │   └── pop_off (Animation) - 0.6s duration
│   ├── YSortPoint (Node2D) - For Y-sorting
│   └── Area2D - For collision detection
├── Sprite2D - Default tree sprite
│   ├── TopHeight (Marker2D) - Full tree height
│   └── AnimationPlayer - Hover transparency
├── TrunkBaseArea (Area2D) - PowerBeam collision
├── LightOccluder2D - Lighting occlusion
└── [Other existing nodes...]
```

## Key Methods

### `take_damage(damage: int)`
- Called by PowerBeam when it hits the tree
- Prevents multiple cuts on the same tree
- Initiates the cutting process

### `is_cut() -> bool`
- Returns whether the tree has been cut
- Useful for other systems to check tree state

### `get_height_marker() -> Node2D`
- Returns the appropriate height marker for collision detection
- Uses stump's `TopHeight` when cut, default `TopHeight` when intact

### `get_y_sort_point() -> float`
- Returns the Y-sorting reference point
- Uses `TreeTop`'s `YSortPoint` when cut, default `YsortPoint` when intact

## Testing

Use the `test_tree_cutting.gd` script to test the system:
1. Attach the script to any scene
2. Press `T` to trigger tree cutting on the first uncut tree
3. Watch the console for debug output

## Integration with PowerBeam

The PowerBeam already has collision detection for `TrunkBaseArea` and calls `take_damage()` on objects. The tree cutting system integrates seamlessly with this existing system.

## Animation Customization

To customize the tree cutting animation:

1. **Modify the "pop_off" animation** in `TreeTopAnimationPlayer`
2. **Adjust random movement parameters** in `_animate_tree_top_pop_off()`:
   - Movement distance (currently 100 pixels)
   - Rotation range (currently ±45 degrees)
   - Animation duration (currently 0.6 seconds)

## Performance Considerations

- Trees are only cut once per instance
- Hover effects are disabled after cutting
- Y-sorting automatically updates to use appropriate markers
- No continuous processing required after cutting

## Future Enhancements

Potential improvements:
- Add particle effects for sawdust/wood chips
- Implement different cutting directions based on PowerBeam angle
- Add sound effects for the cutting process
- Create different stump/top variations
- Add physics-based falling for the tree top 