## Wiring circular obstacles for GolfBall collisions (roof-bounce)

This project uses a simple, height-aware, roof-bounce collision system for circular obstacles like boulders. A ball that is below an obstacle’s height reflects off it; a ball above the obstacle passes over but has its ground level raised to the obstacle’s height so it can “roof-bounce.”

### Implementing a new circular obstacle

1) Scene structure
- Add nodes:
  - Root `Node2D` (script attached)
  - `Area2D` with a `CollisionShape2D` using a CircleShape2D scaled to fit the obstacle
  - `Marker2D` named `TopHeight` to mark the visual top (used for height)
  - Optional `Marker2D` named `YsortPoint` for y-sorting
  - Optional `AnimationPlayer` if you need animations
  - Optional `AudioStreamPlayer2D` for collision sounds

2) Script base and groups
- Extend `BaseObstacle`.
- In `_ready()`, add to groups used by the ball system, typically:
  - `collision_objects`
  - Any obstacle-specific group (e.g., `boulders`, `scarecrows`)

3) Area2D wiring
- Set `Area2D.collision_layer = 1` and `collision_mask = 1` so the ball detects it.
- Connect `area_entered` and `area_exited` to your script.
- Only handle projectiles that don’t have their own collision systems (e.g., ThrowingKnife). Balls handle themselves and will call your handler.

4) Required methods
Implement the following methods to integrate with the GolfBall’s logic:

```gdscript
func get_collision_radius() -> float:
    return 50.0  # Adjust to taste, used by generic obstacle checks

func get_height() -> float:
    return Global.get_object_height_from_marker(self)  # Reads TopHeight

func _handle_roof_bounce_collision(projectile: Node2D) -> void:
    # If projectile height > obstacle height, set projectile ground to obstacle height
    # Else reflect the projectile’s velocity (wall reflect)

func _on_area_entered(area: Area2D) -> void:
    # For knives: call _handle_roof_bounce_collision(area.get_parent())
    # For balls: do nothing; ball calls your _handle_roof_bounce_collision directly

func _on_area_exited(area: Area2D) -> void:
    # Reset projectile ground level if needed
```

For reflection, you can mirror the Boulder logic:

```gdscript
var to_projectile = (projectile.global_position - global_position).normalized()
var reflected_velocity = projectile_velocity - 2.0 * projectile_velocity.dot(to_projectile) * to_projectile
reflected_velocity *= 0.8
reflected_velocity = reflected_velocity.rotated(randf_range(-0.1, 0.1))
```

5) Optional: play sounds and animations
- If your obstacle should react, play an animation and sound as part of the reflect path.
  - Example: `AnimationPlayer.play("shake")`, `AudioStreamPlayer2D.play()`

### ScareCrow specifics

- Script: `res://Obstacles/scare_crow.gd`
- Scene: `res://Obstacles/ScareCrow.tscn`
- Behavior: Same as boulder (circular roof-bounce). On impact below height, plays animation `"shake"` and sound node `"Thud"`.
- Group: `scarecrows`

### Ball integration notes

- The GolfBall checks for obstacle-specific hooks. If your obstacle implements `_handle_boulder_collision(projectile)`, the ball’s boulder branch will also work for you, but generally it calls `_handle_roof_bounce_collision(self)` on the obstacle.
- Ensure your obstacle is added to `collision_objects` and has an `Area2D` configured as above.

