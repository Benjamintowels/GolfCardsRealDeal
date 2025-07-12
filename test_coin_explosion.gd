extends Node2D

# Test script for coin explosion system
# This will create a test NPC that can be killed to trigger coin explosions

@onready var test_npc: Node2D
@onready var coin_explosion_manager: Node

func _ready():
	print("=== COIN EXPLOSION TEST SCENE ===")
	
	# Get the coin explosion manager
	coin_explosion_manager = get_node_or_null("CoinExplosionManager")
	if coin_explosion_manager:
		print("✓ CoinExplosionManager found")
	else:
		print("✗ ERROR: CoinExplosionManager not found!")
	
	# Create a test button
	_create_test_button()

func _create_test_button():
	"""Create a test button to trigger coin explosions"""
	var button = Button.new()
	button.text = "Test Coin Explosion"
	button.position = Vector2(100, 100)
	button.pressed.connect(_on_test_button_pressed)
	add_child(button)
	
	print("✓ Test button created")

func _on_test_button_pressed():
	"""Handle test button press - trigger coin explosion"""
	print("=== TESTING COIN EXPLOSION ===")
	
	if coin_explosion_manager:
		# Trigger coin explosion at a test position
		var test_position = Vector2(400, 300)
		coin_explosion_manager.create_coin_explosion(test_position, 5)
		print("✓ Coin explosion triggered at:", test_position)
	else:
		print("✗ ERROR: CoinExplosionManager not available!")

func _input(event):
	"""Handle input for testing"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				# Space bar triggers coin explosion at mouse position
				var mouse_pos = get_global_mouse_position()
				if coin_explosion_manager:
					coin_explosion_manager.create_coin_explosion(mouse_pos, 3)
					print("✓ Coin explosion triggered at mouse position:", mouse_pos)
			KEY_1:
				# Key 1 triggers small explosion
				var center_pos = Vector2(400, 300)
				if coin_explosion_manager:
					coin_explosion_manager.create_coin_explosion(center_pos, 3)
					print("✓ Small coin explosion triggered")
			KEY_2:
				# Key 2 triggers large explosion
				var center_pos = Vector2(400, 300)
				if coin_explosion_manager:
					coin_explosion_manager.create_coin_explosion(center_pos, 10)
					print("✓ Large coin explosion triggered") 