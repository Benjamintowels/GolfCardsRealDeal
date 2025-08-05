extends Node

# Use in conjunction with PerkDeployer on Course1 scene so the selected perks can be stored here and sent to the deployer

signal perk_ready_to_deploy(perk_type: String)

var selected_perk: String = ""
var is_perk_pending: bool = false

func store_perk(perk_type: String):
	"""Store a selected perk for later deployment"""
	print("PerkReceiver: Storing perk:", perk_type)
	selected_perk = perk_type
	is_perk_pending = true

func get_stored_perk() -> String:
	"""Get the stored perk and mark it as retrieved"""
	var perk = selected_perk
	selected_perk = ""
	is_perk_pending = false
	print("PerkReceiver: Retrieved perk:", perk)
	return perk

func has_pending_perk() -> bool:
	"""Check if there's a perk waiting to be deployed"""
	return is_perk_pending

func clear_perk():
	"""Clear any stored perk"""
	selected_perk = ""
	is_perk_pending = false
	print("PerkReceiver: Cleared stored perk")
