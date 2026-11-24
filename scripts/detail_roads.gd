extends Node3D

const Grid=preload("res://scripts/campaign_grid.gd")
const Roads=preload("res://scripts/world_roads.gd")
const Landscape=preload("res://scripts/detail_landscape.gd")
const LocalNav=preload("res://scripts/local_navigation.gd")
const RoadSurface=preload("res://scripts/road_surface.gd")
var host: Node
var center:=Vector2i.ZERO
var stamp: String=""
var single_tile:=false
var refresh_time:=0.0

func _process(delta: float) -> void:
	if host==null:return
	if single_tile:
		refresh_time+=delta
		if not stamp.is_empty() and refresh_time<1.0:return
		refresh_time=0.0
	var building_stamp: Array=[]
	for city in host.game.get("cities",[]):
		if absi(int(city.c)-center.x)>1 or absi(int(city.r)-center.y)>1:continue
		for building in city.economy.buildings:building_stamp.append([building.type,building.x,building.z,building.get("width",0),building.get("depth",0),float(building.get("hp",0))>0])
	var next: String="%s:%s:%s:%s:%s" % [host.game.get("roadRevision",0),host.game.get("visionRevision",0),host.reveal_all,host.game.ages,building_stamp]
	if next==stamp:return
	stamp=next;rebuild()

func rebuild() -> void:
	for child in get_children():child.queue_free()
	var surfaces: Dictionary={};var road_segments: Dictionary={}
	var height_at := Callable(host,"detail_rendered_height")
	var extent:=0 if single_tile else 1
	if single_tile:
		var tile:=get_parent() as Node3D
		height_at=func(x: float,z: float) -> float:
			return host.detail_rendered_height(x+tile.position.x,z+tile.position.z)
	var edges:=Roads.visual_network(host.game,host.game.explored[0],host.reveal_all)
	for edge in edges:
		var level:=int(edge.level);var owner: Variant=host.territory_allocation.get("territory",{}).get(str(edge.a.x)+":"+str(edge.a.y))
		if owner==null:owner=host.territory_allocation.get("territory",{}).get(str(edge.b.x)+":"+str(edge.b.y))
		var team:=int(owner.team) if owner is Dictionary else 0
		var appearance := RoadSurface.appearance_for(int(host.game.ages[team]),level)
		for dr in range(-extent,extent+1):
			for dc in range(-extent,extent+1):
				var at:=center+Vector2i(dc,dr)
				if at.x<0 or at.y<0 or at.x>=Grid.COLS or at.y>=Grid.ROWS:continue
				if not host.reveal_all and not host.game.explored[0].has(str(at.x)+":"+str(at.y)):continue
				if absi(at.x-edge.a.x)>2 and absi(at.x-edge.b.x)>2:continue
				if absi(at.y-edge.a.y)>2 and absi(at.y-edge.b.y)>2:continue
				var tile_center:=Grid.center(at.x,at.y);var key:=str(at.x)+":"+str(at.y)
				var obstacles:=tile_obstacles(at);var local_points:=local_road(edge.points,tile_center,obstacles,level)
				for i in range(local_points.size()-1):
					var a: Vector2=local_points[i];var b: Vector2=local_points[i+1]
					var part:=Landscape.clip(Vector3(a.x,0,a.y),Vector3(b.x,0,b.y))
					if part.is_empty():continue
					var left: Vector3=part[0];var right: Vector3=part[1]
					var start := Vector2(left.x,left.z)
					var end := Vector2(right.x,right.z)
					if start.is_equal_approx(end):continue
					var half_width := 1.19 * float(RoadSurface.WIDTHS[level]) * 0.86
					var start_side := RoadSurface.road_side(local_points,i,half_width)
					var end_side := RoadSurface.road_side(local_points,i+1,half_width)
					var segment_length := a.distance_to(b)
					var side_at_start := start_side.lerp(end_side,a.distance_to(start)/segment_length)
					var side_at_end := start_side.lerp(end_side,a.distance_to(end)/segment_length)
					var clearance := maxf(side_at_start.length(),side_at_end.length())
					if not clear_segment(start,end,obstacles,clearance):continue
					if not road_segments.has(key):road_segments[key]=[]
					road_segments[key].append([start,end,clearance+2.0])
					if not surfaces.has(appearance):
						var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[appearance]=surface
					var offset := Vector2(dc*225,dr*195)
					var steps := maxi(1,ceili(start.distance_to(end)/1.15))
					RoadSurface.add_strip(surfaces[appearance],start+offset,end+offset,
						side_at_start,side_at_end,height_at,0.045,steps)
	for appearance in surfaces:
		add_child(RoadSurface.make_mesh(surfaces[appearance],center,appearance))
	if single_tile:
		apply_road_segments(get_parent(),road_segments.get(str(center.x)+":"+str(center.y),[]))
		return
	if host.get("detail_root")==null:return
	if host.detail_root.ground_cover!=null:host.detail_root.ground_cover.set_roads(road_segments.get(str(center.x)+":"+str(center.y),[]))
	var neighbors: Node=host.detail_root.get_node_or_null("NeighborTiles")
	if neighbors!=null:
		for tile in neighbors.get_children():
			if not neighbors.in_initial_area(tile.get_meta("coords")):continue
			var at: Vector2i=tile.get_meta("coords",Vector2i(-1,-1));var segments: Array=road_segments.get(str(at.x)+":"+str(at.y),[])
			apply_road_segments(tile,segments)

func apply_road_segments(tile: Node,segments: Array) -> void:
	tile.set_meta("road_segments",segments)
	var nature: Node=tile.get_node_or_null("Nature")
	if nature!=null and nature.ground_cover!=null:nature.ground_cover.set_roads(segments)

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
	var margin: float=2.0*1.19*float(RoadSurface.WIDTHS[level])*0.8+1.2
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
