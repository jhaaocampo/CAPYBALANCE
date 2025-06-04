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
var stack_joints := []
var stack_balance_factor := 0.0
var stack_height := 0
var tipping_over := false
var off_center_timer := 0.0
var imbalance_duration := 0.0
var base_capy_count := 0
var target_camera_position = Vector2.ZERO
var camera_speed = 2.0
var first_frame_setup_done = false

# Preload scenes
var scenes = {
	"BaseCapy": preload("res://BaseCapy.tscn"),
	"BabyCapy": preload("res://BabyCapy.tscn"),
	"LargeCapy": preload("res://LargeCapy.tscn"),
	"SleepingCapy": preload("res://SleepingCapy.tscn"),
	"StickyCapy": preload("res://StickyCapy.tscn")
}

# Combined capybara type data with scene references
var capy_types := {
	"BaseCapy": {"height": 60.0, "mass": 1.0, "bounce": 0.12, "friction": 4.0, "gravity_scale": 2.2},
	"BabyCapy": {"height": 40.0, "mass": 0.6, "bounce": 0.18, "friction": 3.0, "gravity_scale": 1.8},
	"LargeCapy": {"height": 80.0, "mass": 2.0, "bounce": 0.08, "friction": 6.0, "gravity_scale": 2.8},
	"SleepingCapy": {"height": 65.0, "mass": 1.2, "bounce": 0.05, "friction": 8.0, "gravity_scale": 2.0},
	"StickyCapy": {"height": 55.0, "mass": 0.9, "bounce": 0.15, "friction": 5.0, "gravity_scale": 2.1, "sticky_range": 80.0, "sticky_strength": 2.5}
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
	var base_height = start_height
	if capys_stack.size() > 0:
		var top_capy = capys_stack.back()
		var stack_factor = min(capys_stack.size() * 0.5, 3.0)
		var spawn_distance = capy_height * (5 + stack_factor)
		return min(top_capy.position.y - spawn_distance, ground_level - capy_height * 15)
	return base_height

func _process(delta):
	update_camera(delta)
	wobble_time += delta
	
	if current_capy == null and not is_capy_dropping and not tipping_over:
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
	
	# Apply stack effects
	if capys_stack.size() > 1:
		apply_stack_wobble(delta)
		check_stack_stability(delta)
		queue_redraw()

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
		if current_capy and !is_capy_dropping and current_capy.position.y < camera.position.y - (viewport_height * 0.45):
			var capy_screen_pos = current_capy.position.y - (viewport_height * 0.35)
			target_y = min(target_y, capy_screen_pos)
	else:
		if current_capy and !is_capy_dropping:
			target_y = current_capy.position.y - (viewport_height * 0.15)
			var remaining_viewport = viewport_height * 0.85
			var distance_to_lowest = abs(current_capy.position.y - lowest_point)
			if distance_to_lowest > remaining_viewport * 0.8:
				target_y = current_capy.position.y - (viewport_height * 0.1)
		else:
			var stack_height = lowest_point - highest_point
			var weighted_midpoint = lowest_point - (stack_height * 0.75)
			target_y = weighted_midpoint - (viewport_height * 0.6)
		
		# Visibility constraints
		target_y = max(target_y, lowest_point - (viewport_height * 0.6))
		target_y = min(target_y, highest_point - (viewport_height * 0.05))
	
	target_y = min(target_y, ground_level - (viewport_height * 0.5))
	target_camera_position = Vector2(viewport_width / 2, target_y)
	
	# Adaptive camera speed
	var adaptive_speed = camera_speed
	if capys_stack.size() < MIN_CAPYS_FOR_DYNAMIC:
		adaptive_speed *= 0.4
	else:
		var distance = (target_camera_position - camera.position).length()
		adaptive_speed *= (1 + (distance / 300))
	
	camera.position = camera.position.lerp(target_camera_position, delta * adaptive_speed)

func check_stack_stability(delta):
	if capys_stack.size() <= 1:
		return
	
	# Calculate basic stability factors
	var sticky_count = 0
	var stack_is_settled = true
	
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		if get_capy_type_name(capy) == "StickyCapy":
			sticky_count += 1
		if not check_if_stack_settled(i):
			stack_is_settled = false
	
	var imbalance = abs(stack_balance_factor)
	
	# Simple stability threshold based on key factors
	var stability_threshold = 0.4 + (sticky_count * 0.2) + (0.3 if stack_is_settled else 0.0)
	
	# Reset tipping if stack has stabilized
	if tipping_over and stack_is_settled and imbalance < stability_threshold * 0.6:
		tipping_over = false
		imbalance_duration = 0.0
		call_deferred("_reestablish_stack_joints")
		return
	
	# Skip tipping checks if already tipping
	if tipping_over:
		return
	
	# Simple tipping logic
	if imbalance > stability_threshold:
		imbalance_duration += delta * (2.0 if not stack_is_settled else 0.5)
		
		# Immediate tip for extreme imbalance
		if imbalance > 0.8 or (imbalance > 0.6 and capys_stack.size() >= 4):
			destabilize_stack()
		# Gradual tip chance based on duration
		elif imbalance_duration > 1.0 and randf() < 0.02:
			destabilize_stack()
	else:
		imbalance_duration = max(0, imbalance_duration - delta * 2.0)

# NEW: Function to re-establish joints when stack stabilizes
func _reestablish_stack_joints():
	# Clear any existing joints first
	for joint in stack_joints:
		if joint and is_instance_valid(joint):
			joint.queue_free()
	stack_joints.clear()
	
	# Re-establish joints between adjacent capys
	for i in range(1, capys_stack.size()):
		var lower_capy = capys_stack[i-1]
		var upper_capy = capys_stack[i]
		create_sticky_connection(lower_capy, upper_capy)
	
	# Re-stabilize all capys in the stack
	for capy in capys_stack:
		call_deferred("_stabilize_capy", capy)

func destabilize_stack():
	tipping_over = true
	var tip_direction = sign(stack_balance_factor)
	
	# Free all joints
	for joint in stack_joints:
		if joint and is_instance_valid(joint):
			joint.queue_free()
	
	# Apply tipping physics
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb:
			rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
			rb.gravity_scale = 1.3
			
			var height_factor = float(i) / max(1, capys_stack.size() - 1)
			var impulse_strength = 70.0 * height_factor
			var random_factor = randf() * 0.4 + 0.8
			
			rb.apply_impulse(Vector2.ZERO, Vector2(tip_direction * impulse_strength * random_factor, -impulse_strength * 0.3 * random_factor))
			rb.apply_torque_impulse(tip_direction * 500 * height_factor * random_factor)
	
	# Reset timer
	var timer = Timer.new()
	timer.wait_time = 4.0
	timer.one_shot = true
	add_child(timer)
	timer.connect("timeout", Callable(self, "_on_reset_timer_timeout"))
	timer.start()

func _on_reset_timer_timeout():
	get_tree().reload_current_scene()

func apply_stack_wobble(delta):
	calculate_stack_balance()
	
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb and rb.freeze_mode == RigidBody2D.FREEZE_MODE_KINEMATIC:
			var height_factor = float(i) / max(1, capys_stack.size() - 1)
			var stack_weight_above = calculate_stack_weight_above(i)
			
			# Check if stack has settled in a tilted position
			var is_settled = check_if_stack_settled(i)
			
			# If settled, greatly reduce wobble forces
			var settle_factor = 1.0
			if is_settled:
				settle_factor = 0.1  # Greatly reduce forces when settled
			
			# Slightly reduced weight dampening for more flow
			var weight_damping = min(stack_weight_above * 0.18, 0.75)
			var wobble_strength = wobble_factor * abs(stack_balance_factor) * height_factor * (1.0 - weight_damping) * settle_factor
			
			# Slightly increased wobble but reduced when settled
			var wobble_noise = sin(wobble_time * wobble_frequency * 1.1 * (i + 1)) * wobble_amplitude * 1.2 * height_factor * settle_factor
			wobble_noise += (randf() * 2 - 1) * height_factor * 0.6 * settle_factor
			wobble_noise *= (1.0 - weight_damping * 0.9)
			
			var stability_factor = max(0, 1.0 - abs(stack_balance_factor) * 1.4)
			
			# Reduce centering force when settled to allow tilted position
			var centering_force_factor = 1.0
			if is_settled:
				centering_force_factor = 0.05  # Much less centering when settled
			
			var centering_force = -stack_balance_factor * auto_center_force * height_factor * stability_factor * 0.9 * centering_force_factor
			
			# Weight increases centering force (but still reduced when settled)
			centering_force *= (1.0 + stack_weight_above * 0.28)
			
			# Apply reduced forces when settled
			rb.apply_impulse(Vector2(centering_force + wobble_noise, 0) * delta * 80, Vector2.ZERO)
			
			if i > 0:
				var torque_damping = min(stack_weight_above * 0.28, 0.68)
				var torque_force = wobble_strength * 70 * delta * (1.0 - torque_damping) * settle_factor
				rb.apply_torque_impulse((randf() * 2 - 1) * torque_force)

# New function to check if stack has settled in position
func check_if_stack_settled(capy_index):
	if capys_stack.size() <= 1:
		return true
	
	var capy = capys_stack[capy_index]
	var rb = find_rigidbody(capy)
	if not rb:
		return true
	
	# Check if capy has low velocity (indicating it has settled)
	var velocity_threshold = 15.0
	var angular_velocity_threshold = 0.3
	
	var is_velocity_low = rb.linear_velocity.length() < velocity_threshold
	var is_angular_velocity_low = abs(rb.angular_velocity) < angular_velocity_threshold
	
	# Check if the stack has been in a tilted state for a while
	var imbalance = abs(stack_balance_factor)
	var has_significant_tilt = imbalance > 0.15
	
	# Consider it settled if it's been tilted and has low movement
	return has_significant_tilt and is_velocity_low and is_angular_velocity_low

func calculate_stack_balance():
	if capys_stack.size() <= 1:
		stack_balance_factor = 0.0
		return
	
	var stack_center_x = 0.0
	var total_weight = 0.0
	var sticky_stabilization = 0.0
	
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		if get_capy_type_name(capy) == "StickyCapy":
			sticky_stabilization += 0.3
		
		var weight = pow(2.5, i)
		stack_center_x += capy.position.x * weight
		total_weight += weight
	
	if total_weight > 0:
		stack_center_x /= total_weight
	
	var base_x = capys_stack[0].position.x
	var screen_width = get_viewport_rect().size.x
	var raw_balance = (stack_center_x - base_x) / (screen_width * 0.15)
	raw_balance *= (1.0 - min(sticky_stabilization, 0.8))
	
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

# Combined rigidbody setup function
func setup_rigidbody(rb, capy_type_name, is_dropping = false):
	var capy_data = capy_types[capy_type_name]
	
	rb.gravity_scale = capy_data.gravity_scale if is_dropping else 2.5
	rb.mass = capy_data.mass
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.contact_monitor = true
	rb.max_contacts_reported = 8
	rb.collision_layer = 1
	rb.collision_mask = 1
	
	if rb.physics_material_override == null:
		rb.physics_material_override = PhysicsMaterial.new()
	rb.physics_material_override.bounce = capy_data.bounce
	rb.physics_material_override.friction = capy_data.friction
	
	# Apply gentler physics for early stack positions
	if not is_dropping and capys_stack.size() <= 2:
		apply_gentle_early_physics(rb, capys_stack.size())

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
			# Gentler velocity reduction for early stack
			var velocity_reduction = 0.3 if capys_stack.size() > 2 else 0.6
			rb.linear_velocity *= velocity_reduction
			rb.angular_velocity *= velocity_reduction
			
			# Extra gentle settling for second capy
			if capys_stack.size() == 1:  # This will be the second capy
				rb.linear_velocity.y = min(rb.linear_velocity.y, 50)  # Cap downward velocity
				rb.apply_impulse(Vector2.ZERO, Vector2(0, -30))  # Small upward impulse to cushion
			
			# Gentler settling forces
			if capys_stack.size() > 0:
				var top_capy = capys_stack.back()
				var horizontal_offset = abs(current_capy.position.x - top_capy.position.x)
				var offset_factor = horizontal_offset / capy_height
				
				if offset_factor > 0.8:
					# Much gentler settling forces for early stack
					var settling_force = 80 if capys_stack.size() > 2 else 40
					rb.apply_impulse(Vector2.ZERO, Vector2(0, settling_force))
					var correction_direction = sign(top_capy.position.x - current_capy.position.x)
					var correction_force = 40 if capys_stack.size() > 2 else 20
					rb.apply_impulse(Vector2.ZERO, Vector2(correction_direction * correction_force, 0))
			
			call_deferred("_stabilize_capy", current_capy)
		
		# More lenient tipping thresholds for early stack
		if capys_stack.size() > 0:
			var top_capy = capys_stack.back()
			var horizontal_offset = abs(current_capy.position.x - top_capy.position.x)
			var offset_factor = horizontal_offset / capy_height
			
			var current_type = get_capy_type_name(current_capy)
			var below_type = get_capy_type_name(top_capy)
			var has_sticky = (current_type == "StickyCapy" or below_type == "StickyCapy")
			
			# Extra lenient for early stack to prevent immediate game over
			var early_stack_bonus = 0.4 if capys_stack.size() <= 2 else 0.0
			var immediate_tip_threshold = (1.2 if has_sticky else 0.9) + early_stack_bonus
			var delayed_tip_threshold = (1.0 if has_sticky else 0.7) + early_stack_bonus
			
			if offset_factor > immediate_tip_threshold:
				capys_stack.append(current_capy)
				stack_balance_factor = sign(current_capy.position.x - top_capy.position.x) * 0.9
				destabilize_stack()
				return
			elif offset_factor > delayed_tip_threshold and capys_stack.size() >= 3:
				capys_stack.append(current_capy)
				stack_balance_factor = sign(current_capy.position.x - top_capy.position.x) * 0.6
				imbalance_duration = 0.8
			else:
				capys_stack.append(current_capy)
		else:
			capys_stack.append(current_capy)
		
		# Only create joint if this isn't the base capy and we're not tipping
		if capys_stack.size() > 1 and not tipping_over:
			create_sticky_connection(capys_stack[capys_stack.size() - 2], current_capy)
		
		current_capy = null
		is_capy_dropping = false
		spawn_timer = 0.0
		
		if capys_stack.size() == 1:
			call_deferred("spawn_capy")
		
		calculate_stack_balance()
		
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
	var lower_rb = find_rigidbody(lower_capy)
	var upper_rb = find_rigidbody(upper_capy)
	
	if lower_rb and upper_rb:
		var lower_type = get_capy_type_name(lower_capy)
		var upper_type = get_capy_type_name(upper_capy)
		var has_sticky_capy = (lower_type == "StickyCapy" or upper_type == "StickyCapy")
		
		var horizontal_offset = abs(upper_rb.global_position.x - lower_rb.global_position.x)
		var offset_factor = horizontal_offset / capy_height
		
		# Calculate stack weight above this connection
		var stack_weight_above = calculate_stack_weight_above(capys_stack.size() - 1)
		
		# Better centered placement gets much stronger connection
		var center_bonus = max(0, 1.0 - offset_factor * 2.0)  # Strong bonus for centered placement
		
		# Only create weak connection if very off-center AND no stabilizing factors
		if offset_factor > 0.8 and stack_weight_above < 1.0 and not has_sticky_capy and center_bonus < 0.2:
			create_weak_connection(lower_rb, upper_rb)
		else:
			# Create stronger connection with center bonus
			create_multi_point_connection(lower_rb, upper_rb, has_sticky_capy, stack_weight_above, offset_factor, center_bonus)

func create_multi_point_connection(lower_rb, upper_rb, has_sticky_capy, stack_weight_above, offset_factor, center_bonus = 0.0):
	var connection_strength = calculate_connection_strength(has_sticky_capy, stack_weight_above, offset_factor, center_bonus)
	
	# Create main connection point - stronger for centered capys
	var main_joint = PinJoint2D.new()
	add_child(main_joint)
	main_joint.position = (lower_rb.global_position + upper_rb.global_position) / 2
	main_joint.node_a = lower_rb.get_path()
	main_joint.node_b = upper_rb.get_path()
	
	# Smoother joint settings to prevent twitching
	var base_softness = 0.7 - connection_strength * 0.3 - center_bonus * 0.2
	var base_bias = 0.1 + connection_strength * 0.2 + center_bonus * 0.15
	
	main_joint.softness = clamp(base_softness, 0.3, 0.9)
	main_joint.bias = clamp(base_bias, 0.05, 0.4)
	main_joint.disable_collision = false
	stack_joints.append(main_joint)
	
	# Only add stabilizing joints for very strong connections to avoid conflicts
	if (stack_weight_above > 1.5 or has_sticky_capy) and center_bonus > 0.6:
		create_stabilizing_joints(lower_rb, upper_rb, connection_strength, center_bonus)

func create_stabilizing_joints(lower_rb, upper_rb, strength, center_bonus = 0.0):
	var offset = capy_height * 0.25  # Reduced offset to prevent over-constraint
	var enhanced_strength = strength + center_bonus * 0.2  # Reduced bonus
	
	# Create only one additional joint to avoid over-constraining
	var side_joint = PinJoint2D.new()
	add_child(side_joint)
	
	# Offset to the side with less constraint conflict
	var side_offset = offset * (1 if randf() > 0.5 else -1)
	side_joint.position = Vector2((lower_rb.global_position.x + upper_rb.global_position.x) / 2 + side_offset, 
								  (lower_rb.global_position.y + upper_rb.global_position.y) / 2)
	side_joint.node_a = lower_rb.get_path()
	side_joint.node_b = upper_rb.get_path()
	
	# Much softer settings to prevent fighting with main joint
	var stab_softness = 0.85 - enhanced_strength * 0.15
	var stab_bias = 0.08 + enhanced_strength * 0.12
	
	side_joint.softness = clamp(stab_softness, 0.6, 0.95)
	side_joint.bias = clamp(stab_bias, 0.03, 0.25)
	side_joint.disable_collision = false
	stack_joints.append(side_joint)

func calculate_connection_strength(has_sticky_capy, stack_weight_above, offset_factor, center_bonus = 0.0):
	var base_strength = 0.2
	
	# Major bonus for centered placement
	base_strength += center_bonus * 0.6
	
	if has_sticky_capy:
		base_strength += 0.35
	
	# Weight adds significant strength
	base_strength += min(stack_weight_above * 0.2, 0.6)
	
	# Offset reduces strength, but less severely for well-centered capys
	var offset_penalty = offset_factor * (0.5 - center_bonus * 0.3)
	base_strength -= offset_penalty
	
	return clamp(base_strength, 0.1, 1.0)

func create_weak_connection(lower_rb, upper_rb):
	var joint = PinJoint2D.new()
	add_child(joint)
	joint.position = (lower_rb.global_position + upper_rb.global_position) / 2
	joint.node_a = lower_rb.get_path()
	joint.node_b = upper_rb.get_path()
	joint.softness = 0.98  # Slightly softer (was 0.95)
	joint.bias = 0.08      # Slightly less bias (was 0.1)
	joint.disable_collision = false
	stack_joints.append(joint)

# Add this new function
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
		
		rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		rb.freeze = false
		
		# Treat all capys the same - remove base capy special case
		var base_gravity = 0.5
		var weight_gravity_reduction = min(stack_weight_above * 0.08, 0.18)
		rb.gravity_scale = base_gravity - weight_gravity_reduction
		
		var normalized_height = float(stack_position) / max(1, capys_stack.size() - 1)
		var base_mass = 0.95 + (1.0 - normalized_height) * 0.75
		rb.mass = base_mass + stack_weight_above * 0.25
		
		var base_damp = 2.2
		var weight_damp_bonus = stack_weight_above * 0.45
		rb.linear_damp = base_damp + weight_damp_bonus
		rb.angular_damp = base_damp + weight_damp_bonus

func spawn_capy():
	if current_capy != null or is_capy_dropping:
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
		
		# StickyCapy special effects
		if capy_type_name == "StickyCapy":
			rb.body_entered.connect(_on_sticky_capy_contact.bind(capy_instance))
	
	current_capy = capy_instance

func get_capy_type_to_spawn():
	if base_capy_count < base_capy_count_threshold:
		return "BaseCapy"
	
	var choices = [
		{"type": "BaseCapy", "weight": 25},
		{"type": "BabyCapy", "weight": 20},
		{"type": "LargeCapy", "weight": 20},
		{"type": "SleepingCapy", "weight": 20},
		{"type": "StickyCapy", "weight": 20}
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

func _on_sticky_capy_contact(body, sticky_capy):
	if is_capy_dropping and current_capy == sticky_capy:
		var contact_capy = find_capy_owner(body)
		if contact_capy in capys_stack:
			var rb = find_rigidbody(sticky_capy)
			if rb:
				rb.linear_velocity *= 0.6
				rb.angular_velocity *= 0.4

func _draw():
	draw_line(Vector2(0, ground_level), Vector2(get_viewport_rect().size.x, ground_level), Color.WHITE, 2.0)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
