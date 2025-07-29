extends AnimatedSprite2D

# Electric arc visual effect
# Defaults left to right orientation, can be rotated to face targets

var arc_duration: float = 0.5  # How long the arc stays visible
var arc_timer: float = 0.0

func _ready():
	# Connect animation finished signal
	animation_finished.connect(_on_animation_finished)
	
	# Start the arc animation
	play("default")

func _process(delta):
	# Timer for auto-cleanup
	arc_timer += delta
	if arc_timer >= arc_duration:
		queue_free()

func _on_animation_finished():
	# Clean up when animation is done
	queue_free()
