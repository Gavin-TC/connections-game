extends Camera2D

@export_range(0, 5) var MIN_ZOOM: float = 1.0
@export_range(0, 5) var MAX_ZOOM: float = 2.0
@export_range(0, 50) var ZOOM_RATE: float = 5.0
@export_range(0.05, 1.0) var ZOOM_INC: float = 0.5
## Setting this will set the zoom when spawning in 
@export var target_zoom: float = (MIN_ZOOM + MAX_ZOOM) / 2


func _physics_process(delta) -> void:
	zoom = lerp(zoom, Vector2.ONE * target_zoom, ZOOM_RATE * delta)
	set_physics_process(not is_equal_approx(zoom.x, target_zoom))


func _input(event) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:	  zoom_in()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_out()
	elif event.is_action_pressed("zoom_in"):  zoom_in()
	elif event.is_action_pressed("zoom_out"): zoom_out()


func zoom_in() -> void:
	var next_step = floor(target_zoom / ZOOM_INC) * ZOOM_INC + ZOOM_INC
	target_zoom = min(next_step, MAX_ZOOM)
	set_physics_process(true)


func zoom_out() -> void:
	var next_step = ceil(target_zoom / ZOOM_INC) * ZOOM_INC - ZOOM_INC
	target_zoom = max(next_step, MIN_ZOOM)
	set_physics_process(true)
