extends RefCounted
## Exterior joinery and masonry. Decorations follow the actual perimeter and
## openings, so editing a room never leaves trim floating at its old location.
const Plan = preload("res://scripts/house_plan_geometry.gd")
static var unit_box := BoxMesh.new()

const PROFILES := [
	{"foot":"stone","frame":"wood","accent":"hide","cornice":0.07},
	{"foot":"cutstone","frame":"plank","accent":"minoanRed","cornice":0.11},
	{"foot":"cutstone","frame":"cutstone","accent":"romanbrick","cornice":0.13},
	{"foot":"stone","frame":"wood","accent":"cedarTrim","cornice":0.11},
	{"foot":"cutstone","frame":"limestone","accent":"sageTrim","cornice":0.16},
	{"foot":"stone","frame":"brick","accent":"ironTrim","cornice":0.12},
	{"foot":"cutstone","frame":"ironTrim","accent":"sageTrim","cornice":0.10},
]

const PERIOD_PROFILES := [
	{},
	{"foot":"aegeanStone","frame":"aegeanRed","accent":"aegeanBlue","cornice":0.13},
	{"foot":"romanTravertine","frame":"romanTravertine","accent":"romanRed","cornice":0.15},
	{"foot":"medievalMasonry","frame":"norseTimber","accent":"norsePaint","cornice":0.13},
	{"foot":"pavingSetts","frame":"lappedPine","accent":"maritimePaint","cornice":0.13},
	{"foot":"sootBrick","frame":"millBrick","accent":"castIron","cornice":0.10},
	{"foot":"boardConcrete","frame":"metalTrim","accent":"darkCladding","cornice":0.10},
]

static func strip(batches: Dictionary, finish: String, a: Vector3, b: Vector3, height: float, depth: float) -> void:
	var direction := b-a
	if direction.length_squared()<0.0001:
		return
	if not batches.has(finish):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[finish]=surface
	var surface: SurfaceTool=batches[finish]
	var basis := Basis(Vector3.UP,-atan2(direction.z,direction.x))
	basis=Basis(basis.x*direction.length(),basis.y*height,basis.z*depth)
	surface.append_from(unit_box,0,Transform3D(basis,(a+b)/2.0))

static func trim(batches: Dictionary, finish: String, a: Vector3,b: Vector3, y: float, height: float, depth: float, offset: Vector3) -> void:
	strip(batches,finish,a+offset+Vector3.UP*y,b+offset+Vector3.UP*y,height,depth)

static func upright(batches: Dictionary, finish: String, at: Vector3, axis: Vector3,width: float,lo: float,hi: float,depth: float) -> void:
	trim(batches,finish,at-axis*width/2.0,at+axis*width/2.0,(lo+hi)/2.0,hi-lo,depth,Vector3.ZERO)

static func exterior(edge: Dictionary, floors: Array) -> Vector2:
	var direction: Vector2=(edge.b-edge.a).normalized()
	var normal:=Vector2(direction.y,-direction.x)
	var midpoint: Vector2=(edge.a+edge.b)/2
	for floor in floors:
		if Plan.inside(midpoint+normal*0.6,floor):
			return -normal
	return normal

static func build(target: Node3D, design: Dictionary, geometry: Dictionary, origin: Vector2, age: int, height: float) -> void:
	if geometry.floors.is_empty() or design.get("build","wall")=="open":
		return
	var period: bool=int(design.get("periodStyle",0))>0
	var profile: Dictionary=PERIOD_PROFILES[age] if period else PROFILES[age]
	var batches: Dictionary={}
	var simple_roof: bool=design.get("roofForm","") in ["gable","hip"] and design.get("roofMat","") not in ["reed","thatch"]
	var floor_band: bool=age>=1 and not design.get("upperLevel",false)
	var ornament:=str(design.get("periodOrnament",""))
	var detailed_windows: Dictionary={}
	var added_canopy := false
	var kind := str(design.get("id","")).get_slice("@",0)
	for edge in geometry.walls:
		if edge.group!="outer":
			continue
		var delta: Vector2=edge.b-edge.a
		var normal:=exterior(edge,geometry.floors)
		var out:=Vector3(normal.x,0,normal.y)
		var curved: bool=edge.get("curved",false)
		var a:=Vector3(edge.a.x-origin.x,0,edge.a.y-origin.y)/Plan.PX_PER_M
		var b:=Vector3(edge.b.x-origin.x,0,edge.b.y-origin.y)/Plan.PX_PER_M
		if delta.length()>36.0 and not curved:
			if period:
				era_trim(batches,design,ornament,age,a,b,out,height)
			if simple_roof and age>1:
				trim(batches,profile.frame,a,b,height-0.055,float(profile.cornice),0.09,out*0.105)
				if age in [2,4]:
					trim(batches,profile.accent,a,b,height-0.19,0.055,0.075,out*0.095)
			if age in [3,4,5,6] and delta.length()>100.0:
				for point in [a,b]:
					upright(batches,profile.frame,point+out*0.098,(b-a).normalized(),0.18,0.16,height-0.12,0.12)
		for span in Plan.split_wall(edge,design):
			var start:=Vector3(span.a.x-origin.x,0,span.a.y-origin.y)/Plan.PX_PER_M
			var stop:=Vector3(span.b.x-origin.x,0,span.b.y-origin.y)/Plan.PX_PER_M
			var length:=start.distance_to(stop)
			if length<0.045:
				continue
			if span.get("type","")!="door" and not design.get("upperLevel",false):
				var plinth_height:=0.16 if age<=1 else 0.22 if age<=4 else 0.26
				trim(batches,profile.foot,start,stop,plinth_height/2,plinth_height,0.13,out*0.085)
				if floor_band and not curved:
					trim(batches,profile.foot,start,stop,plinth_height+0.035,0.065,0.15,out*0.087)
			if not span.has("opening") or curved or length<0.18:
				continue
			var opening: Dictionary=span.opening
			if detailed_windows.has(opening):
				continue
			detailed_windows[opening]=true
			var axis: Vector3=(stop-start).normalized()
			var middle: Vector3=(start+stop)/2
			if opening.type=="window":
				var frame:=Plan.window_span(age,str(opening.get("style","")))
				var sill:=frame.x
				var head:=frame.y
				trim(batches,profile.frame,start-axis*0.10,stop+axis*0.10,sill-0.015,0.085,0.26,out*0.093)
				if age>=2 and head<height-0.04:
					trim(batches,profile.frame,start-axis*0.08,stop+axis*0.08,head+0.05,0.11,0.16,out*0.105)
					for point in [start,stop]:
						upright(batches,profile.frame,point+out*0.103,axis,0.085,sill,head,0.10)
				if age in [3,4] and opening.get("style","") in ["shutter","sash"] and length>0.3:
					for sign_ in [-1,1]:
						var side: Vector3=middle+axis*float(sign_)*(length/2+0.13)+out*0.125
						upright(batches,profile.accent,side,axis,0.20,sill+0.04,head-0.035,0.045)
						for y in [sill+0.13,head-0.11]:
							trim(batches,profile.frame,side-axis*0.105,side+axis*0.105,y,0.037,0.048,out*0.016)
				if opening.get("style","") in ["factoryWindow","glazed","sash","pictureWindow"]:
					trim(batches,"windowGlass",start,stop,(sill+head)/2.0,head-sill,0.022,out*0.064)
					var mullions:=2 if opening.style in ["factoryWindow","pictureWindow"] else 1
					for index in mullions:
						var bar:=start.lerp(stop,float(index+1)/(mullions+1))+out*0.086
						upright(batches,profile.accent,bar,axis,0.032,sill,head,0.038)
					if opening.style in ["factoryWindow","sash"]:
						trim(batches,profile.accent,start,stop,(sill+head)/2.0,0.034,0.045,out*0.082)
				if age==4 and kind in ["house","inn"] and length>0.35:
					trim(batches,"cedarTrim",start-axis*0.05,stop+axis*0.05,sill-0.10,0.13,0.15,out*0.22)
			elif not design.get("upperLevel",false):
				trim(batches,profile.foot,start-axis*0.09,stop+axis*0.09,0.05,0.11,0.44,out*0.17)
				if age>=2:
					var head:=1.60
					if opening.get("style","") in ["double","arched"]:
						head+=0.09
					if head<height+0.04:
						trim(batches,profile.frame,start-axis*0.13,stop+axis*0.13,head+0.045,0.13,0.21,out*0.10)
						for point in [start,stop]:
							upright(batches,profile.frame,point+out*0.10,axis,0.12,0.10,head,0.13)
				if age in [1,2] and opening.get("style","") in ["double","greek"]:
					for shift in [-0.22,0.22]:
						upright(batches,profile.accent,middle+axis*shift+out*0.15,axis,0.04,1.54,minf(height,1.70),0.065)
				if not added_canopy and age>=3 and ornament not in ["norse","veranda"] and kind in ["house","inn","railstation","guildhall","market","public_school","high_school","university"]:
					var canopy_level:=minf(height+0.06,1.87)
					if canopy_level>1.73:
						added_canopy=true
						var structure: String=profile.accent if age>=5 else profile.frame
						var reach:=0.61 if age<=4 else 0.76
						var left:=start-axis*0.22
						var right:=stop+axis*0.22
						trim(batches,structure,left,right,canopy_level,0.10,reach,out*(0.12+reach/2.0))
						trim(batches,profile.frame,left,right,canopy_level-0.04,0.10,0.06,out*(reach+0.10))
						if age<=4:
							for point in [left,right]:
								upright(batches,structure,point+out*(reach+0.08),axis,0.09,0.06,canopy_level,0.10)
	for finish in batches:
		var surface: SurfaceTool=batches[finish]
		surface.set_material(target.material_for(finish))
		var mesh:=MeshInstance3D.new()
		mesh.name="Facade_"+finish
		mesh.mesh=surface.commit()
		target.add_child(mesh)



static func era_trim(batches: Dictionary, design: Dictionary, ornament: String, age: int, a: Vector3,b: Vector3,out: Vector3,height: float) -> void:
	var axis:=(b-a).normalized()
	var length:=a.distance_to(b)
	var upper: bool=design.get("upperLevel",false)
	match age:
		1:
			if design.get("roofMat","") in ["reed","thatch"]:
				return
			var cap:=height-0.12
			trim(batches,"aegeanRed",a,b,cap,0.22,0.10,out*0.10)
			trim(batches,"aegeanFrieze",a,b,cap-0.19,0.14,0.09,out*0.101)
			trim(batches,"aegeanSlab",a,b,cap-0.245,0.05,0.085,out*0.10)
			if length>=1.6 and ornament=="aegeanCivic":
				var count:=maxi(3,roundi(length/0.34))
				for index in count:
					var value:=a.lerp(b,(index+0.5)/count)+out*0.153
					upright(batches,"aegeanSlab",value,axis,0.085,cap-0.075,cap+0.055,0.036)
		2:
			if length<0.8:
				return
			trim(batches,"romanTravertine",a,b,height-0.04,0.16,0.14,out*0.11)
			trim(batches,"romanRed",a,b,height-0.18,0.09,0.08,out*0.098)
			if ornament=="romanCivic" and length>=2.0:
				var count:=maxi(3,roundi(length/0.34))
				for index in count:
					var value:=a.lerp(b,(index+0.5)/count)+out*0.147
					upright(batches,"romanStucco",value,axis,0.086,height-0.155,height-0.055,0.046)
		3:
			if ornament=="norse":
				trim(batches,"norsePaint",a,b,height-0.10,0.21,0.14,out*0.113)
				if length>1.9:
					var count:=maxi(1,floori((length-0.55)/1.45))
					for index in range(1,count+1):
						var at:=a.lerp(b,float(index)/(count+1))+out*0.13
						upright(batches,"norseTimber",at,axis,0.14,0.15,height-0.16,0.19)
			elif length>0.6:
				trim(batches,"medievalMasonry",a,b,height-0.11,0.20,0.10,out*0.105)
		4:
			var cornice: String="maritimePaint" if ornament=="dock" else "lappedPine"
			trim(batches,cornice,a,b,height-0.12,0.23,0.11,out*0.11)
			if upper:
				trim(batches,cornice,a,b,0.095,0.17,0.12,out*0.107)
		5:
			trim(batches,"sootBrick",a,b,height-0.11,0.19,0.15,out*0.113)
			if ornament=="factory":
				trim(batches,"castIron",a,b,height-0.245,0.045,0.08,out*0.099)
		6:
			trim(batches,"metalTrim",a,b,height-0.07,0.12,0.085,out*0.10)
			if upper:
				trim(batches,"boardConcrete",a,b,0.055,0.14,0.18,out*0.115)
