# scripts/debug_grid.gd — add as child of Main, toggle with F1
extends Node2D

var visible_grid := false


func _ready() -> void:
	visible = false
	z_index = 5


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			visible_grid = not visible_grid
			visible = visible_grid
			queue_redraw()


func _draw() -> void:
	if not visible_grid or Game.current_map == null:
		return
	var s: Vector2i = Game.current_map.size
	for x in s.x + 1:
		draw_line(Vector2(x * Game.TILE, 0), Vector2(x * Game.TILE, s.y * Game.TILE), Color(1, 1, 1, 0.12))
	for y in s.y + 1:
		draw_line(Vector2(0, y * Game.TILE), Vector2(s.x * Game.TILE, y * Game.TILE), Color(1, 1, 1, 0.12))
