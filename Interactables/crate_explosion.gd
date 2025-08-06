extends Node2D

# Crate explosion effect with brown particles and reward placement

# Particle system for brown explosion
var particles: GPUParticles2D
var reward_placement: Node2D

# Reward types that can be spawned
var reward_types = [
	"coin",  # Money
	"card",  # Card pickup
	"health",  # Health pickup
	"ammo"   # Ammo pickup
]

func _ready():
	# Get references to child nodes
	particles = get_node_or_null("GPUParticles2D")
	reward_placement = get_node_or_null("RewardPlacement")
	
	# Initially hide the explosion
	visible = false
	
	# Set up particle system if it exists
	if particles:
		_setup_particle_system()

func _setup_particle_system():
	"""Set up the brown particle explosion effect"""
	if not particles:
		return
	
	# Create a particle process material for the explosion
	var process_material = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 10.0
	process_material.gravity = Vector3(0, 0, 0)  # No gravity for explosion
	process_material.initial_velocity_min = 50.0
	process_material.initial_velocity_max = 150.0
	process_material.scale_min = 2.0
	process_material.scale_max = 4.0
	process_material.color = Color(0.6, 0.4, 0.2, 1.0)  # Brown color
	
	# Apply the material to the particle system
	particles.process_material = process_material
	
	# Configure particle system properties
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 20

func trigger_explosion():
	"""Trigger the crate explosion effect"""
	print("=== CRATE EXPLOSION TRIGGERED ===")
	
	# Make the explosion visible
	visible = true
	
	# Start particle emission
	if particles:
		particles.emitting = true
		print("✓ Particle explosion started")
	
	# Place a random reward
	_place_random_reward()
	
	# Set up cleanup timer
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 3.0  # Clean up after 3 seconds
	cleanup_timer.one_shot = true
	cleanup_timer.connect("timeout", _cleanup_explosion)
	add_child(cleanup_timer)
	cleanup_timer.start()

func _place_random_reward():
	"""Place a random reward at the crate's position"""
	var reward_type = reward_types[randi() % reward_types.size()]
	print("Placing reward type:", reward_type)
	
	# Get the crate's position
	var crate_position = global_position
	
	# Create the reward based on type
	match reward_type:
		"coin":
			_create_coin_reward(crate_position)
		"card":
			_create_card_reward(crate_position)
		"health":
			_create_health_reward(crate_position)
		"ammo":
			_create_ammo_reward(crate_position)

func _create_coin_reward(position: Vector2):
	"""Create a coin reward at the specified position"""
	# Create a simple coin node
	var coin = Node2D.new()
	coin.name = "CoinReward"
	coin.global_position = position
	
	# Add a sprite (you can replace with actual coin sprite)
	var sprite = Sprite2D.new()
	# For now, we'll use a colored rectangle as placeholder
	# In a real implementation, you'd load a coin texture
	sprite.modulate = Color.YELLOW
	coin.add_child(sprite)
	
	# Add collision area for pickup
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	collision.shape = circle
	area.add_child(collision)
	coin.add_child(area)
	
	# Connect to pickup signal
	area.connect("area_entered", _on_coin_pickup)
	
	# Add to scene
	get_parent().add_child(coin)
	print("✓ Coin reward placed at:", position)

func _create_card_reward(position: Vector2):
	"""Create a card reward at the specified position"""
	# Create a simple card node
	var card = Node2D.new()
	card.name = "CardReward"
	card.global_position = position
	
	# Add a sprite (placeholder)
	var sprite = Sprite2D.new()
	sprite.modulate = Color.BLUE
	card.add_child(sprite)
	
	# Add collision area for pickup
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	collision.shape = circle
	area.add_child(collision)
	card.add_child(area)
	
	# Connect to pickup signal
	area.connect("area_entered", _on_card_pickup)
	
	# Add to scene
	get_parent().add_child(card)
	print("✓ Card reward placed at:", position)

func _create_health_reward(position: Vector2):
	"""Create a health reward at the specified position"""
	# Create a simple health pickup node
	var health = Node2D.new()
	health.name = "HealthReward"
	health.global_position = position
	
	# Add a sprite (placeholder)
	var sprite = Sprite2D.new()
	sprite.modulate = Color.GREEN
	health.add_child(sprite)
	
	# Add collision area for pickup
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	collision.shape = circle
	area.add_child(collision)
	health.add_child(area)
	
	# Connect to pickup signal
	area.connect("area_entered", _on_health_pickup)
	
	# Add to scene
	get_parent().add_child(health)
	print("✓ Health reward placed at:", position)

func _create_ammo_reward(position: Vector2):
	"""Create an ammo reward at the specified position"""
	# Create a simple ammo pickup node
	var ammo = Node2D.new()
	ammo.name = "AmmoReward"
	ammo.global_position = position
	
	# Add a sprite (placeholder)
	var sprite = Sprite2D.new()
	sprite.modulate = Color.RED
	ammo.add_child(sprite)
	
	# Add collision area for pickup
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	collision.shape = circle
	area.add_child(collision)
	ammo.add_child(area)
	
	# Connect to pickup signal
	area.connect("area_entered", _on_ammo_pickup)
	
	# Add to scene
	get_parent().add_child(ammo)
	print("✓ Ammo reward placed at:", position)

func _on_coin_pickup(area: Area2D):
	"""Handle coin pickup"""
	var player = area.get_parent()
	if player and player.has_method("add_money"):
		player.add_money(10)  # Add 10 money
		print("✓ Coin picked up! +10 money")
		area.get_parent().queue_free()  # Remove the coin

func _on_card_pickup(area: Area2D):
	"""Handle card pickup"""
	var player = area.get_parent()
	if player and player.has_method("add_card"):
		# Add a random card to the player's deck
		player.add_card("random")
		print("✓ Card picked up!")
		area.get_parent().queue_free()  # Remove the card

func _on_health_pickup(area: Area2D):
	"""Handle health pickup"""
	var player = area.get_parent()
	if player and player.has_method("heal"):
		player.heal(25)  # Heal 25 health
		print("✓ Health picked up! +25 health")
		area.get_parent().queue_free()  # Remove the health pickup

func _on_ammo_pickup(area: Area2D):
	"""Handle ammo pickup"""
	var player = area.get_parent()
	if player and player.has_method("add_ammo"):
		player.add_ammo(5)  # Add 5 ammo
		print("✓ Ammo picked up! +5 ammo")
		area.get_parent().queue_free()  # Remove the ammo pickup

func _cleanup_explosion():
	"""Clean up the explosion after it's finished"""
	print("=== CLEANING UP CRATE EXPLOSION ===")
	
	# Stop particles
	if particles:
		particles.emitting = false
	
	# Hide the explosion
	visible = false
	
	# Remove this node after a delay
	var final_cleanup = Timer.new()
	final_cleanup.wait_time = 1.0
	final_cleanup.one_shot = true
	final_cleanup.connect("timeout", queue_free)
	add_child(final_cleanup)
	final_cleanup.start()
