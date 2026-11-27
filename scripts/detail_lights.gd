extends Node3D

const Terrain=preload("res://scripts/detail_terrain.gd")
const LocalNav=preload("res://scripts/local_navigation.gd")
const Period=preload("res://scripts/house_period_styles.gd")
const Plan=preload("res://scripts/house_plan_geometry.gd")
const PlanCollision=preload("res://scripts/house_plan_collision.gd")
const Facade=preload("res://scripts/house_facade_details.gd")
const Fits=preload("res://data/building_fits.json")
const Rules=preload("res://data/build_rules.json")
const NIGHT_TINTS:=["ffab50","ffba75","ffce8c","ef9e5c","ffd099","f6d6ac","d1e6f7"]
const DOORS:={"house":[3.5,[1.25]],"hall":[4.5,[-2.05,2.05]],"market":[3.4,[-1.9,1.9]],"tavern":[3.1,[-1.55,1.55]],"barracks":[3.8,[-1.8,1.8]],"warehouse":[3.2,[-1.7,1.7]],"farm":[3.4,[1.45]],"lumber":[3.2,[1.45]],"quarry":[3.4,[1.45]],"mason":[3.1,[1.35]],"pottery_kiln":[3.0,[1.25]],"workshop":[3.2,[1.5]],"watchtower":[3.0,[1.35]],"stonetower":[3.1,[1.5]],"woodgate":[1.4,[-2.35,2.35]],"gatehouse":[1.5,[-2.55,2.55]],"harbor":[3.1,[1.3]],"port":[3.1,[1.4]],"library":[3.2,[-1.5,1.5]],"school":[3.1,[1.4]],"study":[3.0,[1.3]],"blacksmith":[3.0,[1.4]],"baker":[3.0,[1.3]],"mill":[3.0,[1.4]]}
var host: Node
var city_id:=0
var heights: Array=[]
var visual_heights:=PackedVector4Array()
var stamp: String=""
var fire_nodes: Array=[]
var lights: Array=[]
var update_clock:=0.0
static var glow_texture: ImageTexture

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

static func period_entry(building: Dictionary, age: int) -> Dictionary:
	var type:=str(building.type)
	var id:=Period.designer_id(type,maxi(age,int(Rules.data.age.get(type,0))))
	var design: Dictionary=building.get("houseDesignV354",{})
	var saved_id:=str(design.get("id",""))
	if saved_id.get_slice("@",0)==type and Fits.data.has(saved_id):
		id=saved_id
	else:
		design=Period.get_plan(id)
	if design.is_empty() or not Fits.data.has(id):
		return {}
	var geometry:=Plan.plan_geometry(design)
	for opening in design.get("openings",[]):
		if opening.get("type","")!="door" or opening.get("group","")!="outer":
			continue
		var point:=Plan.point(opening.point)
		var nearby:=Plan.nearest_wall(point,geometry.walls,20.0)
		if nearby.is_empty() or nearby.edge.group!="outer":
			continue
		var fit: Dictionary=Fits.data[id]
		var normal:=Facade.exterior(nearby.edge,geometry.floors)
		var direction:=Vector2(-normal.y,normal.x)
		var local_point: Vector2=(nearby.point-PlanCollision.origin(design))/Plan.PX_PER_M
		local_point=local_point*Vector2(fit.scale[0],fit.scale[2])+Vector2(fit.offset[0],fit.offset[2])
		if type=="house" and int(building.get("houseUpgradeLevelV218",0))>=1:local_point*=Vector2(1.12,1.10)
		return {"point":local_point,"normal":normal,"axis":direction,"angle":atan2(normal.x,normal.y),"coastYaw":Period.coast_yaw(design) if building.has("shoreAngle") else 0.0}
	return {}

static func valid_site(sites: Array, point:Vector2) -> bool:
	for site in sites:
		if point.distance_squared_to(Vector2(site.x,site.z))<1.0:
			return false
	return true

static func locations(buildings: Array,use_clearance:=false,age:=0) -> Array:
	var ranked: Array=[]
	for i in buildings.size():ranked.append({"building":buildings[i],"index":i})
	ranked.sort_custom(func(a,b):
		var pa:=priority(str(a.building.get("type","")));var pb:=priority(str(b.building.get("type","")))
		return pa<pb if pa!=pb else int(a.index)<int(b.index))
	var sites: Array=[]
	for entry in ranked:
		var b: Dictionary=entry.building
		if b.get("virtual",false) or float(b.get("hp",0))<=0 or not b.get("ready",true) or not b.has("x") or not b.has("z"):continue
		var angle:=float(b.get("buildingRotationV228",b.get("wallAngleV175",PI/2 if b.get("wallAxis",false) else 0)))
		if age>0:
			var entryway:=period_entry(b,age)
			if not entryway.is_empty():
				angle+=float(entryway.get("coastYaw",0.0))
				var positions: Array=[-1.0,1.0] if b.type in ["hall","barracks","gatehouse","market","harbor","warehouse"] else [1.0]
				for side in positions:
					var local_point: Vector2=entryway.point+entryway.normal*(0.83 if age>=4 else 0.52)+entryway.axis*float(side)*(1.16 if age>=4 else 0.95)
					var point:=Vector2(float(b.x),float(b.z))+local_point.rotated(-angle)
					if not valid_site(sites,point):continue
					sites.append({"x":point.x,"z":point.y,"kind":b.type,"doorX":b.x,"doorZ":b.z,"angle":angle+float(entryway.angle)})
					if sites.size()>=22:return sites
				continue
		if not DOORS.has(b.type):continue
		var door: Array=DOORS[b.type]
		var bounds: Variant=LocalNav.clearance(b) if use_clearance else null
		for dx in door[1]:
			var dz: float=maxf(float(door[0]),float(bounds.rz)+0.6) if bounds!=null else float(door[0])
			var lx: float=signf(float(dx))*minf(maxf(0.9,absf(float(dx))),maxf(0.9,float(bounds.rx)*0.6)) if bounds!=null else float(dx)
			var x:=float(b.x)+lx*cos(angle)+dz*sin(angle);var z:=float(b.z)-lx*sin(angle)+dz*cos(angle)
			var too_close:=false
			for site in sites:
				if Vector2(x,z).distance_to(Vector2(site.x,site.z))<1.0:too_close=true;break
			if too_close:continue
			sites.append({"x":x,"z":z,"kind":b.type,"doorX":b.x,"doorZ":b.z,"angle":angle})
			if sites.size()>=22:return sites
	return sites

static func priority(kind: String) -> int:
	return 0 if kind in ["woodgate","gatehouse","hall"] else 1 if kind=="house" else 2

func setup(owner: Node,id: int,tile_heights: Array,visual:=PackedVector4Array()) -> void:
	host=owner;city_id=id;heights=tile_heights;visual_heights=visual

func _process(delta: float) -> void:
	if host==null:return
	update_clock+=delta
	var city: Dictionary={}
	for candidate in host.game.get("cities",[]):
		if int(candidate.id)==city_id:city=candidate;break
	if city.is_empty():return
	if update_clock>=1.0 or stamp.is_empty():
		update_clock=0
		var age:=int(host.game.ages[clampi(int(city.team),0,3)])
		var building_stamp: Array=[]
		for b in city.economy.buildings:building_stamp.append([b.get("type"),b.get("x"),b.get("z"),b.get("buildingRotationV228"),b.get("wallAxis"),b.get("ready"),float(b.get("hp",0))>0,hash(b.get("houseDesignV354",{}))])
		var next:=str(age)+str(building_stamp)
		if next!=stamp:stamp=next;rebuild(city.economy.buildings,age)
	var hour:=fposmod(8.0+float(host.game.time)/60.0,24.0);var elevation:=sin((hour-6.0)*PI/12.0)
	var daylight:=clampf((elevation+0.09)/0.52,0,1);var power:=clampf((0.4-daylight)/0.36,0,1)
	for fire in fire_nodes:fire.visible=power>0.04
	for i in lights.size():lights[i].light_energy=power*(0.95+0.05*sin(float(host.game.time)*9+i))

func rebuild(buildings: Array,age: int) -> void:
	for child in get_children():child.queue_free()
	fire_nodes.clear();lights.clear()
	var kind:=fixture(age);var path: String="res://assets/world/city_lights/"+kind+".glb"
	if not ResourceLoader.exists(path):return
	var scene: PackedScene=load(path);var sites:=locations(buildings,true,age)
	var lamp_tint:=Color(NIGHT_TINTS[clampi(age,0,6)])
	for i in sites.size():
		var site: Dictionary=sites[i];var root:=Node3D.new();root.position=Vector3(site.x,Terrain.visual_rendered_height(heights,visual_heights,site.x,site.z)+0.035,site.z);root.rotation.y=float(site.angle);add_child(root)
		root.add_child(scene.instantiate())
		var pos: Vector3={"stone_torch":Vector3(0.04,1.36,0),"torch":Vector3(0,2,0),"lantern":Vector3(0.46,2.2,0),"gas":Vector3(0,3.45,0),"electric":Vector3(1.45,6.05,0)}[kind]
		var flame:=Node3D.new();flame.position=pos;root.add_child(flame);fire_nodes.append(flame)
		var halo:=Sprite3D.new();halo.texture=glow();halo.pixel_size=(0.8 if kind=="stone_torch" else 1.5)/64.0
		halo.billboard=BaseMaterial3D.BILLBOARD_ENABLED;halo.shaded=false;halo.modulate=Color(1.0,0.83,0.59,0.8) if kind not in ["gas","electric"] else Color(1.0,0.95,0.82,0.8)
		halo.position.y=0.25;flame.add_child(halo)
		var pool:=MeshInstance3D.new();var ground:=PlaneMesh.new();ground.size=Vector2.ONE*(4.6 if kind=="stone_torch" else 7.0);pool.mesh=ground;pool.position=Vector3(pos.x,0.045,0)
		var pool_material:=StandardMaterial3D.new();pool_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;pool_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;pool_material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;pool_material.albedo_texture=glow();pool_material.albedo_color=Color(1.0,0.45,0.15,0.35) if age==0 else Color(lamp_tint.r,lamp_tint.g*0.69,lamp_tint.b*0.62,0.31);pool.material_override=pool_material;root.add_child(pool);fire_nodes.append(pool)
		if kind in ["gas","electric"]:
			var bulb:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=0.12 if kind=="gas" else 0.18;sphere.height=sphere.radius*2;bulb.mesh=sphere
			var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=lamp_tint;material.emission_enabled=true;material.emission=lamp_tint;material.emission_energy_multiplier=2.0;bulb.material_override=material;flame.add_child(bulb)
		else:
			var scale_factor:=0.62 if kind=="stone_torch" else 0.22 if kind=="lantern" else 1.4
			var material:=ShaderMaterial.new();material.shader=load("res://scripts/city_fire.gdshader")
			for part in 3:
				var mesh:=MeshInstance3D.new();var plane:=QuadMesh.new();plane.size=Vector2(0.5,1)*scale_factor;mesh.mesh=plane;mesh.position.y=0.5*scale_factor;mesh.rotation.y=part*PI/3;mesh.material_override=material;flame.add_child(mesh)
		if i<4:
			var light:=OmniLight3D.new();light.position=pos;light.light_color=lamp_tint;light.omni_range=15 if kind=="stone_torch" else 20;light.shadow_enabled=false;root.add_child(light);lights.append(light)
