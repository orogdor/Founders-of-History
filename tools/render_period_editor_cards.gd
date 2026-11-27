extends SceneTree
const Model=preload("res://scripts/house_plan_model.gd")
const Period=preload("res://scripts/house_period_styles.gd")
const Props=preload("res://scripts/house_period_props.gd")
const Workplaces=preload("res://scripts/house_period_workplaces.gd")
const IronSites=preload("res://scripts/iron_age_fixtures.gd")
const BronzeSites=preload("res://scripts/bronze_worksite_visuals.gd")

const OUTPUT:="res://assets/house_designer/web_cards/"
const BRONZE_OUTPUT:="res://assets/house_designer/bronze_cards/"
const PROPS:=[
	["householdJar",1],["saddleQuern",1],["aegeanAmphoraRack",1],["romanTaberna",2],["romanBasin",2],["romanColumn",2],
	["norseHearth",3],["norseSleepingBench",3],["norseLoom",3],["medievalBelfry",3],
	["dockCrane",4],["navalBales",4],["civicClock",4],
	["canvasShelter",5],["workerChimney",5],["factoryLathe",5],["factorySwitchboard",5],["factoryDrive",5],
	["modernPlanter",6],["labStation",6],["labCabinet",6],["loadingPallet",6],["airfieldPlane",6],
	["substation",6],["processVessels",6],["siteShelter",5],["wheelLoader",6],
]
const ROOFS:=[
	["roof-earthenShed","house@1"],
	["roof-norse","house@3"],["roof-sawtooth","steelworks@5"],
	["roof-barrelRoof","barracks@5"],["roof-roofTerrace","house@6"],
]
const OPENINGS:=[
	["door-timberLintel","door","timberLintel",1],
	["window-sash","window","sash",4],["window-factoryWindow","window","factoryWindow",5],
	["window-glazed","window","glazed",6],["window-pictureWindow","window","pictureWindow",6],
	["door-loadingDoor","door","loadingDoor",5],
]
var stage: SubViewport
var camera: Camera3D

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Editor icons need a graphical renderer.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	prepare()
	var count:=0
	var selected:=OS.get_cmdline_user_args()
	if selected.is_empty() or "iron" in selected:
		var iron_output:="res://assets/house_designer/iron_cards/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(iron_output))
		for item:String in IronSites.TYPES:
			var visual:=Model.new()
			stage.add_child(visual)
			visual.design_period=2
			visual.iron_family="craft"
			var plan:={"id":"mine","ironFamily":"craft","items":[],"fences":[]}
			if not IronSites.place(visual,item,Vector3.ZERO,plan) or not await render(visual,item,Vector3(3.5,2.65,4.9),iron_output):
				quit(1)
				return
			count+=1
	if selected.is_empty() or "bronze" in selected:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BRONZE_OUTPUT))
		for item:String in BronzeSites.TYPES+["bridgeSpan","bronzeBoat"]:
			var visual:=Model.new()
			stage.add_child(visual)
			visual.design_period=1
			visual.bronze_family="craft"
			var plan:={"id":"coppermine", "items":[], "fences":[]}
			if not BronzeSites.place(visual,item,Vector3.ZERO,"craft",plan) or not await render(visual,item,Vector3(3.5,2.65,4.9),BRONZE_OUTPUT):
				quit(1)
				return
			count+=1
	for item in PROPS:
		if not selected.is_empty() and item[0] not in selected:continue
		var visual:=Model.new()
		stage.add_child(visual)
		visual.design_period=item[1]
		var built: bool=Workplaces.build(visual,item[0],Vector3.ZERO)
		if not built:
			built=Props.build(visual,item[0],Vector3.ZERO,1.20)
		if not built:
			push_error("Missing editor model for "+str(item[0]))
			quit(1)
			return
		if not await render(visual,item[0],Vector3(3.5,2.65,4.9)):
			quit(1)
			return
		count+=1
	for roof in ROOFS:
		if not selected.is_empty() and roof[0] not in selected:continue
		var visual:=Model.new()
		stage.add_child(visual)
		var plan:=Period.get_plan(roof[1]).duplicate(true)
		plan.erase("yard")
		plan.fences=[]
		plan["items"]=[]
		visual.rebuild(plan,3)
		if not await render(visual,roof[0],Vector3(3.9,4.7,5.0)):
			quit(1)
			return
		count+=1
	for entry in OPENINGS:
		if not selected.is_empty() and entry[0] not in selected:continue
		var style: String=entry[2]
		var age: int=entry[3]
		var design: Dictionary=Period.get_plan("house@"+str(age)).duplicate(true)
		var room: Dictionary=Period.room(362,245,598,362)
		design["rooms"]=[room]
		design["openings"]=[Period.opening(entry[1],480,362,style)]
		design["roofForm"]="none"
		for key in ["inner","yard","items","fences","wallRuns","wallFinishes","upper"]:
			design.erase(key)
		if style!="timberLintel":design.erase("periodOrnament")
		var visual:=Model.new()
		stage.add_child(visual)
		visual.rebuild(design,2)
		if not await render(visual,entry[0],Vector3(1.15,1.25,5.0)):
			quit(1)
			return
		count+=1
	stage.free()
	Model.clear_cache()
	print("PERIOD_EDITOR_CARDS_OK ",count)
	quit()

func prepare() -> void:
	stage=SubViewport.new()
	stage.own_world_3d=true
	stage.transparent_bg=true
	stage.size=Vector2i(190,160)
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	var world:=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("f2dfc0")
	world.environment.ambient_light_energy=0.56
	stage.add_child(world)
	var main:=DirectionalLight3D.new()
	main.rotation_degrees=Vector3(-42,-34,0)
	main.light_color=Color("fff2db")
	main.light_energy=1.03
	stage.add_child(main)
	var rim:=DirectionalLight3D.new()
	rim.rotation_degrees=Vector3(-39,143,0)
	rim.light_color=Color("d7e3eb")
	rim.light_energy=0.33
	stage.add_child(rim)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.current=true
	stage.add_child(camera)

func render(visual: Node3D,key: String,camera_offset: Vector3,output:=OUTPUT) -> bool:
	var extent:=bounds(visual)
	if extent.size.length_squared()<0.0001:
		push_error("Empty editor icon "+key)
		return false
	camera.position=extent.get_center()+camera_offset.normalized()*maxf(8.0,extent.size.length()*2.0)
	camera.look_at(extent.get_center(),Vector3.UP)
	camera.size=extent.size.length()*0.91
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Error=stage.get_texture().get_image().save_png(output+key+".png")
	visual.free()
	if result!=OK:
		push_error("Cannot write editor icon "+key)
	return result==OK

func bounds(node: Node3D,parent:=Transform3D.IDENTITY) -> AABB:
	var transform:=parent*node.transform
	var region:=AABB()
	if node is MeshInstance3D and node.mesh!=null:
		region=transform*node.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var box:=bounds(child,transform)
			if box.size.length_squared()>0.00001:
				region=box if region.size.length_squared()<0.00001 else region.merge(box)
	return region

