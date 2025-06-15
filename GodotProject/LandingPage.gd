# LandingPage.gd

extends Control
# Button references
@onready var start_button = $StartButtonContainer/StartButton
@onready var leave_button = $LeaveButtonContainer/LeaveButton
@onready var logo = $Logo
@onready var background = $Background
@onready var landing_page_music = $LandingPageMusic
@onready var button_sound = $ButtonSound
@onready var mute: bool = false

# Animation variables
var start_pulse_tween: Tween
var leave_pulse_tween: Tween
var logo_tilt_tween: Tween

# Leave scene overlay reference
var leave_scene_instance: Control = null

# Scene paths
const GAME_SCENE = "res://ModeSelection.tscn"
const LEAVE_SCENE = "res://LeaveScene.tscn"

# Preloading heavy game scenes in the background
const HEIGHT_CHALLENGE_SCENE = "res://HeightChallenge.tscn"
const ENDLESS_STACK_SCENE = "res://Main.tscn"

# Preloaded scenes - will be shared with ModeSelection via AutoLoad
var height_challenge_packed: PackedScene = null
var endless_stack_packed: PackedScene = null
var preloading_complete = false

func _ready():
	# Set this Control to fill the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Play background music
	play_music()
	
	# Start preloading heavy scenes immediately in background
	start_background_preloading()
	
	# Connect button press signals
	start_button.pressed.connect(_on_start_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)
	# Connect button visual state signals for Start button
	start_button.button_down.connect(func(): _on_button_pressed(start_button))
	start_button.button_up.connect(func(): _on_button_released(start_button))
	start_button.mouse_entered.connect(_on_button_hover)
	start_button.mouse_exited.connect(_on_button_unhover)
	# Connect button visual state signals for Leave button
	leave_button.button_down.connect(func(): _on_button_pressed(leave_button))
	leave_button.button_up.connect(func(): _on_button_released(leave_button))
	leave_button.mouse_entered.connect(_on_button_hover)
	leave_button.mouse_exited.connect(_on_button_unhover)
	# Start the pulsing animations for both buttons
	start_pulse_animation()
	leave_pulse_animation()
	logo_tilt_animation()

# Background preloading system
func start_background_preloading():
	print("Starting background preloading of game scenes...")
	_load_scene_async(HEIGHT_CHALLENGE_SCENE, _on_height_challenge_loaded)
	_load_scene_async(ENDLESS_STACK_SCENE, _on_endless_stack_loaded)

func _load_scene_async(scene_path: String, callback: Callable):
	# Use ResourceLoader to load asynchronously
	ResourceLoader.load_threaded_request(scene_path)
	# Check loading status periodically
	_check_loading_status(scene_path, callback)

func _check_loading_status(scene_path: String, callback: Callable):
	var status = ResourceLoader.load_threaded_get_status(scene_path)
	
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource = ResourceLoader.load_threaded_get(scene_path)
			callback.call(resource)
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# Still loading, check again next frame
			call_deferred("_check_loading_status", scene_path, callback)
		ResourceLoader.THREAD_LOAD_FAILED:
			print("Failed to preload scene: ", scene_path)
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("Invalid resource: ", scene_path)

func _on_height_challenge_loaded(resource: PackedScene):
	height_challenge_packed = resource
	print("Height Challenge scene preloaded in background")
	# Store in singleton/autoload for ModeSelection to access
	if has_method("store_preloaded_scene"):
		store_preloaded_scene("height_challenge", resource)
	_check_preloading_complete()

func _on_endless_stack_loaded(resource: PackedScene):
	endless_stack_packed = resource
	print("Endless Stack scene preloaded in background")
	# Store in singleton/autoload for ModeSelection to access
	if has_method("store_preloaded_scene"):
		store_preloaded_scene("endless_stack", resource)
	_check_preloading_complete()

func _check_preloading_complete():
	if height_challenge_packed != null and endless_stack_packed != null:
		preloading_complete = true
		print("All game scenes preloaded successfully!")
		
		# Optional: Show a subtle indicator that preloading is complete
		_show_preload_complete_indicator()

func _show_preload_complete_indicator():
	# Subtle visual feedback that preloading is done
	# You could add a small dot that changes color, or make the start button glow slightly
	var indicator_tween = create_tween()
	indicator_tween.tween_property(start_button, "modulate", Color(1.1, 1.1, 1.1, 1.0), 0.3)
	indicator_tween.tween_property(start_button, "modulate", Color.WHITE, 0.3)

# Optional: Store preloaded scenes in an AutoLoad/Singleton
func store_preloaded_scene(scene_name: String, scene: PackedScene):
	# If you have a GameManager singleton, store it there:
	# GameManager.preloaded_scenes[scene_name] = scene
	pass

# Pulsing animation functions
func start_pulse_animation():
	if start_pulse_tween:
		start_pulse_tween.kill()
	start_pulse_tween = create_tween()
	start_pulse_tween.set_loops() # Infinite loop
	# Scale up and down with a smooth ease
	start_pulse_tween.tween_property(start_button, "scale", Vector2(1.05, 1.05), 0.8)
	start_pulse_tween.tween_property(start_button, "scale", Vector2.ONE, 0.8)
	# Set easing for smoother animation
	start_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	start_pulse_tween.set_trans(Tween.TRANS_SINE)

func leave_pulse_animation():
	if leave_pulse_tween:
		leave_pulse_tween.kill()
	leave_pulse_tween = create_tween()
	leave_pulse_tween.set_loops() # Infinite loop
	# Scale up and down with a smooth ease - slightly different timing for variety
	leave_pulse_tween.tween_property(leave_button, "scale", Vector2(1.04, 1.04), 1.0)
	leave_pulse_tween.tween_property(leave_button, "scale", Vector2.ONE, 0.8)
	# Set easing for smoother animation
	leave_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	leave_pulse_tween.set_trans(Tween.TRANS_SINE)
	
func logo_tilt_animation():
	if logo_tilt_tween:
		logo_tilt_tween.kill()
	
	logo_tilt_tween = create_tween()
	logo_tilt_tween.set_loops() # Infinite loop
	
	# Tilt side to side
	logo_tilt_tween.tween_property(logo, "rotation", deg_to_rad(1), 0.6)
	logo_tilt_tween.tween_property(logo, "rotation", deg_to_rad(-1), 1.2)
	logo_tilt_tween.tween_property(logo, "rotation", 0.0, 0.6)
	
	# Set easing for smoother animation
	logo_tilt_tween.set_ease(Tween.EASE_IN_OUT)
	logo_tilt_tween.set_trans(Tween.TRANS_SINE)

# Button visual state functions
func _on_button_pressed(button: TextureButton):
	var press_tween = create_tween()
	var original_modulate = button.modulate
	# Make button brighter when pressed (like the hover effect)
	press_tween.tween_property(button, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.1)
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

func _on_leave_button_pressed():
	play_button_sound()
	show_leave_scene()

# Audio functions
func play_music() -> void:
	if not mute and landing_page_music:
		landing_page_music.play()

func play_button_sound():
	if not mute and button_sound:
		button_sound.play()

func play_hover_sound():
	pass # Add hover sound here

# Scene transition
func start_game_transition():
	start_button.disabled = true
	leave_button.disabled = true
	
	# Show loading state briefly if scenes aren't preloaded yet
	if not preloading_complete:
		_show_loading_feedback()
		
		# Wait a moment for preloading to complete
		var wait_time = 0.0
		while not preloading_complete and wait_time < 1.0:
			await get_tree().create_timer(0.1).timeout
			wait_time += 0.1
	
	get_tree().change_scene_to_file(GAME_SCENE)

func _show_loading_feedback():
	# Optional: Show "Loading..." text briefly
	# You could modify the logo text or show a loading indicator
	pass

# Leave scene overlay functions
func show_leave_scene():
	# Prevent showing multiple leave scenes
	if leave_scene_instance != null:
		return
	
	# Disable main buttons to prevent interaction while overlay is shown
	start_button.disabled = true
	leave_button.disabled = true
	
	# Dim the background landing page
	dim_landing_page()
	
	# Load and instantiate the leave scene
	var leave_scene_resource = load(LEAVE_SCENE)
	if leave_scene_resource == null:
		push_error("Failed to load LeaveScene.tscn")
		restore_landing_page()  # Restore landing page if loading failed
		return
	
	leave_scene_instance = leave_scene_resource.instantiate()
	if leave_scene_instance == null:
		push_error("Failed to instantiate LeaveScene")
		restore_landing_page()  # Restore landing page if instantiation failed
		return
	
	# Add it as a child to this scene
	add_child(leave_scene_instance)
	
	# Set it up as a full screen overlay
	setup_leave_scene_overlay()
	
	# Hide the "oh no" text when used as overlay
	hide_oh_no_text()
	
	# Connect to leave scene signals
	connect_leave_scene_signals()

func dim_landing_page():
	# Stop pulse animations while overlay is active
	if start_pulse_tween:
		start_pulse_tween.kill()
	if leave_pulse_tween:
		leave_pulse_tween.kill()
	if logo_tilt_tween:
		logo_tilt_tween.kill()
	
	# Create dimming animation
	var dim_tween = create_tween()
	dim_tween.set_parallel(true)
	
	# Dim all elements but keep them visible
	dim_tween.tween_property(start_button, "modulate", Color(0.5, 0.5, 0.5, 0.6), 0.3)
	dim_tween.tween_property(leave_button, "modulate", Color(0.5, 0.5, 0.5, 0.6), 0.3)
	dim_tween.tween_property(logo, "modulate", Color(0.5, 0.5, 0.5, 0.6), 0.3)
	dim_tween.tween_property(background, "modulate", Color(0.7, 0.7, 0.7, 0.8), 0.3)

func restore_landing_page():
	# Re-enable buttons
	start_button.disabled = false
	leave_button.disabled = false
	
	# Create restore animation
	var restore_tween = create_tween()
	restore_tween.set_parallel(true)
	
	# Restore all elements to full brightness
	restore_tween.tween_property(start_button, "modulate", Color.WHITE, 0.3)
	restore_tween.tween_property(leave_button, "modulate", Color.WHITE, 0.3)
	restore_tween.tween_property(logo, "modulate", Color.WHITE, 0.3)
	restore_tween.tween_property(background, "modulate", Color.WHITE, 0.3)
	
	# Restart the pulse animations after restore completes
	restore_tween.finished.connect(restart_pulse_animations)

func restart_pulse_animations():
	start_pulse_animation()
	leave_pulse_animation()
	logo_tilt_animation()  

func setup_leave_scene_overlay():
	if leave_scene_instance == null:
		return
	
	# Make sure it's on top
	leave_scene_instance.z_index = 1000
	
	# Set to fill screen if it's a Control node
	if leave_scene_instance is Control:
		leave_scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add entrance animation
	animate_leave_scene_entrance()

func animate_leave_scene_entrance():
	if leave_scene_instance == null:
		return
	
	# Start with the leave scene invisible and slightly scaled down
	leave_scene_instance.modulate.a = 0.0
	leave_scene_instance.scale = Vector2(0.9, 0.9)
	
	# Fade it in and scale up
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(leave_scene_instance, "modulate:a", 1.0, 0.3)
	fade_tween.tween_property(leave_scene_instance, "scale", Vector2.ONE, 0.3)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_BACK)

func connect_leave_scene_signals():
	if leave_scene_instance == null:
		return
	
	# Connect to common signals that your LeaveScene might emit
	if leave_scene_instance.has_signal("leave_confirmed"):
		leave_scene_instance.leave_confirmed.connect(_on_leave_confirmed)
	
	if leave_scene_instance.has_signal("leave_cancelled"):
		leave_scene_instance.leave_cancelled.connect(_on_leave_cancelled)
	
	# Connect to your specific button names from the scene tree
	var no_button = leave_scene_instance.find_child("NoButton", true, false)
	var yes_button = leave_scene_instance.find_child("YesButton", true, false)
	
	if no_button and no_button.has_signal("pressed"):
		no_button.pressed.connect(_on_leave_cancelled)  # NO = Cancel/Stay
		print("Connected to NoButton")
	
	if yes_button and yes_button.has_signal("pressed"):
		yes_button.pressed.connect(_on_leave_confirmed)  # YES = Confirm/Quit
		print("Connected to YesButton")

func _on_leave_confirmed():
	# User confirmed they want to leave
	play_button_sound()
	print("Leave confirmed")
	hide_leave_scene()
	_quit_game()

func _on_leave_cancelled():
	# User cancelled, hide overlay and restore landing page
	play_button_sound()
	print("Leave cancelled")
	hide_leave_scene()
	# Wait a moment before restoring landing page
	await get_tree().create_timer(0.1).timeout
	restore_landing_page()

func hide_leave_scene():
	if leave_scene_instance == null:
		return
	
	# Optional: Add exit animation before removing
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(leave_scene_instance, "modulate:a", 0.0, 0.2)
	fade_tween.tween_property(leave_scene_instance, "scale", Vector2(0.9, 0.9), 0.2)
	fade_tween.tween_callback(remove_leave_scene).set_delay(0.2)

func remove_leave_scene():
	if leave_scene_instance != null:
		leave_scene_instance.queue_free()
		leave_scene_instance = null

func hide_oh_no_text():
	if leave_scene_instance == null:
		return
	
	# Find and hide the OhNoText Control node (which contains the OhNo Label)
	var oh_no_text_control = leave_scene_instance.find_child("OhNoText", true, false)
	if oh_no_text_control:
		oh_no_text_control.visible = false
		print("Hidden OhNoText control and its children")
		return
	
	# Alternative: Hide just the OhNo Label if the Control is needed for layout
	var oh_no_label = leave_scene_instance.find_child("OhNo", true, false)
	if oh_no_label:
		oh_no_label.visible = false
		print("Hidden OhNo label")

func _quit_game():
	get_tree().quit()
