# Meditation System

## Overview

The meditation system allows players to heal when they are adjacent to an activated bonfire. When a player stands next to a lit bonfire, they automatically enter a meditation state that restores health and provides visual feedback.

## Components

### 1. Player Meditation System
- **Location**: `Characters/Player.gd`
- **Meditation Sprite**: `BennyMeditateSprite` in `BennyChar.tscn`
- **Duration**: 1 second meditation state
- **Heal Amount**: 75 health points
- **Visual Effects**: Green healing particles floating upwards

### 2. Bonfire Integration
- **Location**: `Interactables/bonfire.gd`
- **Trigger**: Automatically detects when player is adjacent to activated bonfire
- **Conditions**: 
  - Bonfire must be active (lit)
  - Player must be adjacent (1 tile away, not on same tile)
  - Player must not be moving
  - Player must not already be meditating

### 3. Heal Effect Particle System
- **Script**: `Particles/HealEffect.gd`
- **Scene**: `Particles/HealEffect.tscn`
- **Texture**: `Particles/HealthParticle.png`
- **Effect**: 15 green particles floating upwards and fading away
- **Duration**: 2 seconds per particle

### 4. Audio Integration
- **Sound**: `Sounds/Meditate.mp3`
- **Source**: Bonfire's "Meditate" AudioStreamPlayer2D
- **Fallback**: Direct file loading if bonfire sound not available

## How It Works

### Automatic Triggering
1. **Bonfire Activation**: Player lights bonfire using Lighter equipment
2. **Adjacency Detection**: Bonfire continuously checks if player is adjacent
3. **Meditation Trigger**: When conditions are met, player enters meditation state
4. **Health Restoration**: Player heals 75 health points
5. **Visual Effects**: Green healing particles appear around player
6. **Audio Feedback**: Meditation sound plays
7. **State Return**: After 1 second, player returns to normal state

### Meditation State Flow
1. **Normal State**: Player shows normal character sprite
2. **Meditation Triggered**: Player switches to BennyMeditateSprite
3. **Health Restoration**: Player health increases by 75 points
4. **Particle Effect**: HealEffect scene instantiated at player position
5. **Sound Playback**: Meditation sound plays from bonfire or fallback
6. **State Completion**: After 1 second, player returns to normal sprite

### Particle Effect Details
- **Spawn Pattern**: 15 particles spawned over 1.5 seconds (0.1s intervals)
- **Movement**: Particles float upwards 100 pixels with slight horizontal drift
- **Fade Effect**: Particles fade out over 1.5 seconds
- **Color**: Green (0.2, 1.0, 0.3) with full alpha
- **Scale**: Random scale variation (0.8x to 1.2x)
- **Z-Index**: 1000 to ensure particles appear on top

## Implementation Details

### Player.gd Methods
```gdscript
# Setup and state management
_setup_meditation_system()           # Initialize meditation system
_find_meditate_sprite_recursive()    # Find BennyMeditateSprite in scene tree
start_meditation()                   # Begin meditation state
stop_meditation()                    # Stop meditation early
is_currently_meditating()            # Check meditation state

# Health and effects
heal_player(amount)                  # Restore player health
_play_meditation_sound()             # Play meditation audio
_create_heal_effect()                # Spawn particle effect
```

### Bonfire.gd Methods
```gdscript
_check_for_player_meditation()       # Check if player should meditate
```

### HealEffect.gd Methods
```gdscript
start_heal_effect()                  # Begin particle spawning
spawn_particle(delay)                # Create individual particle
_animate_particle(particle)          # Animate particle movement
```

## Testing

### Test Scene
- **File**: `test_meditation_system.tscn`
- **Script**: `test_meditation_system.gd`
- **Usage**: Load scene and click "Test Meditation" button

### Manual Testing
1. Load the test scene
2. Click the test button to trigger meditation
3. Observe sprite change, health restoration, and particle effects
4. Verify meditation completes after 1 second

### In-Game Testing
1. Start a round with Benny character
2. Light a bonfire using Lighter equipment
3. Move player adjacent to the bonfire
4. Observe automatic meditation trigger
5. Verify health restoration and visual effects

## Integration Points

### Course Integration
- **Health Bar**: `course_1.gd.heal_player()` method updates health display
- **Player Position**: Bonfire checks player grid position for adjacency
- **Movement State**: Meditation only triggers when player is stationary

### Character Scene Structure
```
BennyChar (Node2D)
├── Sprite2D (normal character sprite)
├── BennyMeditateSprite (meditation sprite)
├── BennyKick (kick animation sprite)
├── BennyPunch (punch animation sprite)
└── ... (other animation sprites)
```

### Audio System
- **Primary**: Bonfire's "Meditate" AudioStreamPlayer2D
- **Fallback**: Direct file loading with temporary AudioStreamPlayer2D
- **Volume**: -5dB for fallback audio (slightly quieter)

## Configuration

### Meditation Parameters
```gdscript
meditation_duration: float = 1.0     # Duration of meditation state
heal_amount: int = 75                # Health points restored
```

### Particle Parameters
```gdscript
particle_count: int = 15             # Number of particles
particle_lifetime: float = 2.0       # How long particles live
spawn_radius: float = 20.0           # Spawn area radius
fade_duration: float = 1.5           # Fade out duration
```

## Future Enhancements

### Potential Improvements
1. **Character-Specific Sprites**: Different meditation sprites for Layla and Clark
2. **Meditation Cards**: Cards that trigger meditation without bonfire
3. **Enhanced Effects**: Additional visual effects (glow, sparkles)
4. **Meditation Duration**: Variable duration based on equipment or cards
5. **Meditation Cooldown**: Prevent rapid successive meditations

### Integration Opportunities
1. **Equipment Effects**: Certain equipment could enhance meditation healing
2. **Card Interactions**: Cards that modify meditation behavior
3. **Environmental Effects**: Different meditation effects in different environments
4. **Multiplayer**: Meditation effects visible to other players 