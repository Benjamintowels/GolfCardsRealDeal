# New Launch Flow Implementation

## Overview
The launch flow has been changed from the old system to a more intuitive height-first approach.

## Old Flow
1. Draw club cards
2. Select club card  
3. Place aiming circle
4. **Charge power** (hold left click)
5. **Charge height** (hold left click)
6. Launch golf ball

## New Flow
1. Draw club cards
2. Select club card
3. Place aiming circle
4. **Set height** (move mouse up/down, then click to confirm)
5. **Charge power** (hold left click)
6. Launch golf ball

## Key Changes Made

### 1. New State Variable
- Added `is_selecting_height` boolean to track height selection phase
- Added `HEIGHT_SELECTION_SENSITIVITY` constant for mouse sensitivity

### 2. Modified Launch Phase Entry
- `enter_launch_phase()` now starts with height selection for non-putter clubs
- Putters and fixed-height clubs still start with power charging immediately
- Height meter is shown first with instruction text

### 3. Updated Input Handling
- Mouse up/down movement during height selection phase adjusts `launch_height`
- Left click during height selection confirms height and starts power charging
- Power charging works the same as before
- Right click cancels the entire launch phase

### 4. Visual Feedback
- Height meter now shows instruction text: "Move mouse up/down to set height Click to confirm"
- Height meter updates in real-time as mouse moves
- Smooth transition from height selection to power charging

## Technical Details

### Height Selection Sensitivity
- `HEIGHT_SELECTION_SENSITIVITY = 2.0` controls how responsive mouse movement is
- Negative Y movement increases height (mouse up = higher shot)
- Height is clamped between `MIN_LAUNCH_HEIGHT` (0.0) and `MAX_LAUNCH_HEIGHT` (480.0)

### State Transitions
```
enter_launch_phase() → is_selecting_height = true (for non-putters)
height selection + left click → is_charging = true
power charging + left release → launch projectile
```

### Special Cases
- **Putters**: Skip height selection, go directly to power charging
- **Fixed height clubs** (like GrenadeLauncherClubCard): Skip height selection
- **Right click**: Cancel entire launch phase from any state

## Testing
A test script (`test_new_launch_flow.gd`) has been created to verify the new flow works correctly.

## Benefits
1. **More intuitive**: Players set trajectory first, then power
2. **Better control**: Precise height selection with mouse movement
3. **Clearer feedback**: Visual instructions guide the player
4. **Consistent**: Works for all projectile types (balls, knives, grenades, spears)

## Backward Compatibility
- All existing club types work with the new system
- Weapon modes (knife, grenade, spear) work unchanged
- Power calculation and launch mechanics remain the same 