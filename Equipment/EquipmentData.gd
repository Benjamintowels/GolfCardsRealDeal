class_name EquipmentData
extends Resource

@export var name: String = ""
@export var image: Texture2D
@export var description: String = ""
@export var buff_type: String = ""  # e.g., "mobility", "strength", "card_draw"
@export var buff_value: int = 0
@export var price: int = 100  # For future shop pricing system 