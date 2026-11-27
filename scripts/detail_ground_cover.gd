extends Node3D

const Terrain=preload("res://scripts/detail_terrain.gd")
const Landscape=preload("res://scripts/detail_landscape.gd")
const Props=preload("res://scripts/detail_nature_props.gd")
const FRAME_ATTEMPTS:=320
const HIDDEN:=Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO)
static var meshes: Dictionary={}
static var work_frame: int=-1
static var frame_attempts:=0
var heights: Array=[]
var visual_heights:=PackedVector4Array()
var river_segments: Array=[]
var road_segments: Array=[]
var biome: String="grassland"
var seed_value:=0
var fraction:=1.0
var jobs: Array=[]
var small_jobs: Array=[]
var current:=0
var blockers: Array=[]
var woods:=false
var arid:=false
var cold:=false
var dry:=false

static func hash_value(a: float,b: float,c: float) -> float:
	var value:=sin(a*127.1+b*311.7+c*74.7)*43758.5453
	return value-floorf(value)

static func noise(x: float,z: float,seed: float) -> float:
	var ix:=floorf(x);var iz:=floorf(z);var fx:=x-ix;var fz:=z-iz
	var u:=fx*fx*(3-2*fx);var v:=fz*fz*(3-2*fz)
	return lerpf(lerpf(hash_value(ix,iz,seed),hash_value(ix+1,iz,seed),u),lerpf(hash_value(ix,iz+1,seed),hash_value(ix+1,iz+1,seed),u),v)

static func fbm(x: float,z: float,seed: float) -> float:
	return noise(x,z,seed)*0.6+noise(x*2.1,z*2.1,seed+7)*0.3+noise(x*4.3,z*4.3,seed+13)*0.1

static func mesh_for(name: String,variant:=0) -> Mesh:
	if name=="stump":return Props.stump()
	if name=="log":return Props.fallen_log()
	if name=="shrub":return Props.shrub()
	if name=="scree":return Props.scree()
	if name=="cactus":return Props.cactus(variant==1)
	if name in ["grass","tall","fern","reed"]:return Props.ground_plants(name)
	if meshes.has(name):return meshes[name]
	var path: String="res://assets/world/ground_cover/"+name+".glb"
	if not ResourceLoader.exists(path):return null
	var scene: Node=load(path).instantiate();var instance:=first_mesh(scene)
	if instance==null:scene.free();return null
	var mesh: Mesh=instance.mesh.duplicate()
	for index in mesh.get_surface_count():
		var source: Material=mesh.surface_get_material(index)
		if source is BaseMaterial3D:
			var material: BaseMaterial3D=source.duplicate();material.vertex_color_use_as_albedo=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.surface_set_material(index,material)
	meshes[name]=mesh;scene.free();return mesh

static func first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:return node
	for child in node.get_children():
		var found:=first_mesh(child)
		if found!=null:return found
	return null

func setup(c: int,r: int,visual_biome: String,tile_heights: Array,water: Array,share:=1.0,visual:=PackedVector4Array()) -> void:
	seed_value=(c*193+r*337)%20000;biome=visual_biome.trim_prefix("coastal_")
	heights=tile_heights;visual_heights=visual;river_segments=water;fraction=share
	process_priority=-5 if fraction>=0.25 else 0
	woods=biome in ["forest","taiga","jungle"];arid=biome in ["desert","mesa"];cold=biome in ["tundra","snow","snow_mountain"];dry=arid or cold or biome=="steppe"
	if biome in ["mountain","snow_mountain"]:
		add_job("scree",88 if biome=="snow_mountain" else 140)
		return
	var grass:=0.12 if arid else 0.24 if biome=="snow" else 0.55 if cold else 0.7 if biome=="jungle" else 1.0
	var tall:=0.05 if arid else 1.5 if biome=="steppe" else 0.2 if cold else 1.0
	var flower:=0.0 if arid else 0.2 if cold else 0.45 if biome=="steppe" else 1.25 if biome=="grassland" else 1.0
	add_job("grass",3400*grass);add_job("tall",520*tall)
	var flowers:=["f4f1e6","f2d24a","b58ad6","e6795c","8fb1e6","f3a6c4"]
	for k in flowers.size():add_job("flower_"+flowers[k],200*flower/6.0*(1.6 if k<2 else 0.8),k)
	add_job("stone",90*(2.2 if arid else 1.9 if cold else 2.0 if biome in ["mountain","snow_mountain","hills"] else 1.0))
	add_job("drybush" if arid else "shrub",52*(1.7 if woods or arid else 0.8 if cold else 0.6 if biome=="steppe" else 1.35 if biome=="grassland" else 1.0))
	if not dry:add_job("fern",50*(2.2 if woods else 0.6)*(1.6 if biome=="jungle" else 1.0))
	if not dry and not river_segments.is_empty():add_job("reed",86)
	if woods or biome in ["grassland","lush_river"]:
		var share_wood:=1.0 if woods else 0.35
		add_job("stump",14*share_wood);add_job("log",14*share_wood*0.6)
		if woods:add_job("mushroom",28)
	if arid:
		var cacti:=36.0*(1.2 if biome=="mesa" else 2.2)
		add_job("cactus",cacti*.47)
		add_job("cactus",cacti*.53,1)

func add_job(name: String,amount: float,variant: int=0) -> void:
	var target:=roundi(amount*fraction)
	if target<=0:
		if amount>0.0:small_jobs.append([name,amount,variant])
		return
	var mesh:=mesh_for(name,variant)
	if mesh==null:return
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=mesh;multi.instance_count=target;multi.visible_instance_count=0
	var node:=MultiMeshInstance3D.new();node.multimesh=multi;add_child(node)
	if name in ["grass","fern","reed"]:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jobs.append({"name":name,"amount":amount,"target":target,"count":0,"tries":0,"variant":variant,"multi":multi,"points":[],"transforms":[],"colors":[],"shown":PackedByteArray()})

func raise_density(share: float) -> void:
	if share<=fraction:return
	fraction=share
	process_priority=-5
	for job in jobs:
		var target:=roundi(float(job.amount)*fraction)
		if target<=int(job.target):continue
		var multi: MultiMesh=job.multi
		multi.instance_count=target
		for i in int(job.count):
			multi.set_instance_transform(i,job.transforms[i] if job.shown[i] else HIDDEN)
			multi.set_instance_color(i,job.colors[i])
		multi.visible_instance_count=int(job.count)
		job.target=target
	var pending:=small_jobs.duplicate()
	small_jobs.clear()
	for job in pending:add_job(job[0],job[1],job[2])
	current=0;set_process(true)

func _process(_delta: float) -> void:
	if current>=jobs.size():set_process(false);return
	var frame:=Engine.get_process_frames()
	if frame!=work_frame:work_frame=frame;frame_attempts=0
	var attempts:=mini(120,FRAME_ATTEMPTS-frame_attempts)
	var remaining:=attempts
	while remaining>0 and current<jobs.size():
		var job: Dictionary=jobs[current]
		if int(job.count)>=int(job.target) or int(job.tries)>=int(job.target)*6:
			current+=1;continue
		job.tries+=1;remaining-=1
		var name: String=job.name;var source_name: String="flower:#"+name.trim_prefix("flower_") if name.begins_with("flower_") else name
		var i: int=int(job.tries)+source_name.length()*977
		if name=="cactus":i+=int(job.variant)*1391
		var x: float=(hash_value(i,seed_value,1)-0.5)*221;var z: float=(hash_value(i,seed_value,2)-0.5)*191
		var meadow:=fbm(x/38,z/38,seed_value+11);var field:=chance(name,x,z,meadow,int(job.variant))
		if hash_value(i,seed_value,3)>field or blocked(Vector2(x,z)):continue
		var y:=Terrain.visual_rendered_height(heights,visual_heights,x,z)
		if y<0.25:continue
		var size:=scale_for(name,i);var yaw:=hash_value(i,seed_value,4)*TAU
		var transform:=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),Vector3(x,y,z))
		var multi: MultiMesh=job.multi;var n:=int(job.count);multi.set_instance_transform(n,transform)
		var tint:=0.85+hash_value(i,seed_value,12)*0.3
		var color:=Color(tint,tint,tint,1)
		if name in ["grass","tall","fern","shrub","reed"]:
			var sun_dried:=smoothstep(.48,.78,meadow)
			color=Color(.86*tint,1.02*tint,.91*tint).lerp(Color(1.12*tint,.94*tint,.71*tint),sun_dried)
			if cold:color=color.lerp(Color(.91*tint,.80*tint,.65*tint),.68)
		multi.set_instance_color(n,color);job.points.append(Vector2(x,z));job.transforms.append(transform);job.colors.append(color);job.shown.append(1);job.count=n+1;multi.visible_instance_count=n+1
	frame_attempts+=attempts-remaining

func chance(name: String,x: float,z: float,meadow: float,variant: int) -> float:
	match name:
		"grass":return 0.25+meadow*0.9
		"tall":return maxf(0,meadow-0.45)*2.4
		"stone","scree":return 0.15+maxf(0,fbm(x/30,z/30,seed_value+47)-0.4)*1.8
		"shrub","drybush":return 0.2+maxf(0,0.55-meadow)*1.5
		"fern":return 0.8 if woods else maxf(0,0.5-meadow)
		"reed":return .55+meadow*.45 if Landscape.near_water(Vector2(x,z),river_segments,1.57) else 0.0
		"cactus":return 0.3+maxf(0,fbm(x/30,z/30,seed_value+47)-0.35)
	if name.begins_with("flower_"):
		var drift:=fbm(x/22,z/22,seed_value+29)
		var group:=floori(fbm(x/45,z/45,seed_value+61+variant)*3)
		return maxf(0,drift-0.5)*3.2*(1.0 if group==1 else 0.25)
	return 0.7

func scale_for(name: String,i: int) -> float:
	if name in ["grass","tall"]:return 0.8+hash_value(i,seed_value,7 if name=="grass" else 8)*0.65
	if name.begins_with("flower_"):return 1.3+hash_value(i,seed_value,9)*0.8
	match name:
		"reed":return .72+hash_value(i,seed_value,18)*.71
		"stone":return 0.18+pow(hash_value(i,seed_value,11),3)*(1.6 if biome in ["mountain","snow_mountain","hills"] else 0.9)
		"scree":return .29+pow(hash_value(i,seed_value,11),2.8)*1.68
		"shrub":return 0.28+pow(hash_value(i,seed_value,13),1.8)*1.12
		"drybush":return 1.6+hash_value(i,seed_value,13)*1.4
		"fern":return 0.8+hash_value(i,seed_value,15)*0.9
		"stump":return 0.59+hash_value(i,seed_value,17)*0.72
		"log":return 0.7+hash_value(i,seed_value,18)*0.5
		"mushroom":return 1+hash_value(i,seed_value,19)
		"cactus":return 2.2+hash_value(i,seed_value,21)*2.2
	return 1.0

func blocked(point: Vector2) -> bool:
	if Landscape.near_water(point,river_segments):return true
	for segment in road_segments:
		var a: Vector2=segment[0];var end: Vector2=segment[1];var radius:=float(segment[2])
		if point.x<minf(a.x,end.x)-radius or point.x>maxf(a.x,end.x)+radius or point.y<minf(a.y,end.y)-radius or point.y>maxf(a.y,end.y)+radius:continue
		var line:=end-a
		var t:=clampf((point-a).dot(line)/maxf(0.0001,line.length_squared()),0,1)
		if point.distance_to(a+line*t)<radius:return true
	for rect in blockers:
		if absf(point.x-float(rect.x))<float(rect.rx) and absf(point.y-float(rect.z))<float(rect.rz):return true
	return false

func set_roads(segments: Array) -> void:
	if road_segments==segments:return
	road_segments=segments
	refresh_visibility()

func set_areas(areas: Array) -> void:
	if blockers==areas:return
	blockers=areas
	refresh_visibility()

func refresh_visibility() -> void:
	for job in jobs:
		var multi: MultiMesh=job.multi
		for i in job.points.size():
			var shown:=int(not blocked(job.points[i]))
			if shown==job.shown[i]:continue
			job.shown[i]=shown
			multi.set_instance_transform(i,job.transforms[i] if shown else HIDDEN)

func clear_area(x: float,z: float,rx: float,rz: float) -> void:
	var area:={"x":x,"z":z,"rx":rx,"rz":rz}
	if area in blockers:return
	blockers.append(area)
	for job in jobs:
		var multi: MultiMesh=job.multi
		for i in job.points.size():
			var p: Vector2=job.points[i]
			if job.shown[i] and absf(p.x-x)<rx and absf(p.y-z)<rz:
				job.shown[i]=0
				multi.set_instance_transform(i,HIDDEN)
