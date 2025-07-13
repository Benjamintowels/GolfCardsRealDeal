extends Node2D

# Test script for Wraith Boss system

var test_wraith: Node = null
var test_boss_manager: Node = null

func _ready():
	print("=== WRAITH BOSS TEST ===")
	
	# Test 1: Spawn Wraith
	_test_spawn_wraith()
	
	# Test 2: Test Boss Manager
	_test_boss_manager()
	
	print("=== WRAITH BOSS TEST COMPLETE ===")

func _test_spawn_wraith():
	print("Test 1: Spawning Wraith...")
	
	# Load and instantiate Wraith
	var wraith_scene = preload("res://NPC/Bosses/Wraith.tscn")
	test_wraith = wraith_scene.instantiate()
	test_wraith.global_position = Vector2(100, 100)
	add_child(test_wraith)
	
	# Connect to signals
	test_wraith.boss_defeated.connect(_on_test_wraith_defeated)
	test_wraith.turn_completed.connect(_on_test_wraith_turn_completed)
	
	print("✓ Wraith spawned successfully")
	print("  - Health:", test_wraith.current_health, "/", test_wraith.max_health)
	print("  - Movement range:", test_wraith.movement_range)
	print("  - Position:", test_wraith.global_position)

func _test_boss_manager():
	print("Test 2: Testing Boss Manager...")
	
	# Load and instantiate BossManager
	var boss_manager_scene = preload("res://NPC/Bosses/BossManager.tscn")
	test_boss_manager = boss_manager_scene.instantiate()
	add_child(test_boss_manager)
	
	# Connect to signals
	test_boss_manager.boss_encounter_started.connect(_on_boss_encounter_started)
	test_boss_manager.boss_encounter_ended.connect(_on_boss_encounter_ended)
	
	print("✓ Boss Manager created successfully")
	print("  - Boss holes:", test_boss_manager.boss_holes)
	print("  - Current hole:", test_boss_manager.current_hole)

func _on_test_wraith_defeated():
	print("✓ Test Wraith defeated signal received")

func _on_test_wraith_turn_completed():
	print("✓ Test Wraith turn completed signal received")

func _on_boss_encounter_started(boss_type: String, hole_number: int):
	print("✓ Boss encounter started signal received")
	print("  - Boss type:", boss_type)
	print("  - Hole number:", hole_number)

func _on_boss_encounter_ended(boss_type: String, hole_number: int):
	print("✓ Boss encounter ended signal received")
	print("  - Boss type:", boss_type)
	print("  - Hole number:", hole_number)

# Test damage function
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_test_damage_wraith(10)
			KEY_2:
				_test_damage_wraith(50)
			KEY_3:
				_test_freeze_wraith()
			KEY_4:
				_test_boss_hole_check()

func _test_damage_wraith(damage: int):
	if test_wraith and test_wraith.is_alive:
		print("Testing damage:", damage)
		test_wraith.take_damage(damage)
		print("  - Current health:", test_wraith.current_health)

func _test_freeze_wraith():
	if test_wraith and test_wraith.is_alive:
		print("Testing freeze effect")
		test_wraith.freeze()
		print("  - Is frozen:", test_wraith.is_frozen)

func _test_boss_hole_check():
	if test_boss_manager:
		print("Testing boss hole check:")
		for hole in [1, 9, 18, 20]:
			var is_boss = test_boss_manager.is_boss_hole(hole)
			print("  - Hole", hole, "is boss hole:", is_boss) 