extends Button

func _ready():
	# Connect the button press signal to our function
	pressed.connect(_on_start_round_pressed)

func _on_start_round_pressed():
	# Switch to Course 1 scene
	get_tree().change_scene_to_file("res://Course1.tscn")
func start_round() -> void:
	initialize_deck()
	draw_cards()
	create_movement_buttons()
