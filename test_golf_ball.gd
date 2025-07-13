extends CharacterBody2D

var ball_height: float = 0.0
var ball_velocity: Vector2 = Vector2(100, 0)

func _ready():
	# Create a simple visual representation
	var sprite = Sprite2D.new()
	var texture = preload("res://GolfBall.png")
	sprite.texture = texture
	sprite.scale = Vector2(0.5, 0.5)
	add_child(sprite)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8.0
	collision.shape = shape
	add_child(collision)

func _physics_process(delta):
	# Simple movement
	position += ball_velocity * delta
	
	# Bounce off screen edges
	if position.x < 0 or position.x > 800:
		ball_velocity.x = -ball_velocity.x
	if position.y < 0 or position.y > 600:
		ball_velocity.y = -ball_velocity.y

# Methods expected by bonfire collision system
func get_ball_height() -> float:
	return ball_height

func get_ball_velocity() -> Vector2:
	return ball_velocity

func set_ball_velocity(new_velocity: Vector2):
	ball_velocity = new_velocity

# Test functions
func set_ball_height(height: float):
	ball_height = height

func launch_ball():
	ball_height = 20.0  # Launch ball into air
	ball_velocity = Vector2(100, -50)  # Upward trajectory 