class_name Item
extends RefCounted

var id := ""
var def: Dictionary = {}
var quality := 2  # index into ItemDB.QUALITY_NAMES
var count := 1


func display_name() -> String:
	var base: String = def["name"]
	if def["kind"] == "weapon" or def["kind"] == "armor":
		return "%s %s" % [ItemDB.QUALITY_NAMES[quality], base]
	return base
func tooltip_text() -> String:
	var lines: Array[String] = []
	lines.append(display_name())
	lines.append("Quality: %s" % ItemDB.QUALITY_NAMES[quality])
	match String(def["kind"]):
		"potion":
			lines.append("Heals %d HP on drink." % int(def["heal"]))
		"food":
			lines.append("Restores %d nutrition." % int(def["nutrition"]))
		"weapon":
			lines.append("Attack +%d" % int(def["atk"] * ItemDB.QUALITY_MULT[quality]))
		"armor":
			lines.append("Defense +%d" % int(def["def"] * ItemDB.QUALITY_MULT[quality]))
		"scroll":
			lines.append("Cast power %d." % int(def["power"] * ItemDB.QUALITY_MULT[quality]))
		"supply":
			lines.append("Consumed by resting.")
		"material":
			lines.append("Raw material. Sell or craft.")
	lines.append("Weight: %.1f   Value: %d g" % [weight(), value()])
	return "\n".join(lines)

func value() -> int:
	return int(def["value"] * ItemDB.QUALITY_MULT[quality])


func weight() -> float:
	return def["weight"] * count


func stackable() -> bool:
	return def["stack"]
func color() -> Color:
	var c: Color = def.get("color", Color.WHITE)
	return c
