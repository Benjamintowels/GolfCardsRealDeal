# Player Ragdoll System

## Overview

The player ragdoll system allows the player to be affected by explosions with realistic ragdoll animation, similar to how GangMembers are affected. When the player is within an explosion radius and survives the damage, they will be pushed back and perform a ragdoll animation.

## Features

### Explosion Integration
- **Automatic Detection**: Player is automatically detected within explosion radius
- **Distance-based Damage**: Closer to explosion = more damage
- **Survival Check**: Only players who survive the explosion get ragdoll animation
- **Pushback Distance**: Player is pushed back 2 tiles minimum when they survive
- **Reduced Force**: Players use reduced ragdoll force (100 pixels vs 300 for GangMembers) for grid-appropriate movement

### Ragdoll Animation
- **Duration**: 1.5 seconds (configurable)
- **Animation Phases**:
  1. **Launch Phase** (40% of duration): Player launches upward and backward
  2. **Tilt Phase**: Player tilts backward 30 degrees during launch
  3. **Fall Phase** (60% of duration): Player falls back to landing position
  4. **Recovery Phase**: Player returns to normal rotation and position

### Safety Features
- **Launch Distance Limits**: Maximum launch distance of 2 tiles to prevent extreme positions
- **Screen Bounds**: Player cannot be launched outside screen bounds (100 pixel margin)
- **Pushback Limits**: Maximum pushback distance of 4 tiles from current position
- **Position Validation**: Landing position is validated against obstacles and other entities

### Grid Integration
- **Grid-based Landing**: Player always lands on valid grid positions
- **Position Updates**: Automatically updates course and attack handler with new position
- **Signal Emission**: Emits `moved_to_tile` signal when ragdoll completes
- **Y-sort Updates**: Maintains proper Y-sorting during and after ragdoll

## Technical Details

### Force Calculation
```gdscript
# Explosion force for players (reduced from GangMember force)
var ragdoll_force = 100.0 * force_factor  # Base force of 100 pixels

# Launch distance calculation
var launch_distance = force * 0.3  # 30% of force for reasonable launch
var max_launch_distance = cell_size * 2  # Maximum 2 tiles
```

### Landing Position Calculation
```gdscript
# Distance calculation
var distance = force * 0.4  # 40% of force for landing position

# Minimum pushback enforcement
if pushback_distance < 2:
    # Force 2-tile minimum pushback

# Maximum pushback limit
var max_pushback_distance = 4  # Maximum 4 tiles
```

### Safety Checks
- **Screen bounds validation**: Prevents off-screen positions
- **Obstacle collision detection**: Avoids landing on blocked tiles
- **Entity collision detection**: Avoids landing on occupied tiles
- **Fallback positions**: Uses current position if no valid landing found

## Usage

### Automatic Triggering
The ragdoll system is automatically triggered when:
1. Player is within explosion radius
2. Player survives the explosion damage
3. Explosion system calls `_start_player_ragdoll()`

### Manual Control
```gdscript
# Start ragdoll animation manually
player.start_ragdoll_animation(direction, force)

# Check ragdoll state
if player.is_currently_ragdolling():
    # Player is currently ragdolling

# Stop ragdoll animation
player.stop_ragdoll()
```

## Integration Points

### Course System
- Updates `course.player_grid_pos` when ragdoll completes
- Calls `course.update_player_position()` for position synchronization
- Emits `moved_to_tile` signal for course event handling

### Attack Handler
- Updates attack handler's player position reference
- Ensures attack calculations use correct player position

### Camera System
- Maintains camera tracking during ragdoll animation
- Smooth camera transitions after ragdoll completion

## Debug Information

The system provides extensive debug output including:
- Force calculations and factors
- Launch and landing positions
- Grid position updates
- Safety check results
- Animation phase transitions

## Performance Considerations

- **Tween-based Animation**: Uses Godot's tween system for smooth performance
- **Minimal Updates**: Only updates Y-sorting when necessary
- **Efficient Validation**: Quick bounds and collision checks
- **Memory Management**: Proper cleanup of animation tweens

## Implementation Details

### Explosion System (`Particles/Explosion.gd`)
- Added player detection in `_apply_explosion_radius_effects()`
- New methods:
  - `_find_player()`: Finds player in scene using multiple methods
  - `_affect_player_with_explosion()`: Applies damage and schedules ragdoll
  - `_start_player_ragdoll()`: Initiates ragdoll animation

### Player System (`Characters/Player.gd`)
- Added ragdoll state tracking (`is_ragdolling`)
- Added ragdoll animation properties
- New methods:
  - `start_ragdoll_animation()`: Main ragdoll entry point
  - `_calculate_ragdoll_landing_position()`: Calculates final landing position with 2-tile minimum
  - `_validate_landing_position()`: Ensures landing position is valid
  - `_start_ragdoll_sequence()`: Handles the complete animation sequence
  - `_on_ragdoll_complete()`: Called when ragdoll animation finishes
  - `stop_ragdoll()`: Emergency stop for ragdoll animation
  - `is_currently_ragdolling()`: Check ragdoll state

### Position Updates
When ragdoll animation completes:
- Updates player's grid position to landing position
- Updates course's player position references
- Updates attack handler's player position
- Emits `moved_to_tile` signal to notify the course
- Updates Y-sorting for new position

## Usage

### Automatic Usage
The player ragdoll system works automatically with existing explosions:
- **Oil Drum Explosions**: When oil drums explode from fire element balls
- **Manual Explosions**: Any explosion created with `Explosion.create_explosion_at_position()`

### Testing
Use the test scene `test_explosion_radius.tscn` to test the system:
1. Load the test scene
2. GangMembers and player will be created automatically
3. Press SPACE to trigger an explosion
4. Observe which entities ragdoll and which are unaffected

### Configuration
Modify these constants in `Particles/Explosion.gd`:
```gdscript
const EXPLOSION_RADIUS: float = 150.0  # Radius in pixels
const EXPLOSION_DAMAGE: int = 50       # Base damage
const RAGDOLL_DELAY: float = 0.1       # Delay before ragdoll starts
```

Modify these constants in `Characters/Player.gd`:
```gdscript
var ragdoll_duration: float = 1.5  # Duration of ragdoll animation
```

## Technical Notes

### Performance
- Player detection uses efficient scene tree traversal
- Ragdoll animations use Godot's Tween system for smooth performance
- Position validation is optimized to avoid unnecessary checks

### Compatibility
- Works with existing player systems
- Compatible with course position management
- Integrates with existing collision and health systems
- Preserves all existing player functionality

### Debugging
The system includes extensive debug output:
- Explosion radius detection logs
- Player distance calculations
- Ragdoll animation progress
- Position validation details
- Damage application details

## Future Enhancements

Potential improvements for the system:
- **Variable Explosion Types**: Different explosion types with different pushback distances
- **Environmental Effects**: Explosions could affect terrain or other objects
- **Sound Effects**: Different sounds for different explosion distances
- **Particle Effects**: Additional visual effects during ragdoll animation
- **Physics Integration**: More realistic physics-based ragdoll behavior
- **Animation Variations**: Different ragdoll animations based on explosion type or player state 