extends SceneTree

const Model=preload("res://scripts/house_plan_model.gd")
const Plans=preload("res://scripts/house_period_styles.gd")
const Preview=preload("res://scripts/house_plan_preview.gd")
const Geometry=preload("res://scripts/house_plan_geometry.gd")

var failures:Array[String]=[]

func check(ok:bool,message:String) -> void:
	if not ok:
		push_error(message)
		failures.append(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var model:=Model.new()
	root.add_child(model)
	var preview:=Preview.new()
	var house:=Plans.get_plan("house@2").duplicate(true)
	model.rebuild(house)
	check(model.find_child("RomanDoorArch",true,false)!=null,"Real door arch missing")
	var court:=model.get_node_or_null("CourtyardPaving") as MeshInstance3D
	check(court!=null and court.mesh.get_aabb().size.x<4 and court.mesh.get_aabb().size.z<4,"Mosaic spills across the house plot")
	preview.set_roof_visibility(model,false)
	var roof:=model.find_child("RoofDeck",true,false) as MeshInstance3D
	check(roof!=null and not roof.visible and roof.mesh.get_faces().size()>200,"Tiled roof course visibility")
	house.roofForm="none"
	house.openings=house.openings.filter(func(value):return value.type!="door")
	model.rebuild(house)
	check(model.has_node("RoofDeck")==false and model.has_node("RomanDoorArch")==false,"Deleted roof or door still draws")
	var market:=Plans.get_plan("market@2").duplicate(true)
	model.rebuild(market)
	preview.set_roof_visibility(model,false)
	check(not model.get_node("Roman_stallCover").visible and model.get_node("Roman_stall").visible,"Market awning visibility")
	market.items=market.items.filter(func(value):return value.type!="stall")
	model.rebuild(market)
	check(model.find_child("Roman_stall*",true,false)==null,"Deleted stall still draws")
	var mill:=Plans.get_plan("watermill").duplicate(true)
	model.rebuild(mill)
	var mount:=model.find_child("RomanWatermill",true,false) as Node3D
	check(mount!=null and mount.has_node("IronMillWheel") and mount.has_node("RomanMillRace"),"Watermill rotor and channel")
	var placed:Dictionary=mill.items.filter(func(value):return value.type=="waterwheel")[0]
	placed.point.x+=25
	model.rebuild(mill)
	mount=model.find_child("RomanWatermill",true,false) as Node3D
	check(mount.position.is_equal_approx(model.local(Geometry.point(placed.point))),"Wheel disconnected from moved item")
	var fort:=Plans.get_plan("gatehouse@2").duplicate(true)
	model.rebuild(fort)
	preview.set_roof_visibility(model,false)
	check(model.has_node("RomanRampartDeck") and not model.get_node("RomanRampartDeck").visible and model.get_node("Roman_archGate").visible,"Fort roof toggle")
	fort.items=fort.items.filter(func(value):return value.type!="archGate")
	model.rebuild(fort)
	check(not model.has_node("Roman_archGate"),"Gate arch disconnected from editor")
	model.rebuild(Plans.get_plan("house@3"))
	check(model.iron_family.is_empty() and not model.has_node("RomanFacade"),"Iron decoration leaks into the next era")
	model.free()
	preview.free()
	Model.clear_cache()
	print("IRON_SITE_VISUALS_OK" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
