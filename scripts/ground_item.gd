class_name GroundItem
extends Node2D

var item: Item
var grid_pos := Vector2i.ZERO


func _ready() -> void:
	position = Vector2(grid_pos) * Game.TILE + Vector2(Game.TILE, Game.TILE) * 0.5
	queue_redraw()


func _draw() -> void:
	var unit := Game.TILE / 16.0
	var s := 6.0 * unit
	draw_rect(Rect2(-3, -3, 6, 6), item.color())
	draw_rect(Rect2(-3, -3, 6, 6), Color(0, 0, 0, 0.6), false, 1.0)
