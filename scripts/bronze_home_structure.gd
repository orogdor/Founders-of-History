extends RefCounted
## Earthen construction for the editable Bronze Age family dwelling.
const Plan = preload("res://scripts/house_plan_geometry.gd")
const Fence = preload("res://scripts/house_fence.gd")
const Facade = preload("res://scripts/house_facade_details.gd")
const Finishes = preload("res://scripts/bronze_home_materials.gd")

static func enabled(design: Dictionary) -> bool:
	return design.get("periodOrnament", "") == "aegeanHousehold"

static func room_height(room: Dictionary, height: float) -> float:
	return height * clampf(float(room.get("heightFactor", 1.0)), 0.55, 1.0)

static func wall_height(span: Dictionary, rooms: Array, height: float) -> float:
	var middle: Vector2 = (span.a + span.b) / 2.0
	for room in rooms:
		if not room.has("heightFactor"):
			continue
		for side in Plan.edges(Plan.room_polygon(room)):
			if Plan.closest(middle, side.a, side.b).distance_squared_to(middle) < 0.01:
				return room_height(room, height)
	return height

static func surface(material: Material) -> SurfaceTool:
	var result := SurfaceTool.new()
	result.begin(Mesh.PRIMITIVE_TRIANGLES)
	result.set_material(material)
	return result

static func finish(model: Node3D, builder: SurfaceTool, label: String) -> void:
	builder.index()
	var mesh := builder.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	model.add_child(node,true)

# Clockwise front faces follow Godot's winding convention.
static func triangle(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (c-a).cross(b-a).normalized()
	if normal.is_zero_approx():
		return
	if normal.dot(outward) < 0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	for p in [a, b, c]:
		builder.set_normal(normal)
		if builder.has_meta("grain_axis"):
			var grain: Vector3 = builder.get_meta("grain_axis")
			builder.set_uv(Vector2(p.dot(grain)*0.47,(p-grain*p.dot(grain)).dot(Vector3.ONE)*1.7))
		else:
			builder.set_uv(Vector2(p.x + p.z, p.y))
		builder.add_vertex(p)

static func quad(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	triangle(builder, a, b, c, outward)
	triangle(builder, a, c, d, outward)

# Eight unequal corners, a bevel, and a slight keystone angle keep each course
# legible at a distance without modelling individual chips in the mesh.
static func stone(builder: SurfaceTool, at: Vector3, axis: Vector3, depth_axis: Vector3, width: float, height: float, depth: float, rng: RandomNumberGenerator) -> void:
	var outline := [Vector2(-0.50,-0.22), Vector2(-0.33,-0.5), Vector2(0.32,-0.5), Vector2(0.50,-0.26),
		Vector2(0.50,0.25), Vector2(0.31,0.5), Vector2(-0.32,0.5), Vector2(-0.5,0.21)]
	var rings: Array = []
	var skew := rng.randf_range(-0.24,0.24)
	var slope := rng.randf_range(-0.25,0.25)
	var tone := rng.randf_range(0.70,1.0)
	builder.set_color(Color(tone,tone*rng.randf_range(0.94,1.0),tone*rng.randf_range(0.89,0.99)))
	for i in outline.size():
		var p: Vector2 = outline[i]
		outline[i] = Vector2(p.x + skew*p.y + rng.randf_range(-0.04,0.04),p.y + slope*p.x + rng.randf_range(-0.11,0.11))
	for layer in [-1,0,1]:
		var ring := PackedVector3Array()
		for p: Vector2 in outline:
			var scale_ := 1.0 if layer == 0 else rng.randf_range(0.84,0.96)
			ring.append(at + ((axis*p.x*width) + Vector3.UP*p.y*height)*scale_ + depth_axis*layer*depth*0.5)
		rings.append(ring)
	for side in [0,2]:
		var direction: Vector3 = depth_axis * (side - 1)
		var center := at + direction*depth*0.52
		for i in outline.size():
			triangle(builder,center,rings[side][i],rings[side][(i+1)%8],direction)
	for row in 2:
		for i in outline.size():
			var j := (i+1)%8
			var a: Vector3 = rings[row][i]
			var b: Vector3 = rings[row][j]
			var c: Vector3 = rings[row+1][j]
			var d: Vector3 = rings[row+1][i]
			quad(builder,a,b,c,d,(a+b+c+d)*0.25-at)

static func course(builder: SurfaceTool, mortar: SurfaceTool, a: Vector3, b: Vector3, height: float, depth: float, seed_: int) -> void:
	var length := a.distance_to(b)
	if length < 0.08:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var axis := (b-a)/length
	var depth_axis := Vector3(-axis.z,0,axis.x)
	var rows := 3 if height >= 0.48 else 2
	# Earth mortar beds the inner part of each rubble course; only the uneven
	# exposed stone faces stand clear of it.
	bar(mortar,(a+b)*0.5+Vector3.UP*height*0.43,axis,depth_axis,length,height*0.86,depth*0.76)
	for row in rows:
		var level := (row+0.5)*height/rows
		var offset := 0.0
		while offset < length-0.005:
			var width := rng.randf_range(0.26,0.73)
			if offset == 0 and row%2:
				width *= 0.53
			if length-offset-width < 0.21:
				width = length-offset
			var run := offset+width*0.5
			var undulation := sin(run*2.3+row*0.83+float(seed_%97))*0.023
			var center := a + axis*run + Vector3.UP*(level+undulation)
			stone(builder,center,axis,depth_axis,width*1.055,height/rows*rng.randf_range(1.06,1.24),depth*rng.randf_range(0.90,1.07),rng)
			offset += width

# Build paint into the wall mesh. Coordinates stay in metres for adjacent
# editable spans, so a moved opening always interrupts the same wear pattern.
static func plaster_mesh(box: BoxMesh, pose: Transform3D, domestic_floor: bool) -> ArrayMesh:
	if domestic_floor:
		box.subdivide_width = mini(64,ceili(box.size.x/0.17))
		box.subdivide_height = mini(32,ceili(box.size.y/0.10))
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.append_from(box,0,pose)
	var arrays := builder.commit_to_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	for i in vertices.size():
		var p := vertices[i]
		# A few islands of worn, earth-rich undercoat extend above the stones.
		# The lighter dust has a softer upper limit; high walls stay clean.
		var along := p.x+p.z
		var patch := 0.5+0.5*sin(along*3.77+0.64*sin(along*5.94))
		var chipped := 0.39+0.18*patch*patch+0.075*sin(along*7.3+1.8)
		var dust := 0.62+0.12*sin(along*1.79)+0.09*cos(along*5.14)
		var weather := Color.WHITE.lerp(Color("c5ad8b"),1.0-smoothstep(dust-0.16,dust+0.19,p.y))
		weather = weather.lerp(Color("ab8c69"),1.0-smoothstep(chipped-0.024,chipped+0.03,p.y))
		colors[i] = weather if domestic_floor else Color.WHITE
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

# The angled cheeks and sill sit inside the punched opening. They leave an
# uninterrupted view through the smaller inner rectangle.
static func window_reveal(builder: SurfaceTool, a: Vector3, b: Vector3, outward: Vector3) -> void:
	var axis := (b-a).normalized()
	var window := Plan.window_span(1,"hole")
	var bounds := [a+Vector3.UP*window.x,b+Vector3.UP*window.x,b+Vector3.UP*window.y,a+Vector3.UP*window.y]
	var front := PackedVector3Array()
	var recess := PackedVector3Array()
	var inner := PackedVector3Array()
	for i in 4:
		var inset := axis*(0.030 if i in [0,3] else -0.030) + Vector3.UP*(0.038 if i<2 else -0.024)
		front.append(bounds[i]+outward*0.1402)
		recess.append(bounds[i]+inset+outward*0.028)
		inner.append(bounds[i]+inset-outward*0.134)
	var normals := [Vector3.UP,-axis,Vector3.DOWN,axis]
	for i in 4:
		var j := (i+1)%4
		quad(builder,front[i],front[j],recess[j],recess[i],normals[i]+outward)
		quad(builder,recess[i],recess[j],inner[j],inner[i],normals[i])

static func exterior_details(model: Node3D, design: Dictionary, geometry: Dictionary, height: float) -> void:
	var rock_mat: StandardMaterial3D = Finishes.get_finish("rubble",model.texture_variant).duplicate()
	rock_mat.vertex_color_use_as_albedo = true
	rock_mat.vertex_color_is_srgb = true
	rock_mat.albedo_color = Color("d2c8b7")
	var rocks := surface(rock_mat)
	var mortar_mat: StandardMaterial3D = Finishes.get_finish("rubble",model.texture_variant).duplicate()
	mortar_mat.albedo_color = Color("918474")
	var mortar := surface(mortar_mat)
	var timber_mat: StandardMaterial3D = Finishes.get_finish("wood",model.texture_variant).duplicate()
	timber_mat.uv1_triplanar = false
	timber_mat.uv1_scale = Vector3.ONE
	timber_mat.albedo_color = Color("baaa91")
	var joinery := surface(timber_mat)
	var reveal_mat: StandardMaterial3D = Finishes.get_finish("plaster",model.texture_variant).duplicate()
	reveal_mat.albedo_color = Color("a0876c")
	var reveals := surface(reveal_mat)
	var step_rng := RandomNumberGenerator.new()
	step_rng.seed = 1923
	# Paint boundaries must never split a continuous lintel or a stone course.
	var trim_plan := design.duplicate()
	trim_plan.wallFinishes = []
	for edge in geometry.walls:
		if design.get("build","wall")=="open" and edge.group=="outer":
			continue
		var exterior := Facade.exterior(edge,geometry.floors)
		var outward := Vector3(exterior.x,0,exterior.y)
		for span in Plan.split_wall(edge,trim_plan):
			var a: Vector3 = model.local(span.a)
			var b: Vector3 = model.local(span.b)
			var axis := (b-a).normalized()
			if span.get("opening",{}).get("style","")=="hole" and span.finish=="aegeanPlaster":
				window_reveal(reveals,a,b,outward)
			if span.get("type","") != "door":
				if edge.group=="outer" and not design.get("upperLevel",false) and design.get("base","plinth")!="none":
					course(rocks,mortar,a+outward*0.118,b+outward*0.118,0.44,0.18,hash(span.a))
			elif span.opening.get("style","") == "timberLintel":
				var mid := (a+b)*0.5
				var door_width := a.distance_to(b)
				var head := minf(1.78,wall_height(span,design.rooms,height)-0.13)
				# The head and reveals are attached to the opening, including moved doors.
				joinery.set_meta("grain_axis",axis)
				bar(joinery,mid+Vector3.UP*(head+0.095)+outward*0.10,axis,outward,door_width+0.34,0.195,0.39)
				joinery.set_meta("grain_axis",Vector3.UP)
				for pos in [a-axis*0.062,b+axis*0.062]:
					bar(joinery,pos+Vector3.UP*head*0.5+outward*0.055,axis,outward,0.15,head,0.34)
				if edge.group=="outer" and not design.get("upperLevel",false):
					stone(rocks,mid+outward*0.12+Vector3.UP*0.046,axis,outward,door_width+0.15,0.095,0.52,step_rng)
					for i in 3:
						var dist := 0.66+i*0.44
						stone(rocks,mid+outward*dist+axis*step_rng.randf_range(-0.075,0.075)+Vector3.UP*0.018,axis,outward,door_width*(0.93-0.09*i),0.052,0.40,step_rng)
	for fence in Fence.layout(design):
		if fence.get("kind","") == "stoneLine":
			var a: Vector3 = model.local(Plan.point(fence.a))
			var b: Vector3 = model.local(Plan.point(fence.b))
			course(rocks,mortar,a,b,0.55,0.47,hash(fence.a))
	finish(model,mortar,"DwellingMortar")
	finish(model,rocks,"DwellingRubble")
	finish(model,joinery,"DwellingDoorTimbers")
	finish(model,reveals,"DwellingWindowReveals")

static func bar(builder: SurfaceTool, at: Vector3, axis: Vector3, forward: Vector3, width: float, height: float, depth: float) -> void:
	var x := axis*width*0.5
	var y := Vector3.UP*height*0.5
	var z := forward*depth*0.5
	for sign_: float in [-1.0,1.0]:
		var face := at+x*sign_
		quad(builder,face-y-z,face+y-z,face+y+z,face-y+z,x*sign_)
		face = at+y*sign_
		quad(builder,face-x-z,face+x-z,face+x+z,face-x+z,y*sign_)
		face = at+z*sign_
		quad(builder,face-x-y,face+x-y,face+x+y,face-x+y,z*sign_)

# Add the short vertical face above an adjoining lower roof. It is a wall
# even when the roof cover is hidden in the editor.
static func fill_height_changes(model: Node3D, design: Dictionary, height: float) -> void:
	for room in design.rooms:
		if not room.has("heightFactor"):
			continue
		for neighbor in design.rooms:
			var lower := room_height(room,height)
			var higher := room_height(neighbor,height)
			if higher <= lower+0.01:
				continue
			for left in Plan.edges(Plan.room_polygon(room)):
				var axis: Vector2 = (left.b-left.a).normalized()
				for right in Plan.edges(Plan.room_polygon(neighbor)):
					if absf(axis.cross(right.a-left.a))>0.1 or absf(axis.cross(right.b-left.a))>0.1:
						continue
					var u: float = (right.a-left.a).dot(axis)
					var v: float = (right.b-left.a).dot(axis)
					var lo := maxf(0.0,minf(u,v))
					var hi := minf(left.a.distance_to(left.b),maxf(u,v))
					if hi-lo>1.0:
						model.add_wall({"a":left.a+axis*lo,"b":left.a+axis*hi,"group":"outer","finish":design.wallStyle},lower,higher)

static func roof(model: Node3D, room: Dictionary, design: Dictionary, height: float) -> void:
	var floor := Plan.room_polygon(room)
	if floor.size() < 3:
		return
	var outlines := Geometry2D.offset_polygon(floor,20.0,Geometry2D.JOIN_ROUND)
	if outlines.is_empty():
		return
	var polygon: PackedVector2Array = outlines[0]
	var shell := surface(model.material_for(str(design.get("roofMat","earth"))))
	var beams := surface(Finishes.get_finish("wood",model.texture_variant))
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for p in polygon:
		low = low.min(p)
		high = high.max(p)
	var pitch := clampf(float(design.get("roofHeight",75))/75.0,0.0,3.0)
	var rise := minf(0.27,(high.y-low.y)/Plan.PX_PER_M*0.05)*pitch
	var eave := room_height(room,height)
	var base_at := func(point: Vector2) -> float:
		return eave + rise*clampf((high.y-point.y)/maxf(high.y-low.y,1.0),0.0,1.0)
	# A short plaster wedge closes the building under the mild drainage pitch.
	var wedge := surface(model.material_for(str(design.get("wallStyle","aegeanPlaster"))))
	var wall_outlines := Geometry2D.offset_polygon(floor,Plan.PX_PER_M*0.14,Geometry2D.JOIN_MITER)
	var wall_outline: PackedVector2Array = wall_outlines[0] if not wall_outlines.is_empty() else floor
	for side in Plan.edges(wall_outline):
		var out := Facade.exterior(side,[wall_outline])
		var a: Vector3 = model.local(side.a,eave-0.016)
		var b: Vector3 = model.local(side.b,eave-0.016)
		quad(wedge,a,b,model.local(side.b,base_at.call(side.b)),model.local(side.a,base_at.call(side.a)),Vector3(out.x,0,out.y))
	finish(model,wedge,"RoofPlasterInfill")
	var inner := PackedVector3Array()
	var shoulder := PackedVector3Array()
	var lower := PackedVector3Array()
	var bottom := PackedVector3Array()
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var delta := b-a
		if delta.length_squared()<0.0001:
			continue
		var out2 := Vector2(delta.y,-delta.x).normalized()
		if Plan.inside((a+b)*0.5+out2*0.5,polygon):out2 = -out2
		var out := Vector3(out2.x,0,out2.y)
		var steps := maxi(1,ceili(delta.length()/26.0))
		for j in steps:
			var sample_point := a.lerp(b,float(j)/steps)
			var wave := 0.017*sin(sample_point.x*0.045+sample_point.y*0.029)+0.010*cos(sample_point.y*0.068-sample_point.x*0.061)
			var p: Vector3 = model.local(sample_point,base_at.call(sample_point))
			bottom.append(p + out*(wave-0.03) - Vector3.UP*(0.008-wave*0.25))
			lower.append(p+out*(wave+0.008)+Vector3.UP*(0.038+wave*0.45))
			shoulder.append(p+out*(wave+0.024)+Vector3.UP*(0.158+wave))
			inner.append(p-out*0.069+Vector3.UP*0.21)
		if room.type == "rect" and absf(out.z)>0.9 and delta.length()>35.0:
			var count := maxi(1,roundi(delta.length()/Plan.PX_PER_M/0.92))
			for j in count:
				var beam_pos := a.lerp(b,(j+0.5)/count)
				var center: Vector3 = model.local(beam_pos,base_at.call(beam_pos)+0.015)
				log_end(beams,center-out*0.13,out,0.083+0.013*sin(j),0.27+0.033*cos(j))
	var footprint := PackedVector2Array()
	for p in inner:footprint.append(Vector2(p.x,p.z))
	var triangles := Geometry2D.triangulate_polygon(footprint)
	for i in range(0,triangles.size(),3):
		var ia := triangles[i]
		var ib := triangles[i+1]
		var ic := triangles[i+2]
		triangle(shell,inner[ia],inner[ib],inner[ic],Vector3.UP)
		triangle(shell,bottom[ia],bottom[ib],bottom[ic],Vector3.DOWN)
	for i in inner.size():
		var j := (i+1)%inner.size()
		var edge := inner[j]-inner[i]
		var direction := Vector3(edge.z,0,-edge.x).normalized()
		if Geometry2D.is_polygon_clockwise(footprint):direction = -direction
		quad(shell,inner[i],inner[j],shoulder[j],shoulder[i],direction+Vector3.UP)
		quad(shell,shoulder[i],shoulder[j],lower[j],lower[i],direction)
		quad(shell,lower[i],lower[j],bottom[j],bottom[i],direction+Vector3.DOWN)
	finish(model,shell,"RoofDeck")
	finish(model,beams,"RoofRafterEnds")

static func log_end(builder: SurfaceTool, center: Vector3, axis: Vector3, radius: float, depth: float) -> void:
	var side := Vector3(axis.z,0,-axis.x)
	var far := center+axis*depth
	for i in 8:
		var t := TAU*i/8.0
		var u := TAU*(i+1)/8.0
		var left := side*cos(t)*radius + Vector3.UP*sin(t)*radius
		var right := side*cos(u)*radius + Vector3.UP*sin(u)*radius
		quad(builder,center+left,center+right,far+right,far+left,left+right)
		triangle(builder,far,far+left,far+right,axis)
