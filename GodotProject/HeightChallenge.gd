# HeightChallenge.gd
extends "res://Main.gd"  # Inherit from your main script

signal stack_changed

# Height Challenge specific variables
@export var challenge_duration := 60.0  # 1 minute countdown
var time_remaining := 60.0
var challenge_active := false
var challenge_started := false
var best_stack_height := 0
var five_second_warning_played := false
@onready var height_challenge_bgm = $HeightChallengeBGM
@onready var five_second_warning = $FiveSecondWarning

# Override the setup_scoreboard function to use the correct path
func setup_scoreboard():
	# When HeightChallenge scene is running, the root is HeightChallenge, not Main
	var current_scene_name = get_tree().current_scene.name
	scoreboard = get_node_or_null("/" + "root/" + current_scene_name + "/UI/Scoreboard")
	
	if not scoreboard:
		# Try alternative paths
		var possible_paths = [
			"/root/" + current_scene_name + "/UI/Scoreboard",
			"UI/Scoreboard",
			"/root/HeightChallenge/UI/Scoreboard",
			"/root/Main/UI/Scoreboard"  # Fallback to original
		]
		
		for path in possible_paths:
			scoreboard = get_node_or_null(path)
			if scoreboard:
				print("Found scoreboard at: ", path)
				break
	
	if scoreboard:
		print("Scoreboard connected successfully")
		# Initialize for height challenge mode
		setup_height_challenge_mode()
	else:
		print("ERROR: Could not find scoreboard at any expected path")

func setup_height_challenge_mode():
	if not scoreboard:
		return
	
	# Force the scoreboard into height challenge mode
	scoreboard.current_game_mode = scoreboard.GameMode.HEIGHT_CHALLENGE
	scoreboard.countdown_duration = challenge_duration
	scoreboard.time_remaining = time_remaining
	scoreboard.challenge_active = challenge_active
	scoreboard.best_height = best_stack_height
	scoreboard.current_height = 0
	
	# Load height challenge best score
	scoreboard.load_height_challenge_best()
	best_stack_height = scoreboard.best_height
	
	# Force initial display update
	scoreboard.update_display()
	
	print("Height challenge mode setup complete")

# Override the _ready function
func _ready():
	super._ready()  # This will call Main's _ready, which calls setup_scoreboard
	
	drop_sound_base = get_node_or_null("DropSoundBase")
	drop_sound_baby = get_node_or_null("DropSoundBaby") 
	drop_sound_large = get_node_or_null("DropSoundLarge")
	drop_sound_sleeping = get_node_or_null("DropSoundSleeping")
	
	time_remaining = challenge_duration
	challenge_active = true
	challenge_started = true
	
	# Load our best height
	load_best_height()
	
	# Make sure scoreboard is in the right mode (in case setup_scoreboard ran before this)
	if scoreboard:
		setup_height_challenge_mode()
	# Play BGM when height challenge starts
	play_height_challenge_bgm()
# Override _process to handle countdown timer
func _process(delta):
	# INTEGRATED FIX: Handle game over timer and restart - same as Main.gd
	update_camera(delta)
	wobble_time += delta
	
	# Handle game over timer and restart
	if tipping_over:
		game_over_timer += delta
		if game_over_timer >= game_over_delay:
			show_game_over_screen()
		return  # Don't process anything else during game over
	
	# Check for fallen capybaras FIRST - before any other logic
	check_for_fallen_capys()
	
	# Exit early if game over was triggered
	if tipping_over:
		return
	
	# Only spawn if not tipping over and no current capy
	if current_capy == null and not is_capy_dropping:
		spawn_timer += delta
		if spawn_timer >= spawn_delay:
			spawn_capy()
			spawn_timer = 0.0
	
	# Handle input and movement - prevent input during game over
	if current_capy and not is_capy_dropping:
		if Input.is_action_just_pressed("ui_accept"):
			drop_current_capy()
			return
		
		handle_horizontal_movement(delta)
	
	if capys_stack.size() > 1:
		apply_stack_wobble(delta)
		check_stack_stability(delta)
		apply_height_based_global_stability(delta)
	
	# HEIGHT CHALLENGE SPECIFIC: Handle countdown timer
	if challenge_active and challenge_started and scoreboard:
		var previous_time = time_remaining
		time_remaining -= delta
		
		if time_remaining <= 5.0 and time_remaining > 0.0 and not five_second_warning_played:
			# Fade out BGM and play warning sound
			if height_challenge_bgm and height_challenge_bgm.playing:
				var tween = create_tween()
				tween.tween_property(height_challenge_bgm, "volume_db", -80.0, 0.5)
				tween.tween_callback(height_challenge_bgm.stop)
			play_five_second_warning()
			five_second_warning_played = true
		
		var current_height = capys_stack.size() if capys_stack else 0
		
		# Update scoreboard with current stats
		scoreboard.update_height_challenge_stats(
			current_height,
			best_stack_height,
			time_remaining,
			challenge_active
		)
		
		# End challenge when time runs out
		if time_remaining <= 0.0:
			end_height_challenge()

# Override finalize_capy_placement with integrated fixes
func finalize_capy_placement():
	# INTEGRATED FIX: Check for game over before finalizing - same as Main.gd
	if tipping_over:
		if current_capy:
			current_capy.queue_free()
			current_capy = null
		is_capy_dropping = false
		return
		
	if current_capy:
		var rb = find_rigidbody(current_capy)
		if rb:
			# Softer landing
			rb.linear_velocity *= 0.3
			rb.angular_velocity *= 0.1
			rb.apply_impulse(Vector2.ZERO, Vector2(0, 30))
		
		# Add to stack
		capys_stack.append(current_capy)
				# Play specific capybara sound based on type
		#play_capybara_land_sound(current_capy) 
		
		var capy_type = get_capy_type_name(current_capy)
		match capy_type:
			"BaseCapy":
				play_base_sound()
			"BabyCapy":
				play_baby_sound()
			"LargeCapy":
				play_large_sound()
			"SleepingCapy":
				play_sleeping_sound()
		
		# Enhanced base stability
		if capys_stack.size() == 1:
			create_ground_anchor(current_capy)
		
		# Progressive stickiness
		if capys_stack.size() > 1:
			create_sticky_connection(capys_stack[capys_stack.size() - 2], current_capy)
		
		# Apply progressive foundation stabilization to lower capybaras
		apply_progressive_foundation_stability()
		
		current_capy = null
		is_capy_dropping = false
		spawn_timer = 0.0
		
		calculate_stack_balance()
		
		if scoreboard and scoreboard.has_method("_on_stack_added"):
			scoreboard._on_stack_added()
	
	# HEIGHT CHALLENGE SPECIFIC: Emit stack changed signal and update stats
	emit_signal("stack_changed")
	
	if scoreboard:
		var current_height = capys_stack.size()
		
		# Update best height if this is a new record
		if current_height > best_stack_height:
			best_stack_height = current_height
			save_best_height()
			# Also update scoreboard's best_height
			scoreboard.best_height = best_stack_height
		
		# Update scoreboard immediately
		scoreboard.update_height_challenge_stats(
			current_height,
			best_stack_height,
			time_remaining,
			challenge_active
		)

func trigger_game_over():
	# INTEGRATED FIX: Same prevention logic as Main.gd
	if tipping_over:
		return  # Already triggered
	
	# HEIGHT CHALLENGE SPECIFIC: Check if challenge is still active
	if challenge_active:
		end_height_challenge()
	else:
		# Use the integrated game over logic from Main.gd
		tipping_over = true
		print("Game Over! Stack collapsed!")
		play_game_over_sound()
		# Notify scoreboard of game over
		if scoreboard and scoreboard.has_method("game_over"):
			scoreboard.game_over()
		
		# IMMEDIATELY stop spawning and remove current capy
		if current_capy:
			current_capy.queue_free()
			current_capy = null
		
		# Reset all spawning variables
		spawn_timer = 0.0
		is_capy_dropping = false
		
		# Start restart timer
		game_over_timer = 0.0

func end_height_challenge():
	if not challenge_active:
		return
		
	challenge_active = false
	challenge_started = false
	time_remaining = 0.0
	play_game_over_sound()
	
	
	# Record the final stack height
	var final_height = capys_stack.size()
	
	# Check if it's a new best
	if final_height > best_stack_height:
		best_stack_height = final_height
		save_best_height()
	
	# Notify scoreboard of challenge end
	if scoreboard:
		scoreboard.end_height_challenge(final_height, best_stack_height)
	
	# Start restart timer using integrated logic
	tipping_over = true
	game_over_timer = 0.0
	
	# INTEGRATED FIX: Stop spawning and clean up current capy
	if current_capy:
		current_capy.queue_free()
		current_capy = null
	
	spawn_timer = 0.0
	is_capy_dropping = false
	
	print("Height Challenge Complete! Final Height: ", final_height, " Best: ", best_stack_height)

func save_best_height():
	var save_file = FileAccess.open("user://height_challenge_save.save", FileAccess.WRITE)
	if save_file:
		save_file.store_32(best_stack_height)
		save_file.close()

func load_best_height():
	var save_file = FileAccess.open("user://height_challenge_save.save", FileAccess.READ)
	if save_file:
		best_stack_height = save_file.get_32()
		save_file.close()
	else:
		best_stack_height = 0

func play_height_challenge_bgm():
	if not mute and height_challenge_bgm:
		height_challenge_bgm.play()
		
func play_game_over_sound():
	if not mute and game_over_sound:
		game_over_sound.play()

func play_base_sound():
	if not mute and drop_sound_base:
		drop_sound_base.play()

func play_baby_sound():
	if not mute and drop_sound_baby:
		drop_sound_baby.play()

func play_large_sound():
	if not mute and drop_sound_large:
		drop_sound_large.play()

func play_sleeping_sound():
	if not mute and drop_sound_sleeping:
		drop_sound_sleeping.play()
		
func play_five_second_warning():
	if not mute and five_second_warning:
		five_second_warning.play()
