extends Node

# Used as native in Course1 to be able to receive perks from Main scene and apply them after the whole Course1 is loaded

const CardData = preload("res://Cards/CardData.gd")
const EquipmentData = preload("res://Equipment/EquipmentData.gd")

var perk_receiver: Node = null
var course: Node = null

func _ready():
	"""Initialize the perk deployer"""
	print("PerkDeployer: Initialized")
	
	# Find the PerkReceiver in the Main scene (it should be accessible via autoload or scene tree)
	# We'll check for it when the round starts

func setup(course_reference: Node):
	"""Setup the deployer with course reference"""
	course = course_reference
	print("PerkDeployer: Setup with course reference")

func check_and_deploy_perk():
	"""Check for pending perks and deploy them"""
	print("PerkDeployer: Checking for pending perks")
	
	# Use the PerkReceiver autoload
	perk_receiver = PerkReceiver
	print("PerkDeployer: PerkReceiver autoload found:", perk_receiver != null)
	
	if perk_receiver:
		print("PerkDeployer: PerkReceiver has pending perk:", perk_receiver.has_pending_perk())
		if perk_receiver.has_pending_perk():
			var perk_type = perk_receiver.get_stored_perk()
			print("PerkDeployer: Deploying perk:", perk_type)
			_apply_perk(perk_type)
		else:
			print("PerkDeployer: No pending perks found")
	else:
		print("PerkDeployer: PerkReceiver autoload is null!")

func _apply_perk(perk_type: String):
	"""Apply the selected perk effect"""
	print("PerkDeployer: Applying perk:", perk_type)
	
	match perk_type:
		"start_with_200_looty":
			print("PerkDeployer: Applying perk: Start with 200 extra $Looty")
			_apply_looty_perk()
		"upgrade_card":
			print("PerkDeployer: Applying perk: Upgrade a card in deck")
			_apply_upgrade_card_perk()
		"random_rare_action":
			print("PerkDeployer: Applying perk: Receive random rare action card")
			_apply_random_rare_action_perk()
		"random_equipment":
			print("PerkDeployer: Applying perk: Receive random equipment")
			_apply_random_equipment_perk()
		"random_club_card":
			print("PerkDeployer: Applying perk: Receive random club card")
			_apply_random_club_card_perk()
		"receive_bounty":
			print("PerkDeployer: Applying perk: Receive bounty (placeholder)")
			_apply_bounty_perk()
		_:
			print("PerkDeployer: Unknown perk type:", perk_type)

func _apply_looty_perk():
	"""Apply the start with 200 looty perk"""
	Global.add_looty(200)
	print("PerkDeployer: Added 200 looty to player")

func _apply_upgrade_card_perk():
	"""Apply the upgrade card perk"""
	# This would need to be implemented based on your card upgrade system
	# For now, just add a basic club card as a placeholder
	if course and course.deck_manager and course.club_data:
		var available_clubs = course.club_data.keys()
		var random_club = available_clubs[randi() % available_clubs.size()]
		
		var card_data = CardData.new()
		card_data.name = random_club
		card_data.effect_type = "Club"  # Use effect_type instead of type
		card_data.effect_strength = 1
		card_data.default_tier = 1
		card_data.level = 2  # Upgraded level
		
		course.deck_manager.add_card_to_current_deck(card_data)
		print("PerkDeployer: Added upgraded club card:", random_club, " (Level 2)")
	else:
		print("PerkDeployer: Card upgrade perk - course, deck_manager, or club_data not found")

func _apply_random_rare_action_perk():
	"""Apply the random rare action card perk"""
	if course and course.deck_manager:
		# List of action cards (non-club cards) - these are the "rare" action cards
		var action_card_resources = [
			"res://Cards/Move1.tres",
			"res://Cards/Move2.tres", 
			"res://Cards/Move3.tres",
			"res://Cards/Move4.tres",
			"res://Cards/Move5.tres",
			"res://Cards/StickyShot.tres",
			"res://Cards/Bouncey.tres",
			"res://Cards/Dub.tres",
			"res://Cards/RooBoostCard.tres",
			"res://Cards/FloridaScramble.tres",
			"res://Cards/KickB.tres",
			"res://Cards/PunchB.tres",
			"res://Cards/PistolCard.tres",
			"res://Cards/BurstShot.tres",
			"res://Cards/ShotgunCard.tres",
			"res://Cards/SniperCard.tres",
			"res://Cards/GrenadeCard.tres",
			"res://Cards/ThrowingKnife.tres",
			"res://Cards/TeleportCard.tres",
			"res://Cards/Draw2.tres",
			"res://Cards/CoffeeCard.tres",
			"res://Cards/BlockB.tres",
			"res://Cards/CaddyCard.tres",
			"res://Cards/CallofthewildCard.tres",
			"res://Cards/Dash.tres",
			"res://Cards/EtherDash.tres",
			"res://Cards/AssassinDash.tres",
			"res://Cards/GhostMode.tres",
			"res://Cards/Vampire.tres",
			"res://Cards/DodgeCard.tres",
			"res://Cards/MeteorCard.tres",
			"res://Cards/BagCheck.tres",
			"res://Cards/FiragaCard.tres",
			"res://Cards/IceSpearCard.tres"
		]
		
		# Pick a random action card
		var random_card_path = action_card_resources[randi() % action_card_resources.size()]
		var card_data = load(random_card_path) as CardData
		
		if card_data:
			course.deck_manager.add_card_to_current_deck(card_data)
			print("PerkDeployer: Added random rare action card:", card_data.name)
		else:
			print("PerkDeployer: Failed to load action card from:", random_card_path)
	else:
		print("PerkDeployer: Random rare action perk - course or deck_manager not found")

func _apply_random_equipment_perk():
	"""Apply the random equipment perk"""
	if course:
		# Find the EquipmentManager
		var equipment_manager = course.get_node_or_null("EquipmentManager")
		if equipment_manager:
			# List of available equipment resources
			var equipment_resources = [
				"res://Equipment/Lighter.tres",
				"res://Equipment/Drone.tres", 
				"res://Equipment/ShineStar.tres",
				"res://Equipment/PutterHelp.tres",
				"res://Equipment/ComputerChip.tres",
				"res://Equipment/BrassKnuckles.tres",
				"res://Equipment/FireExtinguisher.tres",
				"res://Equipment/AnimalTranslator.tres",
				"res://Equipment/Sledgehammer.tres",
				"res://Equipment/Khukri.tres",
				"res://Equipment/Sword.tres",
				"res://Equipment/Wand.tres",
				"res://Equipment/FlashLight.tres",
				"res://Equipment/Watch.tres",
				"res://Equipment/FancyWatch.tres",
				"res://Equipment/HeadPhones.tres",
				"res://Equipment/RangeFinder.tres",
				"res://Equipment/Flute.tres",
				"res://Equipment/SoundBowl.tres",
				"res://Equipment/SML.tres",
				"res://Equipment/JesusSandles.tres",
				"res://Equipment/GolfShoes.tres"
			]
			
			# Pick a random equipment
			var random_equipment_path = equipment_resources[randi() % equipment_resources.size()]
			var equipment_data = load(random_equipment_path) as EquipmentData
			
			if equipment_data:
				equipment_manager.add_equipment(equipment_data)
				print("PerkDeployer: Added random equipment:", equipment_data.name)
			else:
				print("PerkDeployer: Failed to load equipment from:", random_equipment_path)
		else:
			print("PerkDeployer: EquipmentManager not found in course")
	else:
		print("PerkDeployer: Course reference is null")

func _apply_random_club_card_perk():
	"""Apply the random club card perk"""
	if course and course.deck_manager and course.club_data:
		# Get a random club from the available clubs
		var available_clubs = course.club_data.keys()
		var random_club = available_clubs[randi() % available_clubs.size()]
		
		# Create a card data for the random club
		var card_data = CardData.new()
		card_data.name = random_club
		card_data.effect_type = "Club"  # Use effect_type instead of type
		card_data.effect_strength = 1
		card_data.default_tier = 1
		
		# Add the card to the deck
		course.deck_manager.add_card_to_current_deck(card_data)
		print("PerkDeployer: Added random club card:", random_club)
	else:
		print("PerkDeployer: Random club card perk - course, deck_manager, or club_data not found")

func _apply_bounty_perk():
	"""Apply the bounty perk"""
	# This would need to be implemented based on your bounty system
	print("PerkDeployer: Bounty perk - needs implementation")
