extends Node2D

@onready var crowd_sprite: Sprite2D = $CrowdSprite
@onready var crowd_cheer_sprite: Sprite2D = $CrowdCheerSprite

var animation_timer: Timer
var is_animating: bool = false
var animation_speed: float = 0.3  # Time between sprite switches

func _ready():
	# Add to crowd group for easy cleanup
	add_to_group("crowd")
	
	# Create animation timer
	animation_timer = Timer.new()
	animation_timer.wait_time = animation_speed
	animation_timer.timeout.connect(_on_animation_tick)
	add_child(animation_timer)
	
	# Start with normal crowd sprite
	crowd_sprite.visible = true
	crowd_cheer_sprite.visible = false

func start_cheering():
	"""Start the crowd cheering animation"""
	if not is_animating:
		is_animating = true
		animation_timer.start()
		print("Crowd started cheering!")

func stop_cheering():
	"""Stop the crowd cheering animation"""
	if is_animating:
		is_animating = false
		animation_timer.stop()
		# Reset to normal crowd sprite
		crowd_sprite.visible = true
		crowd_cheer_sprite.visible = false
		print("Crowd stopped cheering!")

func _on_animation_tick():
	"""Handle animation timer tick - switch between sprites"""
	if is_animating:
		crowd_sprite.visible = !crowd_sprite.visible
		crowd_cheer_sprite.visible = !crowd_cheer_sprite.visible
