extends SceneTree

const Grid=preload("res://scripts/campaign_grid.gd")
const Terrain=preload("res://scripts/detail_terrain.gd")
const Mobile=preload("res://scripts/mobile_profile.gd")
const DISTANCE:=6

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Mobile.active=OS.get_environment("FPV_TEST_DESKTOP").is_empty()
	root.size=Vector2i(1280,720)
	var game: Node=load("res://campaign.tscn").instantiate()
	root.add_child(game)
	game.paused=true
	await process_frame
	game.game_hud.game_menu.close_menu()
	game.reveal_all=false
	var start:=find_route(game)
	assert(start.x>=0,"No dry route across the map borders")
	var explored: Dictionary={}
	for column in DISTANCE+1:explored["%d:%d" % [start.x+column,start.y]]=true
	game.game.explored[0]=explored
	game.selected=start
	game.open_selected_tile()
	var detail: Node3D=game.detail_root
	var neighbors: Node=detail.get_node("NeighborTiles")
	var first:=start+Vector2i.RIGHT
	var destination:=start+Vector2i(DISTANCE,0)
	for frame in 240:
		await process_frame
		if neighbors.can_enter(first):break
	assert(neighbors.can_enter(first))
	var nearby: WeakRef=weakref(neighbors.tiles[first])
	var walker: Node=game.fpv_walker
	assert(walker.place_at(108.0,0.0))
	walker.yaw=0.0
	walker.pitch=-0.10
	assert(game.camera.environment.background_mode==Environment.BG_SKY)
	assert(game.camera.environment.sky.sky_material.shader!=null)
	await capture()
	game.set_process(false)
	var final_x:=float(DISTANCE)*225.0+50.0
	while world_x(walker,neighbors,start)<final_x:
		var before:=world_x(walker,neighbors,start)
		var height: float=walker.pos.y
		walker.step(0.1,Vector2.RIGHT,true)
		var movement:=world_x(walker,neighbors,start)-before
		assert(movement>0.0,"Walking stalled on the seam at %f" % before)
		assert(movement<1.01 and absf(walker.pos.y-height)<0.9,"Walking jumped at the seam")
		assert(game.detail_root.get_node("NeighborTiles")==neighbors and walker.active)
		await process_frame
	assert(walker.tile==destination and not is_instance_valid(detail) and nearby.get_ref()==null)
	assert(neighbors.tiles.size()<=5)
	for frame in 150:
		walker.step(0.1,Vector2.RIGHT,true)
		await process_frame
	var edge_x:=world_x(walker,neighbors,start)
	assert(edge_x>float(DISTANCE)*225.0+111.0 and edge_x<float(DISTANCE)*225.0+112.5)
	assert(walker.tile==destination and not neighbors.can_enter(destination+Vector2i.RIGHT))
	walker.exit_walking()
	assert(not walker.active and game.camera.environment==null)
	assert(game.detail_mode and game.detail_root.tree_cell==destination)
	assert(is_equal_approx(world_x(walker,neighbors,start),edge_x))
	var sea:=Vector2i(1,1)
	assert(not game.grid[sea.y*Grid.COLS+sea.x].land)
	game.game.explored[0]["1:1"]=true
	game.toggle_detail();game.selected=sea;game.open_selected_tile()
	assert(game.detail_rendered_height(0.0,0.0)< -0.78)
	assert(walker.place_at(0.0,0.0) and is_equal_approx(walker.pos.y,-0.78))
	walker.step(0.1,Vector2.RIGHT,false)
	assert(walker.pos.x>0.0 and game.camera.global_position.y>0.0)
	print("DETAIL_WALK_STREAM_OK mobile=",Mobile.active," tiles=",DISTANCE," edge=",destination)
	game.queue_free()
	quit()

func find_route(game: Node) -> Vector2i:
	for r in range(2,Grid.ROWS-2):
		for c in range(2,Grid.COLS-DISTANCE-2):
			var dry:=true
			for i in DISTANCE+1:
				var cell: Dictionary=game.grid[r*Grid.COLS+c+i]
				if not cell.land or cell.get("mountain",false) or cell.get("river",false) or float(cell.h)<8.0:
					dry=false
					break
			if not dry:continue
			for i in DISTANCE+1:
				var heights:=Terrain.tile_heights(game.grid,c+i,r)
				var visual: PackedVector4Array=game.detail_visual_for(c+i,r)
				for x in range(-112,113,4):
					if Terrain.visual_rendered_height(heights,visual,float(x),0.0)<=0.35:
						dry=false
						break
			if dry:return Vector2i(c,r)
	return Vector2i(-1,-1)

func world_x(walker: Node,neighbors: Node,start: Vector2i) -> float:
	return float(walker.pos.x)+float(neighbors.anchor.x-start.x)*225.0

func capture() -> void:
	var output:=OS.get_environment("FPV_TEST_CAPTURE")
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	for frame in 12:await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output)==OK)
