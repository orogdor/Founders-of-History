extends RefCounted
## Pointed transport amphora with a flared mouth and twin handles, about 0.85 m tall.
static var jar: ArrayMesh

static func amphora() -> ArrayMesh:
	if jar!=null: return jar
	var shell:=SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2]=[Vector2(.035,0),Vector2(.073,.10),Vector2(.19,.31),Vector2(.21,.50),Vector2(.18,.58),Vector2(.075,.66),Vector2(.07,.77),Vector2(.095,.79),Vector2(.094,.82),Vector2(.057,.82),Vector2(.054,.78)]
	const SIDES:=12
	for i in profile.size()-1:
		for j in SIDES:
			var a:=Vector2.from_angle(TAU*j/SIDES)
			var b:=Vector2.from_angle(TAU*(j+1)/SIDES)
			var u:=profile[i]
			var w:=profile[i+1]
			quad(shell,Vector3(a.x*u.x,u.y,a.y*u.x),Vector3(b.x*u.x,u.y,b.y*u.x),Vector3(a.x*w.x,w.y,a.y*w.x),Vector3(b.x*w.x,w.y,b.y*w.x))
	for side:float in [-1.,1.]:
		var path: Array[Vector3]=[Vector3(side*.173,.54,0),Vector3(side*.226,.61,0),Vector3(side*.231,.71,0),Vector3(side*.19,.76,0),Vector3(side*.077,.77,0)]
		for i in range(1,path.size()):
			var previous:=path[i-1]
			var next:=path[i]
			var axis:=(next-previous).normalized()
			var radial:=axis.cross(Vector3.BACK)
			for j in 6:
				var a:=Vector2.from_angle(TAU*j/6)
				var b:=Vector2.from_angle(TAU*(j+1)/6)
				var r0:=(radial*a.x+Vector3.BACK*a.y)*.027
				var r1:=(radial*b.x+Vector3.BACK*b.y)*.027
				quad(shell,previous+r0,previous+r1,next+r0,next+r1)
	shell.index()
	shell.generate_normals()
	var finish:=StandardMaterial3D.new()
	finish.albedo_color=Color("b67853")
	finish.roughness=.94
	finish.cull_mode=BaseMaterial3D.CULL_DISABLED
	shell.set_material(finish)
	jar=shell.commit()
	return jar

static func quad(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	for point:Vector3 in [a,b,c,b,d,c]: surface.add_vertex(point)

static func place(parent: Node3D,at: Vector3,factor:=1.) -> void:
	var pot:=MeshInstance3D.new()
	pot.mesh=amphora()
	pot.position=at
	pot.scale=Vector3.ONE*factor
	parent.add_child(pot)

