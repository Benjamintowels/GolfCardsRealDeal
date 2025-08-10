extends Node2D

signal wet_tile_completed(tile_position: Vector2i)

var tile_position: Vector2i = Vector2i.ZERO

var water_sound: AudioStreamPlayer2D

func _ready():
    # Play water sound once on creation
    water_sound = get_node_or_null("WaterEffect")
    if water_sound and water_sound.stream:
        water_sound.play()
    _apply_wet_tint()

func set_tile_position(pos: Vector2i):
    tile_position = pos

func get_tile_position() -> Vector2i:
    return tile_position

func _apply_wet_tint():
    # Find the original tile sprite and darken blue
    var course = get_tree().current_scene
    if not course:
        return
    if "obstacle_map" in course:
        var obstacle_map = course.obstacle_map
        if obstacle_map.has(tile_position):
            var tile = obstacle_map[tile_position]
            if tile and tile.has_node("Sprite2D"):
                var s: Sprite2D = tile.get_node("Sprite2D")
                # Darken blue hue similar to ice but stronger blue
                s.modulate = Color(0.5, 0.7, 1.0, 1.0)


