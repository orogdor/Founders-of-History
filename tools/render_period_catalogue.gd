extends SceneTree
## Godot catalogue art is rendered from the same saved plans as play.
## Run with the graphical renderer, not --headless.
const Period=preload("res://scripts/house_period_styles.gd")
const Model=preload("res://scripts/house_plan_model.gd")
const FILTER_COLORS := ["181915","756958","776b66","505959","57666b","5d5e5c","586d72"]
const HORIZONS := ["7d765f","b4a289","aaa090","777e76","a2a1a2","938980","9faeaf"]
const WIDTH:=420
const HEIGHT:=312
var stage: SubViewport
var environment: Environment
var camera: Camera3D
var plinth: MeshInstance3D
var plinth_material: StandardMaterial3D
var first_age:=1
var last_age:=6

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Catalogue cards need a graphical renderer.")
		quit(1)
		return
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():first_age=clampi(int(args[0]),1,6)
	if args.size()>1:last_age=clampi(int(args[1]),first_age,6)
	var directory:="res://assets/house_designer/period_portraits/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	setup()
	var count:=0
	for age in range(first_age,last_age+1):
		var group:=0
		for key: String in Period.Defaults.data:
			if Period.age_of(key)!=age:
				continue
			var design:=Period.get_plan(key)
			if not await capture(design,directory+key+".jpg",age):
				quit(1)
				return
			count+=1
			group+=1
		print("CATALOGUE_PERIOD ",age," ",group)
	Model.clear_cache()
	stage.free()
	await process_frame
	print("CATALOGUE_PORTRAITS_OK ",count)
	quit()

func setup() -> void:
	stage=SubViewport.new()
	stage.size=Vector2i(WIDTH,HEIGHT)
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	stage.own_world_3d=true
	root.add_child(stage)
	var world:=WorldEnvironment.new()
	environment=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("e8d8ca")
	environment.ambient_light_energy=0.52
	world.environment=environment
	stage.add_child(world)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-42,-39,0)
	sun.light_color=Color("fff2d9")
	sun.light_energy=0.79
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=70
	stage.add_child(sun)
	var fill:=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-31,115,0)
	fill.light_color=Color("ccddeb")
	fill.light_energy=0.18
	stage.add_child(fill)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.current=true
	stage.add_child(camera)
	plinth=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(460,460)
	plinth.mesh=plane
	plinth.position.y=-0.055
	plinth_material=StandardMaterial3D.new()
	plinth_material.roughness=1.0
	plinth.material_override=plinth_material
	stage.add_child(plinth)

func capture(design: Dictionary,path: String,age: int) -> bool:
	var model:=Model.new()
	stage.add_child(model)
	model.rebuild(design,abs(str(design.id).hash())%8)
	var extent:=bounds(model)
	if extent.size.length_squared()<0.003:
		extent=AABB(Vector3(-1,0,-1),Vector3(2,2,2))
	var focus:=extent.get_center()
	var diagonal:=extent.size.length()
	camera.size=maxf(1.4,diagonal*0.81+0.55)
	camera.position=focus+Vector3(9.0,7.5,13.0)*maxf(1.0,diagonal/14.0)
	camera.look_at(focus)
	camera.force_update_transform()
	# Keep tall or narrow structures inside the frame at the same camera angle.
	var margin := Vector2(WIDTH, HEIGHT) * 0.455
	var screen_center := Vector2(WIDTH, HEIGHT) * 0.5
	var fit := 1.0
	for mesh_node in model.find_children("*","MeshInstance3D",true,false):
		var piece := mesh_node as MeshInstance3D
		if piece.mesh == null or piece.name in ["WeatheredYard","CourtyardPaving"]:
			continue
		var box := piece.mesh.get_aabb()
		for corner in 8:
			var screen := camera.unproject_position(piece.to_global(box.get_endpoint(corner)))
			var ratio := (screen - screen_center).abs() / margin
			fit = maxf(fit, maxf(ratio.x,ratio.y))
	camera.size *= fit
	plinth_material.albedo_color=Color(FILTER_COLORS[age])
	environment.background_color=Color(HORIZONS[age])
	await process_frame
	await RenderingServer.frame_post_draw
	var status:=stage.get_texture().get_image().save_jpg(path,0.86)
	model.free()
	if status!=OK:
		push_error("Cannot write "+path)
	return status==OK

func bounds(node: Node3D, inherited:=Transform3D.IDENTITY) -> AABB:
	var transform:=inherited*node.transform
	var extent:=AABB()
	if node is MeshInstance3D and node.mesh!=null and node.name not in ["WeatheredYard","CourtyardPaving"]:
		extent=transform*node.mesh.get_aabb()
	for child in node.get_children():
		if not child is Node3D:
			continue
		var other:=bounds(child,transform)
		if other.size.length_squared()>0.00001:
			extent=other if extent.size.length_squared()<0.00001 else extent.merge(other)
	return extent

