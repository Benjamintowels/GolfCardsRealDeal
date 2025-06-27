extends Control

@onready var background: TextureRect = $Background
@onready var character_image: TextureRect = $CharacterImage
@onready var score_label: Label = $ScoreLabel
@onready var return_button: Button = $ReturnButton

var character_end_images = {
	1: {  # Layla
		"good": preload("res://Characters/LaylaGood.png"),
		"bad": preload("res://Characters/LaylaBad.png")
	},
	2: {  # Benny
		"good": preload("res://Characters/BennyGood.png"),
		"bad": preload("res://Characters/BennyBad.png")
	},
	3: {  # Clark
		"good": preload("res://Characters/ClarkGood.png"),
		"bad": preload("res://Characters/ClarkBad.png")
	}
}

func _ready():
	# Connect the return button
	return_button.pressed.connect(_on_return_button_pressed)
	
	# Display the final score and character image
	display_final_results()

func display_final_results():
	# Get the selected character and final score from Global
	var selected_character = Global.selected_character
	var final_score = Global.final_18_hole_score
	var total_par = GolfCourseLayout.get_total_par()
	var score_vs_par = final_score - total_par
	
	# Determine if it's a good or bad performance (better than 4 over par = good)
	var performance = "good" if score_vs_par <= 4 else "bad"
	
	# Set the character image based on performance
	var character_textures = character_end_images.get(selected_character, character_end_images[1])
	var character_texture = character_textures.get(performance, character_textures["good"])
	character_image.texture = character_texture
	
	# Create the score text
	var score_text = "Final Score: %d strokes\n" % final_score
	score_text += "Course Par: %d\n" % total_par
	
	# Add score vs par
	if score_vs_par == 0:
		score_text += "Final Result: Even Par ✓\n"
	elif score_vs_par > 0:
		score_text += "Final Result: %+d (Over Par)\n" % score_vs_par
	else:
		score_text += "Final Result: %+d (Under Par) ✓\n" % score_vs_par
	
	# Add performance message
	if performance == "good":
		score_text += "\nGreat round! You played well!"
	else:
		score_text += "\nKeep practicing! You'll get better!"
	
	score_label.text = score_text

func _on_return_button_pressed():
	# Return to main menu
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Main.tscn"), 0.5) 
