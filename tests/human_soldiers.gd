extends SceneTree
## Kõik väeliigid uute inimestega: riietus, varustus, animatsiooni järgimine.
## Peata: godot --headless --path . -s tests/human_soldiers.gd
## Pildiga: godot --path . --resolution 1600x900 -s tests/human_soldiers.gd -- <kaust>
const View=preload("res://scripts/battle_view.gd")
const Humans=preload("res://scripts/human_factory.gd")
const Rig=preload("res://scripts/human_rig.gd")
var out_dir:=""
func _initialize() -> void:
	var a:=OS.get_cmdline_user_args();if a.size()>0:out_dir=a[0]
	call_deferred("run")
func run() -> void:
	var factory=View.new()
	var units: Dictionary=Humans.config().units
	var names: Dictionary=preload("res://data/economy.json").data.troops
	var world:=Node3D.new();root.add_child(world)
	var cam:=Camera3D.new();cam.fov=30;world.add_child(cam)
	var label:Label
	if out_dir!="":
		var env:=WorldEnvironment.new();var e:=Environment.new();var sky:=Sky.new();sky.sky_material=ProceduralSkyMaterial.new();e.background_mode=Environment.BG_SKY;e.sky=sky
		e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("aeb8c4");e.ambient_light_energy=0.6;e.tonemap_mode=Environment.TONE_MAPPER_ACES;e.tonemap_exposure=0.85;env.environment=e;world.add_child(env)
		var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,30,0);sun.light_color=Color("fff1dc");sun.shadow_enabled=true;sun.directional_shadow_max_distance=15;world.add_child(sun)
		var ground:=MeshInstance3D.new();var pm:=PlaneMesh.new();pm.size=Vector2(400,40);ground.mesh=pm
		var gm:=StandardMaterial3D.new();gm.albedo_texture=load("res://assets/ground/grass-color.webp");gm.uv1_scale=Vector3(140,14,1);gm.albedo_color=Color(0.72,0.78,0.62);ground.material_override=gm;world.add_child(ground)
		var ui:=CanvasLayer.new();world.add_child(ui);label=Label.new();label.position=Vector2(0,24);label.size=Vector2(1600,70);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",60);label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8));label.add_theme_constant_override("shadow_offset_x",3);label.add_theme_constant_override("shadow_offset_y",3);ui.add_child(label)
	var shots: Array=[];var dressed:=0;var checked:=0;var skipped: Array=[]
	var i:=0
	for kind in units:
		var info: Dictionary=factory.soldier_scene(kind,i%2)
		var model: Node3D=info.scene.instantiate();model.scale=Vector3.ONE*float(info.scale);world.add_child(model);model.position=Vector3(i*8.0,0,0);model.rotation.y=0.5
		factory.correct_soldier_materials(model,i%2)
		var ok:=Humans.dress_soldier(model,kind,i%2,Humans.stable_hash(kind),float(info.scale))
		if not ok:
			skipped.append(kind);model.queue_free();i+=1;continue
		dressed+=1
		var ap:AnimationPlayer=factory.animation_player(model)
		var anim:="attack" if ap!=null and ap.has_animation("attack") else ""
		if ap!=null and info.animated and anim!="":ap.play(anim);ap.seek(0.35,true);model.set_meta("soldier_anim",anim)
		elif not info.animated:preload("res://scripts/human_motion.gd").new().apply(model,1.0,false,"train");model.set_meta("soldier_anim","attack")
		await process_frame
		Humans.follow_soldier(model)
		await process_frame
		var src: Skeleton3D=model.get_meta("soldier_source");var rig=model.get_meta("soldier_rig")
		var hs:=src.find_bone("hand_R")
		if hs>=0 and rig!=null and model.find_child("SoldierGear",true,false)!=null:
			var a: Vector3=src.global_transform*src.get_bone_global_pose(hs).origin
			var hsk: Skeleton3D=rig.skeleton;var b: Vector3=hsk.global_transform*hsk.get_bone_global_pose(rig.index["hand_R"]).origin
			var d:=a.distance_to(b);checked+=1
			assert(d<0.22,"%s: uue inimese käsi on relvakäest liiga kaugel (%.2f m)" % [kind,d])
		shots.append([model,kind])
		i+=1
	print("SÕDUREID RIIETATUD: ",dressed," / ",units.size(),", käsi kontrollitud: ",checked,"; masinamudeliga (vana meeskond): ",skipped)
	assert(dressed>=25,"Jalaväe ja ratsaväe väeliigid peavad saama uue inimese")
	if out_dir!="":
		var cols:=6;var tw:=280;var th:=380;var rows:=ceili(shots.size()/float(cols));var sheet:=Image.create(tw*cols,th*rows,false,Image.FORMAT_RGBA8)
		for k in shots.size():
			var model: Node3D=shots[k][0];var kind: String=shots[k][1];var mounted:=model.find_child("SoldierGear",true,false)!=null and kind in ["knight","cavalry","heavy_cavalry","cuirassier","dragoon","bronze_cavalry","chariot"]
			var c:=model.global_position;var h:=2.7 if mounted else 1.8
			cam.position=c+Vector3(2.4,h*0.75,3.6)*(h/1.8);cam.look_at(c+Vector3(0,h*0.52,0))
			label.text=str(names.get(kind,{}).get("name",kind))
			for f in 3:await process_frame
			var img:=root.get_texture().get_image();img.convert(Image.FORMAT_RGBA8);var w:=img.get_width();var hh:=img.get_height()
			var crop:=img.get_region(Rect2i(w/2-int(hh*0.37),0,int(hh*0.74),hh));crop.resize(tw,th,Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(crop,Rect2i(0,0,tw,th),Vector2i((k%cols)*tw,(k/cols)*th))
		sheet.save_png(out_dir+"/sodurid.png");print("PILT sodurid")
	factory.free()
	print("HUMAN_SOLDIERS_OK");quit()
