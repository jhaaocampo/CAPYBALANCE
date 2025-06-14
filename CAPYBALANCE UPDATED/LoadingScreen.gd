# LoadingScreen.gd

extends Node2D

func _ready():
	# Get the target scene from meta data
	var target_scene = get_tree().get_meta("target_scene")
	
	# Load the target scene in the next frame to avoid blocking
	await get_tree().process_frame
	
	# Change to the target scene
	get_tree().change_scene_to_file(target_scene)
