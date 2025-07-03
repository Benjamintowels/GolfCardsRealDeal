extends Node
class_name EquipmentManager

signal equipment_updated

# Current equipped items
var equipped_equipment: Array[EquipmentData] = []

# Equipment effects
var mobility_bonus: int = 0
var strength_bonus: int = 0
var card_draw_bonus: int = 0

func _ready():
	print("EquipmentManager: _ready() called")

func add_equipment(equipment: EquipmentData):
	"""Add equipment and apply its effects"""
	equipped_equipment.append(equipment)
	apply_equipment_effects(equipment)
	emit_signal("equipment_updated")
	print("EquipmentManager: Added", equipment.name, "to equipment. Total equipment:", equipped_equipment.size())

func remove_equipment(equipment: EquipmentData):
	"""Remove equipment and remove its effects"""
	if equipped_equipment.has(equipment):
		equipped_equipment.erase(equipment)
		remove_equipment_effects(equipment)
		emit_signal("equipment_updated")
		print("EquipmentManager: Removed", equipment.name, "from equipment. Total equipment:", equipped_equipment.size())

func apply_equipment_effects(equipment: EquipmentData):
	"""Apply the effects of a piece of equipment"""
	match equipment.buff_type:
		"mobility":
			mobility_bonus += equipment.buff_value
			print("EquipmentManager: Applied mobility bonus +", equipment.buff_value, "from", equipment.name)
		"strength":
			strength_bonus += equipment.buff_value
			print("EquipmentManager: Applied strength bonus +", equipment.buff_value, "from", equipment.name)
		"card_draw":
			card_draw_bonus += equipment.buff_value
			print("EquipmentManager: Applied card draw bonus +", equipment.buff_value, "from", equipment.name)

func remove_equipment_effects(equipment: EquipmentData):
	"""Remove the effects of a piece of equipment"""
	match equipment.buff_type:
		"mobility":
			mobility_bonus -= equipment.buff_value
			print("EquipmentManager: Removed mobility bonus -", equipment.buff_value, "from", equipment.name)
		"strength":
			strength_bonus -= equipment.buff_value
			print("EquipmentManager: Removed strength bonus -", equipment.buff_value, "from", equipment.name)
		"card_draw":
			card_draw_bonus -= equipment.buff_value
			print("EquipmentManager: Removed card draw bonus -", equipment.buff_value, "from", equipment.name)

func get_mobility_bonus() -> int:
	"""Get the total mobility bonus from all equipped items"""
	return mobility_bonus

func get_strength_bonus() -> int:
	"""Get the total strength bonus from all equipped items"""
	return strength_bonus

func get_card_draw_bonus() -> int:
	"""Get the total card draw bonus from all equipped items"""
	return card_draw_bonus

func get_equipped_equipment() -> Array[EquipmentData]:
	"""Get all currently equipped equipment"""
	return equipped_equipment.duplicate()

func has_equipment(equipment_name: String) -> bool:
	"""Check if a specific piece of equipment is equipped"""
	for equipment in equipped_equipment:
		if equipment.name == equipment_name:
			return true
	return false

func get_equipment_count() -> int:
	"""Get the total number of equipped items"""
	return equipped_equipment.size()

func clear_all_equipment():
	"""Clear all equipped equipment and reset bonuses"""
	equipped_equipment.clear()
	mobility_bonus = 0
	strength_bonus = 0
	card_draw_bonus = 0
	emit_signal("equipment_updated")
	print("EquipmentManager: Cleared all equipment and reset bonuses") 