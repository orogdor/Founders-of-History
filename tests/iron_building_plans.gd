extends SceneTree

const Period = preload("res://scripts/house_period_styles.gd")
const Plan = preload("res://scripts/house_plan_geometry.gd")
const Edit = preload("res://scripts/house_plan_edit.gd")
const EditorPanel = preload("res://scripts/house_plan_panel.gd")
const Model = preload("res://scripts/house_plan_model.gd")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func item_count(design: Dictionary, kind: String) -> int:
	return design.items.filter(func(item): return item.type == kind).size()

func run() -> void:
	var count := 0
	for id: String in Period.Catalogue.data.catalog:
		if Period.age_of(id) != 2:
			continue
		count += 1
		var original: Dictionary = Period.Defaults.data[id].duplicate(true)
		var design := Period.get_plan(id)
		check(Period.Defaults.data[id] == original, id + " modified the original plan")
		check(design.get("periodStyle") == 2 and design.has("ironFamily"), id + " missing Iron Age design")
		if design.ironFamily != "fort" and not design.rooms.is_empty():
			check(design.roofMat == "romanTile", id + " lost tiled roof")
		var walls: Array = Plan.plan_geometry(design).walls
		for cut in design.openings:
			var matching := walls.filter(func(wall): return wall.group == cut.group)
			check(not Plan.nearest_wall(Plan.point(cut.point), matching, 2.01).is_empty(),
				"%s %s detached at %s" % [id, cut.type, cut.point])
		for item in design.items:
			check(Period.Catalogue.data.choices[id].has(item.type), "%s missing editor choice %s" % [id,item.type])
			check(not Edit.item_zone(design, item.type, Plan.point(item.point)).is_empty(),
				"%s item %s outside editor bounds at %s" % [id,item.type,item.point])
		for special in ["field","pier"]:
			check(design.get(special) == original.get(special), "%s changed its %s" % [id,special])
		if design.ironFamily == "fort":
			check(design.fences == original.fences and design.build == original.build, id + " lost its defensive alignment")
		var model := Model.from_design(design, 3, true)
		check(not model.find_children("*","MeshInstance3D",true,false).is_empty(), id + " has no real model")
		model.free()
	check(count == 53, "Wrong Iron Age catalogue size")
	var home := Period.get_plan("house@2")
	check(home.rooms.size() == 3 and item_count(home,"romanBasin") == 1 and item_count(home,"romanColumn") == 4, "Open atrium house")
	var market := Period.get_plan("market@2")
	check(item_count(market,"stall") == 4 and item_count(market,"romanTaberna") == 2, "Market courts")
	for item in market.items:
		if item.type == "stall" or item.type == "romanTaberna":
			check(Edit.item_zone(market, item.type, Plan.point(item.point)) == "yard", "Covered market stall")
	check(item_count(Period.get_plan("smelter"),"furnace") == 2, "Iron bloomery lacks both shafts")
	check(item_count(Period.get_plan("smith"),"anvil") == 1, "Smith has no anvil")
	check(item_count(Period.get_plan("watermill"),"waterwheel") == 1, "Watermill lacks its moving wheel")
	check(item_count(Period.get_plan("orchard"),"fruitTree") == 6, "Orchard rows incomplete")
	check(item_count(Period.get_plan("harbor@2"),"bronzeBoat") == 1, "Harbor boat missing")
	check(Period.get_plan("hall@2").porch == "front" and Period.get_plan("academy").rooms.size() == 3, "Public court not resolved")
	var furnace_index := -1
	var works := Period.get_plan("smelter")
	for i in works.items.size():
		if works.items[i].type == "furnace":
			furnace_index = i
			break
	check(furnace_index >= 0, "No movable furnace")
	if furnace_index >= 0:
		var at := Plan.point(works.items[furnace_index].point)
		var moved := Edit.move_item(works,furnace_index,at+Vector2(8,12),false)
		check(moved.has("design") and Plan.point(works.items[furnace_index].point) == at, "Moving furniture should create a new plan")
	var panel := EditorPanel.new()
	root.add_child(panel)
	check(panel.open_design("fisher@2","Kalameheonn"), "Fisher plan must open")
	check(panel.pier_available and panel.mini_preview.coast_active, "Fisher needs a drawable pier and coastal preview")
	var existing: Dictionary = Period.Defaults.data.smith.duplicate(true)
	existing.roofHeight = 126
	existing.items[0].point.x += 19
	check(panel.open_design("smith","Sepikoda",existing), "Existing smith design must open")
	check(not panel.canvas.design.has("ironFamily") and panel.canvas.design.rooms == existing.rooms and
			panel.canvas.design.items == existing.items and panel.canvas.design.roofHeight == 126,
			"Opening an older custom design must preserve the saved layout and roof")
	panel.free()
	Model.clear_cache()
	if failures.is_empty():
		print("IRON_BUILDING_PLANS_OK ", count, " editable designs")
	quit(0 if failures.is_empty() else 1)
