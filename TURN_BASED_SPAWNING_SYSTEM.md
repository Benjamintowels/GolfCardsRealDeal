# Turn-Based Spawning System

## Overview

The turn-based spawning system automatically increases the number of gang members and oil drums spawned on each hole based on the current turn count. This creates a progressive difficulty system where the game becomes more challenging as players progress through turns.

## How It Works

### Global Turn Counter
- A global turn counter (`Global.global_turn_count`) tracks turns across all holes
- This counter increments every time the player ends their turn
- The counter resets when starting a new round

### Spawning Milestones
The system uses 5-turn increments for spawning additional entities:

- **Turn 1-4**: Base spawns (1 gang member, 3 oil drums)
- **Turn 5-9**: +1 gang member, +1 oil drum (2 gang members, 4 oil drums)
- **Turn 10-14**: +2 gang members, +2 oil drums (3 gang members, 5 oil drums)
- **Turn 15-19**: +3 gang members, +3 oil drums (4 gang members, 6 oil drums)
- **Turn 20-24**: +4 gang members, +4 oil drums (5 gang members, 7 oil drums)
- **Turn 25+**: Maximum spawns (5 gang members, 8 oil drums)

### Implementation Details

#### Global.gd Functions
- `get_turn_based_gang_member_count()`: Calculates gang member spawn count
- `get_turn_based_oil_drum_count()`: Calculates oil drum spawn count
- `increment_global_turn()`: Increments the global turn counter
- `reset_global_turn()`: Resets the global turn counter

#### Build Map Integration
- `build_map.gd` now uses turn-based spawning by default
- Parameters `-1` for gang members and oil drums trigger turn-based calculation
- Spawn counts are logged for debugging

#### Course Integration
- `course_1.gd` increments global turn counter on end turn
- Global turn counter resets when starting new round
- HUD displays both local and global turn counts
- Game state saving/loading includes global turn counter

## Usage

### Automatic Operation
The system works automatically - no manual intervention required. As players progress through turns, they will notice:

1. More gang members on green tiles
2. More oil drums on fairway tiles
3. Increased challenge and strategic complexity

### Manual Testing
Use the test script `test_turn_based_spawning.gd` to verify the system:

- Press SPACE to increment turn counter
- Press R to reset turn counter
- Check console output for spawn counts

### Configuration
To modify the spawning behavior, adjust these values in `Global.gd`:

```gdscript
# In get_turn_based_gang_member_count()
var base_count = 1        # Starting gang member count
var turn_increment = 5    # Turns between increases
var max_count = 5         # Maximum gang members

# In get_turn_based_oil_drum_count()
var base_count = 3        # Starting oil drum count
var turn_increment = 5    # Turns between increases
var max_count = 8         # Maximum oil drums
```

## Benefits

1. **Progressive Difficulty**: Game becomes more challenging over time
2. **Strategic Depth**: More obstacles require better planning
3. **Replayability**: Different turn counts create varied experiences
4. **Balanced Scaling**: Reasonable caps prevent overwhelming difficulty

## Technical Notes

- The system is deterministic - same turn count always produces same spawn counts
- Spawn positions remain random within valid areas
- System integrates seamlessly with existing save/load functionality
- Performance impact is minimal - only affects initial map generation 