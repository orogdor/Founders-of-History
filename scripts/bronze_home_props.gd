extends RefCounted

const Finishes = preload("res://scripts/bronze_home_materials.gd")
static var jar_mesh: ArrayMesh
static var quern_mesh: ArrayMesh

static func place(parent: Node3D, kind: String, at: Vector3) -> void:
	var object := MeshInstance3D.new()
	if kind == "householdJar":
		if not jar_mesh:
			jar_mesh = make_jar()
		object.mesh = jar_mesh
		var scale_factor := 0.88 + fposmod(at.x * 3.7 + at.z * 2.1, 0.32)
		object.scale = Vector3.ONE * scale_factor
		object.rotation.y = fposmod(at.x * 2.4, TAU)
	else:
		if not quern_mesh:
			quern_mesh = make_quern()
		object.mesh = quern_mesh
		object.rotation.y = -0.25
	object.name = "Item_" + kind
	object.position = at
	parent.add_child(object)

static func shaded_surface(finish: String) -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := Finishes.get_finish(finish).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	surface.set_material(material)
	return surface

# The profile continues down the inside of the mouth so the jar is visibly hollow.
static func make_jar() -> ArrayMesh:
	var surface := shaded_surface("plaster")
	var profile := PackedVector2Array([
		Vector2(0.15,0.015), Vector2(0.19,0.055), Vector2(0.22,0.12),
		Vector2(0.32,0.30), Vector2(0.36,0.48), Vector2(0.35,0.58),
		Vector2(0.31,0.69), Vector2(0.21,0.79), Vector2(0.18,0.82),
		Vector2(0.18,0.86), Vector2(0.215,0.875), Vector2(0.22,0.904),
		Vector2(0.197,0.919), Vector2(0.156,0.904), Vector2(0.15,0.85),
		Vector2(0.18,0.78), Vector2(0.23,0.67), Vector2(0.15,0.30), Vector2(0.015,0.22)
	])
	var rings: Array[PackedVector3Array] = []
	var colors: Array[Color] = []
	for i in profile.size():
		var p := profile[i]
		var ring := PackedVector3Array()
		for s in 24:
			var a := TAU*s/24.0
			var radius := p.x*(1.0 + 0.014*sin(3.0*a + p.y*2.0) + 0.011*cos(5.0*a))
			ring.append(Vector3(cos(a)*radius,p.y+0.004*sin(2.0*a),sin(a)*radius))
		rings.append(ring)
		var color := Color("c69372") if i < 13 else Color("644333").lerp(Color("241914"),clampf((0.9-p.y)*2.0,0,1))
		if i in [9,10,12]: color = Color("eebf91")
		colors.append(color.lightened(0.04 * sin(i*1.6)) if i<13 else color)
	stitch(surface,rings,colors)
	for side: float in [-1.0,1.0]:
		rings.clear()
		colors.clear()
		for j in 13:
			var a := lerpf(-PI*0.5,PI*0.5,float(j)/12)
			var center := Vector3(side*(0.32+0.114*cos(a)-0.035*sin(a)),0.593+0.133*sin(a),0)
			var radial := Vector3(side*cos(a),sin(a),0)
			var ring := PackedVector3Array()
			for k in 8:
				var b := TAU*k/8.0
				ring.append(center + 0.027*(radial*cos(b) + Vector3.BACK*sin(b)))
			rings.append(ring)
			colors.append(Color("bd8969"))
		stitch(surface,rings,colors)
	surface.generate_normals()
	surface.index()
	return surface.commit()

# A saddle quern has an elongated, worn hollow and a separate transverse handstone.
static func make_quern() -> ArrayMesh:
	var surface := shaded_surface("rubble")
	var rings: Array[PackedVector3Array] = []
	var colors: Array[Color] = []
	var profile := [Vector2(0.76,0.02),Vector2(1.0,0.1),Vector2(0.95,0.26),Vector2(0.72,0.285),Vector2(0.45,0.21),Vector2(0.015,0.175)]
	for j in profile.size():
		var ring := PackedVector3Array()
		for s in 18:
			var a := TAU*s/18.0
			var r: float = profile[j].x*(1.0+0.032*sin(5*a)+0.025*cos(3*a))
			ring.append(Vector3(0.55*r*cos(a),profile[j].y+0.07*r*abs(cos(a)),0.36*r*sin(a)))
		rings.append(ring)
		colors.append(Color("cfc7af") if j<3 else Color("e5d7bd"))
	stitch(surface,rings,colors)
	rings.clear()
	colors.clear()
	for j in 9:
		var a := -PI*0.5+j*PI/8.0
		var ring := PackedVector3Array()
		for s in 12:
			var b := TAU*s/12.0
			ring.append(Vector3(0.12+0.135*cos(a)*cos(b),0.33+0.083*cos(a)*sin(b),0.30*sin(a)))
		rings.append(ring)
		colors.append(Color("b9ab92"))
	stitch(surface,rings,colors)
	surface.generate_normals()
	surface.index()
	return surface.commit()

static func stitch(surface: SurfaceTool, rings: Array[PackedVector3Array], colors: Array[Color]) -> void:
	for row in rings.size()-1:
		for col in rings[row].size():
			var next := (col+1)%rings[row].size()
			for corner in [Vector2i(row,col),Vector2i(row,next),Vector2i(row+1,next),Vector2i(row,col),Vector2i(row+1,next),Vector2i(row+1,col)]:
				surface.set_color(colors[corner.x])
				surface.add_vertex(rings[corner.x][corner.y])

