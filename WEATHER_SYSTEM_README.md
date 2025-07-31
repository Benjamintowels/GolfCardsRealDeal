# Weather System

A basic weather system that adds wind factors to the golf game, affecting projectile trajectories.

## Overview

The weather system consists of:
- **WeatherManager**: Core system that generates and manages wind factors
- **WindArrow**: Visual indicator showing current wind direction and intensity
- **Projectile Integration**: Wind effects applied to all in-air projectiles

## Components

### WeatherManager.gd
- Generates random wind factors for each hole
- Wind direction: 0-360 degrees (random)
- Wind intensity: 0-10 mph (Front 9), 0-30 mph (Back 9)
- Applies wind effects to projectiles in flight
- Emits signals for UI updates

### WindArrow (UI/wind_arrow.gd)
- Visual indicator in the UI layer
- Sprite rotates to show wind direction
- Label displays wind intensity in mph
- Automatically updates when wind changes

### Projectile Integration
Wind effects are applied to:
- GolfBall.gd
- ThrowingKnife.gd
- Grenade.gd
- Spear.gd
- Shuriken.gd

## How It Works

1. **Wind Generation**: New wind factors are generated when:
   - First hole loads
   - Player advances to next hole
   - New hole layout is created

2. **Wind Application**: Wind affects projectiles when:
   - Projectile is in the air (z > 0)
   - Wind is active (intensity > 0.1 mph)
   - Wind influence factor is applied to velocity

3. **Visual Feedback**: WindArrow shows:
   - Direction: Arrow points in wind direction
   - Intensity: Label shows speed in mph
   - "No wind" when intensity < 0.1 mph

## Configuration

### Wind Influence Factor
- Default: 0.15 (15% of wind force applied to projectiles)
- Can be adjusted in WeatherManager.gd
- Range: 0.0 (no effect) to 1.0 (full wind force)

### Wind Intensity Range
- Front 9 holes (1-9): 0-10 mph
- Back 9 holes (10-18): 0-30 mph
- Can be adjusted in WeatherManager.gd variables
- Minimum threshold: 0.1 mph (below this = no wind)

## Performance

- Efficient: Only applies wind when projectiles are in air
- Minimal overhead: Simple vector addition to velocity
- Debug output: Limited to 1% chance per frame to avoid spam

## Integration

The system integrates seamlessly with existing code:
- No changes required to course_1.gd physics
- Automatic wind factor generation on hole transitions
- Visual indicator automatically updates
- All projectiles automatically affected

## Future Enhancements

Potential additions:
- Rain effects (reduced visibility, wet surfaces)
- Fog effects (reduced range)
- Temperature effects (ball physics changes)
- Weather patterns (consistent wind for multiple holes)
- Weather forecasts (show upcoming conditions) 