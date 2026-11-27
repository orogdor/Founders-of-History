extends Node3D

const Grid=preload("res://scripts/campaign_grid.gd")
const Terrain=preload("res://scripts/detail_terrain.gd")
const Roads=preload("res://scripts/world_roads.gd")
const Landscape=preload("res://scripts/detail_landscape.gd")
const LocalNav=preload("res://scripts/local_navigation.gd")
const PeriodPath=preload("res://scripts/detail_period_path_materials.gd")
const PeriodRail=preload("res://scripts/detail_period_rail.gd")
const WIDTHS:=[0.0,0.78,0.9,1.05,1.575]
const COLORS:=["","716147","7e6b50","817767","8b8170","9a9182","858682","545a5a"]
const APPEARANCES:=[[1,1,1,1],[1,2,2,2],[2,3,3,3],[2,3,4,4],[2,3,4,5],[3,6,6,5],[3,6,7,7]]
const LINE_SPACING:=5.2
const LINE_LENGTH:=2.4
const ROMAN_TONES := [Color(1,1,1,0),Color(.82,.77,.70),Color.WHITE,Color.WHITE,Color.WHITE,Color(.82,.77,.70),Color(1,1,1,0)]
const BRONZE_WIDTHS := [-1.16,-0.80,-0.47,0.0,0.47,0.80,1.16]
const BRONZE_TONES := [Color(1,1,1,0),Color.WHITE,Color(0.80,0.76,0.71),Color.WHITE,Color(0.80,0.76,0.71),Color.WHITE,Color(1,1,1,0)]
var host: Node
var center:=Vector2i.ZERO
var stamp: String=""
var traffic_routes: Dictionary={}

func _process(_delta: float) -> void:
	if host==null:return
	var building_stamp: Array=[]
	for city in host.game.get("cities",[]):
		if absi(int(city.c)-center.x)>1 or absi(int(city.r)-center.y)>1:continue
		for building in city.economy.buildings:building_stamp.append([building.type,building.x,building.z,building.get("width",0),building.get("depth",0),float(building.get("hp",0))>0])
	var next: String="%s:%s:%s:%s:%s:%s" % [host.game.get("roadRevision",0),host.game.get("railRevision",0),host.game.get("visionRevision",0),host.reveal_all,host.game.ages,building_stamp]
	if next==stamp:return
	stamp=next;rebuild()

func rebuild() -> void:
	for child in get_children():child.queue_free()
	traffic_routes.clear()
	var surfaces: Dictionary={};var heights: Dictionary={};var road_segments: Dictionary={}
	var lane_lines:=SurfaceTool.new()
	lane_lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edging:=SurfaceTool.new()
	edging.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curb_count:=0
	var line_count:=0
	var edges:=Roads.visual_network(host.game,host.game.explored[0],host.reveal_all)
	for edge in edges:
		var level:=int(edge.level);var owner: Variant=host.territory_allocation.get("territory",{}).get(str(edge.a.x)+":"+str(edge.a.y))
		if owner==null:owner=host.territory_allocation.get("territory",{}).get(str(edge.b.x)+":"+str(edge.b.y))
		var team:=int(owner.team) if owner is Dictionary else 0
		var age:=clampi(int(host.game.ages[team]),0,6)
		var appearance: int=APPEARANCES[age][level-1]
		var group:=Vector4i(age,appearance,0 if age==0 else level,0 if age==0 else PeriodPath.variant_at(edge.a))
		var route_key:=Roads.road_key({"c":edge.a.x,"r":edge.a.y},{"c":edge.b.x,"r":edge.b.y})
		var traffic: Array=[]
		for dr in range(-1,2):
			for dc in range(-1,2):
				var at:=center+Vector2i(dc,dr)
				if at.x<0 or at.y<0 or at.x>=Grid.COLS or at.y>=Grid.ROWS:continue
				if not host.reveal_all and not host.game.explored[0].has(str(at.x)+":"+str(at.y)):continue
				if absi(at.x-edge.a.x)>2 and absi(at.x-edge.b.x)>2:continue
				if absi(at.y-edge.a.y)>2 and absi(at.y-edge.b.y)>2:continue
				var tile_center:=Grid.center(at.x,at.y);var key:=str(at.x)+":"+str(at.y)
				var obstacles:=tile_obstacles(at);var local_points:=local_road(edge.points,tile_center,obstacles,level)
				var total_distance:=0.0
				for i in range(local_points.size()-1):
					var a: Vector2=local_points[i];var b: Vector2=local_points[i+1]
					var distance_before:=total_distance
					total_distance+=a.distance_to(b)
					var part:=Landscape.clip(Vector3(a.x,0,a.y),Vector3(b.x,0,b.y))
					if part.is_empty():continue
					if not heights.has(key):heights[key]=Terrain.tile_heights(host.grid,at.x,at.y)
					if not surfaces.has(group):
						var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[group]=surface
					var left: Vector3=part[0];var right: Vector3=part[1]
					var direction:=Vector2(right.x-left.x,right.z-left.z).normalized()
					var normal: Vector2=Vector2(-direction.y,direction.x)*1.19*float(WIDTHS[level])*0.86
					if not clear_segment(Vector2(left.x,left.z),Vector2(right.x,right.z),obstacles,normal.length()):continue
					var tile_offset:=Vector2(dc*225,dr*195)
					if age>0:
						traffic.append([Vector2(left.x,left.z)+tile_offset,Vector2(right.x,right.z)+tile_offset])
					if age==6 and level==4:
						var first:=Vector2(left.x,left.z)
						var second:=Vector2(right.x,right.z)
						line_count+=mark_lane(lane_lines,first+tile_offset,second+tile_offset,distance_before+a.distance_to(first))
					if not road_segments.has(key):road_segments[key]=[]
					road_segments[key].append([Vector2(left.x,left.z),Vector2(right.x,right.z),normal.length()+2.0])
					if age==2 and level>=3:
						var start:=Vector2(left.x,left.z)
						curb_count+=roadside_stones(edging,start+tile_offset,Vector2(right.x,right.z)+tile_offset,normal,distance_before+a.distance_to(start))
					if age in [1,2]:
						ancient_road_segment(surfaces[group],Vector2(left.x,left.z),Vector2(right.x,right.z),normal,tile_offset,Vector2(at)*Vector2(225,195),age==2 and level>=2)
						continue
					var vertices: Array=[Vector2(left.x,left.z)-normal,Vector2(left.x,left.z)+normal,Vector2(right.x,right.z)+normal,Vector2(left.x,left.z)-normal,Vector2(right.x,right.z)+normal,Vector2(right.x,right.z)-normal]
					for v in vertices:
						var p: Vector2=v
						var uv:=p+Vector2(at)*Vector2(225.0,195.0)
						var mesh: SurfaceTool=surfaces[group]
						if age>0:
							mesh.set_uv(uv*0.48)
							mesh.set_normal(Vector3.UP)
						mesh.add_vertex(Vector3(p.x+dc*225,host.detail_rendered_height(p.x+dc*225,p.y+dr*195)+0.045,p.y+dr*195))
		if not traffic.is_empty():
			traffic_routes[route_key]=traffic
	for surface_id: Vector4i in surfaces:
		var node:=MeshInstance3D.new();node.mesh=surfaces[surface_id].commit()
		var material:=PeriodPath.finish(surface_id.x,surface_id.z,COLORS[surface_id.y],surface_id.w)
		node.material_override=material;add_child(node)
	if curb_count>0:
		var stones:=MeshInstance3D.new()
		stones.name="RomanRoadKerbs"
		edging.index()
		stones.mesh=edging.commit()
		var limestone:=StandardMaterial3D.new()
		limestone.vertex_color_use_as_albedo=true
		limestone.cull_mode=BaseMaterial3D.CULL_DISABLED
		limestone.roughness=.96
		stones.material_override=limestone
		add_child(stones)
	if line_count>0:
		var lanes:=MeshInstance3D.new()
		lanes.name="ModernRoadMarkings"
		lanes.mesh=lane_lines.commit()
		var finish:=StandardMaterial3D.new()
		finish.albedo_color=Color("c9c8ad")
		finish.cull_mode=BaseMaterial3D.CULL_DISABLED
		finish.roughness=1.0
		lanes.material_override=finish
		lanes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lanes)
	var rails:=PeriodRail.available_edges(host.game,center,host.reveal_all)
	PeriodRail.build(self,rails,host.detail_rendered_height,PeriodPath.variant_at(center))
	if host.get("detail_root")==null:return
	if host.detail_root.ground_cover!=null:host.detail_root.ground_cover.set_roads(road_segments.get(str(center.x)+":"+str(center.y),[]))
	var neighbors: Node=host.detail_root.get_node_or_null("NeighborTiles")
	if neighbors!=null:
		for tile in neighbors.get_children():
			var at: Vector2i=tile.get_meta("coords",Vector2i(-1,-1));var segments: Array=road_segments.get(str(at.x)+":"+str(at.y),[])
			tile.set_meta("road_segments",segments)
			var nature: Node=tile.get_node_or_null("Nature")
			if nature!=null and nature.ground_cover!=null:nature.ground_cover.set_roads(segments)

func traffic_pose(start: Dictionary,finish: Dictionary,at: Vector2) -> Dictionary:
	var key:=Roads.road_key(start,finish)
	var forward:=Vector2((float(finish.c)-float(start.c))*225.0,(float(finish.r)-float(start.r))*195.0)
	var nearest:=400.0
	var result: Dictionary={}
	for segment in traffic_routes.get(key,[]):
		var first: Vector2=segment[0]
		var second: Vector2=segment[1]
		var point:=Geometry2D.get_closest_point_to_segment(at,first,second)
		var distance:=point.distance_squared_to(at)
		if distance>=nearest:
			continue
		var tangent:=second-first
		if tangent.dot(forward)<0.0:
			tangent=-tangent
		nearest=distance
		result={"point":point,"heading":atan2(tangent.x,tangent.y)}
	return result

func mark_lane(surface: SurfaceTool,a: Vector2,b: Vector2,from: float) -> int:
	var distance:=a.distance_to(b)
	if distance<0.001:
		return 0
	var direction:=(b-a)/distance
	var side:=Vector2(-direction.y,direction.x)*0.043
	var end:=from+distance
	var count:=0
	for dash in range(floori(from/LINE_SPACING),ceili(end/LINE_SPACING)):
		var start_line:=float(dash)*LINE_SPACING
		var p:=a+direction*(maxf(from,start_line)-from)
		var q:=a+direction*(minf(end,start_line+LINE_LENGTH)-from)
		if (q-p).dot(direction)<0.003:
			continue
		for v in [p-side,p+side,q+side,p-side,q+side,q-side]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(v.x,host.detail_rendered_height(v.x,v.y)+0.062,v.y))
		count+=1
	return count

func roadside_stones(surface:SurfaceTool,a:Vector2,b:Vector2,normal:Vector2,route_distance:float) -> int:
	var length:=a.distance_to(b)
	if length<.12:return 0
	var along:=(b-a)/length
	var width:=.16
	var n:=normal.normalized()
	var stones:=0
	const STEP:=.93
	for side:float in [-1.,1.]:
		var stagger:=.28 if side<0. else 0.
		var start_index:=floori((route_distance+stagger)/STEP)
		var stop_index:=ceili((route_distance+length+stagger)/STEP)
		for index in range(start_index,stop_index):
			var start:=maxf(0.,index*STEP+.028-stagger-route_distance)
			var finish:=minf(length,(index+1)*STEP-.028-stagger-route_distance)
			if finish-start<.10:continue
			var back:=a+along*start+normal*(side*.90)
			var front:=a+along*finish+normal*(side*.90)
			var y_back:float=host.detail_rendered_height(back.x,back.y)+.10
			var y_front:float=host.detail_rendered_height(front.x,front.y)+.10
			var tint:=Color("a59e8e").darkened(.045*posmod(index,4))
			var cross:=n*(side*width*.5)
			var p:=Vector3(back.x-cross.x,y_back,back.y-cross.y)
			var q:=Vector3(back.x+cross.x,y_back,back.y+cross.y)
			var r:=Vector3(front.x+cross.x,y_front,front.y+cross.y)
			var s:=Vector3(front.x-cross.x,y_front,front.y-cross.y)
			for point in [p,q,r,p,r,s]:
				surface.set_normal(Vector3.UP)
				surface.set_color(tint)
				surface.add_vertex(point)
			for point in [q,q-Vector3.UP*.095,r,r,q-Vector3.UP*.095,r-Vector3.UP*.095]:
				surface.set_normal(Vector3(n.x*side,0,n.y*side))
				surface.set_color(tint.darkened(.15))
				surface.add_vertex(point)
			stones+=1
	return stones

func ancient_road_segment(surface: SurfaceTool, a: Vector2, b: Vector2, normal: Vector2, tile_offset: Vector2, world_offset: Vector2, paved: bool) -> void:
	var positions := PackedVector3Array()
	var uvs := PackedVector2Array()
	for point: Vector2 in [a,b]:
		var world := point + world_offset
		for fraction: float in BRONZE_WIDTHS:
			var phase := world.x*0.79 + world.y*0.43 + signf(fraction)*2.9
			var uneven := sin(phase)*0.067 + sin(phase*2.19)*0.025
			var local := point + normal*fraction*(1.0+absf(fraction)*uneven)
			var p := local + tile_offset
			var crown := .065*maxf(0.0,1.-absf(fraction)) if paved else 0.0
			positions.append(Vector3(p.x,host.detail_rendered_height(p.x,p.y)+0.045+crown,p.y))
			uvs.append((local+world_offset)*.41 if paved else (local+world_offset)*.48)
	var count := BRONZE_WIDTHS.size()
	for i in count-1:
		for index: int in [i,i+1,count+i+1,i,count+i+1,count+i]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(uvs[index])
			surface.set_color(ROMAN_TONES[index%count] if paved else BRONZE_TONES[index%count])
			surface.add_vertex(positions[index])

func tile_obstacles(at: Vector2i) -> Array:
	var result: Array=[]
	for city in host.game.get("cities",[]):
		if int(city.c)!=at.x or int(city.r)!=at.y:continue
		for building in city.economy.buildings:
			if building.get("virtual",false) or float(building.get("hp",0))<=0:continue
			if building.type in ["woodgate","gatehouse"]:
				var wide:=bool(building.get("extendedPalisadeV166",false));var side:=5.2 if wide else 2.55;var post:=1.6 if wide else 1.35
				var vertical:=bool(building.get("wallAxis",false))
				for sign_value in [-1,1]:result.append([float(building.x)+(0 if vertical else sign_value*side),float(building.z)+(sign_value*side if vertical else 0),0.95 if vertical else post,post if vertical else 0.95])
				continue
			var bounds: Variant=LocalNav.clearance(building)
			if bounds!=null:result.append([float(building.x),float(building.z),float(bounds.rx),float(bounds.rz)])
	return result

static func local_road(points: Array,tile_center: Vector2,obstacles: Array,level: int) -> Array:
	var result: Array=[]
	for i in range(1,points.size()):
		var a: Vector2=points[i-1];var b: Vector2=points[i]
		var steps:=maxi(1,ceili(a.distance_to(b)/0.58))
		for k in range(0 if i==1 else 1,steps+1):
			var p:=a.lerp(b,float(k)/steps)-tile_center
			result.append(Vector2(p.x*4.5,p.y*3.9))
	if obstacles.is_empty():return result
	var margin: float=2.0*1.19*float(WIDTHS[level])*0.8+1.2
	for round_index in 8:
		var moved:=false
		for i in range(1,result.size()-1):
			var p: Vector2=result[i]
			for obstacle in obstacles:
				var dx:=p.x-float(obstacle[0]);var dz:=p.y-float(obstacle[1]);var rx:=float(obstacle[2])+margin;var rz:=float(obstacle[3])+margin
				if absf(dx)>=rx or absf(dz)>=rz:continue
				if rx-absf(dx)<rz-absf(dz):p.x=float(obstacle[0])+(1 if dx>=0 else -1)*(rx+0.05)
				else:p.y=float(obstacle[1])+(1 if dz>=0 else -1)*(rz+0.05)
				moved=true
			result[i]=p
		if not moved and round_index>1:break
		for pass_index in 2:
			for i in range(1,result.size()-1):result[i]=result[i]*0.5+(result[i-1]+result[i+1])*0.25
	return result

static func clear_segment(a: Vector2,b: Vector2,obstacles: Array,margin: float) -> bool:
	if obstacles.is_empty():return true
	var steps:=maxi(1,ceili(a.distance_to(b)/0.75))
	for i in range(steps+1):
		var p:=a.lerp(b,float(i)/steps)
		for obstacle in obstacles:
			if absf(p.x-float(obstacle[0]))<float(obstacle[2])+margin and absf(p.y-float(obstacle[1]))<float(obstacle[3])+margin:return false
	return true
