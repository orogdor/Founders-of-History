extends RefCounted

const Navigation=preload("res://scripts/local_navigation.gd")
const PeriodLod=preload("res://scripts/house_period_city_lod.gd")
const Styles=preload("res://scripts/house_period_styles.gd")
const PaintedMaterials=preload("res://scripts/painted_building_materials.gd")

const SIZES:={"hall":10.0,"house":7.0,"lumber":8.4,"quarry":9.0,"well":3.0,"farm":9.0,"barracks":9.2,"archery":9.2,"hunter":8.4,"fisher":9.2,"study":8.6,"pasture":9.0,"mason":8.0,"claypit":7.0,"pottery_kiln":6.0,"watchtower":4.0,"palisade":7.0,"woodgate":6.0,"stonewall":7.0,"stonetower":5.0,"cellar":5.0,"storage":7.0,"warehouse":8.0,"mill":7.0,"bakery":6.0,"coppermine":8.0,"tinmine":8.0,"bronze_foundry":7.0,"forester":7.0,"saw":7.0,"road_depot":7.0}
const MODELS:={"hall":"peamaja","house":"house","lumber":"lumber","forester":"lumber","saw":"lumber","quarry":"quarry","farm":"farm","well":"well","hunter":"hunter","fisher":"fisher","pasture":"pasture","mason":"mason","barracks":"barracks","archery":"archery","claypit":"claypit","pottery_kiln":"pottery_kiln","study":"study","watchtower":"watchtower","palisade":"palisade","woodgate":"woodgate","stonewall":"palisade","stonetower":"watchtower","cellar":"house","storage":"house","warehouse":"house","mill":"farm","bakery":"house","coppermine":"quarry","tinmine":"quarry","bronze_foundry":"pottery_kiln","road_depot":"lumber"}
const CORE:=["hall","house","well","study","cellar","storage","warehouse","market","bakery","mill","scriptorium","inn","granary"]
const SKIP:=["field","road","bridge"]
static var meshes: Dictionary={}

static func hidden_on_map(kind: String, age: int) -> bool:
	return kind in SKIP and not (age in [1,2] and kind == "field")

static func stamp(buildings: Array, age := 0) -> String:
	var parts:=PackedStringArray()
	for b in buildings:
		if hidden_on_map(b.type, age) or float(b.get("hp",0))<=0 or b.get("virtual",false):continue
		parts.append("%s:%s:%s:%s:%s" % [b.type,b.get("ready",false),roundi(float(b.x)),roundi(float(b.z)),b.get("buildingRotationV228",b.get("wallAngleV175",0))])
		if age in [1,2]:
			if not b.get("houseDesignV354",{}).is_empty():
				parts.append(str(hash(b.houseDesignV354)))
			if b.type=="field":parts.append(str([b.get("width",16),b.get("depth",16)]))
			if b.has("shoreAngle") or b.has("palisadeSpanV167") or b.has("extendedPalisadeV166") or b.has("wallAxis"):
				parts.append(str(hash([b.get("shoreAngle",0),b.get("palisadeSpanV167",0),b.get("cliffEmbedStartV179",0),b.get("cliffEmbedEndV179",0),b.get("extendedPalisadeV166",false),b.get("wallAxis",false)])))
	return "|".join(parts)

static func map_size(kind: String, age: int) -> float:
	if age==2:
		if kind=="field":return 10.0
		if not SIZES.has(kind) and Navigation.FOOTPRINTS.has(kind):
			var extent: Array=Navigation.FOOTPRINTS[kind]
			return clampf(1.5*maxf(extent[0],extent[1]),4.5,14.)
	return float(SIZES.get(kind,6.0))

static func layout(buildings: Array, age := 0) -> Dictionary:
	var extent:=0.0;var core:=0.0
	for b in buildings:
		if hidden_on_map(b.type, age) or float(b.get("hp",0))<=0 or b.get("virtual",false):continue
		var radius:=map_size(b.type,age)/4.5*0.5
		var e:=maxf(absf(float(b.x)/4.5)+radius,absf(float(b.z)/3.9)+radius)
		extent=maxf(extent,e)
		if b.type in CORE:core=maxf(core,e)
	var basis:=core if core>0 else extent
	var factor:=clampf(24.5/basis,1,5) if basis>0 else 1.0
	var list: Array=[]
	for b in buildings:
		if hidden_on_map(b.type, age) or float(b.get("hp",0))<=0 or b.get("virtual",false):continue
		var size:=map_size(b.type,age)/4.5*factor*1.4
		var limit:=maxf(0,24.5-size*0.5)
		var x:=float(b.x)/4.5*factor;var z:=float(b.z)/3.9*factor
		if absf(x)>limit or absf(z)>limit:
			var f:=minf(1,minf(limit/maxf(0.000001,absf(x)),limit/maxf(0.000001,absf(z))))
			x*=f;z*=f
		list.append({"building":b,"x":x,"z":z,"size":size})
	return {"scale":factor,"list":list}

static func clearances(buildings: Array,origin: Vector2,age:=0) -> Array:
	var result: Array=[];var core_radius:=0.0
	for item in layout(buildings,age).list:
		var radius:=maxf(2.4,float(item.size)*0.9)
		if age in [1,2] and item.building.type=="field":
			radius*=maxf(float(item.building.get("width",16)),float(item.building.get("depth",16)))/16.0
		result.append({"x":origin.x+float(item.x),"z":origin.y+float(item.z),"r":radius})
		if item.building.type in CORE:core_radius=maxf(core_radius,Vector2(float(item.x),float(item.z)).length()+radius)
	if core_radius>0:result.append({"x":origin.x,"z":origin.y,"r":core_radius})
	return result

static func get_mesh(name: String) -> Mesh:
	if meshes.has(name):return meshes[name]
	var path: String="res://assets/world/town_models/"+name+".glb"
	if not ResourceLoader.exists(path):return null
	var source: Node=load(path).instantiate();var found:=find_mesh(source)
	if found==null:source.free();return null
	var mesh: Mesh=found.mesh.duplicate()
	var material:=PaintedMaterials.world_material()
	for surface in mesh.get_surface_count():mesh.surface_set_material(surface,material)
	meshes[name]=mesh;source.free();return mesh

static func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:return node
	for child in node.get_children():
		var found:=find_mesh(child)
		if found!=null:return found
	return null

static func map_rotation(building: Dictionary, age: int, coast_plan: Dictionary, fortification: bool) -> float:
	var fallback := PI/2 if age in [1,2] and fortification and building.get("wallAxis",false) else 0.0
	var angle := float(building.get("buildingRotationV228",building.get("wallAngleV175",building.get("shoreAngle",fallback))))
	if age in [1,2] and building.type in ["harbor","fisher"] and building.has("shoreAngle"):
		var plan := coast_plan if not coast_plan.is_empty() else Styles.get_plan(Styles.designer_id(building.type,age))
		angle += Styles.coast_yaw(plan)
	return angle

static func build(buildings: Array,origin: Vector3,height: Callable,tile:=Vector2i.ZERO,age:=0) -> Node3D:
	var root:=Node3D.new();root.name="TownBuildings"
	var groups: Dictionary={}
	var plans: Dictionary={}
	var kinds: Dictionary={}
	for item in layout(buildings, age).list:
		var b: Dictionary=item.building;var name: String=MODELS.get(b.type,"house") if age==0 else PeriodLod.category(b.type,age)
		var saved: Dictionary = b.get("houseDesignV354",{})
		if age in [1,2] and (name.begins_with("bronze_") or name.begins_with("iron_")) and Styles.age_of(str(saved.get("id",""))) == age and str(saved.id).get_slice("@",0)==b.type:
			# The full key is only built on map refresh. Identical custom layouts
			# share one batch and are released with the city's map representation.
			name += ":" + JSON.stringify(saved)
			plans[name] = saved
			kinds[name] = str(b.type)
		if not groups.has(name):groups[name]=[]
		groups[name].append(item)
	for name in groups:
		var mesh:=PeriodLod.site_mesh(plans[name],kinds[name],age) if plans.has(name) else get_mesh(name) if age==0 else PeriodLod.mesh(clampi(age,1,6),name)
		if mesh==null:continue
		var bounds:=mesh.get_aabb();var divisor:=maxf(maxf(bounds.size.x,bounds.size.z),0.000001)
		if age==2 and groups[name][0].building.type=="watchtower":divisor=maxf(divisor,bounds.size.y*.66)
		var center:=Vector3(bounds.position.x+bounds.size.x/2.0,bounds.position.y,bounds.position.z+bounds.size.z/2.0)
		var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_custom_data=true
		# On the Compatibility renderer an explicit white instance color keeps
		# this mesh's painted plaster, earth and timber vertex colors visible.
		batch.use_colors = age in [1,2]
		batch.mesh=mesh;batch.instance_count=groups[name].size()
		for i in groups[name].size():
			var item: Dictionary=groups[name][i];var b: Dictionary=item.building
			var ready: bool=b.get("ready",false);var scalar: float=float(item.size)*0.04*(1 if ready else 0.75)/divisor
			var fortification: bool = b.type in ["palisade","stonewall","reinforced_wall","woodgate","gatehouse"]
			var angle := map_rotation(b,age,plans.get(name,{}),fortification)
			var span := 1.0
			if age in [1,2] and fortification:
				if float(b.get("palisadeSpanV167",0))>0 and b.type in ["palisade","stonewall","reinforced_wall"]:
					span=(float(b.palisadeSpanV167)+float(b.get("cliffEmbedStartV179",0))+float(b.get("cliffEmbedEndV179",0)))/7.0
				elif b.type in ["palisade","woodgate","gatehouse"] and b.get("extendedPalisadeV166",false):
					span=2.0
			var basis:=Basis(Vector3.UP,angle).scaled_local(Vector3(scalar*span,scalar*(1 if ready else 0.5),scalar))
			if age in [1,2] and b.type=="field":
				basis=basis.scaled_local(Vector3(float(b.get("width",16))/16.0,1.0,float(b.get("depth",16))/16.0))
			var point:=Vector3(float(item.x)*0.04,0,float(item.z)*0.04)
			point.y=float(height.call(origin+point))-float(height.call(origin))
			batch.set_instance_transform(i,Transform3D(basis,point-basis*center))
			if batch.use_colors:
				batch.set_instance_color(i,Color.WHITE)
			var variant:=PaintedMaterials.variant_at(tile,Vector2(b.x,b.z),b.type)
			batch.set_instance_custom_data(i,Color(float(variant)/7.0,0,0,0))
		var visual:=MultiMeshInstance3D.new();visual.multimesh=batch;root.add_child(visual)
	return root
