extends Node

# Global variables
var selected_character = 1  # Default to character 1

var CHARACTER_STATS = {
	1: { "name": "Layla", "base_mobility": 3 },
	2: { "name": "Benny", "base_mobility": 2 },
	3: { "name": "Clark", "base_mobility": 1 }
}

func _ready():
	print("Global script loaded, selected_character = ", selected_character)
