# Together Mode - WorldTurnManager

## Overview

Together Mode is a toggleable modifier for the WorldTurnManager that allows all NPCs to execute their AI simultaneously in a cascade based on priority. This makes the world turn happen much faster and creates a more dynamic, chaotic gameplay experience.

## Features

### Cascade Execution
- All NPCs execute their turns simultaneously within their priority group
- Higher priority NPCs (Squirrels, Zombies) activate first
- Lower priority NPCs (Police, Gang Members) activate after a small delay
- Creates a visual cascade effect as NPCs move in waves

### Priority System
The cascade follows the established priority system:
1. **Priority 4 (Squirrels)** - Fastest, ball chasers
2. **Priority 3 (ZombieGolfers)** - Fast, aggressive
3. **Priority 2 (GangMembers)** - Medium, patrol/chase
4. **Priority 1 (Police)** - Slow, defensive

### Configurable Parameters
- **Turn Duration**: Total time for the together mode turn (default: 3.0 seconds)
- **Cascade Delay**: Delay between priority groups (default: 0.1 seconds)

## Usage

### Basic Toggle
```gdscript
# Toggle together mode on/off
world_turn_manager.toggle_together_mode()

# Set together mode to specific state
world_turn_manager.set_together_mode(true)  # Enable
world_turn_manager.set_together_mode(false) # Disable

# Check if together mode is enabled
var is_enabled = world_turn_manager.is_together_mode_enabled()
```

### Configuration
```gdscript
# Set turn duration (in seconds)
world_turn_manager.set_together_mode_duration(5.0)

# Set cascade delay between priority groups (in seconds)
world_turn_manager.set_together_mode_cascade_delay(0.2)
```

### Debug Methods
```gdscript
# Show together mode status
world_turn_manager.debug_together_mode_status()

# Show how NPCs are grouped by priority
world_turn_manager.debug_priority_groups()

# Get turn progress including together mode info
var progress = world_turn_manager.get_turn_progress()
print("Together mode: ", progress.together_mode)
print("Duration: ", progress.together_duration)
print("Cascade delay: ", progress.together_cascade_delay)
```

## Testing

### Test Scene
Use the `test_together_mode.tscn` scene to test the together mode functionality:

1. **UI Controls**:
   - Toggle Together Mode button
   - Start World Turn button
   - Force Complete Turn button
   - Duration and cascade delay sliders
   - Debug buttons

2. **Keyboard Shortcuts**:
   - `T` - Toggle together mode
   - `Space` - Start world turn
   - `Escape` - Force complete turn
   - `D` - Debug status
   - `P` - Debug priority groups

### Integration with Course1
The together mode integrates seamlessly with the existing Course1 scene:

1. **Automatic Detection**: The WorldTurnManager automatically detects when together mode is enabled
2. **Message Display**: Shows "World Turn - Together!" instead of "World Turn"
3. **Camera Handling**: Maintains the same camera transition logic
4. **Turn Flow**: Preserves the normal turn flow after completion

## Technical Details

### Execution Flow
1. **Priority Grouping**: NPCs are grouped by their priority level
2. **Cascade Activation**: Each priority group activates simultaneously
3. **Async Execution**: NPC turns execute asynchronously within their group
4. **Completion Tracking**: System waits for all NPCs to complete their turns
5. **Duration Control**: Total turn duration is controlled by the configured parameter

### Performance Considerations
- **Async Processing**: NPC turns run concurrently to maintain performance
- **Task Management**: Uses a task-based system to track completion
- **Memory Management**: Automatic cleanup of completed tasks
- **Error Handling**: Graceful handling of invalid NPCs

### Compatibility
- **Backward Compatible**: Existing sequential turn system remains unchanged when together mode is disabled
- **NPC Compatibility**: All existing NPC types work with together mode
- **Signal Compatibility**: All existing signals are preserved and emitted correctly

## Example Scenarios

### Fast-Paced Combat
Enable together mode for intense, chaotic battles where multiple NPCs react simultaneously to the player's actions.

### Quick Exploration
Use together mode to speed up NPC movement during exploration phases, allowing faster progression through the course.

### Dynamic Events
Create dynamic events where NPCs coordinate their actions in a cascade, creating emergent gameplay situations.

## Troubleshooting

### Common Issues
1. **NPCs Not Moving**: Check if together mode is enabled and NPCs are properly registered
2. **Performance Issues**: Reduce turn duration or cascade delay if too many NPCs are active
3. **Camera Issues**: Ensure camera reference is properly set in the WorldTurnManager

### Debug Steps
1. Use `debug_together_mode_status()` to check configuration
2. Use `debug_priority_groups()` to verify NPC grouping
3. Check console output for detailed execution logs
4. Use the test scene to isolate issues

## Future Enhancements

### Potential Features
- **Selective Together Mode**: Enable for specific NPC types only
- **Dynamic Priority**: Adjust priorities based on game state
- **Visual Effects**: Add particle effects or animations for cascade execution
- **Sound Integration**: Coordinated sound effects for together mode
- **AI Coordination**: NPCs that work together in together mode

### Configuration Options
- **Per-NPC Settings**: Individual NPC together mode preferences
- **Conditional Activation**: Enable based on game conditions
- **Progressive Cascade**: Gradually increase cascade speed over time 