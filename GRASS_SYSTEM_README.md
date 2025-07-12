# Grass System

This system allows you to create multiple grass sprite variations for visual enhancement of the map. Grass elements are purely visual and don't affect gameplay - they just add variety to the environment with proper Y-sorting.

## How It Works

1. **GrassData Resource**: Each grass variation is defined by a `GrassData` resource file (`.tres`)
2. **GrassManager**: Automatically loads all grass variations and handles random selection
3. **Grass Integration**: Grass elements automatically apply random variations when placed

## File Structure

```
Obstacles/
├── GrassData.gd              # Resource script for grass variations
├── GrassManager.gd           # Manages grass variation loading and selection
├── GrassVariations/          # Folder containing all grass variation .tres files
│   ├── SummerGrass1.tres     # Summer grass variation 1
│   ├── SummerGrass2.tres     # Summer grass variation 2
│   └── [Future: Autumn/Winter grass]
├── GrassVariations/summer_grass.gd  # Grass element script
└── GrassVariations/SummerGrass.tscn # Grass scene file
```

## Adding New Grass Variations

### Step 1: Create Your Grass Sprite
1. Create your grass sprite image (PNG recommended)
2. Place it in the `Obstacles/` folder or a subfolder
3. Make sure it's similar in size to other grass sprites

### Step 2: Create a New .tres File
1. Right-click in the `Obstacles/GrassVariations/` folder
2. Select "New Resource"
3. Choose "GrassData" as the resource type
4. Save it with a descriptive name (e.g., `SummerGrass3.tres`)

### Step 3: Configure the GrassData
In the new `.tres` file, set these properties:
- **Name**: Display name for the grass (e.g., "SummerGrass3")
- **Sprite Texture**: Your grass sprite image
- **Rarity**: Weight for random selection (higher = more common)
  - Default: 1.0 (most common)
  - Uncommon: 0.6 (less frequent)
  - Rare: 0.4 (rare)
  - Very Rare: 0.3 (very rare)
- **Description**: Optional description
- **Height**: Height for Y-sorting (default: 15.0)
- **Seasons**: Array of seasons this grass appears in (e.g., ["summer"])

### Example GrassData Configuration
```gdscript
[resource]
script = ExtResource("1_grassdata")
name = "SummerGrass3"
sprite_texture = ExtResource("2_grass3")  # Your grass texture
rarity = 1.0
description = "A summer grass patch"
height = 15.0
seasons = ["summer"]
```

## How to Replace Placeholder Sprites

Currently, grass variations use the existing SummerGrass1.png and SummerGrass2.png as placeholders. To replace them:

1. **Create your grass sprite images**
2. **Update each .tres file**:
   - Open the `.tres` file in Godot
   - In the Inspector, click on "Sprite Texture"
   - Select your new grass sprite image
   - Save the file

### Example: Replacing SummerGrass1 Sprite
1. Create `SummerGrass1.png` with your grass sprite
2. Open `Obstacles/GrassVariations/SummerGrass1.tres`
3. Set "Sprite Texture" to `res://Obstacles/SummerGrass1.png`
4. Save the file

## Rarity System

The rarity system uses weighted random selection:
- **Higher rarity values** = more likely to be selected
- **Lower rarity values** = less likely to be selected

### Current Summer Grass Setup
- **SummerGrass1**: 1.0 (50% chance)
- **SummerGrass2**: 1.0 (50% chance)

### Future Season System
The system is designed to support seasonal grass variations:
- **Summer Grass**: Green, lush grass (current)
- **Autumn Grass**: Dried, brown grass
- **Winter Grass**: Snow-covered or sparse grass

### Recommended Rarity Values for Future Seasons
- **Common Variations**: 1.0 (equal distribution)
- **Uncommon Variations**: 0.6 (less frequent)
- **Rare Variations**: 0.4 (rare)
- **Very Rare Variations**: 0.3 (very rare)

## Testing the System

Run the test script to verify everything works:
```gdscript
# Attach test_grass_system.gd to a Node2D in a test scene
# Run the scene to see the GrassData variation system in action
```

## Technical Details

### GrassData Resource
- **Extends**: Resource
- **Class Name**: GrassData
- **Properties**: name, sprite_texture, rarity, description, height, seasons

### GrassManager
- **Extends**: Node
- **Class Name**: GrassManager
- **Functions**:
  - `get_random_grass_data()`: Returns random grass based on rarity
  - `get_grass_variation_by_name(name)`: Returns specific grass by name
  - `get_grass_variations_by_season(season)`: Returns all grass for a season
  - `get_all_grass_variations()`: Returns all available variations

### Grass Integration
- Grass elements automatically apply random variations when placed
- All Y-sorting mechanics remain identical
- Only the visual sprite changes
- No collision or gameplay effects

## Benefits

1. **Modular**: Easy to add/remove grass variations
2. **Performance**: No additional collision calculations
3. **Maintainable**: All grass logic in one place
4. **Scalable**: Add unlimited grass variations
5. **Consistent**: All grass elements behave identically
6. **Visual Enhancement**: Adds variety to the map without affecting gameplay

## Integration with Map System

To integrate grass elements into your map generation system:

1. **Create GrassManager instance**:
```gdscript
var grass_manager = GrassManager.new()
add_child(grass_manager)
```

2. **Get random grass data**:
```gdscript
var grass_data = grass_manager.get_random_grass_data()
```

3. **Apply to grass element**:
```gdscript
grass_element.set_grass_data(grass_data)
```

## Troubleshooting

### Grass Not Showing Variations
1. Check that GrassData files are in the correct folder
2. Verify GrassManager is being created
3. Check console for error messages

### Missing GrassData Script
1. Ensure `GrassData.gd` exists in `Obstacles/` folder
2. Check that the script extends Resource and has class_name GrassData

### Import Errors
1. Make sure all texture files are properly imported
2. Check file paths in .tres files
3. Verify UIDs are correct

### Y-Sorting Issues
1. Ensure grass elements have TopHeight and YsortPoint markers
2. Check that grass elements are added to the "objects" group
3. Verify Global.update_object_y_sort() is being called 