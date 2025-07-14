# PowerMeter System

## Overview
The PowerMeter system provides a visual power meter for golf shots with automatic cycling, sweet spot detection, and customizable settings.

## Features

### Visual Components
- **Background**: Uses PowerMeter.png as the container background
- **Power Bar**: Transparent progress bar that fills to show current power level
- **Sweet Spot Indicator**: Yellow marker showing the optimal power range
- **Power Label**: Displays current power percentage
- **Color-coded Feedback**: Bar changes color from green (low) to yellow (medium) to red (high)

### Functionality
- **Automatic Cycling**: Power automatically cycles from 0% to 100% and back
- **Sweet Spot Detection**: Emits signal when sweet spot is hit
- **Customizable Settings**: 
  - Sweet spot range (default: 70-85%)
  - Power increment speed
  - Maximum power level
- **Easy Integration**: Simple start/stop methods

## Usage

### Basic Usage
```gdscript
@onready var power_meter = $PowerMeter

# Start the power meter
power_meter.start_power_meter()

# Stop the power meter and get results
power_meter.stop_power_meter()
var power = power_meter.get_current_power()
var sweet_spot_hit = power_meter.is_sweet_spot_hit()
```

### Signal Connections
```gdscript
# Connect to power changes
power_meter.power_changed.connect(_on_power_changed)

# Connect to sweet spot hits
power_meter.sweet_spot_hit.connect(_on_sweet_spot_hit)

func _on_power_changed(power_value: float):
    print("Power: ", power_value, "%")

func _on_sweet_spot_hit():
    print("Sweet spot hit!")
```

### Customization
```gdscript
# Set custom sweet spot range
power_meter.set_sweet_spot_range(60.0, 80.0)

# Set power increment speed
power_meter.set_power_increment(2.0)  # Slower
power_meter.set_power_increment(5.0)  # Faster
```

## Integration with Golf Game

The PowerMeter is integrated into the LaunchManager system:

1. **Automatic Display**: Shows when entering launch phase
2. **Power Calculation**: Uses PowerMeter value for shot power
3. **Sweet Spot Feedback**: Provides visual feedback for optimal shots
4. **Club-specific Settings**: Sweet spot adjusts based on club and distance

### LaunchManager Integration
```gdscript
# In LaunchManager.gd
func show_power_meter():
    var power_meter_scene = preload("res://UI/PowerMeter.tscn")
    power_meter = power_meter_scene.instantiate()
    
    # Configure based on club and distance
    var sweet_spot_center = (power_for_target / max_power_for_bar) * 100.0
    power_meter.set_sweet_spot_range(sweet_spot_min, sweet_spot_max)
    
    # Start the meter
    power_meter.start_power_meter()
```

## Testing

Use the test scene `test_power_meter.tscn` to test the PowerMeter functionality:

1. Open the test scene
2. Click "Start Power Meter" to begin
3. Watch the power cycle automatically
4. Click "Stop Power Meter" to see results
5. Try to hit the sweet spot for optimal results

## Files

- `UI/PowerMeter.tscn` - The PowerMeter scene
- `UI/PowerMeter.gd` - PowerMeter script with all functionality
- `UI/PowerMeter.png` - Background image asset
- `test_power_meter.tscn` - Test scene for demonstration
- `test_power_meter.gd` - Test script

## Signals

- `power_changed(power_value: float)` - Emitted when power value changes
- `sweet_spot_hit()` - Emitted when sweet spot is hit

## Methods

- `start_power_meter()` - Start the power meter cycling
- `stop_power_meter()` - Stop the power meter and emit final power
- `get_current_power() -> float` - Get current power percentage
- `is_sweet_spot_hit() -> bool` - Check if sweet spot was hit
- `set_sweet_spot_range(min: float, max: float)` - Set sweet spot range
- `set_power_increment(increment: float)` - Set power cycling speed 