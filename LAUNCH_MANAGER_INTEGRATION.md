# LaunchManager Integration Guide

This guide shows how to integrate the new LaunchManager script with the existing course_1.gd file to clean up the launch mechanics.

## Step 1: Add LaunchManager to course_1.gd

Add the following to the top of course_1.gd after the existing @onready variables:

```gdscript
@onready var launch_manager: LaunchManager = $LaunchManager
```

## Step 2: Remove Launch Variables from course_1.gd

Remove these variables from course_1.gd (they're now handled by LaunchManager):

```gdscript
# Remove these variables:
var golf_ball: Node2D = null
var power_meter: Control = null
var height_meter: Control = null
var launch_power := 0.0
var launch_height := 0.0
var launch_direction := Vector2.ZERO
var is_charging := false
var is_charging_height := false
const MAX_LAUNCH_POWER := 1200.0
const MIN_LAUNCH_POWER := 300.0
const POWER_CHARGE_RATE := 300.0
const MAX_LAUNCH_HEIGHT := 480.0   # 10 cells (48 * 10) for pixel perfect system
const MIN_LAUNCH_HEIGHT := 144.0   # 3 cells (48 * 3) for pixel perfect system
const HEIGHT_CHARGE_RATE := 600.0  # Adjusted for pixel perfect system
const HEIGHT_SWEET_SPOT_MIN := 0.4
const HEIGHT_SWEET_SPOT_MAX := 0.6
var charge_time := 0.0
var max_charge_time := 3.0
var original_aim_mouse_pos: Vector2 = Vector2.ZERO
var launch_spin: float = 0.0
var current_charge_mouse_pos: Vector2 = Vector2.ZERO
var spin_indicator: Line2D = null
var power_for_target := 0.0
var max_power_for_bar := 0.0
```

## Step 3: Initialize LaunchManager in _ready()

Add this to the _ready() function in course_1.gd:

```gdscript
func _ready():
    # ... existing code ...
    
    # Initialize LaunchManager
    launch_manager.camera_container = camera_container
    launch_manager.ui_layer = ui_layer
    launch_manager.player_node = player_node
    launch_manager.cell_size = cell_size
    launch_manager.camera = camera
    launch_manager.card_effect_handler = card_effect_handler
    
    # Connect signals
    launch_manager.ball_launched.connect(_on_ball_launched)
    launch_manager.launch_phase_entered.connect(_on_launch_phase_entered)
    launch_manager.launch_phase_exited.connect(_on_launch_phase_exited)
```

## Step 4: Update LaunchManager References

In the _process() function, replace the launch-related code with:

```gdscript
func _process(delta: float):
    # ... existing code ...
    
    # Update LaunchManager
    launch_manager.chosen_landing_spot = chosen_landing_spot
    launch_manager.selected_club = selected_club
    launch_manager.club_data = club_data
    launch_manager.player_stats = player_stats
    
    # Handle launch input
    if game_phase == "launch":
        for event in get_viewport().input_handler.get_events():
            if launch_manager.handle_input(event):
                break
```

## Step 5: Replace Launch Functions

Replace the existing launch functions with calls to LaunchManager:

```gdscript
func enter_launch_phase() -> void:
    launch_manager.enter_launch_phase()

func launch_golf_ball(direction: Vector2, charged_power: float, height: float):
    launch_manager.launch_golf_ball(direction, charged_power, height)

func show_power_meter():
    launch_manager.show_power_meter()

func hide_power_meter():
    launch_manager.hide_power_meter()

func show_height_meter():
    launch_manager.show_height_meter()

func hide_height_meter():
    launch_manager.hide_height_meter()

func update_spin_indicator():
    launch_manager.update_spin_indicator()
```

## Step 6: Add Signal Handlers

Add these signal handlers to course_1.gd:

```gdscript
func _on_ball_launched(ball: Node2D):
    # Set up ball properties that require course_1.gd references
    ball.map_manager = map_manager
    update_ball_y_sort(ball)
    play_swing_sound(ball.final_power if ball.has_method("get_final_power") else 0.0)
    
    # Connect ball signals
    ball.landed.connect(_on_golf_ball_landed)
    ball.out_of_bounds.connect(_on_golf_ball_out_of_bounds)
    ball.sand_landing.connect(_on_golf_ball_sand_landing)
    
    # Set camera following
    camera_following_ball = true
    
    # Handle card effects
    if sticky_shot_active and next_shot_modifier == "sticky_shot":
        ball.sticky_shot_active = true
        sticky_shot_active = false
        next_shot_modifier = ""
    
    if bouncey_shot_active and next_shot_modifier == "bouncey_shot":
        ball.bouncey_shot_active = true
        bouncey_shot_active = false
        next_shot_modifier = ""

func _on_launch_phase_entered():
    game_phase = "launch"

func _on_launch_phase_exited():
    game_phase = "ball_flying"
```

## Step 7: Update Input Handling

In the _input() function, replace launch input handling with:

```gdscript
func _input(event: InputEvent):
    # ... existing code ...
    
    if game_phase == "launch":
        if launch_manager.handle_input(event):
            return
```

## Step 8: Add LaunchManager Node

Add a LaunchManager node as a child of the main scene in the scene tree:

1. Right-click on the main scene node
2. Add Child Node
3. Search for "LaunchManager" and select it
4. Name it "LaunchManager"

## Benefits of This Refactoring

1. **Cleaner Code**: Launch mechanics are now isolated in their own class
2. **Better Organization**: Related functionality is grouped together
3. **Easier Maintenance**: Changes to launch mechanics only affect one file
4. **Reusability**: LaunchManager can be reused in other scenes if needed
5. **Reduced Complexity**: course_1.gd is now more focused on game flow and coordination

## Notes

- The LaunchManager handles all the complex launch calculations and UI
- The course_1.gd file now acts as a coordinator between different systems
- Signal connections maintain the same functionality while improving code organization
- All existing functionality should work exactly the same after integration 