# PauseMenu.gd

extends Control

# UI References - Based on your PauseMenu.tscn structure
@onready var pause_label = $CanvasLayer/GameoverBox/Label
@onready var restart_button = $CanvasLayer/RestartButtonContainer/RestartButton
@onready var menu_button = $CanvasLayer/MenuButtonContainer/MenuButton
@onready var x_button = $CanvasLayer/XButtonContainer/XButton
@onready var backgrounds = $Backgrounds
@onready var button_sound = $ButtonSound
@onready var mute: bool = false
# Volume state
var volume_enabled: bool = true

# Scene paths
const MAIN_SCENE = "res://Main.tscn"
const HEIGHT_CHALLENGE_SCENE = "res://HeightChallenge.tscn"
const LANDING_PAGE_SCENE = "res://ModeSelection.tscn"

# Game mode detection
var is_height_challenge: bool = false

var button_original_scales: Dictionary = {}
var button_hover_tweens: Dictionary = {}
var button_click_tweens: Dictionary = {}

func _ready():
	# Validate that all required nodes exist
	if not validate_nodes():
		push_error("Pause Menu Scene: Missing required UI nodes!")
		return
	
	# Set this Control to fill the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Make sure it processes even when paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Connect button signals
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
	if x_button:
		x_button.pressed.connect(_on_x_button_pressed)
	
	# Connect button visual state signals
	connect_button_signals()
	
	# Load volume setting
	load_volume_setting()
	
	# Detect game mode
	detect_game_mode()
	
	# Setup display
	setup_display()
	
	# Start animations
	animate_entrance()
	
	# Ensure the game stays paused
	get_tree().paused = true

func validate_nodes() -> bool:
	# Check if critical nodes exist
	var required_nodes = [x_button, restart_button]  # X button and restart are required
	
	for node in required_nodes:
		if node == null:
			return false
	
	return true

func connect_button_signals():
	# Store original scales for all buttons
	var buttons = [restart_button, menu_button, x_button]
	
	for button in buttons:
		if button:
			button_original_scales[button] = button.scale
			
			# Connect press/release signals for click effects
			button.button_down.connect(func(): _on_button_pressed(button))
			button.button_up.connect(func(): _on_button_released(button))
			
			# Connect hover signals for hover effects (all buttons get hover effects now)
			button.mouse_entered.connect(func(): _on_button_hover_enter(button))
			button.mouse_exited.connect(func(): _on_button_hover_exit(button))

# Hover effects (for all buttons)
func _on_button_hover_enter(button: TextureButton):
	# Cancel any existing hover tween for this button
	if button_hover_tweens.has(button) and button_hover_tweens[button]:
		button_hover_tweens[button].kill()
	
	# Create new tween for hover effect
	button_hover_tweens[button] = create_tween()
	button_hover_tweens[button].set_parallel(true)
	
	# Scale up and brighten on hover
	var original_scale = button_original_scales[button]
	var target_scale = original_scale * 1.03
	button_hover_tweens[button].tween_property(button, "scale", target_scale, 0.1)
	button_hover_tweens[button].tween_property(button, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1)
	
	# Play hover sound
	play_hover_sound()

func _on_button_hover_exit(button: TextureButton):
	# Cancel any existing hover tween for this button
	if button_hover_tweens.has(button) and button_hover_tweens[button]:
		button_hover_tweens[button].kill()
	
	# Create new tween to return to original state
	button_hover_tweens[button] = create_tween()
	button_hover_tweens[button].set_parallel(true)
	
	# Scale back to original size and normal color
	var original_scale = button_original_scales[button]
	button_hover_tweens[button].tween_property(button, "scale", original_scale, 0.1)
	button_hover_tweens[button].tween_property(button, "modulate", Color.WHITE, 0.1)

func detect_game_mode():
	# Try to detect from current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		var script = current_scene.get_script()
		if script:
			var script_path = script.get_path()
			is_height_challenge = script_path.get_file() == "HeightChallenge.gd"
	
	print("Pause Menu - Height Challenge mode: ", is_height_challenge)

func setup_display():
	# Set pause label text
	if pause_label:
		pause_label.text = "PAUSED"
	
	# Setup backgrounds if needed
	if backgrounds:
		backgrounds.modulate = Color.WHITE  # Ensure backgrounds are visible

func animate_entrance():
	# Start with everything invisible/scaled down
	if pause_label:
		pause_label.modulate.a = 0.0
	if restart_button:
		restart_button.modulate.a = 0.0
	if menu_button:
		menu_button.modulate.a = 0.0
	if x_button:
		x_button.modulate.a = 0.0
	
	var entrance_tween = create_tween()
	entrance_tween.set_parallel(true)
	
	# Fade in pause label
	if pause_label:
		entrance_tween.tween_property(pause_label, "modulate:a", 1.0, 0.3)
	
	# Fade in buttons with slight delays
	if restart_button:
		entrance_tween.tween_interval(0.1)
		entrance_tween.tween_property(restart_button, "modulate:a", 1.0, 0.3)
	
	if menu_button:
		entrance_tween.tween_interval(0.2)
		entrance_tween.tween_property(menu_button, "modulate:a", 1.0, 0.3)
	
	if x_button:
		entrance_tween.tween_interval(0.3)
		entrance_tween.tween_property(x_button, "modulate:a", 1.0, 0.3)

# Button interaction functions
func _on_button_pressed(button: TextureButton):
	# Cancel any existing click tween for this button
	if button_click_tweens.has(button) and button_click_tweens[button]:
		button_click_tweens[button].kill()
	
	# Create new tween for press effect
	button_click_tweens[button] = create_tween()
	button_click_tweens[button].set_parallel(true)
	
	# Scale down slightly on click (no color change)
	var original_scale = button_original_scales[button]
	var pressed_scale = original_scale * 0.95
	button_click_tweens[button].tween_property(button, "scale", pressed_scale, 0.03)

func _on_button_released(button: TextureButton):
	# Cancel any existing click tween for this button
	if button_click_tweens.has(button) and button_click_tweens[button]:
		button_click_tweens[button].kill()
	
	# Create new tween for release effect
	button_click_tweens[button] = create_tween()
	button_click_tweens[button].set_parallel(true)
	
	# Determine target scale and color based on whether mouse is still hovering
	var target_scale = button_original_scales[button]
	var target_color = Color.WHITE
	
	if button.is_hovered():
		# Mouse is still over the button, return to hover state
		target_scale = button_original_scales[button] * 1.03
		target_color = Color(1.2, 1.2, 1.2, 1.0)
	
	# Return to appropriate scale and color
	button_click_tweens[button].tween_property(button, "scale", target_scale, 0.1)
	button_click_tweens[button].tween_property(button, "modulate", target_color, 0.1)

# Button action functions
func _on_x_button_pressed():
	play_button_sound()
	resume_game()

func _on_restart_button_pressed():
	play_button_sound()
	restart_game()

func _on_menu_button_pressed():
	play_button_sound()
	go_to_main_menu()

# Game control functions
func resume_game():
	# Unpause the game
	get_tree().paused = false
	
	# Remove this pause menu
	queue_free()

func restart_game():
	# Unpause the game first
	get_tree().paused = false
	
	# Reload the current scene
	get_tree().reload_current_scene()

func go_to_main_menu():
	# Unpause the game
	get_tree().paused = false
	
	# Go to landing page
	get_tree().change_scene_to_file(LANDING_PAGE_SCENE)

# Audio functions
func play_button_sound():
	if volume_enabled and button_sound:
		button_sound.play()

func play_hover_sound():
	# Add your hover sound logic here
	pass

func load_volume_setting():
	# Load volume setting from config file (same as Scoreboard)
	var config = ConfigFile.new()
	var err = config.load("user://volume_settings.cfg")
	if err == OK:
		volume_enabled = config.get_value("audio", "volume_enabled", true)
	else:
		volume_enabled = true

# Handle ESC key to resume
func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		resume_game()

# Public method to setup as overlay (called from Scoreboard)
func setup_as_overlay():
	# Make sure it's on top of everything
	z_index = 100
	
	# Set to fill screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Make sure it processes when paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
