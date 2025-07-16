# BagCheck Card System

## Overview

The BagCheck card is a new card type with the "BagAdjust" effect that allows players to temporarily use any club from their bag for a single shot. When played, it shows a dialog with 2 random club cards drawn from the entire range of available clubs, and the player can select one to use for their next shot.

## How It Works

### 1. Card Selection
When the BagCheck card is selected from the hand or bag pile:
- A dialog appears with 2 randomly selected club cards
- The player can choose one of the two clubs
- The selected club becomes the temporary club for the next shot
- The BagCheck card is discarded after use

### 2. Temporary Club Usage
- The temporary club replaces the normal club selection phase
- Only the selected temporary club is shown (with a "TEMP" indicator)
- The temporary club functions exactly like the normal club would
- After the shot is taken, the temporary club is cleared

### 3. Sound Effects
- The bag sound plays when a club is selected from the dialog
- This provides audio feedback that the BagCheck effect is working

## Implementation Details

### Card Data
- **Name**: BagCheck
- **Effect Type**: BagAdjust
- **Tier**: 2 (Medium-tier card)
- **Price**: 75 coins
- **Image**: Uses Putter image as placeholder

### Dialog System
- **Scene**: `BagCheckDialog.tscn`
- **Script**: `BagCheckDialog.gd`
- **Features**:
  - Shows 2 random club cards from all available clubs
  - Clickable card selection
  - Bag sound plays on selection
  - Modal dialog with background click to close

### Available Clubs
The dialog randomly selects from these club types:
- Putter
- Wood
- Wooden
- Iron
- Hybrid
- Driver
- PitchingWedge
- Fire Club
- Ice Club
- GrenadeLauncherClubCard

### Course Integration
- **Temporary Club Variable**: `temporary_club: CardData` in course_1.gd
- **Methods**:
  - `set_temporary_club(club_data: CardData)`: Sets the temporary club
  - `clear_temporary_club()`: Clears the temporary club after use
  - `_show_temporary_club_selection()`: Shows the temporary club UI
  - `_on_temporary_club_pressed()`: Handles temporary club selection

### Club Selection Logic
The `draw_club_cards()` function in course_1.gd has been modified to:
1. Check if a temporary club is set
2. If yes, show only the temporary club with "TEMP" indicator
3. If no, proceed with normal club card drawing

## Visual Indicators

### Temporary Club Display
- Shows the selected club card image
- Yellow "TEMP" label in top-left corner
- Same hover effects as normal club cards
- Single button instead of multiple club options

### Dialog Design
- Similar to ArrangeDialog with 2 card buttons
- Dark background with semi-transparent overlay
- Card buttons with hover effects
- Clear title: "Select a Club to Use for This Shot"

## Card Effect Handler Integration

### New Effect Type
- Added "BagAdjust" to the effect type handling in `CardEffectHandler.gd`
- `handle_bag_adjust_effect(card: CardData)`: Main handler
- `_on_bag_check_club_selected(selected_club: CardData)`: Club selection handler
- `_on_bag_check_dialog_closed()`: Dialog close handler

### Signal Connections
- `club_selected`: Emitted when a club is chosen
- `dialog_closed`: Emitted when dialog is closed

## Testing

### Test Scene
- **File**: `test_bag_check_system.tscn`
- **Script**: `test_bag_check_system.gd`
- **Controls**:
  - SPACE: Run test again
  - R: Reset test

### Test Verification
1. BagCheck card loads correctly
2. Dialog appears with 2 random club cards
3. Club selection works and plays bag sound
4. Temporary club is set correctly
5. Temporary club UI shows with "TEMP" indicator

## Integration Points

### Shop System
- Added to `ShopInterior.gd` available_cards list
- Available in tiered shop generation

### Reward System
- Added to `RewardSelectionDialog.gd` base_cards list
- Available as reward after completing holes

### Starter Deck
- Added to `current_deck_manager.gd` starter_deck list
- Available for testing in new games

## Future Enhancements

Potential improvements could include:
1. **Custom Card Image**: Replace placeholder Putter image with unique BagCheck art
2. **Multiple Shots**: Allow temporary club to last for multiple shots
3. **Club Restrictions**: Limit which clubs can be selected based on game state
4. **Visual Effects**: Add special effects when temporary club is used
5. **Upgrade System**: Enhanced versions with more club options or longer duration

## Technical Notes

### Card Identification
BagCheck cards are identified by the name "BagCheck" and effect_type "BagAdjust"

### Club Data Integration
The temporary club uses the same club_data dictionary as normal clubs for distance, height, and other properties

### Sound Integration
Uses the existing bag sound system from `Sounds/BagSound.mp3`

### UI Layer Integration
Dialog is added to the UILayer to ensure proper z-index and visibility 