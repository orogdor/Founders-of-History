extends SceneTree

const Detail = preload("res://scripts/detail_view.gd")
const HousePanel = preload("res://scripts/house_plan_panel.gd")
const Model = preload("res://scripts/house_plan_model.gd")
const Collision = preload("res://scripts/house_collision.gd")
const Economy = preload("res://data/economy.json")
const Rules = preload("res://data/build_rules.json")
const Designs = preload("res://data/house_default_designs.json")
const Geometry = preload("res://scripts/house_plan_geometry.gd")
const PlanCollision = preload("res://scripts/house_plan_collision.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var panel := HousePanel.new()
	root.add_child(panel)
	assert(panel.open_design("house","Elamu"))
	assert(panel.era_buttons.size() == 7)
	var detail := Detail.new()
	var checked := 0
	for age in range(3, 7):
		panel.choose_era(age)
		assert(panel.era == age and panel.catalogue_open)
		for kind in Economy.data.buildings:
			if kind=="bridge" or int(Rules.data.age.get(kind,0))>age:
				continue
			var id := Detail.designer_id(kind,age)
			assert(id == "%s@%d" % [kind,age])
			assert(panel.catalogue_buttons.has(id), id)
			var model := detail.create_designed_building(kind,age)
			assert(model != null and model.get_child(0).get_script() == Model, id)
			assert(detail.first_mesh(model) != null, id)
			model.free()
			checked+=1

	assert(panel.open_design("house@5","Tööstusajastu elamu"))
	var updated: Dictionary=panel.canvas.design.duplicate(true)
	updated.wallStyle="brick"
	updated.roofForm="gable"
	if updated.get("upper") is Dictionary:updated.upper.roofForm="gable"
	var modified := detail.create_designed_building("house",6,updated)
	assert(modified.get_meta("designer_id")=="house@5")
	var roof := modified.find_child("RoofDeck",true,false) as MeshInstance3D
	assert(roof!=null and roof.get_active_material(0)!=null)
	assert(modified.find_child("RoofDeck",true,false)!=null)
	var wall: Array=PlanCollision.walls(updated)[0]
	var fit: Dictionary=Detail.MODEL_FITS.data["house@5"]
	var x := (float(wall[0])+float(wall[2]))*0.5*float(fit.scale[0])+float(fit.offset[0])
	var z := (float(wall[1])+float(wall[3]))*0.5*float(fit.scale[2])+float(fit.offset[2])
	var building := {"type":"house","x":0.0,"z":0.0,"ready":true,"houseDesignV354":updated}
	assert(Collision.hits(detail,building,6,x,z)==true)
	assert(Collision.hits(detail,building,6,60.0,60.0)==false)
	assert(Collision.reach(detail,building,6)>0.0)
	modified.free()
	var legacy: Dictionary=Designs.data["house@5"].duplicate(true)
	assert(legacy.has("upper"))
	var legacy_model:=detail.create_designed_building("house",6,legacy)
	assert(legacy_model.find_child("SecondStorey",true,false)!=null)
	legacy_model.free()

	var pier: Dictionary=Designs.data["harbor@6"]
	var shape := Geometry.pier_outline(pier.pier)
	var center := Vector2.ZERO
	for point in shape:
		center+=point
	center/=shape.size()
	var pier_at := (center-PlanCollision.origin(pier))/Geometry.PX_PER_M
	fit=Detail.MODEL_FITS.data["harbor@6"]
	x=pier_at.x*float(fit.scale[0])+float(fit.offset[0])
	z=pier_at.y*float(fit.scale[2])+float(fit.offset[2])
	var harbor := {"type":"harbor","x":0.0,"z":0.0,"ready":true}
	assert(Collision.pier_surface(detail,harbor,6,x,z)!=null)

	var town := Detail.new()
	root.add_child(town)
	var found := {"type":"house","x":0.0,"z":0.0,"hp":100,"ready":false,"progress":2.0}
	town.heights = [1.0,1.0,1.0,1.0]
	town.sync_buildings({"economy":{"buildings":[found]}},5)
	assert(town.construction_models.size() == 1)
	var construction: Node3D=town.construction_models[0].model
	assert(construction.get_meta("designer_id")=="house@5")
	assert(construction.find_child("RoofDeck",true,false)!=null)
	var old_height := construction.scale.y
	found.progress=10000.0
	town.update_building_animations(0.0)
	assert(construction.scale.y > old_height and is_equal_approx(construction.scale.y,1.0))
	town.queue_free()
	detail.free()
	panel.queue_free()
	Model.clear_cache()
	print("LATER_HOUSE_DESIGNS_OK ",checked)
	quit()

