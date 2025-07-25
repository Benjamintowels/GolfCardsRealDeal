extends BaseObstacle
@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer

var flicker_timer: Timer

func _ready():
	#super()
	# Add splash, sound, etc.
	
	# Setup random water flickering
	setup_water_flickering()
	
func setup_water_flickering():
	# Create a timer for random flickering intervals
	flicker_timer = Timer.new()
	add_child(flicker_timer)
	flicker_timer.timeout.connect(_on_flicker_timer_timeout)
	
	# Start the first flicker after a random delay
	start_random_flicker()

func start_random_flicker():
	# Random interval between 2-8 seconds
	var random_interval = randf_range(2.0, 8.0)
	flicker_timer.wait_time = random_interval
	flicker_timer.start()

func _on_flicker_timer_timeout():
	# Play the water_idle animation
	if animation_player and animation_player.has_animation("water_idle"):
		animation_player.play("water_idle")
	
	# Schedule the next random flicker
	start_random_flicker()

func play_water_splash():
	"""Play the water splash animation when a ball lands on water"""
	if animation_player and animation_player.has_animation("water_splash"):
		animation_player.play("water_splash")
	
func on_player_interact():
	pass
