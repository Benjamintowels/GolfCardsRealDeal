extends Node

var shake_timer: Timer = null
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_elapsed: float = 0.0
var original_camera_position: Vector2
var camera: Camera2D = null

func _ready():
	# Try to find the main camera in the scene
	if not camera:
		camera = get_tree().current_scene.get_node_or_null("GameCamera")

func shake_camera(intensity: float = 12.0, duration: float = 0.25):
	if not camera:
		camera = get_tree().current_scene.get_node_or_null("GameCamera")
	if not camera:
		print("CameraEffectManager: No camera found for shake!")
		return
	shake_intensity = intensity
	shake_duration = duration
	shake_elapsed = 0.0
	original_camera_position = camera.position
	set_process(true)

func _process(delta):
	if shake_elapsed < shake_duration:
		shake_elapsed += delta
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
		camera.position = original_camera_position + offset
	else:
		if camera:
			camera.position = original_camera_position
		set_process(false)
