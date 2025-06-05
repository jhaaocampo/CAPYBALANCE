extends Control

# Button references
@onready var start_button = $StartButtonContainer/StartButton
@onready var volume_button = $VolumeButtonContainer/VolumeButton
@onready var leave_button = $LeaveButtonContainer/LeaveButton
@onready var logo = $Logo
@onready var background = $Background

# Animation variables
var pulse_tween: Tween

# Volume state
var volume_enabled: bool = true

# Scene paths
const GAME_SCENE = "res://ModeSelection.tscn"

func _ready():
	# Set this Control to fill the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Load volume setting
	load_volume_setting()
	
	# Enable toggle mode for volume button
	volume_button.toggle_mode = true
	volume_button.button_pressed = !volume_enabled  # Inverted because pressed = muted
	
	# Connect button press signals
	start_button.pressed.connect(_on_start_button_pressed)
	volume_button.pressed.connect(_on_volume_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)
	
	# Connect button visual state signals for Start button
	start_button.button_down.connect(func(): _on_button_pressed(start_button))
	start_button.button_up.connect(func(): _on_button_released(start_button))
	start_button.mouse_entered.connect(_on_button_hover)
	start_button.mouse_exited.connect(_on_button_unhover)
	
	# Connect button visual state signals for Volume button
	volume_button.button_down.connect(func(): _on_button_pressed(volume_button))
	volume_button.button_up.connect(func(): _on_button_released(volume_button))
	volume_button.mouse_entered.connect(_on_button_hover)
	volume_button.mouse_exited.connect(_on_button_unhover)
	
	# Connect button visual state signals for Leave button
	leave_button.button_down.connect(func(): _on_button_pressed(leave_button))
	leave_button.button_up.connect(func(): _on_button_released(leave_button))
	leave_button.mouse_entered.connect(_on_button_hover)
	leave_button.mouse_exited.connect(_on_button_unhover)
	
	# Start the pulsing animation for the start button
	start_pulse_animation()

# Volume functions
func _on_volume_button_pressed():
	toggle_volume()

func toggle_volume():
	volume_enabled = !volume_button.button_pressed  # Inverted because pressed = muted
	save_volume_setting()
	apply_volume_setting()
	
	if volume_enabled:
		play_button_sound()

func apply_volume_setting():
	# Set the master audio bus volume
	var master_bus_index = AudioServer.get_bus_index("Master")
	if volume_enabled:
		AudioServer.set_bus_volume_db(master_bus_index, 0.0)  # Normal volume
	else:
		AudioServer.set_bus_volume_db(master_bus_index, -80.0)  # Effectively muted

func save_volume_setting():
	# Save volume setting to a simple config file
	var config = ConfigFile.new()
	config.set_value("audio", "volume_enabled", volume_enabled)
	config.save("user://volume_settings.cfg")

func load_volume_setting():
	# Load volume setting from config file
	var config = ConfigFile.new()
	var err = config.load("user://volume_settings.cfg")
	if err == OK:
		volume_enabled = config.get_value("audio", "volume_enabled", true)
	else:
		volume_enabled = true  # Default to volume on
	
	# Apply the loaded setting
	apply_volume_setting()

# Pulsing animation functions
func start_pulse_animation():
	if pulse_tween:
		pulse_tween.kill()
	
	pulse_tween = create_tween()
	pulse_tween.set_loops() # Infinite loop
	
	# Scale up and down with a smooth ease
	pulse_tween.tween_property(start_button, "scale", Vector2(1.05, 1.05), 0.8)
	pulse_tween.tween_property(start_button, "scale", Vector2.ONE, 0.8)
	
	# Set easing for smoother animation
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_trans(Tween.TRANS_SINE)

# Button visual state functions
func _on_button_pressed(button: TextureButton):
	# Create a temporary press animation that doesn't interfere with pulsing
	var press_tween = create_tween()
	var original_modulate = button.modulate
	press_tween.tween_property(button, "modulate", Color(0.8, 0.8, 0.8, 1.0), 0.1)
	press_tween.tween_property(button, "modulate", original_modulate, 0.1)

func _on_button_released(button: TextureButton):
	# No need to do anything special on release since we're not stopping animations
	pass

# Hover functions
func _on_button_hover():
	if volume_enabled:
		play_hover_sound()

func _on_button_unhover():
	pass

# Button action functions
func _on_start_button_pressed():
	if volume_enabled:
		play_button_sound()
	start_game_transition()

func _on_leave_button_pressed():
	if volume_enabled:
		play_button_sound()
	show_quit_confirmation()

# Audio functions
func play_button_sound():
	pass

func play_hover_sound():
	pass

func start_game_transition():
	start_button.disabled = true
	volume_button.disabled = true
	leave_button.disabled = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file(GAME_SCENE))

func show_quit_confirmation():
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Are you sure you want to quit?"
	dialog.title = "Confirm Exit"
	
	dialog.add_button("Cancel", false, "cancel")
	dialog.add_button("Quit", true, "quit")
	
	add_child(dialog)
	dialog.popup_centered()
	
	dialog.custom_action.connect(_on_quit_dialog_action)
	dialog.confirmed.connect(_quit_game)

func _on_quit_dialog_action(action):
	if action == "quit":
		_quit_game()

func _quit_game():
	get_tree().quit()
