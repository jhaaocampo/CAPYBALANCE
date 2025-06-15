# Main.gd

extends Node2D

# Settings
@export var capy_height := 60.0
@export var spawn_delay := 0.6
@export var ground_margin := 130.0
@export var move_speed := 100.0
@export var max_horizontal_movement := 100.0
@export var base_capy_count_threshold := 3
@export var foundation_stability_multiplier := 2.5
@export var height_scaling_factor := 0.15
@export var compression_strength := 40.0
@export var foundation_mass_scaling := 1.8
@onready var mute: bool = false
@onready var endless_page_music = $EndlessPageMusic
@onready var drop_sound_base = $DropSoundBase
@onready var drop_sound_baby = $DropSoundBaby
@onready var drop_sound_large = $DropSoundLarge
@onready var drop_sound_sleeping = $DropSoundSleeping
@onready var enter_drop_sound = $EnterDropSound
@onready var game_over_sound = $GameOverSound
@export var ui_exclusion_zone_height := 220.0

@onready var ground_body = $Ground


# References
var current_capy = null
var spawn_timer := 0.0
var ground_level := 0.0
var moving_right := true
var capys_stack := []
var start_x_position := 0.0
var is_capy_dropping := false
var wobble_time := 0.0
var stack_balance_factor := 0.0
var stack_height := 0
var tipping_over := false
var imbalance_duration := 0.0
var base_capy_count := 0
var target_camera_position = Vector2.ZERO
var camera_speed = 2.0
var first_frame_setup_done = false
var game_over_timer := 0.0
var game_over_delay := 2.0
var scoreboard = null

# Preload scenes
var scenes = {
	"BaseCapy": preload("res://BaseCapy.tscn"),
	"BabyCapy": preload("res://BabyCapy.tscn"),
	"LargeCapy": preload("res://LargeCapy.tscn"),
	"SleepingCapy": preload("res://SleepingCapy.tscn")
}

var capy_types := {
	"BaseCapy": {"height": 60.0, "mass": 1.0, "gravity_scale": 2.2},
	"BabyCapy": {"height": 40.0, "mass": 0.6, "gravity_scale": 1.8},
	"LargeCapy": {"height": 80.0, "mass": 2.0, "gravity_scale": 2.8},
	"SleepingCapy": {"height": 65.0, "mass": 1.2, "gravity_scale": 2.0}
}

const GAME_OVER_SCENE = "res://GameOver.tscn"
var game_over_scene_instance = null

func _ready():
	randomize()
	# Calculate ground level from the actual Ground node position
	ground_body = $Ground  # Make sure we have the reference
	if ground_body:
		# Get the top surface of the ground collision shape
		var collision_shape = ground_body.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape:
			var shape = collision_shape.shape as RectangleShape2D
			if shape:
				# Ground level is the top of the ground body
				ground_level = ground_body.global_position.y - (shape.size.y / 2)
			else:
				# Fallback if shape is not RectangleShape2D
				ground_level = ground_body.global_position.y
		else:
			# Fallback if no collision shape found
			ground_level = ground_body.global_position.y
	else:
		# Fallback to original calculation if Ground node not found
		ground_level = get_viewport_rect().size.y - ground_margin
	
	start_x_position = get_viewport_rect().size.x / 2
	
	setup_touch_input()
	
	# create_ground()  # Remove this line
	place_base_capy()
	setup_initial_camera()
	setup_scoreboard()
	play_music()

func play_music() -> void:
	if not mute and endless_page_music:
		endless_page_music.play()
		
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

func play_enter_drop_sound():
	if not mute and enter_drop_sound:
		enter_drop_sound.play()

func play_game_over_sound():
	if not mute and game_over_sound:
		game_over_sound.play()
	
func setup_scoreboard():
	scoreboard = get_node_or_null("/root/Main/UI/Scoreboard")

func setup_initial_camera():
	var camera = $Camera2D
	if camera:
		camera.position = Vector2(get_viewport_rect().size.x / 2, ground_level - get_viewport_rect().size.y * 0.4)

func place_base_capy():
	var base_capy = scenes["BaseCapy"].instantiate()
	add_child(base_capy)
	base_capy.position = Vector2(start_x_position, ground_level - capy_height * 10)
	
	var rb = find_rigidbody(base_capy)
	if rb:
		setup_rigidbody(rb, "BaseCapy", true)
		rb.linear_velocity = Vector2(0, 90)
	
	current_capy = base_capy
	is_capy_dropping = true

func is_contacting_something(rb):
	for contact_body in rb.get_colliding_bodies():
		if contact_body == ground_body:
			return true
		if find_capy_owner(contact_body) in capys_stack:
			return true
	
	# Use the calculated ground_level for ground contact detection
	var capy_bottom = rb.global_position.y + (capy_height * 0.4)
	return capy_bottom >= ground_level - 5.0  # Small tolerance for ground contact

func find_capy_owner(body):
	var node = body
	while node != null:
		if node in capys_stack:
			return node
		node = node.get_parent()
	return null

func get_spawn_height():
	var consistent_drop_distance = capy_height * 8.0
	
	if capys_stack.size() > 0:
		var top_capy = capys_stack.back()
		return top_capy.position.y - consistent_drop_distance
	else:
		# For first capy, spawn at same relative distance from ground
		return ground_level - capy_height * 12.0  # Increased to maintain consistency

func _process(delta):
	update_camera(delta)
	wobble_time += delta
	
	# Handle game over - but don't reload scene automatically
	if tipping_over:
		# Remove the automatic scene reload logic
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
		# Check for touch input (mobile) or keyboard input (desktop)
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("touch_drop"):
			drop_current_capy()
			return
		
		handle_horizontal_movement(delta)
	
	if capys_stack.size() > 1:
		apply_stack_wobble(delta)
		check_stack_stability(delta)
		apply_height_based_global_stability(delta)
		
func setup_touch_input():
	# Create touch input action if it doesn't exist
	if not InputMap.has_action("touch_drop"):
		InputMap.add_action("touch_drop")
		
		# Add screen touch event
		var touch_event = InputEventScreenTouch.new()
		InputMap.action_add_event("touch_drop", touch_event)
		
		# Note: We handle mouse separately now to apply UI exclusion zone
		
func cleanup_game_over():
	if game_over_scene_instance:
		# Get the UI canvas reference and remove it
		var ui_canvas = game_over_scene_instance.get_meta("ui_canvas", null)
		if ui_canvas:
			ui_canvas.queue_free()
		else:
			game_over_scene_instance.queue_free()
		game_over_scene_instance = null
	get_tree().paused = false

func check_for_fallen_capys():
	if tipping_over:  # Already triggered, don't check again
		return
		
	if capys_stack.size() == 0:  # No capybaras in stack
		return
		
	# Check all capybaras for various failure conditions
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		if not is_instance_valid(capy):
			continue
		
		var rb = find_rigidbody(capy)
		if not rb:
			continue
		
		# FIXED: Check if any non-base capy has touched the ground
		if i > 0:  # Not the base capy (index 0)
			# More precise ground collision detection
			var capy_bottom = capy.position.y + (capy_height * 0.4)  # Bottom edge of capy
			if capy_bottom >= ground_level:
				print("Game Over: Non-base capybara touched ground at position ", capy.position.y, " (ground: ", ground_level, ")")
				trigger_game_over()
				return
			
			# Also check if touching ground body directly
			if rb.get_colliding_bodies().has(ground_body):
				print("Game Over: Non-base capybara collided with ground body")
				trigger_game_over()
				return
		
		# Each capy should only touch the one directly below it (and above it if it exists)
		var colliding_bodies = rb.get_colliding_bodies()
		for body in colliding_bodies:
			var capy_owner = find_capy_owner(body)
			if capy_owner and capy_owner in capys_stack:
				var owner_index = capys_stack.find(capy_owner)
				var current_index = i
				
				# A capy should only touch adjacent capys (one above, one below)
				var index_difference = abs(owner_index - current_index)
				if index_difference > 1:
					print("Game Over: Capy at index ", current_index, " is touching non-adjacent capy at index ", owner_index)
					trigger_game_over()
					return
		
		# Check for extreme horizontal displacement from stack center
		var base_x = capys_stack[0].position.x if capys_stack.size() > 0 else start_x_position
		var horizontal_distance = abs(capy.position.x - base_x)
		var max_allowed_distance = capy_height * 3.0  # Reasonable horizontal limit
		
		if horizontal_distance > max_allowed_distance:
			print("Game Over: Capybara displaced too far horizontally: ", horizontal_distance)
			trigger_game_over()
			return
			
		# Check for extreme velocities (capybara flying off)
		if rb.linear_velocity.length() > 800:  # Very high velocity
			print("Game Over: Capybara moving too fast: ", rb.linear_velocity.length())
			trigger_game_over()
			return

func check_dropping_capy_collision():
	if not current_capy or not is_capy_dropping or tipping_over:
		return
		
	var rb = find_rigidbody(current_capy)
	if not rb:
		return
		
	# Check what the dropping capy is colliding with
	var colliding_bodies = rb.get_colliding_bodies()
	var valid_collision = false
	var invalid_collision = false
	var touching_top_capy = false
	var touching_other_capys = false
	
	for body in colliding_bodies:
		if body == ground_body:
			# Ground collision is only valid for the first capy (base capy)
			if capys_stack.size() == 0:
				valid_collision = true
			else:
				print("Game Over: Capy tried to land on ground instead of stack")
				invalid_collision = true
				break
		else:
			# Check if colliding with a capy in the stack
			var capy_owner = find_capy_owner(body)
			if capy_owner and capy_owner in capys_stack:
				var capy_index = capys_stack.find(capy_owner)
				var top_capy_index = capys_stack.size() - 1
				
				if capy_index == top_capy_index:
					# Touching the top capy - this is good
					touching_top_capy = true
				else:
					# Touching a capy that's not the top one - this is bad
					touching_other_capys = true
					print("Game Over: Capy is touching capy at index ", capy_index, " instead of only the top capy at index ", top_capy_index)
	
	# Determine if collision is valid
	if capys_stack.size() == 0:
		# First capy - can only touch ground
		valid_collision = not touching_other_capys and not touching_top_capy
	else:
		# Subsequent capys - must touch ONLY the top capy, not any others
		valid_collision = touching_top_capy and not touching_other_capys
		if touching_other_capys:
			invalid_collision = true
	
	# If there's an invalid collision, trigger game over
	if invalid_collision:
		trigger_game_over()
		return
		
	# Check for collision with valid target and sufficient contact
	if valid_collision:
		var sufficient_contact = false
		
		if capys_stack.size() == 0:
			# First capy landing on ground
			sufficient_contact = current_capy.position.y >= ground_level - capy_height * 0.6
		else:
			# Capy landing on top of stack
			var top_capy = capys_stack.back()
			var vertical_distance = current_capy.position.y - top_capy.position.y
			sufficient_contact = vertical_distance <= capy_height * 1.2 and vertical_distance >= capy_height * 0.3
		
		if sufficient_contact and rb.linear_velocity.length() < 150:
			finalize_capy_placement()

func handle_horizontal_movement(delta):
	var rb = find_rigidbody(current_capy)
	var direction = 1 if moving_right else -1
	
	if rb:
		rb.linear_velocity.x = move_speed * direction
	else:
		current_capy.position.x += move_speed * direction * delta
	
	# Change direction at boundaries
	if current_capy.position.x > start_x_position + max_horizontal_movement:
		moving_right = false
	elif current_capy.position.x < start_x_position - max_horizontal_movement:
		moving_right = true

func destabilize_stack():
	trigger_game_over()
	
	var tip_direction = sign(stack_balance_factor)
	if tip_direction == 0:
		tip_direction = 1 if randf() > 0.5 else -1
	
	# Apply dramatic tipping physics for visual effect
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb:
			var height_factor = float(i) / max(1, capys_stack.size() - 1)
			var impulse_strength = 150.0 * height_factor
			
			rb.apply_impulse(Vector2.ZERO, Vector2(tip_direction * impulse_strength, -impulse_strength * 0.3))
			rb.apply_torque_impulse(tip_direction * 1000 * height_factor)

func trigger_game_over():
	if tipping_over:
		return  # Already triggered
	
	play_game_over_sound()
	
	tipping_over = true
	print("Game Over! Stack collapsed!")
	
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
	
	# Instead of reloading scene, show game over screen after a short delay
	await get_tree().create_timer(2.0).timeout  # Give time to see the collapse
	show_game_over_screen()

func show_game_over_screen():
	# Load and instantiate the game over scene
	var game_over_scene = load(GAME_OVER_SCENE)
	if not game_over_scene:
		push_error("Could not load game over scene!")
		return
	
	game_over_scene_instance = game_over_scene.instantiate()
	
	# Get the current score from scoreboard
	var current_score = 0
	var high_score = 0
	
	if scoreboard:
		if scoreboard.has_method("get_current_score"):
			current_score = scoreboard.get_current_score()
		elif scoreboard.has_method("get_score"):
			current_score = scoreboard.get_score()
		else:
			current_score = capys_stack.size()  # Fallback to stack size
		
		if scoreboard.has_method("get_stacking_high_score"):
			high_score = scoreboard.get_stacking_high_score()
		elif "stacking_high_score" in scoreboard:
			high_score = scoreboard.stacking_high_score
	
	# Setup the game over screen with data
	if game_over_scene_instance.has_method("setup_game_over_data"):
		var is_new_record = (current_score == high_score and current_score > 0)
		game_over_scene_instance.setup_game_over_data(current_score, high_score, false, is_new_record)
	
	# Create a dedicated CanvasLayer for UI that won't move with camera
	var ui_canvas = CanvasLayer.new()
	ui_canvas.name = "GameOverUI"
	ui_canvas.layer = 1000  # Very high layer to ensure it's always on top
	
	# Add the CanvasLayer to the scene tree root (not current scene)
	get_tree().root.add_child(ui_canvas)
	
	# Add the game over screen to the CanvasLayer
	ui_canvas.add_child(game_over_scene_instance)
	
	# Ensure it fills the screen
	game_over_scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Store reference to the UI canvas for cleanup
	game_over_scene_instance.set_meta("ui_canvas", ui_canvas)
	
	# Optional: Pause the game
	get_tree().paused = true
	game_over_scene_instance.process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func apply_stack_wobble(delta):
	calculate_stack_balance()
	
	var stack_height = capys_stack.size()
	var foundation_size = min(ceil(stack_height * 0.6), stack_height - 1)  # Larger foundation for taller stacks
	var stack_stability_multiplier = 1.0 + min(stack_height * height_scaling_factor, 4.0)  # Increased scaling
	
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb:
			var height_factor = float(i) / max(1, stack_height - 1)
			var depth_factor = float(stack_height - i) / stack_height
			var is_foundation = i < foundation_size
			
			# ENHANCED: Much stronger foundation stability scaling
			var foundation_multiplier = 1.0
			if is_foundation:
				var foundation_depth = float(foundation_size - i) / foundation_size
				var height_bonus = pow(stack_height / 3.0, 0.8)  # Exponential scaling
				foundation_multiplier = 1.0 + (foundation_depth * foundation_stability_multiplier * height_bonus)
			
			# ENHANCED: Progressive centering force - much stronger for foundation
			var base_centering = 45.0 * stack_stability_multiplier * foundation_multiplier  # Increased from 35.0
			var centering_force = -stack_balance_factor * base_centering * height_factor * (1.0 - depth_factor * 0.2)
			rb.apply_impulse(Vector2(centering_force * delta, 0), Vector2.ZERO)
			
			# ENHANCED: Foundation compression - creates "anchor" effect
			if is_foundation:
				var compression_multiplier = foundation_multiplier * (1.0 + stack_height * 0.1)
				var compression = depth_factor * i * compression_strength * delta * compression_multiplier
				rb.apply_impulse(Vector2.ZERO, Vector2(0, compression))
				
				# ENHANCED: Anti-wobble force - exponentially stronger for foundation
				var anti_wobble_strength = foundation_multiplier * (1.0 + stack_height * 0.12)
				var anti_wobble = -rb.linear_velocity.x * anti_wobble_strength * 1.2
				rb.apply_impulse(Vector2(anti_wobble * delta, 0), Vector2.ZERO)
				
				# ENHANCED: Angular velocity damping - much more aggressive for foundation
				if abs(rb.angular_velocity) > 0.2:  # Lower threshold
					var angular_damping = -rb.angular_velocity * foundation_multiplier * (1.0 + stack_height * 0.08)
					rb.apply_torque_impulse(angular_damping * delta)

func check_stack_stability(delta):
	if capys_stack.size() <= 1 or tipping_over:
		return
	
	var imbalance = abs(stack_balance_factor)
	# Enhanced threshold calculation
	var base_threshold = 0.8
	var height_bonus = min(capys_stack.size() * 0.12, 0.6)
	var foundation_bonus = min(capys_stack.size() * 0.05, 0.3)
	var stability_threshold = base_threshold + height_bonus + foundation_bonus
	
	# Check for rapid movement
	var top_capy = capys_stack.back()
	var rb = find_rigidbody(top_capy)
	var rapid_movement = false
	if rb:
		var velocity_threshold = 500 + min(capys_stack.size() * 40, 300)
		var angular_threshold = 12.0 + min(capys_stack.size() * 0.8, 8.0)
		rapid_movement = rb.linear_velocity.length() > velocity_threshold or abs(rb.angular_velocity) > angular_threshold
	
	# Additional check: if any capybara is moving extremely fast, trigger immediately
	for capy in capys_stack:
		var capy_rb = find_rigidbody(capy)
		if capy_rb and capy_rb.linear_velocity.length() > 1000:  # Emergency threshold
			print("Game Over: Emergency velocity threshold exceeded")
			trigger_game_over()
			return
	
	if imbalance > stability_threshold or rapid_movement:
		imbalance_duration += delta
		var grace_period = 4.0 + min(capys_stack.size() * 0.8, 6.0)
		if imbalance_duration > grace_period:
			print("Game Over: Stack stability threshold exceeded after grace period")
			destabilize_stack()
	else:
		imbalance_duration = max(0, imbalance_duration - delta * 3.0)

func check_if_stack_settled(capy_index):
	if capys_stack.size() <= 1:
		return true
	
	var capy = capys_stack[capy_index]
	var rb = find_rigidbody(capy)
	if not rb:
		return true
	
	# Height-based velocity thresholds - more lenient for taller stacks
	var base_threshold = 35.0  # Increased from 25.0
	var height_bonus = min(capys_stack.size() * 5.0, 25.0)
	var velocity_threshold = base_threshold + height_bonus
	var angular_velocity_threshold = 0.8 + min(capys_stack.size() * 0.1, 0.5)
	
	var is_velocity_low = rb.linear_velocity.length() < velocity_threshold
	var is_angular_velocity_low = abs(rb.angular_velocity) < angular_velocity_threshold
	
	# More forgiving tilt tolerance
	var imbalance = abs(stack_balance_factor)
	var tilt_tolerance = 0.05 + min(capys_stack.size() * 0.02, 0.15)
	var has_acceptable_tilt = imbalance > tilt_tolerance
	
	# Very still detection
	var is_very_still = rb.linear_velocity.length() < 15.0 and abs(rb.angular_velocity) < 0.3
	
	return (has_acceptable_tilt and is_velocity_low and is_angular_velocity_low) or is_very_still

func calculate_stack_balance():
	if capys_stack.size() <= 1:
		stack_balance_factor = 0.0
		return
	
	var stack_center_x = 0.0
	var total_weight = 0.0
	
	# More forgiving weight distribution calculation
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		# Reduced exponential weight growth for more forgiveness
		var weight = pow(2.0, i * 0.8)  # Reduced from 2.5
		stack_center_x += capy.position.x * weight
		total_weight += weight
	
	if total_weight > 0:
		stack_center_x /= total_weight
	
	var base_x = capys_stack[0].position.x
	var screen_width = get_viewport_rect().size.x
	
	# More forgiving balance calculation with height-based tolerance
	var tolerance_factor = 0.2 + min(capys_stack.size() * 0.02, 0.1)  # Increased tolerance
	var raw_balance = (stack_center_x - base_x) / (screen_width * tolerance_factor)
	
	# Apply smoothing to reduce sudden balance changes
	var target_balance = clamp(raw_balance, -1, 1)
	if abs(target_balance - stack_balance_factor) > 0.1:
		stack_balance_factor = lerp(stack_balance_factor, target_balance, 0.7)
	else:
		stack_balance_factor = target_balance
	
	stack_height = capys_stack.size()

func drop_current_capy():
	# Prevent dropping during game over
	if tipping_over:
		print("Prevented drop during game over")
		return
	play_enter_drop_sound()
	is_capy_dropping = true
	var capy_type_name = get_capy_type_name(current_capy)
	var capy_data = capy_types[capy_type_name]
	
	var rb = find_rigidbody(current_capy)
	if rb:
		setup_rigidbody(rb, capy_type_name, false)
		
		# Reduce velocity for early capys to prevent knockover
		var base_velocity = {"BabyCapy": 140, "LargeCapy": 200}.get(capy_type_name, 170)
		
		# Gentler drop for first few capys
		if capys_stack.size() <= 2:
			base_velocity *= 0.6
		
		rb.linear_velocity = Vector2(0, base_velocity)

func setup_rigidbody(rb, capy_type_name, is_dropping = false):
	var capy_data = capy_types[capy_type_name]
	
	# Standard rigidbody settings
	rb.gravity_scale = capy_data.gravity_scale if is_dropping else 1.8
	rb.mass = capy_data.mass
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.contact_monitor = true
	rb.max_contacts_reported = 10
	rb.collision_layer = 1
	rb.collision_mask = 1
	
	# High friction, low bounce physics material
	if rb.physics_material_override == null:
		rb.physics_material_override = PhysicsMaterial.new()
	
	rb.physics_material_override.bounce = 0.05  # Very low bounce
	rb.physics_material_override.friction = 6.0  # High friction
	
	# Heavy damping to prevent jittering
	rb.linear_damp = 3.0
	rb.angular_damp = 5.0

func update_camera(delta):
	var camera = $Camera2D
	if !camera:
		return
	
	var viewport_height = get_viewport_rect().size.y
	var viewport_width = get_viewport_rect().size.x
	
	# Initial frame setup
	if not first_frame_setup_done:
		camera.position = Vector2(viewport_width / 2, ground_level - (viewport_height * 0.5))
		first_frame_setup_done = true
		return
	
	# Game over camera behavior - show the collapse
	if tipping_over:
		# Find the vertical center of the collapsing stack, keep horizontal centered
		var stack_center_y = ground_level
		var valid_capys = 0
		
		for capy in capys_stack:
			if is_instance_valid(capy):
				stack_center_y = min(stack_center_y, capy.position.y)
				valid_capys += 1
		
		if valid_capys > 0:
			# Position camera to show the collapse nicely - only vertical adjustment
			target_camera_position = Vector2(viewport_width / 2, stack_center_y - viewport_height * 0.3)
			# Clamp vertical position to reasonable bounds
			target_camera_position.y = clamp(target_camera_position.y, ground_level - viewport_height * 0.8, ground_level - viewport_height * 0.2)
		else:
			target_camera_position = Vector2(viewport_width / 2, ground_level - viewport_height * 0.4)
		
		# Smooth camera movement to show collapse
		camera.position = camera.position.lerp(target_camera_position, delta * camera_speed * 3)
		return

	# Handle base capy dropping
	if capys_stack.size() == 0 and current_capy and is_capy_dropping:
		target_camera_position = Vector2(viewport_width / 2, current_capy.position.y - (viewport_height * 0.3))
		if target_camera_position.y > ground_level - (viewport_height * 0.4):
			target_camera_position.y = ground_level - (viewport_height * 0.4)
		camera.position = camera.position.lerp(target_camera_position, delta * camera_speed * 4)
		return
	
	# Calculate stack bounds  
	var highest_point = ground_level
	var lowest_point = ground_level
	
	if capys_stack.size() > 0:
		for capy in capys_stack:
			highest_point = min(highest_point, capy.position.y - (capy_height/2))
			lowest_point = max(lowest_point, capy.position.y + (capy_height/2))
	
	# Dynamic camera positioning
	var target_y
	var MIN_CAPYS_FOR_DYNAMIC = 4
	
	if capys_stack.size() < MIN_CAPYS_FOR_DYNAMIC:
		target_y = ground_level - (viewport_height * 0.4)
		
		# Show current capy if it's moving above
		if current_capy and !is_capy_dropping and current_capy.position.y < camera.position.y - (viewport_height * 0.45):
			var capy_screen_pos = current_capy.position.y - (viewport_height * 0.35)
			target_y = min(target_y, capy_screen_pos)
	else:
		# For larger stacks - just follow the natural stack growth
		if current_capy and !is_capy_dropping:
			target_y = current_capy.position.y - (viewport_height * 0.15)
		else:
			# No current capy - follow the top of the stack naturally
			var stack_height = lowest_point - highest_point
			var weighted_midpoint = lowest_point - (stack_height * 0.75)
			target_y = weighted_midpoint - (viewport_height * 0.6)
	
	# Visibility constraints
	target_y = max(target_y, lowest_point - (viewport_height * 0.7))  # Don't go too low
	target_y = min(target_y, highest_point - (viewport_height * 0.1))  # Don't go too high
	target_y = min(target_y, ground_level - (viewport_height * 0.4))    # Ground level limit
	
	target_camera_position = Vector2(viewport_width / 2, target_y)
	
	# Adaptive camera speed
	var adaptive_speed = camera_speed
	if capys_stack.size() < MIN_CAPYS_FOR_DYNAMIC:
		adaptive_speed *= 0.5
	else:
		var distance = (target_camera_position - camera.position).length()
		adaptive_speed *= (1 + (distance / 400))
	
	camera.position = camera.position.lerp(target_camera_position, delta * adaptive_speed)

func find_rigidbody(node):
	if node is RigidBody2D:
		return node
	for child in node.get_children():
		if child is RigidBody2D:
			return child
	return null

func _physics_process(delta):
	# CRITICAL: Exit early if game over
	if tipping_over:
		return
		
	if current_capy and is_capy_dropping:
		var rb = find_rigidbody(current_capy)
		if not rb:
			is_capy_dropping = false
			current_capy = null
			spawn_timer = spawn_delay
			return
		
		var landed = (current_capy.position.y >= ground_level - capy_height/2 or 
					 (capys_stack.size() > 0 and check_stack_collision(rb)) or 
					 (rb.linear_velocity.length() < 20 and is_near_stack(current_capy)) or 
					 (capys_stack.size() == 0 and is_contacting_something(rb)))
		
		if landed:
			finalize_capy_placement()
			
	if capys_stack.size() > 5:
		reinforce_foundation_continuously(delta)
		
	if capys_stack.size() > 6:
		apply_foundation_anchoring(delta)

func create_ground_anchor(capy):
	var rb = find_rigidbody(capy)
	if rb:
		# Base capybara becomes progressively more stable
		var initial_mass = 6.0  # Increased from 4.0
		rb.mass = initial_mass
		
		if rb.physics_material_override:
			rb.physics_material_override.friction = 20.0  # Increased from 15.0
			rb.physics_material_override.bounce = 0.001  # Almost no bounce
		
		# Much lower gravity for base - almost "rooted"
		rb.gravity_scale = 0.1  # Reduced from 0.3
		
		# Very high damping for base stability
		rb.linear_damp = 6.0  # Increased from 4.0
		rb.angular_damp = 10.0  # Increased from 6.0
		
func reinforce_foundation_continuously(delta):
	var stack_height = capys_stack.size()
	var foundation_size = min(ceil(stack_height * 0.65), stack_height - 1)  # Even larger foundation
	
	for i in range(foundation_size):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb:
			var foundation_strength = float(foundation_size - i) / foundation_size
			var height_factor = pow(stack_height / 4.0, 0.9)  # Stronger exponential scaling
			
			# ENHANCED: Much stronger continuous compression
			var compression_force = foundation_strength * height_factor * 45.0 * delta  # Increased from 30.0
			rb.apply_impulse(Vector2.ZERO, Vector2(0, compression_force))
			
			# ENHANCED: Horizontal stabilization - creates "root" system effect
			var stability_bonus = 1.0 + (stack_height - 5) * 0.15  # Bonus for very tall stacks
			var horizontal_damping = -rb.linear_velocity.x * foundation_strength * height_factor * stability_bonus * 1.8
			rb.apply_impulse(Vector2(horizontal_damping * delta, 0), Vector2.ZERO)
			
			# ENHANCED: Rotation prevention - foundation should barely rotate
			if abs(rb.angular_velocity) > 0.3:
				var rotation_damping = -rb.angular_velocity * foundation_strength * height_factor * stability_bonus * 1.2
				rb.apply_torque_impulse(rotation_damping * delta)
			
			# ENHANCED: Progressive mass increase - foundation becomes "heavier"
			if stack_height > 4 and i < min(4, foundation_size):
				var mass_growth_rate = foundation_strength * foundation_mass_scaling * 0.08 * delta
				var max_mass_multiplier = 1.0 + stack_height * 0.3  # Scales with total height
				rb.mass = min(rb.mass + mass_growth_rate, rb.mass * max_mass_multiplier)

func apply_height_based_global_stability(delta):
	var stack_height = capys_stack.size()
	if stack_height < 5:
		return
	
	# Global stability bonus that affects the entire stack
	var global_stability = min((stack_height - 4) * 0.1, 0.5)
	
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb:
			# Apply global anti-wobble
			var anti_wobble = -rb.linear_velocity * global_stability * 0.3
			rb.apply_impulse(anti_wobble * delta, Vector2.ZERO)
			
			# Reduce angular momentum globally
			var angular_damping = -rb.angular_velocity * global_stability * 0.4
			rb.apply_torque_impulse(angular_damping * delta)

func check_stack_collision(rb):
	for contact_body in rb.get_colliding_bodies():
		if contact_body and find_capy_owner(contact_body) in capys_stack:
			return true
	return false

func is_near_stack(capy):
	if capys_stack.size() == 0:
		return false
	var top_capy = capys_stack.back()
	return (capy.position - top_capy.position).length() < capy_height * 1.5

func finalize_capy_placement():
	# CRITICAL: Check for game over before finalizing
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
		
		# ADD SOUND EFFECT HERE - right after adding to stack
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
		
func apply_progressive_foundation_stability():
	var stack_height = capys_stack.size()
	if stack_height <= 2:
		return
	
	# ENHANCED: Dynamic foundation size that grows with stack height
	var foundation_size = min(ceil(stack_height * 0.7), stack_height - 1)  # Increased from 0.6
	
	# Apply enhanced stability to foundation capybaras
	for i in range(foundation_size):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb:
			# ENHANCED: Much stronger stability multipliers
			var height_multiplier = pow(stack_height / 2.5, 1.0)  # Stronger exponential growth
			var foundation_depth = float(foundation_size - i) / foundation_size
			var total_weight_above = calculate_stack_weight_above(i)
			
			# ENHANCED: Progressive mass increase - foundation becomes much heavier
			var base_mass = capy_types[get_capy_type_name(capy)]["mass"]
			var mass_bonus = foundation_depth * height_multiplier * foundation_mass_scaling  # Increased scaling
			var weight_bonus = min(total_weight_above * 0.6, 2.5)  # Increased weight bonus
			var height_bonus = (stack_height - 3) * 0.15 * foundation_depth  # New height-based bonus
			rb.mass = base_mass + mass_bonus + weight_bonus + height_bonus
			
			# ENHANCED: Much stronger damping system
			var base_linear_damp = 5.0  # Increased from 4.0
			var base_angular_damp = 8.0  # Increased from 6.0
			var damp_bonus = foundation_depth * height_multiplier * 4.5  # Increased scaling
			var stability_damp = (stack_height - 3) * 0.3 * foundation_depth  # Height-based damping
			rb.linear_damp = base_linear_damp + damp_bonus + stability_damp
			rb.angular_damp = base_angular_damp + (damp_bonus + stability_damp) * 1.5
			
			# ENHANCED: Gravity manipulation - foundation "roots" to ground
			var gravity_reduction = foundation_depth * height_multiplier * 0.6  # Increased reduction
			var height_gravity_bonus = (stack_height - 3) * 0.05 * foundation_depth
			rb.gravity_scale = max(-0.1, rb.gravity_scale - gravity_reduction - height_gravity_bonus)  # Can go slightly negative
			
			# ENHANCED: Super-friction for foundation
			if rb.physics_material_override:
				var friction_multiplier = 1.0 + foundation_depth * height_multiplier * 0.8
				var height_friction = (stack_height - 3) * 0.4 * foundation_depth
				rb.physics_material_override.friction = min(25.0, rb.physics_material_override.friction * friction_multiplier + height_friction)
				
func apply_foundation_anchoring(delta):
	var stack_height = capys_stack.size()
	if stack_height < 6:
		return
	
	var anchor_size = min(3, stack_height - 3)  # Bottom 3 capys become "anchors"
	
	for i in range(anchor_size):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb:
			var anchor_strength = float(anchor_size - i) / anchor_size
			var height_factor = (stack_height - 5) * 0.1
			
			# Pull anchors toward their original position
			var target_x = start_x_position
			var position_error = capy.position.x - target_x
			var centering_impulse = -position_error * anchor_strength * (2.0 + height_factor) * delta
			rb.apply_impulse(Vector2(centering_impulse, 0), Vector2.ZERO)
			
			# Compress anchors down toward ground
			var downward_force = anchor_strength * (15.0 + height_factor * 10.0) * delta
			rb.apply_impulse(Vector2.ZERO, Vector2(0, downward_force))
			
			# Prevent any upward movement for anchors
			if rb.linear_velocity.y < 0:
				rb.linear_velocity.y *= 0.3

func apply_gentle_early_physics(rb, stack_position):
	# Make early capys less bouncy and more stable
	if stack_position <= 2:
		if rb.physics_material_override == null:
			rb.physics_material_override = PhysicsMaterial.new()
		
		# Reduce bounce for early capys
		rb.physics_material_override.bounce *= 0.5
		# Increase friction for better grip
		rb.physics_material_override.friction *= 1.5

func create_sticky_connection(lower_capy, upper_capy):
	# Don't create any joints at all - use physics forces instead
	var lower_rb = find_rigidbody(lower_capy)
	var upper_rb = find_rigidbody(upper_capy)
	
	if lower_rb and upper_rb:
		# Just increase friction and reduce bounce for better stacking
		if lower_rb.physics_material_override:
			lower_rb.physics_material_override.friction = 8.0
			lower_rb.physics_material_override.bounce = 0.02
		if upper_rb.physics_material_override:
			upper_rb.physics_material_override.friction = 8.0
			upper_rb.physics_material_override.bounce = 0.02
			
func calculate_placement_quality(lower_capy, upper_capy):
	var lower_rb = find_rigidbody(lower_capy)
	var upper_rb = find_rigidbody(upper_capy)
	
	if not lower_rb or not upper_rb:
		return 0.0
	
	var horizontal_offset = abs(upper_rb.global_position.x - lower_rb.global_position.x)
	var offset_factor = horizontal_offset / capy_height
	
	# Perfect placement is when offset is minimal
	var centering_quality = max(0, 1.0 - offset_factor * 1.5)
	
	# Velocity quality - slower placement is better
	var velocity_magnitude = upper_rb.linear_velocity.length()
	var velocity_quality = max(0, 1.0 - velocity_magnitude / 200.0)
	
	# Angular velocity quality - less rotation is better
	var angular_quality = max(0, 1.0 - abs(upper_rb.angular_velocity) / 2.0)
	
	# Combined quality score
	return (centering_quality * 0.5 + velocity_quality * 0.3 + angular_quality * 0.2)

func calculate_connection_strength(stack_weight_above, offset_factor, center_bonus = 0.0, stickiness_factor = 1.0, placement_quality = 0.0):
	var base_strength = 0.25  # Slightly increased from 0.2
	
	# Enhanced strength scaling based on stack height
	var total_height = capys_stack.size()
	var height_bonus = min(total_height * 0.1, 0.5)  # Increased height bonus
	
	base_strength += center_bonus * 0.6
	base_strength += min(stack_weight_above * 0.25, 0.7)
	base_strength += (stickiness_factor - 1.0) * 0.5  # Increased stickiness impact
	base_strength += placement_quality * 0.3
	base_strength += height_bonus
	
	# Reduced offset penalty for more forgiveness
	var offset_penalty = offset_factor * (0.3 - center_bonus * 0.3 - (stickiness_factor - 1.0) * 0.15 - height_bonus * 0.3)
	base_strength -= offset_penalty
	
	return clamp(base_strength, 0.1, 1.0)  # Increased minimum strength

func apply_weight_compression(delta):
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb:
			var weight_above = calculate_stack_weight_above(i)
			if weight_above > 0.2:
				var compression_force = weight_above * 12.0 * delta
				var position_factor = float(capys_stack.size() - i) / capys_stack.size()
				compression_force *= position_factor
				rb.apply_impulse(Vector2.ZERO, Vector2(0, compression_force))

func spawn_capy():
	# CRITICAL: Multiple checks to prevent spawning during game over
	if current_capy != null or is_capy_dropping or tipping_over:
		print("Spawn prevented - current_capy: ", current_capy, " is_dropping: ", is_capy_dropping, " tipping: ", tipping_over)
		return
	
	var capy_type_name = get_capy_type_to_spawn()
	var capy_instance = scenes[capy_type_name].instantiate()
	add_child(capy_instance)
	
	if capy_type_name == "BaseCapy":
		base_capy_count += 1
	
	var spawn_height = get_spawn_height()
	capy_instance.position = Vector2(start_x_position, spawn_height)
	moving_right = randi() % 2 == 0
	
	var rb = find_rigidbody(capy_instance)
	if rb:
		rb.gravity_scale = 0.0
		rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		rb.freeze = false
		rb.linear_damp = 0.25
		rb.angular_damp = 4.5
		rb.linear_velocity = Vector2(move_speed * (1 if moving_right else -1), 0)
	
	current_capy = capy_instance
	print("Spawned new capy: ", capy_type_name)

func calculate_stack_weight_above(index):
	var weight = 0.0
	for i in range(index + 1, capys_stack.size()):
		if i < capys_stack.size():
			var capy_type = get_capy_type_name(capys_stack[i])
			weight += capy_types[capy_type]["mass"]
	return weight

func _stabilize_capy(capy):
	var rb = find_rigidbody(capy)
	if rb:
		var stack_position = capys_stack.find(capy)
		var stack_weight_above = calculate_stack_weight_above(stack_position)
		var total_stack_height = capys_stack.size()
		
		rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		rb.freeze = false
		
		# Enhanced stability scaling based on stack height and position
		var depth_factor = float(total_stack_height - stack_position) / max(1, total_stack_height)
		var height_multiplier = pow(total_stack_height / 5.0, 0.6)  # Logarithmic scaling
		
		# Progressive gravity reduction for lower capybaras, but apply weight compression
		var base_gravity = 0.5
		var weight_gravity_reduction = min(stack_weight_above * 0.12, 0.25)
		var depth_gravity_reduction = depth_factor * 0.15 * height_multiplier
		rb.gravity_scale = max(0.1, base_gravity - weight_gravity_reduction - depth_gravity_reduction)
		
		# Apply weight compression - push capybaras down based on weight above
		if stack_weight_above > 0.5:
			var compression_force = stack_weight_above * 25.0 * depth_factor
			rb.apply_impulse(Vector2.ZERO, Vector2(0, compression_force))
		
		# Enhanced mass scaling for better stability at bottom
		var base_mass = 0.95 + depth_factor * 1.2
		var weight_mass_bonus = stack_weight_above * 0.35
		var stability_mass_bonus = depth_factor * height_multiplier * 0.8
		rb.mass = base_mass + weight_mass_bonus + stability_mass_bonus
		
		# Increased damping for lower capybaras to reduce wobbling
		var base_damp = 2.2
		var weight_damp_bonus = stack_weight_above * 0.5
		var depth_damp_bonus = depth_factor * 1.8 * height_multiplier
		rb.linear_damp = base_damp + weight_damp_bonus + depth_damp_bonus
		rb.angular_damp = base_damp + weight_damp_bonus + depth_damp_bonus * 1.2

func get_capy_type_to_spawn():
	if base_capy_count < base_capy_count_threshold:
		return "BaseCapy"
	
	var choices = [
		{"type": "BaseCapy", "weight": 25},
		{"type": "BabyCapy", "weight": 25},
		{"type": "LargeCapy", "weight": 25},
		{"type": "SleepingCapy", "weight": 25}
	]
	
	var total_weight = 0
	for choice in choices:
		total_weight += choice.weight
	
	var rand_val = randi() % total_weight
	var current_weight = 0
	
	for choice in choices:
		current_weight += choice.weight
		if rand_val < current_weight:
			return choice.type
	
	return "BaseCapy"

func get_capy_type_name(capy_instance):
	var scene_path = capy_instance.scene_file_path
	for type_name in capy_types.keys():
		if scene_path.ends_with(type_name + ".tscn"):
			return type_name
	return "BaseCapy"

func _input(event):
	# Handle restart key
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
		return
	
	# Handle touch input for mobile devices - with UI exclusion zone
	if event is InputEventScreenTouch:
		if event.pressed and current_capy and not is_capy_dropping and not tipping_over:
			# Check if touch is in the UI exclusion zone (top part of screen)
			var screen_size = get_viewport_rect().size
			var touch_y = event.position.y
			
			# Only allow capybara dropping if touch is below the UI zone
			if touch_y > ui_exclusion_zone_height:
				drop_current_capy()
	
	# Handle mouse clicks for desktop (optional - for testing on desktop)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if current_capy and not is_capy_dropping and not tipping_over:
				# Apply same UI exclusion zone for mouse clicks
				var screen_size = get_viewport_rect().size
				var click_y = event.position.y
				
				# Only allow capybara dropping if click is below the UI zone
				if click_y > ui_exclusion_zone_height:
					drop_current_capy()
