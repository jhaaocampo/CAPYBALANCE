# SceneManager.gd
# Add this as an AutoLoad singleton in Project Settings
extends Node

# Scene paths - updated to match your actual paths (directly in res://)
const SCENES = {
	"landing": "res://LandingPage.tscn",
	"mode_selection": "res://ModeSelection.tscn",
	"main": "res://Main.tscn",
	"height_challenge": "res://HeightChallenge.tscn",
	"pause_menu": "res://PauseMenu.tscn",
	"game_over": "res://GameOver.tscn",
	"leave_scene": "res://LeaveScene.tscn"
}

# Custom loading scene path
const LOADING_SCENE_PATH = "res://LoadingScreen.tscn"

var current_scene = null
var is_transitioning = false
var loading_scene_instance = null

# UI elements for simple fade transition (fallback)
var transition_layer: CanvasLayer
var fade_rect: ColorRect

func _ready():
	# Get the current scene
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	
	# Create transition UI
	setup_transition_ui()

func setup_transition_ui():
	# Create canvas layer for transition overlay
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 100  # High layer to appear on top
	add_child(transition_layer)
	
	# Create fade rectangle (for simple fade transitions)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.modulate.a = 0.0
	transition_layer.add_child(fade_rect)

# Main function to change scenes
func goto_scene(scene_key: String, show_loading: bool = true, use_custom_loading: bool = true):
	if is_transitioning:
		return
	
	if not SCENES.has(scene_key):
		print("Error: Scene key '", scene_key, "' not found!")
		return
	
	is_transitioning = true
	
	if show_loading and use_custom_loading:
		call_deferred("_deferred_goto_scene_with_custom_loading", SCENES[scene_key])
	else:
		call_deferred("_deferred_goto_scene", SCENES[scene_key], show_loading)

# Deferred scene change with custom loading scene
func _deferred_goto_scene_with_custom_loading(path: String):
	# Fade out current scene
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(fade_rect, "modulate:a", 1.0, 0.3)
	await fade_out_tween.finished
	
	# Free current scene
	current_scene.free()
	
	# Load and show custom loading scene
	var loading_scene_resource = ResourceLoader.load(LOADING_SCENE_PATH)
	if loading_scene_resource:
		loading_scene_instance = loading_scene_resource.instantiate()
		get_tree().root.add_child(loading_scene_instance)
		get_tree().current_scene = loading_scene_instance
		
		# Fade in loading scene
		var fade_in_tween = create_tween()
		fade_in_tween.tween_property(fade_rect, "modulate:a", 0.0, 0.3)
		await fade_in_tween.finished
		
		# Let loading scene play for a bit (adjust time as needed)
		await get_tree().create_timer(1.5).timeout
		
		# Fade out loading scene
		var fade_out_loading_tween = create_tween()
		fade_out_loading_tween.tween_property(fade_rect, "modulate:a", 1.0, 0.3)
		await fade_out_loading_tween.finished
		
		# Free loading scene
		loading_scene_instance.free()
		loading_scene_instance = null
	else:
		print("Warning: Could not load custom loading scene, using fallback")
		await get_tree().create_timer(1.0).timeout
	
	# Load target scene
	var new_scene = ResourceLoader.load(path)
	current_scene = new_scene.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	# Fade in new scene
	var final_fade_tween = create_tween()
	final_fade_tween.tween_property(fade_rect, "modulate:a", 0.0, 0.3)
	await final_fade_tween.finished
	
	is_transitioning = false

# Original deferred scene change (fallback)
func _deferred_goto_scene(path: String, show_loading: bool):
	# Fade out
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.3)
	await tween.finished
	
	# Free current scene
	current_scene.free()
	
	# Small delay for loading effect (optional)
	if show_loading:
		await get_tree().create_timer(0.5).timeout
	
	# Load new scene
	var new_scene = ResourceLoader.load(path)
	current_scene = new_scene.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	# Fade in
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(fade_rect, "modulate:a", 0.0, 0.3)
	await fade_in_tween.finished
	is_transitioning = false

# Quick scene change without loading screen (for overlays)
func goto_scene_fast(scene_key: String):
	goto_scene(scene_key, false, false)

# Scene change with simple fade (no custom loading scene)
func goto_scene_simple(scene_key: String):
	goto_scene(scene_key, true, false)

# Reload current scene
func reload_current_scene():
	if is_transitioning:
		return
	
	var scene_path = current_scene.scene_file_path
	call_deferred("_deferred_goto_scene", scene_path, true)

# Convenience functions for your specific scene flow
func go_to_landing():
	goto_scene("landing")

func go_to_mode_selection():
	goto_scene("mode_selection")

func go_to_main_game():
	goto_scene("main")

func go_to_height_challenge():
	goto_scene("height_challenge")

func show_pause_menu():
	# Instantly switch to pause menu without any transition
	_instant_scene_change("pause_menu")

func show_game_over():
	goto_scene_fast("game_over")

func show_leave_scene():
	# Instantly switch to leave scene without any transition
	_instant_scene_change("leave_scene")

func reload_main():
	goto_scene("main")

func reload_height_challenge():
	goto_scene("height_challenge")

# Instant scene change with no transition at all
func _instant_scene_change(scene_key: String):
	if is_transitioning:
		return
	
	if not SCENES.has(scene_key):
		print("Error: Scene key '", scene_key, "' not found!")
		return
	
	is_transitioning = true
	
	# Free current scene
	current_scene.free()
	
	# Load new scene immediately
	var new_scene = ResourceLoader.load(SCENES[scene_key])
	current_scene = new_scene.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	is_transitioning = false

# Return to mode selection from pause menu or game over
func return_to_mode_selection():
	goto_scene("mode_selection")

# Exit game (for mobile, this might minimize the app)
func exit_game():
	get_tree().quit()
