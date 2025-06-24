# CardVisual.gd
extends Control

@onready var label = $Label
@onready var icon = $TextureRect

var data: CardData

func setup(card_data: CardData) -> void:
	data = card_data
	label.text = card_data.name
	icon.texture = card_data.image
