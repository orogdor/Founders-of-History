extends RefCounted

static func cylinder(model: Node3D,at: Vector3,height: float,base_radius: float,top_radius: float,material: String) -> MeshInstance3D:
	var shape:=CylinderMesh.new()
	shape.height=height
	shape.bottom_radius=base_radius
	shape.top_radius=top_radius
	shape.radial_segments=12
	return model.fixture_mesh(model,shape,at,material)

static func box(model: Node3D, at: Vector3,size: Vector3,material: String) -> MeshInstance3D:
	return model.fixture_box(model,size,at,material)

static func beam(model: Node3D,a: Vector3,b: Vector3,thickness: float,material: String) -> void:
	model.fascia(a,b,material,thickness)
	var mesh: Node3D=model.get_child(model.get_child_count()-1)
	mesh.name="PeriodBeam"

static func build(model: Node3D, kind: String, at: Vector3,height: float) -> bool:
	match kind:
		"householdJar", "saddleQuern":
			preload("res://scripts/bronze_home_props.gd").place(model, kind, at)
		"romanBasin":
			box(model,at+Vector3.UP*0.045,Vector3(1.85,0.10,1.61),"romanMosaic")
			box(model,at+Vector3.UP*0.114,Vector3(1.46,0.035,1.18),"windowWater")
			for sign_ in [-1.0,1.0]:
				box(model,at+Vector3(0,0.13,float(sign_)*0.645),Vector3(1.58,0.15,0.11),"romanTravertine")
				box(model,at+Vector3(float(sign_)*0.75,0.13,0),Vector3(0.11,0.15,1.28),"romanTravertine")
		"romanColumn":
			box(model,at+Vector3.UP*0.06,Vector3(0.38,0.12,0.38),"romanTravertine")
			cylinder(model,at+Vector3.UP*0.84,1.53,0.13,0.105,"romanTravertine")
			cylinder(model,at+Vector3.UP*1.63,0.13,0.11,0.17,"romanTravertine")
			box(model,at+Vector3.UP*1.73,Vector3(0.38,0.09,0.38),"romanStucco")
		"medievalBelfry":
			var shaft_height:=height+1.18
			box(model,at+Vector3.UP*(shaft_height/2.0),Vector3(1.42,shaft_height,1.42),"medievalMasonry")
			var balcony:=at+Vector3.UP*(shaft_height+0.32)
			box(model,balcony-Vector3.UP*0.16,Vector3(1.54,0.27,1.54),"norseTimber")
			for x in [-0.62,0.62]:
				for z in [-0.62,0.62]:
					beam(model,balcony+Vector3(x,0,z),balcony+Vector3(x,0.94,z),0.14,"norseTimber")
			for x in [-0.62,0.62]:
				beam(model,balcony+Vector3(x,0.24,-0.62),balcony+Vector3(x,0.82,0.62),0.11,"norseTimber")
			var bell:=cylinder(model,balcony+Vector3.UP*0.46,0.46,0.23,0.14,"bellBronze")
			bell.name="BelfryBell"
			var cone:=CylinderMesh.new()
			cone.height=1.30
			cone.top_radius=0.035
			cone.bottom_radius=1.12
			cone.radial_segments=4
			var cap: MeshInstance3D=model.fixture_mesh(model,cone,balcony+Vector3.UP*1.59,"slate")
			cap.rotation.y=PI/4.0
			beam(model,balcony+Vector3.UP*2.20,balcony+Vector3.UP*2.52,0.07,"castIron")
		"workerChimney":
			var flue_top:=height+2.0
			box(model,at+Vector3.UP*(flue_top/2.0),Vector3(0.47,flue_top,0.55),"sootBrick")
			box(model,at+Vector3.UP*flue_top,Vector3(0.61,0.14,0.64),"millBrick")
			for x in [-0.15,0.15]:
				cylinder(model,at+Vector3(x,flue_top+0.17,0),0.30,0.11,0.095,"romanTile")
		"dockCrane":
			var top:=at+Vector3.UP*2.86
			var point:=top+Vector3(1.42,0.27,-0.12)
			box(model,at+Vector3.UP*0.13,Vector3(0.70,0.24,0.70),"pavingSetts")
			beam(model,at+Vector3.UP*0.24,top,0.20,"navalPlank")
			beam(model,top-Vector3(0.50,0.12,0),point,0.17,"navalPlank")
			beam(model,at+Vector3.UP*1.18,top+Vector3(0.54,0.07,0),0.12,"navalPlank")
			beam(model,point,point-Vector3.UP*2.02,0.032,"rope")
			box(model,point-Vector3.UP*2.10,Vector3(0.22,0.19,0.18),"castIron")
			var winch:=cylinder(model,at+Vector3(0.23,0.94,0),0.23,0.28,0.28,"castIron")
			winch.rotation.z=PI/2.0
		"canvasShelter":
			var low:=at+Vector3.UP*0.13
			var ridge:=at+Vector3.UP*1.32
			var fabric:=SurfaceTool.new()
			fabric.begin(Mesh.PRIMITIVE_TRIANGLES)
			fabric.set_material(model.material_for("khakiCanvas"))
			for sign_ in [-1.0,1.0]:
				var edge:=low+Vector3(float(sign_)*0.75,0,0)
				model.roof_panel(fabric,edge-Vector3.BACK*0.98,edge+Vector3.BACK*0.98,ridge-Vector3.BACK*0.98,ridge+Vector3.BACK*0.98)
				for z in [-0.98,0.98]:
					beam(model,edge+Vector3.BACK*z,ridge+Vector3.BACK*z,0.064,"navalPlank")
			fabric.generate_normals()
			var cover:=MeshInstance3D.new()
			cover.name="CanvasShelter"
			cover.mesh=fabric.commit()
			model.add_child(cover)
			beam(model,ridge-Vector3.BACK*1.04,ridge+Vector3.BACK*1.04,0.06,"navalPlank")
		"civicClock":
			var top:=at+Vector3.UP*(height+0.91)
			box(model,top-Vector3.UP*0.22,Vector3(0.92,1.22,0.88),"romanTravertine")
			var ledge:=box(model,top+Vector3.UP*0.40,Vector3(1.08,0.16,1.02),"slate")
			ledge.name="ClockCornice"
			for sign_ in [-1.0,1.0]:
				var face:=top+Vector3(0,-0.02,0.465*float(sign_))
				var dial:=cylinder(model,face,0.048,0.29,0.29,"clockFace")
				dial.rotation.x=PI*0.5
				var center:=face+Vector3.BACK*float(sign_)*0.045
				beam(model,center,center+Vector3(0.038,0.17,0),0.022,"clockInk")
				beam(model,center,center+Vector3(-0.12,0.061,0),0.026,"clockInk")
				for direction in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
					var mark: Vector3=center+Vector3(direction.x*0.223,direction.y*0.223,0)
					box(model,mark,Vector3(0.033,0.033,0.017),"clockInk")
		"modernPlanter":
			box(model,at+Vector3.UP*0.12,Vector3(1.62,0.23,0.69),"boardConcrete")
			box(model,at+Vector3.UP*0.239,Vector3(1.49,0.035,0.56),"landDirt")
			for i in 4:
				var p:=at+Vector3(-0.57+i*0.36,0.24,0)
				cylinder(model,p+Vector3.UP*0.21,0.40,0.028,0.021,"norseTimber")
				var shrub:=SphereMesh.new()
				shrub.radius=0.24
				shrub.height=0.49+0.025*i
				shrub.radial_segments=9
				shrub.rings=5
				model.fixture_mesh(model,shrub,p+Vector3.UP*0.46,"planterLeaf")
		_:
			return false
	return true

static func porch(model: Node3D, design: Dictionary, height: float, geometry: Dictionary) -> void:
	if design.get("periodOrnament","")!="veranda" or design.get("upperLevel",false) or design.get("roofForm","")=="pediment":
		return
	var primary: Dictionary={}
	for opening in design.get("openings",[]):
		if opening.get("group","")=="outer" and opening.get("type","")=="door":
			primary=opening
			break
	if primary.is_empty():
		return
	var point:=Vector2(float(primary.point.x),float(primary.point.y))
	var nearest:=preload("res://scripts/house_plan_geometry.gd").nearest_wall(point,geometry.walls,2.0)
	if nearest.is_empty() or nearest.edge.group!="outer":
		return
	var edge: Dictionary=nearest.edge
	var dx: Vector2=(edge.b-edge.a).normalized()
	var perpendicular: Vector2=preload("res://scripts/house_facade_details.gd").exterior(edge,geometry.floors)
	var axis:=Vector3(dx.x,0,dx.y)
	var out:=Vector3(perpendicular.x,0,perpendicular.y)
	var center: Vector3=model.local(point)
	var left: Vector3=model.local(edge.a)+axis*0.08
	var right: Vector3=model.local(edge.b)-axis*0.08
	var length:=left.distance_to(right)
	if length<1.6:
		return
	center=(left+right)/2.0
	var reach:=1.12
	var top:=height-0.035
	var foot: MeshInstance3D=box(model,center+out*(0.5+reach/8.0)+Vector3.UP*0.08,Vector3(length,0.15,reach+0.1),"navalPlank")
	foot.rotation.y=-atan2(axis.z,axis.x)
	var cover:=SurfaceTool.new()
	cover.begin(Mesh.PRIMITIVE_TRIANGLES)
	cover.set_material(model.material_for("slate"))
	model.roof_panel(cover,left+out*reach+Vector3.UP*top,right+out*reach+Vector3.UP*top,
		left+Vector3.UP*(top+0.27),right+Vector3.UP*(top+0.27))
	cover.generate_normals()
	var roof:=MeshInstance3D.new()
	roof.name="VerandaRoof"
	roof.mesh=cover.commit()
	roof.set_meta("house_roof",true)
	model.add_child(roof)
	var count:=maxi(2,roundi(length/1.32))
	for i in count+1:
		var at:=left.lerp(right,float(i)/count)+out*(reach-0.1)
		box(model,at+Vector3.UP*top/2.0,Vector3(0.12,top-0.1,0.12),"lappedPine")
		box(model,at+Vector3.UP*(top-0.05),Vector3(0.18,0.08,0.18),"romanTravertine")


static func longhouse_braces(model: Node3D, design: Dictionary, height: float,geometry: Dictionary) -> void:
	if design.get("roofForm","")!="norse" or design.get("upperLevel",false):
		return
	for edge in geometry.walls:
		if edge.group!="outer" or edge.a.distance_to(edge.b)<4.6*73.0:
			continue
		var normal:=preload("res://scripts/house_facade_details.gd").exterior(edge,geometry.floors)
		var out:=Vector3(normal.x,0,normal.y)
		for ratio in [0.13,0.87]:
			var a: Vector3=model.local(edge.a.lerp(edge.b,ratio))
			box(model,a+out*0.54+Vector3.UP*0.050,Vector3(0.26,0.11,0.29),"medievalMasonry")
			beam(model,a+out*0.56+Vector3.UP*0.105,a+out*0.092+Vector3.UP*(height-0.12),0.13,"norseTimber")

static func watchtower(model: Node3D, at: Vector3,age: int) -> void:
	var frame: String="navalPlank" if age==4 else "castIron" if age==5 else "metalTrim"
	var siding: String="lappedPine" if age==4 else "corrugation" if age==5 else "boardConcrete"
	var height:=2.62 if age==4 else 3.2
	var trim: String="slate" if age==4 else "corrugation" if age==5 else "membrane"
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			var footprint:=Vector3(0.73*float(x),0,0.68*float(z))
			box(model,at+footprint+Vector3.UP*0.06,Vector3(0.26,0.13,0.26),"pavingSetts")
			beam(model,at+footprint,at+footprint*0.82+Vector3.UP*height,0.14,frame)
	for x in [-1.0,1.0]:
		var side:=Vector3(0.67*float(x),0,0)
		beam(model,at+side+Vector3(-0.015,0.28,-0.66),at+side+Vector3(0,2.48,0.54),0.09,frame)
		beam(model,at+side+Vector3(0,0.29,0.67),at+side+Vector3(0,2.45,-0.58),0.09,frame)
	box(model,at+Vector3.UP*(height+0.04),Vector3(1.68,0.17,1.60),frame)
	box(model,at+Vector3.UP*(height+0.48),Vector3(1.59,0.75,1.47),siding)
	for side in [-1.0,1.0]:
		box(model,at+Vector3(0,height+0.61,0.746*float(side)),Vector3(1.11,0.28,0.055),"windowGlass")
		box(model,at+Vector3(0,height+0.61,0.781*float(side)),Vector3(0.043,0.29,0.07),frame)
	var roof:=box(model,at+Vector3.UP*(height+0.91),Vector3(1.84,0.15,1.73),trim)
	roof.rotation.x=0.076 if age<6 else 0.0
