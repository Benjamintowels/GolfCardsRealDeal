# Structured Shop System

## Overview

The shop system has been redesigned to provide a more predictable and balanced shopping experience. Instead of random item generation, the shop now uses a structured approach with guaranteed slots for different item types.

## Shop Layout

The shop always has **4 slots** with the following structure:

1. **Slot 1: Guaranteed Club Card**
   - Always contains a random club card (Putter, Wood, Iron, Driver, etc.)
   - Ensures players always have access to basic golf equipment

2. **Slot 2: Guaranteed Equipment**
   - Always contains a random piece of equipment
   - Provides consistent access to buffs and special abilities

3. **Slot 3: Random Tiered Item**
   - Contains a random card or equipment based on current reward tier
   - Quality scales with game progress

4. **Slot 4: Random Tiered Item**
   - Contains a random card or equipment based on current reward tier
   - Quality scales with game progress

## Reward Tier System

The random slots (3 and 4) use the existing reward tier system that scales with turn count:

### Tier Progression
- **Turns 1-4**: Tier 1 (90% Tier 1, 10% Tier 2, 0% Tier 3)
- **Turns 5-9**: Tier 2 (80% Tier 1, 15% Tier 2, 5% Tier 3)
- **Turns 10-14**: Tier 3 (70% Tier 1, 20% Tier 2, 10% Tier 3)
- **Turns 15+**: Higher tiers with better probabilities

### Tier Probabilities
Each tier has different probability distributions for item quality:

- **Tier 1**: Basic items (common cards, basic equipment)
- **Tier 2**: Improved items (better cards, upgraded equipment)
- **Tier 3**: Premium items (rare cards, powerful equipment)

## Implementation Details

### Shop Generation Process
1. **Get Current Tier**: Uses `Global.get_current_reward_tier()`
2. **Generate Club Card**: Random selection from available club cards
3. **Generate Equipment**: Random selection from available equipment
4. **Generate Tiered Items**: Weighted random selection based on tier probabilities
5. **Display Items**: Always shows 4 slots (empty slots if items unavailable)

### Weighted Selection
The tiered items use a weighted selection system:
- Items are categorized by their `get_reward_tier()` value
- Probability weights are applied based on current game tier
- Higher tiers have better chances for premium items

### Empty Slot Handling
If any item type is unavailable, the corresponding slot shows as "Empty":
- Darker background
- "Empty" text label
- Non-clickable
- Maintains visual consistency

## Benefits

1. **Predictable Structure**: Players always know what to expect
2. **Balanced Progression**: Guaranteed access to basic items
3. **Scalable Quality**: Random items improve with game progress
4. **Consistent Experience**: No more shops with only cards or only equipment
5. **Strategic Planning**: Players can plan purchases based on guaranteed slots

## Testing

Use the test script `test_structured_shop_system.gd` to verify:
- Correct slot structure at different tiers
- Proper item type placement
- Tier probability scaling
- Empty slot handling

## Configuration

The system uses existing configuration:
- Club card list in `get_club_cards()`
- Equipment pool in `available_equipment`
- Card pool in `available_cards`
- Tier probabilities in `Global.get_tier_probabilities()`

## Future Enhancements

Potential improvements:
- Slot-specific item pools (e.g., only certain equipment in slot 2)
- Dynamic pricing based on tier
- Special event slots (holidays, achievements)
- Player preference learning 