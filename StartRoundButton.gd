extends Button

func _ready():
	# Connect the button press signal to our function
	pressed.connect(_on_start_round_pressed)

func _on_start_round_pressed():
	# Use FadeManager for smooth transition
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Course1.tscn"), 0.5)
