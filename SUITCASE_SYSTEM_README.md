# SuitCase System

## Overview

The SuitCase system places a SuitCase on the map every 6 holes (holes 6, 12, 18, etc.) that provides unique reward selection opportunities. When the player reaches the SuitCase tile, they can choose from 3 rewards, and gameplay resumes without transitioning to the next hole.

## How It Works

### Placement Logic

- **Frequency**: Every 6 holes (holes 6, 12, 18, etc.)
- **Location**: Randomly placed on fairway tiles ("F")
- **Spacing**: Minimum 4 tiles away from other placed objects
- **Detection**: Uses the same placement validation as other map objects

### Detection System

- **Player Movement**: Detected when player moves to the SuitCase grid position
- **Signal System**: MapSuitCase emits `suitcase_reached` signal
- **One-time Activation**: SuitCase disappears after activation to prevent multiple triggers

### Reward Selection

- **Dialog**: Uses the existing RewardSelectionDialog system
- **No Advance Button**: Removes the "Advance to Next Hole" button for SuitCase rewards
- **Resume Gameplay**: After reward selection, gameplay continues on the same hole
- **Same Rewards**: Uses the same 3-slot reward system (club card, equipment, action card/$Looty)

## Implementation Details

### Key Files

- `MapSuitCase.gd` - SuitCase placed on the map with collision detection
- `MapSuitCase.tscn` - Scene file for map SuitCase
- `golfcards/build_map.gd` - Placement logic and position tracking
- `course_1.gd` - Player detection and reward handling

### Placement Functions

```gdscript
func should_place_suitcase() -> bool:
    # Place SuitCase on holes 6, 12, 18, etc. (every 6th hole)
    return (current_hole + 1) % 6 == 0

func get_valid_fairway_positions(layout: Array) -> Array:
    # Get all valid fairway positions for SuitCase placement
    # Checks spacing from other placed objects
```

### Detection Functions

```gdscript
func _on_suitcase_reached():
    # Handle when the player reaches a SuitCase
    # Clear position, exit movement mode, show reward selection

func show_suitcase_reward_selection():
    # Show reward selection dialog for SuitCase
    # Removes advance button for SuitCase rewards
```

## Integration Points

### Build Map System

- Added to `get_random_positions_for_objects()` function
- Tracks SuitCase position in `suitcase_grid_pos` variable
- Connects to course signal handling

### Course System

- Added SuitCase position tracking variables
- Integrated with player movement detection
- Handles reward selection and cleanup

### UI System

- Uses existing RewardSelectionDialog
- Custom handling to remove advance button
- Proper cleanup on hole transitions

## Testing

Use the test scene `test_suitcase_system.tscn` to verify:

1. **Placement Logic**: Press 1 to test which holes should have SuitCases
2. **Detection Logic**: Press 2 to test player position detection
3. **Fairway Positions**: Press 3 to test fairway position generation

## Expected Behavior

### Hole 6 (Front 9)
- SuitCase appears on fairway
- Player can reach it during gameplay
- Reward selection appears when reached
- Gameplay resumes after reward selection

### Hole 12 (Back 9)
- Same behavior as hole 6
- Continues the 6-hole pattern

### Other Holes
- No SuitCase placement
- Normal gameplay continues

## Future Enhancements

- **Visual Effects**: Add sparkles or glow to SuitCase
- **Sound Effects**: Add discovery sound when reached
- **Animation**: Add opening animation when activated
- **Variety**: Different SuitCase types with different reward pools
- **Persistence**: Save SuitCase state across game sessions 