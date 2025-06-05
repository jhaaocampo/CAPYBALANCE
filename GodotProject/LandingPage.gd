extends Control

# Button references
@onready var start_button = $StartButtonContainer/StartButton
@onready var settings_button = $SettingsButtonContainer/SettingsButton
@onready var leave_button = $LeaveButtonContainer/LeaveButton
@onready var logo = $Logo
@onready var background = $Background

# Scene paths
const GAME_SCENE = "res://Main.tscn"
const SETTINGS_SCENE = "res://scenes/SettingsScene.tscn"

# Design resolution (the resolution you designed your UI for)
const DESIGN_WIDTH = 1080.0
const DESIGN_HEIGHT = 1920.0

func _ready():
	# Set this Control to fill the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Connect button press signals
	start_button.pressed.connect(_on_start_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)
	
	# Connect button visual state signals for Start button
	start_button.button_down.connect(func(): _on_button_pressed(start_button))
	start_button.button_up.connect(func(): _on_button_released(start_button))
	start_button.mouse_entered.connect(_on_button_hover)
	start_button.mouse_exited.connect(_on_button_unhover)
	
	# Connect button visual state signals for Settings button
	settings_button.button_down.connect(func(): _on_button_pressed(settings_button))
	settings_button.button_up.connect(func(): _on_button_released(settings_button))
	settings_button.mouse_entered.connect(_on_button_hover)
	settings_button.mouse_exited.connect(_on_button_unhover)
	
	# Connect button visual state signals for Leave button
	leave_button.button_down.connect(func(): _on_button_pressed(leave_button))
	leave_button.button_up.connect(func(): _on_button_released(leave_button))
	leave_button.mouse_entered.connect(_on_button_hover)
	leave_button.mouse_exited.connect(_on_button_unhover)
	
	# Set up mobile-specific settings
	setup_mobile_settings()

func setup_mobile_settings():
	# Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Call once to set initial scaling
	call_deferred("_on_viewport_size_changed")

func _on_viewport_size_changed():
	var viewport_size = get_viewport().size
	print("Viewport size: ", viewport_size)
	
	# Calculate scale factors
	var scale_x = viewport_size.x / DESIGN_WIDTH
	var scale_y = viewport_size.y / DESIGN_HEIGHT
	
	# Use the smaller scale to maintain aspect ratio
	var scale_factor = min(scale_x, scale_y)
	
	print("Scale factor: ", scale_factor)
	
	# Apply scaling to the entire UI
	scale = Vector2(scale_factor, scale_factor)
	
	# Center the UI if there's extra space
	var scaled_width = DESIGN_WIDTH * scale_factor
	var scaled_height = DESIGN_HEIGHT * scale_factor
	
	position.x = (viewport_size.x - scaled_width) / 2.0
	position.y = (viewport_size.y - scaled_height) / 2.0
	
	# Ensure size matches design resolution
	size = Vector2(DESIGN_WIDTH, DESIGN_HEIGHT)

# Alternative scaling method - try this if the above doesn't work
func setup_alternative_scaling():
	# Set the Control to use the full screen
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

# Button visual state functions
func _on_button_pressed(button: Button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.1)

func _on_button_released(button: Button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.1)

func _on_button_hover():
	play_hover_sound()

func _on_button_unhover():
	pass

# Button action functions
func _on_start_button_pressed():
	play_button_sound()
	start_game_transition()

func _on_settings_button_pressed():
	play_button_sound()
	get_tree().change_scene_to_file(SETTINGS_SCENE)

func _on_leave_button_pressed():
	play_button_sound()
	show_quit_confirmation()

# Audio functions
func play_button_sound():
	pass

func play_hover_sound():
	pass

func start_game_transition():
	start_button.disabled = true
	settings_button.disabled = true
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
