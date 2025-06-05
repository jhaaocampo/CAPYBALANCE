# Scoreboard.gd
extends Control

@onready var score_label: Label = $Stacks
@onready var high_score_label: Label = $HighScore

var current_score: int = 0
var high_score: int = 0

# Called when the node enters the scene tree for the first time
func _ready():
	# Load high score from saved data
	load_high_score()
	update_score_display()
	
	# Connect to the game's stack addition signal
	# Replace "GameManager" with your actual game manager node name
	if has_node("/root/Main"):
		var game_manager = get_node("/root/Main")
		if game_manager.has_signal("stack_added"):
			game_manager.stack_added.connect(_on_stack_added)

func _on_stack_added():
	# """Called whenever a new item is added to the stack"""
	add_score(1)

func add_score(points: int):
	# """Add points to the current score"""
	current_score += points
	
	# Check if we have a new high score
	if current_score > high_score:
		high_score = current_score
		save_high_score()
	
	update_score_display()
	
	# Optional: Add some visual feedback
	animate_score_increase()

func reset_score():
	# """Reset the current score to 0"""
	current_score = 0
	update_score_display()

func update_score_display():
	# """Update the score labels"""
	score_label.text = "Stacks\n" + str(current_score)
	high_score_label.text = "High Score\n" + str(high_score)

func animate_score_increase():
	# """Add a small animation when score increases"""
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale animation
	score_label.scale = Vector2(1.2, 1.2)
	tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Color flash animation
	var original_color = score_label.modulate
	score_label.modulate = Color.YELLOW
	tween.tween_property(score_label, "modulate", original_color, 0.3)

func save_high_score():
	# """Save high score to user data"""
	var save_data = {
		"high_score": high_score
	}
	var save_file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()

func load_high_score():
	# """Load high score from saved data"""
	var save_file = FileAccess.open("user://savegame.save", FileAccess.READ)
	if save_file:
		var save_data = JSON.parse_string(save_file.get_as_text())
		save_file.close()
		
		if save_data and save_data.has("high_score"):
			high_score = save_data.high_score
	else:
		# No save file exists, high score remains 0
		high_score = 0
