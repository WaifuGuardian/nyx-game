class_name MapData
## A map's pure data: tile ids per cell, plus spawns.
## Tile ids: "floor", "wall", "door", "stairs_down", "stairs_up",
## "grass", "plains", "woods", "mountain", "water", "dungeon_entrance", "town".
## Filled by loaders (ASCII, procedural, someday editor-painted).

var size := Vector2i.ZERO
var tiles: Dictionary = {}  # Vector2i -> String tile id
var player_spawn := Vector2i.ZERO
var enemy_spawns: Array = []  # [{"pos": Vector2i, "id": String}]
var npc_spawns: Array = []    # [{"pos": Vector2i, "id": String}]
var item_spawns: Array = []   # [{"pos": Vector2i, "id": String, "quality": int, "count": int}]
var is_ambush := false
