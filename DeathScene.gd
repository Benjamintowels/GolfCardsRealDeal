extends Control

@onready var death_label: Label = $DeathLabel
@onready var return_button: Button = $ReturnButton

func _ready():
	# Connect the return button
	return_button.pressed.connect(_on_return_button_pressed)
	
	# Set up the death message
	death_label.text = "You have Died"
	
	# Start with the scene faded in from black
	FadeManager.fade_from_black(1.0)

func _on_return_button_pressed():
	# Return to main menu
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Main.tscn"), 0.5) 