extends Control

@onready var power_meter: Control = $PowerMeter
@onready var start_button: Button = $StartButton
@onready var stop_button: Button = $StopButton
@onready var result_label: Label = $ResultLabel

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_button_pressed)
	stop_button.pressed.connect(_on_stop_button_pressed)
	
	# Connect PowerMeter signals
	if power_meter:
		power_meter.power_changed.connect(_on_power_changed)
		power_meter.sweet_spot_hit.connect(_on_sweet_spot_hit)
	
	# Initially hide the PowerMeter
	power_meter.visible = false

func _on_start_button_pressed():
	power_meter.start_power_meter()
	result_label.text = "Power meter started!"

func _on_stop_button_pressed():
	power_meter.stop_power_meter()
	var power = power_meter.get_current_power()
	var sweet_spot_hit = power_meter.is_sweet_spot_hit()
	result_label.text = "Power: " + str(int(power)) + "% - Sweet spot: " + ("HIT!" if sweet_spot_hit else "Miss")

func _on_power_changed(power_value: float):
	print("Power changed to: ", power_value, "%")

func _on_sweet_spot_hit():
	print("SWEET SPOT HIT!")
	result_label.text = "SWEET SPOT HIT!" 