extends Node2D
class_name BennyArmHeightController

# References
var benny_armless_sprite: Sprite2D = null
var benny_normal_sprite: Sprite2D = null  # The normal BennyChar sprite
var benny_arm_height: Node2D = null
var pivot_point: Marker2D = null  # The pivot point for rotation
var rotation_container: Node2D = null  # Container for rotation around pivot
var camera: Camera2D = null
var player_node: Node2D = null
var launch_manager: Node = null  # Reference to get height value

# Height-based rotation limits
const MIN_HEIGHT = 0.0
const MAX_HEIGHT = 200.0  # Updated to match actual height range from LaunchManager
const MIN_ROTATION_DEG = 90.0  # 90 degrees for 0 height (arm pointing up)
const MAX_ROTATION_DEG = 0.0   # 0 degrees for 200 height (arm pointing down)

# Old rotation limits (no longer used)
# const MAX_ROTATION_UP = -90.0  # 90 degrees up (negative because Godot's rotation is clockwise)
# const MAX_ROTATION_DOWN = 0.0  # 0 degrees down (horizontal)

# State tracking
var is_set_height_phase = false

func _ready():
	# Find the BennyArmlessSprite in the character scene
	# It should be a sibling of this controller
	benny_armless_sprite = get_parent().get_node_or_null("BennyArmlessSprite")
	if not benny_armless_sprite:
		print("⚠ BennyArmlessSprite not found")
		return
	
	# Find the normal BennyChar sprite (the main Sprite2D)
	benny_normal_sprite = get_parent().get_node_or_null("Sprite2D")
	if not benny_normal_sprite:
		print("⚠ Normal BennyChar sprite not found")
		return
	
	# Load and instantiate the BennyArmHeight scene
	var benny_arm_height_scene = preload("res://Characters/BennyArmHeight.tscn")
	if benny_arm_height_scene:
		benny_arm_height = benny_arm_height_scene.instantiate()
		benny_arm_height.visible = false  # Start hidden
		
		# Position the arm height sprite with X offset of 15.0
		# The BennyArmHeight scene has its origin at the rotation point
		benny_arm_height.position = benny_armless_sprite.position + Vector2(15.0, 0.0)
		
		# Find the pivot point and rotation container
		pivot_point = benny_arm_height.get_node_or_null("PivotPoint")
		rotation_container = benny_arm_height.get_node_or_null("PivotPoint/RotationContainer")
		
		if pivot_point and rotation_container:
			print("✓ PivotPoint and RotationContainer found for rotation")
			print("  PivotPoint position:", pivot_point.position)
			print("  RotationContainer found:", rotation_container != null)
		else:
			print("⚠ PivotPoint or RotationContainer not found - will use default rotation")
			print("  PivotPoint:", pivot_point != null)
			print("  RotationContainer:", rotation_container != null)
		
		add_child(benny_arm_height)
		print("✓ BennyArmHeight scene loaded and added at position:", benny_arm_height.position)
	else:
		print("⚠ BennyArmHeight scene not found")

func _process(delta):
	if not is_set_height_phase or not benny_arm_height or not launch_manager:
		return
	
	# Update rotation based on height
	_update_arm_rotation()

func _update_arm_rotation():
	"""Update the arm rotation based on height value"""
	if not benny_arm_height or not launch_manager:
		return
	
	# Get the current height from the launch manager
	var current_height = 0.0
	if launch_manager.has_method("get_launch_height"):
		current_height = launch_manager.get_launch_height()
	
	# Clamp height to our range
	var clamped_height = clamp(current_height, MIN_HEIGHT, MAX_HEIGHT)
	
	# Calculate rotation based on height (linear interpolation)
	var height_ratio = (clamped_height - MIN_HEIGHT) / (MAX_HEIGHT - MIN_HEIGHT)
	var rotation_deg = lerp(MIN_ROTATION_DEG, MAX_ROTATION_DEG, height_ratio)
	
	# Convert to radians for rotation
	var rotation_rad = deg_to_rad(rotation_deg)
	
	# Apply the rotation around the pivot point
	if rotation_container:
		# Rotate the container around the pivot point
		rotation_container.rotation = rotation_rad
	else:
		# Fallback to default rotation on the main node
		benny_arm_height.rotation = rotation_rad
	
	# Debug output (only occasionally to avoid spam)
	if Time.get_ticks_msec() % 1000 < 16:  # Only every ~1 second
		print("Arm rotation - Height: ", current_height, " Clamped: ", clamped_height, " Rotation: ", rotation_deg, " Radians: ", rotation_rad, " Pivot: ", pivot_point != null, " Container: ", rotation_container != null)

func set_set_height_phase(active: bool):
	"""Set whether we're in the SetHeight phase"""
	print("BennyArmHeightController: set_set_height_phase called with active =", active)
	is_set_height_phase = active
	
	if not benny_armless_sprite or not benny_arm_height or not benny_normal_sprite:
		print("⚠ Cannot set SetHeight phase - missing sprites")
		print("  BennyArmlessSprite:", benny_armless_sprite != null)
		print("  BennyArmHeight:", benny_arm_height != null)
		print("  NormalSprite:", benny_normal_sprite != null)
		return
	
	if active:
		# Hide the normal sprite and show the armless sprite and arm height
		benny_normal_sprite.visible = false
		benny_armless_sprite.visible = true
		benny_arm_height.visible = true
		print("✓ SetHeight phase activated - showing arm visual effect")
		print("  NormalSprite visible:", benny_normal_sprite.visible)
		print("  BennyArmlessSprite visible:", benny_armless_sprite.visible)
		print("  BennyArmHeight visible:", benny_arm_height.visible)
		print("  Camera available:", camera != null)
	else:
		# Show the normal sprite and hide the armless sprite and arm height
		benny_normal_sprite.visible = true
		benny_armless_sprite.visible = false
		benny_arm_height.visible = false
		print("✓ SetHeight phase deactivated - hiding arm visual effect")
		print("  NormalSprite visible:", benny_normal_sprite.visible)

func set_camera_reference(camera_ref: Camera2D):
	"""Set the camera reference for mouse position calculation"""
	camera = camera_ref
	print("✓ Camera reference set for BennyArmHeightController")

func set_player_reference(player_ref: Node2D):
	"""Set the player reference"""
	player_node = player_ref
	print("✓ Player reference set for BennyArmHeightController")

func _on_height_changed(new_height: float):
	"""Called when the height value changes in the launch manager"""
	if is_set_height_phase and benny_arm_height:
		# Update rotation immediately when height changes
		_update_arm_rotation()
		print("✓ Arm rotation updated immediately for height:", new_height)

func set_launch_manager_reference(launch_mgr: Node):
	"""Set the launch manager reference for height data"""
	launch_manager = launch_mgr
	print("✓ Launch manager reference set for BennyArmHeightController")
	
	# Connect to height changed signal for immediate updates
	if launch_manager and launch_manager.has_signal("height_changed"):
		launch_manager.height_changed.connect(_on_height_changed)
		print("✓ Connected to height_changed signal")
	else:
		print("⚠ Launch manager missing height_changed signal") 
