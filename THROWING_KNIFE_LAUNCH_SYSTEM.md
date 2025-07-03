# Throwing Knife Launch System Integration

## Overview

The throwing knife system has been integrated with the existing LaunchManager to provide a unified launch mechanic for both golf balls and throwing knives. This allows players to use the same power/height charging system for knife throwing as they do for golf shots.

## Key Features

### 1. Unified Launch System
- Throwing knives now use the same LaunchManager as golf balls
- Same power meter, height meter, and charging mechanics
- Consistent aiming and targeting system

### 2. Hybrid Club Stats
- Knives use Hybrid club statistics:
  - Max Distance: 1050.0
  - Min Distance: 200.0
  - Trailoff Forgiveness: 0.8 (most forgiving)
- This provides good range and accuracy for knife throwing

### 3. Knife-Specific Physics
- Knives rotate while in flight (720 degrees/second)
- Reduced bounce mechanics (only 1 bounce vs 2+ for golf balls)
- Lower bounce factor (0.3 vs 0.7 for golf balls)
- Knives stick in the ground when they land

### 4. No Golf Scoring Impact
- Knife throws do not affect hole scores or round progression
- Knives are purely for combat/utility purposes
- Separate from the golf game mechanics

## How It Works

### 1. Weapon Card Selection
When a player selects a "Throwing Knife" card:
1. The WeaponHandler processes the card selection
2. Card is discarded from hand
3. Weapon aiming mode is entered

### 2. Knife Launch Process
When the player clicks to fire the knife:
1. WeaponHandler detects it's a throwing knife
2. Creates a knife instance in the scene
3. Sets up LaunchManager with Hybrid club stats
4. Enters knife mode in LaunchManager
5. Player can now charge power and height like a golf shot

### 3. Launch Mechanics
- **Power Charging**: Hold left mouse button to charge power
- **Height Charging**: Release power, then hold to charge height
- **Launch**: Release height to throw the knife
- **Targeting**: Knife follows the red circle targeting system

### 4. Flight Physics
- Knife follows an arc trajectory like golf balls
- Rotates continuously during flight
- Can bounce once before landing
- Sticks in the ground when it stops moving

## Technical Implementation

### Files Modified

1. **Weapons/ThrowingKnife.gd** - New script for knife physics and behavior
2. **Weapons/ThrowingKnife.tscn** - Updated scene with "knives" group
3. **LaunchManager.gd** - Added knife mode support
4. **WeaponHandler.gd** - Integrated with LaunchManager for knives
5. **course_1.gd** - Updated WeaponHandler setup

### Key Methods

#### LaunchManager.gd
- `enter_knife_mode()` - Switch to knife throwing mode
- `launch_throwing_knife()` - Launch a knife with physics
- `is_ball_in_flight()` - Updated to check for knives too

#### ThrowingKnife.gd
- `launch()` - Initialize knife physics and trajectory
- `is_in_flight()` - Check if knife is currently moving
- `check_target_hits()` - Detect if knife hit any targets

#### WeaponHandler.gd
- `launch_throwing_knife()` - Bridge between weapon system and LaunchManager

## Usage Example

```gdscript
# In WeaponHandler.gd
func launch_throwing_knife() -> void:
    # Set up LaunchManager for knife mode
    launch_manager.chosen_landing_spot = mouse_pos
    launch_manager.selected_club = "Hybrid"
    launch_manager.enter_knife_mode()
```

## Benefits

1. **Consistent UI**: Players already know how to use the power/height system
2. **Balanced Gameplay**: Hybrid stats provide good range without being overpowered
3. **Visual Feedback**: Same meters and targeting as golf shots
4. **Modular Design**: Easy to add other projectile weapons using the same system
5. **No Score Impact**: Knives don't interfere with golf mechanics

## Future Enhancements

- Add knife-specific sound effects
- Implement knife damage to enemies
- Add different knife types with different stats
- Create knife retrieval mechanics
- Add visual effects for knife impacts 