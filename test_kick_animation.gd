extends Node2D

@onready var player: Node2D = $Player
@onready var test_button: Button = $TestButton

func _ready():
	print("=== KICK ANIMATION TEST SCENE READY ===")
	test_button.pressed.connect(_on_test_button_pressed)

func _on_test_button_pressed():
	print("=== TEST KICK ANIMATION BUTTON PRESSED ===")
	if player and player.has_method("start_kick_animation"):
		player.start_kick_animation()
		print("✓ Kick animation test started")
	else:
		print("✗ Player or kick animation method not found") 