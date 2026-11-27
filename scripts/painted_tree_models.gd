extends RefCounted

const SHADER = preload("res://scripts/painted_tree.gdshader")
const HEIGHTS := {"oak":16.76573,"lime":20.28008,"birch":18.25661,"pine":18.16921,"spruce":18.09630,"palm":13.54984}
const CROWNS := {
	"oak": ["304a2e","5b7742","849b59"],
	"lime": ["384d29","688342","92a75e"],
	"birch": ["43573a","738c51","9eae68"],
	"pine": ["2b4837","4e7151","789665"],
	"spruce": ["254338","456952","6f8d65"],
	"palm": ["40522b","718849","98a960"],
}
static var meshes: Dictionary = {}
static var material: ShaderMaterial


static func mesh_for(kind: String, variant: int, level: String) -> Mesh:
	var key := "%s:%d:%s" % [kind, variant, level]
	if meshes.has(key):
		return meshes[key]
	var random := RandomNumberGenerator.new()
	random.seed = kind.hash() + 7919 * variant
	var stem_height: float = HEIGHTS[kind]
	var lean := Vector3(random.randf_range(-0.10,0.10),0.0,random.randf_range(-0.10,0.10)) * stem_height
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(tree_material())
	var rings := 5 if level == "near" else 4 if level == "mid" else 2
	var sides := 11 if level == "near" else 7 if level == "mid" else 5
	var palette := CROWNS[kind] as Array
	var trunk := Color("ac9e81") if kind == "birch" else Color("745944") if kind == "palm" else Color("66513b")
	var radius := stem_height * (0.032 if kind in ["oak","lime"] else 0.024 if kind in ["pine","spruce","palm"] else 0.018)
	var number_of_stem_sections := 4 if level == "near" else 3 if level == "mid" else 1
	var top := 0.87 if kind == "palm" else 0.92
	for index in number_of_stem_sections:
		var a := float(index) / number_of_stem_sections
		var b := float(index+1) / number_of_stem_sections
		var start := Vector3.UP * stem_height * a * top + lean * a * a
		var end := Vector3.UP * stem_height * b * top + lean * b * b
		var start_radius := radius * lerpf(1.19,0.22,a)
		var end_radius := radius * lerpf(1.19,0.22,b)
		branch(builder,start,end,start_radius,end_radius,sides,trunk)
	if kind == "palm":
		palm_crown(builder,Vector3.UP * stem_height * top + lean,stem_height,variant,level,palette)
	elif kind in ["spruce","pine"]:
		evergreen(builder,kind,stem_height,lean,variant,rings,sides,level,palette)
	else:
		broadleaf(builder,kind,stem_height,lean,variant,rings,sides,level,palette,trunk)
	var mesh := builder.commit()
	meshes[key] = mesh
	return mesh


static func tree_material() -> ShaderMaterial:
	if material == null:
		material = ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("leaf_color",load("res://assets/painted/foliage.webp"))
		material.set_shader_parameter("bark_color",load("res://assets/painted/wood.webp"))
	return material


static func grass_mesh(tall: bool) -> Mesh:
	var key := "tall_grass" if tall else "short_grass"
	if meshes.has(key):
		return meshes[key]
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass_material := ShaderMaterial.new()
	grass_material.shader = preload("res://scripts/painted_grass_blades.gdshader")
	builder.set_material(grass_material)
	for index in (7 if tall else 9):
		var angle := 2.39996 * index
		var ray := Vector3(cos(angle),0,sin(angle))
		var side := ray.cross(Vector3.UP)
		var growth := 0.69 + 0.30 * sin(index*8.71+1.1)
		var height := (0.43 if tall else 0.28) * growth
		var width := (0.019 if tall else 0.024) * (0.65 + 0.27*cos(index*5.1))
		var start := ray * (0.026 + 0.009 * (index%3))
		var middle := start + ray*height*0.31 + Vector3.UP*height*0.57
		var tip := start + ray*height*0.78 + Vector3.UP*height
		var color := Color("71834b").lerp(Color("a2aa69"),0.5+0.5*sin(index*2.9))
		var a := start-side*width*0.51
		var b := start+side*width*0.51
		var c := middle-side*width
		var d := middle+side*width
		var facing := (Vector3.UP-ray*0.42).normalized()
		quad(builder,a,b,c,d,facing,color,true)
		triangle(builder,c,d,tip,facing,color.lightened(0.08))
		quad(builder,a,b,c,d,-facing,color.darkened(0.12),true)
		triangle(builder,c,d,tip,-facing,color)
	var mesh := builder.commit()
	meshes[key] = mesh
	return mesh


static func broadleaf(out: SurfaceTool,kind: String,height: float,lean: Vector3,variant: int,rings: int,sides: int,level: String,palette: Array,bark: Color) -> void:
	var width := 0.24 if kind == "oak" else 0.19 if kind == "lime" else 0.14
	width *= 0.90 + 0.055 * variant
	var crown_height := 0.675 if kind == "oak" else 0.725 if kind == "lime" else 0.77
	var top := Vector3.UP * height * (crown_height+0.085)+lean
	var core := Vector3(width,0.205 if kind=="oak" else 0.175, width * 0.91)*height
	cluster(out,top,core,rings,sides,variant*3.13,palette,false)
	var lobes := 6 if level == "near" else 4 if level == "mid" else 2
	for index in lobes:
		var turn := TAU * float(index)/lobes + variant * 0.92
		var spread := width * (0.68 + 0.26 * sin(index * 6.2 + variant))
		var y := crown_height - 0.052 + sin(index * 2.73 + variant) * 0.089
		var direction := Vector3(cos(turn),0,sin(turn))
		var center := (direction * spread + Vector3.UP * y) * height + lean * 0.75
		var scale := (0.78 + 0.15 * cos(index * 3.6 + variant)) * width
		var size := Vector3(scale,0.125 if kind=="oak" else 0.145,scale*0.79)*height
		if level != "far":
			var start := Vector3.UP * height * (y-0.20+0.049*cos(index*3.3)) + lean * 0.5
			branch(out,start,center,height*0.016,height*0.004,5 if level=="near" else 4,bark)
		cluster(out,center,size,rings,sides,turn + index * 1.8,palette,false)
		if level == "near":
			var accent := center + (direction*0.068 + Vector3.UP*(0.030+0.052*sin(index*3.8)))*height
			cluster(out,accent,size*0.55,3,7,turn*1.83,palette,false)


static func evergreen(out: SurfaceTool,kind: String,height: float,lean: Vector3,variant: int,rings: int,sides: int,level: String,palette: Array) -> void:
	var tiers := 6 if level=="near" else 4 if level=="mid" else 3
	var bottom := 0.29 if kind=="spruce" else 0.49
	for index in tiers:
		var step := float(index) / (tiers - 1)
		var y := lerpf(bottom,0.907,step)
		var radius := lerpf(0.251 if kind=="spruce" else 0.228,0.038,step)
		radius *= 0.9 + 0.043 * variant
		var center := Vector3.UP * height * y + lean * step
		center += Vector3(sin(index*2.6+variant),0,cos(index*2.1+variant))*height*0.026
		var depth := radius * (0.87+0.10*sin(variant+index))
		var rise := lerpf(0.132,0.090,step) if kind=="spruce" else lerpf(0.11,0.085,step)
		cluster(out,center,Vector3(radius,rise,depth)*height,rings,sides,index*0.97+variant,palette,kind=="spruce")


static func palm_crown(out: SurfaceTool,center: Vector3,height: float,variant: int,level: String,palette: Array) -> void:
	var blades := 10 if level=="near" else 8 if level=="mid" else 5
	var segments := 6 if level=="near" else 4 if level=="mid" else 2
	for blade in blades:
		var angle := TAU * float(blade)/blades + 0.33 * variant
		var ray := Vector3(cos(angle),0,sin(angle))
		var side := ray.cross(Vector3.UP)
		var length := height * (0.35 + 0.07 * sin(blade*5.32+variant))
		var lift := 0.14 if blade%3==0 else 0.07
		for index in segments:
			var t := float(index) / segments
			var u := float(index+1) / segments
			var a := center + ray*length*t + Vector3.UP * height * (sin(t*PI)*lift-t*t*0.20)
			var b := center + ray*length*u + Vector3.UP * height * (sin(u*PI)*lift-u*u*0.20)
			var w0 := side * length * maxf(0.01,sin(t*PI)*0.13)
			var w1 := side * length * maxf(0.01,sin(u*PI)*0.13)
			var tint := leaf_tint(palette,0.6-0.25*t)
			quad(out,a-w0,a+w0,b-w1,b+w1,Vector3.UP,tint,true)
			quad(out,a-w0,a+w0,b-w1,b+w1,Vector3.DOWN,tint.darkened(0.22),true)


static func cluster(out: SurfaceTool,center: Vector3,size: Vector3,rings: int,sides: int,phase: float,palette: Array,spire: bool) -> void:
	var tint := leaf_tint(palette,clampf(0.55+0.20*sin(phase),0.15,0.85))
	for row in rings:
		var lower := -PI*0.5 + PI*float(row)/rings
		var upper := -PI*0.5 + PI*float(row+1)/rings
		for column in sides:
			var theta := TAU * float(column)/sides
			var next := TAU * float(column+1)/sides
			var a := leaf_point(center,size,lower,theta,phase,spire)
			var b := leaf_point(center,size,lower,next,phase,spire)
			var c := leaf_point(center,size,upper,theta,phase,spire)
			var d := leaf_point(center,size,upper,next,phase,spire)
			var facing := ((a+b+c+d)*0.25-center).normalized()
			triangle(out,a,b,c,facing,tint,center)
			triangle(out,c,b,d,facing,tint,center)


static func leaf_point(center: Vector3,size: Vector3,latitude: float,angle: float,phase: float,spire: bool) -> Vector3:
	var wiggle := 0.91 + 0.12*sin(angle*3.0+phase+latitude*2.0) + 0.079*cos(angle*5.0-phase*0.71)
	var width := cos(latitude) * wiggle
	if spire:
		width *= 1.02-0.48*sin(latitude)
	var y := sin(latitude) + cos(latitude)*(0.070*sin(angle*4.0+phase)+0.04*sin(angle*7.0-phase))
	return center + Vector3(cos(angle)*width,y,sin(angle)*width)*size


static func leaf_tint(palette: Array, value: float) -> Color:
	var tint := Color(palette[0]).lerp(Color(palette[1]),value*2.0) if value<0.5 else Color(palette[1]).lerp(Color(palette[2]),value*2.0-1.0)
	tint.a=1.0
	return tint


static func branch(out: SurfaceTool,start: Vector3,end: Vector3,lower: float,upper: float,sides: int,tint: Color) -> void:
	var axis := (end-start).normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	if right.length_squared()<0.01:
		right=axis.cross(Vector3.RIGHT).normalized()
	var front := right.cross(axis).normalized()
	for index in sides:
		var angle := TAU*float(index)/sides
		var next := TAU*float(index+1)/sides
		var a := right*cos(angle)+front*sin(angle)
		var b := right*cos(next)+front*sin(next)
		var textured := tint.darkened(0.13*(0.5+0.5*sin(angle*3.0)))
		textured.a=0.0
		quad(out,start+a*lower,start+b*lower,end+a*upper,end+b*upper,(a+b).normalized(),textured,false)


static func quad(out: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3,tint: Color,leaf: bool) -> void:
	tint.a=1.0 if leaf else 0.0
	triangle(out,a,b,c,normal,tint)
	triangle(out,c,b,d,normal,tint)


static func triangle(out: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3,tint: Color,center:=Vector3.INF) -> void:
	var face := (c-a).cross(b-a)
	if face.length_squared()<0.0000001:
		return
	var positions := [a,b,c] if face.dot(normal)>=0.0 else [a,c,b]
	var outward := face.normalized() * (1.0 if face.dot(normal)>=0.0 else -1.0)
	for position in positions:
		var vertex_normal := normal
		var vertex_color := tint
		if center!=Vector3.INF:
			var radial: Vector3=(position-center).normalized()
			vertex_normal=outward.lerp(radial,0.90).normalized()
			var brightness:=0.87+0.26*(radial.y*0.5+0.5)+0.046*sin(position.x*2.9+position.y*4.1+position.z*2.6)
			vertex_color=Color(tint.r*brightness,tint.g*brightness,tint.b*brightness,tint.a).srgb_to_linear()
		elif tint.a==0.0:
			vertex_color=tint.srgb_to_linear()
		out.set_normal(vertex_normal)
		out.set_color(vertex_color)
		out.add_vertex(position)
