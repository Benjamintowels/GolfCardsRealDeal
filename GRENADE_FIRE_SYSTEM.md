# Grenade Fire System

## Overview

The Grenade Fire System allows grenade explosions to create fire tiles on flammable terrain. When a grenade explodes, it creates fire tiles in a radius around the explosion point on specific tile types.

## Flammable Tile Types

Grenade explosions can create fire tiles on the following tile types:
- **Base** - Base grass tiles
- **G** - Green tiles  
- **R** - Rough tiles
- **F** - Fairway tiles

## How It Works

### 1. Explosion Detection
When a grenade explodes, the `deal_explosion_damage()` function is called, which:
- Deals damage to entities within the explosion radius
- Calls `_create_fire_tiles_in_radius()` to create fire tiles

### 2. Fire Tile Creation
The `_create_fire_tiles_in_radius()` function:
- Calculates the explosion radius in tiles
- Checks each tile within the radius
- Verifies the tile is flammable and not already on fire
- Creates fire tiles using the existing fire tile system

### 3. Fire Tile Behavior
Created fire tiles:
- Deal damage to entities on the tile (30 damage) and adjacent tiles (15 damage)
- Show animated fire sprites with flickering effects
- Play flame sound effects
- Transition to scorched earth after 2 turns
- Integrate with the existing bonfire activation system

## Implementation Details

### Key Functions

#### `_create_fire_tiles_in_radius()`
```gdscript
func _create_fire_tiles_in_radius() -> void:
    # Calculate explosion radius in tiles
    var explosion_radius_tiles = int(ceil(explosion_radius / cell_size))
    
    # Check tiles in a square area around the explosion
    for x in range(center_tile.x - explosion_radius_tiles, center_tile.x + explosion_radius_tiles + 1):
        for y in range(center_tile.y - explosion_radius_tiles, center_tile.y + explosion_radius_tiles + 1):
            # Check if tile is within circular radius and flammable
            # Create fire tile if conditions are met
```

#### `_is_flammable_tile(tile_type: String)`
```gdscript
func _is_flammable_tile(tile_type: String) -> bool:
    return tile_type in ["Base", "G", "R", "F"]  # Base grass, Green, Rough, Fairway
```

#### `_create_fire_tile(tile_pos: Vector2i)`
```gdscript
func _create_fire_tile(tile_pos: Vector2i) -> void:
    # Create fire tile scene instance
    # Position it correctly in the world
    # Add to fire_tiles group
    # Connect completion signal
```

### Integration Points

1. **Map Manager**: Uses `map_manager.get_tile_type()` to check tile types
2. **Fire Tile System**: Leverages existing `FireTile.tscn` and `fire_tile.gd`
3. **Bonfire System**: Fire tiles can activate nearby bonfires
4. **Damage System**: Fire tiles deal damage to entities and players
5. **Scorched Earth**: Tiles transition to scorched state after fire burns out

## Configuration

### Explosion Radius
- Default: 150.0 pixels
- Configurable via `explosion_radius` property in grenade script

### Fire Tile Duration
- Default: 2 turns
- Configurable in `fire_tile.gd` via `turns_to_fire` property

### Damage Values
- Fire tile damage: 30 (entities on fire tile)
- Adjacent tile damage: 15 (entities adjacent to fire tile)

## Testing

Use the test scene `test_grenade_fire_system.tscn` to verify the system:

1. **Setup**: The test creates a simple map manager with different tile types
2. **Launch**: Press SPACE to launch a grenade
3. **Explosion**: Grenade explodes and creates fire tiles
4. **Verification**: Check console output for fire tile creation details

### Test Commands
- **SPACE**: Launch test grenade
- **Console Output**: Shows fire tile creation and positions

## Dependencies

- `Weapons/Grenade.gd` - Main grenade implementation
- `Particles/FireTile.tscn` - Fire tile scene
- `Particles/fire_tile.gd` - Fire tile behavior
- `MapManager.gd` - Tile type checking
- `course_1.gd` - Fire damage system integration

## Future Enhancements

1. **Fire Spreading**: Fire tiles could spread to adjacent flammable tiles over time
2. **Weather Effects**: Rain could extinguish fire tiles
3. **Fire Resistance**: Certain entities could be immune to fire damage
4. **Fire Extinguishers**: Equipment to put out fires
5. **Smoke Effects**: Visual smoke particles from burning tiles 