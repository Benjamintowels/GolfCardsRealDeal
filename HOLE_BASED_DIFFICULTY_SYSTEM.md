# Hole-Based Difficulty System

## Overview

The hole-based difficulty system creates a more structured and predictable difficulty progression by assigning base difficulty levels to each hole, which are then amplified by the global difficulty tier system.

## How It Works

### Base Difficulty Per Hole

Each hole has a predefined base difficulty that determines the minimum number of NPCs that will spawn:

#### Front 9 Holes (1-9)
- **Hole 1**: Just squirrels (5 squirrels)
- **Hole 2**: 2 zombies + squirrels (5 squirrels, 2 zombies)
- **Hole 3**: Lots of zombies + squirrels (5 squirrels, 4 zombies)
- **Hole 4**: Lots of zombies + 1 gang member + squirrels (5 squirrels, 4 zombies, 1 gang member)
- **Hole 5**: 3 gang members + squirrels (5 squirrels, 3 gang members)
- **Hole 6**: 1 police + 1 gang member + squirrels (5 squirrels, 1 gang member, 1 police)
- **Hole 7**: 2 police + 2 gang members + squirrels (5 squirrels, 2 gang members, 2 police)
- **Hole 8**: 2 police + 2 gang members + lots of zombies + squirrels (5 squirrels, 4 zombies, 2 gang members, 2 police)
- **Hole 9**: 3 police + 3 gang members + lots of zombies + squirrels (5 squirrels, 4 zombies, 3 gang members, 3 police)

#### Back 9 Holes (10-18)
The back 9 uses the same pattern as the front 9 but with increased base difficulty:
- Each hole gets +2 more squirrels
- Each hole gets +1 more zombie
- Each hole gets +1 more gang member
- Each hole gets +1 more police

### Tier Amplification

The global difficulty tier system amplifies the base difficulty every 5 turns:

- **Tier 0** (Turns 1-5): No amplification (base counts only)
- **Tier 1** (Turns 6-10): +1 squirrel, +0 zombies, +0 gang members, +0 police
- **Tier 2** (Turns 11-15): +2 squirrels, +1 zombie, +0 gang members, +0 police
- **Tier 3** (Turns 16-20): +3 squirrels, +1 zombie, +1 gang member, +0 police
- **Tier 4** (Turns 21-25): +4 squirrels, +2 zombies, +1 gang member, +1 police
- **Tier 5** (Turns 26-30): +5 squirrels, +2 zombies, +1 gang member, +1 police
- And so on...

### Amplification Formula

```gdscript
# Every tier adds:
additional_squirrels = tier
additional_zombies = tier / 2      # Every 2 tiers
additional_gang_members = tier / 3 # Every 3 tiers  
additional_police = tier / 4       # Every 4 tiers
```

## Example Progression

### Hole 1 at Different Tiers
- **Tier 0**: 5 squirrels, 0 zombies, 0 gang members, 0 police
- **Tier 1**: 6 squirrels, 0 zombies, 0 gang members, 0 police
- **Tier 2**: 7 squirrels, 1 zombie, 0 gang members, 0 police
- **Tier 3**: 8 squirrels, 1 zombie, 1 gang member, 0 police
- **Tier 4**: 9 squirrels, 2 zombies, 1 gang member, 1 police

### Hole 5 at Different Tiers
- **Tier 0**: 5 squirrels, 0 zombies, 3 gang members, 0 police
- **Tier 1**: 6 squirrels, 0 zombies, 3 gang members, 0 police
- **Tier 2**: 7 squirrels, 1 zombie, 3 gang members, 0 police
- **Tier 3**: 8 squirrels, 1 zombie, 4 gang members, 0 police
- **Tier 4**: 9 squirrels, 2 zombies, 4 gang members, 1 police

### Back 9 Comparison
- **Hole 10** (Tier 0): 7 squirrels, 1 zombie, 1 gang member, 1 police
- **Hole 19** (Tier 0): 7 squirrels, 1 zombie, 1 gang member, 1 police

## Benefits

1. **Predictable Progression**: Players know what to expect on each hole
2. **Balanced Difficulty**: Each hole has appropriate challenge for its position
3. **Scalable System**: Tier amplification ensures long-term challenge
4. **Back 9 Challenge**: Back 9 holes are naturally harder than front 9
5. **Strategic Planning**: Players can plan their approach based on known enemy types

## Implementation Details

### Key Functions

- `get_hole_base_npc_counts(hole_index)`: Returns base NPC counts for a specific hole
- `amplify_npc_counts_by_tier(base_counts, tier)`: Applies tier amplification to base counts
- `get_difficulty_tier_npc_counts(hole_index)`: Main function that combines base + amplification

### Integration

The system integrates seamlessly with the existing:
- Map building system (`build_map.gd`)
- Turn-based progression
- Save/load functionality
- Performance optimization

## Testing

Use the test scene `test_hole_based_difficulty.tscn` to verify:
- Base difficulty per hole
- Tier amplification effects
- Front 9 vs back 9 differences
- Overall system balance

## Configuration

To modify the system, adjust these values in `Global.gd`:
- Base NPC counts in `get_hole_base_npc_counts()`
- Amplification rates in `amplify_npc_counts_by_tier()`
- Back 9 difficulty multipliers

## Future Enhancements

Potential improvements:
- Hole-specific enemy types (e.g., hole 5 always has gang members)
- Dynamic difficulty based on player performance
- Special events on certain holes
- Weather effects that modify difficulty 