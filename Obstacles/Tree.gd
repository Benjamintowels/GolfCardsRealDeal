extends CharacterBody2D

var blocks_movement := true  # Trees block by default; water might not

func blocks(): 
	return blocks_movement

# Returns the Y-sorting reference point (base of trunk)
func get_y_sort_point() -> float:
	# The node's global_position.y is the base of the trunk due to the Y offset
	return global_position.y

func _ready():
	# Connect to Area2D's area_entered signal for collision detection with Area2D balls
	var area2d = get_node_or_null("Area2D")
	if area2d:
		area2d.connect("area_entered", _on_area_entered)
		print("Tree _ready called - Area2D collision detection set up")
		print("Tree Area2D found and ready for collision detection")
	else:
		print("ERROR: Tree Area2D not found!")

func _on_area_entered(area: Area2D):
	# Check if the colliding area belongs to a golf ball
	# Area2D -> Sprite2D -> GolfBall/GhostBall
	var ball = area.get_parent().get_parent()
	print("Tree collision detected! Area entered:", area.name)
	print("Ball node:", ball.name if ball else "No ball found")
	if ball and (ball.name == "GolfBall" or ball.name == "GhostBall"):
		print("Valid ball collision detected!")
		_handle_ball_collision(ball)
	else:
		print("Invalid ball collision - ball name:", ball.name if ball else "No ball")

func _handle_ball_collision(ball: Node2D):
	# Get the ball's height
	var ball_height = 0.0
	if ball.has_method("get_height"):
		ball_height = ball.get_height()
	elif "z" in ball:
		ball_height = ball.z
	
	# Set tree height (same as in Y-sorting)
	var tree_height = 100.0
	
	# Only reflect if ball is not higher than the tree
	if ball_height < tree_height:
		_reflect_ball(ball)
		print("Tree collision: Ball reflected off tree trunk")

func _reflect_ball(ball: Node2D):
	# Get the ball's current velocity
	var ball_velocity = Vector2.ZERO
	if ball.has_method("get_velocity"):
		ball_velocity = ball.get_velocity()
	elif "velocity" in ball:
		ball_velocity = ball.velocity
	
	# Calculate reflection direction
	# For a simple reflection, we'll reverse the velocity
	# In a more complex system, you might want to calculate the normal vector
	var reflected_velocity = -ball_velocity * 0.95  # Reduce speed by only 5% to maintain more velocity
	
	# Apply the reflected velocity to the ball
	if ball.has_method("set_velocity"):
		ball.set_velocity(reflected_velocity)
	elif "velocity" in ball:
		ball.velocity = reflected_velocity
	
	print("Ball reflected with velocity:", reflected_velocity)
