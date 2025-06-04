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
	if tipping_over:
		return
	
	# Count StickyCapys for stability bonus
	var sticky_count = 0
	for capy in capys_stack:
		if get_capy_type_name(capy) == "StickyCapy":
			sticky_count += 1
	
	# Calculate effective threshold with StickyCapy bonus
	var effective_threshold = balance_threshold + (sticky_count * 0.4)
	effective_threshold = min(effective_threshold, 0.9)
	
	var imbalance = abs(stack_balance_factor)
	
	if imbalance > effective_threshold:
		imbalance_duration += delta
		var tip_chance = (imbalance - effective_threshold) * 5
		tip_chance *= sqrt(capys_stack.size()) * 0.4
		tip_chance *= min(imbalance_duration, 3.0) * 0.5
		
		# StickyCapy resistance
		if sticky_count > 0:
			var resistance_factor = max(0.1, 1.0 - (sticky_count * 0.6))
			tip_chance *= resistance_factor
		
		# Force tipping thresholds
		var extreme_threshold = 0.95 if sticky_count > 0 else 0.65
		var severe_threshold = 0.85 if sticky_count > 0 else 0.5
		
		if imbalance > extreme_threshold or (imbalance > severe_threshold and capys_stack.size() >= 3 and sticky_count == 0):
			tip_chance = 100
		
		if randf() < tip_chance * 0.01:
			destabilize_stack()
	else:
		imbalance_duration = max(0, imbalance_duration - delta * 2)

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
			var wobble_strength = wobble_factor * abs(stack_balance_factor) * height_factor
			var wobble_noise = sin(wobble_time * wobble_frequency * (i + 1)) * wobble_amplitude * height_factor
			wobble_noise += (randf() * 2 - 1) * height_factor * 0.5
			
			var stability_factor = max(0, 1.0 - abs(stack_balance_factor) * 1.5)
			var centering_force = -stack_balance_factor * auto_center_force * height_factor * stability_factor
			
			rb.apply_impulse(Vector2(centering_force + wobble_noise, 0) * delta * 70, Vector2.ZERO)
			
			if i > 0:
				rb.apply_torque_impulse((randf() * 2 - 1) * wobble_strength * 60 * delta)

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
		
		var base_velocity = {"BabyCapy": 140, "LargeCapy": 200}.get(capy_type_name, 170)
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
			rb.linear_velocity *= 0.5
			rb.angular_velocity *= 0.5
			call_deferred("_stabilize_capy", current_capy)
		
		# Check extreme off-center placement
		if capys_stack.size() > 0:
			var top_capy = capys_stack.back()
			var horizontal_offset = abs(current_capy.position.x - top_capy.position.x)
			var off_center_factor = horizontal_offset / capy_height
			
			var current_type = get_capy_type_name(current_capy)
			var below_type = get_capy_type_name(top_capy)
			var has_sticky = (current_type == "StickyCapy" or below_type == "StickyCapy")
			
			var tip_threshold = 1.3 if has_sticky else 0.8
			
			if off_center_factor > tip_threshold and capys_stack.size() >= 2:
				capys_stack.append(current_capy)
				stack_balance_factor = sign(current_capy.position.x - top_capy.position.x) * 0.8
				destabilize_stack()
				return
		
		capys_stack.append(current_capy)
		
		if capys_stack.size() > 1:
			create_sticky_connection(capys_stack[capys_stack.size() - 2], current_capy)
		
		current_capy = null
		is_capy_dropping = false
		spawn_timer = 0.0
		
		if capys_stack.size() == 1:
			call_deferred("spawn_capy")
		
		calculate_stack_balance()

func create_sticky_connection(lower_capy, upper_capy):
	var lower_rb = find_rigidbody(lower_capy)
	var upper_rb = find_rigidbody(upper_capy)
	
	if lower_rb and upper_rb:
		var lower_type = get_capy_type_name(lower_capy)
		var upper_type = get_capy_type_name(upper_capy)
		var has_sticky_capy = (lower_type == "StickyCapy" or upper_type == "StickyCapy")
		
		var horizontal_offset = abs(upper_rb.global_position.x - lower_rb.global_position.x)
		var offset_factor = horizontal_offset / capy_height
		
		# Enhanced properties for StickyCapy
		var effective_sticky_range = capy_types["StickyCapy"]["sticky_range"] if has_sticky_capy else center_sticky_range
		var sticky_multiplier = capy_types["StickyCapy"]["sticky_strength"] if has_sticky_capy else 1.0
		
		var joint = PinJoint2D.new()
		add_child(joint)
		joint.position = (lower_rb.global_position + upper_rb.global_position) / 2
		joint.node_a = lower_rb.get_path()
		joint.node_b = upper_rb.get_path()
		
		# Calculate stickiness
		var base_stickiness = 1.0 - clamp(horizontal_offset / effective_sticky_range, 0, 0.95)
		var stickiness = base_stickiness * sticky_multiplier
		
		# Edge penalty reduction for StickyCapy
		var edge_penalty_factor = edge_penalty * (0.1 if has_sticky_capy else 1.0)
		if has_sticky_capy:
			stickiness = max(stickiness, 0.7)
		
		if offset_factor > 0.5:
			stickiness *= (1.0 - ((offset_factor - 0.5) * edge_penalty_factor))
		
		# Joint configuration
		var height_factor = float(capys_stack.size()) / 8.0
		var offset_softness = offset_factor * stack_elasticity * (0.2 if has_sticky_capy else 1.0)
		var base_softness = 0.3 + (1.0 - stickiness) * stack_elasticity + offset_softness
		var dynamic_softness = (base_softness + height_factor) * (0.4 if has_sticky_capy else 1.0)
		
		joint.softness = clamp(dynamic_softness, 0.05, 0.95)
		joint.bias = max(0.6 if has_sticky_capy else 0.2, 0.3 - offset_factor * 0.1)
		joint.disable_collision = false
		
		stack_joints.append(joint)

func _stabilize_capy(capy):
	var rb = find_rigidbody(capy)
	if rb:
		var stack_position = capys_stack.find(capy)
		
		rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		rb.freeze = false
		
		if stack_position == 0:
			# Base capy - more stable
			rb.gravity_scale = 0.5
			rb.mass = 5.0
			rb.linear_damp = 10.0
			rb.angular_damp = 10.0
		else:
			# Stack capys
			rb.gravity_scale = 0.45
			var normalized_height = float(stack_position) / max(1, capys_stack.size() - 1)
			rb.mass = 1.0 + (1.0 - normalized_height) * 0.8
			rb.linear_damp = 2.5
			rb.angular_damp = 2.5

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
