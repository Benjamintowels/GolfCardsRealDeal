# Element System Documentation

## Overview
The element system allows golf balls to have visual element effects applied to them during shots. Elements are represented as sprites that appear on top of the golf ball and can have special visual effects.

## How It Works

### 1. Element Data Structure
- Elements are defined as `ElementData` resources in the `Elements/` folder
- Each element has a name, texture, and color
- Example: `Elements/Fire.tres` contains the Fire element data

### 2. Golf Ball Integration
- The `GolfBall.tscn` scene has an `Element` Sprite2D node
- The `GolfBall.gd` script manages element application and visual effects
- Elements are applied during ball launch and cleared when the ball lands

### 3. Card Integration
- ModifyNext cards can apply elements to the next shot
- The `CardEffectHandler.gd` processes element cards
- The `course_1.gd` script applies elements to balls during launch

## Current Elements

### Fire Element
- **Resource**: `Elements/Fire.tres`
- **Texture**: `Elements/Fire.png`
- **Card**: `Cards/FireBallCard.tres`
- **Effect**: Adds fire sprite to ball with flickering animation

## Adding New Elements

### 1. Create Element Data
1. Create a new `.tres` file in the `Elements/` folder
2. Set the script to `ElementData.gd`
3. Configure name, texture, and color properties

### 2. Create Element Card
1. Create a new card resource in the `Cards/` folder
2. Set `effect_type` to "ModifyNext"
3. Set `name` to match your element name

### 3. Add Card Handling
1. Add element handling to `CardEffectHandler.gd` in `handle_modify_next_card()`
2. Add element variable to `course_1.gd` (e.g., `ice_ball_active`)
3. Add element application logic in the ball launch section

### 4. Add Visual Effects (Optional)
1. Add element-specific effects in `GolfBall.gd` `update_visual_effects()`
2. Use the element name to apply custom animations or effects

## Example: Adding Ice Element

```gdscript
# 1. Create Elements/Ice.tres
[gd_resource type="Resource" script_class="ElementData" load_steps=3 format=3]
[ext_resource type="Script" path="res://Elements/ElementData.gd" id="1_ice"]
[ext_resource type="Texture2D" path="res://Elements/Ice.png" id="2_ice"]
[resource]
script = ExtResource("1_ice")
name = "Ice"
texture = ExtResource("2_ice")
color = Color(0.8, 0.9, 1.0, 1.0)

# 2. Add to CardEffectHandler.gd
elif card.name == "IceBall":
    course.ice_ball_active = true
    course.next_shot_modifier = "ice_ball"
    # ... rest of handling code

# 3. Add to course_1.gd ball launch section
if ice_ball_active and next_shot_modifier == "ice_ball":
    var ice_element = preload("res://Elements/Ice.tres")
    ball.set_element(ice_element)
    ice_ball_active = false
    next_shot_modifier = ""
```

## Technical Details

### Element Application Flow
1. Player plays element card → `CardEffectHandler` sets modifier
2. Player launches ball → `course_1.gd` applies element to ball
3. Ball flies with element sprite visible
4. Ball lands → element is cleared via `reset_shot_effects()`

### Visual Effects
- Elements appear on top of the ball sprite
- Element sprites follow ball position and scale
- Custom effects can be added per element type
- Elements are automatically cleared when ball lands

### Performance Considerations
- Element sprites are lightweight
- Visual effects are frame-rate independent
- Element system uses existing sprite infrastructure 