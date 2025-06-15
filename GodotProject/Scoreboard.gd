# Scoreboard.gd UI script
extends Control

@onready var score_label: Label = $Stacks
@onready var high_score_label: Label = $HighScore
@onready var timer_label: Label = $Timer
@onready var volume_button: TextureButton = $VolumeButtonContainer/VolumeButton
@onready var pause_button: TextureButton = $PauseButtonContainer/PauseButton

# Volume state
var volume_enabled: bool = true

# Game state
var game_over_state: bool = false

# Game mode detection
enum GameMode { STACKING, HEIGHT_CHALLENGE }

var current_game_mode: GameMode = GameMode.STACKING

# Position storage for HighScore label
var high_score_original_position: Vector2
var high_score_stacking_offset: Vector2 = Vector2(0, -100)  # Move 50 pixels up for stacking mode

# Stacking mode variables
var current_score: int = 0
var stacking_high_score: int = 0

# Height challenge mode variables
var countdown_duration: float = 60.0
var time_remaining: float = 60.0
var challenge_active: bool = false
var current_height: int = 0
var best_height: int = 0

# Pause button hover and click effects
var pause_button_original_scale: Vector2
var pause_button_hover_tween: Tween
var pause_button_click_tween: Tween

func _ready():
	# Store the original position of the high score label
	if high_score_label:
		high_score_original_position = high_score_label.position
	
	detect_game_mode()
	load_high_scores()
	load_volume_setting()  # Load volume setting
	setup_volume_button()  # Setup volume button
	setup_pause_button()
	update_display()
	connect_to_game_signals()

# Game state management
func set_game_over(is_game_over: bool):
	game_over_state = is_game_over
	update_ui_button_states()

func update_ui_button_states():
	# Disable/enable buttons based on game state
	if volume_button:
		volume_button.disabled = game_over_state
		# Visual feedback for disabled state
		if game_over_state:
			volume_button.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Grayed out
		else:
			volume_button.modulate = Color.WHITE
	
	if pause_button:
		pause_button.disabled = game_over_state
		# Visual feedback for disabled state
		if game_over_state:
			pause_button.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Grayed out
		else:
			pause_button.modulate = Color.WHITE

# Position adjustment for HighScore label based on game mode
func adjust_high_score_position():
	if not high_score_label:
		return
	
	if current_game_mode == GameMode.STACKING:
		# Set static position higher for stacking mode
		high_score_label.position = high_score_original_position + high_score_stacking_offset
	else:
		# Use original position for height challenge mode
		high_score_label.position = high_score_original_position

# Volume functions
func setup_volume_button():
	if volume_button:
		volume_button.toggle_mode = true
		volume_button.button_pressed = !volume_enabled  # Inverted because pressed = muted
		volume_button.pressed.connect(_on_volume_button_pressed)

func _on_volume_button_pressed():
	# Don't process if game is over or button is disabled
	if game_over_state or volume_button.disabled:
		return
	toggle_volume()

func toggle_volume():
	volume_enabled = !volume_button.button_pressed  # Inverted because pressed = muted
	save_volume_setting()
	apply_volume_setting()
	
	if volume_enabled:
		play_ui_sound()

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

# Audio function for UI sounds (you can expand this)
func play_ui_sound():
	# Add your UI sound logic here
	pass

# Rest of your existing code remains the same...
func detect_game_mode():
	var current_scene = get_tree().current_scene
	if current_scene:
		var script = current_scene.get_script()
		if script:
			var script_path = script.get_path()
			print("Current scene script: ", script_path)
			if script_path.get_file() == "HeightChallenge.gd":
				current_game_mode = GameMode.HEIGHT_CHALLENGE
				print("Detected HEIGHT_CHALLENGE mode via scene script")
				adjust_high_score_position()  # Adjust position after mode detection
				return
			
	current_game_mode = GameMode.STACKING
	print("Detected STACKING mode (default)")
	adjust_high_score_position()  # Adjust position after mode detection

func load_height_challenge_best():
	var save_file = FileAccess.open("user://height_challenge_save.save", FileAccess.READ)
	if save_file:
		best_height = save_file.get_32()
		save_file.close()
	else:
		best_height = 0
		
func set_height_challenge_mode(is_height_challenge: bool, duration: float = 60.0):
	if is_height_challenge:
		current_game_mode = GameMode.HEIGHT_CHALLENGE
		countdown_duration = duration
		time_remaining = duration
		challenge_active = true
		print("Scoreboard set to HEIGHT_CHALLENGE mode")
	else:
		current_game_mode = GameMode.STACKING
		challenge_active = false
		print("Scoreboard set to STACKING mode")
	
	adjust_high_score_position()  # Adjust position when mode changes
	update_display()

func _process(delta):
	# Always monitor stack changes for height challenge
	if current_game_mode == GameMode.HEIGHT_CHALLENGE:
		update_current_height()
		
		# Also handle countdown if the main scene isn't handling it
		var main_node = get_node("/root/Main")
		if main_node and main_node.has_method("get"):
			if main_node.get("challenge_active") == true:
				var time_remaining = main_node.get("time_remaining")
				if time_remaining != null:
					update_countdown_timer(time_remaining)
					# Check if time ran out and disable buttons
					if time_remaining <= 0 and challenge_active:
						set_game_over(true)

func update_current_height():
	var main_node = get_node("/root/Main")
	if main_node and main_node.has_method("get") and main_node.get("capys_stack"):
		var new_height = main_node.capys_stack.size()
		if new_height != current_height:
			current_height = new_height
			
			# Update best height if this is a new record
			if current_height > best_height:
				best_height = current_height
				save_height_challenge_score()
			
			update_display()
			animate_score_increase()

func save_height_challenge_score():
	# Save to the height challenge specific file
	var save_file = FileAccess.open("user://height_challenge_save.save", FileAccess.WRITE)
	if save_file:
		save_file.store_32(best_height)
		save_file.close()
		
func save_high_scores():
	if current_game_mode == GameMode.HEIGHT_CHALLENGE:
		save_height_challenge_score()
	else:
		# Original stacking mode save
		var save_data = {
			"stacking_high_score": stacking_high_score,
			"best_height": best_height
		}
		var save_file = FileAccess.open("user://capybara_savegame.save", FileAccess.WRITE)
		if save_file:
			save_file.store_string(JSON.stringify(save_data))
			save_file.close()
			
func update_height_challenge_stats(height: int, best: int, time: float, active: bool):
	current_height = height
	best_height = best
	time_remaining = time
	challenge_active = active
	update_display()

func start_countdown():
	challenge_active = true

func update_countdown_timer(remaining_time: float):
	time_remaining = remaining_time
	update_display()

func end_height_challenge(final_height: int, best: int):
	challenge_active = false
	current_height = final_height
	best_height = best
	set_game_over(true)  # Disable UI buttons when height challenge ends
	save_high_scores()
	update_display()
	animate_challenge_complete()

func set_best_height(height: int):
	best_height = height
	update_display()

# Stacking mode methods
func _on_stack_added():
	if current_game_mode == GameMode.STACKING:
		add_score(1)

func add_score(points: int):
	if current_game_mode != GameMode.STACKING:
		return
		
	current_score += points
	
	if current_score > stacking_high_score:
		stacking_high_score = current_score
		save_high_scores()
	
	update_display()
	animate_score_increase()

func game_over():
	if current_game_mode == GameMode.STACKING:
		# Standard game over for stacking mode
		set_game_over(true)  # Disable UI buttons
		update_display()

# Method to reset game state (call this when starting a new game)
func reset_game_state():
	set_game_over(false)  # Re-enable UI buttons
	reset_score()

# Method to start a new height challenge
func start_new_height_challenge():
	set_game_over(false)  # Re-enable UI buttons
	challenge_active = true
	current_height = 0
	time_remaining = countdown_duration
	update_display()

# Display updates
func update_display():
	if current_game_mode == GameMode.STACKING:
		update_stacking_display()
	else:
		update_height_challenge_display()

func update_stacking_display():
	score_label.text = "\n" + str(current_score)
	high_score_label.text = "Highest\nStack\n" + str(stacking_high_score)
	
	if timer_label:
		timer_label.visible = false

func update_height_challenge_display():
	score_label.text = "\n" + str(current_height)
	high_score_label.text = "Best\nHeight\n" + str(best_height)
	
	if timer_label:
		timer_label.visible = true
		if challenge_active:
			timer_label.text = "Time\n" + format_countdown_time(time_remaining)
			# Color coding based on remaining time
			if time_remaining > 30:
				timer_label.modulate = Color.WHITE
			elif time_remaining > 10:
				timer_label.modulate = Color.YELLOW
			else:
				timer_label.modulate = Color.RED
		else:
			timer_label.text = "Time\n" + format_countdown_time(0)
			timer_label.modulate = Color.RED

func format_countdown_time(time_seconds: float) -> String:
	var minutes = int(time_seconds) / 60
	var seconds = int(time_seconds) % 60
	var decimal = int((time_seconds - int(time_seconds)) * 100)
	return "%01d:%02d.%02d" % [minutes, seconds, decimal]

# Animations
# Replace the animate_score_increase function in Scoreboard.gd with this version:

func animate_score_increase():
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale animation (keep for both modes)
	score_label.scale = Vector2(1.2, 1.2)
	tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Color modulation - only for stacking mode
	if current_game_mode == GameMode.STACKING:
		var flash_color = Color.YELLOW
		var original_color = score_label.modulate
		score_label.modulate = flash_color
		tween.tween_property(score_label, "modulate", original_color, 0.3)
	# For height challenge mode, keep original color (no color animation)
	
	# Play sound effect if volume is enabled
	if volume_enabled:
		play_score_sound()

func animate_challenge_complete():
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Flash the final height
	score_label.scale = Vector2(1.3, 1.3)
	tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.5)
	
	# Check if it's a new record
	if current_height == best_height and best_height > 0:
		var flash_color = Color.GREEN
		var original_color = high_score_label.modulate
		high_score_label.modulate = flash_color
		tween.tween_property(high_score_label, "modulate", original_color, 0.8)
		
		# Play achievement sound if volume is enabled
		if volume_enabled:
			play_achievement_sound()

# Audio functions (you can implement these with actual AudioStreamPlayer nodes)
func play_score_sound():
	# Add your score sound logic here
	pass

func play_achievement_sound():
	# Add your achievement sound logic here
	pass

func load_high_scores():
	# Load stacking mode scores
	var save_file = FileAccess.open("user://capybara_savegame.save", FileAccess.READ)
	if save_file:
		var save_data = JSON.parse_string(save_file.get_as_text())
		save_file.close()
		
		if save_data:
			if save_data.has("stacking_high_score"):
				stacking_high_score = save_data.stacking_high_score
			if save_data.has("best_height"):
				best_height = save_data.best_height
	else:
		stacking_high_score = 0
	
	# Load height challenge scores separately
	load_height_challenge_best()

# Public methods
func get_current_score() -> int:
	return current_score if current_game_mode == GameMode.STACKING else current_height

func is_height_challenge_mode() -> bool:
	return current_game_mode == GameMode.HEIGHT_CHALLENGE

func reset_score():
	if current_game_mode == GameMode.STACKING:
		current_score = 0
	else:
		current_height = 0
		time_remaining = countdown_duration
		challenge_active = false
	update_display()
	
func connect_to_game_signals():
	if has_node("/root/Main"):
		var game_manager = get_node("/root/Main")
		
		# For both modes, we need to monitor stack changes
		# Connect to any available stack change signals
		if game_manager.has_signal("stack_changed"):
			game_manager.stack_changed.connect(_on_stack_changed)
		elif game_manager.has_signal("capy_added"):
			game_manager.capy_added.connect(_on_capy_added)
	
	# Also try to connect to HeightChallenge if that's the current scene
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_signal("stack_changed"):
		current_scene.stack_changed.connect(_on_stack_changed)
		print("Connected to HeightChallenge stack_changed signal")

func _on_stack_changed():
	if current_game_mode == GameMode.HEIGHT_CHALLENGE:
		# Get the current height from the game scene
		var game_scene = get_tree().current_scene
		if game_scene and game_scene.get("capys_stack"):
			var new_height = game_scene.capys_stack.size()
			if new_height > current_height:
				# Height increased, animate it
				current_height = new_height
				update_display()
				animate_score_increase()
			else:
				current_height = new_height
				update_display()
	else:
		update_current_height()

func _on_capy_added():
	if current_game_mode == GameMode.HEIGHT_CHALLENGE:
		update_current_height()
	else:
		_on_stack_added()

# Public method to get volume state (useful for other scripts)
func is_volume_enabled() -> bool:
	return volume_enabled
	
func setup_pause_button():
	if pause_button:
		# Store original scale
		pause_button_original_scale = pause_button.scale
		
		# Connect signals
		pause_button.pressed.connect(_on_pause_button_pressed)
		pause_button.mouse_entered.connect(_on_pause_button_hover_enter)
		pause_button.mouse_exited.connect(_on_pause_button_hover_exit)
		pause_button.button_down.connect(_on_pause_button_down)
		pause_button.button_up.connect(_on_pause_button_up)

# Hover effects
func _on_pause_button_hover_enter():
	# Don't play sound if button is disabled
	if game_over_state or pause_button.disabled:
		return
	
	# Play UI sound if volume is enabled
	if volume_enabled:
		play_ui_sound()

func _on_pause_button_hover_exit():
	# No visual effect needed for hover exit
	pass

# Click effects
func _on_pause_button_down():
	# Don't process if game is over or button is disabled
	if game_over_state or pause_button.disabled:
		return
	
	# Cancel any existing click tween
	if pause_button_click_tween:
		pause_button_click_tween.kill()
	
	# Create new tween for press effect
	pause_button_click_tween = create_tween()
	pause_button_click_tween.set_parallel(true)
	
	# Scale down slightly and brighten
	var pressed_scale = pause_button_original_scale * 0.95
	pause_button_click_tween.tween_property(pause_button, "scale", pressed_scale, 0.05)
	pause_button_click_tween.tween_property(pause_button, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.05)

func _on_pause_button_up():
	# Don't process if game is over or button is disabled
	if game_over_state or pause_button.disabled:
		return
	
	# Cancel any existing click tween
	if pause_button_click_tween:
		pause_button_click_tween.kill()
	
	# Create new tween for release effect
	pause_button_click_tween = create_tween()
	pause_button_click_tween.set_parallel(true)
	
	# Return to original scale and normal color
	pause_button_click_tween.tween_property(pause_button, "scale", pause_button_original_scale, 0.1)
	pause_button_click_tween.tween_property(pause_button, "modulate", Color.WHITE, 0.1)

# Your existing pause function remains the same
func _on_pause_button_pressed():
	# Don't process if game is over or button is disabled
	if game_over_state or pause_button.disabled:
		return
	pause_game()

func pause_game():
	# Pause the game
	get_tree().paused = true
	
	# Play UI sound if volume is enabled
	if volume_enabled:
		play_ui_sound()
	
	# Load and instantiate the PauseMenu scene as an overlay
	var pause_scene = preload("res://PauseMenu.tscn")
	var pause_instance = pause_scene.instantiate()
	
	# Setup the overlay to appear on top
	pause_instance.setup_as_overlay()
	
	# Add it to the scene tree
	get_tree().current_scene.add_child(pause_instance)
