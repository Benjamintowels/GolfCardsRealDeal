# Pseudo 3D Effect System

## Overview

The Pseudo3DEffect system creates a cool visual effect that simulates a 3D perspective flattening when a hole is completed. It scales the Course1 node down on the Y-axis while scaling objects (players, trees, bushes, etc.) up on the Y-axis to create a flattened perspective effect.

## How It Works

1. **Hole Completion**: When a hole is completed, the `trigger_3d_effect()` function is called
2. **Y-Sort Disabled**: Y-sorting updates are disabled to prevent visual glitches during scaling
3. **Animation**: The Course1 node scales down to 0.25 on Y-axis while objects scale up to 3.63 on Y-axis
4. **Duration**: The effect stays active during rewards selection and puzzle type selection phases
5. **Next Hole**: When the next hole is loaded, the `reverse_3d_effect()` function restores normal scaling
6. **Y-Sort Re-enabled**: Y-sorting updates are re-enabled after the effect is completely reversed

## Configuration

The effect can be customized by modifying these constants in `Pseudo3DEffect.gd`:

```gdscript
const COURSE_Y_SCALE_TARGET: float = 0.25    # How much to scale Course1 down
const OBJECTS_Y_SCALE_TARGET: float = 3.63   # How much to scale objects up
const ANIMATION_DURATION: float = 1.5        # Animation duration in seconds
```

## Object Groups

The system automatically scales objects in these groups:
- `players` - Player characters
- `trees` - Tree obstacles
- `bushes` - Bush obstacles
- `grass_elements` - Grass and vegetation
- `obstacles` - General obstacles
- `NPC` - Non-player characters
- `balls` - Golf balls

## Integration

### Minimal Course1.gd Changes

Only 3 lines were added to `course_1.gd`:

1. **Preload**: `const Pseudo3DEffect := preload("res://Pseudo3DEffect.tscn")`
2. **Variable**: `var pseudo_3d_effect: Node = null`
3. **Initialization**: `pseudo_3d_effect = Pseudo3DEffect.instantiate()`

### UIManager.gd Changes

One line added to `show_hole_completion_dialog()`:
```gdscript
if course.pseudo_3d_effect and course.pseudo_3d_effect.has_method("trigger_3d_effect"):
    course.pseudo_3d_effect.trigger_3d_effect()
```

### Reset Function

One line added to `reset_for_next_hole()`:
```gdscript
if pseudo_3d_effect and pseudo_3d_effect.has_method("reverse_3d_effect"):
    pseudo_3d_effect.reverse_3d_effect()
```

## Testing

To test the effect manually, add the `test_pseudo_3d_effect.gd` script as a child of Course1. It will automatically trigger and reverse the effect after 2 seconds.

## Files

- `Pseudo3DEffect.gd` - Main effect script
- `Pseudo3DEffect.tscn` - Scene file for the effect
- `test_pseudo_3d_effect.gd` - Test script for manual testing
- `PSEUDO_3D_EFFECT_README.md` - This documentation

## Usage

The system is fully automatic and requires no manual intervention:

1. **Automatic Trigger**: Effect triggers when hole completion dialog is shown
2. **Automatic Reverse**: Effect reverses when next hole is loaded
3. **Cleanup**: Effect automatically cleans up when scene is destroyed

## Troubleshooting

- **Effect not triggering**: Check that Pseudo3DEffect node is properly added to Course1
- **Objects not scaling**: Verify objects are added to the correct groups
- **Animation conflicts**: The system automatically kills existing tweens to prevent conflicts
- **Y-sorting issues**: Y-sorting is automatically disabled during the effect and re-enabled after completion 