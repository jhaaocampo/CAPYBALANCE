extends Control

# Button references
@onready var start_button = $StartButtonContainer/StartButton
@onready var settings_button = $SettingsButtonContainer/SettingsButton
@onready var leave_button = $LeaveButtonContainer/LeaveButton
@onready var logo = $Logo
@onready var background = $Background
@onready var landing_page_music = $LandingPageMusic
@onready var button_sound = $ButtonSound

# Audio mute flag
@onready var mute: bool = false

# Animation variables
var pulse_tween: Tween

# Scene paths
const GAME_SCENE = "res://ModeSelection.tscn"
const SETTINGS_SCENE = "res://scenes/SettingsScene.tscn"

func _ready():
	# Set this Control to fill the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Play background music
	play_music()
	

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

	# Start the pulsing animation for the start button
	start_pulse_animation()

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
	var press_tween = create_tween()
	var original_modulate = button.modulate
	press_tween.tween_property(button, "modulate", Color(0.8, 0.8, 0.8, 1.0), 0.1)
	press_tween.tween_property(button, "modulate", original_modulate, 0.1)

func _on_button_released(button: TextureButton):
	pass

# Hover functions
func _on_button_hover():
	play_hover_sound()

func _on_button_unhover():
	pass

# Button action functions
func _on_start_button_pressed():
	play_button_sound()
	start_game_transition()
	play_button_sound()

func _on_settings_button_pressed():
	play_button_sound()
	get_tree().change_scene_to_file(SETTINGS_SCENE)
	play_button_sound()

func _on_leave_button_pressed():
	play_button_sound()
	show_quit_confirmation()
	play_button_sound()

# Audio functions
func play_music() -> void:
	if not mute and landing_page_music:
		landing_page_music.play()

func play_button_sound():
	if not mute and landing_page_music:
		button_sound.play()

func play_hover_sound():
	pass # Add hover sound here

# Scene transition
func start_game_transition():
	start_button.disabled = true
	settings_button.disabled = true
	leave_button.disabled = true

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file(GAME_SCENE))

# Quit confirmation dialog
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
