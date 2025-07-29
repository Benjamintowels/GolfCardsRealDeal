# Police Bullet System

## Overview
The police shooting mechanic has been improved with a visual bullet indicator that shows the trajectory of shots fired by police NPCs.

## Components

### 1. Bullet Scene (`Particles/Bullet.tscn`)
- **Script**: `Particles/bullet.gd`
- **Sprite**: `Particles/Bullet.png` (default facing upwards)
- **Scale**: 0.05x0.05 (very small for realistic bullet size)
- **Area2D**: Circle collision shape with 2px radius for hit detection
- **Collision Layer**: 0 (doesn't collide with other bullets)
- **Collision Mask**: 2 (detects HitBoxes on layer 2)

### 2. Bullet Script Features
- **Trajectory Animation**: Smooth movement from start to target position
- **Rotation**: Automatically rotates to face movement direction
- **Collision Detection**: Uses Area2D for reliable hit detection during flight
- **Speed**: 1600 pixels per second
- **Max Distance**: 1000 pixels (prevents infinite travel)
- **Auto Cleanup**: Automatically removes itself after hitting or missing

### 3. Police Integration
- **Bullet Origin**: Uses `BulletOrigin` marker in police scene
- **Visual Feedback**: Shows actual bullet trajectory
- **Reliable Detection**: More accurate hit detection than previous raycast system
- **Sound Integration**: Plays pistol shot sound when firing
- **Damage System**: Uses PlayerManager for player damage, direct damage for NPCs

## How It Works

1. **Police Attack**: When police attacks, `_fire_bullet_at_player()` is called
2. **Bullet Creation**: Creates bullet instance and adds to scene
3. **Trajectory Calculation**: Calculates path from BulletOrigin to player HitBox position
4. **Animation**: Bullet rotates and moves along trajectory
5. **Collision Detection**: Area2D detects hits during flight
6. **Damage Application**: If hit detected, applies damage via PlayerManager
7. **Cleanup**: Bullet removes itself after completion

## Benefits

- **Visual Feedback**: Players can see exactly where bullets are going
- **Reliability**: More consistent hit detection than raycast system
- **Debugging**: Easier to see what's happening during attacks
- **Realism**: Bullets have travel time and visible trajectory
- **Performance**: Efficient cleanup prevents memory leaks

## Technical Details

### Bullet Properties
```gdscript
speed: float = 1600.0  # Pixels per second
max_distance: float = 1000.0  # Maximum travel distance
```

### Collision Layers
- Bullet uses Area2D with collision mask 2 (HitBoxes)
- Bullet collision layer is 0 (doesn't interfere with other bullets)
- Ignores police HitBoxes to prevent self-damage

### Rotation System
- Bullet sprite faces up by default
- Automatically rotates to face movement direction
- Uses `rad_to_deg(angle) - 90` to account for default orientation

### Signal System
- `bullet_hit(target: Node)`: Emitted when bullet hits something
- `bullet_missed`: Emitted when bullet reaches target without hitting

## Usage

The system is automatically integrated into the police attack system. No additional setup required beyond ensuring the `BulletOrigin` marker exists in the police scene.

## Future Enhancements

- Bullet impact effects
- Different bullet types (ricochet, explosive, etc.)
- Bullet trails or particle effects
- Sound effects for bullet travel 