class_name Entity
extends Node2D

var grid_pos := Vector2i.ZERO
var display_name := "entity"
var hostile := false
var alive := true
var color := Color.WHITE

var attributes: Dictionary = {
	"STR": 10, "CON": 10, "DEX": 10, "PER": 10,
	"WIL": 10, "MAG": 10, "LUCK": 10, "CHA": 10,
}

var hp: int = 20:
	set(v): hp = clampi(v, 0, max_hp())
var guarding := false
var meditating := false
var stamina: float = 100.0
var mana: float = 0.0
var energy: float = 0.0
var face_path := ""
var face: Texture2D = null
var token_size := 1.0
var ring_color := Color(0.55, 0.5, 0.4)
var show_ring := true
var _move_tween: Tween


func _ready() -> void:
	z_index = 1
	mana = max_mana()
	snap()
	queue_redraw()


func snap() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
		_move_tween = null
	position = Vector2(grid_pos) * Game.TILE + Vector2(Game.TILE, Game.TILE) * 0.5


func slide() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	var target := Vector2(grid_pos) * Game.TILE + Vector2(Game.TILE, Game.TILE) * 0.5
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target, 0.08)


func set_face(path: String) -> void:
	face_path = path
	face = null
	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("[face] load failed: %s" % path)
		else:
			var img: Image = tex.get_image()
			if img == null:
				push_error("[face] image is null: %s" % path)
			else:
				var used := img.get_used_rect()
				print("[face] used rect: %s" % used)
				if used.size.x > 0 and used.size.y > 0:
					img = img.get_region(used)
				if img.is_compressed():
					img.decompress()
				img.generate_mipmaps()
				face = ImageTexture.create_from_image(img)
				print("[face] final texture: %dx%d" % [face.get_width(), face.get_height()])
	else:
		print("[face] no file found at: %s" % path)
	queue_redraw()


# --- Derived stats (all read from attributes) ---------------------------

func max_hp() -> int:
	return 10 + attributes["CON"] * 2


func max_mana() -> float:
	return 20.0 + attributes["WIL"] * 2.0


func speed() -> int:
	return 100 + (attributes["DEX"] - 10) * 2


func accuracy() -> int:
	return attributes["DEX"] * 2


func evasion() -> int:
	return attributes["DEX"] * 2


func attack_power() -> int:
	return 1 + int(attributes["STR"] / 4.0)


func defense() -> int:
	return int(attributes["CON"] / 5.0)


## Default turn for entities that never act; enemies override this.
func take_turn() -> int:
	return 100


# --- Resource ticks -------------------------------------------------------

## waiting: 0 = normal tick, 1 = guarding, 2 = waiting (full stop)
func tick_resources(waiting: int = 0) -> void:
	var st_gain := 1.0
	if waiting == 1:
		st_gain = 1.5
	elif waiting == 2:
		st_gain = 3.0
	stamina = minf(stamina + st_gain, 100.0)
	mana = minf(mana + 0.5, max_mana())
	queue_redraw()


# --- Combat / lifecycle ---------------------------------------------------

func take_damage(amount: int) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0:
		die()


func die() -> void:
	alive = false
	Game.entities.erase(self)
	queue_free()


func _draw() -> void:
	var radius := 5.0 * token_size
	var center := Vector2.ZERO
	# Grounding shadow: squashed dark ellipse under the token.
	draw_set_transform(Vector2(0, radius * 0.7), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, radius * 0.9, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if face != null:
		var tex_size := Vector2(face.get_width(), face.get_height())
		var fit: float = (radius * 2.0) / maxf(tex_size.x, tex_size.y)
		var draw_size := tex_size * fit
		if show_ring:
			draw_circle(center, radius, Color.WHITE)
		draw_texture_rect(face, Rect2(center - draw_size / 2.0, draw_size), false)
		if show_ring:
			draw_arc(center, radius, 0.0, TAU, 48, ring_color, 2.0)
	else:
		draw_circle(center, radius, color)
		draw_arc(center, radius, 0.0, TAU, 48, ring_color, 1.5)
	if meditating:
		draw_circle(Vector2(0, -9 * token_size), 2.0, Color(0.5, 0.7, 1.0))
	if hp < max_hp():
		var bar_w := 10.0 * token_size
		draw_rect(Rect2(-bar_w / 2, -radius - 4, bar_w, 2), Color.BLACK)
		draw_rect(Rect2(-bar_w / 2, -radius - 4, bar_w * hp / max_hp(), 2), Color.RED)
