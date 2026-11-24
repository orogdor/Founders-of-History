extends Node3D

const RoadSurface=preload("res://scripts/road_surface.gd")
const DIRECTIONS:=[Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]
var host: Node
var center:=Vector2i.ZERO
var clock:=0.0
var last_change: float=-1
var last_full:=0.0

func find_nav() -> Variant:
	if host.detail_root==null:return null
	if not host.detail_inspection and center==host.player:
		if host.city_created and not host.settler_mode:return host.city_nav
		return host.local_nav
	for city in host.game.get("cities",[]):
		if int(city.c)==center.x and int(city.r)==center.y:
			var runtime: Dictionary=host.city_runtimes.get(str(int(city.id)),{})
			return runtime.get("nav")
	return null

func _process(delta: float) -> void:
	clock+=delta;last_full+=delta
	if clock<2.0:return
	clock=0
	var nav: Variant=find_nav()
	if nav==null:return
	var changed:=float(nav.trail_world.get("trailChanges",0))
	if changed==last_change and last_full<10:return
	last_change=changed;last_full=0;rebuild(nav)

static func level(value: float) -> int:
	return 4 if value>=64 else 3 if value>=30 else 2 if value>=13 else 1 if value>=4 else 0

func rebuild(nav: RefCounted) -> void:
	for child in get_children():child.queue_free()
	var spots: Array=[]
	for key in nav.heat:
		var index:=int(key)
		if index<0 or index>=nav.mask.size():continue
		var strength: float=nav.road_strength(index);var rank:=level(strength)
		if rank==0 or nav.mask[index]==0:continue
		spots.append({"index":index,"strength":strength,"level":rank})
	spots.sort_custom(func(a,b):return float(a.strength)>float(b.strength))
	if spots.size()>4096:spots.resize(4096)
	var ranks: Dictionary={};var surfaces: Dictionary={};var counts: Dictionary={}
	var height_at := Callable(host.detail_root,"display_height")
	for spot in spots:ranks[int(spot.index)]=int(spot.level)
	for spot in spots:
		var index:=int(spot.index);var rank:=int(spot.level);var pos: Dictionary=nav.point(index)
		if not surfaces.has(rank):
			var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[rank]=surface
		var surface: SurfaceTool=surfaces[rank]
		var center_point:=Vector2(float(pos.x),float(pos.z));var radius: float=0.85*[0.0,0.82,1.06,1.26,1.5][rank]
		var y: float=host.detail_root.display_height(center_point.x,center_point.y);var flat:=true
		for d in [Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
			if absf(host.detail_root.display_height(center_point.x+d.x,center_point.y+d.y)-y)>0.045:flat=false;break
		if flat:
			counts[rank]=int(counts.get(rank,0))+30
			for i in 10:
				var a:=TAU*i/10.0;var b:=TAU*(i+1)/10.0
				var first := Vector2(cos(a),sin(a))
				var second := Vector2(cos(b),sin(b))
				RoadSurface.add_vertex(surface,center_point,y+0.018,Vector2.ZERO)
				RoadSurface.add_vertex(surface,center_point+first*radius,y+0.018,first)
				RoadSurface.add_vertex(surface,center_point+second*radius,y+0.018,second)
		for direction in DIRECTIONS:
			var other: int=nav.index(pos.x+direction.x,pos.z+direction.y)
			if not ranks.has(other):continue
			var end: Dictionary=nav.point(other)
			if not nav.clear_line(pos,end):continue
			var use_level:=mini(rank,int(ranks[other]));var target: SurfaceTool=surfaces.get(use_level)
			if target==null:
				target=SurfaceTool.new();target.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[use_level]=target
			var end_point:=Vector2(float(end.x),float(end.z));var line:=end_point-center_point
			var normal:=Vector2(-line.y,line.x).normalized()*1.19*float(RoadSurface.WIDTHS[use_level])*0.65
			counts[use_level]=int(counts.get(use_level,0))+6
			RoadSurface.add_strip(target,center_point,end_point,normal,normal,height_at,0.02,1)
	for rank in surfaces:
		if int(counts.get(rank,0))==0:continue
		add_child(RoadSurface.make_mesh(surfaces[rank],center,rank,RoadSurface.View.TRAIL))
