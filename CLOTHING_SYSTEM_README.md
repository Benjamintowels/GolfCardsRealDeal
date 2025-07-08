# Clothing System

## Overview

The Clothing System allows players to equip clothing items that provide visual representation on their character and grant stat bonuses. Clothing items are different from regular equipment in that they:

1. **Occupy specific clothing slots** (head, neck, body)
2. **Provide visual representation** on the player character
3. **Use separate display images** in UI (e.g., CapeDisplayImage.png for rewards)
4. **Don't count against regular equipment slots**

## Clothing Slots

- **Head**: For hats, helmets, etc. (e.g., Top Hat)
- **Neck**: For capes, necklaces, etc. (e.g., Cape)
- **Body**: For armor, shirts, etc. (currently unused)

## Equipment Data Structure

Clothing items extend the `EquipmentData` class with additional properties:

```gdscript
@export var is_clothing: bool = false  # Whether this is clothing equipment
@export var clothing_slot: String = ""  # "head", "neck", "body"
@export var clothing_scene_path: String = ""  # Path to the clothing scene (.tscn file)
@export var display_image: Texture2D  # Alternative image for display
```

## Current Clothing Items

### Cape
- **Slot**: Neck
- **Effect**: +1 Mobility
- **Display Image**: CapeDisplayImage.png (for rewards)
- **Scene**: Cape.tscn (for character visualization)
- **Resource**: `res://Equipment/Clothes/Cape.tres`

### Top Hat
- **Slot**: Head
- **Effect**: +1 Card Draw
- **Display Image**: TopHat.png (same as regular image)
- **Scene**: TopHat.tscn (for character visualization)
- **Resource**: `res://Equipment/Clothes/TopHat.tres`

## Equipment Manager Integration

The `EquipmentManager` has been extended to handle clothing:

```gdscript
# Clothing slots
var head_slot: EquipmentData = null
var neck_slot: EquipmentData = null
var body_slot: EquipmentData = null

# Methods
func _equip_clothing(clothing: EquipmentData)
func _unequip_clothing(clothing: EquipmentData)
func _update_player_clothing()
func get_clothing_slots() -> Dictionary
```

## Visual Representation

When clothing is equipped, the system:

1. **Loads the clothing scene** from `clothing_scene_path`
2. **Adds it as a child** to the player character
3. **Names it appropriately** (HeadClothing, NeckClothing, BodyClothing)
4. **Removes previous clothing** in the same slot

## UI Integration

### Reward Selection Dialog
- Uses `display_image` for clothing items in reward selection
- Checks clothing slot availability instead of equipment slots
- Shows clothing items as potential rewards

### Bag Inventory
- Shows clothing slots separately from regular equipment
- Displays clothing items in their respective slots
- Uses `display_image` for visual representation

### Shop System
- Supports clothing purchases
- Uses `display_image` for shop display
- Handles clothing slot checking for purchases

## Slot Checking Logic

Clothing items use different slot checking logic:

```gdscript
# For clothing, check if the specific slot is available
if equipment_data.is_clothing:
    var clothing_slots = equipment_manager.get_clothing_slots()
    var slot_name = equipment_data.clothing_slot
    return not clothing_slots.has(slot_name) or clothing_slots[slot_name] == null
else:
    # For regular equipment, check equipment slots
    var equipped_items = equipment_manager.get_equipped_equipment()
    var equipment_slots = bag.get_equipment_slots()
    return equipped_items.size() < equipment_slots
```

## Adding New Clothing Items

To add a new clothing item:

1. **Create the clothing scene** (.tscn file) with proper sprite positioning
2. **Create the equipment resource** (.tres file) with clothing properties
3. **Add to available equipment** in RewardSelectionDialog.gd
4. **Add display image** if needed (for UI representation)
5. **Test the clothing system** using the test scene

## Testing

Use `test_clothing_system.tscn` to verify:
- Equipment data loading
- Clothing slot assignment
- Stat bonus application
- Equipment manager functionality

## File Structure

```
Equipment/
├── EquipmentData.gd          # Base equipment class
├── EquipmentManager.gd       # Equipment management
├── Clothes/
│   ├── Cape.tres            # Cape equipment resource
│   ├── Cape.tscn            # Cape visual scene
│   ├── Cape.png             # Cape sprite
│   ├── CapeDisplayImage.png # Cape display image
│   ├── TopHat.tres          # Top Hat equipment resource
│   ├── TopHat.tscn          # Top Hat visual scene
│   └── TopHat.png           # Top Hat sprite
└── Wand.tres                # Regular equipment (not clothing)
```

## Integration Points

- **Player.gd**: Receives clothing visual nodes
- **RewardSelectionDialog.gd**: Shows clothing as rewards
- **Bag.gd**: Displays clothing slots
- **ShopInterior.gd**: Sells clothing items
- **CardReplacementDialog.gd**: Handles clothing replacement 