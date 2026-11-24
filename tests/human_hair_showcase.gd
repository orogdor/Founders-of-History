extends SceneTree
## Kõik soengud ja habemed peakujutistena: godot --path . --resolution 1600x900 -s tests/human_hair_showcase.gd -- <kaust>
const Humans=preload("res://scripts/human_factory.gd")
const Motion=preload("res://scripts/human_motion.gd")
var out_dir:="/tmp"
func _initialize() -> void:
	var a:=OS.get_cmdline_user_args();if a.size()>0:out_dir=a[0]
	call_deferred("run")
func run() -> void:
	var items: Dictionary=Humans.config().items
	var looks: Array=[]
	var men: Dictionary={}
	for e in Humans.config().eras:
		for id in e.hair.man:men[id]=true
	for id in items:
		if str(items[id].slot)=="hair":looks.append(["man" if men.has(id) else "woman",[id],str(items[id].name)])
	for id in items:
		if str(items[id].slot)=="beard":looks.append(["man",["mh_short02",id],str(items[id].name)])
	var env:=WorldEnvironment.new();var e:=Environment.new();var sky:=Sky.new();var sm:=ProceduralSkyMaterial.new();sky.sky_material=sm;e.background_mode=Environment.BG_SKY;e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("aeb8c4");e.ambient_light_energy=0.6;e.tonemap_mode=Environment.TONE_MAPPER_ACES;e.tonemap_exposure=0.85;env.environment=e;root.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,35,0);sun.light_color=Color("fff1dc");sun.shadow_enabled=true;root.add_child(sun)
	var cam:=Camera3D.new();cam.fov=24;root.add_child(cam)
	var ui:=CanvasLayer.new();root.add_child(ui);var label:=Label.new();label.position=Vector2(0,20);label.size=Vector2(1600,60);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",54);label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8));label.add_theme_constant_override("shadow_offset_x",3);label.add_theme_constant_override("shadow_offset_y",3);ui.add_child(label)
	var cols:=6;var tw:=300;var th:=300;var rows:=ceili(looks.size()/float(cols));var sheet:=Image.create(tw*cols,th*rows,false,Image.FORMAT_RGBA8)
	for i in looks.size():
		var look: Array=looks[i];var ids: Array=look[1].duplicate();ids.append("mod_tshirt" if look[0]=="man" else "mod_blouse")
		var p:=Humans.create_with_items(look[0],ids,40+i);p.scale=Vector3.ONE*1.66;root.add_child(p);p.rotation.y=0.55
		var m:=Motion.new();for f in 2:m.apply(p,2.0,false,"");await process_frame
		var hy:=1.68 if look[0]=="man" else 1.5
		cam.position=Vector3(0.15,hy+0.05,1.25);cam.look_at(Vector3(0,hy-0.05,0));label.text=look[2]
		for f in 3:await process_frame
		var img:=root.get_texture().get_image();img.convert(Image.FORMAT_RGBA8)
		var w:=img.get_width();var h:=img.get_height();var crop:=img.get_region(Rect2i(w/2-h/2,0,h,h));crop.resize(tw,th,Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(crop,Rect2i(0,0,tw,th),Vector2i((i%cols)*tw,(i/cols)*th))
		p.queue_free();await process_frame
	sheet.save_png(out_dir+"/soengud.png");print("PILT soengud ",looks.size());quit()
