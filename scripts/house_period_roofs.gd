extends RefCounted

const Vapor=preload("res://scripts/period_vapor.gd")
const Plan=preload("res://scripts/house_plan_geometry.gd")

static func build(model: Node3D, room: Dictionary, design: Dictionary, height: float) -> bool:
	if room.get("type","")!="rect":
		return false
	var form:=str(design.get("roofForm",""))
	if form not in ["norse","sawtooth","roofTerrace","barrelRoof"]:
		return false
	var a:=Plan.point(room.a)
	var b:=Plan.point(room.b)
	var dimensions:=(a-b).abs()/Plan.PX_PER_M
	var basis_x:=Vector3.RIGHT if dimensions.x>=dimensions.y else Vector3.BACK
	var basis_z:=Vector3(-basis_x.z,0,basis_x.x)
	var center: Vector3=model.local((a+b)/2.0)
	var length:=maxf(dimensions.x,dimensions.y)
	var width:=minf(dimensions.x,dimensions.y)
	if length<0.15 or width<0.15:
		return false
	match form:
		"norse":
			norse(model,design,center,basis_x,basis_z,length,width,height)
		"sawtooth":
			sawtooth(model,design,center,basis_x,basis_z,length,width,height)
		"barrelRoof":
			barrel_roof(model,design,center,basis_x,basis_z,length,width,height)
		"roofTerrace":
			terrace(model,design,center,basis_x,basis_z,length,width,height)
	return true

static func surface(model: Node3D, material: String) -> SurfaceTool:
	var result:=SurfaceTool.new()
	result.begin(Mesh.PRIMITIVE_TRIANGLES)
	result.set_material(model.material_for(material))
	return result

static func finish(model: Node3D, mesh_surface: SurfaceTool, name: String) -> void:
	mesh_surface.generate_normals()
	var node:=MeshInstance3D.new()
	node.name=name
	node.mesh=mesh_surface.commit()
	model.add_child(node)

static func along_roof(model: Node3D, a: Vector3,b: Vector3,finish_name: String, thickness: float) -> void:
	if a.distance_squared_to(b)>0.0001:
		model.fascia(a,b,finish_name,thickness)

static func norse_point(center: Vector3, ax: Vector3, az: Vector3,length: float,width: float,height: float,peak: float,sign_: float,s: float,t: float) -> Vector3:
	var sweep: float=pow(absf(s*2.0-1.0),2.0)
	var belly: float=0.22*(1.0-sweep)
	var curve:=sin(t*PI)*0.11
	return center+ax*((s-0.5)*(length+1.0))+az*sign_*(width/2.0+0.40+belly)*(1.0-t)+Vector3.UP*(lerpf(height-0.18+sweep*0.14,peak+sweep*0.24,t)+curve)

static func norse(model: Node3D, design: Dictionary, center: Vector3,ax: Vector3,az: Vector3,length: float,width: float,height: float) -> void:
	var peak:=height+clampf(width*0.38*float(design.get("roofHeight",120))/100.0,0.68,3.05)
	var roof_name:=str(design.get("roofMat","norseShingle"))
	var cover:=surface(model,roof_name)
	var gables:=surface(model,"norseTimber")
	for side in [-1.0,1.0]:
		var sample:=func(s: float,t: float) -> Vector3:
			return norse_point(center,ax,az,length,width,height,peak,side,s,t)
		for u in 12:
			var s0:=float(u)/12.0
			var s1:=float(u+1)/12.0
			for v in 5:
				var t0:=float(v)/5.0
				var t1:=float(v+1)/5.0
				var quad:=[sample.call(s0,t0),sample.call(s1,t0),sample.call(s0,t1),sample.call(s1,t1)]
				var uv:=[Vector2(s0*length,t0*width)*0.74,Vector2(s1*length,t0*width)*0.74,Vector2(s0*length,t1*width)*0.74,Vector2(s1*length,t1*width)*0.74]
				model.emit_roof_triangle(cover,[quad[0],quad[2],quad[1]],[uv[0],uv[2],uv[1]])
				model.emit_roof_triangle(cover,[quad[2],quad[3],quad[1]],[uv[2],uv[3],uv[1]])
			along_roof(model,sample.call(s0,0.0),sample.call(s1,0.0),"norsePaint",0.13)
		for s in [0.0,1.0]:
			for t in 5:
				along_roof(model,sample.call(s,float(t)/5.0),sample.call(s,float(t+1)/5.0),"norsePaint",0.16)
		for direction in [-1.0,1.0]:
			var end: Vector3=center+ax*direction*length/2.0+Vector3.UP*(height-0.07)
			model.roof_panel(gables,end,end+az*float(side)*width/2.0,end+Vector3.UP*(peak-height+0.16),end+Vector3.UP*(peak-height+0.16))
	finish(model,cover,"RoofDeck")
	finish(model,gables,"RoofGableEnds")
	for end in [-1.0,1.0]:
		var tip: Vector3=center+ax*float(end)*(length/2.0+0.57)+Vector3.UP*(peak+0.24)
		var wing: Vector3=ax*float(end)
		# Carved upward finial, with three tapered strokes rather than a copy
		# of any particular film prop or site carving.
		along_roof(model,tip-wing*0.23,tip+wing*0.18+Vector3.UP*0.21,"norsePaint",0.18)
		along_roof(model,tip+wing*0.18+Vector3.UP*0.21,tip+wing*0.11+Vector3.UP*0.43,"norsePaint",0.16)
		along_roof(model,tip+wing*0.11+Vector3.UP*0.43,tip+wing*0.31+Vector3.UP*0.38,"norseTimber",0.12)
	var ridge_a:=center-ax*(length/2.0+0.48)+Vector3.UP*(peak+0.25)
	var ridge_b:=center+ax*(length/2.0+0.48)+Vector3.UP*(peak+0.25)
	if not model.roof_vents.is_empty():
		var vent: Vector2=model.roof_vents[0]
		Vapor.add(model,Vector3(vent.x,peak-0.025,vent.y),Vector2(1.24,2.0),"smoke",int(model.texture_variant))
	for index in 12:
		var s0:=float(index)/12.0
		var s1:=float(index+1)/12.0
		if not model.roof_vents.is_empty() and index in [5,6]:
			continue
		var left:=ridge_a.lerp(ridge_b,s0)-Vector3.UP*(0.24*(1.0-pow(absf(s0*2.0-1.0),2.0)))
		var right:=ridge_a.lerp(ridge_b,s1)-Vector3.UP*(0.24*(1.0-pow(absf(s1*2.0-1.0),2.0)))
		along_roof(model,left,right,"norsePaint",0.15)

static func sawtooth(model: Node3D, design: Dictionary, center: Vector3,ax: Vector3,az: Vector3,length: float,width: float,height: float) -> void:
	var teeth:=3 if width>=3.7 else 2
	var depth:=width/teeth
	var rise:=clampf(depth*0.49*float(design.get("roofHeight",75))/75.0,0.40,1.15)
	var roof_name:=str(design.get("roofMat","corrugation"))
	var cover:=surface(model,roof_name)
	var clerestory:=surface(model,"windowGlass")
	var ends:=surface(model,str(design.get("wallStyle","millBrick")))
	var eave:=height+0.095
	var half:=length/2.0+0.19
	for index in teeth:
		var foot:=center+az*(-width/2.0+index*depth)+Vector3.UP*eave
		var shoulder:=foot+az*depth+Vector3.UP*rise
		var low:=shoulder-Vector3.UP*rise
		model.roof_panel(cover,foot-ax*half,foot+ax*half,shoulder-ax*half,shoulder+ax*half)
		model.roof_panel(clerestory,low-ax*(half-0.08),low+ax*(half-0.08),shoulder-ax*(half-0.08),shoulder+ax*(half-0.08))
		for endpoint in [-1.0,1.0]:
			var cap: Vector3=ax*float(endpoint)*length/2.0
			model.roof_panel(ends,foot+cap,low+cap,shoulder+cap,shoulder+cap)
		along_roof(model,foot-ax*half,foot+ax*half,"castIron",0.12)
		along_roof(model,shoulder-ax*half,shoulder+ax*half,"castIron",0.14)
		var divisions:=maxi(3,roundi(length/0.9))
		for post in divisions+1:
			var shift: Vector3=ax*lerpf(-half+0.065,half-0.065,float(post)/divisions)
			along_roof(model,low+shift,shoulder+shift,"castIron",0.055)
	finish(model,cover,"RoofDeck")
	finish(model,clerestory,"RoofClerestory")
	finish(model,ends,"RoofGableEnds")

static func terrace(model: Node3D, design: Dictionary, center: Vector3,ax: Vector3,az: Vector3,length: float,width: float,height: float) -> void:
	var half:=length/2.0+0.18
	var side:=width/2.0+0.18
	var base:=center+Vector3.UP*(height+0.075)
	var rotation: float=-atan2(ax.z,ax.x)
	var deck: MeshInstance3D=model.fixture_box(model,Vector3(length+0.36,0.155,width+0.36),base,str(design.get("roofMat","membrane")))
	deck.rotation.y=rotation
	deck.name="RoofDeck"
	var upper:=base+Vector3.UP*0.21
	var corners: Array[Vector3]=[upper-ax*half-az*side,upper+ax*half-az*side,upper+ax*half+az*side,upper-ax*half+az*side]
	for index in 4:
		var a:Vector3=corners[index]
		var b:Vector3=corners[(index+1)%4]
		var mid:Vector3=(a+b)/2.0
		var housing: MeshInstance3D=model.fixture_box(model,Vector3(a.distance_to(b),0.29,0.16),mid,"boardConcrete")
		housing.rotation.y=-atan2(b.z-a.z,b.x-a.x)
		along_roof(model,a+Vector3.UP*0.145,b+Vector3.UP*0.145,"metalTrim",0.09)
	if width>=2.9 and length>=4.0 and not design.get("upperLevel",false):
		var at:=base-ax*length*0.21-az*width*0.15+Vector3.UP*0.18
		var vent:MeshInstance3D=model.fixture_box(model,Vector3(0.81,0.39,0.68),at,"metalTrim")
		vent.rotation.y=rotation
		vent.name="RoofVent"
		var kind:=str(design.get("id","")).get_slice("@",0)
		var panels:=3 if kind in ["powerplant","laboratory","public_school","autofactory","office"] else 2
		for index in panels:
			var panel_at:=base+ax*(0.30+index*0.75)+az*width*0.17+Vector3.UP*0.20
			if absf((panel_at-base).dot(ax))>half-0.53:
				break
			var panel:MeshInstance3D=model.fixture_box(model,Vector3(0.66,0.07,0.92),panel_at,"solarPanel")
			panel.rotation.y=rotation
			panel.rotate_object_local(Vector3.RIGHT,-0.18)
			panel.name="SolarPanel"



static func barrel_roof(model: Node3D, design: Dictionary, center: Vector3,ax: Vector3,az: Vector3,length: float,width: float,height: float) -> void:
	var roof_name:=str(design.get("roofMat","corrugation"))
	var cover:=surface(model,roof_name)
	var ends:=surface(model,str(design.get("wallStyle","sootBrick")))
	var eave:=height-0.06
	var half:=length/2.0+0.19
	var rising:=clampf(width*0.34*float(design.get("roofHeight",85))/85.0,0.46,1.78)
	var broad:=width/2.0+0.17
	var divisions:=16
	for index in divisions:
		var u:=PI*float(index)/divisions
		var v:=PI*float(index+1)/divisions
		var first:=az*(cos(u)*broad)+Vector3.UP*(eave+sin(u)*rising)
		var second:=az*(cos(v)*broad)+Vector3.UP*(eave+sin(v)*rising)
		model.roof_panel(cover,center+first-ax*half,center+second-ax*half,center+first+ax*half,center+second+ax*half)
		for side in [-1.0,1.0]:
			var cap: Vector3=center+ax*float(side)*half
			along_roof(model,cap+first,cap+second,"castIron",0.10)
			var interior: Vector3=center+ax*float(side)*length/2.0
			model.roof_panel(ends,interior+first,interior+second,interior+Vector3.UP*eave,interior+Vector3.UP*eave)
	for sign_ in [-1.0,1.0]:
		var at: Vector3=center+az*float(sign_)*broad+Vector3.UP*eave
		along_roof(model,at-ax*half,at+ax*half,"castIron",0.105)
	finish(model,cover,"RoofDeck")
	finish(model,ends,"RoofGableEnds")
