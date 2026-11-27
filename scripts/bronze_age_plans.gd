extends RefCounted
## Resolve the authored Bronze Age layouts into the same editable data used by the canvas,
## construction footprints, walk mode and local saves. Coordinates use the native plan grid.
const Recipe = preload("res://scripts/period_plan_recipe.gd")
const Recipes = preload("res://data/bronze_building_plans.json")

static func family_for(kind: String) -> String:
	if kind == "house":
		return "home"
	return str(Recipes.data.get(kind, {}).get("family", ""))

static func uses_earthen_building(plan: Dictionary) -> bool:
	return plan.get("periodOrnament", "") == "aegeanHousehold" or (plan.has("bronzeFamily") and plan.get("build", "wall") != "tower")

static func finishes(floor_plan: Dictionary, fortified: bool) -> void:
	floor_plan.wallStyle = "aegeanStone" if fortified else "aegeanPlaster"
	floor_plan.columns = "post"
	floor_plan.porch = "none"
	if not fortified and not floor_plan.get("rooms", []).is_empty():
		floor_plan.base = "plinth"
		floor_plan.roofMat = "earth"
		floor_plan.roofForm = "earthenShed"
		for cut in floor_plan.openings:
			if cut.group == "outer":
				cut.style = "timberLintel" if cut.type == "door" else "hole"
	floor_plan.erase("courtyardStyle")
	floor_plan.erase("bronzePrestige")

static func apply(plan: Dictionary, kind: String) -> void:
	if not Recipes.data.has(kind):
		return
	var recipe: Dictionary = Recipes.data[kind]
	plan.bronzeFamily = recipe.family
	if recipe.has("rooms"):
		Recipe.set_rooms(plan, recipe, "timberLintel", "hole")
	Recipe.set_yard_and_items(plan, recipe)
	var fortified: bool = plan.get("build","") == "tower"
	if plan.get("rooms", []).is_empty() and plan.get("wallRuns", []).is_empty():
		plan.openings = []
	finishes(plan, fortified)
	plan.wallScale = recipe.get("height", plan.get("wallScale", 100))
	if recipe.get("porch",false):
		plan.porch = "front"
	if plan.get("upper") is Dictionary:
		finishes(plan.upper, false)
		plan.upper.wallScale = 118
		plan.upper.base = "none"
