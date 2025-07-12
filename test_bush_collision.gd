extends Node2D

# Test script for Bush Area2D collision system

func _ready():
	print("=== BUSH AREA2D COLLISION TEST ===")
	
	# Test bush scene loading
	var bush_scene = preload("res://Obstacles/Bush.tscn")
	var ball_scene = preload("res://GolfBall.tscn")
	
	if bush_scene and ball_scene:
		print("✓ Scenes loaded successfully")
		
		# Create bush
		var bush = bush_scene.instantiate()
		bush.position = Vector2(100, 100)
		add_child(bush)
		print("✓ Bush created at position:", bush.position)
		
		# Create golf ball
		var ball = ball_scene.instantiate()
		ball.position = Vector2(50, 100)  # Start to the left of the bush
		add_child(ball)
		print("✓ Golf ball created at position:", ball.position)
		
		# Set up ball properties
		ball.cell_size = 48
		ball.velocity = Vector2(100, 0)  # Move right towards the bush
		print("✓ Ball velocity set to:", ball.velocity)
		
		# Test collision layers
		var bush_area = bush.get_node_or_null("Area2D")
		var ball_area = ball.get_node_or_null("Area2D")
		
		if bush_area and ball_area:
			print("✓ Area2D nodes found")
			print("  Bush collision layer:", bush_area.collision_layer)
			print("  Bush collision mask:", bush_area.collision_mask)
			print("  Ball collision layer:", ball_area.collision_layer)
			print("  Ball collision mask:", ball_area.collision_mask)
			
			# Check if they should collide
			if (bush_area.collision_layer & ball_area.collision_mask) != 0:
				print("✓ Collision layers are compatible")
			else:
				print("✗ Collision layers are NOT compatible")
		else:
			print("✗ Area2D nodes not found")
		
		# Start the test after a short delay
		await get_tree().create_timer(1.0).timeout
		print("=== STARTING COLLISION TEST ===")
		
		# Move the ball towards the bush
		var tween = create_tween()
		tween.tween_property(ball, "position", Vector2(150, 100), 2.0)
		tween.tween_callback(_on_test_complete)
		
	else:
		print("✗ Scene loading failed")

func _on_test_complete():
	print("=== COLLISION TEST COMPLETE ===")
	print("If you saw bush collision debug messages above, the system is working!")
	print("If not, there may be an issue with the collision detection.")
	
	# Clean up
	queue_free() 