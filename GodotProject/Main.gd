extends Node2D

# Settings
export var capy_height := 60.0
export var spawn_delay := 1.0
export var ground_margin := 100.0
export var move_speed := 100.0
export var start_height := 300.0
export var max_horizontal_movement := 100.0
# Balance physics settings - MODIFIED FOR MORE REALISTIC PHYSICS
export var wobble_factor := 1.5  # Increased for more pronounced wobbling
export var center_sticky_range := 10.0  # Decreased from 15.0 - Much narrower sticky range
export var max_sticky_force := 30.0  # Decreased from 50.0 - Lower joint force
export var balance_threshold := 0.25  # Decreased from 0.4 - Much lower threshold for imbalance
export var auto_center_force := 1.0  # Decreased from 2.0 - Weaker auto-centering
export var wobble_frequency := 0.4  # Increased for more dynamic wobbling
export var wobble_amplitude := 1.5  # Increased for more dramatic movement
export var stack_elasticity := 0.35  # Increased for more elastic connections
export var edge_penalty := 2.0  # NEW: Penalty multiplier for off-center stacking
export var base_capy_count_threshold := 3  # How many BaseCapys before random spawning

# References
var current_capy = null
var spawn_timer := 0.0
var ground_level := 0.0
var moving_right := true
var capys_stack := []
var start_x_position := 0.0
var BaseCapy = preload("res://BaseCapy.tscn")
var BabyCapy = preload("res://BabyCapy.tscn")
var LargeCapy = preload("res://LargeCapy.tscn")
var SleepingCapy = preload("res://SleepingCapy.tscn")
var StickyCapy = preload("res://StickyCapy.tscn")
var is_capy_dropping := false
var ground_body = null  # Reference to the ground physics body
var wobble_time := 0.0  # Time accumulator for wobble effect
var stack_joints := []  # Store joints between capys
var stack_balance_factor := 0.0  # Current balance state of the stack (-1 to 1, 0 is balanced)
var stack_height := 0  # Current height of the stack
var tipping_over := false # Flag to check if stack is currently tipping
var off_center_timer := 0.0  # NEW: Timer to track how long stack is off-center
var imbalance_duration := 0.0  # NEW: How long the stack has been imbalanced
var base_capy_count := 0  # Track how many BaseCapys have been spawned

# Capybara type data for different behaviors
var capy_types := {
	"BaseCapy": {
		"scene": null,  # Will be set in _ready()
		"height": 60.0,
		"mass": 1.0,
		"bounce": 0.12,
		"friction": 4.0,
		"gravity_scale": 2.2
	},
	"BabyCapy": {
		"scene": null,  # Will be set in _ready()
		"height": 40.0,  # Smaller
		"mass": 0.6,     # Lighter
		"bounce": 0.18,  # More bouncy
		"friction": 3.0, # Less friction
		"gravity_scale": 1.8  # Falls slower
	},
	"LargeCapy": {
		"scene": null,  # Will be set in _ready()
		"height": 80.0,  # Bigger
		"mass": 2.0,     # Heavier
		"bounce": 0.08,  # Less bouncy
		"friction": 6.0, # More friction
		"gravity_scale": 2.8  # Falls faster
	},
	"SleepingCapy": {
		"scene": null,  # Will be set in _ready()
		"height": 65.0,  # Slightly wider
		"mass": 1.2,     # Bit heavier
		"bounce": 0.05,  # Very stable
		"friction": 8.0, # Very stable
		"gravity_scale": 2.0  # Falls normally
	}
}

#Camera
var target_camera_position = Vector2.ZERO
var camera_speed = 2.0  # Lower = smoother but slower camera
var first_frame_setup_done = false  # Flag to track initial camera setup

func _ready():
	randomize()
	ground_level = get_viewport_rect().size.y - ground_margin
	start_x_position = get_viewport_rect().size.x / 2
	
	# Set up capy type scenes
	capy_types["BaseCapy"]["scene"] = BaseCapy
	capy_types["BabyCapy"]["scene"] = BabyCapy
	capy_types["LargeCapy"]["scene"] = LargeCapy
	capy_types["SleepingCapy"]["scene"] = SleepingCapy
	
	# Create physical ground
	create_ground()
	
	# Place base capybara at center ground first
	place_base_capy()
	
	# Initialize camera to show the base capy and ground
	var camera = $Camera2D
	if camera:
		camera.position = Vector2(get_viewport_rect().size.x / 2, ground_level - get_viewport_rect().size.y * 0.4)

# Add function to place the base capybara at the center ground
func place_base_capy():
	var base_capy = BaseCapy.instance()
	add_child(base_capy)
	
	# Position it above the center of the ground - moved higher up for better visibility
	base_capy.position = Vector2(start_x_position, ground_level - capy_height * 10)
	
	# Set up physics for the base capy to drop naturally
	var rb = find_rigidbody(base_capy)
	if rb:
		rb.gravity_scale = 2.5  # Increased for faster dropping
		rb.mode = RigidBody2D.MODE_RIGID
		rb.bounce = 0.1
		rb.friction = 4.0  # Decreased for less stickiness
		rb.contact_monitor = true
		rb.contacts_reported = 8
		rb.collision_layer = 1
		rb.collision_mask = 1
		# Add slightly stronger initial velocity
		rb.linear_velocity = Vector2(0, 90)
	
	# Set as current dropping capy
	current_capy = base_capy
	is_capy_dropping = true

# Create a physical ground object
func create_ground():
	# Create a static body for the ground
	ground_body = StaticBody2D.new()
	ground_body.position = Vector2(get_viewport_rect().size.x / 2, ground_level + 10)
	ground_body.collision_layer = 1
	ground_body.collision_mask = 1
	add_child(ground_body)
	
	# Add collision shape
	var ground_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(get_viewport_rect().size.x / 2, 10)  # Width of screen, 20px height
	ground_shape.shape = shape
	ground_body.add_child(ground_shape)

# Check if the rigidbody is contacting ground or other capys
func is_contacting_something(rb):
	# Check the body's collision state
	for i in range(rb.get_colliding_bodies().size()):
		var contact_body = rb.get_colliding_bodies()[i]
		# If contacting ground or another capy
		if contact_body == ground_body:
			return true
		
		# Check if contacting another capy or capy part
		var potential_capy = find_capy_owner(contact_body)
		if potential_capy in capys_stack:
			return true
			
	# Check proximity to ground (backup method)
	if abs(rb.global_position.y - ground_level) < capy_height * 0.35:  # Reduced for tighter detection
		return true
		
	return false

# Helper function to find which capy owns a certain physics body
func find_capy_owner(body):
	# Start with the body itself
	var node = body
	
	# Traverse up the tree until we find a parent in our capys_stack
	while node != null:
		if node in capys_stack:
			return node
		node = node.get_parent()
		
	return null

# Get the height where new capys should spawn
func get_spawn_height():
	var base_height = start_height
	
	# If we have capys in the stack, spawn much higher above the highest one
	if capys_stack.size() > 0:
		var top_capy = capys_stack.back()
		var top_y = top_capy.position.y
		
		# Calculate a spawn height that increases with stack height
		var stack_factor = min(capys_stack.size() * 0.5, 3.0)  # Maximum 3x multiplier
		var spawn_distance = capy_height * (5 + stack_factor)
		
		# Spawn at a greater distance above the top capy as stack grows
		return min(top_y - spawn_distance, ground_level - capy_height * 15)
	
	return base_height

func _process(delta):
	
	update_camera(delta)
	
	wobble_time += delta
	
	if current_capy == null and not is_capy_dropping and not tipping_over:
		spawn_timer += delta
		if spawn_timer >= spawn_delay:
			spawn_capy()
			spawn_timer = 0.0
	
	# Handle horizontal movement
	if current_capy and not is_capy_dropping:
		# Drop capy when space pressed or screen touched
		if Input.is_action_just_pressed("ui_accept") or (OS.has_feature("mobile") and Input.get_touch_count() > 0):
			drop_current_capy()
			return
		
		# Horizontal movement logic
		var rb = find_rigidbody(current_capy)
		var direction = 1 if moving_right else -1
		
		if rb:
			# Apply horizontal velocity to the rigidbody
			rb.linear_velocity.x = move_speed * direction
		else:
			# Fallback to direct position manipulation if no rigidbody
			current_capy.position.x += move_speed * direction * delta
		
		# Change direction at boundaries
		if current_capy.position.x > start_x_position + max_horizontal_movement:
			moving_right = false
		elif current_capy.position.x < start_x_position - max_horizontal_movement:
			moving_right = true
	
	# Apply wobble effect to the stack based on balance
	if capys_stack.size() > 1:
		apply_stack_wobble(delta)
		check_stack_stability(delta)  # Pass delta to track time
		update()  # Force redraw for debug visualization

func update_camera(delta):
	var camera = $Camera2D
	if !camera:
		return
	
	var viewport_height = get_viewport_rect().size.y
	var viewport_width = get_viewport_rect().size.x
	
	# Special handling for initial frame when game starts
	if not first_frame_setup_done:
		# Position camera to show both ground and initial capybara clearly
		camera.position = Vector2(viewport_width / 2, ground_level - (viewport_height * 0.5))
		first_frame_setup_done = true
		return
	
	# 1. Find the highest point in the stack (lowest Y value)
	var highest_stack_point = ground_level
	var lowest_stack_point = ground_level
	
	# IMPROVED: Special handling for base capy when it's dropping
	if capys_stack.size() == 0 and current_capy and is_capy_dropping:
		# When base capy is dropping, make sure it's centered and clearly visible
		lowest_stack_point = ground_level
		highest_stack_point = current_capy.position.y - (capy_height)
		
		# Set target directly to show base capy clearly in the lower part of screen
		# Position camera to show the base capy in lower third of screen
		target_camera_position = Vector2(
			viewport_width / 2, 
			current_capy.position.y - (viewport_height * 0.3)
		)
		
		# Make sure ground is visible
		if target_camera_position.y > ground_level - (viewport_height * 0.4):
			target_camera_position.y = ground_level - (viewport_height * 0.4)
			
		# Fast camera movement for initial drop
		camera.position = camera.position.linear_interpolate(
			target_camera_position, 
			delta * camera_speed * 4  # Much faster for initial setup
		)
		return
	elif capys_stack.size() > 0:
		for capy in capys_stack:
			highest_stack_point = min(highest_stack_point, capy.position.y - (capy_height/2))
			lowest_stack_point = max(lowest_stack_point, capy.position.y + (capy_height/2))
	
	# 2. Calculate stack metrics
	var stack_height = lowest_stack_point - highest_stack_point
	
	# 3. Calculate camera position
	var target_y
	
	# NEW: Fixed camera for early game stages (1-4 capys)
	# This fixes the camera from shifting upward too early
	var MIN_CAPYS_FOR_DYNAMIC_CAMERA = 4  # Don't start dynamic camera until 4+ capys
	
	if capys_stack.size() < MIN_CAPYS_FOR_DYNAMIC_CAMERA:
		# Keep camera at a FIXED position relative to ground for early game stability
		target_y = ground_level - (viewport_height * 0.4)
		
		# Minor adjustment only for the spawning capy if it would go off-screen
		if current_capy and !is_capy_dropping:
			# Only adjust if capy would be off-screen
			if current_capy.position.y < camera.position.y - (viewport_height * 0.45):
				# Minimal adjustment - just enough to keep capy on screen
				var capy_screen_pos = current_capy.position.y - (viewport_height * 0.35)
				target_y = min(target_y, capy_screen_pos)
	else:
		# Original stack camera logic for when we have 4+ capys
		if current_capy and !is_capy_dropping:
			# Position spawned capy higher (15% from top)
			target_y = current_capy.position.y - (viewport_height * 0.15)
			
			# Ensure we can see enough of the stack below
			# 85% of viewport remains below the spawned capy
			var remaining_viewport = viewport_height * 0.85
			
			# Check if we need to move the camera down even more to show stack
			var distance_to_lowest = abs(current_capy.position.y - lowest_stack_point)
			
			# If the stack extends beyond what we can see, adjust camera down aggressively
			if distance_to_lowest > remaining_viewport * 0.8:
				# Move camera down to show more stack (keeping spawned capy just visible)
				target_y = current_capy.position.y - (viewport_height * 0.1)
		else:
			# When dropping or no current capy, focus even more on the stack
			# Position to show the full stack, heavily weighted toward base
			var weighted_midpoint = lowest_stack_point - (stack_height * 0.75)
			target_y = weighted_midpoint - (viewport_height * 0.6)
		
		# Ensure base capys are always well visible (40% from bottom of screen)
		var min_base_visibility = lowest_stack_point - (viewport_height * 0.6)
		target_y = max(target_y, min_base_visibility)
		
		# Ensure highest capy is at least minimally visible (5% from top)
		var max_top_visibility = highest_stack_point - (viewport_height * 0.05)
		target_y = min(target_y, max_top_visibility)
	
	# 4. Clamp to prevent going too low (always show ground)
	target_y = min(target_y, ground_level - (viewport_height * 0.5))
	
	# 5. Keep X centered
	target_camera_position = Vector2(viewport_width / 2, target_y)
	
	# 6. Adaptive camera speed based on game state
	var adaptive_speed = camera_speed
	
	# Much slower camera movement during early game
	if capys_stack.size() < MIN_CAPYS_FOR_DYNAMIC_CAMERA:
		adaptive_speed *= 0.4  # Very slow camera movement in early game
	else:
		# Original dynamic speed calculation
		var distance = (target_camera_position - camera.position).length()
		adaptive_speed *= (1 + (distance / 300))
	
	# 7. Apply camera movement
	camera.position = camera.position.linear_interpolate(
		target_camera_position, 
		delta * adaptive_speed
	)

# IMPROVED: Check if stack is becoming unstable
func check_stack_stability(delta):
	# If stack is already marked as tipping, no need to check again
	if tipping_over:
		return
	
	# Calculate imbalance
	var imbalance = abs(stack_balance_factor)
	
	# If stack is imbalanced, accumulate time
	if imbalance > balance_threshold:
		imbalance_duration += delta
		
		# Calculate tip probability based on:
		# 1. How imbalanced the stack is
		# 2. How long it's been imbalanced
		# 3. Height of the stack
		
		var tip_chance = (imbalance - balance_threshold) * 5  # Base chance from imbalance
		tip_chance *= sqrt(capys_stack.size()) * 0.4  # Increase with height
		tip_chance *= min(imbalance_duration, 3.0) * 0.5  # Increase with time imbalanced
		
		# Edge case: Force tipping if extremely unbalanced
		if imbalance > 0.65 or (imbalance > 0.5 and capys_stack.size() >= 3):
			tip_chance = 100  # Guarantee tipping
		
		# Debug visualization of tip chance
		print("Imbalance: ", imbalance, " Tip chance: ", tip_chance * 0.1, "%")
		
		# Roll for tipping
		if randf() < tip_chance * 0.01:
			destabilize_stack()
	else:
		# Reset imbalance timer if balanced
		imbalance_duration = max(0, imbalance_duration - delta * 2)  # Recover stability slowly

# Function to make the stack tip over when extremely unbalanced
func destabilize_stack():
	tipping_over = true
	print("STACK TIPPING OVER!")
	
	# Get tipping direction (which way the stack is leaning)
	var tip_direction = sign(stack_balance_factor)
	
	# Detach all joints first for visual dramatic effect of falling over
	for joint in stack_joints:
		if joint and is_instance_valid(joint):
			joint.queue_free()
	
	# Apply impulses to make stack tip over realistically
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb:
			# Make all capys dynamic again
			rb.mode = RigidBody2D.MODE_RIGID
			rb.gravity_scale = 1.3  # Increased gravity during toppling
			
			# Higher capys get stronger sideways impulse
			var height_factor = float(i) / max(1, capys_stack.size() - 1)
			var impulse_strength = 70.0 * height_factor
			
			# Apply directional impulse based on imbalance
			var random_factor = randf() * 0.4 + 0.8  # 0.8 to 1.2
			rb.apply_impulse(Vector2.ZERO, Vector2(tip_direction * impulse_strength * random_factor, 
											   -impulse_strength * 0.3 * random_factor))
			
			# Add some rotation to enhance the "toppling" effect
			rb.apply_torque_impulse(tip_direction * 500 * height_factor * random_factor)
	
	# Set a timer to reset the game after tipping is complete
	var timer = Timer.new()
	timer.wait_time = 4.0  # Longer time to allow player to see the collapse
	timer.one_shot = true
	add_child(timer)
	timer.connect("timeout", self, "_on_reset_timer_timeout")
	timer.start()

# Reset the game after stack tips over
func _on_reset_timer_timeout():
	get_tree().reload_current_scene()

# IMPROVED: Apply wobble effect to the capybara stack
func apply_stack_wobble(delta):
	# Calculate the current balance factor of the stack
	calculate_stack_balance()
	
	# Apply forces based on stack balance
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		var rb = find_rigidbody(capy)
		if rb and rb.mode == RigidBody2D.MODE_RIGID:
			# The higher up in the stack, the more effect
			var height_factor = float(i) / max(1, capys_stack.size() - 1)
			
			# Calculate wobble force based on balance and height
			var wobble_strength = wobble_factor * abs(stack_balance_factor) * height_factor
			
			# Small random wobble effect that increases with height
			var wobble_noise = sin(wobble_time * wobble_frequency * (i + 1)) * wobble_amplitude * height_factor
			
			# Add random variation for more natural movement
			wobble_noise += (randf() * 2 - 1) * height_factor * 0.5
			
			# Auto-centering force when unbalanced
			# Make centering force weaker the more unbalanced to allow tipping
			var stability_factor = max(0, 1.0 - abs(stack_balance_factor) * 1.5)  # Weaker stability
			var centering_force = -stack_balance_factor * auto_center_force * height_factor * stability_factor
			
			# Apply forces - increased overall effect
			rb.apply_impulse(Vector2.ZERO, Vector2(centering_force + wobble_noise, 0) * delta * 70)
			
			# Apply random rotational impulse for more natural movement
			if i > 0: # Don't rotate the base capy
				rb.apply_torque_impulse((randf() * 2 - 1) * wobble_strength * 60 * delta)

# IMPROVED: Calculate the current balance factor of the stack
func calculate_stack_balance():
	if capys_stack.size() <= 1:
		stack_balance_factor = 0.0
		return
	
	var stack_center_x = 0.0
	var total_weight = 0.0
	
	# Calculate weighted center of mass
	for i in range(capys_stack.size()):
		var capy = capys_stack[i]
		var weight = pow(2.5, i)  # Increased from 2.0 - Higher capys have MUCH more impact on balance
		stack_center_x += capy.position.x * weight
		total_weight += weight
	
	if total_weight > 0:
		stack_center_x /= total_weight
	
	# Calculate how far the stack's center is from the base
	var base_x = capys_stack[0].position.x
	var screen_width = get_viewport_rect().size.x
	
	# Normalize the balance factor between -1 and 1
	# -1 means leaning far left, 0 means balanced, 1 means leaning far right
	# Made more sensitive by using a smaller divisor (0.15 instead of 0.2)
	stack_balance_factor = clamp((stack_center_x - base_x) / (screen_width * 0.15), -1, 1)
	
	# Update the stack height for game logic
	stack_height = capys_stack.size()

func drop_current_capy():
	is_capy_dropping = true
	
	# Get capy type and apply dropping physics
	var capy_type_name = get_capy_type_name(current_capy)
	var capy_data = capy_types[capy_type_name]
	
	var rb = find_rigidbody(current_capy)
	if rb:
		# Apply type-specific gravity and physics
		rb.gravity_scale = capy_data.gravity_scale
		rb.mass = capy_data.mass
		rb.bounce = capy_data.bounce
		rb.friction = capy_data.friction
		
		# Initial drop velocity (adjusted by type)
		var base_velocity = 170
		if capy_type_name == "BabyCapy":
			base_velocity = 140  # Lighter, falls slower
		elif capy_type_name == "LargeCapy":
			base_velocity = 200  # Heavier, falls faster
			
		rb.linear_velocity = Vector2(0, base_velocity)
		rb.contact_monitor = true
		rb.contacts_reported = 8
		rb.collision_layer = 1
		rb.collision_mask = 1

func find_rigidbody(node):
	if node is RigidBody2D:
		return node
	
	for child in node.get_children():
		if child is RigidBody2D:
			return child
	
	return null

func _physics_process(delta):
	if current_capy and is_capy_dropping:
		var landed = false
		var rb = find_rigidbody(current_capy)
		
		# Debug printing when no RigidBody is found
		if not rb:
			print("Warning: No RigidBody found for current_capy")
			is_capy_dropping = false
			current_capy = null
			# Try to spawn a new capy
			spawn_timer = spawn_delay
			return
			
		# Check for ground collision
		if current_capy.position.y >= ground_level - capy_height/2:
			print("Ground collision detected")
			landed = true
		
		# Check for stack collision using physics contacts
		if not landed and rb and capys_stack.size() > 0:
			var colliding_bodies = rb.get_colliding_bodies()
			for i in range(colliding_bodies.size()):
				var contact_body = colliding_bodies[i]
				# Skip null contacts
				if not contact_body:
					continue
					
				var potential_capy = find_capy_owner(contact_body)
				if potential_capy in capys_stack:
					print("Stack collision detected")
					landed = true
					break
		
		# Check if almost stopped and near another capy
		if not landed and rb and rb.linear_velocity.length() < 20 and is_near_stack(current_capy):
			print("Capy nearly stopped near stack")
			landed = true
		
		# Extra check for base capy landing on ground
		if capys_stack.size() == 0 and rb and is_contacting_something(rb):
			print("Base capy landed")
			landed = true
		
		if landed and rb:
			print("Finalizing capy placement")
			finalize_capy_placement()

# Check if capy is near the existing stack
func is_near_stack(capy):
	if capys_stack.size() == 0:
		return false
		
	var top_capy = capys_stack.back()
	var distance = (capy.position - top_capy.position).length()
	
	return distance < capy_height * 1.5

# IMPROVED: Finalize capy placement with better physics
func finalize_capy_placement():
	if current_capy:
		var rb = find_rigidbody(current_capy)
		if rb:
			# First adjust velocity for a more natural landing
			rb.linear_velocity *= 0.5
			rb.angular_velocity *= 0.5
			
			# Apply gradual transition to static
			call_deferred("_stabilize_capy", current_capy)
		
		# Check if placement is very off-center before accepting
		var off_center_factor = 0.0
		
		if capys_stack.size() > 0:
			var top_capy = capys_stack.back()
			var horizontal_offset = abs(current_capy.position.x - top_capy.position.x)
			off_center_factor = horizontal_offset / capy_height
			
			# NEW: If extremely off-center (more than 80% of capy width),
			# immediately trigger destabilization
			if off_center_factor > 0.8 and capys_stack.size() >= 2:
				# Calculate which direction it's off-center
				var direction = sign(current_capy.position.x - top_capy.position.x)
				
				# Add to stack temporarily
				capys_stack.append(current_capy)
				
				# Force balance calculation with the new capy
				stack_balance_factor = direction * 0.8  # Force significant imbalance
				
				# Trigger destabilization
				destabilize_stack()
				return
		
		# Add to stack
		capys_stack.append(current_capy)
		
		# Create joints to connect to previous capy for stickiness
		if capys_stack.size() > 1:
			create_sticky_connection(capys_stack[capys_stack.size() - 2], current_capy)
		
		current_capy = null
		is_capy_dropping = false
		spawn_timer = 0.0
		
		# If this was the first capybara (base), spawn the first player-controlled one immediately
		if capys_stack.size() == 1:
			call_deferred("spawn_capy")  # Use call_deferred to avoid physics issues
		
		# Recalculate the stack balance
		calculate_stack_balance()

# IMPROVED: Create a joint connection between two capybaras for stickiness
func create_sticky_connection(lower_capy, upper_capy):
	var lower_rb = find_rigidbody(lower_capy)
	var upper_rb = find_rigidbody(upper_capy)
	
	if lower_rb and upper_rb:
		# Calculate horizontal offset between capys - key for edge stacking
		var horizontal_offset = abs(upper_rb.global_position.x - lower_rb.global_position.x)
		
		# Calculate offset as a factor of capy width
		var offset_factor = horizontal_offset / capy_height
		
		# Create pin joint (acts like glue)
		var joint = PinJoint2D.new()
		add_child(joint)
		
		# Position the joint between the two capys
		joint.position = (lower_rb.global_position + upper_rb.global_position) / 2
		
		# Connect the joint to both bodies
		joint.node_a = lower_rb.get_path()
		joint.node_b = upper_rb.get_path()
		
		# Calculate stickiness (much reduced for off-center placements)
		var stickiness = 1.0 - clamp(horizontal_offset / center_sticky_range, 0, 0.95)
		
		# Apply edge penalty for off-center connections
		if offset_factor > 0.5:
			stickiness *= (1.0 - ((offset_factor - 0.5) * edge_penalty))
		
		# Calculate dynamic joint softness - MUCH higher elasticity based on offset
		var height_factor = float(capys_stack.size()) / 8.0
		var offset_softness = offset_factor * stack_elasticity * 2.0  # Major impact from offset
		var base_softness = 0.3 + (1.0 - stickiness) * stack_elasticity + offset_softness
		var dynamic_softness = base_softness + height_factor
		
		# Configure joint properties - much more elastic for off-center connections
		joint.softness = clamp(dynamic_softness, 0.3, 0.95)
		joint.bias = max(0.2, 0.3 - offset_factor * 0.2)  # Lower bias (stability) for off-center
		joint.disable_collision = false
		
		# Store the joint reference
		stack_joints.append(joint)
		
		# Debug output
		print("Joint created with softness: ", joint.softness, " (offset: ", offset_factor, ")")

# IMPROVED: Helper function to make transition to static smooth
func _stabilize_capy(capy):
	var rb = find_rigidbody(capy)
	if rb:
		# Find position in stack
		var stack_position = capys_stack.find(capy)
		
		# Special handling for base capy
		if stack_position == 0:
			# Make base capy NOT fully static, but very stable
			rb.mode = RigidBody2D.MODE_RIGID
			rb.gravity_scale = 0.5  # Some gravity to keep it grounded
			rb.mass = 5.0  # Much heavier base
			rb.linear_damp = 10.0  # Strong damping for stability
			rb.angular_damp = 10.0  # Prevent rotation
		else:
			# All other capys remain dynamic with reduced gravity
			rb.mode = RigidBody2D.MODE_RIGID
			rb.gravity_scale = 0.45
			
			# Dynamic mass based on position in stack
			var normalized_height = float(stack_position) / max(1, capys_stack.size() - 1)
			
			# Higher capys have less mass to be more affected by physics
			rb.mass = 1.0 + (1.0 - normalized_height) * 0.8
			
			# Less damping for more natural movement
			rb.linear_damp = 2.5
			rb.angular_damp = 2.5

func spawn_capy():
	print("Spawning new capy")
	
	# Safety check to make sure we're not spawning multiple capys
	if current_capy != null:
		print("Warning: Attempting to spawn new capy while current_capy exists")
		return
		
	if is_capy_dropping:
		print("Warning: Attempting to spawn new capy while another is dropping")
		return
	
	# Get capy type to spawn
	var capy_type_name = get_capy_type_to_spawn()
	var capy_scene = capy_types[capy_type_name]["scene"]
	
	# Track BaseCapy count
	if capy_type_name == "BaseCapy":
		base_capy_count += 1
	
	var capy_instance = capy_scene.instance()
	add_child(capy_instance)
	
	# Set position and initial direction
	var spawn_height = get_spawn_height()
	capy_instance.position = Vector2(start_x_position, spawn_height)
	moving_right = randi() % 2 == 0
	
	# Apply type-specific physics
	apply_capy_physics(capy_instance, capy_type_name)
	
	var rb = find_rigidbody(capy_instance)
	if rb:
		rb.gravity_scale = 0.0  # No gravity while moving horizontally
		rb.mode = RigidBody2D.MODE_RIGID
		rb.linear_damp = 0.25
		rb.angular_damp = 4.5
		
		# Apply initial velocity
		rb.linear_velocity = Vector2(move_speed * (1 if moving_right else -1), 0)
	else:
		print("Error: No RigidBody found in new capy")
	
	current_capy = capy_instance
	print("New ", capy_type_name, " spawned successfully")
	
# Get the appropriate capybara type to spawn
func get_capy_type_to_spawn():
	# Always spawn BaseCapy for the first base_capy_count_threshold capybaras
	if base_capy_count < base_capy_count_threshold:
		return "BaseCapy"
	
	# After threshold, randomly choose from all types with weights
	var capy_choices = [
		{"type": "BaseCapy", "weight": 30},    # Still common
		{"type": "BabyCapy", "weight": 25},    # Light and bouncy
		{"type": "LargeCapy", "weight": 20},   # Heavy and stable
		{"type": "SleepingCapy", "weight": 25} # Very stable
	]
	
	# Calculate total weight
	var total_weight = 0
	for choice in capy_choices:
		total_weight += choice.weight
	
	# Random selection based on weights
	var rand_val = randi() % total_weight
	var current_weight = 0
	
	for choice in capy_choices:
		current_weight += choice.weight
		if rand_val < current_weight:
			return choice.type
	
	return "BaseCapy"  # Fallback

# Get capybara type from instance
func get_capy_type_name(capy_instance):
	var scene_path = capy_instance.filename
	if scene_path.ends_with("BabyCapy.tscn"):
		return "BabyCapy"
	elif scene_path.ends_with("LargeCapy.tscn"):
		return "LargeCapy"
	elif scene_path.ends_with("SleepingCapy.tscn"):
		return "SleepingCapy"
	else:
		return "BaseCapy"

# Apply physics properties based on capybara type
func apply_capy_physics(capy_instance, capy_type_name):
	var rb = find_rigidbody(capy_instance)
	if not rb:
		return
	
	var capy_data = capy_types[capy_type_name]
	
	# Apply type-specific physics
	rb.mass = capy_data.mass
	rb.bounce = capy_data.bounce
	rb.friction = capy_data.friction
	rb.gravity_scale = capy_data.gravity_scale
	
	# Configure common properties
	rb.contact_monitor = true
	rb.contacts_reported = 8
	rb.collision_layer = 1
	rb.collision_mask = 1	
	
# IMPROVED: Debug visualization
func _draw():
	
	# Draw ground line
	draw_line(Vector2(0, ground_level), Vector2(get_viewport_rect().size.x, ground_level), Color.white, 2.0)
	

func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_R:
		get_tree().reload_current_scene()
