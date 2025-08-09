extends Node2D

# GolfSmith NPC for world map and fight rooms
# - Collides with GolfBall via BodyArea2D like other NPCs
# - Participates in WorldTurn with highest priority
# - Global Y-sort using `YSortPoint`
# - Simple AI: moves away from nearest enemy; if enemy within 2 tiles, attack for 45
# - Can block: switch to block sprite and use a BlockHealthBar-style shield for 30, reset each world turn

signal turn_completed

@onready var sprite_default: Sprite2D = $GolfSmithSprite
@onready var sprite_block: Sprite2D = $GolfSmithBlockSprite
@onready var body_area: Area2D = $BodyArea2D
@onready var top_height: Marker2D = $TopHeight
@onready var ysort_point: Marker2D = $YSortPoint
@onready var hitbox: Area2D = $HitBox

var grid_position: Vector2i = Vector2i.ZERO
var grid_pos: Vector2i = Vector2i.ZERO
var cell_size: int = 48

var is_alive: bool = true
var is_dead: bool = false

# Turn/movement
var is_moving: bool = false
var movement_tween: Tween
var movement_duration: float = 0.3

# AI
var movement_range: int = 1
var vision_range: int = 12
var attack_range: int = 2
var attack_damage: int = 45

# References
var course: Node = null
var entities_manager: Node = null
var world_turn_manager: Node = null
var player: Node = null

# Blocking
var block_active: bool = false
var block_amount: int = 0
var max_block_amount: int = 30
var block_bar: BlockHealthBar = null
var block_bar_container: Control = null

func _ready():
	add_to_group("NPC")
	add_to_group("collision_objects")
	_find_course_and_refs()
	_setup_body_collision()
	_create_block_bar()
	call_deferred("_late_ready")

func _late_ready() -> void:
	# Register with managers after the scene tree settles
	if world_turn_manager:
		world_turn_manager.register_npc(self)
		if not world_turn_manager.world_turn_started.is_connected(_on_world_turn_started):
			world_turn_manager.world_turn_started.connect(_on_world_turn_started)
	if entities_manager and entities_manager.has_method("register_npc"):
		entities_manager.register_npc(self)

	# Set initial ysort
	update_z_index_for_ysort()

func _find_course_and_refs() -> void:
	# Find course (course_1.gd) up the tree
	var current: Node = self
	while current:
		if current.get_script() and current.get_script().resource_path.ends_with("course_1.gd"):
			course = current
			break
		current = current.get_parent()
	# Fallback to scene root
	if not course and get_tree().current_scene and get_tree().current_scene.get_script() and get_tree().current_scene.get_script().resource_path.ends_with("course_1.gd"):
		course = get_tree().current_scene

	if course:
		entities_manager = course.get_node_or_null("Entities")
		# Try different paths for world_turn_manager
		var paths: Array[String] = ["WorldTurnManager", "NPC/WorldTurnManager", "NPC/world_turn_manager"]
		for p in paths:
			if course.has_node(p):
				world_turn_manager = course.get_node(p)
				break
		if course.has_method("get_player_reference"):
			player = course.get_player_reference()
		elif course.player_manager and course.player_manager.get_player_node():
			player = course.player_manager.get_player_node()

func _setup_body_collision() -> void:
	if not body_area:
		return
	body_area.collision_layer = 1
	body_area.collision_mask = 1
	if not body_area.is_connected("area_entered", _on_body_area_entered):
		body_area.connect("area_entered", _on_body_area_entered)
	if not body_area.is_connected("area_exited", _on_body_area_exited):
		body_area.connect("area_exited", _on_body_area_exited)
	# Ensure hitbox is discoverable by weapon systems
	if hitbox:
		hitbox.collision_layer = 2
		hitbox.collision_mask = 0
		hitbox.add_to_group("hitboxes")

func _create_block_bar() -> void:
	block_bar_container = Control.new()
	block_bar_container.name = "BlockBarContainer"
	block_bar_container.custom_minimum_size = Vector2(60.0, 30.0)
	block_bar_container.size = Vector2(60.0, 30.0)
	block_bar_container.position = Vector2(-30.0, 10.0)
	block_bar_container.scale = Vector2(0.35, 0.35)
	add_child(block_bar_container)
	var scene: PackedScene = preload("res://BlockHealthBar.tscn")
	block_bar = scene.instantiate()
	block_bar_container.add_child(block_bar)
	block_bar.clear_block()

# WorldTurn hooks
func _on_world_turn_started() -> void:
	# Reset per-turn things (e.g., clear residual block from last round of hits)
	if block_active:
		clear_block()

func take_turn() -> void:
	if is_dead or not is_alive:
		turn_completed.emit()
		return
	# Defensive AI: always move away from nearest enemy and block
	var enemy_pos: Variant = _get_nearest_enemy_grid_pos()
	_move_away_from(enemy_pos)
	# Raise block for the coming player/enemy actions (visual + mitigation)
	activate_block(max_block_amount)
	# End of this unit's turn
	turn_completed.emit()

func _get_nearest_enemy_grid_pos() -> Variant:
	# Enemies are typical hostile NPCs (GangMember, ZombieGolfer, Police)
	var nearest: Variant = null
	var best_dist: float = INF
	var scene_nodes: Array = get_tree().get_nodes_in_group("NPC")
	for n in scene_nodes:
		if n == self:
			continue
		if not is_instance_valid(n):
			continue
		if not n.has_method("get_grid_position"):
			continue
		# Consider anything with a typical hostile script name as enemy
		var spath: String = n.get_script().resource_path if n.get_script() else ""
		if spath.find("GangMember.gd") == -1 and spath.find("ZombieGolfer.gd") == -1 and spath.find("police.gd") == -1:
			continue
		var pos: Vector2i = n.get_grid_position()
		var d: float = grid_position.distance_to(pos)
		if d < best_dist:
			best_dist = d
			nearest = pos
	return nearest

func _attack_enemy_at(_enemy_grid_pos: Vector2i) -> void:
	# Disabled: Golfsmith is defensive-only now
	pass

func _move_away_from(threat_grid_pos: Variant) -> void:
	if threat_grid_pos == null:
		# No threat found: small random wiggle within movement_range
		var candidates: Array[Vector2i] = _get_adjacent_positions()
		if not candidates.is_empty():
			var choice: Vector2i = candidates[randi() % candidates.size()]
			if _is_position_free(choice):
				_move_to(choice)
		return
	var best: Vector2i = grid_position
	var best_dist: float = grid_position.distance_to(threat_grid_pos)
	var steps: int = min(movement_range, 3)
	# Greedy: try adjacent positions that increase distance
	for i in range(steps):
		var improved := false
		for p in _get_adjacent_positions_from(best):
			if not _is_position_free(p):
				continue
			var d: float = p.distance_to(threat_grid_pos)
			if d > best_dist:
				best_dist = d
				best = p
				improved = true
		if not improved:
			break
	if best != grid_position:
		_move_to(best)

func _get_adjacent_positions() -> Array[Vector2i]:
	return _get_adjacent_positions_from(grid_position)

func _get_adjacent_positions_from(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		result.append(origin + d)
	return result

func _is_position_free(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		return false
	if player and "grid_pos" in player and player.grid_pos == pos:
		return false
	if course and course.has_method("is_position_occupied_by_entity"):
		if course.is_position_occupied_by_entity(pos):
			return false
	return true

func _move_to(target_grid: Vector2i) -> void:
	grid_position = target_grid
	grid_pos = target_grid
	var target_world: Vector2 = Vector2(target_grid.x, target_grid.y) * float(cell_size) + Vector2(float(cell_size) / 2.0, float(cell_size) / 2.0)
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
	is_moving = true
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_QUAD)
	movement_tween.set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(self, "position", target_world, movement_duration)
	movement_tween.tween_callback(update_z_index_for_ysort)
	movement_tween.tween_callback(_on_move_done)

func _on_move_done() -> void:
	is_moving = false

# Collision with ball
func _on_body_area_entered(area: Area2D) -> void:
	var obj = area.get_parent()
	if not obj:
		return
	# Ignore vision areas
	if area.name == "VisionArea2D":
		return
	# GolfBall or ThrowingKnife-like objects call _handle_ball_collision
	if obj.has_method("get_height"):
		_handle_ball_collision(obj)

func _on_body_area_exited(area: Area2D) -> void:
	var obj = area.get_parent()
	if not obj:
		return
	# Reset ground level if needed
	if obj.has_method("_reset_ground_level"):
		obj._reset_ground_level()
	elif "current_ground_level" in obj:
		obj.current_ground_level = 0.0

func handle_ball_collision(ball: Node2D) -> void:
	_handle_ball_collision(ball)

func _handle_ball_collision(ball: Node2D) -> void:
	# Prefer Entities system if present (handles moving-NPC push, velocity damage, etc.)
	if entities_manager and entities_manager.has_method("handle_npc_ball_collision"):
		entities_manager.handle_npc_ball_collision(self, ball)
		return
	# Fallback: velocity-based damage handling similar to Police/GangMember
	if Global.is_object_above_obstacle(ball, self):
		return
	_apply_default_velocity_damage(ball)

func _apply_default_velocity_damage(ball: Node2D) -> void:
	var vel: Vector2 = Vector2.ZERO
	if ball.has_method("get_velocity"):
		vel = ball.get_velocity()
	elif "velocity" in ball:
		vel = ball.velocity
	var dmg: int = _calculate_velocity_damage(vel.length())
	take_damage(dmg)
	# reflect slightly
	var reflected: Vector2 = -vel * 0.8
	if ball.has_method("set_velocity"):
		ball.set_velocity(reflected)
	elif "velocity" in ball:
		ball.velocity = reflected

func _calculate_velocity_damage(mag: float) -> int:
	const MIN_V := 25.0
	const MAX_V := 1200.0
	var c: float = clamp(mag, MIN_V, MAX_V)
	var pct: float = (c - MIN_V) / (MAX_V - MIN_V)
	var dmg: float = 1.0 + (pct * 87.0)
	return int(dmg)

# Damage and block
func take_damage(amount: int) -> void:
	if not is_alive:
		return
	var remaining: int = amount
	if block_active and block_bar and block_bar.has_block():
		remaining = block_bar.take_block_damage(amount)
		block_amount = block_bar.get_block_amount()
		if not block_bar.has_block():
			clear_block()
	if remaining <= 0:
		return
	# Apply simple health logic: if any damage gets through block, Golfsmith dies
	_die()

func activate_block(amount: int) -> void:
	block_active = true
	block_amount = amount
	if block_bar:
		block_bar.set_block(amount, amount)
	if sprite_default and sprite_block:
		sprite_default.visible = false
		sprite_block.visible = true

func clear_block() -> void:
	block_active = false
	block_amount = 0
	if block_bar:
		block_bar.clear_block()
	if sprite_default and sprite_block:
		sprite_default.visible = true
		sprite_block.visible = false

# Grid helpers / integration
func get_grid_position() -> Vector2i:
	return grid_position

func set_grid_position(pos: Vector2i) -> void:
	grid_position = pos
	grid_pos = pos
	position = Vector2(pos.x, pos.y) * float(cell_size) + Vector2(float(cell_size) / 2.0, float(cell_size) / 2.0)
	update_z_index_for_ysort()

func get_height() -> float:
	if top_height:
		return top_height.global_position.y
	return global_position.y - 92.0

func get_y_sort_point() -> float:
	if ysort_point:
		return ysort_point.global_position.y
	return global_position.y

func update_z_index_for_ysort() -> void:
	Global.update_object_y_sort(self, "characters")

# Priority helper so systems can give this NPC highest priority
func get_script_path() -> String:
	return get_script().resource_path if get_script() else ""

func _die() -> void:
	if not is_alive:
		return
	is_alive = false
	is_dead = true
	# Switch to dead visuals
	if sprite_default:
		sprite_default.visible = false
	if sprite_block:
		sprite_block.visible = false
	var dead_sprite: Sprite2D = get_node_or_null("GolfSmithDeadSprite")
	if dead_sprite:
		dead_sprite.visible = true
	# Play death sound
	var death_audio: AudioStreamPlayer2D = get_node_or_null("DeathGroan")
	if death_audio:
		death_audio.play()
	# Blood explosion effect
	_spawn_blood_explosion()
	# Fade out then cleanup
	_fade_and_cleanup()
	# Unregister from Entities if present
	if entities_manager and entities_manager.has_method("unregister_npc"):
		entities_manager.unregister_npc(self)

func _spawn_blood_explosion() -> void:
	var scene: PackedScene = preload("res://Interactables/BloodExplosion.tscn")
	var fx: Node2D = scene.instantiate()
	fx.global_position = global_position
	get_tree().current_scene.add_child(fx)
	if fx.has_method("trigger"):
		fx.trigger()

func _fade_and_cleanup() -> void:
	var tween := create_tween()
	# Fade the whole node
	tween.tween_property(self, "modulate:a", 0.0, 0.9)
	tween.tween_callback(func(): queue_free())

# Spawning helpers
static func should_spawn_this_round() -> bool:
	# If Golfsmith questline is completed, do not spawn on random holes
	if Engine.has_singleton("SaveFileManager"):
		var save = Engine.get_singleton("SaveFileManager")
		if save and save.has_method("get_npc_quest_progress"):
			return save.get_npc_quest_progress("golfsmith") < 100
	return true

# Allow enemies to prefer chasing whichever is closer (player or golfsmith) by providing grid pos
func get_preferred_target_grid_pos() -> Vector2i:
	return grid_position

# Utility to deal melee damage to hostile NPCs around us
func _deal_melee_damage_in_radius(_radius: int) -> void:
	# Disabled: Golfsmith no longer attacks
	pass
