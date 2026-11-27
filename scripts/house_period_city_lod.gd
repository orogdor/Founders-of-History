extends RefCounted
## Shared geometry per period/role for the far map. Individual buildings
## remain MultiMesh instances so a developed city does not add a node per roof.
const Painted=preload("res://scripts/painted_building_materials.gd")
const Styles=preload("res://scripts/house_period_styles.gd")
const BronzeMap = preload("res://scripts/bronze_age_map_mesh.gd")
const IronMap = preload("res://scripts/iron_age_map_mesh.gd")
const PeriodShader=preload("res://scripts/period_world_building.gdshader")
const FAMILIES:=[
	[],["aegeanPlaster","romanTile","aegeanRed"],["romanStucco","romanTile","romanRed"],
	["norseTimber","norseShingle","medievalMasonry"],["lappedPine","slate","maritimePaint"],
	["millBrick","corrugation","castIron"],["boardConcrete","membrane","metalTrim"],
]
const WALLS := ["","b89c73","c2a88a","746255","afa198","a06149","aab2b2"]
const ROOFS := ["","a4593d","9b4d3c","5d483a","5e5f64","646965","677478"]
const ACCENTS := ["","925340","9f5443","835546","5d7377","535952","4b6572"]
static var cache: Dictionary={}
static var materials: Dictionary={}

static func category(type: String, age := 0) -> String:
	if age in [1,2]:
		var id := Styles.designer_id(type, age)
		if not id.is_empty() and Styles.age_of(id) == age:
			return ("bronze_" if age == 1 else "iron_") + type
	if type in Styles.DEFENSE:
		return "guard"
	if type in Styles.CIVIC:
		return "civic"
	if type in Styles.COAST:
		return "dock"
	if type in Styles.INDUSTRY:
		return "works"
	if type in ["farm","pasture","lumber","stable","windmill"]:
		return "yard"
	return "home"

static func material(age: int) -> ShaderMaterial:
	if not materials.has(age):
		var shader:=ShaderMaterial.new()
		shader.shader=PeriodShader
		var names:=["walls","roofs","accents"]
		for slot in names.size():
			var family: String = ["period_aegeanPlaster", Painted.SOIL, "period_norseTimber"][slot] if age == 1 else "period_" + str(FAMILIES[age][slot])
			shader.set_shader_parameter(names[slot],Painted.atlas(family))
		if age in [1,2]:
			shader.set_shader_parameter("paint_strength", 0.20 if age == 1 else 0.17)
		materials[age]=shader
	return materials[age]

static func triangle(surface: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,color: Color,finish:=0) -> void:
	for point in [a,b,c]:
		surface.set_color(color)
		surface.set_uv(Vector2(finish,0))
		surface.add_vertex(point)

static func quad(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color,finish:=0) -> void:
	triangle(surface,a,c,b,color,finish)
	triangle(surface,c,d,b,color,finish)

static func prism(surface: SurfaceTool, center: Vector3,size: Vector3,tint: Color,finish:=0) -> void:
	var bottom:=center-size/2.0
	var top:=center+size/2.0
	var a:=Vector3(bottom.x,bottom.y,bottom.z)
	var b:=Vector3(top.x,bottom.y,bottom.z)
	var c:=Vector3(top.x,bottom.y,top.z)
	var d:=Vector3(bottom.x,bottom.y,top.z)
	var rise:=Vector3.UP*size.y
	for edge in [[a,b],[b,c],[c,d],[d,a]]:
		quad(surface,edge[0],edge[1],edge[0]+rise,edge[1]+rise,tint,finish)
	quad(surface,a+rise,b+rise,d+rise,c+rise,tint,finish)

static func ridged(surface: SurfaceTool,at: Vector3,width: float,depth: float,rise: float,tint: Color,end_tint: Color,hip:=false) -> void:
	var x:=width/2
	var z:=depth/2
	var a:=at+Vector3(-x,0,-z)
	var b:=at+Vector3(x,0,-z)
	var c:=at+Vector3(x,0,z)
	var d:=at+Vector3(-x,0,z)
	var lip:=maxf(0.0,z-x*0.54) if hip else z
	var p:=at+Vector3(0,rise,-lip)
	var q:=at+Vector3(0,rise,lip)
	quad(surface,a,d,p,q,tint,1)
	quad(surface,c,b,q,p,tint,1)
	triangle(surface,a,b,p,tint if hip else end_tint,1 if hip else 0)
	triangle(surface,d,q,c,tint if hip else end_tint,1 if hip else 0)

static func sawtooth(surface: SurfaceTool,at: Vector3,width: float,depth: float,tint: Color,accent: Color) -> void:
	var half:=width*0.5
	var rise:=Vector3.UP*0.23
	for index in 3:
		var lo:=at+Vector3(0,0,depth*(float(index)/3.0-0.5))
		var hi:=lo+Vector3(0,0,depth/3.0)
		var left:=Vector3(-half,0,0)
		var right:=Vector3(half,0,0)
		quad(surface,lo+left,lo+right,hi+left+rise,hi+right+rise,tint,1)
		quad(surface,hi+left,hi+right,hi+left+rise,hi+right+rise,accent,2)
		triangle(surface,lo+left,hi+left,hi+left+rise,tint,1)
		triangle(surface,lo+right,hi+right,hi+right+rise,tint,1)

# These blocks use clockwise faces and flat normals so the two shallow
# roofs still catch light independently at the world map's smallest zoom.
static func dwelling_block(surface: SurfaceTool, from: Vector3, to: Vector3, tint: Color, finish: int, rear_rise := 0.0) -> void:
	var bottom := PackedVector3Array([
		from, Vector3(to.x, from.y, from.z), Vector3(to.x, from.y, to.z), Vector3(from.x, from.y, to.z)
	])
	var top := PackedVector3Array()
	for i in 4:
		var corner := bottom[i]
		corner.y = to.y + (rear_rise if i < 2 else 0.0)
		top.append(corner)
	for i in 4:
		var next := (i + 1) % 4
		quad(surface, bottom[next], bottom[i], top[next], top[i], tint, finish)
	quad(surface, top[0], top[3], top[1], top[2], tint, finish)

static func bronze_house_mesh() -> Mesh:
	var plan := Styles.get_plan("house@1")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	surface.set_material(material(1))
	var stone := Color("93816d")
	var door := Color("231d19")
	var timber := Color("674329")
	var roof := Color("b07d50")
	var plaster := Color("d0a46e")
	var units := Styles.Plan.PX_PER_M
	for room in plan.rooms:
		var start := Styles.Plan.point(room.a) / units
		var end := Styles.Plan.point(room.b) / units
		var height := 1.55 * float(plan.wallScale) / 100.0 * float(room.get("heightFactor", 1.0))
		var rise := (end.y - start.y) * 0.045
		dwelling_block(surface, Vector3(start.x, 0, start.y), Vector3(end.x, height, end.y), plaster, 0, rise)
		dwelling_block(surface, Vector3(start.x - 0.035, 0, start.y - 0.035), Vector3(end.x + 0.035, 0.43, end.y + 0.035), stone, 2)
		dwelling_block(surface, Vector3(start.x - 0.12, height, start.y - 0.12), Vector3(end.x + 0.12, height + 0.13, end.y + 0.12), roof, 1, rise)
	for opening in plan.openings:
		if opening.type == "door" and opening.get("group") == "outer":
			var point := Styles.Plan.point(opening.point) / units
			dwelling_block(surface, Vector3(point.x - 0.46, 0, point.y), Vector3(point.x + 0.46, 1.70, point.y + 0.05), door, 2)
			dwelling_block(surface, Vector3(point.x - 0.59, 1.70, point.y), Vector3(point.x + 0.59, 1.91, point.y + 0.12), timber, 2)
		elif opening.type == "window":
			var point := Styles.Plan.point(opening.point) / units
			for room in plan.rooms:
				var bounds_end := Styles.Plan.point(room.b) / units
				var bounds_start := Styles.Plan.point(room.a) / units
				if is_equal_approx(point.y, bounds_end.y):
					dwelling_block(surface, Vector3(point.x - 0.18, 1.02, point.y), Vector3(point.x + 0.18, 1.48, point.y + 0.03), door, 2)
				elif is_equal_approx(point.x, bounds_start.x):
					dwelling_block(surface, Vector3(point.x - 0.03, 1.02, point.y - 0.18), Vector3(point.x, 1.48, point.y + 0.18), door, 2)
	var yard := Rect2()
	for fence in plan.get("fences", []):
		if fence.get("kind") == "stoneLine":
			var a := Styles.Plan.point(fence.a) / units
			var b := Styles.Plan.point(fence.b) / units
			if yard.size == Vector2.ZERO:
				yard.position = a
			yard = yard.expand(a).expand(b)
			dwelling_block(surface, Vector3(minf(a.x, b.x) - 0.11, 0, minf(a.y, b.y) - 0.11), Vector3(maxf(a.x, b.x) + 0.11, 0.53, maxf(a.y, b.y) + 0.11), stone, 2)
	if yard.has_area():
		dwelling_block(surface, Vector3(yard.position.x, 0, yard.position.y), Vector3(yard.end.x, 0.03, yard.end.y), Color("a38863"), 1)
	surface.generate_normals()
	return surface.commit()

static func mesh(age: int,role: String) -> Mesh:
	var key:="%d:%s" % [age,role]
	if cache.has(key):
		return cache[key]
	if age == 1 and role == "bronze_house":
		cache[key] = bronze_house_mesh()
		return cache[key]
	if age in [1,2]:
		var representative := {"home":"farm", "dock":"harbor", "guard":"gatehouse", "civic":"hall", "works":"bronze_foundry", "yard":"pasture"}
		var prefix := "bronze_" if age == 1 else "iron_"
		var kind: String = representative.get(role, role.trim_prefix(prefix))
		var plan := Styles.get_plan(Styles.designer_id(kind, age))
		if not plan.is_empty():
			cache[key] = site_mesh(plan,kind,age)
			return cache[key]
	var wall:=Color(WALLS[age])
	var cover:=Color(ROOFS[age])
	var accent:=Color(ACCENTS[age])
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material(age))
	var civic:=role=="civic"
	var military:=role=="guard"
	var dock:=role=="dock"
	var works:=role=="works"
	var length:=1.72 if civic or works else 1.43 if dock else 1.18 if age==3 else 1.07
	var width:=1.06 if civic or works else 0.68 if age<=3 else 0.84
	var h:=0.62 if civic else 0.46
	if military:
		width=0.65
		length=0.77
		h=0.95 if age<5 else 0.57
	if dock:
		wall=Color("786958")
	if works:
		wall=Color("895b4e") if age<6 else Color("68747a")
	prism(surface,Vector3(0,h/2,0),Vector3(width,h,length),wall)
	prism(surface,Vector3(0,0.046,0),Vector3(width+0.12,0.092,length+0.10),wall.darkened(0.18))
	if age==6:
		prism(surface,Vector3(0,h+0.032,0),Vector3(width+0.10,0.064,length+0.11),cover,1)
		if civic or works:
			prism(surface,Vector3(-width*0.22,h+0.093,-length*0.24),Vector3(width*0.26,0.12,length*0.22),accent,2)
		for side in [-0.51,0.51]:
			prism(surface,Vector3(width*side,h+0.082,0),Vector3(0.041,0.09,length+0.08),cover,2)
		for x in [-0.26,0.01,0.28]:
			prism(surface,Vector3(width*x,h*0.70,length/2+0.012),Vector3(width*0.21,h*0.30,0.024),accent,2)
	elif military:
		prism(surface,Vector3(0,h+0.038,0),Vector3(width+0.10,0.076,length+0.10),cover,1)
		if age<5:
			for x in [-0.31,0.0,0.31]:
				prism(surface,Vector3(x,h+0.11,length/2),Vector3(0.12,0.18,0.13),wall)
	elif age==5 and works:
		sawtooth(surface,Vector3(0,h,0),width+0.08,length+0.08,cover,accent)
		prism(surface,Vector3(width*0.28,0.57,-length*0.32),Vector3(0.13,1.15,0.13),wall.darkened(0.15))
	else:
		var added_depth:=0.24 if civic and age in [1,2,4] else 0.10
		var roof_center:=Vector3(0,h,0.065 if added_depth>0.10 else 0.0)
		ridged(surface,roof_center,width+0.15,length+added_depth,0.42 if age==3 else 0.27 if age==1 else 0.22,cover,wall,age==2 or age==4)
		if age<=2 or (civic and age==4):
			var front:=length/2+0.12
			for factor in [-0.43,0.0,0.43]:
				prism(surface,Vector3(width*factor,h*0.48,front),Vector3(0.072,h*0.93,0.085),accent if age==1 else wall.lightened(0.23),2 if age==1 else 0)
			prism(surface,Vector3(0,h-0.024,front),Vector3(width+0.04,0.087,0.12),accent,2)
		elif age==3:
			prism(surface,Vector3(0,h+0.41,0),Vector3(0.08,0.071,length+0.21),accent,2)
		if age==4 and dock:
			prism(surface,Vector3(0,0.063,length*0.68),Vector3(width*0.72,0.13,length*0.55),wall.darkened(0.12))
		prism(surface,Vector3(0,h*0.31,length/2+0.009),Vector3(width*0.20,h*0.62,0.025),wall.darkened(0.47))
	surface.generate_normals()
	var result:=surface.commit()
	cache[key]=result
	return result


static func site_mesh(plan: Dictionary, kind: String, age: int) -> Mesh:
	if age == 2:
		return IronMap.new().build(plan,kind,material(age))
	return bronze_site_mesh(plan,kind)

static func bronze_site_mesh(plan: Dictionary, kind: String) -> Mesh:
	return BronzeMap.new().build(plan,kind,material(1))
