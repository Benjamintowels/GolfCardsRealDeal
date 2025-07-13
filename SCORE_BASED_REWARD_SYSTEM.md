# Score-Based Reward System

## Overview

The score-based reward system enhances the existing tiered reward system by adjusting reward probabilities based on the player's performance on each hole. Better scores (relative to par) result in higher chances of receiving higher-tier rewards.

## How It Works

### Score vs Par Calculation

The system calculates the player's score relative to par for each hole:
- **Score vs Par = Hole Score - Hole Par**

### Reward Tier Adjustments

Based on the score vs par, the system modifies the base tier probabilities:

#### Excellent Performance (Under Par)
- **Double Eagle (-3)**: -30% Tier 1, +15% Tier 2, +15% Tier 3
- **Eagle (-2)**: -25% Tier 1, +15% Tier 2, +10% Tier 3
- **Birdie (-1)**: -15% Tier 1, +10% Tier 2, +5% Tier 3

#### Standard Performance
- **Par (0)**: No modification - uses base tier probabilities

#### Below Average Performance (Over Par)
- **Bogey (+1)**: +5% Tier 1, -5% Tier 2, no change to Tier 3
- **Double Bogey (+2)**: +10% Tier 1, -10% Tier 2, no change to Tier 3
- **Triple Bogey or worse (+3+)**: +15% Tier 1, -15% Tier 2, no change to Tier 3

### Example Probabilities

#### Base Tier 1 Probabilities (70% Tier 1, 20% Tier 2, 10% Tier 3)

**Eagle (-2) Performance:**
- Tier 1: 45% (70% - 25%)
- Tier 2: 35% (20% + 15%)
- Tier 3: 20% (10% + 10%)

**Par (0) Performance:**
- Tier 1: 70% (no change)
- Tier 2: 20% (no change)
- Tier 3: 10% (no change)

**Double Bogey (+2) Performance:**
- Tier 1: 80% (70% + 10%)
- Tier 2: 10% (20% - 10%)
- Tier 3: 10% (no change)

## Implementation

### Global.gd Functions

- `get_score_based_tier_probabilities(hole_score, hole_par)`: Returns adjusted tier probabilities based on score performance

### RewardSelectionDialog.gd Changes

- Added `show_score_based_reward_selection(score, par)` function
- Modified all tiered reward functions to use score-based probabilities when available
- Added score tracking variables: `hole_score`, `hole_par`, `use_score_based_rewards`

### Course Integration

- `course_1.gd` now passes hole score and par information to reward dialogs
- Both hole completion rewards and SuitCase rewards use score-based probabilities

## Usage

### Automatic Operation

The system works automatically when:
1. Player completes a hole (hole completion rewards)
2. Player opens a SuitCase (SuitCase rewards)

### Manual Testing

Use the test scene `test_score_based_rewards.tscn` to verify the system:
1. Run the test scene
2. Check console output for probability calculations
3. Verify reward tier distributions

## Benefits

1. **Skill Rewards**: Better players receive better rewards
2. **Motivation**: Encourages players to improve their performance
3. **Progression**: Creates a natural difficulty curve where skilled play is rewarded
4. **Balance**: Maintains base probabilities for average performance
5. **Transparency**: Clear relationship between performance and reward quality

## Technical Details

### Probability Normalization

The system ensures probabilities always sum to 1.0:
1. Apply score-based modifiers to base probabilities
2. Clamp values between 0.0 and 1.0
3. Normalize to ensure total equals 1.0

### Fallback System

If score information is not available, the system falls back to base tier probabilities from `Global.get_tier_probabilities()`.

### Debug Information

The system prints detailed information to the console when score-based rewards are used:
```
=== SCORE-BASED REWARDS ===
Hole Score: 2 Par: 3 Score vs Par: -1
Tier Probabilities: {"tier_1": 0.55, "tier_2": 0.30, "tier_3": 0.15}
=== END SCORE-BASED REWARDS ===
```

## Future Enhancements

Potential improvements to consider:
1. **Streak Bonuses**: Additional rewards for multiple good holes in a row
2. **Course Difficulty**: Adjust probabilities based on hole difficulty
3. **Character Bonuses**: Different reward curves for different characters
4. **Visual Indicators**: Show reward tier probabilities in the UI
5. **Achievement System**: Track and reward exceptional performances 