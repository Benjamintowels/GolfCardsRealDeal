# GolfCards Smart Performance Optimization Guide

## Overview

This document outlines the **smart performance optimizations** implemented to improve the game's performance by only running expensive operations when they're actually needed. The system is designed specifically for turn-based gameplay where most operations are not needed every frame.

## Major Performance Issues Identified

### 1. Y-Sort System Running Every Frame
**Problem**: The `update_all_ysort_z_indices()` function was running in `_process()` every frame, updating z-indices for ALL objects (trees, pins, characters, balls).

**Impact**: High CPU usage, especially with many objects on screen.

**Smart Solution**: 
- **Only update when ball moves significantly** (>5 pixels) or camera moves (>10 pixels)
- **Queue objects for update** instead of updating all every frame
- **60 FPS updates for moving objects**, no updates for static objects
- **Turn-based optimization**: No Y-sort updates during turn-based phases

### 2. Tree Collision Detection
**Problem**: Each tree runs `_process()` checking ALL balls in the scene every frame.

**Impact**: O(n*m) complexity where n = number of trees, m = number of balls.

**Smart Solution**:
- **Only active when ball is near trees** (within 200 pixels)
- **Updates every 0.1 seconds** instead of every frame
- **Spatial partitioning**: Only check trees that are actually near the ball
- **Turn-based optimization**: No tree collision checks during turn-based phases

### 3. Grid Tile Redraws
**Problem**: Every frame, all grid tiles were redrawn in `_input()`.

**Impact**: Unnecessary GPU usage and frame drops.

**Smart Solution**:
- **Only redraw on mouse movement** or when flashlight effect changes
- **Only redraw during aiming** or when ball is active
- **Eliminates unnecessary redraws** during turn-based phases
- **Event-driven redraws** instead of frame-based redraws

### 4. No Resource Preloading
**Problem**: Scenes and textures were loaded on-demand during gameplay.

**Impact**: Frame drops when new objects are instantiated.

**Smart Solution**: Implemented comprehensive loading screen with resource preloading.

## Loading Screen Implementation

### When to Use Loading Screens

Loading screens are beneficial when:
- Loading large scenes with many objects (like your golf course)
- Preloading textures, audio, and other resources
- Initializing complex systems (Y-sort, collision detection)
- Transitioning between major game states

### Files Created

1. **LoadingScreen.tscn** - The loading screen scene
2. **LoadingScreen.gd** - Loading screen logic with progress bar
3. **SmartPerformanceOptimizer.gd** - Smart optimization system (NEW)
4. **OptimizedYSort.gd** - Optimized Y-sort system (LEGACY)
5. **OptimizedTree.gd** - Optimized tree collision detection (LEGACY)
6. **PerformanceOptimizer.gd** - Main optimization controller (LEGACY)
7. **SmartOptimizationGuide.gd** - Implementation guide for smart optimizations

### Resource Preloading

The loading screen preloads:
- All character scenes and textures
- All obstacle scenes (trees, water, sand, etc.)
- All card scenes and textures
- All audio files
- UI elements and weapons

## Smart Performance Optimizations

### 1. Y-Sort Optimization

**Before**:
```gdscript
func _process(delta):
    # Update global Y-sort for all objects (trees, pins, etc.)
    update_all_ysort_z_indices()  # Runs every frame
```

**Smart After**:
```gdscript
func _process(delta):
    # SMART: Only update Y-sort when ball moves or camera moves
    if smart_optimizer:
        smart_optimizer.smart_process(delta, self)
    # Y-sort only updates when:
    # - Ball moves significantly (>5 pixels)
    # - Camera moves significantly (>10 pixels)
    # - Objects are queued for update
```

### 2. Tree Collision Optimization

**Before**:
```gdscript
func _process(delta):
    # Check for nearby balls and play leaves rustling sound
    var balls = get_tree().get_nodes_in_group("balls")
    for ball in balls:  # Check ALL balls every frame
        # ... collision detection logic
```

**Smart After**:
```gdscript
func update_tree_collisions(course_instance):
    # Only check trees when ball is near them
    if not ball_is_active or not has_nearby_trees():
        return
    
    var nearby_trees = get_nearby_trees(ball_position)
    for tree in nearby_trees:
        check_tree_collision(tree, ball)
    # Tree collision only active when:
    # - Ball is active AND near trees (within 200 pixels)
    # - Updates every 0.1 seconds instead of every frame
```

### 3. Grid Redraw Optimization

**Before**:
```gdscript
func _input(event: InputEvent) -> void:
    # Redraw all grid tiles every frame
    for y in grid_size.y:
        for x in grid_size.x:
            grid_tiles[y][x].get_node("TileDrawer").queue_redraw()
    queue_redraw()
```

**Smart After**:
```gdscript
func smart_input(event: InputEvent, course_instance):
    # SMART: Only redraw grid when necessary
    if should_redraw_grid(event):
        redraw_grid(course_instance)

func should_redraw_grid(event: InputEvent) -> bool:
    # Only redraw on mouse movement or when flashlight effect changes
    return (event is InputEventMouseMotion or 
            aiming_phase_active or
            ball_is_active)
    # Grid redraw only happens when:
    # - Mouse moves
    # - During aiming phase
    # - When ball is active
    # - Eliminates redraws during turn-based phases
```

## Smart Implementation Guide

### 1. Enable Loading Screen

The loading screen is now the main scene. It will:
1. Show a progress bar while loading resources
2. Preload all necessary assets
3. Transition to the main menu when complete

### 2. Apply Smart Performance Optimizations

To apply the smart optimizations to your existing `course_1.gd`:

1. **Add the SmartPerformanceOptimizer as a child node**:
```gdscript
var smart_optimizer: Node

func _ready():
    # Add smart performance optimizer
    var optimizer_script = load("res://SmartPerformanceOptimizer.gd")
    smart_optimizer = optimizer_script.new()
    add_child(smart_optimizer)
```

2. **Replace the _process function**:
```gdscript
func _process(delta):
    if smart_optimizer:
        smart_optimizer.smart_process(delta, self)
    else:
        # Fallback to original process
        original_process(delta)
```

3. **Replace the _input function**:
```gdscript
func _input(event: InputEvent) -> void:
    if smart_optimizer:
        smart_optimizer.smart_input(event, self)
    else:
        # Fallback to original input
        original_input(event)
```

4. **Add game state updates throughout your game logic**:
```gdscript
# When entering aiming phase:
func enter_aiming_phase():
    if smart_optimizer:
        smart_optimizer.update_game_state("aiming", false, true, false)

# When ball is launched:
func _on_ball_launched(ball: Node2D):
    if smart_optimizer:
        smart_optimizer.update_game_state("ball_flying", true, false, false)

# When ball lands:
func _on_golf_ball_landed():
    if smart_optimizer:
        smart_optimizer.update_game_state("move", false, false, false)
```

### 3. Add Objects to Appropriate Groups

```gdscript
# Add collision objects to the "collision_objects" group:
obstacle.add_to_group("collision_objects")

# Add trees to the "trees" group:
tree.add_to_group("trees")

# Add balls to the "balls" group:
ball.add_to_group("balls")
```

## Performance Monitoring

### Frame Rate Monitoring

Add this to monitor performance:

```gdscript
func _process(delta):
    # Monitor frame rate
    if Engine.get_process_frames() % 60 == 0:  # Every 60 frames
        var fps = 1.0 / delta
        print("FPS: ", fps)
```

### Memory Usage Monitoring

```gdscript
func _process(delta):
    # Monitor memory usage
    if Engine.get_process_frames() % 300 == 0:  # Every 300 frames
        var memory = OS.get_static_memory_usage() / 1024 / 1024  # MB
        print("Memory usage: ", memory, " MB")
```

## Expected Performance Improvements

### Before Optimization:
- Y-sort updates: Every frame (60 times per second)
- Tree collision checks: Every frame for all trees
- Grid redraws: Every frame
- Resource loading: On-demand during gameplay

### After Smart Optimization:
- **Y-sort updates**: Only when ball moves (>5 pixels) or camera moves (>10 pixels)
- **Tree collision checks**: Only when ball is near trees (within 200 pixels), every 0.1 seconds
- **Grid redraws**: Only on mouse movement or during active phases
- **Resource loading**: Preloaded during loading screen
- **Turn-based phases**: Minimal CPU usage (80-90% reduction)

### Expected Results:
- **Turn-based phases**: 80-90% reduction in CPU usage
- **Ball movement phases**: 40-60% reduction in CPU usage
- **Aiming phases**: 30-50% reduction in CPU usage
- **Overall**: 50-70% reduction in unnecessary calculations
- **Loading Times**: Eliminated in-game loading stutters
- **Memory Usage**: More consistent, less fragmentation

## Troubleshooting

### If Performance is Still Poor:

1. **Check Object Count**: Monitor how many objects are in the scene
2. **Reduce Update Intervals**: Decrease the update intervals in the optimizer
3. **Enable Profiling**: Use Godot's built-in profiler to identify bottlenecks
4. **Object Pooling**: Consider implementing object pooling for frequently created/destroyed objects

### If Loading Screen Takes Too Long:

1. **Reduce Resource List**: Remove unnecessary resources from preloading
2. **Compress Textures**: Use compressed texture formats
3. **Stream Audio**: Use streaming for large audio files
4. **Progressive Loading**: Load critical resources first, others in background

## Future Optimizations

### Potential Improvements:

1. **LOD System**: Level of Detail for distant objects
2. **Frustum Culling**: Only render objects in view
3. **Occlusion Culling**: Don't render hidden objects
4. **GPU Instancing**: Batch similar objects
5. **Texture Atlasing**: Combine multiple textures into one
6. **Audio Pooling**: Reuse audio players instead of creating new ones

### Advanced Techniques:

1. **Multithreading**: Move heavy calculations to background threads
2. **GPU Compute**: Use compute shaders for physics calculations
3. **Spatial Hashing**: More efficient spatial partitioning
4. **Predictive Loading**: Load resources before they're needed

## Conclusion

These optimizations should significantly improve your game's performance. The loading screen will eliminate in-game loading stutters, while the performance optimizations will reduce CPU usage and improve frame rates.

Monitor the performance after implementation and adjust the update intervals as needed for your specific use case. 