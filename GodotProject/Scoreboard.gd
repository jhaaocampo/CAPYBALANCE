# Scoreboard.gd UI script
extends Control

@onready var score_label: Label = $Stacks
@onready var high_score_label: Label = $HighScore
@onready var timer_label: Label = $Timer
@onready var volume_button: TextureButton = $VolumeButtonContainer/VolumeButton
@onready var pause_button: TextureButton = $PauseButtonContainer/PauseButton

# Volume state
var volume_enabled: bool = true

# Game mode detection
enum GameMode { STACKING, HEIGHT_CHALLENGE }

var current_game_mode: GameMode = GameMode.STACKING

# Stacking mode variables
var current_score: int = 0
var stacking_high_score: int = 0

# Height challenge mode variables
var countdown_duration: float = 60.0
var time_remaining: float = 60.0
var challenge_active: bool = false
var current_height: int = 0
var best_height: int = 0

func _ready():
	detect_game_mode()
	load_high_scores()
	load_volume_setting()  # Load volume setting
	setup_volume_button()  # Setup volume button
	setup_pause_button()
	update_display()
	connect_to_game_signals()

# Volume functions
func setup_volume_button():
	if volume_button:
		volume_button.toggle_mode = true
		volume_button.button_pressed = !volume_enabled  # Inverted because pressed = muted
		volume_button.pressed.connect(_on_volume_button_pressed)

func _on_volume_button_pressed():
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
				return
			
	current_game_mode = GameMode.STACKING
	print("Detected STACKING mode (default)")

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
		update_display()

# Display updates
func update_display():
	if current_game_mode == GameMode.STACKING:
		update_stacking_display()
	else:
		update_height_challenge_display()

func update_stacking_display():
	score_label.text = "Stacks\n" + str(current_score)
	high_score_label.text = "High Score\n" + str(stacking_high_score)
	
	if timer_label:
		timer_label.visible = false

func update_height_challenge_display():
	score_label.text = "Height\n" + str(current_height)
	high_score_label.text = "Best Height\n" + str(best_height)
	
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
func animate_score_increase():
	var tween = create_tween()
	tween.set_parallel(true)
	
	score_label.scale = Vector2(1.2, 1.2)
	tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.2)
	
	var flash_color = Color.YELLOW if current_game_mode == GameMode.STACKING else Color.CYAN
	var original_color = score_label.modulate
	score_label.modulate = flash_color
	tween.tween_property(score_label, "modulate", original_color, 0.3)
	
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

func _on_stack_changed():
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
		pause_button.pressed.connect(_on_pause_button_pressed)

func _on_pause_button_pressed():
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
