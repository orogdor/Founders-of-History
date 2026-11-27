extends RefCounted
## Shared meshes for metre-scale resources on the local map.

const LIMESTONE=preload("res://assets/house_designer/mine-rock.webp")
const BARK=preload("res://assets/house_designer/proc-bark.webp")
const RockSurface=preload("res://scripts/resource_stone.gdshader")
const WoodCut=preload("res://scripts/cut_wood.gdshader")
const PALETTES:={
	"stone":["b5afa1","747957"], "ore":["999082","8d533d"], "copper":["a19a84","688075"],
	"tin":["aaa69a","b6beb2"], "clay":["bd8059","c69870"], "gems":["958f92","86a395"],
}
static var meshes: Dictionary={}
static var rock_material: ShaderMaterial
static var weathered_bark: ShaderMaterial
static var cut_faces: ShaderMaterial

static func ground_plants(kind: String) -> ArrayMesh:
	if meshes.has(kind):return meshes[kind]
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.roughness=0.92
	material.metallic_specular=0.16
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	if kind=="fern":
		add_fern(surface)
	else:
		var reed:=kind=="reed"
		var tall:=kind=="tall" or reed
		var count:=12 if tall else 9
		for i in count:
			var turn:=float(i)*2.399963
			var direction:=Vector3(cos(turn),0.0,sin(turn))
			var across:=Vector3(-direction.z,0.0,direction.x)
			var height:=lerpf(0.36,0.76,scattered(i*5+1)) if tall else lerpf(0.13,0.36,scattered(i*5+1))
			var spread:=lerpf(0.04,0.22,scattered(i*5+2))*(1.35 if tall else 1.0)
			var blade_width:=lerpf(0.011,0.025,scattered(i*5+3))*(1.15 if tall else 1.0)
			var base:=direction*lerpf(0.018,0.15,scattered(i*5+4))
			var leaf_color:=Color("52713a").lerp(Color("85914b"),scattered(i*5+5))
			if reed:
				height*=1.4
				spread*=0.71
				blade_width*=0.69
				leaf_color=leaf_color.lerp(Color("92905e"),scattered(i*5+6)*.64)
			add_grass_blade(surface,base,direction,across,height,spread,blade_width,leaf_color)
	var result:=surface.commit()
	meshes[kind]=result
	return result

static func scattered(seed: int) -> float:
	var value:=sin(float(seed)*89.173+3.44)*41387.87
	return value-floorf(value)

static func add_grass_blade(surface: SurfaceTool,base: Vector3,direction: Vector3,across: Vector3,height: float,spread: float,width: float,tint: Color) -> void:
	var center:=base+Vector3.UP*(height*0.50)+direction*(spread*0.18)
	var upper:=base+Vector3.UP*(height*0.83)+direction*(spread*0.54)
	var tip:=base+Vector3.UP*(height*0.88)+direction*spread
	var points: Array[Vector3]=[
		base-across*width*0.32,base+across*width*0.32,
		center-across*width*0.5,center+across*width*0.5,
		upper-across*width*0.31,upper+across*width*0.31,tip]
	var root_color:=tint.darkened(0.21)
	var tip_color:=tint.lightened(0.18)
	for index in [0,2,1,1,2,3,2,4,3,3,4,5,4,6,5]:
		surface.set_color(root_color.lerp(tip_color,float(index)/6.0))
		surface.set_normal((Vector3.UP+direction*0.45).normalized())
		surface.add_vertex(points[index])

static func add_fern(surface: SurfaceTool) -> void:
	for frond in 6:
		var angle:=float(frond)*TAU/6.0+scattered(frond+8)*0.32
		var direction:=Vector3(cos(angle),0.0,sin(angle))
		var side:=Vector3(-direction.z,0.0,direction.x)
		var reach:=lerpf(0.32,0.58,scattered(frond+29))
		var height:=lerpf(0.18,0.37,scattered(frond*5+2))
		var frond_point:=func(t: float)->Vector3:
			return direction*(reach*t)+Vector3.UP*(0.02+height*sin(t*2.30))
		for row in 7:
			var t:=float(row)/7.0
			var p: Vector3=frond_point.call(t)
			var next: Vector3=frond_point.call((row+1.0)/7.0)
			var base_color:=Color("4c663b").lerp(Color("879a57"),t)
			surface.set_normal(Vector3.UP)
			surface.set_color(base_color)
			for vertex in [p-side*0.004,p+side*0.004,next-side*0.003,next-side*0.003,p+side*0.004,next+side*0.003]:
				surface.add_vertex(vertex)
			if row==0:continue
			var along: Vector3=(next-p).normalized()
			var length:=sin(t*PI)*lerpf(0.071,0.102,scattered(frond*19+row))
			for sign_: float in [-1.0,1.0]:
				var endpoint:=p+side*sign_*length+along*0.055-Vector3.UP*(t*0.031)
				var ridge:=p.lerp(endpoint,0.56)+Vector3.UP*0.009
				var width:=along*(0.013+0.015*sin(t*PI))
				surface.set_color(base_color)
				for vertex in [p,ridge-width,endpoint,p,endpoint,ridge+width]:
					surface.add_vertex(vertex)

static func shrub() -> ArrayMesh:
	if meshes.has("shrub"):return meshes.shrub
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.roughness=0.93
	material.metallic_specular=0.17
	material.backlight_enabled=true
	material.backlight=Color(0.21,0.34,0.09)
	surface.set_material(material)
	for branch in 8:
		var angle:=float(branch)*2.399963+scattered(branch*5+11)*.29
		var direction:=Vector3(cos(angle),0,sin(angle))
		var lateral:=Vector3(-direction.z,0,direction.x)
		var reach:=lerpf(.26,.58,scattered(branch*7+11))
		var height:=lerpf(.37,.71,scattered(branch*7+13))
		var sweep:=lerpf(-.11,.14,scattered(branch*7+16))
		var stem:=func(t: float)->Vector3:
			return direction*(reach*t*t)+Vector3.UP*(height*(t+.22*sin(PI*t)))+lateral*(sweep*t)
		for node in 6:
			var t:=float(node)/6.0
			var first: Vector3=stem.call(t)
			var last: Vector3=stem.call((node+1.0)/6.0)
			var width: Vector3=lateral*lerpf(.017,.002,t)
			surface.set_color(Color("53513c"))
			surface.set_normal(Vector3.UP)
			for point in [first-width,last-width*.68,first+width,first+width,last-width*.68,last+width*.68]:
				surface.add_vertex(point)
			if node==0:continue
			var rise: Vector3=(last-first).normalized()
			for side in [-1.0,1.0]:
				var seed:=roundi(float(branch*31+node*5)+side+31.0)
				var leaf_direction: Vector3=(lateral*side*lerpf(.63,1.22,scattered(seed+9))+rise*.62+direction*.57).normalized()
				var length:=lerpf(.083,.179,scattered(seed+11))*(1.0-t*.35)
				var color:=Color("435a31").lerp(Color("879152"),scattered(seed+13))
				var bottom:=first.lerp(last,0.22+maxf(0,side)*.18)
				shrub_leaf(surface,bottom,leaf_direction,length,color)
		var top: Vector3=stem.call(1.0)
		shrub_leaf(surface,top,(direction+Vector3.UP*.18).normalized(),.098,Color("a1a451"))
	var result:=surface.commit()
	meshes.shrub=result
	return result

static func shrub_leaf(surface: SurfaceTool,bottom: Vector3,orientation: Vector3,length: float,color: Color) -> void:
	var across:=Vector3.UP.cross(orientation).normalized()*length*.29
	var center:=bottom+orientation*(length*.49)+Vector3.UP*(length*.09)
	var upper:=bottom+orientation*(length*.79)
	var tip:=bottom+orientation*length-Vector3.UP*(length*.08)
	var corners: Array[Vector3]=[bottom,center+across,upper+across*.56,tip,upper-across*.58,center-across]
	var normal: Vector3=(Vector3.UP-orientation*.32).normalized()
	for i in corners.size():
		surface.set_color(color.lightened(.15))
		surface.set_normal(normal)
		surface.add_vertex(center)
		surface.set_color(color.darkened(.21 if i==0 else .055))
		surface.add_vertex(corners[i])
		surface.add_vertex(corners[(i+1)%corners.size()])

static func cactus(padded: bool) -> ArrayMesh:
	var key:="cactus_pads" if padded else "cactus_column"
	if meshes.has(key):return meshes[key]
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=.96
	material.metallic_specular=.13
	surface.set_material(material)
	var skin:=Color("5c794a")
	var growth:=Color("8b965a")
	if padded:
		add_rock(surface,Vector3(0,.122,0),Vector3(.145,.20,.073),skin,growth,4.0,10,4)
		add_rock(surface,Vector3(-.112,.316,.011),Vector3(.139,.203,.083),skin,growth,14.1,10,4)
		add_rock(surface,Vector3(.126,.255,.047),Vector3(.156,.162,.070),skin,growth,12.2,10,4)
		add_rock(surface,Vector3(.160,.451,.083),Vector3(.094,.134,.058),skin,growth,8.1,8,4)
		add_rock(surface,Vector3(-.172,.511,.029),Vector3(.096,.128,.055),skin,growth,22.0,8,4)
	else:
		cactus_stem(surface,Vector3(0,-.04,0),Vector3(.047,1.23,-.015),.099,skin)
		cactus_stem(surface,Vector3(.021,.49,-.005),Vector3(.19,.65,-.009),.063,skin.darkened(.04))
		cactus_stem(surface,Vector3(.19,.60,-.009),Vector3(.24,.98,.053),.060,growth.darkened(.22))
		cactus_stem(surface,Vector3(-.018,.71,-.012),Vector3(-.15,.87,-.108),.055,skin)
		cactus_stem(surface,Vector3(-.15,.823,-.108),Vector3(-.14,1.109,-.153),.048,growth.darkened(.21))
	var result:=surface.commit()
	meshes[key]=result
	return result

static func cactus_stem(surface: SurfaceTool,bottom: Vector3,top: Vector3,radius: float,tint: Color) -> void:
	const SIDES:=20
	const PROFILE:=[1.0,1.06,.99,.84,.46,.045]
	const LEVELS:=[0.0,.22,.63,.85,.965,1.0]
	var axis: Vector3=(top-bottom).normalized()
	var rotation:=Basis(Quaternion(Vector3.UP,axis))
	for row in PROFILE.size()-1:
		for side in SIDES:
			for sample: Vector2i in [Vector2i(row,side),Vector2i(row,side+1),Vector2i(row+1,side),Vector2i(row+1,side),Vector2i(row,side+1),Vector2i(row+1,side+1)]:
				var angle:=float(posmod(sample.y,SIDES))*TAU/SIDES
				var direction:=rotation*Vector3(cos(angle),0,sin(angle))
				var rib:=1.0 if sample.y%2==0 else .81
				var position: Vector3=bottom.lerp(top,LEVELS[sample.x])+direction*(radius*float(PROFILE[sample.x])*rib)
				var normal: Vector3=(direction+axis*smoothstep(.64,1.0,LEVELS[sample.x])*1.6).normalized()
				surface.set_color(tint.darkened((1.0-rib)*.73).lightened(.12*float(LEVELS[sample.x])))
				surface.set_normal(normal)
				surface.add_vertex(position)
	surface.set_color(tint.lightened(.12))
	surface.set_normal(axis)
	for side in SIDES:
		surface.add_vertex(top+axis*radius*.013)
		for i in [side,side+1]:
			var angle:=float(posmod(i,SIDES))*TAU/SIDES
			var rim:=rotation*Vector3(cos(angle),0,sin(angle))
			var rib:=1.0 if i%2==0 else .81
			surface.add_vertex(top+rim*(radius*.045*rib))

static func deposit(kind: String) -> ArrayMesh:
	if meshes.has(kind):return meshes[kind]
	var palette: Array=PALETTES.get(kind,PALETTES.stone)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(stone_material())
	if kind=="clay":
		add_rock(surface,Vector3(0,-0.12,0),Vector3(1.22,0.36,0.79),Color(palette[0]),Color(palette[1]),0.0)
		add_rock(surface,Vector3(0.69,-0.14,-0.26),Vector3(0.68,0.32,0.63),Color(palette[0]),Color(palette[1]),1.0)
	else:
		add_rock(surface,Vector3(-0.16,-0.20,-0.07),Vector3(0.80,0.91,0.66),Color(palette[0]),Color(palette[1]),1.5)
		add_rock(surface,Vector3(0.63,-0.10,0.13),Vector3(0.49,0.44,0.44),Color(palette[0]),Color(palette[1]),4.7)
		add_rock(surface,Vector3(-0.52,-0.10,0.53),Vector3(0.37,0.32,0.29),Color(palette[0]),Color(palette[1]),12.0)
		add_rock(surface,Vector3(0.37,-0.10,-0.54),Vector3(0.36,0.24,0.34),Color(palette[0]),Color(palette[1]),8.9)
		add_rock(surface,Vector3(-0.28,-0.025,0.78),Vector3(0.17,0.16,0.14),Color(palette[0]),Color(palette[1]),7.7,6,3)
		add_rock(surface,Vector3(0.82,-0.045,0.39),Vector3(0.23,0.20,0.15),Color(palette[0]),Color(palette[1]),19.4,6,3)
	var result:=surface.commit()
	meshes[kind]=result
	return result

static func scree() -> ArrayMesh:
	if meshes.has("scree"):return meshes.scree
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(stone_material())
	var shale:=Color("938f7e")
	var oxide:=Color("76654f")
	add_rock(surface,Vector3(-.1,-.12,.08),Vector3(.56,.46,.39),shale,oxide,25.1,7,3)
	add_rock(surface,Vector3(.34,-.09,-.12),Vector3(.29,.22,.33),shale,oxide,19.4,6,3)
	add_rock(surface,Vector3(.58,-.014,.09),Vector3(.16,.12,.12),shale,oxide,3.8,5,2)
	var result:=surface.commit()
	meshes.scree=result
	return result

static func stone_material() -> ShaderMaterial:
	if rock_material==null:
		rock_material=ShaderMaterial.new()
		rock_material.shader=RockSurface
		rock_material.set_shader_parameter("stone_detail",LIMESTONE)
	return rock_material

static func add_rock(surface: SurfaceTool,center: Vector3,scale: Vector3,base: Color,accent: Color,seed: float,sides:=10,rings:=5) -> void:
	var point:=func(ring: int,side: int) -> Vector3:
		var latitude:=lerpf(-1.03,1.52,float(ring)/rings)
		var angle:=float(posmod(side,sides))*TAU/sides
		var normal:=Vector3(cos(angle)*cos(latitude),sin(latitude),sin(angle)*cos(latitude))
		var faceting:=1.0+sin(angle*3+seed+latitude*2.3)*0.19+cos(angle*5-latitude*4+seed)*0.09
		var rock:=normal*faceting
		rock.x+=rock.y*(sin(seed*0.6)*0.24)
		rock.z+=rock.y*(cos(seed*0.7)*0.14)
		rock.y=lerpf(rock.y,clampf(rock.y,-0.83,0.86),smoothstep(0.20,1.0,absf(rock.y))*0.72)
		return rock
	for r in rings:
		for s in sides:
			for sample: Vector2i in [Vector2i(r,s),Vector2i(r,s+1),Vector2i(r+1,s),Vector2i(r+1,s),Vector2i(r,s+1),Vector2i(r+1,s+1)]:
				var v: Vector3=point.call(sample.x,sample.y)
				var band:=smoothstep(0.56,0.92,0.5+0.5*sin(v.x*7.3+v.y*9.5+v.z*5.1+seed+sin(v.z*11.7)))
				var tint:=base.lerp(accent,band*0.54).darkened(maxf(0.0,-v.y)*0.19)
				surface.set_color(tint)
				surface.set_uv(Vector2(float(sample.y)/sides*1.6,float(sample.x)/rings)+Vector2(seed*0.2,0))
				surface.set_normal((v/scale).normalized())
				surface.add_vertex(center+v*scale)
	for s in sides:
		for v: Vector3 in [point.call(rings,s),point.call(rings,s+1),Vector3.UP]:
			surface.set_color(base);surface.set_normal((v/scale).normalized())
			surface.set_uv(Vector2(v.x,v.z)+Vector2.ONE*0.5);surface.add_vertex(center+v*scale)

static func stump() -> ArrayMesh:
	if meshes.has("stump"):return meshes.stump
	const SIDES:=13
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(wood_material(true))
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
	surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(wood_material(false))
	var center:=Vector3(0.018,0.413,-0.009)
	for s in SIDES:
		for point: Vector3 in [center,trunk.call(s,2),trunk.call(s+1,2)]:
			surface.set_uv(Vector2(point.x,point.z)/0.446+Vector2.ONE*0.5)
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point)
	surface.commit(result)
	meshes.stump=result
	return result

static func wood_material(bark: bool) -> ShaderMaterial:
	if bark:
		if weathered_bark==null:
			weathered_bark=ShaderMaterial.new()
			weathered_bark.shader=WoodCut
			weathered_bark.set_shader_parameter("bark",true)
			weathered_bark.set_shader_parameter("bark_texture",BARK)
		return weathered_bark
	if cut_faces==null:
		cut_faces=ShaderMaterial.new()
		cut_faces.shader=WoodCut
	return cut_faces

static func fallen_log() -> ArrayMesh:
	if meshes.has("log"):return meshes.log
	const SIDES:=11
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(wood_material(true))
	var point:=func(ring: int,side: int)->Vector3:
		var angle:=float(posmod(side,SIDES))*TAU/SIDES
		var radius:=lerpf(.25,.172,float(ring)/4.0)*(1.0+sin(angle*3.0+ring*.62)*.099)
		var x:=lerpf(-1.19,1.05,float(ring)/4.0)+.073*sin(angle+ring)*absf(float(ring)-2.0)/2.0
		return Vector3(x,.155+cos(angle)*radius+.035*sin(ring*.75),sin(angle)*radius)
	for ring in 4:
		for side in SIDES:
			for vertex: Vector2i in [Vector2i(ring,side),Vector2i(ring+1,side),Vector2i(ring,side+1),Vector2i(ring,side+1),Vector2i(ring+1,side),Vector2i(ring+1,side+1)]:
				var p: Vector3=point.call(vertex.x,vertex.y)
				surface.set_color(Color("d7ccc0").lerp(Color("7c7866"),1.0-smoothstep(-.03,.21,p.y)))
				surface.set_uv(Vector2(float(vertex.y)/SIDES,p.x*.71))
				surface.set_normal(Vector3(0,p.y-.155,p.z).normalized())
				surface.add_vertex(p)
	var result:=surface.commit()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(wood_material(false))
	for end in [0,4]:
		var center:=Vector3(-1.19 if end==0 else 1.05,.155+.035*sin(end*.75),0)
		var scale:=.50 if end==0 else .344
		surface.set_normal(Vector3.LEFT if end==0 else Vector3.RIGHT)
		for side in SIDES:
			for p: Vector3 in [center,point.call(end,side),point.call(end,side+1)]:
				surface.set_uv(Vector2(p.z-center.z,p.y-center.y)/scale+Vector2.ONE*.5)
				surface.add_vertex(p)
	surface.commit(result)
	meshes.log=result
	return result

