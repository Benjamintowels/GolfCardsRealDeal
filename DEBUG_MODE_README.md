# Debug Height Mode

This debug mode allows you to precisely test ball heights and collision detection for visual calibration.

## How to Use

1. **Activate Debug Mode**: Click the "Debug Height Mode" button in the top-left corner of the screen
2. **Move the Ball**: The debug ball will follow your mouse cursor 1:1
3. **Adjust Height**: 
   - Press **W** to increase height by 5 units
   - Press **S** to decrease height by 5 units
   - Height range: 0.0 to 1000.0 units

## Testing Collisions

1. **Move over objects**: Position the debug ball over sprites like:
   - GangMembers (height: 200.0)
   - Trees (height: 400.0)
   - Pins (height: 100.0)
   - Players (height: 150.0)

2. **Check output**: The debug label will show:
   - Current ball height
   - Object name and height
   - Whether ball passes over or collides
   - Exact difference in height

## Console Output

The console will display detailed collision information:
```
=== DEBUG BALL COLLISION DETECTED ===
Collided with: GangMember1
Ball height: 150.0
Object height: 200.0
RESULT: Ball would collide (height 150.0 <= object height 200.0)
DIFFERENCE: Ball is 50.0 units below object
=== END DEBUG BALL COLLISION ===
```

## Visual Feedback

- The debug ball has a slight yellow glow to distinguish it from regular balls
- The shadow follows the same logic as regular golf balls
- The ball scales and moves up/down based on height just like the real ball

## Purpose

This tool helps you:
- Determine the exact height values for proper visual scaling
- Test collision detection logic
- Calibrate the perspective system
- Ensure balls appear to go over objects at the right height

## Exit Debug Mode

Click the "Exit Debug Mode" button to remove the debug ball and return to normal gameplay. 