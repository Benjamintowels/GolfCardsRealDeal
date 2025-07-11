# NPC Ball Push System

## Overview

The NPC Ball Push System allows NPCs (GangMembers, Police, etc.) to push golf balls when they collide while the NPC is moving during their turn. This creates dynamic gameplay where NPCs can actively affect ball trajectories based on their movement direction.

## How It Works

### Core Concept

When an NPC is moving during their turn and collides with a golf ball:
1. The system detects the NPC's current movement direction
2. Applies a push force to the ball based on the NPC type
3. The ball's velocity is modified by adding the push force vector
4. **Special handling for landed balls**: If the ball is stationary, it gets "woken up" with a minimum velocity

### Ball State Handling

The system handles different ball states:

- **In Flight**: Ball is in the air (`z > 0.0` or `vz != 0.0`) - push force is added to existing velocity
- **Rolling**: Ball is rolling on ground (`is_rolling = true`) - push force is added to existing velocity  
- **Landed/Stationary**: Ball has stopped (`landed_flag = true` or `velocity.length() < 10.0`) - ball is "woken up" with minimum velocity

### Collision Prevention & Safety

**Infinite Recursion Prevention**:
- **Collision Cooldown**: 100ms cooldown between same NPC-ball collisions
- **Collision Tracking**: Maintains a dictionary of recent collisions to prevent duplicates
- **Automatic Cleanup**: Removes collision records older than 1 second

**Grenade Safety**:
- **Grenade Detection**: Automatically detects grenades using `is_grenade_weapon()` method
- **Delegated Handling**: Grenades use their own collision system instead of NPC push system
- **Double Protection**: Both main handler and moving NPC handler check for grenades

### Push Velocities by NPC Type

- **GangMembers**: 400 velocity (strongest push)
- **Police**: 250 velocity (medium push)
- **Other NPCs**: 300 velocity (default push)

### Movement Direction Detection

The system uses multiple methods to detect the NPC's movement direction:

1. **Active Movement Detection**: When an NPC is currently moving during their turn:
   - The system stores the `movement_start_position` when movement begins
   - Calculates direction as `(current_position - start_position).normalized()`
   - This ensures the push direction matches the actual movement direction

2. **Last Movement Direction**: When an NPC is not currently moving:
   - Uses the `last_movement_direction` property
   - This provides a fallback direction based on the most recent movement

3. **Facing Direction**: As a final fallback:
   - Uses the NPC's `facing_direction` property
   - This ensures there's always a direction available for pushing

## Implementation Details

### Core Methods

**`handle_npc_ball_collision(npc: Node, ball: Node) -> void`**
- Main entry point for NPC-ball collisions
- **Collision Prevention**: Uses a cooldown system to prevent infinite recursion
- **Grenade Handling**: Detects grenades and delegates to their own collision system
- Routes to appropriate collision handler based on NPC state

**`_handle_moving_npc_ball_collision(npc: Node, ball: Node) -> void`**
- Handles collisions when NPCs are actively moving during their turns
- **Safety Checks**: Prevents grenade pushing and validates movement direction
- Applies push forces based on NPC type and movement direction

### Entities.gd Changes

#### New Constants
```gdscript
const GANGMEMBER_PUSH_VELOCITY = 400.0  # Strong push for GangMembers
const POLICE_PUSH_VELOCITY = 250.0      # Medium push for Police
const DEFAULT_PUSH_VELOCITY = 300.0     # Default push for other NPCs
const PUSH_VELOCITY_MULTIPLIER = 1.5    # Multiplier when NPC is actively moving
```

#### New Methods

**`_is_npc_moving_during_turn(npc: Node) -> bool`**
- Checks if an NPC is currently moving during their turn
- Uses `is_currently_moving()` method or `is_moving` property

**`_get_npc_movement_direction(npc: Node) -> Vector2`**
- Retrieves the current movement direction as a Vector2
- Tries multiple methods: `get_movement_direction()`, `get_last_movement_direction()`, etc.

**`_get_npc_push_velocity(npc: Node) -> float`**
- Returns appropriate push velocity based on NPC type
- Checks NPC name and script path for type identification

**`_apply_ball_push_force(ball: Node, push_force: Vector2) -> void`**
- Applies push force to ball by adding to current velocity
- Supports both `set_velocity()` method and direct `velocity` property
- **Special handling for landed balls**: Wakes up stationary balls with minimum velocity

### NPC Class Changes

#### GangMember.gd and Police.gd

**New Methods Added:**
```gdscript
func get_movement_direction() -> Vector2:
    """Get the current movement direction as a Vector2"""
    # If currently moving, return direction to target
    # If not moving, return last movement direction

func get_last_movement_direction() -> Vector2i:
    """Get the last movement direction as Vector2i"""
    return last_movement_direction
```

**Modified Methods:**
- `_handle_ball_collision()` now uses Entities system for collision handling
- Falls back to original logic if Entities system unavailable

### Ball Class Changes

#### GolfBall.gd and GhostBall.gd

**New Helper Methods Added:**
```gdscript
func set_rolling_state(rolling: bool) -> void:
    """Set the rolling state of the ball (for NPC push system)"""
    # Enables/disables rolling state and resets collision delay

func set_landed_flag(landed: bool) -> void:
    """Set the landed flag of the ball (for NPC push system)"""
    # Resets landed state and bounce count when re-enabling flight

func is_in_flight() -> bool:
    """Check if the ball is currently in flight"""
    # Returns true if ball is not landed and has velocity or height
```

## Usage Examples

### Basic Collision Flow

1. **NPC Movement**: GangMember moves from position A to B during turn
2. **Ball Collision**: Golf ball collides with moving GangMember
3. **Direction Detection**: System detects GangMember moving right (1, 0)
4. **Push Calculation**: Push force = (1, 0) * 400 = (400, 0)
5. **Ball Update**: Ball velocity += (400, 0)

### Landed Ball Collision Flow

1. **Ball State**: Ball is stationary (landed_flag = true, velocity = 0)
2. **NPC Movement**: Police moves and collides with stationary ball
3. **State Detection**: System detects ball is landed/stationary
4. **Wake Up**: Ball is "woken up" with minimum velocity (100.0)
5. **Push Application**: Ball starts rolling with push force direction
6. **State Reset**: landed_flag = false, is_rolling = true

### Code Example

```gdscript
# In Entities.gd - automatic handling
func handle_npc_ball_collision(npc: Node, ball: Node) -> void:
    if _is_npc_moving_during_turn(npc):
        _handle_moving_npc_ball_collision(npc, ball)
    else:
        # Normal collision handling
        _apply_default_velocity_damage(npc, ball)
```

## Testing

### Test Script: test_npc_ball_push_system.gd

The test script provides:
- Movement detection testing
- Push velocity verification
- Turn state monitoring
- Debug output for collision events

### Test Instructions

1. Start NPC turns to see them move
2. Launch a ball to collide with moving NPCs
3. Observe how balls get pushed by NPC movement direction
4. Verify different push strengths (GangMember > Police)

## Configuration

### Adjusting Push Velocities

Modify the constants in `Entities.gd`:
```gdscript
const GANGMEMBER_PUSH_VELOCITY = 400.0  # Increase for stronger push
const POLICE_PUSH_VELOCITY = 250.0      # Decrease for weaker push
```

### Adding New NPC Types

1. Add new constant in `Entities.gd`:
```gdscript
const NEW_NPC_PUSH_VELOCITY = 350.0
```

2. Update `_get_npc_push_velocity()` method:
```gdscript
elif npc.name.contains("NewNPC") or npc.get_script().resource_path.contains("NewNPC"):
    return NEW_NPC_PUSH_VELOCITY
```

3. Add movement direction methods to new NPC class:
```gdscript
func get_movement_direction() -> Vector2:
    # Implementation for new NPC type

func get_last_movement_direction() -> Vector2i:
    return last_movement_direction
```

## Integration with Existing Systems

### Compatibility

- **Height Collision System**: Still works - push only applies when ball is at appropriate height
- **Freeze Effects**: Maintained - ice elements still apply freeze effects
- **Damage System**: Preserved - normal damage still applies when not moving
- **Reflection System**: Fallback - uses reflection when movement direction unavailable

### Performance Considerations

- Movement detection is lightweight (property checks)
- Push calculations are simple vector operations
- No additional physics calculations required
- Minimal impact on frame rate

## Future Enhancements

### Potential Improvements

1. **Variable Push Strength**: Based on NPC health, equipment, or status effects
2. **Directional Push Patterns**: Different push behaviors for different movement types
3. **Push Sound Effects**: Unique sounds for different NPC types
4. **Visual Feedback**: Particle effects or animations during push
5. **Push Resistance**: Some balls could resist pushes based on properties

### Advanced Features

1. **Momentum Transfer**: NPCs could lose speed when pushing heavy balls
2. **Chain Reactions**: Multiple NPCs could push the same ball in sequence
3. **Push Combos**: Special effects when multiple NPCs push simultaneously
4. **Environmental Factors**: Terrain could affect push effectiveness

## Troubleshooting

### Common Issues

**Ball not being pushed:**
- Check if NPC is actually moving (`is_moving` property)
- Verify NPC has movement direction methods
- Ensure Entities system is properly connected

**Incorrect push direction:**
- Verify `get_movement_direction()` returns correct Vector2
- Check that `last_movement_direction` is being updated
- Ensure facing direction is properly set

**Wrong push velocity:**
- Confirm NPC type detection in `_get_npc_push_velocity()`
- Check that constants are properly defined
- Verify NPC name/script path matching

### Debug Output

Enable debug prints by checking the console for:
- "=== MOVING NPC BALL COLLISION ==="
- Movement direction and push velocity values
- Ball velocity before and after push
- NPC type detection results 