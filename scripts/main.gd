extends Node2D

var cam: Camera2D


func _ready() -> void:
	var grid := GridContainer.new()
	seed(12345)
	Game.new_game()
	cam = Camera2D.new()
	cam.zoom = Vector2(4, 4)
	add_child(cam)
	cam.make_current()


func _process(_delta: float) -> void:
	if is_instance_valid(Game.player):
		var view_size := get_viewport_rect().size / cam.zoom
		var map_px := Vector2(Game.current_map.size) * Game.TILE
		# Center on the player, then clamp so the map edges never come inward.
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
