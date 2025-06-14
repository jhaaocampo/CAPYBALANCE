# ModeSelection.gd

extends Control

# Button references
@onready var height_challenge_button = $HeightChallengeButtonContainer/HeightChallengeButton
@onready var endless_stack_button = $EndlessStackButtonContainer/EndlessStackButton
@onready var back_button = $BackButtonContainer/BackButton
@onready var title_label = $TitleLabel
@onready var background = $Background
@onready var landing_page_music = $LandingPageMusic
@onready var button_sound = $ButtonSound
@onready var mute: bool = false

# Animation variables
var height_pulse_tween: Tween
var endless_pulse_tween: Tween

# Scene paths
const HEIGHT_CHALLENGE_SCENE = "res://HeightChallenge.tscn"
const ENDLESS_STACK_SCENE = "res://Main.tscn"
const LANDING_PAGE_SCENE = "res://LandingPage.tscn"

func _ready():
	landing_page_music.play()
	# Set this Control to fill the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Connect button press signals
	height_challenge_button.pressed.connect(_on_height_challenge_button_pressed)
	endless_stack_button.pressed.connect(_on_endless_stack_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Connect button visual state signals for Height Challenge button
	height_challenge_button.button_down.connect(func(): _on_button_pressed(height_challenge_button))
	height_challenge_button.button_up.connect(func(): _on_button_released(height_challenge_button))
	height_challenge_button.mouse_entered.connect(_on_button_hover)
	height_challenge_button.mouse_exited.connect(_on_button_unhover)
	
	# Connect button visual state signals for Endless Stack button
	endless_stack_button.button_down.connect(func(): _on_button_pressed(endless_stack_button))
	endless_stack_button.button_up.connect(func(): _on_button_released(endless_stack_button))
	endless_stack_button.mouse_entered.connect(_on_button_hover)
	endless_stack_button.mouse_exited.connect(_on_button_unhover)
	
	# Connect button visual state signals for Back button
	back_button.button_down.connect(func(): _on_button_pressed(back_button))
	back_button.button_up.connect(func(): _on_button_released(back_button))
	back_button.mouse_entered.connect(_on_back_button_hover)
	back_button.mouse_exited.connect(_on_back_button_unhover)
	
	# Start the pulsing animations for both mode buttons simultaneously
	start_height_pulse_animation()
	start_endless_pulse_animation()

# Pulsing animation functions
func start_height_pulse_animation():
	if height_pulse_tween:
		height_pulse_tween.kill()
	
	height_pulse_tween = create_tween()
	height_pulse_tween.set_loops() # Infinite loop
	
	# Scale up and down with a smooth ease
	height_pulse_tween.tween_property(height_challenge_button, "scale", Vector2(1.05, 1.05), 1.0)
	height_pulse_tween.tween_property(height_challenge_button, "scale", Vector2.ONE, 1.0)
	
	# Set easing for smoother animation
	height_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	height_pulse_tween.set_trans(Tween.TRANS_SINE)

func start_endless_pulse_animation():
	if endless_pulse_tween:
		endless_pulse_tween.kill()
	
	endless_pulse_tween = create_tween()
	endless_pulse_tween.set_loops() # Infinite loop
	
	# Start with scale down first (opposite of height challenge button)
	endless_stack_button.scale = Vector2(1.05, 1.05)
	endless_pulse_tween.tween_property(endless_stack_button, "scale", Vector2.ONE, 1.0)
	endless_pulse_tween.tween_property(endless_stack_button, "scale", Vector2(1.05, 1.05), 1.0)
	
	# Set easing for smoother animation
	endless_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	endless_pulse_tween.set_trans(Tween.TRANS_SINE)

# Button visual state functions
func _on_button_pressed(button: TextureButton):
	# Create a temporary press animation that doesn't interfere with pulsing
	var press_tween = create_tween()
	var original_modulate = button.modulate
	press_tween.tween_property(button, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.1)
	press_tween.tween_property(button, "modulate", original_modulate, 0.1)

func _on_button_released(button: TextureButton):
	# No need to do anything special on release since we're not stopping animations
	pass

# Hover functions
func _on_button_hover():
	play_hover_sound()

func _on_button_unhover():
	pass

func _on_back_button_hover():
	play_hover_sound()
	# Scale up on hover (back button doesn't have pulsing animation)
	var hover_tween = create_tween()
	hover_tween.tween_property(back_button, "scale", Vector2(1.1, 1.1), 0.1)
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_QUART)

func _on_back_button_unhover():
	# Scale back to normal
	var unhover_tween = create_tween()
	unhover_tween.tween_property(back_button, "scale", Vector2.ONE, 0.15)
	unhover_tween.set_ease(Tween.EASE_OUT)
	unhover_tween.set_trans(Tween.TRANS_QUART)

# Button action functions
func _on_height_challenge_button_pressed():
	button_sound.play()
	start_game_transition(HEIGHT_CHALLENGE_SCENE)

func _on_endless_stack_button_pressed():
	button_sound.play()
	start_game_transition(ENDLESS_STACK_SCENE)

func _on_back_button_pressed():
	button_sound.play()
	go_back_to_landing()

# Audio functions
func play_music() -> void:
	if not mute and landing_page_music:
		landing_page_music.play()

func play_button_sound():
	if not mute and landing_page_music:
		button_sound.play()

func play_hover_sound():
	# Add your audio logic here
	pass

# Scene transition functions
func start_game_transition(scene_path: String):
	# Disable all buttons during transition
	height_challenge_button.disabled = true
	endless_stack_button.disabled = true
	back_button.disabled = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file(scene_path))

func go_back_to_landing():
	# Disable all buttons during transition
	height_challenge_button.disabled = true
	endless_stack_button.disabled = true
	back_button.disabled = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file(LANDING_PAGE_SCENE))
