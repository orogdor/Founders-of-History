extends Node3D

const Terrain=preload("res://scripts/detail_terrain.gd")
const LocalNav=preload("res://scripts/local_navigation.gd")
const Buildings=preload("res://scripts/building_models.gd")
const Plan=preload("res://scripts/house_plan_geometry.gd")
const PlanCollision=preload("res://scripts/house_plan_collision.gd")
const DOORS:={"house":[3.5,[1.25]],"hall":[4.5,[-2.05,2.05]],"market":[3.4,[-1.9,1.9]],"tavern":[3.1,[-1.55,1.55]],"barracks":[3.8,[-1.8,1.8]],"warehouse":[3.2,[-1.7,1.7]],"farm":[3.4,[1.45]],"lumber":[3.2,[1.45]],"quarry":[3.4,[1.45]],"mason":[3.1,[1.35]],"pottery_kiln":[3.0,[1.25]],"workshop":[3.2,[1.5]],"watchtower":[3.0,[1.35]],"stonetower":[3.1,[1.5]],"woodgate":[1.4,[-2.35,2.35]],"gatehouse":[1.5,[-2.55,2.55]],"harbor":[3.1,[1.3]],"port":[3.1,[1.4]],"library":[3.2,[-1.5,1.5]],"school":[3.1,[1.4]],"study":[3.0,[1.3]],"blacksmith":[3.0,[1.4]],"baker":[3.0,[1.3]],"mill":[3.0,[1.4]]}
var host: Node
var city_id:=0
var site_tile:=Vector2i.ZERO
const Districts=preload("res://scripts/district_context.gd")
const Production=preload("res://scripts/production_bonuses.gd")
var heights: Array=[]
var visual_heights:=PackedVector4Array()
var stamp: String=""
var fire_nodes: Array=[]
var lights: Array=[]
var ground_light: ShaderMaterial
var emitters:=PackedVector3Array()
var light_camera:=Vector3(INF,INF,INF)
var following_camera:=false
var update_clock:=0.0
static var glow_texture: ImageTexture
static var stone_torch_mesh: ArrayMesh

static func glow() -> ImageTexture:
	if glow_texture!=null:return glow_texture
	var img:=Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d:=Vector2((x+0.5)/32.0-1.0,(y+0.5)/32.0-1.0).length()
			var a:=pow(clampf(1.0-d,0,1),2.2)
			img.set_pixel(x,y,Color(1.0,1.0,1.0,a))
	glow_texture=ImageTexture.create_from_image(img)
	return glow_texture

static func fixture(age: int) -> String:
	return "electric" if age>=6 else "gas" if age==5 else "lantern" if age==4 else "stone_torch" if age==0 else "torch"

static func stone_torch() -> MeshInstance3D:
	if stone_torch_mesh==null:
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var material:=StandardMaterial3D.new()
		material.vertex_color_use_as_albedo=true
		material.roughness=0.92
		material.metallic_specular=0.17
		surface.set_material(material)
		var staff:=CylinderMesh.new()
		staff.height=1.23
		staff.top_radius=.027
		staff.bottom_radius=.055
		staff.radial_segments=7
		staff.rings=1
		torch_piece(surface,staff,Transform3D(Basis(Vector3.FORWARD,.024),Vector3(.018,.613,0)),Color("644933"))
		var twig:=CylinderMesh.new()
		twig.height=.266
		twig.top_radius=.026
		twig.bottom_radius=.027
		twig.radial_segments=5
		twig.rings=0
		for i in 7:
			var turn:=float(i)*TAU/7.0
			var offset:=Vector3(cos(turn)*.05,0.0,sin(turn)*.05)
			var blackened:=Color("554334").lerp(Color("382e29"),float(i%4)/3.0)
			var lean:=Basis(Vector3.UP,turn)*Basis(Vector3.FORWARD,-.105)
			torch_piece(surface,twig,Transform3D(lean,Vector3(.04,1.211+.011*sin(i*4.17),0)+offset),blackened)
		var binding:=TorusMesh.new()
		binding.inner_radius=.058
		binding.outer_radius=.078
		binding.rings=9
		binding.ring_segments=6
		for i in 3:
			var position:=Vector3(.04,1.102+float(i)*.029,0)
			var wrap:=Basis(Vector3.RIGHT,.15+float(i)*.11)*Basis(Vector3.FORWARD,.09-float(i)*.11)
			torch_piece(surface,binding,Transform3D(wrap,position),Color("9b7957").darkened(float(i)*.073))
		stone_torch_mesh=surface.commit()
	var node:=MeshInstance3D.new()
	node.mesh=stone_torch_mesh
	return node

static func torch_piece(surface: SurfaceTool,primitive: PrimitiveMesh,pose: Transform3D,tint: Color) -> void:
	var arrays:=primitive.get_mesh_arrays()
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		var p: Vector3=points[index]
		var tone:=.93+.09*sin(p.x*46.0+p.z*33.0+p.y*10.0)
		surface.set_color(tint*Color(tone,tone,tone,1.0))
		surface.set_normal(pose.basis*normals[index])
		surface.add_vertex(pose*p)

static func locations(buildings: Array,use_clearance:=false,age:=-1) -> Array:
	var ranked: Array=[]
	for i in buildings.size():ranked.append({"building":buildings[i],"index":i})
	ranked.sort_custom(func(a,b):
		var pa:=priority(str(a.building.get("type","")));var pb:=priority(str(b.building.get("type","")))
		return pa<pb if pa!=pb else int(a.index)<int(b.index))
	var sites: Array=[]
	for entry in ranked:
		var b: Dictionary=entry.building
		if b.get("virtual",false) or float(b.get("hp",0))<=0 or not b.get("ready",true) or not b.has("x") or not b.has("z"):continue
		var offsets: Array[Vector2]=[]
		if age==0 and b.type in ["house","hunter"]:
			offsets=round_house_lights(b)
		if offsets.is_empty() and DOORS.has(b.type):
			var door: Array=DOORS[b.type]
			var bounds: Variant=LocalNav.clearance(b) if use_clearance else null
			for dx in door[1]:
				var dz: float=maxf(float(door[0]),float(bounds.rz)+0.6) if bounds!=null else float(door[0])
				var lx: float=signf(float(dx))*minf(maxf(0.9,absf(float(dx))),maxf(0.9,float(bounds.rx)*0.6)) if bounds!=null else float(dx)
				offsets.append(Vector2(lx,dz))
		var angle:=float(b.get("buildingRotationV228",b.get("wallAngleV175",PI/2 if b.get("wallAxis",false) else 0)))
		for offset in offsets:
			var position:=Vector2(float(b.x),float(b.z))+offset.rotated(-angle)
			var x:=position.x
			var z:=position.y
			var too_close:=false
			for site in sites:
				if Vector2(x,z).distance_to(Vector2(site.x,site.z))<1.0:too_close=true;break
			if too_close:continue
			sites.append({"x":x,"z":z,"kind":b.type,"doorX":b.x,"doorZ":b.z,"angle":angle})
			if sites.size()>=22:return sites
	return sites

static func round_house_lights(building: Dictionary) -> Array[Vector2]:
	var offsets: Array[Vector2]=[]
	var spec:=Buildings.specification(str(building.type),0,building.get("houseDesignV354",{}),1)
	var plan: Dictionary=spec.plan
	var rooms: Array=plan.get("rooms",[])
	if rooms.size()!=1 or rooms[0].type!="round":return offsets
	var origin:=PlanCollision.origin(plan)
	var center:=Plan.point(rooms[0].a)
	var fit: Dictionary=spec.fit
	for door in plan.get("openings",[]):
		if door.type!="door" or door.get("group","")!="outer":continue
		var point:=Plan.point(door.point)
		var normal: Vector2=(point-center).normalized()
		var side:=Vector2(normal.y,-normal.x)
		var at: Vector2=(point-origin)/Plan.PX_PER_M+normal*0.98+side*1.18
		if not fit.is_empty():at=at*Vector2(fit.scale[0],fit.scale[2])+Vector2(fit.offset[0],fit.offset[2])
		offsets.append(at)
	return offsets

static func priority(kind: String) -> int:
	return 0 if kind in ["woodgate","gatehouse","hall"] else 1 if kind=="house" else 2

func setup(owner: Node,id: int,tile: Vector2i,tile_heights: Array,visual:=PackedVector4Array()) -> void:
	host=owner;city_id=id;site_tile=tile;heights=tile_heights;visual_heights=visual

static func local_context(cities: Array,id: int,tile: Vector2i) -> Dictionary:
	for parent in cities:
		if int(parent.id)==id:
			var context: Variant=Districts.existing(parent,tile)
			return context if context is Dictionary else {}
	return {}

func _process(delta: float) -> void:
	if host==null:return
	update_clock+=delta
	if update_clock>=1.0 or stamp.is_empty():
		update_clock=0
		var city:=local_context(host.game.get("cities",[]),city_id,site_tile)
		if city.is_empty():
			if stamp!="vacant":stamp="vacant";rebuild([],0)
			return
		var age:=Production.visual_age(host.game,int(city.team))
		var building_stamp: Array=[]
		for b in city.economy.buildings:building_stamp.append([b.get("type"),b.get("x"),b.get("z"),b.get("buildingRotationV228"),b.get("wallAxis"),b.get("ready"),b.get("virtual",false),float(b.get("hp",0))>0,hash(b.get("houseDesignV354",{})) if age==0 and b.type in ["house","hunter"] else 0])
		var next:=str(age)+str(building_stamp)
		if next!=stamp:stamp=next;rebuild(city.economy.buildings,age)
	var hour:=host.daylight_hour() as float;var elevation:=sin((hour-6.0)*PI/12.0)
	var daylight:=clampf((elevation+0.09)/0.52,0,1);var power:=clampf((0.4-daylight)/0.36,0,1)
	for fire in fire_nodes:fire.visible=power>0.04
	if ground_light!=null:ground_light.set_shader_parameter("power",power)
	if power>0.04:follow_nearby_torches()
	for i in lights.size():lights[i].light_energy=power*(0.91+0.055*sin(float(host.game.time)*7+i)+0.027*sin(float(host.game.time)*13.3-i))

func follow_nearby_torches() -> void:
	if emitters.size()<=lights.size() or not is_instance_valid(host.camera):return
	var walking: bool=is_instance_valid(host.fpv_walker) and host.fpv_walker.active
	var at:=to_local(host.camera.global_position)
	if walking==following_camera and (not walking or at.distance_squared_to(light_camera)<6.25):return
	following_camera=walking
	light_camera=at
	var order:=range(emitters.size())
	if walking:
		var distances:=PackedFloat32Array()
		for location in emitters:distances.append(location.distance_squared_to(at))
		order.sort_custom(func(a,b):return distances[a]<distances[b] if distances[a]!=distances[b] else a<b)
	for i in lights.size():lights[i].position=emitters[order[i]]

func make_ground_light(center: Vector2,radius: float,fixture_height: float,phase: float) -> MeshInstance3D:
	const STEPS:=10
	var vertices:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var phases:=PackedColorArray()
	var indices:=PackedInt32Array()
	for y in range(STEPS+1):
		for x in range(STEPS+1):
			var uv:=Vector2(x,y)/float(STEPS)
			var at:=center+(uv*2.0-Vector2.ONE)*radius
			vertices.append(Vector3(at.x,Terrain.visual_rendered_height(heights,visual_heights,at.x,at.y)+0.026,at.y))
			uvs.append(uv)
			phases.append(Color(phase,fixture_height/7.0,0,1))
			if x<STEPS and y<STEPS:
				var i:=y*(STEPS+1)+x
				var below:=i+STEPS+1
				indices.append_array(PackedInt32Array([i,i+1,below,i+1,below+1,below]))
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_COLOR]=phases
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var pool:=MeshInstance3D.new()
	pool.mesh=mesh
	pool.material_override=ground_light
	pool.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pool

func rebuild(buildings: Array,age: int) -> void:
	for child in get_children():child.queue_free()
	fire_nodes.clear();lights.clear()
	emitters.clear();light_camera=Vector3(INF,INF,INF);following_camera=false
	if buildings.is_empty():return
	var kind:=fixture(age);var path: String="res://assets/world/city_lights/"+kind+".glb"
	if kind!="stone_torch" and not ResourceLoader.exists(path):return
	var scene: PackedScene=load(path) if kind!="stone_torch" else null
	var sites:=locations(buildings,true,age)
	var clean_light:=kind in ["gas","electric"]
	ground_light=ShaderMaterial.new()
	ground_light.shader=preload("res://scripts/torch_ground.gdshader")
	ground_light.set_shader_parameter("glow_color",Color("ffead1") if clean_light else Color("ffd09a"))
	ground_light.set_shader_parameter("flicker",0.0 if clean_light else 1.0)
	var fire_material:=ShaderMaterial.new()
	fire_material.shader=preload("res://scripts/city_fire.gdshader")
	for i in sites.size():
		var site: Dictionary=sites[i];var root:=Node3D.new();root.position=Vector3(site.x,Terrain.visual_rendered_height(heights,visual_heights,site.x,site.z)+0.035,site.z);root.rotation.y=float(site.angle);add_child(root)
		root.add_child(stone_torch() if kind=="stone_torch" else scene.instantiate())
		var pos: Vector3={"stone_torch":Vector3(0.04,1.36,0),"torch":Vector3(0,2,0),"lantern":Vector3(0.46,2.2,0),"gas":Vector3(0,3.45,0),"electric":Vector3(1.45,6.05,0)}[kind]
		var emitter: Vector3=root.position+pos.rotated(Vector3.UP,float(site.angle))
		emitters.append(emitter)
		var flame:=Node3D.new();flame.position=pos;root.add_child(flame);fire_nodes.append(flame)
		var halo:=Sprite3D.new();halo.texture=glow();halo.pixel_size=(0.8 if kind=="stone_torch" else 1.5)/64.0
		halo.billboard=BaseMaterial3D.BILLBOARD_ENABLED;halo.shaded=false;halo.modulate=Color(1.0,0.77,0.48,0.46) if not clean_light else Color(1.0,0.93,0.79,0.55)
		halo.position.y=0.25;flame.add_child(halo)
		var offset:=pos.rotated(Vector3.UP,float(site.angle))
		var pool:=make_ground_light(Vector2(site.x+offset.x,site.z+offset.z),3.4 if kind=="stone_torch" else 4.8,pos.y,float(i)/22.0)
		add_child(pool);fire_nodes.append(pool)
		if clean_light:
			var bulb:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=0.12 if kind=="gas" else 0.18;sphere.height=sphere.radius*2;bulb.mesh=sphere
			var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("fff1da");material.emission_enabled=true;material.emission=Color("fff1da");material.emission_energy_multiplier=2.0;bulb.material_override=material;flame.add_child(bulb)
		else:
			var scale_factor:=0.62 if kind=="stone_torch" else 0.22 if kind=="lantern" else 1.4
			for part in 3:
				var mesh:=MeshInstance3D.new();var plane:=QuadMesh.new();plane.size=Vector2(0.5,1)*scale_factor;mesh.mesh=plane;mesh.position.y=0.5*scale_factor;mesh.rotation.y=part*PI/3;mesh.material_override=fire_material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;flame.add_child(mesh)
		if i<4:
			var light:=OmniLight3D.new();light.position=emitter;light.light_color=Color("fff1da") if clean_light else Color("ffc692");light.omni_range=12 if kind=="stone_torch" else 19;light.omni_attenuation=1.65;light.shadow_enabled=false;add_child(light);lights.append(light)
