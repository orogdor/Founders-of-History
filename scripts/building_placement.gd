extends RefCounted

const Walls=["palisade","stonewall","reinforced_wall"]
const Gates=["woodgate","gatehouse"]
const Towers=["watchtower","stonetower"]
const WORLD_SCALE:=Vector3(2.0/225.0,0.034,2.0/195.0)
const TILE_SIZE:=Vector2(225.0,195.0)
const JOINT_LIMIT:=0.90
const WALL_PIERCE:=0.13
static var caps:Dictionary={}

static func angle(building: Dictionary) -> float:
	var default_angle:=PI/2.0 if building.get("wallAxis",false) and building.type in Walls+Gates else 0.0
	for key in ["buildingRotationV228","wallAngleV175","shoreAngle"]:
		if building.get(key)!=null:return float(building[key])
	return default_angle

static func alive(building: Dictionary) -> bool:
	return not building.get("virtual",false) and float(building.get("hp",0))>0

static func is_defense(building: Dictionary) -> bool:
	return building.type in Walls+Gates+Towers

static func stamp(building: Dictionary) -> Array:
	return [building.type,building.get("x",0),building.get("z",0),angle(building),building.get("ready",false),alive(building),
		building.get("palisadeSpanV167",0),building.get("extendedPalisadeV166",false),
		building.get("cliffEmbedStartV179",0),building.get("cliffEmbedEndV179",0),
		building.get("woodFortTierV1757",1),building.get("houseUpgradeLevelV218",0),
		building.get("houseDesignV354",{}),building.get("width",0),building.get("depth",0),
		building.get("baseY"),building.get("riverBankV276",false)]

static func wall_endpoints(building: Dictionary) -> Array[Vector2]:
	var turn:=angle(building)
	var axis:=Vector2(cos(turn),-sin(turn))
	var middle:=Vector2(float(building.x),float(building.z))
	var default_span:=14.0 if building.get("extendedPalisadeV166",false) else 7.0
	var half:=float(building.get("palisadeSpanV167",default_span))*0.5
	return [middle-axis*half,middle+axis*half]

static func joined_endpoints(building: Dictionary,other_buildings: Array) -> Array[Vector2]:
	var ends:=wall_endpoints(building)
	var axis:=ends[0].direction_to(ends[1])
	for i in 2:
		var point:=ends[i]
		var outward:=axis if i==1 else -axis
		var best:=INF
		for other:Dictionary in other_buildings:
			if is_same(building,other) or not alive(other):continue
			var center:=Vector2(other.x,other.z)
			if other.type in Walls:
				var other_ends:=wall_endpoints(other)
				var direction:=other_ends[0].direction_to(other_ends[1])
				for k in 2:
					var distance:=point.distance_squared_to(other_ends[k])
					var other_outward:=direction if k==1 else -direction
					if distance>JOINT_LIMIT*JOINT_LIMIT or distance>=best or outward.dot(other_outward)>0.82:continue
					ends[i]=point.lerp(other_ends[k],0.5);best=distance
			elif other.type in Gates+Towers and point.distance_squared_to(center)<90:
				var distance:=attachment_distance(other,point,outward)
				if distance<-0.8 or distance>3.8 or distance*distance>=best:continue
				best=distance*distance
				ends[i]=point+outward*(distance+2.0*WALL_PIERCE)
		ends[i]+=outward*WALL_PIERCE
	ends[0]-=axis*float(building.get("cliffEmbedStartV179",0))
	ends[1]+=axis*float(building.get("cliffEmbedEndV179",0))
	return ends

static func attachment_distance(building: Dictionary,point: Vector2,direction: Vector2) -> float:
	var rotation:=angle(building)
	var relative:=(point-Vector2(building.x,building.z)).rotated(rotation)
	var ray:=direction.rotated(rotation)
	var bounds:=Vector2(1.60,2.12) if building.type=="watchtower" else Vector2(4.85,2.52)
	if building.type in Gates:
		if absf(ray.x)<0.72:return INF
		var half:=5.35 if building.type=="gatehouse" else 3.5
		if building.get("extendedPalisadeV166",false):half*=2.0
		var distance:=(-signf(ray.x)*half-relative.x)/ray.x
		return distance if absf(relative.y+distance*ray.y)<0.85 else INF
	var first:=-INF
	var last:=INF
	for axis in 2:
		if absf(ray[axis])<0.001:
			if absf(relative[axis])>bounds[axis]:return INF
			continue
		var a:=(-bounds[axis]-relative[axis])/ray[axis]
		var b:=(bounds[axis]-relative[axis])/ray[axis]
		first=maxf(first,minf(a,b))
		last=minf(last,maxf(a,b))
	return first if last>=maxf(first,0.0) else INF

# Height uses the same coordinate system as the returned transform.
# Both segments sample their adjoining ends before the overlap is applied.
static func wall_transform(building: Dictionary,ends: Array[Vector2],bounds: AABB,projection: Vector3,height: Callable,progress:=1.0) -> Transform3D:
	var left:=Vector3(ends[0].x*projection.x,0,ends[0].y*projection.z)
	var right:=Vector3(ends[1].x*projection.x,0,ends[1].y*projection.z)
	left.y=float(height.call(left.x,left.z))
	right.y=float(height.call(right.x,right.z))
	var x_axis:=(right-left)/maxf(0.001,bounds.size.x)
	var angle_:=angle(building)
	var z_axis:=Vector3(sin(angle_)*projection.x,0,cos(angle_)*projection.z)
	var basis:=Basis(x_axis,Vector3.UP*projection.y*progress,z_axis)
	var center:=Vector3(bounds.get_center().x,0,bounds.get_center().z)
	return Transform3D(basis,(left+right)*0.5-basis*center)

static func building_transform(building: Dictionary,projection: Vector3,y: float,progress:=1.0,exaggeration:=1.0) -> Transform3D:
	var scale:=Vector3(exaggeration,progress,exaggeration)
	if building.type=="field":
		scale.x*=float(building.get("width",16))/16.0
		scale.z*=float(building.get("depth",16))/16.0
	elif building.type=="house" and int(building.get("houseUpgradeLevelV218",0))>=1:
		scale*=Vector3(1.12,1.42,1.10)
	elif building.type in Gates and building.get("extendedPalisadeV166",false):
		scale.x*=2.0
	var map_basis:=Basis.from_scale(projection)
	var local_basis:=Basis(Vector3.UP,angle(building))*Basis.from_scale(scale)
	return Transform3D(map_basis*local_basis,Vector3(float(building.x)*projection.x,y,float(building.z)*projection.z))

static func cap_mesh(building: Dictionary) -> CylinderMesh:
	var key:="%s:%d" % [building.type,int(building.get("woodFortTierV1757",1))]
	if not caps.has(key):
		var mesh:=CylinderMesh.new()
		var radius:=0.15 if building.type=="palisade" else 0.28 if building.type=="stonewall" else 0.70
		var height:=1.30 if building.type=="palisade" else 0.48 if building.type=="stonewall" else 1.60
		if building.type=="palisade" and int(building.get("woodFortTierV1757",1))==2:
			radius=0.50;height=1.75
		mesh.top_radius=radius*0.87
		mesh.bottom_radius=radius
		mesh.height=height+0.32
		mesh.radial_segments=7
		mesh.rings=1
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color("715239") if building.type=="palisade" else Color("8e8472")
		material.roughness=0.94
		mesh.material=material
		caps[key]=mesh
	return caps[key]

static func cap_transform(endpoint: Vector2,projection: Vector3,height: Callable,mesh: CylinderMesh,progress:=1.0) -> Transform3D:
	var x:=endpoint.x*projection.x
	var z:=endpoint.y*projection.z
	var plane:=float(height.call(x,z))
	return Transform3D(Basis.from_scale(Vector3(projection.x,projection.y*progress,projection.z)),
		Vector3(x,plane+(mesh.height*0.5-0.32)*projection.y*progress,z))
