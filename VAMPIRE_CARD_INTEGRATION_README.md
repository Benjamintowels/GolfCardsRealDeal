# Vampire Card Integration

## Overview

The Vampire card has been successfully integrated into all major game systems:
- ✅ **Rewards System** - Available as a reward after completing holes
- ✅ **Shop System** - Available for purchase in the shop
- ✅ **Starter Deck** - Included in the initial deck for testing
- ✅ **Card Effect System** - Properly handled by CardEffectHandler

## Card Details

### Vampire Card Configuration
- **Name**: Vampire
- **Effect Type**: Vampire
- **Effect Strength**: 1
- **Level**: 1 (can be upgraded to Level 2)
- **Max Level**: 2
- **Upgrade Cost**: 100 coins
- **Price**: 150 coins (Tier 2 pricing)
- **Default Tier**: 2 (Medium-tier card)
- **Image**: `res://Cards/Vampire.png`

### Effect Details
When the Vampire card is played:
1. **Sound Effect**: Plays `res://Sounds/Vampire.mp3`
2. **Visual Effect**: Player sprite animates to dark red hue over 0.5 seconds
3. **Healing Effect**: Player heals for any damage they would take from attacks
4. **Duration**: Lasts until the player's next turn starts

## Integration Details

### 1. Rewards System

**File**: `RewardSelectionDialog.gd`
**Location**: Line 58 in `base_cards` array

```gdscript
preload("res://Cards/Vampire.tres"),
```

The Vampire card is included in the rewards system and will appear as a random reward option after completing holes.

### 2. Shop System

**File**: `Shop/ShopInterior.gd`
**Location**: Line 144 in `available_cards` array

```gdscript
preload("res://Cards/Vampire.tres"),
```

The Vampire card has been added to the shop's available cards and will randomly appear in shop inventories.

### 3. Starter Deck

**File**: `current_deck_manager.gd`
**Location**: Line 25 in `starter_deck` array

```gdscript
preload("res://Cards/Vampire.tres"),        # Vampire card (for testing)
```

The Vampire card has been added to the starter deck for immediate testing.

### 4. Card Effect Handler

**File**: `CardEffectHandler.gd`
**Location**: Line 58 in `handle_card_effect()` function

```gdscript
elif card.effect_type == "Vampire":
    handle_vampire_effect(card)
    return true
```

The Vampire effect type is properly handled by the CardEffectHandler.

## How Vampire Mode Works

### Activation
1. **Card Played**: Player uses Vampire card from hand or bag
2. **Sound Effect**: Plays `res://Sounds/Vampire.mp3`
3. **Visual Effect**: Player sprite animates to dark red hue (`Color(1.0, 0.2, 0.2, 1.0)`)
4. **Mode Activation**: `course.activate_vampire_mode()` is called

### Healing Mechanics
- **Damage Conversion**: When vampire mode is active, any damage the player would take is converted to healing
- **Implementation**: Modified `course_1.gd` `take_damage()` function to check for vampire mode
- **Healing Amount**: Player heals for the full damage amount that would have been dealt

### Visual Effects
- **Dark Red Hue**: Character sprite becomes dark red (`Color(1.0, 0.2, 0.2, 1.0)`)
- **Smooth Animation**: Uses Tween with SINE transition and EASE_OUT easing (0.5 seconds)
- **Restoration**: When deactivated, sprite animates back to normal white color

### Deactivation
- **Trigger**: When player starts their next turn (in `draw_cards_for_shot()` function)
- **Visual Restoration**: Sprite animates back to normal appearance
- **Mode Clear**: `vampire_mode_active` flag is set to false

## Course Integration

### Vampire Mode Variables (`course_1.gd`)
```gdscript
# Vampire mode variables
var vampire_mode_active: bool = false
var vampire_mode_tween: Tween
```

### Vampire Mode Methods (`course_1.gd`)
- `activate_vampire_mode()` - Activates vampire mode with visual effects
- `deactivate_vampire_mode()` - Deactivates vampire mode and restores appearance
- `is_vampire_mode_active()` - Checks if vampire mode is currently active

### Damage System Modification (`course_1.gd`)
```gdscript
func take_damage(amount: int) -> void:
    # Check if vampire mode is active - heal instead of taking damage
    if vampire_mode_active:
        print("Vampire mode active - healing for damage instead of taking damage!")
        heal_player(amount)
        return
    # ... rest of damage handling
```

## Testing

### Test Scene
Use `test_vampire_integration.tscn` to verify all integrations are working:

1. Load the test scene in Godot
2. Check console output for integration status
3. Verify all systems show "✅ SUCCESS" messages

### Manual Testing
1. **Starter Deck Test**: Start a new game and check if Vampire card is in the deck
2. **Shop Test**: Visit the shop and check if Vampire card appears for purchase
3. **Rewards Test**: Complete a hole and check if Vampire card appears as a reward option
4. **Effect Test**: Play the Vampire card and verify:
   - Sound plays
   - Player sprite turns dark red
   - Player heals when taking damage
   - Effect deactivates on next turn

## Balance Considerations

### Pricing and Tier
- **Price**: 150 coins (same as GhostMode)
- **Tier**: 2 (Medium-tier card)
- **Rationale**: Powerful healing effect justifies higher tier and price

### Effect Balance
- **Duration**: Until next turn (same as GhostMode)
- **Healing**: Full damage amount (very powerful)
- **Counterplay**: Limited duration prevents permanent invincibility

## Future Enhancements

Potential improvements for the Vampire system:

1. **Visual Effects**: Add blood particle effects when healing
2. **Sound Variations**: Different sounds for different damage types
3. **Vampire Variants**: Different vampire cards with varying effects
4. **Stacking**: Allow multiple vampire cards to stack duration
5. **Upgrade Effects**: Level 2 could heal for more than damage taken

## Troubleshooting

### Common Issues

1. **Vampire not in shop**:
   - Check `Shop/ShopInterior.gd` line 144
   - Verify Vampire.tres file exists and loads properly

2. **Vampire not in rewards**:
   - Check `RewardSelectionDialog.gd` line 58
   - Verify card resource path is correct

3. **Vampire not in starter deck**:
   - Check `current_deck_manager.gd` line 25
   - Verify CurrentDeckManager is properly initialized

4. **Vampire effect not working**:
   - Check `CardEffectHandler.gd` for Vampire effect handling
   - Verify `course_1.gd` has vampire mode methods
   - Ensure vampire mode variables are properly initialized

### Debug Commands

Add these debug prints to verify integration:

```gdscript
# In RewardSelectionDialog.gd
print("Available cards:", base_cards.map(func(card): return card.name))

# In ShopInterior.gd
print("Shop cards:", available_cards.map(func(card): return card.name))

# In current_deck_manager.gd
print("Starter deck:", starter_deck.map(func(card): return card.name))
```

## Conclusion

The Vampire card is now fully integrated into the game's reward, shop, and starter deck systems. Players can obtain it through rewards, purchase it in shops, and test it immediately from the starter deck. The vampire mechanics provide powerful healing capabilities and add strategic depth to the card system, making it a valuable defensive option for players. 