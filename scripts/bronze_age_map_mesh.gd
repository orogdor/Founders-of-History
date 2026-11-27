extends RefCounted
## World map silhouette, in metres, built once per plan. Roofs, yard entrances
## and work equipment occupy the same positions as in the full-size site.
const Plan = preload("res://scripts/house_plan_geometry.gd")
const Fence = preload("res://scripts/house_fence.gd")
const PLASTER := Color("d0a46e")
const SOIL := Color("ac8b64")
const CLAY := Color("aa7751")
const STONE := Color("99866b")
const WOOD := Color("75543a")
const REED := Color("bfaa76")
const OPENING := Color("35281c")
const GREEN := Color("808542")
const CLOTH := Color("d7c69e")

var tool := SurfaceTool.new()

func build(plan: Dictionary, kind: String, material: Material) -> ArrayMesh:
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var yard = plan.get("yard")
	if not yard is Array or yard.is_empty():
		yard = plan.get("plot")
	if yard is Array and yard.size() >= 3:
		var ground := PackedVector2Array()
		for p in yard:
			ground.append(Plan.point(p) / Plan.PX_PER_M)
		cap(ground, 0.012, ground_color(plan), 1)
	if plan.get("field") is Dictionary and plan.get("plot") is Array:
		crops(plan.plot, plan.field)
	add_storey(plan, 0.0)
	var upper = plan.get("upper")
	if upper is Dictionary and not upper.get("rooms", []).is_empty():
		var next := plan.duplicate()
		next.merge(upper, true)
		add_storey(next, storey_height(plan) + 0.13)
	for f in Fence.layout(plan):
		barrier(f, kind)
	var pier = plan.get("pier")
	if pier is Dictionary:
		var a := Plan.point(pier.a) / Plan.PX_PER_M
		var b := Plan.point(pier.b) / Plan.PX_PER_M
		var half_width := float(pier.get("halfWidth", 45)) / Plan.PX_PER_M
		rail(a, b, half_width * 2, 0.23, 0.23, WOOD)
		var normal := (b-a).normalized().orthogonal() * half_width * 0.82
		for side: float in [-1.0, 1.0]:
			post(b + normal * side, 0.0, 0.75, 0.19)
	var drawn := {}
	for item in plan.get("items", []):
		var id := str(item.get("type", ""))
		var count := int(drawn.get(id, 0))
		if count < 6:
			fixture(id, Plan.point(item.point) / Plan.PX_PER_M, kind)
			drawn[id] = count + 1
	tool.index()
	return tool.commit()

func ground_color(_plan: Dictionary) -> Color:
	return SOIL

static func storey_height(plan: Dictionary) -> float:
	return 1.55 * float(plan.get("wallScale", 100)) / 100.0

func add_storey(plan: Dictionary, lift: float) -> void:
	var h := storey_height(plan)
	var stonework := str(plan.get("wallStyle","")) in ["aegeanStone", "cyclopean", "cutstone", "stone"]
	for room in plan.get("rooms", []):
		var footprint := Plan.room_polygon(room)
		if footprint.size()<3: continue
		var outline := PackedVector2Array()
		for i in footprint.size():
			if room.type != "round" or i % 4 == 0:
				outline.append(footprint[i] / Plan.PX_PER_M)
		var top := lift + h * float(room.get("heightFactor",1))
		var finish := STONE if stonework else PLASTER
		var form := str(plan.get("roofForm","earthenShed"))
		if plan.get("build","wall") == "open":
			for i in outline.size():
				post(outline[i], lift, top-lift, 0.18)
		else:
			prism(outline, lift+0.02, top, finish)
			if lift <= 0.0 and not stonework:
				prism(expand(outline,0.035), 0.0, minf(0.40,top), STONE, 2)
		if form == "none":
			continue
		var roof := expand(outline,0.11)
		var roof_mat := str(plan.get("roofMat", "earth"))
		var pigment := REED if roof_mat in ["reed", "thatch", "matting"] else CLAY
		if form == "battlement":
			prism(roof,top,top+0.13,STONE,2)
			for i in outline.size():
				var a:=outline[i]
				var b:=outline[(i+1)%outline.size()]
				var n:=maxi(1,roundi(a.distance_to(b)/1.05))
				for j in n:
					rail(a.lerp(b,(j+0.08)/n), a.lerp(b,(j+0.62)/n),0.27,top+0.12,0.36,STONE)
		elif form in ["earthenShed","flat","terrace","roofTerrace"]:
			shed(roof, top, pigment, 0.045 if form=="earthenShed" else 0.0)
			if form=="earthenShed" and room.type=="rect":
				var front := outline[0].y
				var left := outline[0].x
				var right := left
				for corner in outline:
					front = maxf(front,corner.y)
					left = minf(left,corner.x)
					right = maxf(right,corner.x)
				var ends := clampi(roundi((right-left)/1.2),2,5)
				for i in ends:
					var x := lerpf(left,right,(i+0.5)/ends)
					prism(rect(Vector2(x,front+0.13),0.18,0.22),top-0.05,top+0.075,WOOD,2)
		elif room.type == "rect":
			pitched(roof,top,minf(1.0,0.25*outline[0].distance_to(outline[1])),pigment)
		else:
			var centre:=Vector2.ZERO
			for p in roof: centre+=p
			centre/=roof.size()
			for i in roof.size():
				face(v(roof[i],top),v(roof[(i+1)%roof.size()],top),v(centre,top+0.73),Vector3.UP,pigment,1)
	add_openings(plan, lift)

func add_openings(plan: Dictionary, lift: float) -> void:
	var h := storey_height(plan)
	var geometry := Plan.plan_geometry(plan)
	var add_porch: bool = plan.get("porch", "") == "front" and is_zero_approx(lift)
	for entry in plan.get("openings", []):
		if entry.get("group","") != "outer": continue
		var p := Plan.point(entry.point)
		var match_ := Plan.nearest_wall(p,geometry.walls,1.5)
		if match_.is_empty(): continue
		var edge: Dictionary=match_.edge
		if edge.group!="outer": continue
		var axis: Vector2=(edge.b-edge.a).normalized()
		var n:=axis.orthogonal()
		for floor_ in geometry.floors:
			if Plan.inside(match_.point+n*0.15,floor_):
				n=-n
				break
		var c:=p / Plan.PX_PER_M + n*0.04
		var door: bool = entry.type=="door"
		var width:=Plan.opening_width(entry,edge)/Plan.PX_PER_M
		var room_h := h
		for room in plan.get("rooms",[]):
			if not room.has("heightFactor"):continue
			var boundary:=Plan.room_polygon(room)
			if Plan.inside(p-n*0.25,boundary):
				room_h=h*float(room.heightFactor)
		var top:=lift+minf(room_h-0.10,1.78 if door else 1.44)
		var base:=lift+(0.025 if door else 0.87)
		if top <= base: continue
		draw_opening(c, axis, width, base, top, door, str(entry.get("style","")))
		if door and add_porch:
			porch(c, axis, n, width, lift, top, plan)
			add_porch = false

func draw_opening(c: Vector2, axis: Vector2, width: float, base: float, top: float, door: bool, _style: String) -> void:
	rail(c-axis*width/2,c+axis*width/2,0.09,base,top-base,OPENING)
	if door:
		rail(c-axis*(width*0.5+0.11),c+axis*(width*0.5+0.11),0.15,top,0.15,WOOD)

func porch(c: Vector2, axis: Vector2, n: Vector2, width: float, lift: float, top: float, _plan: Dictionary) -> void:
	var left := c - axis * (width * 0.5 + 0.30)
	var right := c + axis * (width * 0.5 + 0.30)
	var projection := n * 1.15
	post(left + projection, lift, top, 0.14)
	post(right + projection, lift, top, 0.14)
	shed(PackedVector2Array([left, right, right + projection, left + projection]), top, REED, 0.045)

static func v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x,y,p.y)

func face(a: Vector3,b: Vector3,c: Vector3,out: Vector3,tint: Color,finish: int) -> void:
	var normal := (c-a).cross(b-a).normalized()
	if normal.length_squared()<0.5: return
	if normal.dot(out) < 0:
		var old:=b
		b=c
		c=old
		normal=-normal
	for p in [a,b,c]:
		tool.set_color(tint)
		tool.set_uv(Vector2(finish,0))
		tool.set_normal(normal)
		tool.add_vertex(p)

func panel(a: Vector3,b: Vector3,c: Vector3,d: Vector3,out: Vector3,tint: Color,finish: int) -> void:
	face(a,b,c,out,tint,finish)
	face(a,c,d,out,tint,finish)

func cap(outline: PackedVector2Array,h: float, tint: Color, finish: int) -> void:
	var indices:=Geometry2D.triangulate_polygon(outline)
	for i in range(0,indices.size(),3):
		face(v(outline[indices[i]],h),v(outline[indices[i+1]],h),v(outline[indices[i+2]],h),Vector3.UP,tint,finish)

static func expand(points: PackedVector2Array, by: float) -> PackedVector2Array:
	var offset:=Geometry2D.offset_polygon(points,by,Geometry2D.JOIN_MITER)
	return offset[0] if not offset.is_empty() else points

func prism(outline: PackedVector2Array,lo: float,hi: float,tint: Color,finish:=0) -> void:
	for i in outline.size():
		var a:=outline[i]
		var b:=outline[(i+1)%outline.size()]
		var n:=(b-a).orthogonal().normalized()
		if Plan.inside((a+b)/2+n*0.001,outline): n=-n
		panel(v(a,lo),v(b,lo),v(b,hi),v(a,hi),v(n,0),tint,finish)
	cap(outline,hi,tint,finish)

func shed(outline: PackedVector2Array,height: float,tint: Color,pitch: float) -> void:
	var max_z:=outline[0].y
	for p in outline: max_z=maxf(max_z,p.y)
	var top:=PackedVector3Array()
	for p in outline: top.append(v(p,height+0.17+pitch*(max_z-p.y)))
	for i in outline.size():
		var j:=(i+1)%outline.size()
		var n:=(outline[j]-outline[i]).orthogonal().normalized()
		if Plan.inside((outline[j]+outline[i])/2+n*0.001,outline): n=-n
		panel(v(outline[i],height-0.01),v(outline[j],height-0.01),top[j],top[i],v(n,0),tint.darkened(0.14),1)
	var ids:=Geometry2D.triangulate_polygon(outline)
	for i in range(0,ids.size(),3):face(top[ids[i]],top[ids[i+1]],top[ids[i+2]],Vector3.UP,tint,1)

func pitched(outline: PackedVector2Array,h: float,rise: float,tint: Color) -> void:
	var bounds:=Rect2(outline[0],Vector2.ZERO)
	for p in outline:bounds=bounds.expand(p)
	var a:=bounds.position
	var c:=bounds.end
	var b:=Vector2(c.x,a.y)
	var d:=Vector2(a.x,c.y)
	if bounds.size.x>bounds.size.y:
		var temp:=b
		b=d
		d=temp
	var r1:=v((a+b)/2,h+rise)
	var r2:=v((c+d)/2,h+rise)
	panel(v(a,h),v(d,h),r2,r1,Vector3.UP,tint,1)
	panel(v(b,h),v(c,h),r2,r1,Vector3.UP,tint,1)
	face(v(a,h),v(b,h),r1,v((a-d).normalized(),0),tint,1)
	face(v(c,h),v(d,h),r2,v((d-a).normalized(),0),tint,1)

static func rect(c: Vector2, w: float, d: float) -> PackedVector2Array:
	var s:=Vector2(w,d)*0.5
	return PackedVector2Array([c-s,c+Vector2(s.x,-s.y),c+s,c+Vector2(-s.x,s.y)])

func post(c: Vector2,base: float,height: float,width: float) -> void:
	prism(rect(c,width,width),base,base+height,WOOD,2)

func rail(a: Vector2,b: Vector2,width: float,base: float,height: float,tint: Color) -> void:
	if a.distance_squared_to(b)<0.00001: return
	var side:=(b-a).normalized().orthogonal()*width/2
	prism(PackedVector2Array([a-side,b-side,b+side,a+side]),base,base+height,tint,2)

func barrier(f: Dictionary, kind: String) -> void:
	var a:=Plan.point(f.a)/Plan.PX_PER_M
	var b:=Plan.point(f.b)/Plan.PX_PER_M
	match str(f.kind):
		"gateLine":
			var h:=2.05 if f.get("gateType","")!="rail" else 0.78
			post(a,0,h,0.24)
			post(b,0,h,0.24)
			if h>1.0: rail(a,b,0.34,h-0.12,0.25,STONE if kind=="gatehouse" else WOOD)
		"highStone","rampart","stoneLine":
			var h:=2.25 if f.kind=="highStone" else 1.6 if f.kind=="rampart" else 1.65 if kind=="stonewall" else 0.56
			rail(a,b,0.75 if h>1 else 0.31,0,h,STONE)
		"palisadeLine":
			rail(a,b,0.36,0,1.64,WOOD)
			var count:=maxi(1,ceili(a.distance_to(b)/0.52))
			for i in count:
				post(a.lerp(b,(i+0.5)/count),1.62,0.22,0.22)
		_:
			rail(a,b,0.10,0.42,0.18,WOOD)
			post(a,0,0.78,0.14)
			post(b,0,0.78,0.14)

func crops(points: Array,data: Dictionary) -> void:
	var poly:=PackedVector2Array()
	for p in points:poly.append(Plan.point(p)/Plan.PX_PER_M)
	if poly.size()<3:return
	var bounds:=Rect2(poly[0],Vector2.ZERO)
	for p in poly:bounds=bounds.expand(p)
	var crop_tint:=REED if data.get("crop","wheat") in ["wheat","barley"] else GREEN
	for i in 6:
		var x:=bounds.position.x+bounds.size.x*(i+0.5)/6
		var intersections:=PackedFloat32Array()
		for j in poly.size():
			var a:=poly[j]
			var b:=poly[(j+1)%poly.size()]
			if (a.x<=x and x<b.x) or (b.x<=x and x<a.x): intersections.append(lerpf(a.y,b.y,(x-a.x)/(b.x-a.x)))
		intersections.sort()
		for j in range(0,intersections.size()-1,2):
			var start := intersections[j]+0.08
			var end := intersections[j+1]-0.08
			if end<=start:continue
			var width := minf(0.32,bounds.size.x/14)
			rail(Vector2(x,start),Vector2(x,end),width*1.35,0.015,0.04,SOIL.darkened(0.22))
			# Each group of stalks tapers along the row. Their crowns break up
			# the outline of the plot when seen from the campaign camera.
			var bunches := clampi(roundi((end-start)/0.64),2,10)
			for k in bunches:
				var a:=Vector2(x,lerpf(start,end,float(k)/bunches))
				var b:=Vector2(x,lerpf(start,end,(k+0.92)/bunches))
				var side:=Vector2(width*0.52,0)
				var crown_height:=0.25+0.055*sin(i*2.7+k*4.1)
				var color:=crop_tint.darkened(0.035*((k+i)%3))
				var tip_a:=v(a+(b-a)*0.18,crown_height)
				var tip_b:=v(b-(b-a)*0.12,crown_height*0.94)
				panel(v(a-side,0.05),v(b-side,0.05),tip_b,tip_a,Vector3(-1,1,0),color,1)
				panel(v(a+side,0.05),v(b+side,0.05),tip_b,tip_a,Vector3(1,1,0),color,1)
				face(v(a-side,0.05),v(a+side,0.05),tip_a,Vector3.FORWARD,color,1)
				face(v(b-side,0.05),v(b+side,0.05),tip_b,Vector3.BACK,color,1)

func round_taper(c: Vector2,base: float,h: float,bottom: float,top: float,tint: Color,finish:=2) -> void:
	var rim:=PackedVector2Array()
	for i in 8:
		var a:=Vector2.from_angle(TAU*i/8)
		var b:=Vector2.from_angle(TAU*(i+1)/8)
		rim.append(c+a*top)
		panel(v(c+a*bottom,base),v(c+b*bottom,base),v(c+b*top,base+h),v(c+a*top,base+h),v(a+b,0),tint,finish)
	cap(rim,base+h,tint,finish)

func shelter(p: Vector2,w: float,d: float,h: float,tint: Color) -> void:
	var outline:=rect(p,w,d)
	for corner in outline:
		post(corner.lerp(p,0.10),0,h,0.13)
	shed(outline,h,tint,0.12)

func fixture(id: String,p: Vector2,kind: String) -> void:
	match id:
		"kiln","oven","bronzeHearth":
			round_taper(p,0,0.53,0.64,0.69,CLAY)
			round_taper(p,0.53,0.75,0.69,0.28,CLAY)
			round_taper(p,1.28,0.04,0.20,0.20,OPENING)
		"well","wellRoof":
			round_taper(p,0,0.51,0.57,0.60,STONE)
			round_taper(p,0.51,0.02,0.43,0.43,OPENING)
			if id=="wellRoof":shelter(p,1.65,1.28,1.48,REED)
		"stall","periodMarket":
			shelter(p,1.26,1.02,1.22,CLOTH)
		"shaft","quarrySite","claySite","bronzeOutcrop":
			var rock:=CLAY if kind=="claypit" else Color("7e8878") if kind=="coppermine" else STONE
			for i in 3:
				var c:=p+Vector2.from_angle(i*2.10)*0.44
				round_taper(c,0,0.55+i*0.16,0.72,0.29,rock)
			if id=="shaft":
				shelter(p+Vector2(0,0.59),1.36,0.72,1.33,WOOD)
		"tower":
			var outline:=rect(p,1.43,1.24)
			for c in outline:post(c,0,2.88,0.21)
			prism(rect(p,1.64,1.43),2.57,3.03,WOOD)
			shelter_level(p,3.9)
		"target":
			post(p,0,0.94,0.12)
			prism(rect(p,0.61,0.16),0.57,1.15,REED)
			prism(rect(p+Vector2(0,0.083),0.28,0.016),0.71,1.00,CLAY)
		"flaxRow","vegBed":
			prism(rect(p,1.05,0.53),0.02,0.19,GREEN if id=="vegBed" else REED)
		"manger","trough","hay":
			prism(rect(p,1.14,0.60),0.03,0.40 if id=="hay" else 0.25,REED if id=="hay" else WOOD)
		"workShelter","sideShelter","longShelter","stockShelter","sideStockShelter","canopy":
			shelter(p,1.71,1.17,1.34,REED)
		"bronzeCrane":
			post(p,0,2.23,0.22)
			rail(p-Vector2(0.44,0),p+Vector2(1.10,0),0.16,1.92,0.16,WOOD)
		"bronzeCargo","bronzeBlocks","roadStones","ore":
			var stacked_stone := id != "bronzeCargo"
			var tint := STONE if stacked_stone else WOOD
			prism(rect(p,1.1,0.65),0.02,0.34,tint,2)
			prism(rect(p+Vector2(0.13,0.04),0.65,0.44),0.34,0.57,tint.lightened(0.06),2)
		"bronzeNet","clothRack","periodDrying":
			post(p-Vector2(0.65,0),0,1.37,0.12)
			post(p+Vector2(0.65,0),0,1.37,0.12)
			rail(p-Vector2(0.72,0),p+Vector2(0.72,0),0.10,1.26,0.10,WOOD)
			prism(rect(p,0.99,0.055),0.58,1.27,REED if id=="bronzeNet" else CLOTH,2)
		"householdJar","bronzePaintedJar","aegeanAmphoraRack":
			var jars := 3 if id=="aegeanAmphoraRack" else 1
			for i in jars:
				var c:=p+Vector2(0.42*(i-(jars-1)*0.5),0)
				round_taper(c,0.02,0.39,0.15,0.23,CLAY,2)
				round_taper(c,0.41,0.15,0.23,0.13,CLAY,2)
		"fruitTree","saplings":
			var factor := 1.0 if id=="fruitTree" else 0.61
			post(p,0,1.4*factor,0.20*factor)
			round_taper(p,0.98*factor,0.72*factor,0.48*factor,0.75*factor,GREEN,2)
			round_taper(p,1.70*factor,0.67*factor,0.75*factor,0.19*factor,GREEN,2)
		"bronzeSledge":
			for side: float in [-1.0,1.0]:
				prism(rect(p+Vector2(0,side*0.20),1.15,0.12),0.02,0.16,WOOD,2)
			prism(rect(p,0.86,0.55),0.16,0.37,STONE,2)
		"banner":
			post(p,0,2.18,0.11)
			prism(rect(p+Vector2(0.26,0),0.52,0.044),1.49,2.13,CLAY,2)
		"logs","periodTimber":
			prism(rect(p,1.2,0.59),0.02,0.33,WOOD)
		"bronzeBoat","bronzeBoatFrame":
			var hull:=PackedVector2Array([p+Vector2(0,-1.05),p+Vector2(.43,-.45),p+Vector2(.43,.55),p+Vector2(0,1.05),p+Vector2(-.43,.55),p+Vector2(-.43,-.45)])
			prism(hull,0.04,0.34,WOOD)
		"bridgeSpan":
			prism(rect(p,1.6,3.6),0.22,0.47,WOOD)

func shelter_level(p: Vector2, top: float) -> void:
	for corner in rect(p,1.25,1.02):post(corner,3.0,top-3.0,0.10)
	pitched(rect(p,1.71,1.53),top,0.39,REED)

