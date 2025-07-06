# Explosion Radius System with Ragdoll Animation

## Overview

The explosion system has been enhanced with radius-based damage and ragdoll animation for GangMembers. When an explosion occurs, all GangMembers within the explosion radius will be affected with damage and ragdoll animation.

## Features

### Explosion Radius
- **Radius**: 150 pixels (configurable in `Particles/Explosion.gd`)
- **Base Damage**: 50 damage (configurable)
- **Distance-based Damage**: Closer GangMembers take more damage
- **Automatic Detection**: Finds all GangMembers in the scene automatically

### Ragdoll Animation
- **Duration**: 1.5 seconds (configurable)
- **Animation Phases**:
  1. **Launch Phase** (40% of duration): GangMember launches upward and backward
  2. **Tilt Phase**: GangMember tilts backward 45 degrees during launch
  3. **Fall Phase** (60% of duration): GangMember falls to landing position
  4. **Landing**: GangMember lands and switches to dead state

### Visual Effects
- **Upward Launch**: GangMember flies up and backward from explosion
- **Backward Tilt**: Realistic tilting animation during flight
- **Smooth Landing**: Gradual fall to final position
- **Dead State**: Automatically switches to dead sprite after landing

## Implementation Details

### Explosion System (`Particles/Explosion.gd`)
- Added `EXPLOSION_RADIUS` constant (150 pixels)
- Added `EXPLOSION_DAMAGE` constant (50 damage)
- Added `RAGDOLL_DELAY` constant (0.1 seconds)
- New methods:
  - `_apply_explosion_radius_effects()`: Main radius detection and effect application
  - `_find_all_gang_members()`: Finds all GangMembers in scene
  - `_affect_gang_member_with_explosion()`: Applies damage and schedules ragdoll
  - `_start_gang_member_ragdoll()`: Initiates ragdoll animation

### GangMember System (`NPC/Gang/GangMember.gd`)
- Added ragdoll state tracking (`is_ragdolling`)
- Added ragdoll animation properties
- New methods:
  - `start_ragdoll_animation()`: Main ragdoll entry point
  - `_calculate_ragdoll_landing_position()`: Calculates final landing position
  - `_start_ragdoll_sequence()`: Handles the complete animation sequence
  - `_on_ragdoll_complete()`: Called when ragdoll animation finishes
  - `stop_ragdoll()`: Emergency stop for ragdoll animation
  - `is_currently_ragdolling()`: Check ragdoll state

### Turn System Integration
- GangMembers skip their turns while ragdolling
- Turn completion waits for ragdoll animation to finish
- Seamless integration with existing turn-based system

## Usage

### Automatic Usage
The explosion radius system works automatically with existing explosions:
- **Oil Drum Explosions**: When oil drums explode from fire element balls
- **Manual Explosions**: Any explosion created with `Explosion.create_explosion_at_position()`

### Testing
Use the test scene `test_explosion_radius.tscn` to test the system:
1. Load the test scene
2. GangMembers will be created at various distances
3. Press SPACE to trigger an explosion
4. Observe which GangMembers ragdoll and which are unaffected

### Configuration
Modify these constants in `Particles/Explosion.gd`:
```gdscript
const EXPLOSION_RADIUS: float = 150.0  # Radius in pixels
const EXPLOSION_DAMAGE: int = 50       # Base damage
const RAGDOLL_DELAY: float = 0.1       # Delay before ragdoll starts
```

Modify these constants in `NPC/Gang/GangMember.gd`:
```gdscript
var ragdoll_duration: float = 1.5  # Duration of ragdoll animation
```

## Technical Notes

### Performance
- GangMember detection uses efficient scene tree traversal
- Ragdoll animations use Godot's Tween system for smooth performance
- Turn system integration prevents conflicts during animation

### Compatibility
- Works with existing GangMember systems
- Compatible with Entities turn management
- Integrates with existing collision and health systems
- Preserves all existing GangMember functionality

### Debugging
The system includes extensive debug output:
- Explosion radius detection logs
- GangMember distance calculations
- Ragdoll animation progress
- Damage application details

## Future Enhancements

Potential improvements for the system:
- **Variable Explosion Types**: Different explosion types with different radii/damage
- **Environmental Effects**: Explosions could affect terrain or other objects
- **Sound Effects**: Different sounds for different explosion distances
- **Particle Effects**: Additional visual effects during ragdoll animation
- **Physics Integration**: More realistic physics-based ragdoll behavior 