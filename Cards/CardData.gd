extends Resource
class_name CardData

@export var name: String = ""
@export var effect_type: String = ""
@export var effect_strength: int = 1  # ✅ Fix this spelling
@export var image: Texture
@export var level: int = 1  # Card level (1 = base, 2 = upgraded)
@export var max_level: int = 2  # Maximum upgrade level
@export var upgrade_cost: int = 100  # Cost to upgrade the card

# Upgrade effects for different card types
@export var movement_bonus: int = 1  # Additional movement range for movement cards
@export var attack_bonus: int = 1  # Additional attack range for attack cards
@export var weapon_shots_bonus: int = 1  # Additional shots for weapon cards
@export var effect_bonus: int = 1  # Additional effect strength for modify cards

func is_upgraded() -> bool:
	"""Check if the card is upgraded"""
	return level > 1 and level <= max_level

func can_upgrade() -> bool:
	"""Check if the card can be upgraded"""
	return level < max_level

func get_upgraded_name() -> String:
	"""Get the name with level indicator if upgraded"""
	if level > 1 and level <= max_level:
		return name + " (Lvl " + str(level) + ")"
	return name

func get_effective_strength() -> int:
	"""Get the effective strength including upgrade bonuses"""
	var effective = effect_strength
	if level > 1:
		match effect_type:
			"Movement":
				effective += movement_bonus
			"Attack":
				effective += attack_bonus
			"Weapon":
				effective += weapon_shots_bonus
			"ModifyNext", "Modify":
				effective += effect_bonus
	return effective

func get_upgrade_description() -> String:
	"""Get a description of what the upgrade does"""
	match effect_type:
		"Movement":
			return "Increases movement range by " + str(movement_bonus)
		"Attack":
			return "Increases attack range by " + str(attack_bonus)
		"Weapon":
			return "Allows " + str(weapon_shots_bonus) + " additional shot(s)"
		"ModifyNext", "Modify":
			return "Increases effect strength by " + str(effect_bonus)
		_:
			return "Enhances card effectiveness"
