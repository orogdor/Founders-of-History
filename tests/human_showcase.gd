extends SceneTree
## Teeb igast ajastust näidispildi mängu enda inimesteloojaga (HumanFactory),
## liigutustega (HumanMotion), mängu pinnase ja selle ajastu majaga.
## Käivita graafikaga: godot --path . --resolution 1600x900 -s tests/human_showcase.gd -- <väljundkaust> [lähivaade]
const Humans=preload("res://scripts/human_factory.gd")
const Motion=preload("res://scripts/human_motion.gd")
const Detail=preload("res://scripts/detail_view.gd")
const CAST:=[["man","",11,Vector3(-1.55,0,0.15),0.25,""],["woman","",23,Vector3(-0.45,0,0.35),0.05,""],["girl","",31,Vector3(0.45,0,0.55),-0.1,""],["boy","",47,Vector3(1.25,0,0.3),-0.25,""],
	["man","lumber",52,Vector3(3.6,0,-1.6),-1.0,"chop"],["woman","farm",64,Vector3(-3.7,0,-1.4),0.9,"gather"]]
var out_dir:="/tmp"
var close:=false
var face:=false
var label: Label
var sub: Label

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()>0:out_dir=args[0]
	close=args.size()>1 and args[1] in ["lähivaade","nägu"]
	face=args.size()>1 and args[1]=="nägu"
	call_deferred("run")

func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();var e:=Environment.new()
	var sky:=Sky.new();var sky_mat:=ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("6f9bd1");sky_mat.sky_horizon_color=Color("c9d8e6");sky_mat.ground_horizon_color=Color("b9b2a0");sky_mat.ground_bottom_color=Color("5a5446")
	sky.sky_material=sky_mat;e.background_mode=Environment.BG_SKY;e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("aeb8c4");e.ambient_light_energy=0.55
	e.tonemap_mode=Environment.TONE_MAPPER_ACES;e.tonemap_exposure=0.8
	env.environment=e;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,32,0);sun.light_energy=1.0;sun.light_color=Color("fff1dc");sun.shadow_enabled=true
	sun.directional_shadow_max_distance=30;world.add_child(sun)
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(80,80);ground.mesh=plane
	var gm:=StandardMaterial3D.new();gm.albedo_texture=load("res://assets/ground/grass-color.webp");gm.uv1_scale=Vector3(28,28,1);gm.roughness=1.0;gm.albedo_color=Color(0.72,0.78,0.62)
	ground.material_override=gm;world.add_child(ground)
	var camera:=Camera3D.new();camera.fov=34 if close else 40;world.add_child(camera)
	if face:camera.fov=22;camera.position=Vector3(-1.45,1.66,1.75);camera.look_at(Vector3(-1.3,1.6,0.2))
	elif close:camera.position=Vector3(0,1.15,4.1);camera.look_at(Vector3(-0.1,0.95,0.2))
	else:camera.position=Vector3(0,1.75,8.6);camera.look_at(Vector3(0,1.25,-0.6))
	var ui:=CanvasLayer.new();world.add_child(ui)
	label=Label.new();label.position=Vector2(36,22);label.add_theme_font_size_override("font_size",46)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7));label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2);ui.add_child(label)
	sub=Label.new();sub.position=Vector2(38,84);sub.add_theme_font_size_override("font_size",22)
	sub.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7));sub.add_theme_constant_override("shadow_offset_x",1);sub.add_theme_constant_override("shadow_offset_y",1);ui.add_child(sub)
	var detail=Detail.new();world.add_child(detail)
	var eras: Array=Humans.config().eras
	for era in ([3] if face else range(eras.size())):
		var group:=Node3D.new();world.add_child(group)
		if not close:
			var house: Node3D=detail.create_designed_building("house",era)
			if house!=null:
				group.add_child(house);house.rotation.y=PI*0.06
				var box:=aabb(house);house.position=Vector3(-(box.position.x+box.size.x*0.5),0,-5.5-(box.position.z+box.size.z))
		var people: Array=[]
		for spec in CAST:
			if close and spec[1]!="":continue
			var person:=Humans.create(spec[0],era,spec[1],spec[2]);person.scale=Vector3.ONE*1.66
			person.position=spec[3];person.rotation.y=spec[4];group.add_child(person)
			if spec[1]!="":Humans.equip_job(person,spec[1],era)
			if person.has_meta("job_tool"):person.get_meta("job_tool").visible=Humans.tool_visible(person,era)
			var motion:=Motion.new();motion.phase=float(spec[2])*0.37
			people.append([person,motion,spec[5]])
		label.text=str(eras[era].name)
		var names: Array=[]
		for p in people:names.append("real" if Humans.is_real(p[0]) else "vana")
		sub.text="Mängu inimeste süsteem · MPFB2 kehad · automaatsed proovirõivad (asendatakse päris riietega)"
		for f in 24:
			for p in people:p[1].apply(p[0],2.0+f*0.02,false,p[2],1.0)
			await process_frame
		var image:=root.get_texture().get_image()
		var path:="%s/ajastu_%d_%s%s.png" % [out_dir,era,str(eras[era].id),"_nagu" if face else "_lahivaade" if close else ""]
		image.save_png(path);print("PILT ",path," ",names)
		group.queue_free();await process_frame
	quit()

func aabb(node: Node) -> AABB:
	var box:=AABB();var first:=true
	for child in node.find_children("*","VisualInstance3D",true,false):
		var vi: VisualInstance3D=child
		var b:=(node as Node3D).global_transform.affine_inverse()*vi.global_transform*vi.get_aabb() if vi.is_inside_tree() else vi.get_aabb()
		if first:box=b;first=false
		else:box=box.merge(b)
	return box
