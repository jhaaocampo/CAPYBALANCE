extends Node2D

# Export variables for easy tweaking in the editor
@export var spawn_area_width := 800  # Increased for more spread
@export var spawn_interval := 1.5  # Increased for less frequent spawning
@export var asset_move_speed := 30.0
@export var cleanup_distance := 1000.0
@export var spawn_distance := 600.0
@export var min_asset_distance := 100.0  # Increased minimum distance between assets
@export var desired_asset_density := 10  # Reduced from 30 to 15 for less clutter
@export var initial_spawn_density := 15  # Even less for initial spawn
@export var camera_clear_radius := 300.0  # Clear area around camera for gameplay focus

# Camera reference - we'll find it automatically
@onready var camera: Camera2D

# Asset textures array - removed yellow star
var textures = []
var spawn_timer := 3.0
var last_spawn_y := 0.0

# Animation properties
var time_passed := 0.0

func _ready():
	# Find the camera automatically
	camera = get_tree().get_first_node_in_group("camera")
	if not camera:
		# Fallback: search for any Camera2D in the scene
		camera = get_tree().current_scene.find_child("Camera2D", true, false)
	
	if not camera:
		push_error("Camera2D not found! Make sure you have a Camera2D in your scene.")
		return
	
	print("Camera found: ", camera.name)
	
	# IMPORTANT: Clear any existing assets first before loading new textures
	clear_all_assets()
	
	# Load all your background asset textures (yellow star completely removed)
	textures = [
		preload("res://silver star.png"),
		preload("res://blue star.png"),
		preload("res://purple star.png"),
		preload("res://comet.png"),
		preload("res://moon.png"),
		preload("res://space ship.png"),
	]
	
	print("Loaded ", textures.size(), " textures")
	
	# Double-check that we're only using the textures we want
	for i in range(textures.size()):
		print("Texture ", i, ": ", textures[i].resource_path)
	
	# Initialize spawn position
	last_spawn_y = camera.global_position.y
	print("Initial camera position: ", camera.global_position)
	
	# Wait a frame to ensure cleanup is complete, then spawn initial assets
	await get_tree().process_frame
	spawn_initial_assets()

func _process(delta):
	if not camera:
		return
	
	# Update time for animations
	time_passed += delta
	
	# Update spawn timer
	spawn_timer -= delta
	
	# Get viewport size for proper spawning
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Continuously spawn assets to maintain density around camera
	spawn_timer -= delta
	if spawn_timer <= 0:
		maintain_asset_density(viewport_size)
		spawn_timer = spawn_interval
	
	# Animate all assets
	animate_assets(delta)
	
	# Clean up assets that are too far below the camera
	cleanup_assets()

func clear_all_assets():
	# Remove all existing sprite assets immediately
	for child in get_children():
		if child is Sprite2D:
			child.free()  # Use free() instead of queue_free() for immediate removal
	
	# Force a scene tree update
	if get_tree():
		get_tree().call_group("background_assets", "queue_free")

# Modified initial spawning for less clutter and better focus
func spawn_initial_assets():
	# Get camera viewport size to spawn within visible area
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_pos = camera.global_position
	var spawn_radius = max(viewport_size.x, viewport_size.y) * .8  # Slightly reduced radius
	
	print("Camera position: ", camera_pos)
	print("Viewport size: ", viewport_size)
	print("Spawning initial assets in radius: ", spawn_radius)
	
	# Use reduced initial density for cleaner look
	var target_spawns = initial_spawn_density
	var attempts = 0
	var spawned = 0
	var max_attempts = target_spawns * 4  # Reasonable attempt limit
	
	while spawned < target_spawns and attempts < max_attempts:
		attempts += 1
		
		# Generate random position around camera, but not too close
		var angle = randf() * TAU
		var distance = randf_range(camera_clear_radius, spawn_radius)  # Keep clear area around camera
		var spawn_pos = camera_pos + Vector2(cos(angle) * distance, sin(angle) * distance)
		
		# Prefer spawning assets more towards the edges and less in center
		var center_bias = distance / spawn_radius  # 0 = center, 1 = edge
		if randf() > (center_bias * 0.7 + 0.3):  # Bias towards outer areas
			continue
		
		# Check if position is valid (not too close to other assets or camera focus area)
		if is_position_valid_for_spawning(spawn_pos) and not is_in_camera_focus_area(spawn_pos):
			create_asset_at_position(spawn_pos)
			spawned += 1
	
	print("Spawned ", spawned, " initial assets in ", attempts, " attempts")

# Check if position is in the camera's focus area (where gameplay happens)
func is_in_camera_focus_area(pos: Vector2) -> bool:
	var camera_pos = camera.global_position
	var distance_to_camera = camera_pos.distance_to(pos)
	return distance_to_camera < camera_clear_radius

func create_asset_at_position(spawn_position: Vector2):
	# Create a new sprite with random texture
	var texture = textures[randi() % textures.size()]
	var sprite = Sprite2D.new()
	sprite.texture = texture
	
	# Add to a group for easier management
	sprite.add_to_group("background_assets")
	
	# Add to scene first
	add_child(sprite)
	
	# Set exact position
	sprite.global_position = spawn_position
	
	# IMPORTANT: Set z-index to render properly (further back for less distraction)
	sprite.z_index = -2  # Further behind to be less distracting
	
	# Reduce scale and alpha for more subtle background presence
	var base_scale = randf_range(0.3, 1.2)  # Smaller overall
	var base_alpha = randf_range(0.4, 0.8)  # More transparent for subtlety
	
	sprite.scale = Vector2(base_scale, base_scale)
	sprite.modulate.a = base_alpha
	
	# Set initial rotation for rotating objects
	sprite.rotation = randf_range(0, TAU)
	
	# Add some random tint for variety but keep it subtle
	if randf() < 0.2:  # Reduced chance for colored tint
		sprite.modulate = Color(
			randf_range(0.8, 1.0),  # Less dramatic color variation
			randf_range(0.8, 1.0), 
			randf_range(0.8, 1.0),
			base_alpha
		)
	
	# ALWAYS store animation data - this ensures ALL sprites get animated
	var texture_name = texture.resource_path.get_file().to_lower()
	sprite.set_meta("original_scale_x", base_scale)
	sprite.set_meta("original_scale_y", base_scale)
	sprite.set_meta("original_alpha", base_alpha)
	sprite.set_meta("animation_offset", randf() * TAU)
	sprite.set_meta("base_rotation", sprite.rotation)
	sprite.set_meta("texture_name", texture_name)
	sprite.set_meta("is_animated_asset", true)  # Flag to identify our assets
	
	# Debug: Print what we're creating
	print("Created asset: ", texture_name, " at: ", sprite.global_position, " with scale: ", base_scale)

func animate_assets(delta):
	var total_children = 0
	var assets_found = 0
	var assets_animated = 0
	
	for child in get_children():
		total_children += 1
		
		# Only animate Sprite2D nodes that are our background assets
		if not child is Sprite2D:
			continue
		
		# Check if this is one of our animated assets
		if not child.has_meta("is_animated_asset"):
			continue
			
		assets_found += 1
		
		# Get stored animation data - all our assets should have this
		var texture_name = child.get_meta("texture_name", "unknown")
		var animation_offset = child.get_meta("animation_offset", 0.0)
		var original_scale_x = child.get_meta("original_scale_x", 1.0)
		var original_scale_y = child.get_meta("original_scale_y", 1.0)
		var original_alpha = child.get_meta("original_alpha", 1.0)
		var base_rotation = child.get_meta("base_rotation", 0.0)
		
		# More subtle drift movement to be less distracting
		var drift_x = sin(time_passed * 0.3 + child.position.y * 0.001 + animation_offset) * 8 * delta  # Reduced intensity
		var drift_y = sin(time_passed * 0.2 + child.position.x * 0.001 + animation_offset) * 3 * delta  # Reduced intensity
		
		child.position.x += drift_x
		child.position.y += drift_y
		
		# Apply specific animations based on asset type (more subtle)
		if texture_name.contains("star") or texture_name.contains("comet"):
			# Gentler pulsing scale animation for stars and comets
			var pulse_factor = 1.0 + sin(time_passed * 1.5 + animation_offset) * 0.15  # Reduced intensity
			child.scale.x = original_scale_x * pulse_factor
			child.scale.y = original_scale_y * pulse_factor
			
			# Subtle alpha pulsing for stars
			if texture_name.contains("star"):
				var alpha_pulse = 1.0 + sin(time_passed * 1.2 + animation_offset) * 0.2  # Reduced intensity
				child.modulate.a = original_alpha * clamp(alpha_pulse, 0.4, 1.0)
		
		elif texture_name.contains("space") or texture_name.contains("moon"):
			# Slower rotating animation for spaceships and moons
			child.rotation = base_rotation + (time_passed * 0.3)  # Slower rotation
		
		assets_animated += 1
	
	# Debug: Print animation info every 5 seconds (less frequent)
	if int(time_passed) % 5 == 0 and fmod(time_passed, 1.0) < delta:
		print("Animation Debug - Total children: ", total_children, " | Assets found: ", assets_found, " | Assets animated: ", assets_animated, " | Time: ", "%.1f" % time_passed)

# Modified to maintain lower density and respect camera focus area
func maintain_asset_density(viewport_size: Vector2):
	var camera_pos = camera.global_position
	var spawn_radius = max(viewport_size.x, viewport_size.y) * 1.5
	
	# Count current assets around camera
	var assets_in_area = count_assets_around_camera(spawn_radius)
	
	# If we need more assets, spawn them (but maintain lower density)
	var assets_to_spawn = desired_asset_density - assets_in_area
	if assets_to_spawn > 0:
		# Limit spawning rate to prevent lag and maintain subtlety
		assets_to_spawn = min(assets_to_spawn, 3)  # Spawn fewer at a time
		
		for i in range(assets_to_spawn):
			var spawn_pos = get_random_spawn_position_around_camera(camera_pos, viewport_size, spawn_radius)
			if spawn_pos != Vector2.ZERO and not is_in_camera_focus_area(spawn_pos):  # Respect focus area
				create_asset_at_position(spawn_pos)

func count_assets_around_camera(radius: float) -> int:
	var count = 0
	var camera_pos = camera.global_position
	
	for child in get_children():
		if child is Sprite2D and child.has_meta("is_animated_asset"):
			var distance = camera_pos.distance_to(child.global_position)
			if distance <= radius:
				count += 1
	
	return count

func get_random_spawn_position_around_camera(camera_pos: Vector2, viewport_size: Vector2, max_radius: float) -> Vector2:
	# Try multiple times to find a good spawn position
	for attempt in range(15):  # More attempts for better positioning
		# Generate random position in circle around camera
		var angle = randf() * TAU
		var distance = randf_range(camera_clear_radius * 1.2, max_radius)  # Ensure minimum distance from camera
		
		var spawn_pos = camera_pos + Vector2(cos(angle) * distance, sin(angle) * distance)
		
		# Check if position is far enough from existing assets and camera focus
		if is_position_valid_for_spawning(spawn_pos):
			return spawn_pos
	
	return Vector2.ZERO  # No valid position found

func is_position_valid_for_spawning(pos: Vector2) -> bool:
	# Check distance from existing assets
	for child in get_children():
		if child is Sprite2D and child.has_meta("is_animated_asset"):
			var distance = pos.distance_to(child.global_position)
			if distance < min_asset_distance:
				return false
	
	return true

func cleanup_assets():
	# Remove assets that are too far from the camera (in all directions)
	var camera_pos = camera.global_position
	var cleanup_radius = cleanup_distance * 1.5  # Use radius instead of just Y distance
	var cleaned_count = 0
	
	for child in get_children():
		if child is Sprite2D and child.has_meta("is_animated_asset"):
			var distance = camera_pos.distance_to(child.global_position)
			if distance > cleanup_radius:
				cleaned_count += 1
				child.queue_free()
	
	if cleaned_count > 0:
		print("Cleaned up ", cleaned_count, " assets")

func spawn_assets_in_area(center_position: Vector2, count: int = 3):  # Reduced default count
	for i in range(count):
		var random_offset = Vector2(
			randf_range(-spawn_area_width, spawn_area_width),
			randf_range(-200, 200)
		)
		var spawn_pos = center_position + random_offset
		if not is_in_camera_focus_area(spawn_pos):  # Respect camera focus area
			create_asset_at_position(spawn_pos)

# Add this function for testing
func spawn_test_asset():
	var sprite = Sprite2D.new()
	sprite.texture = textures[0]  # Use first texture
	add_child(sprite)
	sprite.global_position = camera.global_position + Vector2(camera_clear_radius, 0)  # Place outside focus area
	sprite.scale = Vector2(2, 2)  # Make it visible but not huge
	sprite.modulate = Color.YELLOW  # Make it bright yellow for testing
	sprite.z_index = -1  # Put it in background
	
	# Add animation metadata for testing - SAME as create_asset_at_position
	var texture_name = textures[0].resource_path.get_file().to_lower()
	sprite.set_meta("original_scale_x", 2.0)
	sprite.set_meta("original_scale_y", 2.0)
	sprite.set_meta("original_alpha", 1.0)
	sprite.set_meta("animation_offset", 0.0)
	sprite.set_meta("base_rotation", 0.0)
	sprite.set_meta("texture_name", texture_name)
	sprite.set_meta("is_animated_asset", true)  # This is crucial!
	
	print("TEST ASSET created: ", texture_name, " at position: ", sprite.global_position)

# Force refresh all assets (useful when you change textures during development)
func refresh_all_assets():
	clear_all_assets()
	await get_tree().process_frame
	spawn_initial_assets()
