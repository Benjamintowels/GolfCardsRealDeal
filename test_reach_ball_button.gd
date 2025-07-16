extends Node2D

@onready var reach_ball_button: Control = $UI/ReachBallButton

func _ready():
	print("=== TESTING REACH BALL BUTTON ===")
	
	# Connect to the button signal
	if reach_ball_button:
		reach_ball_button.reach_ball_pressed.connect(_on_reach_ball_button_pressed)
		print("✓ Connected to reach_ball_pressed signal")
	else:
		print("✗ ReachBallButton not found")

func _on_reach_ball_button_pressed():
	print("✓ ReachBallButton pressed signal received!")
	
	# Test the button functionality
	print("Testing button visibility methods:")
	reach_ball_button.hide_button()
	print("  - Button hidden")
	await get_tree().create_timer(1.0).timeout
	
	reach_ball_button.show_button()
	print("  - Button shown")
	await get_tree().create_timer(1.0).timeout
	
	reach_ball_button.hide_button()
	print("  - Button hidden again")
	
	print("✓ ReachBallButton test completed successfully!")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				print("Space pressed - toggling button visibility")
				if reach_ball_button.visible:
					reach_ball_button.hide_button()
				else:
					reach_ball_button.show_button()
			KEY_ENTER:
				print("Enter pressed - testing should_show_button method")
				var should_show = reach_ball_button.should_show_button()
				print("  should_show_button() returned:", should_show) 