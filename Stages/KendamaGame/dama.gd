extends CharacterBody2D

# The dama ball that is attached to the Ken by a string so the Ken can yank up and pull the ball up to try and land on the spike

var gravity = 980.0
var damping = 0.98
var is_on_tip = false

@onready var spike_area = $SpikeArea

func _ready():
	spike_area.body_entered.connect(_on_spike_area_body_entered)

func _physics_process(delta):
	if not is_on_tip:
		self.velocity.y += gravity * delta
		self.velocity *= damping
		move_and_slide()

func set_on_tip(value: bool):
	is_on_tip = value

func _on_spike_area_body_entered(body):
	if body.has_method("is_ken_tip"):
		print("Ken tip entered SpikeArea!")
		get_parent()._on_dama_hole_entered(body)
