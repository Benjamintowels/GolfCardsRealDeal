extends Node2D

# Test script for RedJay effect
var red_jay_scene = preload("res://NPC/Animals/RedJay.tscn")
var ball_scene = preload("res://GolfBall.tscn")

func _ready():
	# Create a test ball
	var ball = ball_scene.instantiate()
	ball.position = Vector2(400, 300)
	add_child(ball)
	
	# Create a mock pin position
	var pin_position = Vector2(600, 300)
	
	# Create RedJay effect
	var red_jay = red_jay_scene.instantiate()
	red_jay.position = Vector2(200, 200)
	add_child(red_jay)
	
	# Start the effect
	red_jay.start_red_jay_effect(ball, pin_position)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			# Restart the test
			get_tree().reload_current_scene() 