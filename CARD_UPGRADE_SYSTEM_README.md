# Card Upgrade System

## Overview

The Card Upgrade System allows players to upgrade their cards to Level 2, providing enhanced effects and visual indicators. Upgraded cards feature an orange border and a green "Lvl 2" label in the top-right corner.

## How It Works

### 1. Card Data Structure
All cards now have upgrade-related properties:
- `level`: Current card level (1 = base, 2 = upgraded)
- `max_level`: Maximum upgrade level (currently 2)
- `upgrade_cost`: Cost to upgrade the card (currently 100 coins)
- `movement_bonus`: Additional movement range for movement cards
- `attack_bonus`: Additional attack range for attack cards
- `weapon_shots_bonus`: Additional shots for weapon cards
- `effect_bonus`: Additional effect strength for modify cards

### 2. Upgrade Effects by Card Type

#### Movement Cards
- **Effect**: +1 movement range
- **Example**: Move2 becomes Move2 (Lvl 2) with 3 range instead of 2
- **Implementation**: Uses `get_effective_strength()` in MovementController

#### Attack Cards
- **Effect**: +1 attack range
- **Example**: Kick becomes Kick (Lvl 2) with 2 range instead of 1
- **Implementation**: Uses `get_effective_strength()` in AttackHandler

#### Weapon Cards
- **Effect**: Additional shots based on `weapon_shots_bonus`
- **Example**: BurstShot Lvl 2 fires 10 bullets instead of 5
- **Implementation**: Uses `get_effective_strength()` in WeaponHandler

#### Modify Cards
- **Effect**: Enhanced effect strength
- **Examples**:
  - CoffeeCard Lvl 2 gives 2 extra turns instead of 1
  - Draw2 Lvl 2 draws 3 cards instead of 2
- **Implementation**: Uses `get_effective_strength()` in CardEffectHandler

### 3. Visual Indicators

#### Upgraded Card Display
- **Orange Border**: Upgraded cards have an orange border
- **Green Level Label**: "Lvl 2" label in top-right corner
- **Updated Names**: Cards show "(Lvl 2)" in their names

#### CardVisual System
The `CardVisual.gd` script automatically displays upgrade indicators:
- Checks `card.is_upgraded()` to determine if indicators should be shown
- Adds orange border and green level label for upgraded cards
- Updates card names to include level information

### 4. Upgrade Dialog System

#### Accessing Upgrades
- Click on the Golfsmith button in the shop
- Opens a card selection dialog showing all upgradeable cards
- Only cards that can be upgraded (level < max_level) are shown

#### Upgrade Process
1. **Card Selection**: Choose a card from your deck to upgrade
2. **Confirmation**: Review the upgrade effect and cost
3. **Upgrade**: Confirm to upgrade the card
4. **Feedback**: Success message and upgrade sound

#### Dialog Features
- Shows card count for each card type
- Displays upgrade descriptions
- Shows upgrade costs
- Plays upgrade sound effect
- Updates deck display after upgrade

## Implementation Details

### Key Files

#### Core System
- `Cards/CardData.gd`: Extended with upgrade properties and methods
- `CardUpgradeDialog.gd`: Main upgrade dialog system
- `CardUpgradeDialog.tscn`: Dialog scene file

#### Integration Points
- `Shop/ShopInterior.gd`: Golfsmith button integration
- `CardVisual.gd`: Visual upgrade indicators
- `MovementController.gd`: Uses effective strength for movement
- `AttackHandler.gd`: Uses effective strength for attacks
- `WeaponHandler.gd`: Uses effective strength for weapon shots
- `CardEffectHandler.gd`: Uses effective strength for card effects

### Card Data Methods

#### `is_upgraded() -> bool`
Returns true if the card is level 2 or higher.

#### `can_upgrade() -> bool`
Returns true if the card can be upgraded (level < max_level).

#### `get_upgraded_name() -> String`
Returns the card name with level indicator if upgraded.

#### `get_effective_strength() -> int`
Returns the effective strength including upgrade bonuses.

#### `get_upgrade_description() -> String`
Returns a description of what the upgrade does.

### Example Card Configurations

#### Movement Card (Move2)
```gdscript
name = "Move2"
effect_type = "Move"
effect_strength = 2
level = 1
max_level = 2
upgrade_cost = 100
movement_bonus = 1
```

#### Attack Card (Kick)
```gdscript
name = "Kick"
effect_type = "Attack"
effect_strength = 1
level = 1
max_level = 2
upgrade_cost = 100
attack_bonus = 1
```

#### Weapon Card (BurstShot)
```gdscript
name = "BurstShot"
effect_type = "Weapon"
effect_strength = 5
level = 1
max_level = 2
upgrade_cost = 100
weapon_shots_bonus = 5
```

#### Modify Card (CoffeeCard)
```gdscript
name = "CoffeeCard"
effect_type = "ExtraTurn"
effect_strength = 1
level = 1
max_level = 2
upgrade_cost = 100
effect_bonus = 1
```

## Testing

### Test Script
Run `test_card_upgrade_system.tscn` to verify the upgrade system:
- Tests basic upgrade functionality
- Tests movement card upgrades
- Tests attack card upgrades
- Tests weapon card upgrades
- Tests modify card upgrades

### Manual Testing
1. Enter the shop in-game
2. Click the Golfsmith button
3. Select a card to upgrade
4. Confirm the upgrade
5. Verify the card shows upgrade indicators
6. Test the upgraded card's enhanced effects

## Future Enhancements

### Potential Features
- Multiple upgrade levels (Level 3, 4, etc.)
- Different upgrade costs per card
- Upgrade materials/requirements
- Special upgrade effects
- Upgrade trees/branches
- Downgrade system

### Technical Improvements
- Upgrade persistence across game sessions
- Upgrade history tracking
- Upgrade statistics
- Upgrade animations
- Upgrade sound variations

## Troubleshooting

### Common Issues
1. **Cards not showing in upgrade dialog**: Ensure cards have `max_level > level`
2. **Upgrade effects not working**: Check that systems use `get_effective_strength()`
3. **Visual indicators missing**: Verify `CardVisual.gd` is properly integrated
4. **Golfsmith button not working**: Check signal connections in `ShopInterior.gd`

### Debug Information
- Check console for upgrade-related print statements
- Verify card data properties are set correctly
- Ensure upgrade dialog is properly instantiated
- Confirm upgrade sound is available in shop scene 