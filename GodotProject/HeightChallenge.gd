# HeightChallenge.gd
extends "res://Main.gd"  # Inherit from your main script

signal stack_changed

# Height Challenge specific variables
@export var challenge_duration := 60.0  # 1 minute countdown
var time_remaining := 60.0
var challenge_active := false
var challenge_started := false
var best_stack_height := 0

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
	
	time_remaining = challenge_duration
	challenge_active = true
	challenge_started = true
	
	# Load our best height
	load_best_height()
	
	# Make sure scoreboard is in the right mode (in case setup_scoreboard ran before this)
	if scoreboard:
		setup_height_challenge_mode()

# Override _process to handle countdown timer
func _process(delta):
	super._process(delta)  # Call parent _process
	
	if challenge_active and challenge_started and scoreboard:
		time_remaining -= delta
		
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

# Override finalize_capy_placement 
func finalize_capy_placement():
	super.finalize_capy_placement()
	
	# Emit stack changed signal
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

# Override trigger_game_over for height challenge logic
func trigger_game_over():
	if challenge_active:
		end_height_challenge()
	else:
		super.trigger_game_over()

func end_height_challenge():
	if not challenge_active:
		return
		
	challenge_active = false
	challenge_started = false
	time_remaining = 0.0
	
	# Record the final stack height
	var final_height = capys_stack.size()
	
	# Check if it's a new best
	if final_height > best_stack_height:
		best_stack_height = final_height
		save_best_height()
	
	# Notify scoreboard of challenge end
	if scoreboard:
		scoreboard.end_height_challenge(final_height, best_stack_height)
	
	# Start restart timer
	tipping_over = true
	game_over_timer = 0.0
	
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
