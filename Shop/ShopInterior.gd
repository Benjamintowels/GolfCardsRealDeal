extends Control

func _ready():
	# Connect the return button
	$ReturnButton.pressed.connect(_on_return_button_pressed)
	
	# Play the shop music/sound when entering
	play_shop_sound()

func play_shop_sound():
	"""Play the shop trinkets sound"""
	var trinkets_sound = $Trinkets
	if trinkets_sound and trinkets_sound.stream:
		trinkets_sound.play()
		print("Playing shop trinkets sound")
	else:
		print("Warning: Trinkets sound not found or no stream")

func _on_return_button_pressed():
	"""Return to the course scene"""
	print("Return button pressed - going back to course")
	
	# Stop the shop sound before leaving
	var trinkets_sound = $Trinkets
	if trinkets_sound and trinkets_sound.playing:
		trinkets_sound.stop()
		print("Stopped shop trinkets sound")
	
	# Use FadeManager for smooth transition
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Course1.tscn"), 0.5) 
