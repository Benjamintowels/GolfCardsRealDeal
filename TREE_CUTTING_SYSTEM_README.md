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
│   └── Area2D - For landing collision detection
│       └── CollisionShape2D - Shape for detecting landing collisions
├── Sprite2D - Default tree sprite
│   ├── TopHeight (Marker2D) - Full tree height
│   └── AnimationPlayer - Hover transparency
├── TrunkBaseArea (Area2D) - PowerBeam collision
├── LightOccluder2D - Lighting occlusion
└── [Other existing nodes...]
```

### Area2D Setup for Landing Collisions
The TreeTop's Area2D should be configured for landing collision detection:
- **Collision Layer**: 0 (not used for physics)
- **Collision Mask**: 1 (detect objects on layer 1)
- **Collision Shape**: Should cover the area where the tree top lands
- **Monitoring**: Enabled
- **Monitorable**: Enabled

**Important**: The Area2D must be on collision mask 1 to detect golf balls, which are on collision layer 1. This ensures the tree top can detect golf balls when it lands.

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

### `check_tree_top_landing_collision()`
- **Call this method from the TreeTop animation player** when the tree top lands
- Checks for collisions with NPCs, Players, GolfBalls, and Destructibles
- Applies appropriate damage and knockback based on target type
- Use this in the "pop_off" animation at the frame when the tree top hits the ground

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

## Landing Collision System

### How to Use
1. In the `TreeTopAnimationPlayer`, add a **Call Method** track to the "pop_off" animation
2. Set the method call to `check_tree_top_landing_collision()` 
3. Place the call at the frame when the tree top lands on the ground (around 0.6s)
4. Make sure the TreeTop's Area2D is properly configured for collision detection

### Animation Setup Steps
1. Open the TreeTop's `TreeTopAnimationPlayer`
2. Select the "pop_off" animation
3. Add a new **Call Method** track
4. Set the method to call: `check_tree_top_landing_collision()`
5. Position the call at the landing frame (typically around 0.6 seconds)
6. Test the animation to ensure collisions are detected

### Collision Effects

| Target Type | Damage | Knockback | Special Effects |
|-------------|--------|-----------|-----------------|
| **GolfBall/GhostBall** | None | None | **Rolling**: Reflection with 20% speed loss<br>**In Flight**: Roof bounce if above tree height, reflection if below |
| **Player** | 25 damage | 150 pixels | Standard damage + knockback |
| **NPCs** | 30 damage | 120 pixels | Damage + knockback + weapon position |
| **Destructibles** | 40 damage | None | High damage to destroy objects |

### Supported Targets
- **NPCs**: GangMember, Police, ZombieGolfer, Wraith, BossEye, BossHand
- **Destructibles**: OilDrum, Boulder
- **Players**: Any character with Player.gd script
- **Balls**: GolfBall, GhostBall

### Golf Ball Collision Logic
The tree top uses intelligent collision detection for golf balls:

1. **Rolling Ball Detection**: 
   - Ball height ≤ 5 pixels AND velocity > 10 pixels
   - **Result**: Ball is reflected off the tree top with 20% speed loss

2. **In-Flight Ball Detection**:
   - Ball height > 5 pixels OR velocity ≤ 10 pixels
   - **If ball height > tree height**: Ball can pass over (roof bounce)
   - **If ball height ≤ tree height**: Ball is reflected off the tree top

3. **Reflection Physics**:
   - Uses the same reflection algorithm as other tree collisions
   - Adds small random angle to prevent infinite loops
   - Notifies the ball of the bounce for sound effects

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