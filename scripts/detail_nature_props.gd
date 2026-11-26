extends RefCounted
## Shared meshes for metre-scale resources on the local map.

const LIMESTONE=preload("res://assets/house_designer/mine-rock.webp")
const BARK=preload("res://assets/house_designer/proc-bark.webp")
const PALETTES:={
	"stone":["a9a495","727c65"], "ore":["8c8375","7d4936"], "copper":["8e8171","5a8871"],
	"tin":["969184","afb8af"], "clay":["aa7151","c28d64"], "gems":["817f80","7e938e"],
}
static var meshes: Dictionary={}

static func deposit(kind: String) -> ArrayMesh:
	if meshes.has(kind):return meshes[kind]
	var palette: Array=PALETTES.get(kind,PALETTES.stone)
	var material:=StandardMaterial3D.new()
	material.albedo_texture=LIMESTONE;material.vertex_color_use_as_albedo=true
	material.roughness=0.97;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(material)
	if kind=="clay":
		add_rock(surface,Vector3(0,-0.12,0),Vector3(1.22,0.36,0.79),Color(palette[0]),Color(palette[1]),0.0)
		add_rock(surface,Vector3(0.69,-0.14,-0.26),Vector3(0.68,0.32,0.63),Color(palette[0]),Color(palette[1]),1.0)
	else:
		add_rock(surface,Vector3(-0.16,-0.20,-0.07),Vector3(0.80,0.91,0.66),Color(palette[0]),Color(palette[1]),1.5)
		add_rock(surface,Vector3(0.63,-0.10,0.13),Vector3(0.49,0.44,0.44),Color(palette[0]),Color(palette[1]),4.7)
		add_rock(surface,Vector3(-0.52,-0.10,0.53),Vector3(0.37,0.32,0.29),Color(palette[0]),Color(palette[1]),12.0)
		add_rock(surface,Vector3(0.37,-0.10,-0.54),Vector3(0.36,0.24,0.34),Color(palette[0]),Color(palette[1]),8.9)
	var result:=surface.commit()
	meshes[kind]=result
	return result

static func add_rock(surface: SurfaceTool,center: Vector3,scale: Vector3,base: Color,accent: Color,seed: float) -> void:
	const SIDES:=9
	const RINGS:=5
	var point:=func(ring: int,side: int) -> Vector3:
		var latitude:=lerpf(-1.03,1.52,float(ring)/RINGS)
		var angle:=float(posmod(side,SIDES))*TAU/SIDES
		var normal:=Vector3(cos(angle)*cos(latitude),sin(latitude),sin(angle)*cos(latitude))
		var faceting:=1.0+sin(angle*3+seed+latitude*2.3)*0.14+cos(angle*5-latitude*4+seed)*0.09
		return normal*faceting
	for r in RINGS:
		for s in SIDES:
			for sample: Vector2i in [Vector2i(r,s),Vector2i(r,s+1),Vector2i(r+1,s),Vector2i(r+1,s),Vector2i(r,s+1),Vector2i(r+1,s+1)]:
				var v: Vector3=point.call(sample.x,sample.y)
				var band:=smoothstep(0.39,0.85,0.5+0.5*sin(v.x*5.3+v.y*7.5+v.z*4.1+seed))
				var tint:=base.lerp(accent,band*0.68).darkened(maxf(0.0,-v.y)*0.23)
				surface.set_color(tint)
				surface.set_uv(Vector2(float(sample.y)/SIDES*1.6,float(sample.x)/RINGS)+Vector2(seed*0.2,0))
				surface.set_normal((v/scale).normalized())
				surface.add_vertex(center+v*scale)
	for s in SIDES:
		for v: Vector3 in [point.call(RINGS,s),point.call(RINGS,s+1),Vector3.UP]:
			surface.set_color(base);surface.set_normal((v/scale).normalized())
			surface.set_uv(Vector2(v.x,v.z)+Vector2.ONE*0.5);surface.add_vertex(center+v*scale)

static func stump() -> ArrayMesh:
	if meshes.has("stump"):return meshes.stump
	const SIDES:=13
	var bark:=StandardMaterial3D.new()
	bark.albedo_texture=BARK;bark.vertex_color_use_as_albedo=true;bark.roughness=1.0
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(bark)
	var trunk:=func(side: int,row: int,spacing: float=1.0) -> Vector3:
		var angle:=float(posmod(side,SIDES))*TAU/SIDES
		var foot:=pow(maxf(0.0,sin(angle*4.0+0.8)),7.0)
		var taper: float=[0.30+foot*0.22,0.25+foot*0.05,0.216][row]
		var radius:=float(taper)*(1.0+0.12*cos(angle*3-0.7))*spacing
		var height: float=[-0.075,0.14,0.42+0.031*sin(angle*3.0)+0.018*cos(angle*5.0)][row]
		return Vector3(cos(angle)*radius,height,sin(angle)*radius*0.85)
	for row in 2:
		for s in SIDES:
			for sample: Vector2i in [Vector2i(row,s),Vector2i(row,s+1),Vector2i(row+1,s),Vector2i(row+1,s),Vector2i(row,s+1),Vector2i(row+1,s+1)]:
				surface.set_color(Color("ded6c7") if sample.x>0 else Color("888477"))
				surface.set_uv(Vector2(float(sample.y)*2.0/SIDES,0.5*sample.x))
				surface.add_vertex(trunk.call(sample.y,sample.x))
	surface.generate_normals()
	var result:=surface.commit()
	var wood:=StandardMaterial3D.new()
	wood.vertex_color_use_as_albedo=true;wood.roughness=0.97
	surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(wood)
	var rings:=[0.0,0.18,0.24,0.34,0.42,0.51,0.58,0.71,0.77,0.86,0.93,1.0]
	for row in rings.size()-1:
		for s in SIDES:
			for sample: Vector2i in [Vector2i(row,s),Vector2i(row,s+1),Vector2i(row+1,s),Vector2i(row+1,s),Vector2i(row,s+1),Vector2i(row+1,s+1)]:
				var fraction: float=rings[sample.x]
				var edge: Vector3=trunk.call(sample.y,2)
				var p:=Vector3(0.028,0.412,-0.012).lerp(edge,fraction)
				var ring_ink:=Color("73513b") if row==rings.size()-2 else Color("ad7b50") if row%2==1 else Color("c79669")
				surface.set_color(ring_ink.darkened(0.12 if s==4 and row>4 else 0.0))
				surface.set_normal(Vector3.UP);surface.add_vertex(p)
	surface.commit(result)
	meshes.stump=result
	return result

