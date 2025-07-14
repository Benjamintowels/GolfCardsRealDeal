# Meditation System

## Overview
The meditation system allows the player to automatically enter a healing state when they are placed next to an activated bonfire. This system includes visual effects, sound, and health restoration.

## How It Works

### Trigger Conditions
The player will automatically start meditating when:
1. The player is adjacent to or on the same tile as an activated bonfire
2. The player is not already meditating
3. The player is not currently moving

### Visual Effects
- The player sprite switches from the normal character sprite to the `BennyMeditateSprite`
- Green healing particles (`HealEffect`) spawn from the meditate sprite position
- The meditate sprite respects the player's facing direction (flips horizontally)

### Audio Effects
- Plays the meditation sound from the bonfire's `Meditate` AudioStreamPlayer2D
- Falls back to a temporary audio player if the bonfire sound is not available

### Health Restoration
- Restores 75 health points during meditation
- Updates the course's health bar UI
- Prevents healing beyond maximum health

### Duration
- Meditation lasts for 1.0 seconds
- Automatically returns to normal sprite when complete

## Implementation Details

### Files Involved
- `Characters/Player.gd` - Main meditation logic
- `Interactables/bonfire.gd` - Bonfire activation and meditation trigger
- `Characters/BennyChar.tscn` - Contains the BennyMeditateSprite
- `Particles/HealEffect.tscn` - Healing particle effect
- `Sounds/Meditate.mp3` - Meditation sound effect

### Key Methods

#### Player.gd
- `start_meditation()` - Initiates meditation state
- `stop_meditation()` - Stops meditation early
- `is_currently_meditating()` - Checks meditation status
- `_create_heal_effect()` - Spawns healing particles
- `_play_meditation_sound()` - Plays meditation sound

#### bonfire.gd
- `_check_for_player_meditation()` - Checks if player should meditate
- `set_bonfire_active()` - Activates/deactivates bonfire

### Testing
Use the `test_meditation_system.tscn` scene to test the meditation system:
- Press `L` to light the bonfire
- Press `M` to check meditation status
- Press `S` to stop meditation
- Press `T` to manually trigger meditation

## Configuration
- Meditation duration: 1.0 seconds (adjustable in Player.gd)
- Heal amount: 75 health points (adjustable in Player.gd)
- Trigger distance: 1 tile (adjacent or same tile)

## Troubleshooting
- Ensure the BennyMeditateSprite is properly set up in the character scene
- Verify the HealEffect particle scene exists and is properly configured
- Check that the Meditate sound file is available
- Make sure the bonfire has the Meditate AudioStreamPlayer2D node 