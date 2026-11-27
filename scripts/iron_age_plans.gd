extends RefCounted
## Provincial Roman town buildings share their material vocabulary, while their workshops,
## entrances, production yards and public courts have independently authored floor plans.
const Recipes = preload("res://data/iron_building_plans.json")
const Recipe = preload("res://scripts/period_plan_recipe.gd")

static func apply(plan: Dictionary, kind: String) -> void:
	if not Recipes.data.has(kind):
		return
	var recipe: Dictionary = Recipes.data[kind]
	plan.ironFamily = recipe.family
	var door_style := str(recipe.get("door", "arched"))
	var window_style := str(recipe.get("window", "lattice"))
	if recipe.has("rooms"):
		Recipe.set_rooms(plan, recipe, door_style, window_style)
		plan.erase("upper")
		plan.roofForm = recipe.roof
		plan.roofMat = "romanTile"
		plan.roofHeight = recipe.get("rise", 101)
		plan.base = recipe.get("base", "none")
	else:
		if plan.get("rooms", []).is_empty() and plan.get("wallRuns", []).is_empty():
			plan.openings = []
		for cut in plan.openings:
			if cut.group == "outer":
				cut.style = door_style if cut.type == "door" else window_style
	if recipe.has("height"):
		plan.wallScale = recipe.height
	plan.wallStyle = recipe.get("wall", "romanTravertine")
	plan.columns = "tuscan"
	plan.porch = "front" if recipe.get("porch", false) else "none"
	plan.erase("periodOrnament")
	plan.erase("courtyardStyle")
	plan.erase("bronzePrestige")
	Recipe.set_yard_and_items(plan, recipe)
