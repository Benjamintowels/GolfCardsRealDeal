# AssassinDash Y-Sorting Fix

## Issue Description

When the AssassinDash card was used and the player was placed on a tile below an NPC, the player's Y-sort z_index was not being updated until their next turn when they moved. This caused the player to appear in front of the NPC visually, even though they were positioned behind them in the game world.

## Root Cause

The issue was in the `perform_assassin_dash_attack_on_npc()` function in `AttackHandler.gd`. When the player was moved to the behind-enemy position using `animate_to_position()`, the function did not call `update_z_index_for_ysort()` to update the player's z_index based on their new Y position.

Additionally, the `animate_to_position()` function in `Player.gd` was not updating Y-sorting during the movement animation, unlike other movement functions.

## Solution

### 1. Updated AttackHandler.gd

Added a call to `update_z_index_for_ysort()` in the AssassinDash attack callback:

```gdscript
# CRITICAL: Update player Y-sorting immediately after AssassinDash movement
if player_node and player_node.has_method("update_z_index_for_ysort"):
    player_node.update_z_index_for_ysort([], Vector2i.ZERO)
    print("✓ Updated player Y-sorting after AssassinDash movement to position:", behind_enemy_pos)
```

### 2. Updated Player.gd

Enhanced the `animate_to_position()` function to include Y-sorting updates during movement:

```gdscript
# Update Y-sorting during movement
movement_tween.tween_callback(update_z_index_for_ysort.bind([], Vector2i.ZERO))
```

### 3. Card Row Animation (Already Implemented)

The card row animation is already implemented in `AttackHandler.gd` in the `show_attack_highlights()` function:

```gdscript
# Animate CardRow down to get out of the way of range display
animate_card_row_down()
```

This ensures that when AssassinDash (or any attack card) is used, the card row animates down to get out of the way of the attack range display, providing a better user experience.

## Files Modified

1. **AttackHandler.gd** - Added Y-sorting update in AssassinDash attack callback
2. **Characters/Player.gd** - Added Y-sorting update to animate_to_position function

## Existing Features

The card row animation for attack cards (including AssassinDash) was already implemented in `AttackHandler.gd` and works correctly.

## Testing

A test script has been created at `test_assassin_dash_ysort.gd` to verify the fix.

### Test Scenario

1. Start a game with AssassinDash card in hand
2. Find an NPC on the map
3. Use AssassinDash to attack the NPC
4. Verify that the card row animates down to get out of the way of the attack range display
5. Verify that the player appears behind the NPC (lower z_index) immediately
6. The player should not appear in front of the NPC until their next turn

### Expected Behavior

- **Before fix**: Player would appear in front of NPC until next turn
- **After fix**: Player immediately appears behind NPC with correct z_index
- **Card row animation**: Card row animates down when AssassinDash is selected and animates back up when attack mode exits

## Impact

This fix ensures that:
- Visual depth perception is correct immediately after AssassinDash attacks
- Player positioning appears consistent with their actual game world position
- No visual glitches where the player appears to be floating in front of NPCs
- Consistent behavior with other movement and attack systems

## Related Systems

This fix also improves consistency with other attack cards that use `animate_to_position()`, such as PunchB attacks, ensuring they all properly update Y-sorting during movement animations. 