# NPC Setup Guide - Complete Collision System Implementation

This guide documents the complete process for setting up a new NPC character with proper collision detection, damage handling, and all required functionality. This was successfully implemented for the Wraith boss character.

## Overview

When creating a new NPC that should collide with golf balls, you need to implement the exact same collision system that the GangMember uses. This ensures consistent behavior and prevents collision detection issues.

## Prerequisites

- NPC scene file (`.tscn`)
- NPC script file (`.gd`)
- Basic sprite and animation setup
- Health bar system (optional but recommended)

## Step 1: Scene File Setup (Area2D Configuration)

### 1.1 Add Collision Areas
In your NPC scene file, ensure you have the following Area2D nodes:

```gdscript
[node name="BodyArea2D" type="Area2D" parent="."]
position = Vector2(0.5, 3.5)

[node name="CollisionShape2D" type="CollisionShape2D" parent="BodyArea2D"]
# Configure collision shape as needed
```

**CRITICAL**: The collision area MUST be named `BodyArea2D` (not `NPCBodyArea2D` or similar). The golf ball's collision detection specifically looks for areas named `BodyArea2D` to distinguish them from vision areas.

### 1.2 Optional: Ice State Collision
If your NPC supports ice/freeze effects, add a separate ice collision area:

```gdscript
[node name="NPCIce" type="Node2D" parent="."]
# Ice sprite and collision setup

[node name="BodyArea2D" type="Area2D" parent="NPCIce"]
# Note: Also named BodyArea2D for consistency

[node name="CollisionShape2D" type="CollisionShape2D" parent="NPCIce/BodyArea2D"]
```

## Step 2: Script Setup (Core Methods)

### 2.1 Required Constants and Variables
Add these to your NPC script:

```gdscript
# Headshot mechanics
const HEADSHOT_MIN_HEIGHT = 150.0  # Minimum height for headshot (150-200 range)
const HEADSHOT_MAX_HEIGHT = 200.0  # Maximum height for headshot (150-200 range)
const HEADSHOT_MULTIPLIER = 1.5    # Damage multiplier for headshots

# Health and damage properties
var max_health: int = 30
var current_health: int = 30
var is_alive: bool = true
var is_dead: bool = false

# Collision references
var base_collision_area: Area2D
var ice_sprite: Sprite2D
var ice_collision_area: Area2D
```

### 2.2 Setup Methods
Add these setup methods to your `_ready()` function:

```gdscript
func _ready():
    # Add to groups for smart optimization and roof bounce system
    add_to_group("collision_objects")
    add_to_group("NPC")
    
    # Setup collision areas
    _setup_base_collision()
    _setup_ice_references()
    
    # Create health bar
    _create_health_bar()

func _setup_base_collision() -> void:
    """Setup the base collision area for ball collisions"""
    base_collision_area = get_node_or_null("BodyArea2D")
    if base_collision_area:
        # Set collision layer to 1 so golf balls can detect it
        base_collision_area.collision_layer = 1
        # Set collision mask to 1 so it can detect golf balls on layer 1
        base_collision_area.collision_mask = 1
        # Connect to area_entered and area_exited signals for collision detection
        base_collision_area.connect("area_entered", _on_base_area_entered)
        base_collision_area.connect("area_exited", _on_area_exited)
        print("✓ NPC base collision area setup complete")
    else:
        print("✗ ERROR: BodyArea2D not found!")

func _setup_ice_references() -> void:
    """Setup references to ice sprite and collision areas"""
    ice_sprite = get_node_or_null("NPCIce")
    ice_collision_area = get_node_or_null("NPCIce/BodyArea2D")
    
    if ice_sprite:
        print("✓ Ice sprite reference found")
    else:
        print("✗ ERROR: NPCIce sprite not found!")
    
    if ice_collision_area:
        print("✓ Ice collision area reference found and disabled")
    else:
        print("✗ ERROR: NPCIce/BodyArea2D not found!")
```

### 2.3 Collision Detection Methods
Add these essential collision detection methods:

```gdscript
func _on_base_area_entered(area: Area2D) -> void:
    """Handle collisions with the base collision area"""
    var projectile = area.get_parent()
    if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
        # Handle the collision using proper Area2D collision detection
        _handle_area_collision(projectile)

func _on_area_exited(area: Area2D) -> void:
    """Handle when projectile exits the NPC area - reset ground level"""
    var projectile = area.get_parent()
    if projectile and projectile.has_method("get_height"):
        # Reset the projectile's ground level to normal (0.0)
        if projectile.has_method("_reset_ground_level"):
            projectile._reset_ground_level()
        else:
            # Fallback: directly reset ground level if method doesn't exist
            if "current_ground_level" in projectile:
                projectile.current_ground_level = 0.0

func _handle_area_collision(projectile: Node2D):
    """Handle NPC area collisions using proper Area2D detection"""
    print("=== HANDLING NPC AREA COLLISION ===")
    print("Projectile name:", projectile.name)
    print("Projectile type:", projectile.get_class())
    
    # Check if projectile has height information
    if not projectile.has_method("get_height"):
        print("✗ Projectile doesn't have height method - using fallback reflection")
        _reflect_projectile(projectile)
        return
    
    # Get projectile and NPC heights
    var projectile_height = projectile.get_height()
    var npc_height = Global.get_object_height_from_marker(self)
    
    print("Projectile height:", projectile_height)
    print("NPC height:", npc_height)
    
    # Check if this is a throwing knife (special handling)
    if projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
        _handle_knife_area_collision(projectile, projectile_height, npc_height)
        return
    
    # Apply the collision logic:
    # If projectile height > NPC height: allow entry and set ground level
    # If projectile height < NPC height: deal damage and reflect
    if projectile_height > npc_height:
        print("✓ Projectile is above NPC - allowing entry and setting ground level")
        _allow_projectile_entry(projectile, npc_height)
    else:
        print("✗ Projectile is below NPC height - dealing damage and reflecting")
        # Deal damage first, then reflect
        _handle_ball_collision(projectile)
```

### 2.4 Core Collision Handling Methods
Add these methods that handle the actual collision logic:

```gdscript
func _handle_ball_collision(ball: Node2D) -> void:
    """Handle ball/knife collisions - check height to determine if ball/knife should pass through"""
    print("Handling ball/knife collision - checking ball/knife height")
    
    # IMPORTANT: Handle collisions directly, don't use Entities system to avoid cooldown issues
    # Use enhanced height collision detection with TopHeight markers
    if Global.is_object_above_obstacle(ball, self):
        # Ball/knife is above NPC entirely - let it pass through
        print("Ball/knife is above NPC entirely - passing through")
        return
    else:
        # Ball/knife is within or below NPC height - handle collision
        print("Ball/knife is within NPC height - handling collision")
        
        # Check if this is a throwing knife
        if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
            # Handle knife collision with NPC
            _handle_knife_collision(ball)
        else:
            # Handle regular ball collision
            _handle_regular_ball_collision(ball)

func _handle_regular_ball_collision(ball: Node2D) -> void:
    """Handle regular ball collision with NPC"""
    print("Handling regular ball collision with NPC")
    
    # Play collision sound effect
    _play_collision_sound()
    
    # Apply collision effect to the ball
    _apply_ball_collision_effect(ball)

func _handle_knife_collision(knife: Node2D) -> void:
    """Handle knife collision with NPC"""
    print("Handling knife collision with NPC")
    
    # Play collision sound effect
    _play_collision_sound()
    
    # Check for ice element and apply freeze effect
    if knife.has_method("get_element"):
        var knife_element = knife.get_element()
        if knife_element and knife_element.name == "Ice":
            print("Ice element detected on knife! Applying freeze effect")
            freeze()
    
    # Let the knife handle its own collision logic
    if knife.has_method("_handle_npc_collision"):
        knife._handle_npc_collision(self)
    else:
        # Fallback: just reflect the knife
        _apply_knife_reflection(knife)
```

### 2.5 Damage Calculation Methods
Add these methods for calculating and applying damage:

```gdscript
func _apply_ball_collision_effect(ball: Node2D) -> void:
    """Apply collision effect to the ball (bounce, damage, etc.)"""
    # Check if this is a ghost ball (shouldn't deal damage)
    var is_ghost_ball = false
    if ball.has_method("is_ghost"):
        is_ghost_ball = ball.is_ghost
    elif "is_ghost" in ball:
        is_ghost_ball = ball.is_ghost
    elif ball.name == "GhostBall":
        is_ghost_ball = true
    
    if is_ghost_ball:
        print("Ghost ball detected - no damage dealt, just reflection")
        # Ghost balls only reflect, no damage
        _reflect_projectile(ball)
        return
    
    # Get the ball's current velocity
    var ball_velocity = Vector2.ZERO
    if ball.has_method("get_velocity"):
        ball_velocity = ball.get_velocity()
    elif "velocity" in ball:
        ball_velocity = ball.velocity
    
    print("Applying collision effect to ball with velocity:", ball_velocity)
    
    # Get ball height for headshot detection
    var ball_height = 0.0
    if ball.has_method("get_height"):
        ball_height = ball.get_height()
    elif "z" in ball:
        ball_height = ball.z
    
    # Check if this is a headshot
    var is_headshot = _is_headshot(ball_height)
    var damage_multiplier = HEADSHOT_MULTIPLIER if is_headshot else 1.0
    
    # Calculate base damage based on ball velocity
    var base_damage = _calculate_velocity_damage(ball_velocity.length())
    
    # Apply headshot multiplier if applicable
    var damage = int(base_damage * damage_multiplier)
    
    if is_headshot:
        print("HEADSHOT! Ball height:", ball_height, "Base damage:", base_damage, "Final damage:", damage)
    else:
        print("Body shot. Ball height:", ball_height, "Damage:", damage)
    
    # Check for ice element and apply freeze effect
    if ball.has_method("get_element"):
        var ball_element = ball.get_element()
        if ball_element and ball_element.name == "Ice":
            print("Ice element detected! Applying freeze effect")
            freeze()
    
    # Check if this damage will kill the NPC
    var will_kill = damage >= current_health
    var overkill_damage = 0
    
    if will_kill:
        # Calculate overkill damage (negative health value)
        overkill_damage = damage - current_health
        print("Damage will kill NPC! Overkill damage:", overkill_damage)
        
        # Apply damage to the NPC (this will set health to negative)
        take_damage(damage, is_headshot)
        
        # Apply velocity dampening based on overkill damage
        var dampened_velocity = _calculate_kill_dampening(ball_velocity, overkill_damage)
        print("Ball passed through with dampened velocity:", dampened_velocity)
        
        # Apply the dampened velocity to the ball (no reflection)
        if ball.has_method("set_velocity"):
            ball.set_velocity(dampened_velocity)
        elif "velocity" in ball:
            ball.velocity = dampened_velocity
    else:
        # Normal collision - apply damage and reflect
        take_damage(damage, is_headshot)
        _reflect_projectile(ball)

func _calculate_velocity_damage(velocity_magnitude: float) -> int:
    """Calculate damage based on ball velocity magnitude"""
    # Define velocity ranges for damage scaling
    const MIN_VELOCITY = 25.0  # Minimum velocity for 1 damage
    const MAX_VELOCITY = 1200.0  # Maximum velocity for 88 damage
    
    # Clamp velocity to our defined range
    var clamped_velocity = clamp(velocity_magnitude, MIN_VELOCITY, MAX_VELOCITY)
    
    # Calculate damage percentage (0.0 to 1.0)
    var damage_percentage = (clamped_velocity - MIN_VELOCITY) / (MAX_VELOCITY - MIN_VELOCITY)
    
    # Scale damage from 1 to 88
    var damage = 1 + (damage_percentage * 87)
    
    # Return as integer
    var final_damage = int(damage)
    
    print("=== VELOCITY DAMAGE CALCULATION ===")
    print("Raw velocity magnitude:", velocity_magnitude)
    print("Clamped velocity:", clamped_velocity)
    print("Damage percentage:", damage_percentage)
    print("Calculated damage:", damage)
    print("Final damage (int):", final_damage)
    print("=== END VELOCITY DAMAGE CALCULATION ===")
    
    return final_damage

func _calculate_kill_dampening(ball_velocity: Vector2, overkill_damage: int) -> Vector2:
    """Calculate velocity dampening when ball kills an NPC"""
    # Define dampening ranges
    const MIN_OVERKILL = 1  # Minimum overkill for maximum dampening
    const MAX_OVERKILL = 60  # Maximum overkill for minimum dampening
    
    # Clamp overkill damage to our defined range
    var clamped_overkill = clamp(overkill_damage, MIN_OVERKILL, MAX_OVERKILL)
    
    # Calculate dampening factor (0.0 = no dampening, 1.0 = maximum dampening)
    # Higher overkill = less dampening (ball keeps more speed)
    var dampening_percentage = 1.0 - ((clamped_overkill - MIN_OVERKILL) / (MAX_OVERKILL - MIN_OVERKILL))
    
    # Apply dampening factor to velocity
    # Maximum dampening reduces velocity to 20% of original
    # Minimum dampening reduces velocity to 80% of original
    var dampening_factor = 0.2 + (dampening_percentage * 0.6)  # 0.2 to 0.8 range
    var dampened_velocity = ball_velocity * dampening_factor
    
    print("=== KILL DAMPENING CALCULATION ===")
    print("Overkill damage:", overkill_damage)
    print("Clamped overkill:", clamped_overkill)
    print("Dampening percentage:", dampening_percentage)
    print("Dampening factor:", dampening_factor)
    print("Original velocity magnitude:", ball_velocity.length())
    print("Dampened velocity magnitude:", dampened_velocity.length())
    print("=== END KILL DAMPENING CALCULATION ===")
    
    return dampened_velocity
```

### 2.6 Headshot Detection Methods
Add these methods for headshot functionality:

```gdscript
func _is_headshot(ball_height: float) -> bool:
    """Check if a ball/knife hit is a headshot based on height"""
    # Headshot occurs when the ball/knife hits in the head region (150-200 height)
    return ball_height >= HEADSHOT_MIN_HEIGHT and ball_height <= HEADSHOT_MAX_HEIGHT

func get_headshot_info() -> Dictionary:
    """Get information about the headshot system for debugging and UI"""
    return {
        "min_height": HEADSHOT_MIN_HEIGHT,
        "max_height": HEADSHOT_MAX_HEIGHT,
        "multiplier": HEADSHOT_MULTIPLIER,
        "total_height": Global.get_object_height_from_marker(self),
        "headshot_range": HEADSHOT_MAX_HEIGHT - HEADSHOT_MIN_HEIGHT
    }
```

### 2.7 Damage and Health Methods
Add these methods for handling damage and health:

```gdscript
func take_damage(damage: int, is_headshot: bool = false) -> void:
    """Take damage and handle death"""
    if is_dead or is_frozen:
        return
    
    print("=== NPC TAKING DAMAGE ===")
    print("Damage:", damage)
    print("Current health:", current_health)
    
    current_health -= damage
    
    # Play hurt sound
    if has_method("_play_hurt_sound"):
        _play_hurt_sound()
    
    # Update health bar
    var health_bar = get_node_or_null("HealthBar")
    if health_bar and health_bar.has_method("update_health"):
        health_bar.update_health(current_health)
    
    print("New health:", current_health)
    
    # Check for death
    if current_health <= 0:
        die()
    else:
        # Visual feedback for taking damage
        if is_headshot:
            flash_headshot()
        else:
            flash_damage()

func flash_damage() -> void:
    """Flash the sprite to indicate damage taken"""
    if sprite:
        var tween = create_tween()
        tween.tween_property(sprite, "modulate", Color.RED, 0.1)
        tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func flash_headshot() -> void:
    """Flash the NPC with a special headshot effect"""
    if not sprite:
        return
    
    var original_modulate = sprite.modulate
    var tween = create_tween()
    # Flash with a bright gold color for headshots
    tween.tween_property(sprite, "modulate", Color(1, 0.84, 0, 1), 0.15)  # Bright gold
    tween.tween_property(sprite, "modulate", Color(1, 0.65, 0, 1), 0.1)   # Deeper gold
    tween.tween_property(sprite, "modulate", original_modulate, 0.2)

func die() -> void:
    """Handle the NPC's death"""
    print("=== NPC DEATH ===")
    is_dead = true
    is_alive = false
    
    # Play death sound
    _play_death_sound()
    
    # Trigger coin explosion
    _trigger_coin_explosion()
    
    # Handle death animation/state
    _handle_death_state()

func _play_death_sound() -> void:
    """Play the death sound when the NPC dies"""
    # Use the existing audio player on the NPC
    var death_audio = get_node_or_null("DeathSound")
    if death_audio:
        death_audio.volume_db = 0.0  # Set to full volume
        death_audio.play()
    else:
        pass

func _trigger_coin_explosion() -> void:
    """Trigger a coin explosion when the NPC dies"""
    # Use the static method from CoinExplosionManager
    CoinExplosionManager.trigger_coin_explosion(global_position)
    print("✓ Triggered coin explosion for NPC at:", global_position)
```

### 2.8 Sound and Reflection Methods
Add these methods for sound effects and projectile reflection:

```gdscript
func _play_collision_sound() -> void:
    """Play a sound effect when colliding with the player"""
    # Try to find an audio player in the course
    if course:
        var audio_players = course.get_tree().get_nodes_in_group("audio_players")
        if audio_players.size() > 0:
            var audio_player = audio_players[0]
            if audio_player.has_method("play"):
                audio_player.play()
                return
        
        # Try to find Push sound specifically
        var push_sound = course.get_node_or_null("Push")
        if push_sound and push_sound is AudioStreamPlayer2D:
            push_sound.play()
            return
    
    # Fallback: create a temporary audio player
    var temp_audio = AudioStreamPlayer2D.new()
    var sound_file = load("res://Sounds/Push.mp3")
    if sound_file:
        temp_audio.stream = sound_file
        temp_audio.volume_db = -10.0  # Slightly quieter
        add_child(temp_audio)
        temp_audio.play()
        # Remove the audio player after it finishes
        temp_audio.finished.connect(func(): temp_audio.queue_free())

func _reflect_projectile(projectile: Node2D) -> void:
    """Reflect projectile off the NPC"""
    print("=== REFLECTING PROJECTILE ===")
    
    # Get projectile height for freeze effect logic
    var projectile_height = 0.0
    if projectile.has_method("get_height"):
        projectile_height = projectile.get_height()
    
    var npc_height = Global.get_object_height_from_marker(self)
    
    # Only apply freeze effect if projectile is below NPC height (wall bounces)
    # This handles the case where ball hits NPC's body and reflects
    if projectile_height < npc_height:
        # Check for ice element and apply freeze effect (for wall bounces)
        if projectile.has_method("get_element"):
            var projectile_element = projectile.get_element()
            if projectile_element and projectile_element.name == "Ice":
                print("Ice element detected on projectile reflection (wall bounce)! Applying freeze effect")
                freeze()
    
    # Play collision sound for NPC collision
    _play_collision_sound()
    
    # Get the projectile's current velocity
    var projectile_velocity = Vector2.ZERO
    if projectile.has_method("get_velocity"):
        projectile_velocity = projectile.get_velocity()
    elif "velocity" in projectile:
        projectile_velocity = projectile.velocity
    
    print("Reflecting projectile with velocity:", projectile_velocity)
    
    var projectile_pos = projectile.global_position
    var npc_center = global_position
    
    # Calculate the direction from NPC center to projectile
    var to_projectile_direction = (projectile_pos - npc_center).normalized()
    
    # Simple reflection: reflect the velocity across the NPC center
    var reflected_velocity = projectile_velocity - 2 * projectile_velocity.dot(to_projectile_direction) * to_projectile_direction
    
    # Reduce speed slightly to prevent infinite bouncing
    reflected_velocity *= 0.8
    
    # Add a small amount of randomness to prevent infinite loops
    var random_angle = randf_range(-0.1, 0.1)
    reflected_velocity = reflected_velocity.rotated(random_angle)
    
    print("Reflected velocity:", reflected_velocity)
    
    # Apply the reflected velocity to the projectile
    if projectile.has_method("set_velocity"):
        projectile.set_velocity(reflected_velocity)
    elif "velocity" in projectile:
        projectile.velocity = reflected_velocity

func _apply_knife_reflection(knife: Node2D) -> void:
    """Apply reflection effect to a knife (fallback method)"""
    # Play collision sound effect
    _play_collision_sound()
    
    # Check for ice element and apply freeze effect
    if knife.has_method("get_element"):
        var knife_element = knife.get_element()
        if knife_element and knife_element.name == "Ice":
            print("Ice element detected on knife reflection! Applying freeze effect")
            freeze()
    
    # Get the knife's current velocity
    var knife_velocity = Vector2.ZERO
    if knife.has_method("get_velocity"):
        knife_velocity = knife.get_velocity()
    elif "velocity" in knife:
        knife_velocity = knife.velocity
    
    print("Applying knife reflection with velocity:", knife_velocity)
    
    var knife_pos = knife.global_position
    var npc_center = global_position
    
    # Calculate the direction from NPC center to knife
    var to_knife_direction = (knife_pos - npc_center).normalized()
    
    # Simple reflection: reflect the velocity across the NPC center
    var reflected_velocity = knife_velocity - 2 * knife_velocity.dot(to_knife_direction) * to_knife_direction
    
    # Reduce speed slightly to prevent infinite bouncing
    reflected_velocity *= 0.8
    
    # Add a small amount of randomness to prevent infinite loops
    var random_angle = randf_range(-0.1, 0.1)
    reflected_velocity = reflected_velocity.rotated(random_angle)
    
    print("Reflected knife velocity:", reflected_velocity)
    
    # Apply the reflected velocity to the knife
    if knife.has_method("set_velocity"):
        knife.set_velocity(reflected_velocity)
    elif "velocity" in knife:
        knife.velocity = reflected_velocity
```

### 2.9 Projectile Entry Methods
Add these methods for handling projectiles that pass over the NPC:

```gdscript
func _allow_projectile_entry(projectile: Node2D, npc_height: float) -> void:
    """Allow projectile to enter NPC area and set ground level"""
    print("=== ALLOWING PROJECTILE ENTRY (NPC) ===")
    
    # Get projectile height for freeze effect logic
    var projectile_height = 0.0
    if projectile.has_method("get_height"):
        projectile_height = projectile.get_height()
    
    # Only apply freeze effect if projectile is above NPC height
    # This handles the case where ball bounces off roof and lands on NPC's head
    if projectile_height > npc_height:
        # Check for ice element and apply freeze effect (for roof bounces landing on head)
        if projectile.has_method("get_element"):
            var projectile_element = projectile.get_element()
            if projectile_element and projectile_element.name == "Ice":
                print("Ice element detected on projectile landing (roof bounce)! Applying freeze effect")
                freeze()
    
    # Set the projectile's ground level to the NPC height
    if projectile.has_method("_set_ground_level"):
        projectile._set_ground_level(npc_height)
    else:
        # Fallback: directly set ground level if method doesn't exist
        if "current_ground_level" in projectile:
            projectile.current_ground_level = npc_height
            print("✓ Set projectile ground level to NPC height:", npc_height)
    
    # The projectile will now land on the NPC's head instead of passing through
    # When it exits the area, _on_area_exited will reset the ground level

func _handle_knife_area_collision(knife: Node2D, knife_height: float, npc_height: float) -> void:
    """Handle knife collision with NPC area"""
    print("Handling knife NPC area collision")
    
    if knife_height > npc_height:
        print("✓ Knife is above NPC - allowing entry and setting ground level")
        _allow_projectile_entry(knife, npc_height)
    else:
        print("✗ Knife is below NPC height - reflecting")
        _reflect_projectile(knife)
```

### 2.10 Entities System Integration
Add this method for compatibility with the Entities system:

```gdscript
func handle_ball_collision(ball: Node2D) -> void:
    """Handle collision with a ball - called by Entities system"""
    _handle_ball_collision(ball)
```

## Step 3: Height and Collision Methods

Add these methods for proper height detection and collision shape information:

```gdscript
func get_height() -> float:
    """Get the height of this NPC for collision detection"""
    # Use ice height marker when frozen
    if is_frozen and ice_top_height_marker:
        return ice_top_height_marker.global_position.y
    else:
        return Global.get_object_height_from_marker(self)

func get_y_sort_point() -> float:
    # Use ice Y-sort point when frozen
    if is_frozen and ice_ysort_point:
        return ice_ysort_point.global_position.y
    else:
        var ysort_point_node = get_node_or_null("YsortPoint")
        if ysort_point_node:
            return ysort_point_node.global_position.y
        else:
            return global_position.y

func get_base_collision_shape() -> Dictionary:
    """Get the base collision shape dimensions for this NPC"""
    return {
        "width": 10.0,
        "height": 6.5,
        "offset": Vector2(0, 25)  # Offset from NPC center to base
    }

func get_collision_radius() -> float:
    """Get the collision radius for this NPC"""
    return 30.0  # NPC collision radius
```

## Step 4: Freeze Effect System (Optional)

If your NPC supports freeze effects, add these methods:

```gdscript
# Freeze effect properties
var is_frozen: bool = false
var freeze_turns_remaining: int = 0
var original_modulate: Color

func freeze() -> void:
    """Apply freeze effect to the NPC"""
    if is_frozen or is_dead:
        return
    
    is_frozen = true
    freeze_turns_remaining = 3  # Freeze for 3 turns
    print("NPC frozen for", freeze_turns_remaining, "turns!")
    
    # Play freeze sound
    if has_method("_play_freeze_sound"):
        _play_freeze_sound()
    
    # Switch to ice sprite and collision
    _switch_to_ice_state()

func thaw() -> void:
    """Remove freeze effect from the NPC"""
    if not is_frozen:
        return
    
    is_frozen = false
    freeze_turns_remaining = 0
    print("NPC thawed!")
    
    # Switch back to normal sprite and collision
    _switch_to_normal_state()

func _switch_to_ice_state() -> void:
    """Switch to ice sprite and collision state"""
    print("=== SWITCHING TO ICE STATE ===")
    
    # Hide the normal sprite
    if sprite:
        sprite.visible = false
        print("✓ Hidden normal sprite")
    
    # Show the ice sprite
    if ice_sprite:
        ice_sprite.visible = true
        # Apply the same facing direction to the ice sprite
        _update_ice_sprite_facing()
        print("✓ Showed ice sprite")
    else:
        print("✗ ERROR: Ice sprite not found!")
    
    # Disable normal collision area
    if base_collision_area:
        base_collision_area.monitoring = false
        base_collision_area.monitorable = false
        print("✓ Disabled normal collision area")
    
    # Enable ice collision area
    if ice_collision_area:
        ice_collision_area.monitoring = true
        ice_collision_area.monitorable = true
        # Set collision layer to 1 so golf balls can detect it
        ice_collision_area.collision_layer = 1
        # Set collision mask to 1 so it can detect golf balls on layer 1
        ice_collision_area.collision_mask = 1
        # Connect to area_entered and area_exited signals for collision detection
        if not ice_collision_area.is_connected("area_entered", _on_base_area_entered):
            ice_collision_area.connect("area_entered", _on_base_area_entered)
        if not ice_collision_area.is_connected("area_exited", _on_area_exited):
            ice_collision_area.connect("area_exited", _on_area_exited)
        print("✓ Enabled ice collision area")
    else:
        print("✗ ERROR: Ice collision area not found!")
    
    print("✓ Ice state switch complete")

func _switch_to_normal_state() -> void:
    """Switch back to normal sprite and collision state"""
    print("=== SWITCHING TO NORMAL STATE ===")
    
    # Hide the ice sprite
    if ice_sprite:
        ice_sprite.visible = false
        print("✓ Hidden ice sprite")
    
    # Show the normal sprite
    if sprite:
        sprite.visible = true
        # Restore original modulate
        sprite.modulate = original_modulate
        # Update facing direction
        _update_sprite_facing()
        print("✓ Showed normal sprite")
    else:
        print("✗ ERROR: Normal sprite not found!")
    
    # Disable ice collision area
    if ice_collision_area:
        ice_collision_area.monitoring = false
        ice_collision_area.monitorable = false
        print("✓ Disabled ice collision area")
    
    # Enable normal collision area
    if base_collision_area:
        base_collision_area.monitoring = true
        base_collision_area.monitorable = true
        print("✓ Enabled normal collision area")
    else:
        print("✗ ERROR: Normal collision area not found!")
    
    print("✓ Normal state switch complete")
```

## Step 5: Testing and Verification

### 5.1 Test Collision Detection
1. Launch a golf ball at your NPC
2. Verify that the ball collides properly when below NPC height
3. Verify that the ball passes through when above NPC height
4. Check that damage is applied correctly
5. Verify that headshots work properly

### 5.2 Test Sound Effects
1. Verify collision sounds play when ball hits NPC
2. Verify death sounds play when NPC dies
3. Verify freeze sounds play when NPC is frozen

### 5.3 Test Visual Effects
1. Verify damage flash effects work
2. Verify headshot flash effects work
3. Verify ice state visual changes work (if applicable)

## Common Issues and Solutions

### Issue: Ball doesn't collide with NPC
**Solution**: Check that the collision area is named exactly `BodyArea2D` (not `NPCBodyArea2D` or similar)

### Issue: Collision is prevented by Entities system
**Solution**: Make sure `_handle_ball_collision` handles collisions directly instead of going through the Entities system

### Issue: NPC doesn't take damage
**Solution**: Verify that `take_damage` method is implemented and called correctly

### Issue: No sound effects
**Solution**: Check that `_play_collision_sound` and `_play_death_sound` methods are implemented

### Issue: Headshots don't work
**Solution**: Verify that `_is_headshot` method is implemented and `take_damage` accepts the `is_headshot` parameter

## Summary

This complete setup ensures that your NPC will have:
- ✅ Proper collision detection with golf balls
- ✅ Height-based collision logic (pass through vs. damage)
- ✅ Velocity-based damage calculation
- ✅ Headshot detection and damage multiplier
- ✅ Sound effects for collisions and death
- ✅ Visual feedback (damage flash, headshot flash)
- ✅ Coin explosion on death
- ✅ Freeze effect support (optional)
- ✅ Knife collision handling
- ✅ Ghost ball handling
- ✅ Overkill damage and velocity dampening

By following this guide, you'll have a fully functional NPC that behaves consistently with the existing GangMember system. 