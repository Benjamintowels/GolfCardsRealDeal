# GolfSmith Card Save System

## Overview

The GolfSmith Card Save system is a second upgrade level for the GolfSmith that allows players to unlock CardGenes for the 3D printer by selecting cards from their current deck. This system integrates with the existing 3D printer functionality to expand the available printable cards.

## System Architecture

### Upgrade Levels

1. **Level 1 (Shop Access)**: Cost 250 $Looty
   - Unlocks the GolfSmith in the shop for card upgrades
   - Accessible from the ClubHouse upgrade dialog

2. **Level 2 (Card Save)**: Cost 400 $Looty
   - Requires Level 1 to be unlocked first
   - Adds "Card Save" functionality to the GolfSmith
   - Allows unlocking CardGenes for 3D printer

### Integration Points

- **ClubHouseUpgradeDialog**: Manages both upgrade levels
- **ShopInterior**: Handles GolfSmith button interactions
- **CardSaveDialog**: New dialog for selecting cards to save
- **SaveFileManager**: Stores card_save flag and manages CardGenes
- **3D Printer**: Uses unlocked CardGenes for printing

## Implementation Details

### ClubHouse Upgrade Dialog

The `ClubHouseUpgradeDialog.gd` has been extended to support two GolfSmith upgrade levels:

```gdscript
# New variables for Card Save upgrade
var golfsmith_card_save_button: Button
var golfsmith_card_save_cost_label: Label

# Update logic checks both levels
var shop_unlocked: bool = bool(gs.get("shop", false))
var card_save_unlocked: bool = bool(gs.get("card_save", false))

# Card Save requires shop to be unlocked first
var can_upgrade_card_save = shop_unlocked and not card_save_unlocked and clubhouse_looty >= 400
```

### Shop Integration

The `ShopInterior.gd` GolfSmith button now checks for Card Save unlock:

```gdscript
func _on_golfsmith_button_pressed():
    # Check if Card Save feature is unlocked
    var card_save_unlocked = bool(gs.get("card_save", false))
    
    if card_save_unlocked:
        # Show choice dialog between upgrade and card save
        show_golfsmith_choice_dialog()
    else:
        # Show only upgrade dialog (original behavior)
        show_card_upgrade_dialog()
```

### Card Save Dialog

The new `CardSaveDialog.gd` provides:

- **Card Selection**: Shows all cards in current deck
- **Gene Status**: Visual indicators for already unlocked genes
- **Confirmation**: Confirms gene unlocking with card preview
- **Integration**: Uses SaveFileManager to unlock CardGenes

### Save File Structure

The GolfSmith data structure in SaveFileManager:

```gdscript
npc_quests["golfsmith"] = {
    "appear": false,
    "shop": false,        // Level 1 unlock
    "card_save": false,   // Level 2 unlock
    "quest_completed": false,
    "quest_progress": 0
}
```

## User Experience

### Upgrade Process

1. **Level 1**: Purchase "Hire Golfsmith for Shop" (250 $Looty)
2. **Level 2**: Purchase "Unlock Card Save Feature" (400 $Looty)
   - Only available after Level 1 is unlocked
   - Requires sufficient ClubHouse $Looty

### Using Card Save

1. **Access**: Click GolfSmith button in shop
2. **Choice**: Select "Card Save (Unlock Genes)" from service menu
3. **Selection**: Choose a card from current deck
4. **Confirmation**: Review and confirm gene unlocking
5. **Result**: CardGene unlocked for 3D printer use

### Visual Feedback

- **Gene Status**: Green checkmark on already unlocked cards
- **Disabled Cards**: Grayed out cards that are already unlocked
- **Success Messages**: Confirmation when genes are unlocked
- **Sound Effects**: Bag sound for interactions, save sound for unlocks

## Technical Features

### Card Gene Management

- **Path-based Storage**: CardGenes stored as resource paths
- **Duplicate Prevention**: Prevents unlocking same gene twice
- **Persistence**: Saved to game file via SaveFileManager
- **Integration**: Works with existing 3D printer system

### Dialog System

- **Modal Dialogs**: Proper input blocking during dialogs
- **Choice Interface**: Service selection when both features available
- **Card Display**: Uses CardVisual for consistent card rendering
- **Error Handling**: Graceful fallbacks for missing components

### Save File Integration

- **Backward Compatibility**: Existing saves work without card_save flag
- **Progressive Unlocking**: Level 2 requires Level 1 completion
- **State Persistence**: All unlock states saved automatically

## Testing

Use the test script `test_golfsmith_card_save.gd` to verify:

- SaveFileManager integration
- Card gene unlocking functionality
- Flag persistence
- System state validation

## Future Enhancements

Potential improvements for the Card Save system:

- **Bulk Operations**: Unlock multiple genes at once
- **Gene Categories**: Organize genes by card type
- **Unlock Animations**: Visual effects for gene unlocking
- **Gene Preview**: Show 3D printer preview before unlocking
- **Cost Scaling**: Dynamic costs based on card rarity/tier
