extends Node

# CoinExplosionManager - handles coin particle explosions when NPCs die
# This is a singleton that can be called from any NPC's die() function

signal coin_explosion_completed

# Coin particle scene
var coin_particle_scene: PackedScene
var coin_sound: AudioStream

# Explosion parameters
var min_coins: int = 3
var max_coins: int = 8
var explosion_radius: float = 50.0
var coin_speed: float = 150.0

func _ready():
	# Load the coin particle scene
	coin_particle_scene = preload("res://Particles/CoinParticle.tscn")
	
	# Load the coin sound
	coin_sound = preload("res://Sounds/CoinSound.mp3")

func create_coin_explosion(position: Vector2, coin_count: int = -1) -> void:
	"""
	Create a coin explosion at the specified position
	
	Args:
		position: The world position where the explosion should occur
		coin_count: Number of coins to spawn (-1 for random between min_coins and max_coins)
	"""
	if coin_count == -1:
		coin_count = randi_range(min_coins, max_coins)
	
	print("=== CREATING COIN EXPLOSION ===")
	print("Position:", position)
	print("Coin count:", coin_count)
	
	# Play coin sound
	_play_coin_sound()
	
	# Spawn coin particles
	for i in range(coin_count):
		_spawn_coin_particle(position)
	
	# Emit signal when explosion is complete
	emit_signal("coin_explosion_completed")

func _spawn_coin_particle(spawn_position: Vector2) -> void:
	"""Spawn a single coin particle with random direction and speed"""
	if not coin_particle_scene:
		print("ERROR: Coin particle scene not loaded!")
		return
	
	# Create the coin particle
	var coin_particle = coin_particle_scene.instantiate()
	
	# Add to the current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(coin_particle)
	else:
		print("ERROR: No current scene found!")
		return
	
	# Set initial position
	coin_particle.global_position = spawn_position
	
	# Add random offset to spread coins around the spawn point
	var random_offset = Vector2(
		randf_range(-explosion_radius * 0.5, explosion_radius * 0.5),
		randf_range(-explosion_radius * 0.5, explosion_radius * 0.5)
	)
	coin_particle.position += random_offset
	
	# Add initial velocity for explosion effect
	if coin_particle.has_method("add_explosion_velocity"):
		var random_direction = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()
		var random_speed = randf_range(coin_speed * 0.5, coin_speed * 1.5)
		coin_particle.add_explosion_velocity(random_direction * random_speed)
	
	print("✓ Spawned coin particle at:", coin_particle.global_position)

func _play_coin_sound() -> void:
	"""Play the coin sound effect"""
	if not coin_sound:
		print("ERROR: Coin sound not loaded!")
		return
	
	# Create an AudioStreamPlayer to play the sound
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = coin_sound
	audio_player.volume_db = -5.0  # Slightly quieter than default
	
	# Add to current scene and play
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(audio_player)
		audio_player.play()
		
		# Clean up the audio player when sound finishes
		audio_player.finished.connect(func():
			audio_player.queue_free()
		)
		
		print("✓ Playing coin sound")
	else:
		print("ERROR: No current scene found for audio playback!")

# Static method for easy calling from NPCs
static func trigger_coin_explosion(position: Vector2, coin_count: int = -1) -> void:
	"""Static method to trigger a coin explosion - can be called from any NPC"""
	var explosion_manager = _get_explosion_manager()
	if explosion_manager:
		explosion_manager.create_coin_explosion(position, coin_count)
	else:
		print("ERROR: CoinExplosionManager not found!")

static func _get_explosion_manager() -> Node:
	"""Get the CoinExplosionManager instance from the scene tree"""
	var current_scene = Engine.get_main_loop().current_scene
	if current_scene:
		return current_scene.get_node_or_null("CoinExplosionManager")
	return null 