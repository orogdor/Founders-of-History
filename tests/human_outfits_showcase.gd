extends SceneTree
## Iga ajastu 5 meeste ja 5 naiste riietust koos ajastu soengutega.
## godot --path . --resolution 1600x900 -s tests/human_outfits_showcase.gd -- <kaust>
const Humans=preload("res://scripts/human_factory.gd")
const Motion=preload("res://scripts/human_motion.gd")
var out_dir:="/tmp"
func _initialize() -> void:
	var a:=OS.get_cmdline_user_args();if a.size()>0:out_dir=a[0]
	call_deferred("run")
func run() -> void:
	var cfg:=Humans.config()
	var env:=WorldEnvironment.new();var e:=Environment.new();var sky:=Sky.new();var sm:=ProceduralSkyMaterial.new();sm.sky_top_color=Color("6f9bd1");sm.sky_horizon_color=Color("c9d8e6");sm.ground_horizon_color=Color("9aa585");sm.ground_bottom_color=Color("5c6a40");sky.sky_material=sm;e.background_mode=Environment.BG_SKY;e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("aeb8c4");e.ambient_light_energy=0.6;e.tonemap_mode=Environment.TONE_MAPPER_ACES;e.tonemap_exposure=0.82;env.environment=e;root.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,28,0);sun.light_color=Color("fff1dc");sun.shadow_enabled=true;sun.directional_shadow_max_distance=25;root.add_child(sun)
	var ground:=MeshInstance3D.new();var pm:=PlaneMesh.new();pm.size=Vector2(120,120);ground.mesh=pm
	var gm:=StandardMaterial3D.new();gm.albedo_texture=load("res://assets/ground/grass-color.webp");gm.uv1_scale=Vector3(40,40,1);gm.albedo_color=Color(0.72,0.78,0.62);ground.material_override=gm;root.add_child(ground)
	var cam:=Camera3D.new();cam.fov=36;root.add_child(cam);cam.position=Vector3(0,1.25,9.6);cam.look_at(Vector3(0,0.95,0))
	var ui:=CanvasLayer.new();root.add_child(ui);var label:=Label.new();label.position=Vector2(30,16);label.add_theme_font_size_override("font_size",44)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8));label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2);ui.add_child(label)
	var files: Array=[]
	for era in cfg.eras.size():
		var e2: Dictionary=cfg.eras[era]
		var halves: Array=[]
		for body in ["man","woman"]:
			var group:=Node3D.new();root.add_child(group)
			for n in 5:
				var ids: Array=e2[body][n].items.duplicate()
				ids.append(e2.hair[body][n])
				if body=="man":
					var beards: Array=e2.beards;var b: String=str(beards[(n*2+era)%beards.size()])
					if b!="":ids.append(b)
				var p:=Humans.create_with_items(body,ids,era*10+n+(5 if body=="woman" else 0));p.scale=Vector3.ONE*1.66
				p.position=Vector3((n-2)*1.05,0,0);p.rotation.y=0.18-0.09*n;group.add_child(p)
				Motion.new().apply(p,2.0+n*0.3,false,"")
			cam.position=Vector3(0,1.15,5.4) if body=="man" else Vector3(0,1.05,5.0);cam.look_at(Vector3(0,0.9 if body=="man" else 0.82,0))
			label.text=str(e2.name)+(" · mehed" if body=="man" else " · naised")
			for f in 4:await process_frame
			var img:=root.get_texture().get_image();img.convert(Image.FORMAT_RGBA8);halves.append(img)
			group.queue_free();await process_frame
		var w: int=halves[0].get_width();var h: int=halves[0].get_height()
		var both:=Image.create(w,h*2,false,Image.FORMAT_RGBA8);both.blit_rect(halves[0],Rect2i(0,0,w,h),Vector2i.ZERO);both.blit_rect(halves[1],Rect2i(0,0,w,h),Vector2i(0,h))
		var path:="%s/riietused_%d.png" % [out_dir,era];both.save_png(path);files.append(path);print("PILT ",path)
	quit()
