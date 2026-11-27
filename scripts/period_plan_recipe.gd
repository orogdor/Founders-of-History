extends RefCounted
## Decode authored room and courtyard coordinates into the native editor format.

static func point(x: float, y: float) -> Dictionary:
	return {"x": x, "y": y}

static func opening(kind: String, p: Dictionary, group: String, outer_door: String, outer_window: String) -> Dictionary:
	var finish := outer_window if kind == "window" else "plank" if group == "inner" else outer_door
	return {"type": kind, "group": group, "style": finish, "point": p}

static func set_rooms(plan: Dictionary, recipe: Dictionary, outer_door: String, outer_window: String) -> void:
	plan.rooms = []
	plan.inner = []
	plan.openings = []
	plan.wallRuns = []
	plan.wallFinishes = []
	for dimensions: Array in recipe.rooms:
		if dimensions.size() == 3:
			plan.rooms.append({"type":"round", "a":point(dimensions[0], dimensions[1]), "r":dimensions[2]})
		else:
			var room := {"type":"rect", "a":point(dimensions[0], dimensions[1]), "b":point(dimensions[2], dimensions[3])}
			if dimensions.size() > 4:
				room.heightFactor = dimensions[4]
			plan.rooms.append(room)
	for kind: String in ["door", "window"]:
		for coords: Array in recipe.get(kind + "s", []):
			plan.openings.append(opening(kind, point(coords[0], coords[1]), "outer", outer_door, outer_window))
	for wall: Array in recipe.get("partitions", []):
		plan.inner.append({"a":point(wall[0],wall[1]), "b":point(wall[2],wall[3])})
		if wall.size() > 4:
			plan.openings.append(opening("door", point(wall[4],wall[5]), "inner", outer_door, outer_window))
	plan.build = "wall"
	plan.openSite = false

static func set_yard_and_items(plan: Dictionary, recipe: Dictionary) -> void:
	if recipe.has("yard"):
		var bounds: Array = recipe.yard
		plan.yard = [point(bounds[0],bounds[1]), point(bounds[2],bounds[1]),
			point(bounds[2],bounds[3]), point(bounds[0],bounds[3])]
		plan.plot = null
	if recipe.has("fences"):
		plan.fences = []
		for segment: Array in recipe.fences:
			plan.fences.append({"kind": segment[0], "a": point(segment[1],segment[2]), "b": point(segment[3],segment[4])})
	plan.items = []
	for prop: Array in recipe.get("props", []):
		plan.items.append({"type": prop[0], "point": point(prop[1],prop[2])})

