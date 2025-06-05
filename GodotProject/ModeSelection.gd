extends Control

# Button references - Updated to match container structure like landing page
@onready var height_challenge_button = $HeightChallengeButtonContainer/HeightChallengeButton as TextureButton
@onready var endless_stack_button = $EndlessStackButtonContainer/EndlessStackButton as TextureButton
@onready var back_button = $BackButtonContainer/BackButton as TextureButton
@onready var settings_button = $SettingsButtonContainer/SettingsButton as TextureButton
@onready var logo = $Logo  
@onready var background = $Background

# Scene paths - Adjust these to match your actual scene paths
const HEIGHT_CHALLENGE_SCENE = "res://Main.tscn"
const ENDLESS_STACK_SCENE = "res://EndlessStackGame.tscn"
const LANDING_PAGE_SCENE = "res://LandingPage.tscn"
const SETTINGS_SCENE = "res://scenes/SettingsScene.tscn"

# Design resolution (should match your landing page)
const DESIGN_WIDTH = 1080.0
const DESIGN_HEIGHT = 1920.0

# Pulsing animation variables
var height_pulse_tween: Tween
var endless_pulse_tween: Tween
var is_height_pulsing = false
var is_endless_pulsing = false

func _ready():
	# Set this Control to fill the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Debug: Print node hierarchy to troubleshoot
	print("=== Mode Selection Scene Structure ===")
	_print_node_tree(self, 0)
	print("====================================")
	
	# Connect button press signals with null checks
	if height_challenge_button:
		print("Height Challenge Button found - connecting signals")
		height_challenge_button.pressed.connect(_on_height_challenge_pressed)
		
		# Connect visual state signals
		height_challenge_button.button_down.connect(func(): _on_button_pressed(height_challenge_button))
		height_challenge_button.button_up.connect(func(): _on_button_released(height_challenge_button))
		height_challenge_button.mouse_entered.connect(_on_button_hover)
		height_challenge_button.mouse_exited.connect(_on_button_unhover)
	else:
		print("ERROR: HeightChallengeButton not found! Check your scene structure.")
		print("Expected path: HeightChallengeButtonContainer/HeightChallengeButton")
	
	if endless_stack_button:
		print("Endless Stack Button found - connecting signals")
		endless_stack_button.pressed.connect(_on_endless_stack_pressed)
		
		# Connect visual state signals
		endless_stack_button.button_down.connect(func(): _on_button_pressed(endless_stack_button))
		endless_stack_button.button_up.connect(func(): _on_button_released(endless_stack_button))
		endless_stack_button.mouse_entered.connect(_on_button_hover)
		endless_stack_button.mouse_exited.connect(_on_button_unhover)
	else:
		print("ERROR: EndlessStackButton not found! Check your scene structure.")
		print("Expected path: EndlessStackButtonContainer/EndlessStackButton")
	
	if back_button:
		print("Back Button found - connecting signals")
		back_button.pressed.connect(_on_back_button_pressed)
		
		# Connect visual state signals
		back_button.button_down.connect(func(): _on_button_pressed(back_button))
		back_button.button_up.connect(func(): _on_button_released(back_button))
		back_button.mouse_entered.connect(_on_button_hover)
		back_button.mouse_exited.connect(_on_button_unhover)
	else:
		print("ERROR: BackButton not found! Check your scene structure.")
		print("Expected path: BackButtonContainer/BackButton")
	
	if settings_button:
		print("Settings Button found - connecting signals")
		settings_button.pressed.connect(_on_settings_button_pressed)
		
		# Connect visual state signals
		settings_button.button_down.connect(func(): _on_button_pressed(settings_button))
		settings_button.button_up.connect(func(): _on_button_released(settings_button))
		settings_button.mouse_entered.connect(_on_button_hover)
		settings_button.mouse_exited.connect(_on_button_unhover)
	else:
		print("ERROR: SettingsButton not found! Check your scene structure.")
		print("Expected path: SettingsButtonContainer/SettingsButton")
	
	# Set up mobile-specific settings
	setup_mobile_settings()
	
	# Start the pulsing animations after a short delay
	call_deferred("start_all_pulsing_animations")

# Helper function to print node tree for debugging
func _print_node_tree(node: Node, depth: int):
	var indent = ""
	for i in depth:
		indent += "  "
	
	var info = indent + node.name + " (" + node.get_class() + ")"
	print(info)
	
	for child in node.get_children():
		_print_node_tree(child, depth + 1)

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

# Pulsing animation functions
func start_all_pulsing_animations():
	if height_challenge_button:
		start_height_challenge_pulsing()
	if endless_stack_button:
		# Add a slight delay so they don't pulse in perfect sync
		get_tree().create_timer(0.4).timeout.connect(start_endless_stack_pulsing)

func start_height_challenge_pulsing():
	if is_height_pulsing or not height_challenge_button:
		return
	
	is_height_pulsing = true
	height_pulse_tween = create_tween()
	height_pulse_tween.set_loops()  # Make it loop infinitely
	
	# Create a smooth pulsing effect
	height_pulse_tween.tween_property(height_challenge_button, "scale", Vector2(1.05, 1.05), 0.8)
	height_pulse_tween.tween_property(height_challenge_button, "scale", Vector2(1.0, 1.0), 0.8)

func start_endless_stack_pulsing():
	if is_endless_pulsing or not endless_stack_button:
		return
	
	is_endless_pulsing = true
	endless_pulse_tween = create_tween()
	endless_pulse_tween.set_loops()  # Make it loop infinitely
	
	# Create a smooth pulsing effect
	endless_pulse_tween.tween_property(endless_stack_button, "scale", Vector2(1.05, 1.05), 0.8)
	endless_pulse_tween.tween_property(endless_stack_button, "scale", Vector2(1.0, 1.0), 0.8)

func stop_height_challenge_pulsing():
	if height_pulse_tween:
		height_pulse_tween.kill()
	is_height_pulsing = false
	
	# Ensure button returns to normal scale
	if height_challenge_button:
		var reset_tween = create_tween()
		reset_tween.tween_property(height_challenge_button, "scale", Vector2.ONE, 0.2)

func stop_endless_stack_pulsing():
	if endless_pulse_tween:
		endless_pulse_tween.kill()
	is_endless_pulsing = false
	
	# Ensure button returns to normal scale
	if endless_stack_button:
		var reset_tween = create_tween()
		reset_tween.tween_property(endless_stack_button, "scale", Vector2.ONE, 0.2)

func stop_all_pulsing():
	stop_height_challenge_pulsing()
	stop_endless_stack_pulsing()

# Button visual state functions
func _on_button_pressed(button: TextureButton):
	if not button:
		return
		
	# Temporarily stop pulsing when button is pressed
	if button == height_challenge_button and is_height_pulsing:
		stop_height_challenge_pulsing()
	elif button == endless_stack_button and is_endless_pulsing:
		stop_endless_stack_pulsing()
	
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.1)

func _on_button_released(button: TextureButton):
	if not button:
		return
		
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.1)
	
	# Restart pulsing after button release for game mode buttons
	if button == height_challenge_button:
		get_tree().create_timer(0.3).timeout.connect(start_height_challenge_pulsing)
	elif button == endless_stack_button:
		get_tree().create_timer(0.3).timeout.connect(start_endless_stack_pulsing)

func _on_button_hover():
	play_hover_sound()

func _on_button_unhover():
	pass

# Button action functions
func _on_height_challenge_pressed():
	print("Height Challenge button pressed!")
	play_button_sound()
	stop_all_pulsing()  # Stop all pulsing when transitioning
	
	# Check if scene file exists
	if ResourceLoader.exists(HEIGHT_CHALLENGE_SCENE):
		print("Loading scene: ", HEIGHT_CHALLENGE_SCENE)
		get_tree().change_scene_to_file(HEIGHT_CHALLENGE_SCENE)
	else:
		print("Error: Scene file not found: ", HEIGHT_CHALLENGE_SCENE)

func _on_endless_stack_pressed():
	print("Endless Stack button pressed!")
	play_button_sound()
	stop_all_pulsing()  # Stop all pulsing when transitioning
	
	# Check if scene file exists
	if ResourceLoader.exists(ENDLESS_STACK_SCENE):
		print("Loading scene: ", ENDLESS_STACK_SCENE)
		get_tree().change_scene_to_file(ENDLESS_STACK_SCENE)
	else:
		print("Error: Scene file not found: ", ENDLESS_STACK_SCENE)

func _on_back_button_pressed():
	print("Back button pressed!")
	play_button_sound()
	stop_all_pulsing()  # Stop all pulsing when going back
	
	# Check if scene file exists
	if ResourceLoader.exists(LANDING_PAGE_SCENE):
		print("Loading scene: ", LANDING_PAGE_SCENE)
		get_tree().change_scene_to_file(LANDING_PAGE_SCENE)
	else:
		print("Error: Scene file not found: ", LANDING_PAGE_SCENE)

func _on_settings_button_pressed():
	print("Settings button pressed!")
	play_button_sound()
	
	# Check if scene file exists
	if ResourceLoader.exists(SETTINGS_SCENE):
		print("Loading scene: ", SETTINGS_SCENE)
		get_tree().change_scene_to_file(SETTINGS_SCENE)
	else:
		print("Error: Scene file not found: ", SETTINGS_SCENE)

# Audio functions
func play_button_sound():
	pass

func play_hover_sound():
	pass

# Cleanup function
func _exit_tree():
	if height_pulse_tween:
		height_pulse_tween.kill()
	if endless_pulse_tween:
		endless_pulse_tween.kill()
