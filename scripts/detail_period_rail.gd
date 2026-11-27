extends RefCounted

const Grid=preload("res://scripts/campaign_grid.gd")
const Landscape=preload("res://scripts/detail_landscape.gd")
const Finishes=preload("res://scripts/period_ship_visuals.gd")
const SLEEPER_DISTANCE:=2.85

static func tile_position(tile: Vector2i,origin: Vector2i) -> Vector2:
	return Vector2(tile-origin)*Vector2(225,195)

static func available_edges(state: Dictionary,center: Vector2i,reveal: bool) -> Array:
	var selected: Array=[]
	var known: Dictionary=state.explored[0]
	for key in state.get("railEdges",{}):
		var parts:=str(key).split(":")
		if parts.size()!=2:
			continue
		var first:=int(parts[0])
		var second:=int(parts[1])
		if first<0 or second<0 or first>=Grid.COLS*Grid.ROWS or second>=Grid.COLS*Grid.ROWS:
			continue
		var a:=Vector2i(first%Grid.COLS,first/Grid.COLS)
		var b:=Vector2i(second%Grid.COLS,second/Grid.COLS)
		if a==b or not (in_range(a,center) or in_range(b,center)):
			continue
		if not reveal and (not known.has("%d:%d" % [a.x,a.y]) or not known.has("%d:%d" % [b.x,b.y])):
			continue
		selected.append([tile_position(a,center),tile_position(b,center)])
	return selected

static func in_range(tile: Vector2i,center: Vector2i) -> bool:
	return absi(tile.x-center.x)<=1 and absi(tile.y-center.y)<=1

static func build(parent: Node3D,edges: Array,height_at: Callable,variant: int) -> void:
	if edges.is_empty():
		return
	var ballast:=begin_surface()
	var sleepers:=begin_surface()
	var rails:=begin_surface()
	var count:=0
	for edge in edges:
		var a: Vector2=edge[0]
		var b: Vector2=edge[1]
		var length:=a.distance_to(b)
		var along: Vector2=(b-a).normalized()
		var across:=Vector2(-along.y,along.x)
		var clip:=Landscape.clip(Vector3(a.x,0,a.y),Vector3(b.x,0,b.y),217.0)
		if clip.is_empty():
			continue
		var visible_a:=a.distance_to(Vector2(clip[0].x,clip[0].z))
		var visible_b:=a.distance_to(Vector2(clip[1].x,clip[1].z))
		var divisions:=ceili(length/SLEEPER_DISTANCE)
		var segment:=length/maxi(divisions,1)
		for index in range(maxi(0,floori(visible_a/segment)),mini(divisions,ceili(visible_b/segment))):
			var start:=a+along*(index*segment)
			var end:=start+along*segment
			if height_at.call(start.x,start.y)<-0.12 or height_at.call(end.x,end.y)<-0.12:
				continue
			var index_uv:=float(index)*1.14
			strip(ballast,start,end,across*1.58,0.05,index_uv,height_at)
			var sleeper:=start+along*(segment*0.5)
			strip(sleepers,sleeper-along*0.12,sleeper+along*0.12,across*1.41,0.09,index_uv,height_at)
			for side in [-1.0,1.0]:
				var offset:=across*float(side)*1.12
				strip(rails,start+offset,end+offset,across*0.048,0.128,index_uv,height_at)
			count+=1
	if count==0:
		return
	install(parent,ballast,Finishes.material(Color.WHITE,"period_railBallast",variant),"RailBallast")
	install(parent,sleepers,Finishes.material(Color("6c5441")),"RailSleepers")
	install(parent,rails,Finishes.material(Color("9a9b94"),"period_castIron",variant),"RidingRails")

static func begin_surface() -> SurfaceTool:
	var mesh:=SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	return mesh

static func strip(mesh: SurfaceTool, start: Vector2,end: Vector2,across: Vector2,buoy: float,uv_offset: float,height_at: Callable) -> void:
	var points: Array[Vector2]=[start-across,start+across,end-across,end+across]
	for corner in [0,1,3,0,3,2]:
		var p:=points[corner]
		mesh.set_uv(Vector2(float(corner%2),uv_offset+float(corner/2)))
		mesh.set_normal(Vector3.UP)
		var ground: float=height_at.call(p.x,p.y)
		mesh.add_vertex(Vector3(p.x,ground+buoy,p.y))

static func install(parent: Node3D,source: SurfaceTool,material: Material,label: String) -> void:
	var track:=MeshInstance3D.new()
	track.name=label
	track.mesh=source.commit()
	track.material_override=material
	track.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(track)
