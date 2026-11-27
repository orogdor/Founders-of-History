extends RefCounted
## Small readable silhouettes for traffic and harbour dressing. All coordinates
## are in ship-local model units. World markers and piers set their own scale.
const BronzeFinishes = preload("res://scripts/bronze_home_materials.gd")
const RomanCargo = preload("res://scripts/roman_cargo.gd")
const BronzePots = preload("res://scripts/bronze_home_props.gd")
const Painted=preload("res://scripts/painted_building_materials.gd")
const CLOTH := ["d9c7a1","d7c7ab","e5d4a9","c3ad88","e1d1ae","a89e84","c6d3d4"]
const HULL := ["","period_aegeanRed","period_navalPlank","period_norseTimber","period_lappedPine","period_castIron","period_metalTrim"]
const TRIM := ["","bd9a61","a55243","a8644b","d3ab72","b7a58b","d2793f"]
const FLAGS := ["3f7c8b","a65040","695379","a58a49"]
static var surfaces: Dictionary={}

static func material(tint: Color, family: String="",variant:=0) -> StandardMaterial3D:
	var key:="%s:%s:%d" % [tint.to_html(),family,variant]
	if not surfaces.has(key):
		var value:=StandardMaterial3D.new()
		value.albedo_color=tint
		value.cull_mode=BaseMaterial3D.CULL_DISABLED
		value.roughness=0.83
		if not family.is_empty():
			value.albedo_texture=Painted.texture(family,variant)
			value.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			Painted.apply_height(value,family,variant)
		surfaces[key]=value
	return surfaces[key]

static func part(parent: Node3D,mesh: Mesh,finish: Material,at:=Vector3.ZERO) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=finish
	node.position=at
	parent.add_child(node)
	return node

static func block(parent: Node3D, at: Vector3,dimensions: Vector3,finish: Material) -> MeshInstance3D:
	var mesh:=BoxMesh.new()
	mesh.size=dimensions
	return part(parent,mesh,finish,at)

static func spar(parent: Node3D,a: Vector3,b: Vector3,radius: float,tint: String) -> void:
	var delta:=b-a
	if delta.length_squared()<0.01:
		return
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius*0.73
	mesh.bottom_radius=radius
	mesh.radial_segments=7
	mesh.height=delta.length()
	var node:=part(parent,mesh,material(Color(tint)),(a+b)/2)
	node.quaternion=Quaternion(Vector3.UP,delta.normalized())

static func panel(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,uv_size:=Vector2.ONE) -> void:
	var vertices: Array[Vector3]=[a,b,c,d]
	var uv: Array[Vector2]=[Vector2.ZERO,Vector2(uv_size.x,0),Vector2(0,uv_size.y),uv_size]
	for index in [0,2,1,2,3,1]:
		surface.set_uv(uv[index])
		surface.add_vertex(vertices[index])

static func hull(parent: Node3D,length: float,beam: float,depth: float,age: int,variant: int) -> void:
	var shell:=SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck:=SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gunwale:=SurfaceTool.new()
	gunwale.begin(Mesh.PRIMITIVE_TRIANGLES)
	var positions: Array=[]
	var n:=20
	for index in n+1:
		var t:=float(index)/n
		var z:=(t-0.5)*length
		var tapered:=pow(maxf(0.0,sin(t*PI)),0.64 if age<=4 else 0.29)
		var wide:=beam*lerpf(0.07 if age<=4 else 0.38,1.0,tapered)
		var lift:=pow(absf(t*2.0-1.0),4.0)*(2.6 if age==3 else 1.65 if age<=4 else 0.64)
		positions.append([wide,z,depth+lift])
	for index in n:
		var p: Array=positions[index]
		var q: Array=positions[index+1]
		for side in [-1.0,1.0]:
			var top_a:=Vector3(p[0]*side,p[2],p[1])
			var top_b:=Vector3(q[0]*side,q[2],q[1])
			var turn_a:=Vector3(p[0]*side*0.74,0.25,p[1]*0.91)
			var turn_b:=Vector3(q[0]*side*0.74,0.25,q[1]*0.91)
			var keel_a:=Vector3(p[0]*side*0.29,-0.89,p[1]*0.85)
			var keel_b:=Vector3(q[0]*side*0.29,-0.89,q[1]*0.85)
			panel(shell,top_a,top_b,turn_a,turn_b,Vector2(0.42,0.48))
			panel(shell,turn_a,turn_b,keel_a,keel_b,Vector2(0.42,0.30))
			panel(gunwale,top_a+Vector3.UP*0.10,top_b+Vector3.UP*0.10,top_a-Vector3.UP*0.22,top_b-Vector3.UP*0.22)
		panel(deck,Vector3(-p[0],p[2]-0.07,p[1]),Vector3(p[0],p[2]-0.07,p[1]),Vector3(-q[0],q[2]-0.07,q[1]),Vector3(q[0],q[2]-0.07,q[1]),Vector2(1.1,0.25))
	for end in [0,n]:
		var p: Array=positions[end]
		panel(shell,Vector3(-p[0],p[2],p[1]),Vector3(p[0],p[2],p[1]),Vector3(-p[0]*0.28,-0.65,p[1]*0.85),Vector3(p[0]*0.28,-0.65,p[1]*0.85))
	var hull_tint:=Color("b8a08b" if age<=4 else "a8aa9e" if age==5 else "c5cece")
	shell.generate_normals()
	part(parent,shell.commit(),BronzeFinishes.get_finish("wood",variant) if age in [1,2] else material(hull_tint,HULL[age],variant))
	deck.generate_normals()
	part(parent,deck.commit(),BronzeFinishes.get_finish("wood",variant+2) if age in [1,2] else material(Color("ad9f87"),"period_navalPlank" if age<=4 else "period_castIron",variant))
	gunwale.generate_normals()
	part(parent,gunwale.commit(),material(Color(TRIM[age])))

static func sail(parent: Node3D, z: float,y: float,width: float,height: float,age: int,team: int,variant: int,lateen:=false) -> void:
	var sail_surface:=SurfaceTool.new()
	sail_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var band:=SurfaceTool.new()
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sample:=func(u: float,v: float) -> Vector3:
		var x: float=(u-0.5)*width*lerpf(0.84,1.0,v)
		var lower: float=(0.20 if lateen else 0.09)*height*(u*2.0-1.0)
		var billow:=sin(u*PI)*sin(v*PI*0.92)*width*0.19
		return Vector3(x,y+height*(0.5-v)+lower,z+billow)
	for col in 10:
		var u0:=float(col)/10
		var u1:=float(col+1)/10
		for row in 7:
			var v0:=float(row)/7
			var v1:=float(row+1)/7
			var surface:=band if row==3 or (age==3 and col in [2,3,6,7]) else sail_surface
			panel(surface,sample.call(u0,v0),sample.call(u1,v0),sample.call(u0,v1),sample.call(u1,v1),Vector2(0.22,0.20))
	sail_surface.generate_normals()
	part(parent,sail_surface.commit(),BronzeFinishes.get_finish("linen",variant) if age in [1,2] else material(Color(CLOTH[age]),"period_khakiCanvas",variant))
	band.generate_normals()
	part(parent,band.commit(),material(Color(FLAGS[team]),"period_khakiCanvas",variant))
	var left: Vector3=sample.call(0.0,0.0)
	var right: Vector3=sample.call(1.0,0.0)
	spar(parent,left-Vector3.RIGHT*0.4,right+Vector3.RIGHT*0.4,0.17,"6b5745")
	for sign_ in [-1.0,1.0]:
		var uv: float=(float(sign_)+1.0)/2.0
		var foot: Vector3=sample.call(uv,1.0)
		spar(parent,foot,Vector3(0.6*float(sign_),3.0,z-2.3),0.034,"a79271")

static func visual(kind: String,team: int,age: int,world_scale:=0.04,variant:=0) -> Node3D:
	var root:=Node3D.new()
	root.name="PeriodShip"
	root.scale=Vector3.ONE*world_scale
	age=clampi(age,1,6)
	team=clampi(team,0,3)
	var length: float=[0,24,27,27,31,29,31][age]
	var width: float=[0,3.4,4.2,3.8,5.3,5.4,5.9][age]
	var depth: float=[0,2.6,3.2,2.25,4.4,3.65,3.95][age]
	if kind=="transport":
		width*=1.22 if age==2 else 1.08
	elif age==2:
		width*=0.83
		length*=1.12
		depth*=0.78
	hull(root,length,width,depth,age,variant)
	if age<=4:
		if age==4:
			block(root,Vector3(0,5.5,-10.4),Vector3(6,3.0,6.5),material(Color("c4a77e"),"period_maritimePaint",variant))
			block(root,Vector3(0,7.2,-10.4),Vector3(6.8,0.45,7.0),material(Color("ac8f66"),"period_navalPlank",variant))
			for x in [-2.05,0.0,2.05]:
				block(root,Vector3(x,5.94,-13.7),Vector3(0.75,0.62,0.14),material(Color("d1a45f")))
			block(root,Vector3(0,5.17,10.15),Vector3(4.8,1.1,3.1),material(Color("917856"),"period_navalPlank",variant))
			for sign_ in [-1.0,1.0]:
				var side: float=float(sign_)
				var rail_a:=Vector3(side*width*0.76,depth+0.84,-9.2)
				var rail_b:=Vector3(side*width*0.76,depth+0.84,9.0)
				spar(root,rail_a,rail_b,0.105,"c4a070")
				for i in 7:
					var point:=rail_a.lerp(rail_b,float(i)/6.0)
					spar(root,point-Vector3.UP*0.73,point,0.064,"725340")
			spar(root,Vector3(0,depth+0.72,11.2),Vector3(0,depth+1.80,18.2),0.18,"80674b")

		var mast_positions: Array=[0.0] if age in [1,3] else [-1.85,9.1] if age==2 else [-7.0,0.6,7.2]
		for index in mast_positions.size():
			var z: float=mast_positions[index]
			var mast_height:=18.0+float(index%2)*3.4 if age==4 else 15.6-index*1.2
			var foremast := age==2 and index==1
			var masthead_z := z+2.2 if foremast else z
			if foremast:mast_height=10.1
			spar(root,Vector3(0,depth,z),Vector3(0,mast_height,masthead_z),0.24,"594434")
			var sail_width := 5.6 if foremast else 11.6 if age in [2,4] else 10.4
			var sail_height := 4.1 if foremast else 8.7
			sail(root,masthead_z,mast_height-sail_height*.55,sail_width,sail_height,age,team,variant)
			if age==4 and index==1:
				sail(root,z-0.24,mast_height-8.8,13.0,4.4,age,team,variant)
				var pennant:=SurfaceTool.new()
				pennant.begin(Mesh.PRIMITIVE_TRIANGLES)
				var hoist:=Vector3(0,mast_height,z)
				panel(pennant,hoist,hoist+Vector3(2.51,-0.26,0.62),hoist-Vector3.UP*0.67,hoist+Vector3(2.38,-0.37,0.59))
				pennant.generate_normals()
				part(root,pennant.commit(),material(Color("4f3e39"),"period_khakiCanvas",variant))
				for side in [-1.0,1.0]:
					spar(root,hoist-Vector3.UP*0.60,Vector3(width*float(side)*0.85,depth+0.16,z-3.03),0.035,"796247")

		if age==3:
			spar(root,Vector3(0,3,length/2.1),Vector3(0,7.0,length/2+1.5),0.31,"6a4230")
			spar(root,Vector3(0,7.0,length/2+1.5),Vector3(0,7.9,length/2+0.2),0.27,"895133")
		if age in [1,3] or (age==2 and kind!="transport"):
			for x in [-1.0,1.0]:
				for row in 7:
					var z: float=-length*0.3+row*length/10.0
					spar(root,Vector3(width*float(x)*0.83,depth,z),Vector3((width+2.25)*float(x),depth-1.6,z-0.95),0.071,"9c7a4d")
	else:
		var paint:=material(Color("b8b2a1" if age==5 else "dce4e6"),"period_boardConcrete",variant)
		block(root,Vector3(0,depth+0.97,-1.8),Vector3(width*1.53,2.15,7.0),paint)
		block(root,Vector3(0,depth+2.45,-2.15),Vector3(width*1.28,1.15,4.4),paint)
		var glass:=material(Color("4b6772"))
		for x in [-2.3,0.0,2.3]:
			block(root,Vector3(x,depth+2.5,0.11),Vector3(1.7,0.67,0.10),glass)
		for i in 2:
			var z: float=-6.3-i*3.1
			spar(root,Vector3(0,depth+1.14,z),Vector3(0,depth+5.35,z),0.94 if age==5 else 0.46,"625953")
		if age==6:
			for index in 3:
				var tint:=material(Color(["a96747","75888a","a39d84"][index]))
				block(root,Vector3(0,depth+1.04,5.1+index*2.6),Vector3(width*1.47,2.0,2.42),tint)
		else:
			spar(root,Vector3(0,depth,7.0),Vector3(0,depth+8.2,7.0),0.16,"5f4c3a")
	if age == 1:
		# A broad steering paddle silhouettes the stern; cargo boats carry
		# their jars low amidships with a pale linen awning over the hold.
		spar(root,Vector3(width*0.81,depth+1.0,-length*0.29),Vector3(width+0.25,0.15,-length*0.43),0.12,"806348")
		var blade:=block(root,Vector3(width+0.19,0.41,-length*0.42),Vector3(0.27,1.30,0.66),BronzeFinishes.get_finish("wood",variant))
		blade.rotation.x=-0.63
		if kind=="transport":
			var load_root:=Node3D.new()
			root.add_child(load_root)
			load_root.scale=Vector3.ONE*1.52
			for at: Vector3 in [Vector3(-1.05,depth/1.52,1.7),Vector3(0,depth/1.52,1.85),Vector3(1.01,depth/1.52,1.6)]:
				BronzePots.place(load_root,"householdJar",at)
			for side: float in [-1.0,1.0]:
				for pos: float in [-5.8,-2.9]:
					spar(root,Vector3(side*1.54,depth,pos),Vector3(side*1.54,depth+1.83,pos),0.072,"7c6145")
			block(root,Vector3(0,depth+1.90,-4.35),Vector3(3.38,0.13,3.25),BronzeFinishes.get_finish("linen",variant+1))
	elif age==2:
		for side:float in [-1.,1.]:
			var high:=Vector3(side*width*.73,depth+1.13,-length*.27)
			var low:=Vector3(side*(width+.54),.25,-length*.40)
			spar(root,high,low,.13,"695141")
			var blade:=block(root,low,Vector3(.23,1.54,.69),BronzeFinishes.get_finish("wood",variant))
			blade.rotation.x=-.65
		if kind=="transport":
			var wood:=BronzeFinishes.get_finish("wood",variant)
			block(root,Vector3(0,depth+.23,-4.92),Vector3(width*1.27,.31,3.50),wood)
			for col in 3:
				for row in 2:
					RomanCargo.place(root,Vector3((col-1)*1.13,depth+.30,-5.61+row*1.36),2.24)
			var awning:=block(root,Vector3(0,depth+2.69,-8.45),Vector3(width*1.12,.11,2.95),BronzeFinishes.get_finish("linen",variant))
			awning.rotation.x=-.06
			for side:float in [-1.,1.]:
				for z:float in [-9.65,-7.28]:spar(root,Vector3(side*width*.51,depth+.25,z),Vector3(side*width*.51,depth+2.62,z),.09,"68533e")
	elif kind=="transport" and age<=4:
		var freight:=material(Color("b69c6e"),"period_navalPlank",variant)
		for at in [Vector3(-1.9,depth+0.62,2.9),Vector3(2.0,depth+0.62,-2.2),Vector3(-2.0,depth+0.62,-3.3)]:
			block(root,at,Vector3(1.45,1.25,1.58),freight)
	return root

