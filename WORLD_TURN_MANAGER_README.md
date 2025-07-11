# WorldTurnManager System

## Overview

The WorldTurnManager is a centralized NPC turn management system that handles all NPC turns with consistent logic and proper sequencing. It replaces the scattered turn management that was previously handled in `course_1.gd` and `Entities.gd`.

## Key Features

### 1. Centralized Turn Management
- All NPC turns are managed from a single location
- Consistent logic for turn validation and sequencing
- Proper signal handling and state management

### 2. Priority-Based Turn Order
NPCs are processed in priority order (higher number = higher priority):
- **Squirrel (Priority 4)**: Fastest - ball chasers
- **ZombieGolfer (Priority 3)**: Fast - aggressive
- **GangMember (Priority 2)**: Medium - patrol/chase
- **Police (Priority 1)**: Slow - defensive
- **Default (Priority 0)**: Unknown NPCs

### 3. Smart Turn Validation
- Checks if NPCs are alive
- Handles frozen NPCs (skips if won't thaw this turn)
- Special handling for ball-detecting NPCs (like Squirrels)
- Vision-based validation for other NPCs

### 4. Camera Management
- Automatic camera transitions to NPCs during their turns
- Smooth camera return to player after world turn completion
- Fallback camera handling if course methods aren't available

### 5. Performance Optimization
- NPC priority caching for better performance
- Periodic cleanup of invalid NPCs
- Memory leak prevention

## Integration

### Course Integration

The WorldTurnManager integrates with `course_1.gd` through:

1. **Signal Connection**: The course emits `player_turn_ended` signal when the player ends their turn
2. **Method Calls**: The WorldTurnManager calls course methods for camera transitions and turn continuation
3. **Reference Management**: The WorldTurnManager finds and maintains references to course components

### NPC Integration

NPCs register with the WorldTurnManager by:

1. **Registration**: Calling `register_npc(npc)` during their `_ready()` function
2. **Signal Connection**: Connecting to `npc_turn_started` and `npc_turn_ended` signals
3. **Turn Completion**: Emitting `turn_completed` signal when their turn is done

## Usage

### Basic Setup

1. **Add WorldTurnManager to Scene**: Place the WorldTurnManager node under the NPC folder
2. **Connect Course Signals**: The course should emit `player_turn_ended` when the player ends their turn
3. **Register NPCs**: NPCs should register themselves during their `_ready()` function

### Example NPC Registration

```gdscript
# In NPC _ready() function
course = _find_course_script()
if course and course.has_node("NPC/WorldTurnManager"):
    entities_manager = course.get_node("NPC/WorldTurnManager")
    entities_manager.register_npc(self)
    entities_manager.npc_turn_started.connect(_on_turn_started)
    entities_manager.npc_turn_ended.connect(_on_turn_ended)
```

### Example Course Integration

```gdscript
# In course_1.gd
signal player_turn_ended

func _end_turn_logic():
    # ... existing turn end logic ...
    
    # Emit signal to start world turn
    player_turn_ended.emit()

func _continue_after_world_turn():
    # Continue with player's turn after world turn completion
    # ... turn continuation logic ...
```

## Signals

### WorldTurnManager Signals

- `world_turn_started`: Emitted when world turn sequence begins
- `world_turn_ended`: Emitted when world turn sequence completes
- `npc_turn_started(npc)`: Emitted when an NPC's turn begins
- `npc_turn_ended(npc)`: Emitted when an NPC's turn ends
- `all_npcs_turn_completed`: Emitted when all NPCs have finished their turns

### Required NPC Signals

- `turn_completed`: NPCs must emit this signal when their turn is complete

## Methods

### Public Methods

- `register_npc(npc)`: Register an NPC for turn management
- `unregister_npc(npc)`: Unregister an NPC from turn management
- `start_world_turn()`: Start the world turn sequence
- `is_world_turn_in_progress()`: Check if a world turn is currently active
- `get_current_npc()`: Get the NPC currently taking their turn
- `get_turn_progress()`: Get detailed information about turn progress
- `force_complete_world_turn()`: Force complete the current world turn (debugging)

### Internal Methods

- `_get_active_npcs_for_turn()`: Get all NPCs that should take a turn
- `_should_npc_take_turn(npc)`: Check if an NPC should take a turn
- `_process_next_npc_turn()`: Process the next NPC's turn in sequence
- `_complete_world_turn()`: Complete the world turn sequence

## Configuration

### Constants

- `MAX_VISION_RANGE`: Maximum tiles for player vision (default: 20)
- `MIN_TURN_INTERVAL`: Minimum time between NPC turns (default: 0.5s)
- `CAMERA_TRANSITION_DURATION`: Time for camera transitions (default: 0.5s)
- `TURN_CLEANUP_INTERVAL`: How often to clean up old data (default: 5.0s)

### NPC Priorities

```gdscript
const NPC_PRIORITIES = {
    "Squirrel": 4,      # Fastest - ball chasers
    "ZombieGolfer": 3,  # Fast - aggressive
    "GangMember": 2,    # Medium - patrol/chase
    "Police": 1,        # Slow - defensive
    "default": 0        # Unknown NPCs
}
```

## Troubleshooting

### Common Issues

1. **NPCs Not Taking Turns**: Check if NPCs are properly registered and have valid `turn_completed` signals
2. **Camera Not Transitioning**: Ensure course has `transition_camera_to_npc()` and `transition_camera_to_player()` methods
3. **Turn Sequence Stuck**: Use `force_complete_world_turn()` for debugging
4. **Performance Issues**: Check NPC priority cache and cleanup intervals

### Debug Information

The WorldTurnManager provides extensive debug output:
- Turn sequence progress
- NPC registration status
- Turn validation results
- Camera transition status

### Testing

Use the `test_world_turn_manager.gd` script to test the WorldTurnManager functionality:
- Simulates player turn end
- Displays turn progress
- Shows registered NPCs
- Tests signal connections

## Migration from Old System

### Changes Required

1. **NPC Scripts**: Update registration to use WorldTurnManager instead of Entities
2. **Course Script**: Add `player_turn_ended` signal and `_continue_after_world_turn()` method
3. **Scene Structure**: Ensure WorldTurnManager is placed under NPC folder

### Benefits

- **Consistency**: All NPCs use the same turn logic
- **Maintainability**: Centralized turn management
- **Performance**: Optimized with caching and cleanup
- **Debugging**: Better error handling and debug output
- **Extensibility**: Easy to add new NPC types and behaviors

## Future Enhancements

- **Turn Interruption**: Allow NPCs to interrupt other NPCs' turns
- **Turn Conditions**: More sophisticated turn validation rules
- **Turn Effects**: Global effects that apply during world turns
- **Turn History**: Track and replay turn sequences
- **Turn Optimization**: Parallel processing for independent NPCs 