class_name EquipmentData
extends Resource

@export var name: String = ""
@export var image: Texture2D
@export var description: String = ""
@export var buff_type: String = ""  # e.g., "mobility", "strength", "card_draw"
@export var buff_value: int = 0
@export var price: int = 100  # For future shop pricing system
@export var default_tier: int = 1  # Default tier for reward system (1-3)

# Clothing system properties
@export var is_clothing: bool = false  # Whether this is clothing equipment
@export var clothing_slot: String = ""  # "head", "neck", "body" - only used if is_clothing is true
@export var clothing_scene_path: String = ""  # Path to the clothing scene (.tscn file)
@export var display_image: Texture2D  # Alternative image for display (e.g., CapeDisplayImage.png)

func get_reward_tier() -> int:
	"""Get the current reward tier (equipment doesn't have levels like cards)"""
	return default_tier 