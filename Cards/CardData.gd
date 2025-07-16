extends Resource
class_name CardData

@export var name: String = ""
@export var effect_type: String = ""
@export var effect_strength: int = 1  # ✅ Fix this spelling
@export var image: Texture
@export var level: int = 1  # Card level (1 = base, 2 = upgraded)
@export var max_level: int = 2  # Maximum upgrade level
@export var upgrade_cost: int = 100  # Cost to upgrade the card
@export var price: int = 100  # Price to purchase the card in shop
@export var default_tier: int = 1  # Default tier for reward system (1-3)

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
			"AOEAttack":
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
		"AOEAttack":
			return "Increases attack range by " + str(attack_bonus)
		"Weapon":
			return "Allows " + str(weapon_shots_bonus) + " additional shot(s)"
		"ModifyNext", "Modify":
			return "Increases effect strength by " + str(effect_bonus)
		_:
			return "Enhances card effectiveness"

func get_reward_tier() -> int:
	"""Get the current reward tier based on level and default tier"""
	# Base tier is the default tier
	var base_tier = default_tier
	
	# If card is upgraded, increase tier by 1 (capped at 3)
	if level > 1:
		return min(base_tier + 1, 3)
	
	return base_tier
