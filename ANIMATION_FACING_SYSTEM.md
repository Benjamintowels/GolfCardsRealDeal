# Animation Facing System

## Overview

The Animation Facing System automatically flips animations (Swing, Kick, Punch) based on the player's current facing direction. This ensures that animations always play in the correct direction relative to where the player is facing.

## How It Works

### Player Facing Direction Tracking

The player's facing direction is determined by the mouse position relative to the player:

- **Facing Right**: When mouse is to the right of the player (`current_facing_direction = Vector2i(1, 0)`)
- **Facing Left**: When mouse is to the left of the player (`current_facing_direction = Vector2i(-1, 0)`)

The facing direction is updated in the `_update_mouse_facing()` method and stored in the `current_facing_direction` variable.

### Animation Facing Methods

#### Core Methods

```gdscript
func get_current_facing_direction() -> Vector2i:
    """Get the current facing direction of the player"""
    return current_facing_direction

func is_facing_left() -> bool:
    """Check if the player is currently facing left"""
    return current_facing_direction.x < 0

func is_facing_right() -> bool:
    """Check if the player is currently facing right"""
    return current_facing_direction.x > 0

func update_animation_facing(animation_sprite: Node) -> void:
    """Update the facing direction of an animation sprite to match the player's facing direction"""
    if not animation_sprite:
        return
    
    # Apply the same flip as the main character sprite
    if animation_sprite is Sprite2D:
        animation_sprite.flip_h = is_facing_left()
    elif animation_sprite is AnimatedSprite2D:
        animation_sprite.flip_h = is_facing_left()
```

#### Updated Animation Methods

All animation start methods now automatically update the facing direction:

1. **Swing Animation**: `start_swing_animation()` - Updates SwingSprite facing before starting
2. **Kick Animation**: `start_kick_animation()` - Updates BennyKick sprite facing before showing
3. **Punch Animation**: `start_punchb_animation()` - Updates BennyPunch AnimatedSprite2D facing before showing

### Implementation Details

#### Mouse Facing Update

The `_update_mouse_facing()` method now tracks the facing direction:

```gdscript
# Determine if mouse is to the left or right of player
var mouse_is_left = direction.x < 0

# Update current facing direction
current_facing_direction = Vector2i(-1, 0) if mouse_is_left else Vector2i(1, 0)

# Flip the sprite horizontally based on mouse position
sprite.flip_h = mouse_is_left
```

#### Animation Facing Update

Before any animation starts, the `update_animation_facing()` method is called:

```gdscript
# Update the animation facing before showing it
update_animation_facing(animation_sprite)
```

This ensures that:
- Swing animations flip the SwingSprite
- Kick animations flip the BennyKick sprite
- Punch animations flip the BennyPunch AnimatedSprite2D

## Testing

### Test Scene

Use the `test_animation_facing.tscn` scene to test the animation facing system:

1. **Setup**: The scene includes a Player (BennyChar) and Camera2D
2. **Controls**:
   - Move mouse left/right to change player facing direction
   - Press SPACE to test swing animation
   - Press K to test kick animation
   - Press P to test punch animation

### Expected Behavior

1. **Mouse Movement**: Player sprite should flip based on mouse position
2. **Swing Animation**: Should flip to match player facing direction
3. **Kick Animation**: Should flip to match player facing direction
4. **Punch Animation**: Should flip to match player facing direction

### Debug Output

The system provides detailed debug output:

```
=== TESTING SWING ANIMATION ===
Current facing direction: (-1, 0)
Facing left: true
Facing right: false
Updated animation facing - Direction: (-1, 0), Flip H: true
```

## Integration with Existing Systems

### Equipment System

The animation facing system works alongside the existing equipment system. When the player sprite flips, the equipment manager is notified to update clothing sprites:

```gdscript
# Update clothing sprites to match player sprite flip
var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
if equipment_manager and equipment_manager.has_method("update_all_clothing_flip"):
    equipment_manager.update_all_clothing_flip()
```

### Attack System

The animation facing system integrates with the attack system to ensure that:
- PunchB attacks show the correct facing direction
- All animations are properly oriented relative to the target

## Future Enhancements

### Potential Improvements

1. **Smooth Transitions**: Add smooth flipping transitions for animations
2. **Directional Animations**: Create separate left/right facing animation spritesheets
3. **Weapon Facing**: Extend the system to handle weapon animations
4. **NPC Integration**: Apply similar facing logic to NPC animations

### Code Structure

The system is designed to be easily extensible:

```gdscript
# Easy to add new animation types
func start_new_animation() -> void:
    var animation_sprite = get_new_animation_sprite()
    update_animation_facing(animation_sprite)
    # Start animation logic...
```

## Troubleshooting

### Common Issues

1. **Animation Not Flipping**: Check that the animation sprite is found and the `update_animation_facing()` method is called
2. **Wrong Facing Direction**: Verify that `current_facing_direction` is being updated correctly in `_update_mouse_facing()`
3. **Equipment Not Flipping**: Ensure the equipment manager is properly referenced and has the `update_all_clothing_flip()` method

### Debug Steps

1. Check console output for facing direction updates
2. Verify animation sprite references are valid
3. Test with the provided test scene
4. Check that camera reference is set for mouse position calculation 