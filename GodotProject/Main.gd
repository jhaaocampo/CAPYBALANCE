extends Node2D

# Settings
@export var capy_height := 60.0
@export var spawn_delay := 1.0
@export var ground_margin := 100.0
@export var move_speed := 100.0
@export var start_height := 300.0
@export var max_horizontal_movement := 100.0
# Balance physics settings
@export var wobble_factor := 1.5
@export var center_sticky_range := 10.0
@export var max_sticky_force := 30.0
@export var balance_threshold := 0.25
@export var auto_center_force := 1.0
@export var wobble_frequency := 0.4
@export var wobble_amplitude := 1.5
@export var stack_elasticity := 0.35
@export var edge_penalty := 2.0
@export var base_capy_count_threshold := 3

# References
var current_capy = null
var spawn_timer := 0.0
var ground_level := 0.0
var moving_right := true
var capys_stack := []
var start_x_position := 0.0
var is_capy_dropping := false
var ground_body = null
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

func _ready():
	randomize()
	ground_level = get_viewport_rect().size.y - ground_margin
	start_x_position = get_viewport_rect().size.x / 2
	create_ground()
	place_base_capy()
	setup_initial_camera()

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

func create_ground():
	ground_body = StaticBody2D.new()
	ground_body.position = Vector2(get_viewport_rect().size.x / 2, ground_level + 10)
	ground_body.collision_layer = 1
	ground_body.collision_mask = 1
	add_child(ground_body)
	
	var ground_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(get_viewport_rect().size.x, 20)
	ground_shape.shape = shape
	ground_body.add_child(ground_shape)

# Combined contact checking function
func is_contacting_something(rb):
	for contact_body in rb.get_colliding_bodies():
		if contact_body == ground_body or find_capy_owner(contact_body) in capys_stack:
			return true
	return abs(rb.global_position.y - ground_level) < capy_height * 0.35

func find_capy_owner(body):
	var node = body
	while node != null:
		if node in capys_stack:
			return node
		node = node.get_parent()
	return null

func get_spawn_height():
	var consistent_drop_distance = capy_height * 8.0  # Increased from 4.0 to 8.0
	
	if capys_stack.size() > 0:
		var top_capy = capys_stack.back()
		return top_capy.position.y - consistent_drop_distance
	else:
		# For first capy, spawn at same relative distance from ground
		return ground_level - capy_height * 12.0  # Increased to maintain consistency

func _process(delta):
	update_camera(delta)
	wobble_time += delta
	
	# Handle game over timer and restart
	if tipping_over:
		game_over_timer += delta
		if game_over_timer >= game_over_delay:
			get_tree().reload_current_scene()
		return  # Don't process anything else during game over
	
	# Check for fallen capybaras
	check_for_fallen_capys()
	
	if current_capy == null and not is_capy_dropping:
		spawn_timer += delta
		if spawn_timer >= spawn_delay:
			spawn_capy()
			spawn_timer = 0.0
	
	# Handle input and movement
	if current_capy and not is_capy_dropping:
		if Input.is_action_just_pressed("ui_accept"):
			drop_current_capy()
			return
		
		handle_horizontal_movement(delta)
	
	# Apply simplified stack effects
	if capys_stack.size() > 1:
		apply_stack_wobble(delta)
		check_stack_stability(delta)

func check_for_fallen_capys():
	if capys_stack.size() <= 1:  # Only base capy or empty
		return
		
	# Check all capybaras except the base (index 0)
	for i in range(1, capys_stack.size()):
		var capy = capys_stack[i]
		if not is_instance_valid(capy):
			continue
			
		# If any non-base capy hits the ground, game over
		if capy.position.y >= ground_level - capy_height * 0.3:
			trigger_game_over()
			return

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
		
	tipping_over = true
	print("Game Over! Stack collapsed!")
	
	# Stop spawning new capybaras immediately
	if current_capy and not is_capy_dropping:
		# Remove the current moving capybara
		current_capy.queue_free()
		current_capy = null
	
	# Stop any ongoing spawning
	spawn_timer = 0.0
	is_capy_dropping = false
	
	# Start restart timer
	game_over_timer = 0.0

func apply_stack_wobble(delta):
	calculate_stack_balance()
	
	# Apply gentle corrective forces directly to rigidbodies
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb:
			var height_factor = float(i) / max(1, capys_stack.size() - 1)
			var depth_factor = float(capys_stack.size() - i) / capys_stack.size()
			
			# Gentle centering force (much weaker than before)
			var centering_force = -stack_balance_factor * 15.0 * height_factor * (1.0 - depth_factor * 0.7)
			rb.apply_impulse(Vector2(centering_force * delta, 0), Vector2.ZERO)
			
			# Add weight-based downward force for compression
			var compression = depth_factor * i * 8.0 * delta
			rb.apply_impulse(Vector2.ZERO, Vector2(0, compression))

func check_stack_stability(delta):
	if capys_stack.size() <= 1 or tipping_over:
		return
	
	var imbalance = abs(stack_balance_factor)
	var stability_threshold = 0.6  # Reduced from 0.75 for earlier detection
	
	# Also check for rapid movement indicating instability
	var top_capy = capys_stack.back()
	var rb = find_rigidbody(top_capy)
	var rapid_movement = false
	if rb:
		rapid_movement = rb.linear_velocity.length() > 200 or abs(rb.angular_velocity) > 5.0
	
	if imbalance > stability_threshold or rapid_movement:
		imbalance_duration += delta
		if imbalance_duration > 2.0:  # Reduced from 3.0 seconds
			destabilize_stack()
	else:
		imbalance_duration = max(0, imbalance_duration - delta)

func check_if_stack_settled(capy_index):
	if capys_stack.size() <= 1:
		return true
	
	var capy = capys_stack[capy_index]
	var rb = find_rigidbody(capy)
	if not rb:
		return true
	
	# More lenient velocity thresholds
	var velocity_threshold = 25.0  # Increased from 15.0
	var angular_velocity_threshold = 0.5  # Increased from 0.3
	
	var is_velocity_low = rb.linear_velocity.length() < velocity_threshold
	var is_angular_velocity_low = abs(rb.angular_velocity) < angular_velocity_threshold
	
	# Check if the stack has been in a tilted state for a reasonable time
	var imbalance = abs(stack_balance_factor)
	var has_some_tilt = imbalance > 0.1  # Reduced from 0.15
	
	# Also consider it settled if velocities are very low, even without tilt
	var is_very_still = rb.linear_velocity.length() < 10.0 and abs(rb.angular_velocity) < 0.2
	
	return (has_some_tilt and is_velocity_low and is_angular_velocity_low) or is_very_still

func calculate_stack_balance():
	if capys_stack.size() <= 1:
		stack_balance_factor = 0.0
		return
	
	var stack_center_x = 0.0
	var total_weight = 0.0
	
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		var weight = pow(2.5, i)
		stack_center_x += capy.position.x * weight
		total_weight += weight
	
	if total_weight > 0:
		stack_center_x /= total_weight
	
	var base_x = capys_stack[0].position.x
	var screen_width = get_viewport_rect().size.x
	var raw_balance = (stack_center_x - base_x) / (screen_width * 0.15)
	
	stack_balance_factor = clamp(raw_balance, -1, 1)
	stack_height = capys_stack.size()

func drop_current_capy():
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
			base_velocity *= 0.6  # Reduce velocity by 40%
		
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
	
	# Rest of the normal camera logic remains the same...
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
	if current_capy:
		var rb = find_rigidbody(current_capy)
		if rb:
			# Reduce velocity for softer landing
			rb.linear_velocity *= 0.4
			rb.angular_velocity *= 0.2
			
			# Apply settling force
			rb.apply_impulse(Vector2.ZERO, Vector2(0, 50))
		
		# Add to stack without creating joints
		capys_stack.append(current_capy)
		
		# Make base capy extra stable
		if capys_stack.size() == 1:
			create_ground_anchor(current_capy)  # This now just increases mass/friction
		
		var scoreboard = get_node("/root/Main/UI/Scoreboard")
		if scoreboard:
			scoreboard.add_score(1)
			
		# Apply sticky physics instead of joints
		if capys_stack.size() > 1:
			create_sticky_connection(capys_stack[capys_stack.size() - 2], current_capy)
		
		current_capy = null
		is_capy_dropping = false
		spawn_timer = 0.0
		
		calculate_stack_balance()
		
func create_ground_anchor(capy):
	# Don't create any anchor joint - just make base capy heavier and stickier
	var rb = find_rigidbody(capy)
	if rb:
		rb.mass = 3.0  # Make base capy much heavier
		if rb.physics_material_override:
			rb.physics_material_override.friction = 12.0
			rb.physics_material_override.bounce = 0.01

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
	if current_capy != null or is_capy_dropping or tipping_over:
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

func _draw():
	draw_line(Vector2(0, ground_level), Vector2(get_viewport_rect().size.x, ground_level), Color.WHITE, 2.0)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
