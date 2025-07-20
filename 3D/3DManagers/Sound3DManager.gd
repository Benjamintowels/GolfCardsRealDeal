extends Node
class_name Sound3DManager

# Sound3DManager - Handles 3D audio for golf course
# Optimized for 3D space with spatial audio support

signal sound_played(sound_name: String)

# Audio players
var music_player: AudioStreamPlayer = null
var sfx_player: AudioStreamPlayer = null
var ambient_player: AudioStreamPlayer = null

# Sound settings
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var ambient_volume: float = 0.5

# Sound libraries
var sound_effects = {
	"hole_complete": "res://Sounds/HoleComplete.mp3",
	"ball_hit": "res://Sounds/BallHit.mp3",
	"ball_land": "res://Sounds/BallLand.mp3",
	"player_move": "res://Sounds/PlayerMove.mp3",
	"ui_click": "res://Sounds/Select.mp3"
}

var music_tracks = {
	"course_ambient": "res://Sounds/CourseAmbient.mp3",
	"hole_complete": "res://Sounds/HoleCompleteMusic.mp3"
}

func _ready():
	print("✓ Sound3DManager initialized")
	_setup_audio_players()

func _setup_audio_players():
	"""Setup audio players for different sound types"""
	
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.volume_db = linear_to_db(music_volume)
	add_child(music_player)
	
	# SFX player
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.volume_db = linear_to_db(sfx_volume)
	add_child(sfx_player)
	
	# Ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.volume_db = linear_to_db(ambient_volume)
	add_child(ambient_player)

func play_sound(sound_name: String, volume: float = 1.0):
	"""Play a sound effect"""
	if sound_name in sound_effects:
		var sound_path = sound_effects[sound_name]
		var sound = load(sound_path)
		if sound:
			sfx_player.stream = sound
			sfx_player.volume_db = linear_to_db(volume * sfx_volume * master_volume)
			sfx_player.play()
			sound_played.emit(sound_name)
		else:
			print("⚠ Could not load sound:", sound_path)
	else:
		print("⚠ Unknown sound effect:", sound_name)

func play_music(music_name: String, fade_in: bool = true):
	"""Play background music"""
	if music_name in music_tracks:
		var music_path = music_tracks[music_name]
		var music = load(music_path)
		if music:
			music_player.stream = music
			music_player.volume_db = linear_to_db(music_volume * master_volume)
			music_player.play()
			print("✓ Playing music:", music_name)
		else:
			print("⚠ Could not load music:", music_path)
	else:
		print("⚠ Unknown music track:", music_name)

func play_ambient(ambient_name: String):
	"""Play ambient sounds"""
	if ambient_name in music_tracks:
		var ambient_path = music_tracks[ambient_name]
		var ambient = load(ambient_path)
		if ambient:
			ambient_player.stream = ambient
			ambient_player.volume_db = linear_to_db(ambient_volume * master_volume)
			ambient_player.play()
			print("✓ Playing ambient:", ambient_name)
		else:
			print("⚠ Could not load ambient:", ambient_path)
	else:
		print("⚠ Unknown ambient track:", ambient_name)

# Specific sound functions
func play_hole_complete_sound():
	"""Play hole completion sound"""
	play_sound("hole_complete", 1.2)
	play_music("hole_complete")

func play_ball_hit_sound():
	"""Play ball hit sound"""
	play_sound("ball_hit")

func play_ball_land_sound():
	"""Play ball landing sound"""
	play_sound("ball_land")

func play_player_move_sound():
	"""Play player movement sound"""
	play_sound("player_move", 0.8)

func play_ui_click_sound():
	"""Play UI click sound"""
	play_sound("ui_click")

func start_course_ambient():
	"""Start course ambient sounds"""
	play_ambient("course_ambient")

# Volume control
func set_master_volume(volume: float):
	"""Set master volume (0.0 to 1.0)"""
	master_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()

func set_music_volume(volume: float):
	"""Set music volume (0.0 to 1.0)"""
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume * master_volume)

func set_sfx_volume(volume: float):
	"""Set SFX volume (0.0 to 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)
	sfx_player.volume_db = linear_to_db(sfx_volume * master_volume)

func set_ambient_volume(volume: float):
	"""Set ambient volume (0.0 to 1.0)"""
	ambient_volume = clamp(volume, 0.0, 1.0)
	ambient_player.volume_db = linear_to_db(ambient_volume * master_volume)

func _update_volumes():
	"""Update all audio player volumes"""
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)
	set_ambient_volume(ambient_volume)

# Public API
func stop_all_sounds():
	"""Stop all currently playing sounds"""
	music_player.stop()
	sfx_player.stop()
	ambient_player.stop()

func pause_all_sounds():
	"""Pause all currently playing sounds"""
	music_player.stream_paused = true
	sfx_player.stream_paused = true
	ambient_player.stream_paused = true

func resume_all_sounds():
	"""Resume all paused sounds"""
	music_player.stream_paused = false
	sfx_player.stream_paused = false
	ambient_player.stream_paused = false

func get_volume_info() -> Dictionary:
	"""Get current volume settings"""
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ambient_volume": ambient_volume
	} 