extends Control

signal loading_complete

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var status_label: Label = $StatusLabel
@onready var loading_label: Label = $LoadingLabel

# Resources to preload
var resources_to_load = [
	# Character scenes
	"res://Characters/LaylaChar.tscn",
	"res://Characters/BennyChar.tscn", 
	"res://Characters/ClarkChar.tscn",
	"res://Characters/Player1.tscn",
	
	# Obstacle scenes
	"res://Obstacles/Tree.tscn",
	"res://Obstacles/WaterHazard.tscn",
	"res://Obstacles/Green.tscn",
	"res://Obstacles/Tee.tscn",
	"res://Obstacles/SandTrap.tscn",
	"res://Obstacles/Fairway.tscn",
	"res://Obstacles/Rough.tscn",
	"res://Obstacles/Pin.tscn",
	"res://Obstacles/InvisibleBlocker.tscn",
	
	# Card scenes
	"res://CardVisual.tscn",
	"res://CardStackDisplay.tscn",
	
	# UI scenes
	"res://HealthBar.tscn",
	"res://InventoryDialog.tscn",
	"res://Bags/Bag.tscn",
	
	# Weapon scenes
	"res://Weapons/Pistol.tscn",
	
	# NPC scenes
	"res://NPC/Gang/GangMember.tscn",
	
	# Audio resources
	"res://Sounds/SwingSoft.mp3",
	"res://Sounds/SwingMed.mp3", 
	"res://Sounds/SwingStrong.mp3",
	"res://Sounds/WaterPlunk.mp3",
	"res://Sounds/SandThunk.mp3",
	"res://Sounds/BallLand.mp3",
	"res://Sounds/HoleIn.mp3",
	"res://Sounds/HitFlag.mp3",
	"res://Sounds/DeathGroan.mp3",
	"res://Sounds/CardDraw.mp3",
	"res://Sounds/Discard.mp3",
	"res://Sounds/PistolShot.mp3",
	"res://Sounds/Birds.mp3",
	"res://Sounds/LeavesRustle.mp3",
	"res://Sounds/TrunkThunk.mp3",
	"res://CardTouch.mp3",
	"res://CardPlaySound.mp3",
	"res://Shuffle.mp3",
	
	# Character textures
	"res://Character1.png",
	"res://Character2.png",
	"res://Character3.png",
	"res://Character1sec.png",
	"res://LaylaMid.png",
	"res://BennyMid.png",
	"res://ClarkMid.png",
	
	# Card textures
	"res://Cards/Driver.png",
	"res://Cards/Wood.png",
	"res://Cards/Hybrid.png",
	"res://Cards/Iron.png",
	"res://Cards/PitchingWedge.png",
	"res://Cards/Putter.png",
	"res://Cards/Move1.png",
	"res://Cards/Move2.png",
	"res://Cards/Move3.png",
	"res://Cards/Move4.png",
	"res://Cards/Move5.png",
	"res://Cards/FireClub.png",
	"res://Cards/IceClub.png",
	"res://Cards/ExtraBall.png",
	"res://Cards/StickyShot.png",
	"res://Cards/Bouncey.png",
	"res://Cards/Explosive.png",
	"res://Cards/Dub.png",
	"res://Cards/KickB.png",
	"res://Cards/Wooden.png",
	"res://Cards/FloridaScramble.png",
	"res://Cards/PistolCard.png",
]

var loaded_resources = {}
var current_load_index = 0
var total_resources = 0

func _ready():
	total_resources = resources_to_load.size()
	progress_bar.max_value = total_resources
	progress_bar.value = 0
	
	# Start loading process
	call_deferred("start_loading")

func start_loading():
	update_status("Preloading resources...")
	load_next_resource()

func load_next_resource():
	if current_load_index >= total_resources:
		on_loading_complete()
		return
	
	var resource_path = resources_to_load[current_load_index]
	update_status("Loading: " + resource_path.get_file())
	
	# Load the resource
	var resource = load(resource_path)
	if resource:
		loaded_resources[resource_path] = resource
		print("✓ Loaded: ", resource_path)
	else:
		print("✗ Failed to load: ", resource_path)
	
	current_load_index += 1
	progress_bar.value = current_load_index
	
	# Continue loading on next frame to avoid blocking
	call_deferred("load_next_resource")

func update_status(text: String):
	status_label.text = text
	print("Loading: ", text)

func on_loading_complete():
	update_status("Loading complete!")
	progress_bar.value = total_resources
	
	# Wait a moment to show completion
	await get_tree().create_timer(0.5).timeout
	
	# Transition to main menu
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://Main.tscn"), 0.5)

func get_loaded_resource(path: String):
	return loaded_resources.get(path, null) 