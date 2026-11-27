extends SceneTree

const Period = preload("res://scripts/house_period_styles.gd")
const Plan = preload("res://scripts/house_plan_geometry.gd")
const Edit = preload("res://scripts/house_plan_edit.gd")
const Model = preload("res://scripts/house_plan_model.gd")

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func check_openings(plan: Dictionary, id: String) -> void:
	var walls: Array = Plan.plan_geometry(plan).walls
	for opening in plan.openings:
		var matching := walls.filter(func(wall): return wall.group == opening.group)
		var hit := Plan.nearest_wall(Plan.point(opening.point), matching, 2.01)
		check(not hit.is_empty(), "%s has an unattached %s at %s" % [id, opening.type, opening.point])

func run() -> void:
	var covered := 0
	for id: String in Period.Catalogue.data.catalog:
		if Period.age_of(id) != 1:
			continue
		covered += 1
		var kind := id.get_slice("@", 0)
		var baseline: Dictionary = Period.Defaults.data[id].duplicate(true)
		var plan := Period.get_plan(id)
		check(plan.get("periodStyle") == 1, id + " has no Bronze Age design")
		check(Period.Defaults.data[id] == baseline, id + " altered the source template")
		if kind == "house":
			check(plan.get("periodOrnament") == "aegeanHousehold", id + " lost the reference house")
		else:
			check(plan.has("bronzeFamily"), id + " has no building family")
			if plan.build != "tower" and not plan.rooms.is_empty():
				check(plan.base == "plinth" and plan.roofForm == "earthenShed", id + " lost its earthen roof or stone base")
		check_openings(plan, id)
		if plan.get("upper") is Dictionary:
			check_openings(plan.upper, id + " upper")
		for item in plan.items:
			check(Period.Catalogue.data.choices[id].has(item.type), "%s lacks %s in its editor palette" % [id, item.type])
			var zone := Edit.item_zone(plan, item.type, Plan.point(item.point))
			check(not zone.is_empty(), "%s cannot place %s at %s" % [id, item.type, item.point])
		for feature in ["pier", "field"]:
			check(plan.get(feature) == baseline.get(feature), "%s lost its %s" % [id, feature])
		if plan.get("bronzeFamily") == "fort":
			check(plan.build == baseline.build and plan.fences == baseline.fences, id + " altered its defenses")
		var model := Model.from_design(plan, 2, true)
		check(not model.find_children("*", "MeshInstance3D", true, false).is_empty(), id + " did not produce a world model")
		model.free()
	check(covered == 45, "Expected 45 Bronze Age plans, saw %d" % covered)
	var market := Period.get_plan("market")
	var stalls := 0
	for item in market.items:
		if item.type == "stall":
			stalls += 1
			check(Edit.item_zone(market, item.type, Plan.point(item.point)) == "yard", "Market stall is under a roof")
	check(stalls >= 3, "Market lacks its open-air stalls")
	for entry in [["bronze_foundry", "bronzeHearth"], ["pottery_kiln@1", "kiln"],
			["harbor", "bronzeBoat"], ["fisher@1", "bronzeNet"], ["bridge", "bridgeSpan"],
			["well@1", "wellRoof"], ["weaver", "loom"], ["coppermine", "shaft"]]:
		var site := Period.get_plan(entry[0])
		check(site.items.any(func(item): return item.type == entry[1]), "%s lacks %s" % entry)
	var court := Period.get_plan("courtyard_house")
	check(court.upper.has("stairs") and court.upper.has("gallery"), "Courtyard house lost its two-floor circulation")
	check(Period.get_plan("bronze_town").rooms.size() >= 4, "Town no longer has separate dwellings")
	check(Period.get_plan("hunter@1").rooms[0].type == "round", "Hunter's hut lost its round floor plan")
	var hall := Period.get_plan("hall@1")
	check(hall.porch == "front" and hall.rooms.size() >= 3, "Hall lost its central entrance and side wings")
	Model.clear_cache()
	if failures.is_empty():
		print("BRONZE_BUILDING_PLANS_OK ", covered, " editable models")
	quit(0 if failures.is_empty() else 1)
