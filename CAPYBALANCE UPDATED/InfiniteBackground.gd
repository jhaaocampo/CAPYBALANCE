extends ParallaxBackground

var camera: Camera2D
var zone_height = 1000
var current_zone = 0
var zones = [
	{"color": Color.WHITE},
	{"color": Color(0.9, 0.95, 1.0)}, 
	{"color": Color(0.7, 0.8, 1.0)},
	{"color": Color(0.1, 0.1, 0.3)},
	{"color": Color(0.05, 0.05, 0.2)},
]

func _ready():
	camera = get_viewport().get_camera_2d()

func _process(delta):
	if camera:
		var camera_y = -camera.global_position.y
		var new_zone = max(0, int(camera_y / zone_height))
		if new_zone >= zones.size():
			new_zone = zones.size() - 1
		
		if new_zone != current_zone:
			current_zone = new_zone
			var tween = create_tween()
			for layer in get_children():
				if layer is ParallaxLayer:
					var texture_rect = layer.get_child(0)
					tween.parallel().tween_property(texture_rect, "modulate", zones[current_zone].color, 1.0)
