# LeaveScene.gd
extends Control

# Button references - Updated to TextureButton
@onready var no_button: TextureButton = $NoButtonContainer/NoButton
@onready var yes_button: TextureButton = $YesButtonContainer/YesButton

# Optional audio nodes (add these to your scene if you want sounds)
@onready var button_hover_sound = $ButtonHoverSound if has_node("ButtonHoverSound") else null
@onready var button_click_sound = $ButtonClickSound if has_node("ButtonClickSound") else null

# Animation tweens
var no_button_tween: Tween
var yes_button_tween: Tween

# Signals that can be emitted (optional - for cleaner communication)
signal leave_confirmed
signal leave_cancelled

func _ready():
	# Validate buttons exist
	if not no_button or not yes_button:
		push_error("LeaveScene: Missing required buttons!")
		return
	
	# Set initial properties
	setup_initial_state()
	
	# Connect button signals
	connect_button_signals()
	
	# Start entrance animation
	animate_entrance()

func setup_initial_state():
	# Set initial button states for animation
	no_button.modulate.a = 0.0
	yes_button.modulate.a = 0.0
	no_button.scale = Vector2(0.8, 0.8)
	yes_button.scale = Vector2(0.8, 0.8)

func connect_button_signals():
	# Connect press signals
	no_button.pressed.connect(_on_no_button_pressed)
	yes_button.pressed.connect(_on_yes_button_pressed)
	
	# Connect hover signals for No button
	no_button.mouse_entered.connect(func(): _on_button_hover(no_button))
	no_button.mouse_exited.connect(func(): _on_button_unhover(no_button))
	no_button.button_down.connect(func(): _on_button_pressed(no_button))
	no_button.button_up.connect(func(): _on_button_released(no_button))
	
	# Connect hover signals for Yes button
	yes_button.mouse_entered.connect(func(): _on_button_hover(yes_button))
	yes_button.mouse_exited.connect(func(): _on_button_unhover(yes_button))
	yes_button.button_down.connect(func(): _on_button_pressed(yes_button))
	yes_button.button_up.connect(func(): _on_button_released(yes_button))

func animate_entrance():
	# Create the main entrance tween for both buttons simultaneously
	var entrance_tween = create_tween()
	entrance_tween.set_parallel(true)
	
	# Animate both buttons at the same time
	entrance_tween.tween_property(no_button, "modulate:a", 1.0, 0.3)
	entrance_tween.tween_property(no_button, "scale", Vector2.ONE, 0.3)
	entrance_tween.tween_property(yes_button, "modulate:a", 1.0, 0.3)
	entrance_tween.tween_property(yes_button, "scale", Vector2.ONE, 0.3)
	
	# Set easing for the entrance
	entrance_tween.set_ease(Tween.EASE_OUT)
	entrance_tween.set_trans(Tween.TRANS_BACK)

# Button hover effects - Using TextureButton to match your scene
func _on_button_hover(button: TextureButton):
	play_hover_sound()
	
	# Stop any existing tween for this button
	var tween_to_kill = no_button_tween if button == no_button else yes_button_tween
	if tween_to_kill:
		tween_to_kill.kill()
	
	# Create new hover tween
	var hover_tween = create_tween()
	hover_tween.set_parallel(true)
	
	# Scale up and brighten (removed rotation)
	hover_tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	hover_tween.tween_property(button, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1)
	
	# Set easing
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_QUART)
	
	# Store the tween reference
	if button == no_button:
		no_button_tween = hover_tween
	else:
		yes_button_tween = hover_tween

func _on_button_unhover(button: TextureButton):
	# Stop any existing tween for this button
	var tween_to_kill = no_button_tween if button == no_button else yes_button_tween
	if tween_to_kill:
		tween_to_kill.kill()
	
	# Create new unhover tween
	var unhover_tween = create_tween()
	unhover_tween.set_parallel(true)
	
	# Scale back to normal and reset brightness (removed rotation reset)
	unhover_tween.tween_property(button, "scale", Vector2.ONE, 0.15)
	unhover_tween.tween_property(button, "modulate", Color.WHITE, 0.15)
	
	# Set easing
	unhover_tween.set_ease(Tween.EASE_OUT)
	unhover_tween.set_trans(Tween.TRANS_QUART)
	
	# Store the tween reference
	if button == no_button:
		no_button_tween = unhover_tween
	else:
		yes_button_tween = unhover_tween

func _on_button_pressed(button: TextureButton):
	# Quick press animation - scale down slightly
	var press_tween = create_tween()
	press_tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)
	press_tween.set_ease(Tween.EASE_OUT)

func _on_button_released(button: TextureButton):
	# Quick release animation - scale back up
	var release_tween = create_tween()
	release_tween.tween_property(button, "scale", Vector2(1.15, 1.15), 0.05)
	release_tween.set_ease(Tween.EASE_OUT)

# Button action functions
func _on_no_button_pressed():
	print("No button pressed - staying in game")
	play_click_sound()
	
	# Add a quick feedback animation before closing
	animate_button_choice(no_button, Color.GREEN)
	
	# Emit signal (optional)
	leave_cancelled.emit()
	
	# Close this scene with animation (just hide the dialog)
	animate_exit_cancelled()

func _on_yes_button_pressed():
	print("Yes button pressed - quitting game")
	play_click_sound()
	
	# Add a quick feedback animation before quitting
	animate_button_choice(yes_button, Color.RED)
	
	# Emit signal (optional)
	leave_confirmed.emit()
	
	# Actually quit the game
	get_tree().quit()

func animate_button_choice(chosen_button: TextureButton, feedback_color: Color):
	# Brief color flash to show which button was pressed
	var feedback_tween = create_tween()
	feedback_tween.set_parallel(true)
	
	# Flash the chosen button
	feedback_tween.tween_property(chosen_button, "modulate", feedback_color, 0.1)
	feedback_tween.tween_property(chosen_button, "modulate", Color.WHITE, 0.2)
	
	# Slightly scale up for emphasis
	feedback_tween.tween_property(chosen_button, "scale", Vector2(1.2, 1.2), 0.1)
	feedback_tween.tween_property(chosen_button, "scale", Vector2.ONE, 0.2)

func animate_exit_cancelled():
	# Slide out animation when cancelling
	var exit_tween = create_tween()
	exit_tween.set_parallel(true)
	
	# Fade out and slide down
	exit_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	exit_tween.tween_property(self, "position:y", position.y + 100, 0.3)
	
	# Set easing
	exit_tween.set_ease(Tween.EASE_IN)
	exit_tween.set_trans(Tween.TRANS_QUART)
	
	# Wait for animation to complete, then remove
	exit_tween.tween_callback(queue_free).set_delay(0.3)

func animate_exit_confirmed():
	# Different animation when confirming quit
	var exit_tween = create_tween()
	exit_tween.set_parallel(true)
	
	# Fade out and scale down
	exit_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	exit_tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.4)
	
	# Set easing
	exit_tween.set_ease(Tween.EASE_IN)
	exit_tween.set_trans(Tween.TRANS_QUART)
	
	# Wait for animation to complete, then remove
	exit_tween.tween_callback(queue_free).set_delay(0.4)

# Audio functions
func play_hover_sound():
	if button_hover_sound and button_hover_sound.has_method("play"):
		button_hover_sound.play()

func play_click_sound():
	if button_click_sound and button_click_sound.has_method("play"):
		button_click_sound.play()

# Alternative function for external control (if needed)
func show_with_animation():
	animate_entrance()

func hide_with_animation():
	animate_exit_cancelled()

# Handle ESC key or back button on mobile
func _input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("back"):
		# Treat ESC/back as "No" button
		_on_no_button_pressed()
		get_viewport().set_input_as_handled()

# Optional: Add subtle background dim effect
func _on_background_pressed():
	# If you have a background button/panel, treat clicking it as cancelling
	_on_no_button_pressed()
