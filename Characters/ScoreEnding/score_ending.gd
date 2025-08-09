extends Control

# Use as overlay inside of FinalScoreDisplay scene to show a Good/Bad result image

@onready var texture_rect: TextureRect = $TextureRect

var character_end_images := {
	1: {  # Layla
		"good": preload("res://Characters/ScoreEnding/LaylaGood.png"),
		"bad": preload("res://Characters/ScoreEnding/LaylaBad.png"),
	},
	2: {  # Benny
		"good": preload("res://Characters/ScoreEnding/BennyGood.png"),
		"bad": preload("res://Characters/ScoreEnding/BennyBad.png"),
	},
	3: {  # Clark
		"good": preload("res://Characters/ScoreEnding/ClarkGood.png"),
		"bad": preload("res://Characters/ScoreEnding/ClarkBad.png"),
	},
}

func set_result(is_good: bool) -> void:
	var selected_character: int = int(Global.selected_character)
	var textures: Dictionary = character_end_images.get(selected_character, character_end_images[2])
	var tex: Texture2D = textures["good"] if is_good else textures["bad"]
	if texture_rect:
		texture_rect.texture = tex
