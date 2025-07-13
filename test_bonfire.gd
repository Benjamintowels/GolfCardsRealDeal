extends Node2D

@onready var bonfire: Node2D = $Bonfire
@onready var test_ball: CharacterBody2D = $TestBall

func _ready():
	# Test the bonfire functionality
	print("Bonfire test scene loaded")
	print("Bonfire height: ", bonfire.get_bonfire_height())
	print("Top height position: ", bonfire.get_top_height_position())
	print("Y-sort position: ", bonfire.get_ysort_position())

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				# Launch ball into air
				test_ball.launch_ball()
				print("Ball launched into air!")
			KEY_R:
				# Reset ball to ground
				test_ball.set_ball_height(0.0)
				test_ball.ball_velocity = Vector2(100, 0)
				print("Ball reset to ground level")
			KEY_1:
				# Set ball to low height (should hit bonfire)
				test_ball.set_ball_height(5.0)
				print("Ball set to low height (should hit bonfire)")
			KEY_2:
				# Set ball to high height (should pass over)
				test_ball.set_ball_height(15.0)
				print("Ball set to high height (should pass over)") 