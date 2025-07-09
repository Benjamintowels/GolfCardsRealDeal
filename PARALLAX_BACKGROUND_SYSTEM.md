# Parallax Background System

A comprehensive background scenery system for the golf game that creates depth and visual interest through multiple parallax layers.

## Overview

The parallax background system consists of two main components:

1. **ParallaxBackgroundSystem** - Core system that handles individual background layers and their movement
2. **BackgroundManager** - High-level manager that handles different background themes and automatically sets up layers

## Features

- **Multiple Parallax Layers**: Each layer moves at different speeds relative to camera movement
- **Theme System**: Easy switching between different background styles (golf course, forest, desert, ocean)
- **Automatic Texture Repeating**: Seamless horizontal scrolling for wide backgrounds
- **Performance Optimized**: Only updates when camera moves significantly
- **Fallback Textures**: Creates colored gradients when texture files are missing

## How It Works

### Parallax Effect
- **Parallax Factor**: Controls how much each layer moves (0.0 = static, 1.0 = full camera movement)
- **Layer Ordering**: Uses z-index system to ensure proper layering
- **Camera Integration**: Automatically connects to the game's camera system

### Theme System
Each theme defines multiple layers with different parallax factors:

```gdscript
"golf_course": {
    "layers": [
        {
            "name": "Sky",
            "texture_path": "res://Backgrounds/sky_gradient.png",
            "parallax_factor": 0.0,  # Static sky
            "z_index": -200
        },
        {
            "name": "DistantMountains", 
            "texture_path": "res://Backgrounds/distant_mountains.png",
            "parallax_factor": 0.1,  # Very slow movement
            "z_index": -150
        }
        // ... more layers
    ]
}
```

## Usage

### Basic Setup

1. **Add to Scene**: Include the BackgroundManager node in your scene
2. **Set Camera Reference**: Connect to your camera
3. **Choose Theme**: Set the desired background theme

```gdscript
# In your scene's _ready() function
@onready var background_manager: Node = $BackgroundManager
@onready var camera: Camera2D = $Camera2D

func _ready():
    background_manager.set_camera_reference(camera)
    background_manager.set_theme("golf_course")
```

### Theme Switching

```gdscript
# Switch themes dynamically
background_manager.set_theme("forest")
background_manager.set_theme("desert") 
background_manager.set_theme("ocean")
```

### Available Themes

- **golf_course**: Mountain ranges with sky gradient
- **forest**: Tree layers with forest sky
- **desert**: Sand dunes with desert sky  
- **ocean**: Ocean waves with shore line

## File Structure

```
ParallaxBackground.gd          # Core parallax system
ParallaxBackground.tscn        # Scene file for parallax system
BackgroundManager.gd           # Theme manager
test_parallax_background.gd    # Test script
test_parallax_background.tscn  # Test scene
```

## Integration with Existing Game

The system is designed to work with the existing camera system:

- **Camera Panning**: Background layers respond to middle-mouse camera panning
- **Z-Index System**: Uses the existing z-index system (background layers at -200 to -100)
- **Performance**: Optimized to work with the existing performance systems

## Customization

### Adding New Themes

1. Add theme definition to `BackgroundManager.gd`:
```gdscript
"new_theme": {
    "layers": [
        {
            "name": "LayerName",
            "texture_path": "res://path/to/texture.png",
            "parallax_factor": 0.3,
            "z_index": -150,
            "scale": Vector2(1.0, 1.0),
            "repeat_horizontal": true,
            "repeat_vertical": false
        }
    ]
}
```

2. Create texture files in the `Backgrounds/` folder
3. Use `background_manager.set_theme("new_theme")`

### Adjusting Parallax Factors

- **0.0**: Static (no movement) - good for sky
- **0.1-0.2**: Very slow movement - distant objects
- **0.3-0.5**: Slow movement - mid-distance objects  
- **0.6-0.8**: Medium movement - closer objects
- **1.0**: Full movement - same as camera

## Testing

Use the test scene (`test_parallax_background.tscn`) to:

- **Test Themes**: Press arrow keys to switch themes
- **Cycle Themes**: Press spacebar to cycle through all themes
- **Camera Movement**: Watch automatic camera movement or use middle-mouse to pan
- **Zoom**: Use mouse wheel to test zoom effects

## Performance Considerations

- **Update Threshold**: Only updates when camera moves more than 5 pixels
- **Texture Repeating**: Efficient horizontal repeating for wide backgrounds
- **Layer Management**: Automatic cleanup when switching themes
- **Memory Usage**: Fallback textures prevent crashes when files are missing

## Troubleshooting

### Common Issues

1. **No Background Visible**: Check that camera reference is set correctly
2. **Layers Not Moving**: Verify parallax factors are not all 0.0
3. **Missing Textures**: System will create colored fallback textures
4. **Z-Index Conflicts**: Ensure background z-indices are below game objects (-200 to -100)

### Debug Information

```gdscript
# Get background system info
var info = background_manager.get_background_info()
print("Current theme: ", info.current_theme)
print("Layer count: ", info.layer_count)
print("Available themes: ", info.available_themes)
```

## Future Enhancements

- **Animated Backgrounds**: Add support for animated sprites
- **Weather Effects**: Integrate with weather system
- **Time of Day**: Dynamic lighting changes
- **Custom Shaders**: Add visual effects to background layers
- **Background Music**: Theme-specific ambient sounds 