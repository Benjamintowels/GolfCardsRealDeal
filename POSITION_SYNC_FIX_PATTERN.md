# Position Sync Fix Pattern

## Issue Description

When programmatically updating player position in Godot (e.g., AssassinDash attacks, out-of-bounds resets), the player's `set_grid_position()` method automatically triggers movement animations when `animations_enabled` is true. This creates **duplicate/conflicting animations** that cause visual glitches like "pulling from center of screen" instead of smooth movement.

## Root Cause

The `Player.set_grid_position()` method calls `_animate_movement_to_position()` internally when animations are enabled. If code then calls `animate_to_position()` for the intended visual movement, two animations conflict:

1. **Unintended animation**: Triggered by `set_grid_position()` 
2. **Intended animation**: Your explicit `animate_to_position()` call

## Solution Pattern

**Temporarily disable animations during position setup, then re-enable for intended animation:**

```gdscript
# CRITICAL FIX: Temporarily disable animations to prevent position sync glitches
var original_animations_enabled = false
if player_node and "animations_enabled" in player_node:
    original_animations_enabled = player_node.animations_enabled
    print("🔍 DEBUG: Temporarily disabling animations (was:", original_animations_enabled, ")")
    player_node.animations_enabled = false

# Update positions without triggering unwanted animations
player_node.grid_pos = new_position  # or call set_grid_position()
player_grid_pos = new_position
if course:
    course.player_grid_pos = new_position

# Re-enable animations for intended movement
if player_node and "animations_enabled" in player_node:
    print("🔍 DEBUG: Re-enabling animations")
    player_node.animations_enabled = original_animations_enabled

# Now call your intended animation
if player_node and player_node.has_method("animate_to_position"):
    player_node.animate_to_position(new_position, callback)
```

## Applied Fixes

### 1. AssassinDash Attack (`AttackHandler.gd`)
- **Problem**: Duplicate animations when moving player behind enemy
- **Fixed**: Lines 1340-1380 in `perform_assassin_dash_attack_on_npc()`

### 2. Out-of-Bounds Reset (`course_1.gd`) 
- **Problem**: Visual glitch when resetting player to shot start position
- **Fixed**: Lines 1873-1890 in `_on_golf_ball_out_of_bounds()`

## When to Use This Pattern

Apply this pattern whenever you need to:
- Update player position programmatically (not via user input)
- Prevent unwanted automatic animations during position updates
- Ensure only your intended animation plays

## Key Points

1. **Always store original state**: `original_animations_enabled = player_node.animations_enabled`
2. **Always restore state**: `player_node.animations_enabled = original_animations_enabled`
3. **Apply around ALL position updates**: Including `set_grid_position()`, `grid_pos` assignment, and related updates
4. **Use before intended animation**: The pattern prevents conflicts with your explicit animation calls

## Alternative Approaches (Not Recommended)

- ❌ Updating `grid_pos` directly without this pattern (still causes conflicts)
- ❌ Using `set_grid_position()` without animation disable (triggers unwanted animation)
- ❌ Managing position sync manually (error-prone and complex)

The animation disable pattern is the **cleanest and most reliable** solution for position sync issues. 