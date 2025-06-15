# GameOver.gd

extends Control

# UI References - Updated to match scene tree
@onready var game_over_label = $GameModeText/Label
@onready var stats_container = $ScoreSummary
@onready var stacks_gained_label = $ScoreSummary/StacksGained
@onready var stacks_gained_score = $ScoreSummary/StacksGainedScore
@onready var highest_stack_label = $ScoreSummary/HighestStack
@onready var highest_stack_score = $ScoreSummary/HighestStackScore
@onready var replay_button = $ReplayButtonContainer/ReplayButton
@onready var leave_button = $LeaveButtonContainer/LeaveButton
@onready var background = $Background
@onready var high_score_sound = $HighScoreSound
@onready var leaving_sound = $LeavingSound
@onready var button_sound = $ButtonSound
@onready var regular_game_over_sound = $RegularGameOverSound 
@onready var mute: bool = false

# Animation variables
var replay_pulse_tween: Tween
var leave_pulse_tween: Tween

# Scene paths
const ENDLESS_STACK_SCENE = "res://Main.tscn"
const HEIGHT_CHALLENGE_SCENE = "res://HeightChallenge.tscn"
const MODE_SELECTION_SCENE = "res://ModeSelection.tscn"  # Changed from LANDING_PAGE_SCENE

# Game data
var current_score: int = 0
var high_score: int = 0
var is_height_challenge: bool = false
var is_new_record: bool = false

# Volume state
var volume_enabled: bool = true

func _ready():
	# Validate that all required nodes exist
	if not validate_nodes():
		push_error("Game Over Scene: Missing required UI nodes!")
		return
	
	# Set this Control to fill the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# IMPORTANT: Ensure all GameOver UI elements are visible on startup
	ensure_game_over_visible()
	
	# Connect button signals
	replay_button.pressed.connect(_on_replay_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)
	
	# Connect button visual state signals for Replay button
	replay_button.button_down.connect(func(): _on_button_pressed(replay_button))
	replay_button.button_up.connect(func(): _on_button_released(replay_button))
	replay_button.mouse_entered.connect(_on_button_hover)
	replay_button.mouse_exited.connect(_on_button_unhover)
	
	# Connect button visual state signals for Leave button
	leave_button.button_down.connect(func(): _on_button_pressed(leave_button))
	leave_button.button_up.connect(func(): _on_button_released(leave_button))
	leave_button.mouse_entered.connect(_on_button_hover)
	leave_button.mouse_exited.connect(_on_button_unhover)
	
	# Get game data and setup display
	get_game_data()
	setup_display()
	
	# Start animations - both buttons now pulse
	start_replay_pulse_animation()
	start_leave_pulse_animation()
	animate_entrance()
	
	# Ensure the game is unpaused when this scene is ready
	get_tree().paused = false
	
	# Hide background UI elements
	hide_background_ui()

# NEW: Function to ensure GameOver UI elements are visible
func ensure_game_over_visible():
	# Make sure all GameOver UI elements are visible
	if game_over_label:
		game_over_label.visible = true
	if stats_container:
		stats_container.visible = true
	if replay_button:
		replay_button.visible = true
	if leave_button:
		leave_button.visible = true
	if background:
		background.visible = true
	
	# Make sure this control is visible
	visible = true
	modulate.a = 1.0

func play_high_score_sound():
	if not mute and high_score_sound:
		high_score_sound.play()
		
func play_leaving_sound():
	if not mute and leaving_sound:
		leaving_sound.play()
		
func play_button_sound():
	if not mute and button_sound:
		button_sound.play()
		
func play_regular_game_over_sound():
	if not mute and regular_game_over_sound:
		regular_game_over_sound.play()

func validate_nodes() -> bool:
	# Check if all critical nodes exist
	var required_nodes = [
		game_over_label,
		stats_container,
		stacks_gained_label,
		stacks_gained_score,
		highest_stack_label,
		highest_stack_score,
		replay_button,
		leave_button
	]
	
	for node in required_nodes:
		if node == null:
			return false
	
	return true

func get_game_data():
	# Try to get scoreboard reference
	var scoreboard = find_scoreboard()
	if scoreboard:
		# Check if scoreboard has the method to determine game mode
		if scoreboard.has_method("is_height_challenge_mode"):
			is_height_challenge = scoreboard.is_height_challenge_mode()
		else:
			# Fallback: check for height challenge properties
			is_height_challenge = scoreboard.has_method("get_best_height") or "height" in str(scoreboard).to_lower()
		
		# Get current score
		if scoreboard.has_method("get_current_score"):
			current_score = scoreboard.get_current_score()
		elif scoreboard.has_method("get_score"):
			current_score = scoreboard.get_score()
		else:
			current_score = 0
		
		# Get high score based on game mode
		if is_height_challenge:
			if scoreboard.has_method("get_best_height"):
				high_score = scoreboard.get_best_height()
			elif "best_height" in scoreboard:
				high_score = scoreboard.best_height
			else:
				high_score = 0
			is_new_record = (current_score == high_score and current_score > 0)
		else:
			if scoreboard.has_method("get_stacking_high_score"):
				high_score = scoreboard.get_stacking_high_score()
			elif "stacking_high_score" in scoreboard:
				high_score = scoreboard.stacking_high_score
			else:
				high_score = 0
			is_new_record = (current_score == high_score and current_score > 0)
	else:
		# Fallback - try to detect from scene or use defaults
		detect_game_mode_fallback()

func find_scoreboard():
	# Try multiple possible paths to find the scoreboard
	var possible_paths = [
		"/root/Main/UI/Scoreboard",
		"/root/Main/Scoreboard",
		"/root/HeightChallenge/UI/Scoreboard",
		"/root/HeightChallenge/Scoreboard",
		"/root/EndlessStack/UI/Scoreboard",
		"/root/EndlessStack/Scoreboard"
	]
	
	for path in possible_paths:
		if has_node(path):
			return get_node(path)
	
	return null

func detect_game_mode_fallback():
	# Try to detect based on current scene name
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_name = current_scene.scene_file_path.get_file().to_lower()
		is_height_challenge = "height" in scene_name or "challenge" in scene_name
	
	# Also check the scene file path for additional clues
	var scene_path = get_tree().current_scene.scene_file_path.to_lower()
	if "height" in scene_path or "challenge" in scene_path:
		is_height_challenge = true
	
	# Set default values
	current_score = 0
	high_score = 0
	is_new_record = false
	
	print("Game mode detection fallback - Height Challenge: ", is_height_challenge)

func setup_display():
	# Safety checks before setting text
	if not stacks_gained_score or not highest_stack_score:
		push_error("Game Over Scene: Score labels not found!")
		return
	
	# Update score numbers only - the labels stay the same
	stacks_gained_score.text = str(current_score)
	highest_stack_score.text = str(high_score)
	
	# Update the main labels based on game mode (optional - only if you want different text)
	if is_height_challenge:
		if stacks_gained_label:
			stacks_gained_label.text = "HEIGHT REACHED"
		if highest_stack_label:
			highest_stack_label.text = "BEST HEIGHT"
	else:
		if stacks_gained_label:
			stacks_gained_label.text = "CAPYsBALANCED!"
		if highest_stack_label:
			highest_stack_label.text = "HIGHEST STACK"
	
	# Highlight new record - SIMPLIFIED: Just change color, no animation
	if is_new_record and game_over_label and highest_stack_score:
		highest_stack_score.modulate = Color.GOLD
		# Add "NEW RECORD!" text
		game_over_label.text = "NEW RECORD!"
		game_over_label.modulate = Color.GOLD
		play_high_score_sound()
	else:
		play_regular_game_over_sound()  
# UPDATED: Enhanced pulsing animation functions (similar to LandingPage)
func start_replay_pulse_animation():
	if not replay_button:
		return
		
	if replay_pulse_tween:
		replay_pulse_tween.kill()
	
	replay_pulse_tween = create_tween()
	replay_pulse_tween.set_loops() # Infinite loop
	
	# Scale up and down with a smooth ease (matching LandingPage style)
	replay_pulse_tween.tween_property(replay_button, "scale", Vector2(1.05, 1.05), 0.8)
	replay_pulse_tween.tween_property(replay_button, "scale", Vector2.ONE, 0.8)
	
	# Set easing for smoother animation
	replay_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	replay_pulse_tween.set_trans(Tween.TRANS_SINE)

# NEW: Pulsing animation for leave button (similar to LandingPage)
func start_leave_pulse_animation():
	if not leave_button:
		return
		
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

# LIVELY: Slide-in entrance animation that avoids text duplication
func animate_entrance():
	# Check if nodes exist before animating
	if not game_over_label or not stats_container or not replay_button or not leave_button:
		push_error("Game Over Scene: Cannot animate, missing UI nodes!")
		return
	
	# Get original positions
	var original_game_over_pos = game_over_label.position
	var original_stats_pos = stats_container.position
	var original_replay_pos = replay_button.position
	var original_leave_pos = leave_button.position
	
	# Set starting positions (slide from different directions)
	game_over_label.position.y = original_game_over_pos.y - 200  # Slide from top
	stats_container.position.x = original_stats_pos.x - 300      # Slide from left  
	replay_button.position.x = original_replay_pos.x - 200      # Slide from left
	leave_button.position.x = original_leave_pos.x + 200        # Slide from right
	
	# Make everything visible but offset
	game_over_label.modulate.a = 1.0
	stats_container.modulate.a = 1.0
	replay_button.modulate.a = 1.0
	leave_button.modulate.a = 1.0
	
	var entrance_tween = create_tween()
	entrance_tween.set_parallel(true)
	
	# Slide everything into place with bouncy easing - FASTER timing
	entrance_tween.tween_property(game_over_label, "position", original_game_over_pos, 0.4)
	entrance_tween.tween_property(stats_container, "position", original_stats_pos, 0.3)
	entrance_tween.tween_property(replay_button, "position", original_replay_pos, 0.35)
	entrance_tween.tween_property(leave_button, "position", original_leave_pos, 0.35)
	
	# Set bouncy easing for a lively effect
	entrance_tween.set_ease(Tween.EASE_OUT)
	entrance_tween.set_trans(Tween.TRANS_BACK)
	
	# Add a subtle scale bounce at the end for extra liveliness
	entrance_tween.finished.connect(add_bounce_finish)

# NEW: Add a subtle bounce finish for extra liveliness
func add_bounce_finish():
	if not stats_container:
		return
	
	# Quick subtle bounce for the stats container only (avoids text duplication)
	var bounce_tween = create_tween()
	bounce_tween.tween_property(stats_container, "scale", Vector2(1.05, 1.05), 0.1)
	bounce_tween.tween_property(stats_container, "scale", Vector2.ONE, 0.15)
	bounce_tween.set_ease(Tween.EASE_OUT)
	bounce_tween.set_trans(Tween.TRANS_ELASTIC)

# REMOVED: animate_new_record() function - no special score animations

# UPDATED: Enhanced button interaction functions (matching LandingPage style)
func _on_button_pressed(button: TextureButton):
	var press_tween = create_tween()
	var original_modulate = button.modulate
	# Make button brighter when pressed (like the LandingPage hover effect)
	press_tween.tween_property(button, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.1)
	press_tween.tween_property(button, "modulate", original_modulate, 0.1)

func _on_button_released(button: TextureButton):
	# No special release animation needed (matching LandingPage)
	pass

# UPDATED: Enhanced hover functions (matching LandingPage)
func _on_button_hover():
	play_hover_sound()

func _on_button_unhover():
	pass

# Button action functions
func _on_replay_button_pressed():  
	play_button_sound()
	replay_game()

# UPDATED: Navigate directly to ModeSelection instead of showing leave scene
func _on_leave_button_pressed():
	play_leaving_sound()
	if volume_enabled:
		play_button_sound()
	go_to_mode_selection()  # Changed from show_leave_scene()

# NEW: Navigate to ModeSelection scene
func go_to_mode_selection():
	# Disable buttons during transition
	if replay_button:
		replay_button.disabled = true
	if leave_button:
		leave_button.disabled = true
	
	# Stop pulse animations
	if replay_pulse_tween:
		replay_pulse_tween.kill()
	if leave_pulse_tween:
		leave_pulse_tween.kill()
	
	# Unpause the game
	get_tree().paused = false
	
	# Clean up the UI canvas if it exists
	cleanup_ui_canvas()
	
	# Try multiple possible paths for ModeSelection
	var mode_selection_paths = [
		"res://ModeSelection.tscn",
		"res://scenes/ModeSelection.tscn",
		"res://ui/ModeSelection.tscn",
		"res://LandingPage.tscn"  # Fallback to landing page if ModeSelection doesn't exist
	]
	
	var scene_to_load = ""
	for path in mode_selection_paths:
		if ResourceLoader.exists(path):
			scene_to_load = path
			break
	
	if scene_to_load == "":
		# If no scene found, quit the game as fallback
		print("No valid scene found, quitting game")
		get_tree().quit()
		return
	
	print("Loading scene: ", scene_to_load)
	
	# Immediate scene change without fade for reliability
	var result = get_tree().change_scene_to_file(scene_to_load)
	if result != OK:
		print("Failed to load scene, trying alternative method")
		# Alternative method using call_deferred
		get_tree().call_deferred("change_scene_to_file", scene_to_load)

# Scene transition functions
func replay_game():
	# Disable buttons during transition
	if replay_button:
		replay_button.disabled = true
	if leave_button:
		leave_button.disabled = true
	
	# Unpause the game
	get_tree().paused = false
	
	# Clean up the UI canvas if it exists
	cleanup_ui_canvas()
	
	# Simply reload the current scene (same as pressing R key in main game)
	get_tree().reload_current_scene()

# Add cleanup function for the UI canvas
func cleanup_ui_canvas():
	# Clean up any UI canvas references
	var ui_canvas = get_meta("ui_canvas", null)
	if ui_canvas and is_instance_valid(ui_canvas):
		ui_canvas.queue_free()
	
	# Also try to clean up any remaining UI elements from the game scene
	var main_scene = get_tree().current_scene
	if main_scene:
		# Find and clean up UI containers
		var ui_containers = main_scene.find_children("UI", "", false)
		for ui in ui_containers:
			if ui and is_instance_valid(ui):
				ui.visible = true  # Make sure UI is visible for next game
		
		# Find and clean up scoreboards
		var scoreboards = main_scene.find_children("Scoreboard", "", false)  
		for scoreboard in scoreboards:
			if scoreboard and is_instance_valid(scoreboard):
				scoreboard.visible = true  # Make sure scoreboard is visible for next game

func setup_as_overlay():
	# If you want the game over screen to appear as an overlay instead of replacing the scene
	# Call this method after instantiating the game over scene
	
	# Make sure it's on top of everything
	z_index = 100
	
	# Set to fill screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Add semi-transparent background if needed
	if background:
		background.modulate = Color(0, 0, 0, 0.8)  # Semi-transparent black overlay

# Audio functions
func play_hover_sound():
	# Add your audio logic here
	pass

# Public methods for external setup (if needed)
func setup_game_over_data(score: int, best_score: int, height_challenge_mode: bool = false, new_record: bool = false):
	current_score = score
	high_score = best_score
	is_height_challenge = height_challenge_mode
	is_new_record = new_record
	setup_display()
	print("Game Over data set - Height Challenge: ", is_height_challenge, " Score: ", current_score)

# Alternative method to set just the game mode
func set_game_mode(height_challenge_mode: bool):
	is_height_challenge = height_challenge_mode
	print("Game mode set to Height Challenge: ", is_height_challenge)

# Hide background UI elements
func hide_background_ui():
	# Find and hide the main UI elements from the game scene
	var ui_paths = [
		"/root/Main/UI/Scoreboard",
		"/root/Main/Scoreboard", 
		"/root/HeightChallenge/UI/Scoreboard",
		"/root/HeightChallenge/Scoreboard",
		"/root/Main/UI", # Hide entire UI container
		"/root/HeightChallenge/UI"
	]
	
	for path in ui_paths:
		if has_node(path):
			var ui_node = get_node(path)
			if ui_node:
				ui_node.visible = false
				print("Hidden UI node: ", path)
