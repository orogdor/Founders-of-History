extends SceneTree
## Mängu detailvaate töölised (DetailView.update_workers) uute inimestega ja ajastu vahetus.
## Peata: godot --headless --path . -s tests/human_detail_workers.gd
## Pildiga: godot --path . --resolution 1600x900 -s tests/human_detail_workers.gd -- <väljundkaust>
const Detail=preload("res://scripts/detail_view.gd")
const Humans=preload("res://scripts/human_factory.gd")
class FlatDetail:
	extends Detail
	func display_height(_x: float,_z: float) -> float:return 0.0

var out_dir:=""

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()>0:out_dir=args[0]
	call_deferred("run")

func worker(kind: String,x: float,z: float,heading: float,action: String,moving:=false) -> Dictionary:
	return {"kind":kind,"x":x,"z":z,"heading":heading,"visible":true,"working":not moving,"action":action,"moving":moving,"workRate":1.0}

func run() -> void:
	var detail:=FlatDetail.new();root.add_child(detail)
	var city:={"c":0,"r":0,"team":0,"world":{"workers":{
		"w1":worker("lumber",-3.0,0.6,0.4,"chop"),"w2":worker("berries",-1.2,1.4,0.1,"gather"),"w3":worker("farm",0.8,1.0,-0.2,"gather"),
		"w4":worker("well",2.4,0.8,-0.5,"",true),"w5":worker("market_woman",-0.2,2.6,0.0,""),"w6":worker("mason",3.6,-0.4,-0.9,"build")}},
		"economy":{"cargo":[]}}
	var shots:=[0,2,3,5,6] if out_dir!="" else [0,3,6]
	if out_dir!="":setup_scene(detail)
	var label: Label=root.get_node_or_null("Ui/Label")
	for era in shots:
		for f in 20:
			detail.update_workers(city,2.0+f*0.03,era)
			await process_frame
		var real:=0;var eras_ok:=true
		for key in detail.worker_models:
			var model: Node3D=detail.worker_models[key]
			if Humans.is_real(model):real+=1
			if int(model.get_meta("human_era",-1))!=era:eras_ok=false
		assert(real==6,"Kõik töölised peavad olema uued inimesed (%d)" % real)
		assert(eras_ok,"Ajastu vahetus peab jõudma kõigi tööliste riietesse")
		var lumber: Node3D=detail.worker_models["w1"]
		assert((era==0)==(lumber.has_meta("job_tool") and lumber.get_meta("job_tool").visible),"Kiviaja kirves ainult kiviajal (teiste ajastute tööriistu veel pole)")
		if out_dir!="":
			if label!=null:label.text=str(Humans.config().eras[era].name)+" · mängu detailvaate töölised"
			await process_frame;await process_frame
			var path:="%s/toolised_%d.png" % [out_dir,era];root.get_texture().get_image().save_png(path);print("PILT ",path)
	print("HUMAN_DETAIL_WORKERS_OK")
	quit()

func setup_scene(detail: Node3D) -> void:
	var env:=WorldEnvironment.new();var e:=Environment.new();var sky:=Sky.new();var sm:=ProceduralSkyMaterial.new()
	sm.sky_top_color=Color("6f9bd1");sm.sky_horizon_color=Color("c9d8e6");sky.sky_material=sm;e.background_mode=Environment.BG_SKY;e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("aeb8c4");e.ambient_light_energy=0.55
	e.tonemap_mode=Environment.TONE_MAPPER_ACES;e.tonemap_exposure=0.8;env.environment=e;root.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,28,0);sun.light_energy=1.0;sun.light_color=Color("fff1dc");sun.shadow_enabled=true;root.add_child(sun)
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(80,80);ground.mesh=plane
	var gm:=StandardMaterial3D.new();gm.albedo_texture=load("res://assets/ground/grass-color.webp");gm.uv1_scale=Vector3(28,28,1);gm.albedo_color=Color(0.72,0.78,0.62)
	ground.material_override=gm;root.add_child(ground)
	var camera:=Camera3D.new();camera.fov=38;root.add_child(camera);camera.position=Vector3(0.6,2.6,8.2);camera.look_at(Vector3(0.2,0.9,0.6))
	var ui:=CanvasLayer.new();ui.name="Ui";root.add_child(ui)
	var label:=Label.new();label.name="Label";label.position=Vector2(36,22);label.add_theme_font_size_override("font_size",40)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7));label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2);ui.add_child(label)
