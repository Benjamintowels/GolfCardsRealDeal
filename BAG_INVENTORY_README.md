# Bag Inventory System

## Overview
The Bag Inventory System allows players to view their movement cards and club cards in an organized inventory interface. Players start each round with a character-specific bag level 1 that matches their selected character.

## Components

### 1. Bag Scene (`Bags/Bag.tscn`)
- **Location**: `Bags/Bag.tscn`
- **Script**: `Bags/Bag.gd`
- **Features**:
  - Clickable bag that opens the inventory dialog
  - Character-specific bag textures (Layla, Benny, Clark)
  - Four bag levels (1-4) for each character
  - Automatically displays level 1 bag for selected character
  - Emits `bag_clicked` signal when clicked

### 2. Inventory Dialog (`InventoryDialog.tscn`)
- **Location**: `InventoryDialog.tscn`
- **Script**: `InventoryDialog.gd`
- **Features**:
  - Modal dialog with semi-transparent background
  - Two main buttons: "Movement Cards" and "Club Cards"
  - Scrollable area to display cards in a horizontal row
  - Close button to dismiss the dialog
  - Click outside dialog to close

### 3. Card Display (`CardVisual.tscn`)
- **Location**: `CardVisual.tscn`
- **Script**: `CardVisual.gd`
- **Features**:
  - Displays card image and name
  - Scaled down (50%) for inventory display
  - Non-interactive in inventory mode

## Integration

### Course1 Scene Integration
The bag and inventory system is integrated into the main course scene:

1. **Bag Position**: Top-left corner of the screen (51, 93)
2. **Inventory Dialog**: Full-screen overlay with high z-index (100)
3. **Setup**: Called in `_ready()` function via `setup_bag_and_inventory()`
4. **Character Integration**: Bag automatically updates to match selected character

### Card Sources
- **Movement Cards**: Retrieved from `deck_manager.hand` filtered by `effect_type == "movement"`
- **Club Cards**: Retrieved from `bag_pile` (all available club cards)

## Usage

1. **Character Selection**: Bag automatically displays level 1 bag for selected character
2. **Click the Bag**: Players click the bag icon in the top-left corner
3. **View Movement Cards**: Click "Movement Cards" button to see current hand movement cards
4. **View Club Cards**: Click "Club Cards" button to see all available club cards
5. **Close Inventory**: Click "Close Inventory" button or click outside the dialog

## Character-Specific Bags

### Layla Bags
- **Level 1**: LaylaBag1.png
- **Level 2**: LaylaBag2.png  
- **Level 3**: LaylaBag3.png
- **Level 4**: LaylaBag4.png

### Benny Bags
- **Level 1**: BennyBag1.png
- **Level 2**: BennyBag2.png  
- **Level 3**: BennyBag3.png
- **Level 4**: BennyBag4.png

### Clark Bags
- **Level 1**: ClarkBag1.png
- **Level 2**: ClarkBag2.png  
- **Level 3**: ClarkBag3.png
- **Level 4**: ClarkBag4.png

## Technical Details

### Signals
- `bag_clicked`: Emitted when bag is clicked
- `inventory_closed`: Emitted when inventory dialog is closed

### Functions
- `setup_bag_and_inventory()`: Initializes bag and inventory system
- `_on_bag_clicked()`: Handles bag click events
- `get_movement_cards_for_inventory()`: Returns current movement cards
- `get_club_cards_for_inventory()`: Returns all club cards
- `set_character(character)`: Sets bag to display character-specific texture
- `set_bag_level(level)`: Sets bag level (1-4)

### Character Integration
- Bag automatically updates when character is selected in `display_selected_character()`
- Default bag level is always 1 for new rounds
- Character name is determined from `Global.selected_character`

### File Structure
```
Bags/
├── Bag.tscn          # Bag scene
├── Bag.gd            # Bag script
├── LaylaBag1.png     # Layla bag level 1
├── LaylaBag2.png     # Layla bag level 2
├── LaylaBag3.png     # Layla bag level 3
├── LaylaBag4.png     # Layla bag level 4
├── BennyBag1.png     # Benny bag level 1
├── BennyBag2.png     # Benny bag level 2
├── BennyBag3.png     # Benny bag level 3
├── BennyBag4.png     # Benny bag level 4
├── ClarkBag1.png     # Clark bag level 1
├── ClarkBag2.png     # Clark bag level 2
├── ClarkBag3.png     # Clark bag level 3
└── ClarkBag4.png     # Clark bag level 4

InventoryDialog.tscn  # Inventory dialog scene
InventoryDialog.gd    # Inventory dialog script
CardVisual.tscn       # Card display scene
CardVisual.gd         # Card display script
```

## Future Enhancements
- Add bag level progression system based on game progress
- Implement card filtering and sorting
- Add card details on hover
- Support for bag upgrades during gameplay
- Different bag types per character with unique abilities 