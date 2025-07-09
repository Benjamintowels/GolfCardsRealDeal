extends Node2D

@onready var test_button: Button = $TestButton
@onready var damage_button: Button = $DamageButton
@onready var clear_block_button: Button = $ClearBlockButton

func _ready():
	test_button.pressed.connect(_on_test_block_pressed)
	damage_button.pressed.connect(_on_damage_pressed)
	clear_block_button.pressed.connect(_on_clear_block_pressed)

func _on_test_block_pressed():
	print("=== TESTING BLOCK SYSTEM ===")
	
	# Get the course scene
	var course = get_tree().current_scene
	if not course or not course.has_method("activate_block"):
		print("ERROR: Course not found or missing activate_block method")
		return
	
	# Test activating block with 25 points
	print("Activating block with 25 points...")
	course.activate_block(25)
	
	# Check if block is active
	if course.has_block():
		print("✓ Block is active with", course.get_block_amount(), "points")
	else:
		print("✗ Block is not active")

func _on_damage_pressed():
	print("=== TESTING DAMAGE TO BLOCK ===")
	
	var course = get_tree().current_scene
	if not course or not course.has_method("take_damage"):
		print("ERROR: Course not found or missing take_damage method")
		return
	
	# Take 15 damage (should be absorbed by block)
	print("Taking 15 damage...")
	course.take_damage(15)
	
	# Check remaining block
	if course.has_block():
		print("✓ Block still active with", course.get_block_amount(), "points remaining")
	else:
		print("✗ Block depleted")

func _on_clear_block_pressed():
	print("=== CLEARING BLOCK ===")
	
	var course = get_tree().current_scene
	if not course or not course.has_method("clear_block"):
		print("ERROR: Course not found or missing clear_block method")
		return
	
	course.clear_block()
	print("✓ Block cleared") 