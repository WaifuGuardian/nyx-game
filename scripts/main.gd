extends Node2D

var cam: Camera2D


func _ready() -> void:
	seed(12345)  # fixed seed for reproducible maps; swap for randomize()
	if Game.boot_mode == "load":
		Game.load_game()
	else:
		Game.new_game()
	Game.boot_mode = ""
	cam = Camera2D.new()
	cam.zoom = Vector2(6, 6)
	add_child(cam)
	cam.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom = Vector2.ONE * clampf(cam.zoom.x + 1.0, 3.0, 9.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom = Vector2.ONE * clampf(cam.zoom.x - 1.0, 3.0, 9.0)


func _process(_delta: float) -> void:
	if is_instance_valid(Game.player):
		var view_size := get_viewport_rect().size / cam.zoom
		var map_px := Vector2(Game.current_map.size) * Game.TILE
		var target := Game.player.position
		if map_px.x > view_size.x:
			target.x = clampf(target.x, view_size.x / 2, map_px.x - view_size.x / 2)
		else:
			target.x = map_px.x / 2
		if map_px.y > view_size.y:
			target.y = clampf(target.y, view_size.y / 2, map_px.y - view_size.y / 2)
		else:
			target.y = map_px.y / 2
		cam.position = cam.position.lerp(target, 0.2)
