extends RefCounted
const Kit=preload("res://scripts/iron_age_mesh.gd")
const Geo=preload("res://scripts/house_plan_geometry.gd")
const Facade=preload("res://scripts/house_facade_details.gd")
const Mason=preload("res://scripts/bronze_home_structure.gd")

static func tiled_roof(model:Node3D,room:Dictionary,design:Dictionary,height:float) -> bool:
	var form:String=design.get("roofForm","gable")
	if room.type!="rect" or form not in ["hip","gable","pediment"] or design.get("roofMat","") not in ["tile","romanTile"]:return false
	var a:Vector3=model.local(Geo.point(room.a))
	var b:Vector3=model.local(Geo.point(room.b))
	var tall:=Mason.room_height(room,height)
	var rotate:=absf(b.x-a.x)<absf(b.z-a.z)
	var length:=maxf(absf(a.x-b.x),absf(a.z-b.z))+.34
	var width:=minf(absf(a.x-b.x),absf(a.z-b.z))+.42
	var h:=width*.245*clampf(float(design.get("roofHeight",100))*.01,.35,1.7)
	var hx:=length*.5
	var hz:=width*.5
	var shortened:=minf(hz*.83,hx-.025) if form=="hip" else 0.0
	var eave:=tall+.085
	var kit:=Kit.new()
	kit.variation=model.texture_variant
	var n0:=Vector3(-hx,eave,-hz)
	var n1:=Vector3(hx,eave,-hz)
	var s0:=Vector3(-hx,eave,hz)
	var s1:=Vector3(hx,eave,hz)
	var left:=Vector3(-hx+shortened,eave+h,0)
	var right:=Vector3(hx-shortened,eave+h,0)
	kit.tiled_plane(n0,n1,right,left)
	kit.tiled_plane(s0,s1,right,left)
	for side:int in [-1,1]:
		var x:=hx*side
		var gable:=Vector3(x,eave,0)
		kit.member(Vector3(x,eave-.075,-hz),Vector3(x,eave-.075,hz),.15,.10,"brick")
		if form=="hip":
			var peak:=right if side==1 else left
			kit.tiled_plane(gable+Vector3.BACK*hz,gable+Vector3.FORWARD*hz,peak,peak)
			for z:float in [-hz,hz]:kit.ridge(Vector3(x,eave+.035,z),peak+Vector3.UP*.044,.074)
		else:
			var panel:=kit.builder("lime" if design.get("wallStyle","")=="romanStucco" else "brick")
			var end:=Vector3(side*(hx-.16),eave,0)
			Mason.triangle(panel,end+Vector3.FORWARD*(hz-.17),end+Vector3.BACK*(hz-.17),end+Vector3.UP*(h-.05),Vector3.RIGHT*side)
			if form=="pediment":
				kit.member(gable+Vector3.FORWARD*hz,gable+Vector3.BACK*hz,.13,.18,"ashlar")
				for z:float in [-hz,hz]:
					kit.beam(gable+Vector3.BACK*z,gable+Vector3.UP*h,.062,"ashlar",.062,6)
	for z:float in [-hz,hz]:
		kit.member(Vector3(-hx,eave-.075,z),Vector3(hx,eave-.075,z),.145,.105,"wood")
	kit.ridge(left+Vector3.UP*.05,right+Vector3.UP*.05)
	Kit.install(model,kit.meshes(),(a+b)*.5,"RoofDeck",PI*.5 if rotate else 0.0)
	return true

static func exterior(model:Node3D,design:Dictionary,geometry:Dictionary,height:float) -> void:
	if design.get("build","wall")=="open":return
	var kit:=Kit.new()
	kit.variation=model.texture_variant
	for edge in geometry.walls:
		if edge.group!="outer":continue
		var normal:=Facade.exterior(edge,geometry.floors)
		var out:=Vector3(normal.x,0,normal.y)
		var y:=Mason.wall_height(edge,design.rooms,height)
		var a:Vector3=model.local(edge.a)
		var b:Vector3=model.local(edge.b)
		if b.distance_to(a)<.04:continue
		var axis:=(b-a).normalized()
		for span in Geo.split_wall(edge,design,"romanStucco"):
			var first:Vector3=model.local(span.a)
			var last:Vector3=model.local(span.b)
			var finish:=str(span.finish)
			if first.distance_squared_to(last)<.001 or finish not in ["romanStucco","romanTravertine","romanBrick","romanRed","romanMosaic"]:continue
			var gap:String=span.get("type","")
			if gap!="door" and design.get("base","plinth")!="none" and not design.get("upperLevel",false):
				var foundation:=out*.048+Vector3.UP*.127
				kit.member(first+foundation,last+foundation,.254,.218,"ashlar")
			if gap!="door" and finish=="romanStucco":
				var dado:=out*.102+Vector3.UP*.43
				kit.member(first+dado,last+dado,.42,.018,"redpaint")
				kit.member(first+dado+Vector3.UP*.218,last+dado+Vector3.UP*.218,.023,.021,"ochre")
			if finish in ["romanBrick","romanTravertine"] and y>1.3 and gap=="":
				var bond:=out*.103+Vector3.UP*(y*.55)
				kit.member(first+bond,last+bond,.093,.027,"brick")
			var cornice:=out*.016+Vector3.UP*(y-.055)
			kit.member(first+cornice,last+cornice,.105,.275,"brick")
			if gap=="window":
				var sill:Vector2=Geo.window_span(2,span.opening.get("style",""))
				var step:=out*.044+Vector3.UP*(sill.x-.05)
				kit.member(first-axis*.064+step,last+axis*.064+step,.093,.31,"ashlar")
	Kit.install(model,kit.meshes(),Vector3.ZERO,"RomanFacade")
	porch(model,design,geometry,height)

static func porch(model:Node3D,design:Dictionary,geometry:Dictionary,height:float) -> void:
	if design.get("porch","none")=="none" or design.get("upperLevel",false):return
	for opening in design.get("openings",[]):
		if opening.type!="door" or opening.group!="outer":continue
		var p:=Geo.point(opening.point)
		for edge in geometry.walls:
			if edge.group!="outer" or p.distance_to(Geo.closest(p,edge.a,edge.b))>.7:continue
			var outward:=Facade.exterior(edge,geometry.floors)
			var frontage:float=model.local(edge.a).distance_to(model.local(edge.b))
			var wide:=minf(4.05 if design.ironFamily in ["civic","scribe"] else 2.8,frontage-.13)
			if wide<1.24:continue
			var top:=minf(2.92,Mason.wall_height(edge,design.rooms,height)-.19)
			var depth:=1.20 if wide>3 else .94
			var kit:=Kit.new()
			kit.variation=model.texture_variant
			for x:float in [-wide*.5+.16,wide*.5-.16]:
				kit.pillar(Vector3(x,0,depth),top,str(design.get("columns","doric")))
			kit.cover=true
			for level in 2:
				kit.member(Vector3(-wide*.5,top+.05+level*.105,depth),Vector3(wide*.5,top+.05+level*.105,depth),.10,.27+level*.055,"ashlar" if level==0 else "brick")
			var plane_a:=Vector3(-wide*.5-.12,top+.20,depth+.16)
			var plane_b:=Vector3(wide*.5+.12,top+.20,depth+.16)
			var peak:=Vector3(0,clampf(depth*.35,.26,.56),-depth-.16)
			kit.tiled_plane(plane_a,plane_b,plane_b+peak,plane_a+peak)
			var rim:=Vector3.UP*.019
			kit.ridge(plane_a+peak+rim,plane_b+peak+rim,.054)
			Kit.install(model,kit.meshes(),model.local(p),"RomanPortico",atan2(outward.x,outward.y))
			return

static func fortified_edge(model:Node3D,fence:Dictionary,a:Vector3,b:Vector3,stair:Dictionary) -> void:
	var kit:=Kit.new()
	kit.variation=model.texture_variant
	var axis:=(b-a).normalized()
	var out:=axis.cross(Vector3.UP)
	var len:=a.distance_to(b)
	var heavy:bool=fence.kind=="highStone"
	var half:=.73 if heavy else .25
	var top:=2.24 if heavy else .78
	kit.member(a+Vector3.UP*top*.5,b+Vector3.UP*top*.5,top,half*2,"ashlar")
	for i in (3 if heavy else 1):
		var h:=.32+i*.65
		kit.member(a+Vector3.UP*h,b+Vector3.UP*h,.106,half*2+.075,"brick")
	if heavy:
		for side:float in [-1,1]:
			var lateral:=out*side*(half-.14)
			var cut:float=a.distance_to(model.local(stair.opening)) if not stair.is_empty() and stair.wall==fence and int(stair.side)==side else -100.0
			var clearance:=float(stair.get("landingWidth",0.0))/Geo.PX_PER_M*.55
			var count:=maxi(2,roundi(len/.73))
			for i in count:
				var x:float=(i+.5)*len/count
				if absf(x-cut)<clearance+.22:continue
				var at:=a+axis*x+lateral+Vector3.UP*top
				Mason.bar(kit.builder("ashlar"),at+Vector3.UP*.19,axis,out,len/count+.007,.38,.27)
				if i%2==0:
					Mason.bar(kit.builder("ashlar"),at+Vector3.UP*.61,axis,out,len/count*.81,.48,.27)
					Mason.bar(kit.builder("brick"),at+Vector3.UP*.87,axis,out,len/count*.88,.074,.34)
	else:
		kit.member(a+Vector3.UP*(top+.037),b+Vector3.UP*(top+.037),.075,.55,"brick")
	Kit.install(model,kit.meshes(),Vector3.ZERO,"RomanStoneWall")

static func tower_deck(model:Node3D,room:Dictionary,height:float) -> void:
	var outline:=Geo.room_polygon(room)
	var indices:=Geometry2D.triangulate_polygon(outline)
	if indices.is_empty():return
	var kit:=Kit.new()
	kit.variation=model.texture_variant
	var top:=Mason.room_height(room,height)
	var deck:=kit.builder("brick")
	for i in range(0,indices.size(),3):
		Mason.triangle(deck,model.local(outline[indices[i]],top+.038),model.local(outline[indices[i+1]],top+.038),model.local(outline[indices[i+2]],top+.038),Vector3.UP)
	for edge in Geo.edges(outline):
		var a:Vector3=model.local(edge.a,top)
		var b:Vector3=model.local(edge.b,top)
		var length:=a.distance_to(b)
		if length<.07:continue
		var axis:=(b-a)/length
		var out:=axis.cross(Vector3.UP)
		kit.member(a+Vector3.UP*.16,b+Vector3.UP*.16,.32,.28,"ashlar")
		kit.member(a+Vector3.UP*.32,b+Vector3.UP*.32,.075,.32,"brick")
		var count:=maxi(1,roundi(length/.89))
		for j in count:
			var pos:=a.lerp(b,(j+.5)/count)
			Mason.bar(kit.builder("ashlar"),pos+Vector3.UP*.54,axis,out,length/count*.55,.42,.28)
			Mason.bar(kit.builder("tile"),pos+Vector3.UP*.78,axis,out,length/count*.61,.081,.35)
	Kit.install(model,kit.meshes(),Vector3.ZERO,"RomanRampartDeck")

static func door_arch(model:Node3D,first:Vector3,last:Vector3,top:float) -> void:
	var kit:=Kit.new()
	kit.variation=model.texture_variant
	var axis:=(last-first).normalized()
	var out:=axis.cross(Vector3.UP)
	var mid:=(first+last)*.5
	var radius:=first.distance_to(last)*.5
	var rise:=radius*.86
	var spring:=top-rise
	var finish:="brick" if model.iron_family in ["house","civic","scribe","farm","trade","stable","well"] else "ashlar"
	kit.arch(mid+Vector3.UP*spring,axis,out,radius,rise,.107,.259,finish,11)
	for pos:Vector3 in [first-axis*.049,last+axis*.049]:
		var n:=maxi(3,roundi(spring/.32))
		for j in n:
			Mason.bar(kit.builder(finish),pos+Vector3.UP*((j+.5)*spring/n),axis,out,.106,spring/n-.008,.236)
	Kit.install(model,kit.meshes(),Vector3.ZERO,"RomanDoorArch")

static func court(model:Node3D,design:Dictionary,geometry:Dictionary) -> void:
	if not design.get("yard") is Array or design.get("upperLevel",false):return
	var lo:=Vector2(INF,INF)
	var hi:=Vector2(-INF,-INF)
	for polygon in geometry.floors:
		for point:Vector2 in polygon:
			lo=lo.min(point)
			hi=hi.max(point)
	if lo.x>=hi.x:return
	var areas: Array=[PackedVector2Array([lo,Vector2(hi.x,lo.y),hi,Vector2(lo.x,hi.y)])]
	for floor in geometry.floors:
		var remainder:Array=[]
		for area in areas:remainder.append_array(Geometry2D.clip_polygons(area,floor))
		areas=remainder
	for item in design.get("items",[]):
		if item.type!="romanBasin":continue
		for polygon in areas:
			if not Geometry2D.is_point_in_polygon(Geo.point(item.point),polygon):continue
			var indices:=Geometry2D.triangulate_polygon(polygon)
			if indices.is_empty():continue
			var paving:=Mason.surface(model.material_for("romanMosaic"))
			for index in indices:
				var p:Vector3=model.local(polygon[index],.018)
				paving.set_normal(Vector3.UP)
				paving.set_uv(Vector2(p.x,p.z)*.93)
				paving.add_vertex(p)
			Mason.finish(model,paving,"CourtyardPaving")
			return
