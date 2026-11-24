extends Node3D

const Terrain=preload("res://scripts/detail_terrain.gd")
const GroundMaterial=preload("res://scripts/detail_ground_material.gd")
const Mobile=preload("res://scripts/mobile_profile.gd")
const Grid=preload("res://scripts/campaign_grid.gd")
const Detail=preload("res://scripts/detail_view.gd")
const Discoveries=preload("res://scripts/world_discoveries.gd")
const Campaign=preload("res://scripts/campaign_state.gd")
const Production=preload("res://scripts/production_bonuses.gd")
const DetailWorld=preload("res://scripts/detail_world.gd")
const VisualRiver=preload("res://scripts/visual_river.gd")
const Roads=preload("res://scripts/detail_roads.gd")
const MAP_FOG=preload("res://scripts/detail_map_fog.gdshader")
const TILE_SIZE:=Vector2(225.0,195.0)
const INACTIVE_TILE:=Vector2i(-1,-1)
var host_node: Node
var anchor:=Vector2i.ZERO
var tiles: Dictionary={}
var pending: Dictionary={}
var stages: Dictionary={}
var worker: Thread
var active_at:=INACTIVE_TILE
var active_revision:=0
var walking:=false
var walked_tile:=INACTIVE_TILE
var look_ahead:=INACTIVE_TILE
var vision_revision: int=-1
var focus:=Vector2.ZERO
var wanted: Dictionary={}
var detail_fog: MeshInstance3D
var map_center:=Vector2i.ZERO
var map_rect:=Rect2i()
var map_camera: Transform3D
var map_viewport:=Rect2()
var map_vision_revision: int=-1

func setup(host: Node,center: Vector2i) -> void:
	host_node=host
	anchor=center
	map_center=center
	detail_fog=MeshInstance3D.new();detail_fog.name="DetailMapFog"
	var plane:=PlaneMesh.new();plane.size=Vector2(3200,3200);detail_fog.mesh=plane
	detail_fog.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mist:=ShaderMaterial.new();mist.shader=MAP_FOG;mist.set_shader_parameter("map_offset",Vector2(anchor)*TILE_SIZE)
	detail_fog.material_override=mist;detail_fog.position.y=-20.0;host.detail_root.add_child(detail_fog)
	for at in neighborhood(center):
		if at==anchor:continue
		var heights:=Terrain.tile_heights(host.grid,at.x,at.y)
		var visual: PackedVector4Array=host.detail_visual_for(at.x,at.y)
		var tile:=add_surface(at,heights,visual,host.detail_mesh_for(at.x,at.y,heights,visual))
		add_landscape(at,tile)
		if add_known_nature(host,tile,at,heights,index_of(at)):tile.set_meta("nature_ready",true)
		elif not Mobile.active and has_nature(at):pending[at]=true

func index_of(at: Vector2i) -> int:
	return at.y*Grid.COLS+at.x

func accessible(at: Vector2i) -> bool:
	return at.x>=0 and at.x<Grid.COLS and at.y>=0 and at.y<Grid.ROWS and (
		host_node.reveal_all or host_node.game.explored[0].has(str(at.x)+":"+str(at.y)))

func neighborhood(center: Vector2i) -> Array[Vector2i]:
	var area: Array[Vector2i]=[]
	for row in range(-1,2):
		for column in range(-1,2):
			var at:=center+Vector2i(column,row)
			if accessible(at):area.append(at)
	return area

func coords_at(point: Vector2) -> Vector2i:
	var margin:=TILE_SIZE*0.5
	return anchor+Vector2i(floori((point.x+margin.x)/TILE_SIZE.x),floori((point.y+margin.y)/TILE_SIZE.y))

func in_initial_area(at: Vector2i) -> bool:
	var offset:=at-anchor
	return absi(offset.x)<=1 and absi(offset.y)<=1

func can_enter(at: Vector2i) -> bool:
	return at==anchor or tiles.has(at)

func update_stream(point: Vector2,direction: Vector2) -> void:
	if not walking:detail_fog.hide()
	walking=true
	var center:=coords_at(point)
	var ahead:=coords_at(point+direction*72.0)
	focus=point+direction*42.0
	var revision:=vision_stamp()
	if center==walked_tile and ahead==look_ahead and revision==vision_revision:return
	walked_tile=center;look_ahead=ahead;vision_revision=revision
	var area: Dictionary={}
	for at in neighborhood(center)+neighborhood(ahead):area[at]=true
	set_wanted(area,center)

func vision_stamp() -> int:
	return hash([host_node.game.get("visionRevision",0),host_node.reveal_all])

func update_map_view(camera: Camera3D,point: Vector2) -> void:
	var viewport:=camera.get_viewport().get_visible_rect()
	var revision:=vision_stamp()
	if camera.global_transform==map_camera and viewport==map_viewport and revision==map_vision_revision:return
	map_camera=camera.global_transform;map_viewport=viewport
	var center:=coords_at(point)
	var bounds:=Rect2i(center-Vector2i.ONE,Vector2i(3,3))
	var plane:=Plane(Vector3.UP,-20.0)
	for corner in [viewport.position,Vector2(viewport.end.x,viewport.position.y),Vector2(viewport.position.x,viewport.end.y),viewport.end]:
		var hit: Variant=plane.intersects_ray(camera.project_ray_origin(corner),camera.project_ray_normal(corner))
		if hit!=null:
			var at:=coords_at(Vector2(hit.x,hit.z))
			at=at.clamp(center-Vector2i(3,3),center+Vector2i(3,3))
			bounds=bounds.merge(Rect2i(at,Vector2i.ONE))
	detail_fog.position=Vector3(point.x,-20.0,point.y)
	focus=point
	if bounds==map_rect and center==map_center and revision==map_vision_revision:return
	map_rect=bounds;map_center=center;map_vision_revision=revision
	var area: Dictionary={}
	for row in range(bounds.position.y,bounds.end.y):
		for column in range(bounds.position.x,bounds.end.x):
			var at:=Vector2i(column,row)
			if accessible(at):
				var offset:=at-center
				area[at]=absi(offset.x)<=1 and absi(offset.y)<=1
	set_wanted(area,center)

func set_wanted(area: Dictionary,center: Vector2i) -> void:
	area.erase(anchor)
	wanted=area
	for at in wanted:
		if not tiles.has(at) or (bool(wanted[at]) and has_nature(at) and not tiles[at].has_meta("nature_ready") and not stages.has(at)):
			if at!=active_at:pending[at]=true
	for at in pending.keys():
		if not wanted.has(at):pending.erase(at)
	for at in tiles.keys():
		if wanted.has(at):continue
		var offset: Vector2i=at-center
		if accessible(at) and absi(offset.x)<=2 and absi(offset.y)<=2:continue
		tiles[at].queue_free();tiles.erase(at);stages.erase(at)

func stop_stream() -> void:
	walking=false
	walked_tile=INACTIVE_TILE
	map_vision_revision=-1
	detail_fog.show()
	wanted.clear()
	for at in pending.keys():
		if not in_initial_area(at):pending.erase(at)
	for at in tiles.keys():
		if in_initial_area(at):continue
		tiles[at].queue_free();tiles.erase(at);stages.erase(at)

func has_nature(at: Vector2i) -> bool:
	var cell: Dictionary=host_node.grid[index_of(at)]
	return cell.land or cell.get("deposits",{}).get("fish",false)

func add_surface(at: Vector2i,heights: Array,visual: PackedVector4Array,mesh: ArrayMesh) -> Node3D:
	var offset:=at-anchor
	var tile:=Node3D.new()
	tile.position=Vector3(offset.x*TILE_SIZE.x,0,offset.y*TILE_SIZE.y)
	tile.set_meta("coords",at);tile.set_meta("heights",heights);tile.set_meta("visual_heights",visual)
	add_child(tile);tiles[at]=tile
	var index:=index_of(at)
	var ground:=MeshInstance3D.new();ground.mesh=mesh
	var ground_color: Color=host_node.terrain_color(index)
	var ground_forest:=1.0 if host_node.is_forest_core(index) else 0.0
	GroundMaterial.attach(ground,ground_color,ground_forest,at)
	var adjacent={"ground_w":Vector2i(-1,0),"ground_e":Vector2i(1,0),"ground_n":Vector2i(0,-1),"ground_s":Vector2i(0,1),"ground_nw":Vector2i(-1,-1),"ground_ne":Vector2i(1,-1),"ground_sw":Vector2i(-1,1),"ground_se":Vector2i(1,1)}
	for key in adjacent:
		var neighbor: Vector2i=at+adjacent[key]
		var tint:=ground_color
		var forest:=ground_forest
		if neighbor.x>=0 and neighbor.x<Grid.COLS and neighbor.y>=0 and neighbor.y<Grid.ROWS:
			var other:=index_of(neighbor)
			if host_node.grid[other].land:
				tint=host_node.terrain_color(other);forest=1.0 if host_node.is_forest_core(other) else 0.0
		ground.set_instance_shader_parameter(key,Color(tint.r,tint.g,tint.b,forest))
	ground.set_instance_shader_parameter("blend_neighbours",true)
	tile.add_child(ground)
	var water:=MeshInstance3D.new()
	var plane:=PlaneMesh.new();plane.size=TILE_SIZE;water.mesh=plane
	water.material_override=host_node.detail_ocean_for(at.x,at.y,heights,visual)
	tile.add_child(water)
	return tile

func add_landscape(at: Vector2i,tile: Node3D) -> void:
	tile.set_meta("river_segments",host_node.detail_landscape_for(tile,at.x,at.y,tile.get_meta("heights"),tile.get_meta("visual_heights")))

func closest(items: Dictionary) -> Vector2i:
	var nearest:=INACTIVE_TILE
	var distance:=INF
	for at: Vector2i in items:
		var candidate:=focus.distance_squared_to(Vector2(at-anchor)*TILE_SIZE)
		if candidate<distance:nearest=at;distance=candidate
	return nearest

func revision_stamp() -> int:
	return hash([host_node.game.get("crossingRevision",0),host_node.game.get("terrainRevision",0)])

func _process(_delta: float) -> void:
	if host_node==null:return
	if worker!=null and not worker.is_alive():
		var result: Dictionary=worker.wait_to_finish();worker=null
		var at:=active_at;active_at=INACTIVE_TILE
		if wanted.has(at) or (not walking and in_initial_area(at) and tiles.has(at) and accessible(at)):
			if active_revision!=revision_stamp():
				pending[at]=true
			else:
				if not tiles.has(at):
					var visual: PackedVector4Array=host_node.detail_visual_for(at.x,at.y,result.visual)
					var mesh: ArrayMesh=host_node.detail_mesh_for(at.x,at.y,result.heights,visual,result.mesh)
					add_surface(at,result.heights,visual,mesh)
				stages[at]=result.world
				return
	if not stages.is_empty():
		var at:=closest(stages)
		var tile: Node3D=tiles[at]
		if not tile.has_meta("river_segments"):
			add_landscape(at,tile)
			return
		if add_known_nature(host_node,tile,at,tile.get_meta("heights"),index_of(at),stages[at]):
			tile.set_meta("nature_ready",true)
		elif bool(wanted.get(at,false)) and stages[at].is_empty() and has_nature(at):
			pending[at]=true
		if not in_initial_area(at) and not tile.has_node("TileRoads"):
			var roads:=Roads.new()
			roads.name="TileRoads"
			roads.host=host_node;roads.center=at
			roads.single_tile=true
			tile.add_child(roads)
		stages.erase(at)
		return
	if worker==null and not pending.is_empty():start_worker(closest(pending))

func start_worker(at: Vector2i) -> void:
	pending.erase(at)
	var make_surface:=not tiles.has(at)
	var cell: Dictionary={}
	if bool(wanted.get(at,true)) and has_nature(at):cell=host_node.city_cell_data({"c":at.x,"r":at.y}).duplicate(true)
	var cells: Array=host_node.grid.duplicate()
	var source: Dictionary=host_node.world_river_graph
	var incoming: Dictionary={}
	# The river sampler updates caches. Give it private caches and copies of the
	# nearby cells, including the upstream branches used for river mouths.
	var radius:=8 if make_surface else 3
	for row in range(maxi(0,at.y-radius),mini(Grid.ROWS,at.y+radius+1)):
		for column in range(maxi(0,at.x-radius),mini(Grid.COLS,at.x+radius+1)):
			var index:=row*Grid.COLS+column
			cells[index]=cells[index].duplicate()
			if make_surface and source.get("incoming",{}).has(index):
				var branches: Array=[]
				for upstream in source.incoming[index]:branches.append(upstream.duplicate())
				incoming[index]=branches
	var graph: Dictionary={}
	if make_surface and not source.is_empty():
		graph={"incoming":incoming,"anchors":source.anchors,"lakes":source.lakes}
	var atlas: PackedFloat32Array=host_node.world_height_samples
	var seed:=int(host_node.game.seed)
	var biome: String=host_node.visual_biome(index_of(at))
	var prepare:=func() -> Dictionary:
		var result: Dictionary={"world":{}}
		if make_surface:
			result.heights=Terrain.tile_heights(cells,at.x,at.y)
			result.visual=VisualRiver.color_heights(cells,atlas,at.x,at.y,seed,graph)
			result.mesh=Terrain.mesh_arrays(result.heights,Vector2.ZERO,result.visual)
		if not cell.is_empty():result.world=DetailWorld.create(cells,cell,biome,seed)
		return result
	active_at=at;active_revision=revision_stamp()
	worker=Thread.new()
	if worker.start(prepare)!=OK:
		worker=null;active_at=INACTIVE_TILE;pending[at]=true

func _exit_tree() -> void:
	if worker!=null:worker.wait_to_finish();worker=null

func add_known_nature(host: Node,tile: Node3D,at: Vector2i,heights: Array,index: int,temporary: Dictionary={}) -> bool:
	var city: Variant=null
	for candidate in host.game.get("cities",[]):
		var contexts:Array=[candidate];contexts.append_array(candidate.get("districts",{}).values())
		for context in contexts:
			if int(context.c)==at.x and int(context.r)==at.y and (int(context.team)==0 or Campaign.visible_now(host.game,0,context)):city=context;break
		if city!=null:break
	var key:=str(at.x)+":"+str(at.y)
	var village: Variant=null
	if city==null:
		for landmark in host.game.get("landmarks",[]):
			if landmark.kind=="village" and int(landmark.c)==at.x and int(landmark.r)==at.y:village=landmark;break
	var world: Dictionary=city.world if city!=null else host.game.get("tileWorlds",{}).get(key,temporary)
	if world.is_empty():return false
	DetailWorld.ensure_sea_fish(world,host.grid[index],int(host.game.seed))
	if city!=null or village!=null:world=world.duplicate(true)
	var nature=Detail.new();nature.name="Nature";nature.heights=heights;nature.visual_heights=tile.get_meta("visual_heights",PackedVector4Array());nature.resources=world.resources;nature.world_data=world
	nature.river_segments=tile.get_meta("river_segments",[])
	nature.tree_biome=host.visual_biome(index);nature.tree_temperature=float(host.heat[index]);nature.tree_moisture=float(host.moisture[index]);nature.tree_cell=at;nature.tree_river=bool(host.grid[index].get("river",false))
	nature.tree_seed=int(host.game.seed);nature.tree_mountain=bool(host.grid[index].get("mountain",false))
	tile.add_child(nature);nature.add_nature(nature.tree_biome)
	if host.grid[index].land:
		nature.add_ground_cover(nature.tree_biome,0.12,walking)
		if nature.ground_cover!=null:nature.ground_cover.set_roads(tile.get_meta("road_segments",[]))
	var buildings: Array=city.economy.buildings if city!=null else Discoveries.village_layout(village) if village!=null else []
	nature.sync_removed_resources(world.resources,float(host.game.time),buildings)
	if city!=null:
		nature.person=Node3D.new();nature.add_child(nature.person)
		var hall: Dictionary=city.economy.buildings[0];var upgrade:=Production.upgrade_level(host.game,int(city.team))
		if not hall.get("virtual",false):nature.place_hall(hall.x,hall.z,upgrade,float(hall.get("buildingRotationV228",0)),hall.get("houseDesignV354",{}))
		nature.sync_buildings(city,upgrade)
		nature.add_village_life(host,"city:"+str(city.id),int(city.team),true)
	elif village!=null:
		nature.person=Node3D.new();nature.add_child(nature.person)
		var hall: Dictionary=buildings[0];var age:=Discoveries.village_age(host.game,village)
		nature.place_hall(hall.x,hall.z,age,float(hall.buildingRotationV228),hall.get("houseDesignV354",{}));nature.sync_buildings({"economy":{"buildings":buildings}},age)
		nature.add_village_life(host,"landmark:"+str(village.id),int(village.get("claimedBy",-1)) if village.get("claimedBy")!=null else -1,true)
	return true
