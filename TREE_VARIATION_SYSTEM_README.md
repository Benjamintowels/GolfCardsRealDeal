# Tree Variation System

This system allows you to create multiple tree sprite variations while keeping all collision mechanics identical. It uses `.tres` resource files for easy management and modularity.

## How It Works

1. **TreeData Resource**: Each tree variation is defined by a `TreeData` resource file (`.tres`)
2. **TreeManager**: Automatically loads all tree variations and handles random selection
3. **Tree Integration**: Trees automatically apply random variations when placed

## File Structure

```
Obstacles/
├── TreeData.gd              # Resource script for tree variations
├── TreeManager.gd           # Manages tree variation loading and selection
├── Tree.gd                  # Modified to support TreeData
├── TreeVariations/          # Folder containing all tree variation .tres files
│   ├── TreeSummer1.tres     # Summer tree variation 1
│   ├── TreeSummer2.tres     # Summer tree variation 2
│   ├── TreeSummer3.tres     # Summer tree variation 3
│   └── [Future: Autumn/Winter trees]
```

## Adding New Tree Variations

### Step 1: Create Your Tree Sprite
1. Create your tree sprite image (PNG recommended)
2. Place it in the `Obstacles/` folder or a subfolder
3. Make sure it's similar in size and collision area to the original tree

### Step 2: Create a New .tres File
1. Right-click in the `Obstacles/TreeVariations/` folder
2. Select "New Resource"
3. Choose "TreeData" as the resource type
4. Save it with a descriptive name (e.g., `TreeBirch.tres`)

### Step 3: Configure the TreeData
In the new `.tres` file, set these properties:
- **Name**: Display name for the tree (e.g., "Birch Tree")
- **Sprite Texture**: Your tree sprite image
- **Rarity**: Weight for random selection (higher = more common)
  - Default: 1.0 (most common)
  - Pine: 0.8 (common)
  - Oak: 0.6 (uncommon)
  - Maple: 0.4 (rare)
  - Palm: 0.3 (very rare)
- **Description**: Optional description

### Example TreeData Configuration
```gdscript
[resource]
script = ExtResource("2_tree")
name = "Birch Tree"
sprite_texture = ExtResource("1_birch")  # Your birch tree texture
rarity = 0.5
description = "A white birch tree"
```

## How to Replace Placeholder Sprites

Currently, all tree variations use the default tree sprite as a placeholder. To replace them:

1. **Create your tree sprite images**
2. **Update each .tres file**:
   - Open the `.tres` file in Godot
   - In the Inspector, click on "Sprite Texture"
   - Select your new tree sprite image
   - Save the file

### Example: Replacing Pine Tree Sprite
1. Create `TreePine.png` with your pine tree sprite
2. Open `Obstacles/TreeVariations/TreePine.tres`
3. Set "Sprite Texture" to `res://Obstacles/TreePine.png`
4. Save the file

## Rarity System

The rarity system uses weighted random selection:
- **Higher rarity values** = more likely to be selected
- **Lower rarity values** = less likely to be selected

### Current Summer Tree Setup
- **SummerTree1**: 1.0 (33% chance)
- **SummerTree2**: 1.0 (33% chance) 
- **SummerTree3**: 1.0 (33% chance)

### Future Season System
The system is designed to support seasonal tree variations:
- **Summer Trees**: Green, leafy trees (current)
- **Autumn Trees**: Orange/red/yellow fall colors
- **Winter Trees**: Snow-covered or bare branches

### Recommended Rarity Values for Future Seasons
- **Common Variations**: 1.0 (equal distribution)
- **Uncommon Variations**: 0.6 (less frequent)
- **Rare Variations**: 0.4 (rare)
- **Very Rare Variations**: 0.3 (very rare)

## Testing the System

Run the test script to verify everything works:
```gdscript
# Attach test_summer_trees.gd to a Node2D in a test scene
# Run the scene to see the SummerTree variation system in action
```

## Technical Details

### TreeData Resource
- **Extends**: Resource
- **Class Name**: TreeData
- **Properties**: name, sprite_texture, rarity, description

### TreeManager
- **Extends**: Node
- **Class Name**: TreeManager
- **Functions**:
  - `get_random_tree_data()`: Returns random tree based on rarity
  - `get_tree_variation_by_name(name)`: Returns specific tree by name
  - `get_all_tree_variations()`: Returns all available variations

### Tree Integration
- Trees automatically apply random variations when placed
- All collision mechanics remain identical
- Only the visual sprite changes

## Benefits

1. **Modular**: Easy to add/remove tree variations
2. **Performance**: No additional collision calculations
3. **Maintainable**: All tree logic in one place
4. **Scalable**: Add unlimited tree variations
5. **Consistent**: All trees behave identically

## Troubleshooting

### Trees Not Showing Variations
1. Check that TreeData files are in the correct folder
2. Verify TreeManager is being created
3. Check console for error messages

### Missing TreeData Script
1. Ensure `TreeData.gd` exists in `Obstacles/` folder
2. Check that the script extends Resource and has class_name TreeData

### Import Errors
1. Make sure all texture files are properly imported
2. Check file paths in .tres files
3. Verify UIDs are correct 