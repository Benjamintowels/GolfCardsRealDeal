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
    _maybe_spawn_mushroom()

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



func _maybe_spawn_mushroom():
    # Spawn a Mushroom when a U tile becomes wet
    var map_manager = get_tree().get_first_node_in_group("MapManager")
    if not map_manager:
        return
    if not map_manager.has_method("get_tile_type"):
        return
    var base_type: String = map_manager.get_tile_type(tile_position.x, tile_position.y)
    if base_type != "U":
        return

    # 25% chance to spawn to keep effect modest
    if randf() >= 0.25:
        return

    var course = get_tree().current_scene
    if not course:
        return
    var cell_size: int = 48
    if "cell_size" in course:
        cell_size = course.cell_size

    var mushroom_scene: PackedScene = preload("res://Interactables/Mushroom.tscn")
    var mushroom: Node2D = mushroom_scene.instantiate()
    var world_pos: Vector2 = Vector2(tile_position.x, tile_position.y) * float(cell_size)
    mushroom.position = world_pos + Vector2(float(cell_size) / 2.0, float(cell_size) / 2.0)
    if mushroom.has_method("set_grid_position"):
        mushroom.set_grid_position(tile_position)

    # Parent under obstacle_layer if present
    if "obstacle_layer" in course and course.obstacle_layer:
        course.obstacle_layer.add_child(mushroom)
    else:
        add_sibling(mushroom)

    # Ensure proper Y-sort
    if Engine.has_singleton("Global"):
        # Not used; in this project Global is a node autoload. Call by name instead
        pass
    var global_node = get_node_or_null("/root/Global")
    if global_node and global_node.has_method("update_object_y_sort"):
        global_node.update_object_y_sort(mushroom, "objects")

