extends RefCounted

const Models=preload("res://scripts/building_models.gd")
const Placement=preload("res://scripts/building_placement.gd")
const Navigation=preload("res://scripts/local_navigation.gd")
const SKIP=["road","bridge"]

static func drawable(building: Dictionary) -> bool:
	return Placement.alive(building) and building.type not in SKIP

static func stamp(buildings: Array,age: int,neighbors: Array=[]) -> int:
	var data:Array=[age]
	for building in buildings:
		if drawable(building):data.append(Placement.stamp(building))
	for building in neighbors:data.append(Placement.stamp(building))
	return hash(data)

static func clearances(buildings: Array,origin: Vector2) -> Array:
	var result:Array=[]
	var projection:=Vector2(50.0/225.0,50.0/195.0)
	for building in buildings:
		if not drawable(building):continue
		var center:=Vector2(building.x,building.z)
		if building.type in Placement.Walls:
			var ends:=Placement.wall_endpoints(building)
			var steps:=maxi(1,ceili(ends[0].distance_to(ends[1])/5.0))
			for i in steps+1:
				var point:=origin+ends[0].lerp(ends[1],float(i)/steps)*projection
				result.append({"x":point.x,"z":point.y,"r":1.6})
		else:
			var bounds:Variant=Navigation.clearance(building)
			var radius:=2.0 if bounds==null else clampf(maxf(float(bounds.rx),float(bounds.rz))*0.34,1.6,5.0)
			var point:=origin+center*projection
			if building.type=="field":
				radius=clampf(maxf(float(building.get("width",16))*projection.x,float(building.get("depth",16))*projection.y)*0.5,1.6,9.0)
			result.append({"x":point.x,"z":point.y,"r":radius})
	return result

static func build(buildings: Array,age: int,origin: Vector3,height: Callable,neighbors: Array=[]) -> Node3D:
	var root:=Node3D.new()
	root.name="TownBuildings"
	var groups:Dictionary={}
	var base:=float(height.call(origin))
	var ground:=func(x: float,z: float) -> float:return float(height.call(origin+Vector3(x,0,z)))-base
	var defenses:=buildings.filter(func(b):return Placement.alive(b) and Placement.is_defense(b))
	defenses.append_array(neighbors)
	var scale:=Placement.WORLD_SCALE
	for building in buildings:
		if not drawable(building):continue
		var type:String=building.type
		var mesh:=Models.simplified_mesh(type,age,building.get("houseDesignV354",{}),int(building.get("woodFortTierV1757",1)))
		if mesh==null:continue
		var progress:=1.0 if building.get("ready",false) else 0.32
		if type in Placement.Walls:
			var ends:=Placement.joined_endpoints(building,defenses)
			Models.add_instance(groups,mesh,Placement.wall_transform(building,ends,mesh.get_aabb(),scale,ground,progress))
			var cap:=Placement.cap_mesh(building)
			for end in ends:Models.add_instance(groups,cap,Placement.cap_transform(end,scale,ground,cap,progress))
		else:
			var y:float=ground.call(float(building.x)*scale.x,float(building.z)*scale.z)
			var exaggeration:=1.0 if Placement.is_defense(building) else 1.24
			Models.add_instance(groups,mesh,Placement.building_transform(building,scale,y,progress,exaggeration))
	Models.add_batches(root,groups,false)
	return root
