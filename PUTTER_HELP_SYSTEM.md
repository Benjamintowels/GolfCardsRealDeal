# PutterHelp Equipment System

## Overview

The PutterHelp equipment is a special tool that allows players to always draw an extra putter card in addition to their normal club card draw. This enables strategic deck building by allowing players to replace putter cards with other club varieties, knowing they'll always have a putter available when needed.

### How It Works
- **Normal Club Draw**: Player draws their normal club cards (e.g., Iron, Driver)
- **Virtual Putter**: PutterHelp equipment creates a virtual putter card (doesn't come from deck)
- **Visual Indicator**: The virtual putter card shows a small PutterHelp equipment icon in the top-right corner
- **No Deck Depletion**: The virtual putter doesn't reduce the player's actual putter cards in their deck

## How It Works

### Equipment Effect
- **Equipment Name**: PutterHelp
- **Effect**: Always draws an extra putter card in addition to normal club card drawing
- **Buff Type**: `putter_help`
- **Tier**: 2 (Medium-tier equipment)
- **Price**: 300 coins

### Implementation Details

#### 1. Equipment Detection
The system checks for PutterHelp equipment in the `EquipmentManager`:
```gdscript
func has_putter_help() -> bool:
    """Check if the player has PutterHelp equipment equipped"""
    for equipment in equipped_equipment:
        if equipment.name == "PutterHelp":
            return true
    return false
```

#### 2. Virtual Putter Card Creation
The `DeckManager` includes a specialized method for creating virtual putter cards:
```gdscript
func create_virtual_putter_card() -> CardData:
	"""Create a virtual putter card that doesn't come from the deck. Returns the created card."""
	var virtual_putter = preload("res://Cards/Putter.tres").duplicate()
	virtual_putter.name = "Putter"  # Ensure the name is set correctly
	print("DeckManager: Created virtual putter card for PutterHelp equipment")
	return virtual_putter

func add_virtual_putter_to_hand() -> bool:
	"""Add a virtual putter card to the hand. Returns true if successful."""
	var virtual_putter = create_virtual_putter_card()
	hand.append(virtual_putter)
	emit_signal("deck_updated")
	print("DeckManager: Added virtual putter card to hand via PutterHelp equipment")
	return true
```

#### 3. Integration with Club Card Drawing
The effect is integrated into the `course_1.gd` `draw_club_cards()` function:
```gdscript
# Actually draw club cards to hand first - draw enough for the selection
deck_manager.draw_club_cards_to_hand(final_club_count)

# Check for PutterHelp equipment and add a virtual putter card if equipped
var equipment_manager = get_node_or_null("EquipmentManager")
var putter_help_active = false
if equipment_manager and equipment_manager.has_putter_help():
    print("PutterHelp equipment detected - adding virtual putter card")
    putter_help_active = deck_manager.add_virtual_putter_to_hand()
```

#### 4. Visual Indicator
When a putter card is drawn via PutterHelp equipment, it displays a small equipment icon:
```gdscript
# Add PutterHelp indicator if this is a putter card and PutterHelp is active
if putter_help_active and club_name == "Putter":
    # Create a small equipment indicator in the top-right corner
    var equipment_indicator = TextureRect.new()
    var putter_help_equipment = preload("res://Equipment/PutterHelp.tres")
    equipment_indicator.texture = putter_help_equipment.image
    equipment_indicator.custom_minimum_size = Vector2(20, 20)
    equipment_indicator.position = Vector2(btn.custom_minimum_size.x - 25, 5)
    btn.add_child(equipment_indicator)
```

## Strategic Benefits

### 1. Deck Flexibility
- Players can remove putter cards from their deck to make room for other clubs
- Always guaranteed to have a putter available when needed
- Enables more aggressive deck building strategies

### 2. Consistency
- Eliminates the risk of not drawing a putter when needed
- Provides reliable access to putting shots
- Reduces variance in club card draws

### 3. Resource Management
- Frees up deck slots for other valuable club cards
- Allows players to focus on specialized clubs (Fire Club, Ice Club, etc.)
- Maintains putting capability without deck space cost

## Availability

### Shop
- Available in the Golfsmith shop
- Tier 2 equipment (medium rarity)
- Costs 300 coins

### Rewards
- Available as a reward after completing holes
- Tier 2 probability in reward selection
- Can appear in suitcase rewards

## Testing

A comprehensive test system is included:
- **Test Scene**: `test_putter_help_system.tscn`
- **Test Script**: `test_putter_help_system.gd`
- **Controls**: 
  - SPACE: Run test again
  - R: Reset test

The test verifies:
1. Equipment detection
2. Putter card drawing functionality
3. Integration with normal club card drawing
4. Proper hand management

## Technical Notes

### Card Identification
Putter cards are identified by the name "Putter" in the `is_club_card()` function:
```gdscript
func is_club_card(card: CardData) -> bool:
    var club_names = ["Putter", "Wood", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "Fire Club", "Ice Club", "GrenadeLauncherClubCard"]
    return club_names.has(card.name)
```

### Putter Detection
The system uses the `is_putter` flag in club data:
```gdscript
var club_info = club_data.get(card.name, {})
return club_info.get("is_putter", false)
```

### Equipment Integration
The equipment integrates seamlessly with the existing equipment system:
- Uses standard `EquipmentData` structure
- Compatible with equipment slots and bag system
- Works with clothing system (non-clothing equipment)
- Supports replacement system when bag is full

## Future Enhancements

Potential improvements could include:
1. **Multiple Putter Types**: Support for different putter variants
2. **Conditional Effects**: PutterHelp only works in certain situations
3. **Upgrade System**: Enhanced versions with additional benefits
4. **Visual Indicators**: UI elements showing PutterHelp is active 