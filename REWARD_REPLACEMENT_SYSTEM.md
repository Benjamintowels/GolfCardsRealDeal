# Reward Replacement System

## Overview

The Reward Replacement System handles scenarios where the player's inventory (bag) is full and they need to replace existing items when receiving new rewards. This system works across multiple contexts:

- **Reward Selection Dialog** (after completing holes)
- **Shop Interior** (when purchasing items)
- **Suitcase** (when opening suitcases for rewards)

## How It Works

### 1. Slot Checking

Before adding any item to the inventory, the system checks if there are available slots:

- **Equipment Slots**: Based on bag level (1-4 slots)
- **Movement Card Slots**: Based on bag level (16-28 slots in a grid)
- **Club Card Slots**: Based on bag level (2-5 slots)

### 2. Replacement Trigger

When the bag is full for a specific item type, the system:

1. **RewardSelectionDialog**: Shows the replacement dialog instead of adding the item directly
2. **ShopInterior**: Shows the replacement dialog instead of completing the purchase
3. **SuitCase**: Uses RewardSelectionDialog which handles replacement automatically

### 3. Replacement Process

1. **Dialog Display**: Shows a dialog explaining the replacement process
2. **Bag Inventory**: Opens the bag inventory in replacement mode
3. **Item Selection**: Player clicks on an item to replace
4. **Confirmation**: Shows a confirmation dialog comparing old vs new item
5. **Replacement**: Removes old item, adds new item, updates inventory

## Implementation Details

### Important Note: Equipment Slot Counting

The system correctly distinguishes between regular equipment and clothing items when checking slot availability:

- **Regular Equipment** (Wand, Golf Shoes, etc.): Counted against bag equipment slots (1-4 based on bag level)
- **Clothing Items** (Cape, Top Hat, etc.): Use dedicated clothing slots (head, neck, body) and don't count against regular equipment slots

This prevents the system from incorrectly triggering replacement when you have clothing items equipped but available regular equipment slots.

### Key Files

- `RewardSelectionDialog.gd` - Handles reward selection and triggers replacement
- `Shop/ShopInterior.gd` - Handles shop purchases and triggers replacement
- `UI/card_replacement_dialog.gd` - Core replacement dialog logic
- `Bags/Bag.gd` - Bag inventory display and replacement mode
- `EquipmentManager.gd` - Manages equipment inventory
- `current_deck_manager.gd` - Manages card inventory

### Slot Checking Logic

```gdscript
func check_bag_slots(item: Resource, item_type: String) -> bool:
    var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
    if not bag:
        return true  # Allow if bag not found
    
    if item_type == "card":
        var card_data = item as CardData
        var club_names = ["Putter", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "Fire Club", "Ice Club"]
        if club_names.has(card_data.name):
            # Check club card slots
            var club_cards = bag.get_club_cards()
            var club_slots = bag.get_club_slots()
            return club_cards.size() < club_slots
        else:
            # Check movement card slots
            var movement_cards = bag.get_movement_cards()
            var movement_slots = bag.get_movement_slots()
            return movement_cards.size() < movement_slots
    elif item_type == "equipment":
        # Check equipment slots
        var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
        if equipment_manager:
            var equipment_data = item as EquipmentData
            
            # For clothing, check if the specific slot is available
            if equipment_data.is_clothing:
                var clothing_slots = equipment_manager.get_clothing_slots()
                var slot_name = equipment_data.clothing_slot
                return not clothing_slots.has(slot_name) or clothing_slots[slot_name] == null
            else:
                # For regular equipment, check equipment slots
                # Only count non-clothing equipment for slot checking
                var equipped_items = equipment_manager.get_equipped_equipment()
                var regular_equipment_count = 0
                for equipped_item in equipped_items:
                    if not equipped_item.is_clothing:
                        regular_equipment_count += 1
                var equipment_slots = bag.get_equipment_slots()
                return regular_equipment_count < equipment_slots
    
    return true
```

### Bag Level Slot Configuration

| Bag Level | Equipment Slots | Movement Slots | Club Slots |
|-----------|----------------|----------------|------------|
| 1         | 1              | 16 (4x4)       | 2          |
| 2         | 2              | 20 (4x5)       | 3          |
| 3         | 3              | 24 (4x6)       | 4          |
| 4         | 4              | 28 (4x7)       | 5          |

## Usage Examples

### Reward Selection Dialog

```gdscript
func handle_reward_selection(reward_data: Resource, reward_type: String):
    var slots_available = check_bag_slots(reward_data, reward_type)
    
    if slots_available:
        # Add reward directly
        add_reward_to_inventory(reward_data, reward_type)
        reward_selected.emit(reward_data, reward_type)
        visible = false
    else:
        # Trigger replacement system
        trigger_replacement_system(reward_data, reward_type)
```

### Shop Interior

```gdscript
func _on_shop_item_clicked(event: InputEvent, item):
    var item_type = "card" if item is CardData else "equipment"
    var slots_available = check_bag_slots(item, item_type)
    
    if slots_available:
        # Complete purchase directly
        add_item_to_inventory(item, item_type)
        show_purchase_message("Purchased " + item.name + "!")
    else:
        # Trigger replacement system
        trigger_replacement_system(item, item_type)
```

## Testing

Use the test scene `test_replacement_system.tscn` to verify the replacement system works correctly:

1. Load the test scene
2. Check console output for slot availability
3. Verify replacement triggers when bag is full

## Integration Points

### UI Layer Structure

The replacement system integrates with the UI layer structure:

```
UILayer/
├── Bag (handles inventory display)
├── RewardSelectionDialog (handles rewards)
├── ShopInterior (handles shop)
├── CardReplacementDialog (handles replacement)
└── SuitCase (triggers rewards)
```

### Signal Flow

1. **Item Selection** → `check_bag_slots()`
2. **Full Bag** → `trigger_replacement_system()`
3. **Replacement Dialog** → `show_replacement_dialog()`
4. **Bag Replacement Mode** → `show_inventory_replacement_mode()`
5. **Item Selection** → `show_replacement_confirmation()`
6. **Confirmation** → `_on_confirm_replacement()`
7. **Completion** → `replacement_completed.emit()`

## Error Handling

- **Missing Bag**: System defaults to allowing items
- **Missing Managers**: Graceful fallback to direct addition
- **Invalid Items**: Type checking prevents errors
- **Cancelled Replacement**: Returns to original state

## Future Enhancements

- **Visual Indicators**: Show when bag is full
- **Auto-Organize**: Suggest optimal replacements
- **Undo System**: Allow undoing replacements
- **Bulk Operations**: Replace multiple items at once
- **Smart Suggestions**: Recommend items to replace based on usage 