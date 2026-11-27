extends Node

const InterfaceTheme = preload("res://scripts/interface_theme.gd")

const Mobile = preload("res://scripts/mobile_profile.gd")
const Human=preload("res://assets/people/human_far.glb")
const Motion=preload("res://scripts/human_motion.gd")
const Navigation=preload("res://scripts/local_navigation.gd")
const Grid=preload("res://scripts/campaign_grid.gd")
const Terrain=preload("res://scripts/detail_terrain.gd")
const HouseCollision=preload("res://scripts/house_collision.gd")
const Production=preload("res://scripts/production_bonuses.gd")
const Districts=preload("res://scripts/district_context.gd")
const SKY_SHADER=preload("res://scripts/walking_sky.gdshader")
const BuildLabel=preload("res://scripts/build_label.gd")
var host: Node
var active:=false
var placing:=false
var placed:=false
var tile:=Vector2i.ZERO
var pos:=Vector3.ZERO
var velocity:=Vector3.ZERO
var yaw:=0.54
var pitch:=-0.08
var vertical_speed:=0.0
var airborne:=false
var moving:=false
var bob:=0.0
var model: Node3D
var motion:=Motion.new()
var overlay: CanvasLayer
var bar: Control
var hint: PanelContainer
var names_button: TextureButton
var saved_camera: Dictionary={}
var walking_environment: Environment
var sky_material: ShaderMaterial
var walking_sky: Sky
var sky_hour: float=-1.0
var touch_move_id:=-1
var touch_look_id:=-1
var touch_origin:=Vector2.ZERO
var touch_movement:=Vector2.ZERO
var touch_look_last:=Vector2.ZERO
var touch_stick:Panel
var touch_knob:Panel

func _ready() -> void:
	model=Human.instantiate();model.name="FirstPersonWalker";model.scale=Vector3.ONE*1.66;model.visible=false;add_child(model)
	overlay=CanvasLayer.new();overlay.layer=20;add_child(overlay)
	bar=Control.new();bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;bar.visible=false;overlay.add_child(bar)
	bar.theme=InterfaceTheme.get_theme()
	var cross:=Label.new();cross.text="+";cross.add_theme_font_size_override("font_size",24);cross.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cross.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);cross.mouse_filter=Control.MOUSE_FILTER_IGNORE;bar.add_child(cross)
	var info := Label.new()
	info.text = "Liigu vasakul, vaata paremal." if Mobile.active else "WASD liigu · Shift jookse · Tühik hüppa · Tab vabasta hiir"
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	info.offset_left = 16
	info.offset_right = -170
	info.offset_top = 16
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_outline_color", Color("101820"))
	info.add_theme_constant_override("outline_size", 4)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(info)
	var buttons:=HBoxContainer.new()
	bar.add_child(buttons)
	buttons.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	buttons.offset_left=-175.0;buttons.offset_right=-16.0;buttons.offset_top=43.0
	buttons.add_theme_constant_override("separation",6)
	var version:=Label.new();version.name="GameVersion";version.text=BuildLabel.short_text(get_tree())
	version.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;version.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	version.offset_left=-178.0;version.offset_right=-24.0;version.offset_top=15.0
	version.add_theme_font_size_override("font_size",16);version.add_theme_color_override("font_outline_color",Color("101820"))
	version.add_theme_constant_override("outline_size",4);version.mouse_filter=Control.MOUSE_FILTER_IGNORE;bar.add_child(version)
	names_button=walking_button(buttons,"action_focus","Näita üksuste nimesid",func():
		host.game_hud.game_menu.set_graphics_value("names",not host.graphics_soldier_names)
		update_names_icon())
	update_names_icon()
	walking_button(buttons,"map_center","Paiguta ümber",func():exit_walking();placed=false;start())
	walking_button(buttons,"action_stop","Välju kõndimisest",exit_walking)
	hint=PanelContainer.new();hint.theme=InterfaceTheme.get_theme();hint.visible=false;overlay.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);hint.offset_left=-175;hint.offset_right=175;hint.offset_top=84
	var placement:=HBoxContainer.new();hint.add_child(placement)
	var instruction:=Label.new();instruction.text="Puuduta kaardil vaba kohta" if Mobile.active else "Klõpsa kaardil vaba kohta"
	instruction.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;instruction.size_flags_horizontal=Control.SIZE_EXPAND_FILL;placement.add_child(instruction)
	walking_button(placement,"action_stop","Katkesta paigutamine",cancel_placing)
	touch_stick=Panel.new();touch_stick.size=Vector2(110,110);touch_stick.mouse_filter=Control.MOUSE_FILTER_IGNORE;touch_stick.visible=false
	var ring:=StyleBoxFlat.new();ring.bg_color=Color(0.08,0.12,0.12,0.32);ring.border_color=Color(1,1,1,0.45);ring.set_border_width_all(2);ring.set_corner_radius_all(55);touch_stick.add_theme_stylebox_override("panel",ring);bar.add_child(touch_stick)
	touch_knob=Panel.new();touch_knob.size=Vector2(38,38);touch_knob.position=Vector2(36,36);touch_knob.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var knob_style:=StyleBoxFlat.new();knob_style.bg_color=Color(1,1,1,0.5);knob_style.set_corner_radius_all(19);touch_knob.add_theme_stylebox_override("panel",knob_style);touch_stick.add_child(touch_knob)

func walking_button(parent: Control,icon: String,description: String,action: Callable) -> TextureButton:
	var texture: Texture2D=load("res://assets/ui/ui-art-v303_"+icon+".webp")
	var button:=InterfaceTheme.icon_button(texture,description,action)
	button.custom_minimum_size=Vector2(47,47)
	parent.add_child(button)
	return button

func update_names_icon() -> void:
	names_button.tooltip_text="Peida üksuste nimed" if host.graphics_soldier_names else "Näita üksuste nimesid"
	names_button.accessibility_name=names_button.tooltip_text
	names_button.modulate=Color.WHITE if host.graphics_soldier_names else Color(0.76,0.76,0.76)

func start() -> void:
	if not host.detail_mode:host.update_status("Ava esmalt detailkaart.");return
	if host.battle_view!=null:host.update_status("Kõndimine ei ole lahingus saadaval.");return
	if active:exit_walking();return
	if placing:cancel_placing();return
	if placed and tile==current_tile():enter();return
	placing=true;hint.visible=true

func current_tile() -> Vector2i:
	if is_instance_valid(host.detail_root):return host.detail_root.tree_cell
	return host.selected if host.detail_inspection else host.player

func cancel_placing() -> void:
	placing=false;hint.visible=false

func place_at(x: float,z: float) -> bool:
	if blocked(x,z):host.update_status("Vali vaba koht avastatud alal.");return false
	pos=Vector3(x,ground_height(x,z),z);tile=tile_at(x,z);placed=true;cancel_placing();yaw=0.54;pitch=-0.08;host.zoom=45.0;enter();return true

func enter() -> void:
	if not placed:return
	active=true;velocity=Vector3.ZERO;vertical_speed=0;airborne=false;model.visible=false;bar.visible=true
	update_names_icon()
	saved_camera={"fov":host.camera.fov,"near":host.camera.near,"far":host.camera.far,"environment":host.camera.environment}
	host.camera.fov=68.0;host.camera.near=0.12;host.camera.far=720.0
	host.update_daylight()
	start_sky()
	var neighbors:=host.detail_root.get_node_or_null("NeighborTiles") as Node3D
	if neighbors!=null:neighbors.update_stream(Vector2(pos.x,pos.z),Vector2(-sin(yaw),-cos(yaw)))
	if is_instance_valid(host.game_hud):host.game_hud.visible=false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED);apply_camera()

func exit_walking(recenter:=true) -> void:
	if not active:return
	active=false;velocity=Vector3.ZERO;bar.visible=false;Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	host.camera.environment=saved_camera.get("environment")
	var neighbors:=host.detail_root.get_node_or_null("NeighborTiles") as Node3D
	if neighbors!=null:neighbors.stop_stream()
	touch_move_id=-1;touch_look_id=-1;touch_movement=Vector2.ZERO;touch_stick.visible=false
	if not saved_camera.is_empty():host.camera.fov=saved_camera.fov;host.camera.near=saved_camera.near;host.camera.far=saved_camera.far;saved_camera={}
	if is_instance_valid(host.game_hud):host.game_hud.visible=true
	host.camera_target=Vector3(pos.x,0,pos.z);host.zoom=minf(host.zoom,70.0)
	var shift:=tile-current_tile()
	if recenter and shift!=Vector2i.ZERO:
		if host.transition_detail_tile(tile,shift,true):shift_origin(Vector3(shift.x*225.0,0,shift.y*195.0))
		else:placed=false;host.camera_target=Vector3.ZERO
	sync_model();host.update_camera()

func start_sky() -> void:
	if sky_material==null:
		sky_material=ShaderMaterial.new();sky_material.shader=SKY_SHADER
		walking_sky=Sky.new();walking_sky.sky_material=sky_material;walking_sky.radiance_size=Sky.RADIANCE_SIZE_32
		walking_sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
	walking_environment=host.world_environment.environment.duplicate()
	walking_environment.sky=walking_sky
	walking_environment.background_mode=Environment.BG_SKY
	walking_environment.ambient_light_sky_contribution=0.0
	walking_environment.fog_enabled=true
	walking_environment.fog_mode=Environment.FOG_MODE_DEPTH
	walking_environment.fog_depth_begin=38.0
	walking_environment.fog_depth_end=470.0
	walking_environment.fog_depth_curve=1.55
	walking_environment.fog_density=0.86
	walking_environment.fog_sky_affect=0.0
	host.camera.environment=walking_environment
	sky_hour=-1.0
	update_sky()

func update_sky() -> void:
	if not active or walking_environment==null:return
	walking_environment.ambient_light_energy=host.world_environment.environment.ambient_light_energy
	walking_environment.ambient_light_color=host.world_environment.environment.ambient_light_color
	var hour:=float(host.daylight_hour())
	if sky_hour>=0.0 and absf(hour-sky_hour)<0.02:return
	sky_hour=hour
	var altitude:=sin((hour-6.0)*PI/12.0)
	var daylight:=smoothstep(-0.14,0.34,altitude)
	var twilight:=1.0-smoothstep(0.025,0.41,absf(altitude))
	var horizon:=Color("202f47").lerp(Color("bacdd6"),daylight).lerp(Color("c28a68"),twilight*0.37)
	sky_material.set_shader_parameter("horizon",horizon)
	sky_material.set_shader_parameter("daylight",daylight)
	sky_material.set_shader_parameter("twilight",twilight)
	sky_material.set_shader_parameter("sun_direction",host.sunlight.position.normalized())
	var seed:=int(host.game.get("seed",0))
	var period:=float(host.elapsed)/1440.0
	var wind:=Vector2(period*.24,period*.11)
	sky_material.set_shader_parameter("weather_offset",Vector2(posmod(seed,829),posmod(seed,953))*.036+wind)
	walking_environment.fog_light_color=Color("1d2b43").lerp(Color("a3b9c0"),daylight).lerp(Color("ad8c83"),twilight*0.36)

func sync_model() -> void:
	model.position=pos;model.rotation.y=yaw+PI;model.visible=placed and not active and host.detail_mode and tile==current_tile()

func handle_input(event: InputEvent) -> bool:
	if placing:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:cancel_placing();return true
		if event is InputEventScreenTouch and event.pressed:
			var p: Variant=host.detail_point(event.position)
			if p!=null:place_at(float(p.x),float(p.z))
			return true
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			var p: Variant=host.detail_point(event.position)
			if p!=null:place_at(float(p.x),float(p.z))
			return true
		return false
	if not active:return false
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x<get_viewport().get_visible_rect().size.x*0.5 and touch_move_id<0:
				touch_move_id=event.index;touch_origin=event.position;touch_movement=Vector2.ZERO;touch_stick.position=touch_origin-Vector2(55,55);touch_knob.position=Vector2(36,36);touch_stick.visible=true
			elif touch_look_id<0:touch_look_id=event.index;touch_look_last=event.position
		else:
			if event.index==touch_move_id:touch_move_id=-1;touch_movement=Vector2.ZERO;touch_stick.visible=false
			if event.index==touch_look_id:touch_look_id=-1
		return true
	if event is InputEventScreenDrag:
		if event.index==touch_move_id:
			var delta:Vector2=event.position-touch_origin
			delta.x=clampf(delta.x,-50,50);delta.y=clampf(delta.y,-50,50)
			touch_movement=Vector2(delta.x,-delta.y)/50.0;touch_knob.position=Vector2(36,36)+delta
		elif event.index==touch_look_id:
			var delta:Vector2=event.position-touch_look_last;touch_look_last=event.position
			yaw-=delta.x*0.006;pitch=clampf(pitch-delta.y*0.005,-1.35,1.2);apply_camera()
		return true
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE:exit_walking();return true
			if event.keycode==KEY_TAB:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED);return true
			if event.keycode==KEY_SPACE and not airborne:vertical_speed=1.66*3.1;airborne=true
		return true
	if event is InputEventMouseMotion:
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:yaw-=event.relative.x*0.0024;pitch=clampf(pitch-event.relative.y*0.0022,-1.35,1.2);apply_camera()
		return true
	if event is InputEventMouseButton:
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return true
	return false

func pier_height(x: float,z: float) -> Variant:
	var dc:=floori((x+112.5)/225.0);var dr:=floori((z+97.5)/195.0);var at:=current_tile()+Vector2i(dc,dr);var best: Variant=null
	for parent in host.game.get("cities",[]):
		var city: Variant=Districts.existing(parent,at)
		if city==null:continue
		for building in city.economy.buildings:
			if building.get("type","") not in ["fisher","harbor"] or not building.get("ready",false) or float(building.get("hp",0))<=0:continue
			var bx:=float(building.x)+dc*225.0;var bz:=float(building.z)+dr*195.0
			if absf(x-bx)>35 or absf(z-bz)>35:continue
			var surface: Variant=HouseCollision.pier_surface(host.detail_root,building,Production.visual_age(host.game,int(city.team)),x,z,Vector2(dc*225.0,dr*195.0))
			if surface==null:continue
			var base:float=host.detail_rendered_height(bx,bz)
			if building.has("baseY"):
				if building.get("riverBankV276",false):
					var heights: Array=host.detail_root.heights if dc==0 and dr==0 else host.detail_pick_heights.get(str(at.x)+":"+str(at.y),[])
					if not heights.is_empty():base+=float(building.baseY)-Terrain.detail_height(heights,float(building.x),float(building.z))
				else:base=float(building.baseY)
			var height:=base+float(surface)
			if best==null or height>float(best):best=height
	return best

func ground_height(x: float,z: float) -> float:
	var height:float=host.detail_rendered_height(x,z);var pier: Variant=pier_height(x,z)
	if pier!=null:height=maxf(height,float(pier))
	return maxf(height,-0.78)

func shift_origin(shift: Vector3) -> void:
	pos-=shift

func tile_at(x: float,z: float) -> Vector2i:
	return current_tile()+Vector2i(floori((x+112.5)/225.0),floori((z+97.5)/195.0))

func blocked(x: float,z: float) -> bool:
	if not host.detail_mode:return true
	var center:=current_tile()
	var at:=tile_at(x,z)
	var offset:=at-center;var dc:=offset.x;var dr:=offset.y
	if at.x<0 or at.y<0 or at.x>=Grid.COLS or at.y>=Grid.ROWS:return true
	if not host.reveal_all and not host.game.explored[0].has(str(at.x)+":"+str(at.y)):return true
	var neighbors: Node=host.detail_root.get_node_or_null("NeighborTiles")
	if at!=center and (neighbors==null or not neighbors.can_enter(at)):return true
	for parent in host.game.get("cities",[]):
		var city: Variant=Districts.existing(parent,at)
		if city==null:continue
		for b in city.economy.buildings:
			if b.get("virtual",false) or float(b.get("hp",0))<=0 or b.type in ["bridge","field","pasture","road"]:continue
			var bounds: Variant=Navigation.clearance(b)
			if bounds!=null:
				var early:float=maxf(float(bounds.rx),float(bounds.rz))*2.0+35.0
				if absf(x-(float(b.x)+dc*225.0))>=early or absf(z-(float(b.z)+dr*195.0))>=early:continue
				var age:=Production.visual_age(host.game,int(city.team))
				var reach:float=maxf(maxf(float(bounds.rx),float(bounds.rz))*0.82+2.0,HouseCollision.reach(host.detail_root,b,age))
				if absf(x-(float(b.x)+dc*225.0))>=reach or absf(z-(float(b.z)+dr*195.0))>=reach:continue
				var hit:Variant=HouseCollision.hits(host.detail_root,b,age,x,z,Vector2(dc*225.0,dr*195.0))
				if hit==true:return true
				if hit==null and b.type not in ["woodgate","gatehouse"] and absf(x-(float(b.x)+dc*225.0))<float(bounds.rx)*0.82 and absf(z-(float(b.z)+dr*195.0))<float(bounds.rz)*0.82:return true
	return false

func step(dt: float,input: Vector2,run: bool) -> void:
	if not active:return
	dt=minf(dt,0.1)
	if input.length()>1:input=input.normalized()
	var speed:=1.66*(5.6 if run else 2.4)
	if pos.y< -0.45:speed*=0.54
	var forward:=Vector3(-sin(yaw),0,-cos(yaw));var side:=Vector3(cos(yaw),0,-sin(yaw))
	var want:=forward*input.y*speed+side*input.x*speed
	var neighbors: Node=host.detail_root.get_node_or_null("NeighborTiles")
	if neighbors!=null:
		var heading:=want.normalized() if not want.is_zero_approx() else forward
		neighbors.update_stream(Vector2(pos.x,pos.z),Vector2(heading.x,heading.z))
	velocity=velocity.lerp(want,1.0-exp(-dt*(2.0 if airborne else 12.0)));moving=velocity.length_squared()>0.04
	var nx:=pos.x+velocity.x*dt;var nz:=pos.z+velocity.z*dt
	if not blocked(nx,pos.z):pos.x=nx
	else:velocity.x=0
	if not blocked(pos.x,nz):pos.z=nz
	else:velocity.z=0
	var ground: float=ground_height(pos.x,pos.z)
	vertical_speed-=1.66*9.5*dt;pos.y+=vertical_speed*dt
	if pos.y<=ground:pos.y=ground;vertical_speed=0;airborne=false
	if moving and not airborne:bob+=dt*(13.0 if run else 8.5)
	tile=tile_at(pos.x,pos.z)
	var offset:=tile-current_tile()
	if maxi(absi(offset.x),absi(offset.y))>=3 and neighbors!=null and neighbors.can_enter(tile):
		host.transition_detail_tile(tile,offset,true)
	apply_camera()

func update(dt: float) -> void:
	if not active:
		if placed:sync_model();motion.apply(model,host.elapsed,false)
		return
	var input:=Vector2(int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))-int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),int(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))-int(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)))
	input+=touch_movement
	step(dt,input,Input.is_key_pressed(KEY_SHIFT) or touch_movement.length()>0.92)

func apply_camera() -> void:
	if not active:return
	var eye:=1.66*0.90+(sin(bob)*1.66*0.025 if moving and not airborne else 0.0)
	var position:=pos+Vector3(0,eye,0);var direction:=Vector3(-sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))
	host.camera.position=position;host.camera.look_at(position+direction,Vector3.UP)

func on_detail_closed() -> void:
	cancel_placing()
	if active:exit_walking(false)
	model.visible=false
