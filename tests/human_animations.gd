extends SceneTree
## Kõik HumanMotioni liigutused uutel kehadel (luustiku sobituse kontroll).
## Peata: godot --headless --path . -s tests/human_animations.gd
## Pildiga: godot --path . --resolution 1600x900 -s tests/human_animations.gd -- <väljundkaust>
const Humans=preload("res://scripts/human_factory.gd")
const Motion=preload("res://scripts/human_motion.gd")
const Rig=preload("res://scripts/human_rig.gd")
const ACTIONS:=[["seisab",""],["kõnnib","walk"],["kannab","carry"],["raiub","chop"],["kaevandab","mine"],["ehitab","build"],["korjab","gather"],["harib","farm"],["püüab kala","fishing"],["jahib","hunt"],
	["hiilib","stalk"],["kannab vett","water"],["õpib","study"],["karjatab","herd"],["istub","sit"],["sööb","eat"],["mängib","play"],["valvab","guard"],["räägib","talk"],["kaevab","dig"]]
const TOOLS:={"chop":"lumber","mine":"quarry","build":"builder","gather":"berries","farm":"farm","fishing":"fisher","hunt":"hunter","water":"well","dig":"claypit","herd":"pasture","study":"study"}
var out_dir:=""

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()>0:out_dir=args[0]
	call_deferred("run")

func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	if out_dir!="":setup_scene(world)
	var people: Array=[]
	for i in ACTIONS.size():
		var spec: Array=ACTIONS[i];var action: String=spec[1]
		var body:="woman" if i%2==1 else "man"
		var job: String=TOOLS.get(action,"")
		var person:=Humans.create(body,0,job,100+i);person.scale=Vector3.ONE*1.66
		person.position=Vector3(i*12.0,0,0);world.add_child(person)
		if job!="":Humans.equip_job(person,job,0)
		assert(Humans.is_real(person),"Liigutuse proovis peab olema MPFB2 keha")
		var motion:=Motion.new();motion.phase=float(i)*0.31
		people.append([person,motion,action])
	var heights: Array=[]
	for f in 40:
		for p in people:
			var action: String=p[2]
			p[1].apply(p[0],3.0+f*0.05,action=="walk",action if action!="walk" else "",1.0)
		await process_frame
	# Kontroll: ükski luu ei tohi minna mõistlikust asendist välja (pea jääb jalgade kohale jne).
	for p in people:
		var skeleton:=Rig.find_skeleton(p[0]);var rig=Rig.of(skeleton)
		var head:=skeleton.get_bone_global_pose(rig.index["head"]).origin
		var foot:=skeleton.get_bone_global_pose(rig.index["foot_L"]).origin
		var hips:=skeleton.get_bone_global_pose(rig.index["hips"]).origin
		assert(head.y>hips.y and hips.y>foot.y,"Poos '%s' pöörab keha valesti" % p[2])
		heights.append(snappedf(head.y-foot.y,0.01))
	print("PEA KÕRGUS JALGADEST (luustiku ühikutes): ",heights)
	if out_dir!="":
		var camera: Camera3D=world.get_node("Camera");var label: Label=world.get_node("Ui/Label")
		var tw:=400;var th:=560;var sheet:=Image.create(tw*5,th*4,false,Image.FORMAT_RGBA8)
		for i in people.size():
			var x:=float(i)*12.0;camera.position=Vector3(x+2.9,1.55,2.7);camera.look_at(Vector3(x,0.85,0))
			label.text=str(ACTIONS[i][0])
			for f in 3:
				for p in people:p[1].apply(p[0],3.0+float(40+f)*0.05,p[2]=="walk",p[2] if p[2]!="walk" else "",1.0)
				await process_frame
			var shot:=root.get_texture().get_image();shot.convert(Image.FORMAT_RGBA8)
			var w:=shot.get_width();var h:=shot.get_height()
			var crop:=shot.get_region(Rect2i(w/2-int(h*0.36),0,int(h*0.72),h));crop.resize(tw,th,Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(crop,Rect2i(0,0,tw,th),Vector2i((i%5)*tw,(i/5)*th))
		var path:="%s/liigutused.png" % out_dir;sheet.save_png(path);print("PILT ",path)
	print("HUMAN_ANIMATIONS_OK")
	quit()

func setup_scene(world: Node3D) -> void:
	var env:=WorldEnvironment.new();var e:=Environment.new();var sky:=Sky.new();var sm:=ProceduralSkyMaterial.new()
	sm.sky_top_color=Color("6f9bd1");sm.sky_horizon_color=Color("c9d8e6");sky.sky_material=sm;e.background_mode=Environment.BG_SKY;e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("aeb8c4");e.ambient_light_energy=0.55
	e.tonemap_mode=Environment.TONE_MAPPER_ACES;e.tonemap_exposure=0.8;env.environment=e;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,25,0);sun.light_energy=1.0;sun.light_color=Color("fff1dc");sun.shadow_enabled=true;sun.directional_shadow_max_distance=12;world.add_child(sun)
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(600,80);ground.mesh=plane
	var gm:=StandardMaterial3D.new();gm.albedo_texture=load("res://assets/ground/grass-color.webp");gm.uv1_scale=Vector3(28,28,1);gm.albedo_color=Color(0.72,0.78,0.62)
	ground.material_override=gm;world.add_child(ground)
	var camera:=Camera3D.new();camera.name="Camera";camera.fov=40;world.add_child(camera)
	var ui:=CanvasLayer.new();ui.name="Ui";world.add_child(ui)
	var label:=Label.new();label.name="Label";label.position=Vector2(0,30);label.size=Vector2(1600,80);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",64);label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8));label.add_theme_constant_override("shadow_offset_x",3);label.add_theme_constant_override("shadow_offset_y",3);ui.add_child(label)
