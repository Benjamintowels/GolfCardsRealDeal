# Fighter Deck System

## Overview

The Fighter Deck is a comprehensive deck loadout designed for testing all attack mechanics and NPC combat in the game. It includes one copy of every attack card available, allowing players to test different combat strategies and weapon combinations.

## Deck Contents

### Attack Cards (4 cards)
- **PunchB** - Basic melee attack
- **KickB** - Basic melee attack  
- **AttackDog** - Dog attack
- **AssassinDash** - Dash attack

### Weapon Cards (7 cards)
- **PistolCard** - Basic pistol
- **BurstShot** - Burst fire weapon
- **ShotgunCard** - Shotgun weapon
- **SniperCard** - Sniper weapon
- **GrenadeCard** - Grenade weapon
- **ThrowingKnife** - Throwing knife
- **ShurikenCard** - Shuriken weapon

### AOE/Explosive Cards (4 cards)
- **FireBallCard** - Fire ball attack
- **IceBallCard** - Ice ball attack
- **MeteorCard** - Meteor attack
- **Explosive** - Explosive attack

### Defense Cards (4 cards)
- **BlockB** (x2) - Block damage
- **DodgeCard** - Dodge ability
- **Vampire** - Vampire healing

### Movement Cards (6 cards)
- **Move1** (x2) - 1 movement
- **Move2** (x2) - 2 movement
- **Move3** (x2) - 3 movement

### Club Cards (5 cards)
- **Putter** - Short range club
- **PitchingWedge** - Medium-short range club
- **Iron** - Medium range club
- **Wood** - Medium-long range club
- **Driver** - Long range club

## Usage

### Switching to Fighter Deck

To use the fighter deck for testing, call:

```gdscript
CurrentDeckManager.switch_to_fighter_deck()
```

### Switching Back to Starter Deck

To return to the normal starter deck:

```gdscript
CurrentDeckManager.switch_to_starter_deck()
```

### Testing the Fighter Deck

1. Load the test scene: `test_fighter_deck.tscn`
2. Check the console output for deck statistics
3. Verify all attack cards are included

## Integration with Game Systems

The fighter deck integrates with all existing game systems:

- **DeckManager** - Automatically syncs when deck is switched
- **AttackHandler** - Supports all melee attack cards
- **WeaponHandler** - Supports all weapon cards
- **CardEffectHandler** - Supports all AOE and special effect cards
- **MovementController** - Supports all movement cards

## Testing Combat Mechanics

With the fighter deck, you can test:

1. **Melee Combat** - PunchB, KickB, AttackDog, AssassinDash
2. **Ranged Combat** - All weapon cards with different ranges and effects
3. **Area Damage** - FireBall, IceBall, Meteor, Explosive cards
4. **Defense Systems** - BlockB, DodgeCard, Vampire healing
5. **Movement Tactics** - Different movement ranges for positioning

## Deck Statistics

- **Total Cards**: 30 cards
- **Attack Cards**: 4 cards
- **Weapon Cards**: 7 cards  
- **AOE Cards**: 4 cards
- **Defense Cards**: 4 cards
- **Movement Cards**: 6 cards
- **Club Cards**: 5 cards

## File Locations

- **Deck Definition**: `current_deck_manager.gd` - `fighter_deck` array
- **Test Scene**: `test_fighter_deck.tscn`
- **Test Script**: `test_fighter_deck.gd`
- **Documentation**: `FIGHTER_DECK_README.md` 