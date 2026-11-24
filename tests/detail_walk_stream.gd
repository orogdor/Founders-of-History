extends SceneTree

const Grid=preload("res://scripts/campaign_grid.gd")
const Terrain=preload("res://scripts/detail_terrain.gd")
const Mobile=preload("res://scripts/mobile_profile.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Mobile.active=OS.get_environment("FPV_TEST_DESKTOP").is_empty()
	root.size=Vector2i(1280,720)
	var game: Node=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.paused=true
	await process_frame
	game.game_hud.game_menu.close_menu()
	game.reveal_all=true
	var start:=find_route(game)
	assert(start.x>=0,"No dry route across two map borders")
	game.selected=start
	game.open_selected_tile()
	var detail: Node3D=game.detail_root
	var neighbors: Node=detail.get_node("NeighborTiles")
	var first:=start+Vector2i.RIGHT
	var second:=first+Vector2i.RIGHT
	assert(neighbors.can_enter(first) and not neighbors.can_enter(second))
	var walker: Node=game.fpv_walker
	assert(walker.place_at(108.0,0.0))
	walker.yaw=0.0
	walker.pitch=-0.10
	assert(game.camera.environment.background_mode==Environment.BG_SKY)
	assert(game.camera.environment.sky.sky_material.shader!=null)
	await capture()
	while walker.pos.x<339.0:
		var before: Vector3=walker.pos
		if before.x>330.0:assert(neighbors.can_enter(second),"Destination terrain should be ready before its border")
		walker.step(0.1,Vector2.RIGHT,true)
		assert(walker.pos.x>before.x,"Walking stalled on the seam at %f" % before.x)
		assert(walker.pos.x-before.x<1.0 and absf(walker.pos.y-before.y)<0.9,"Walking jumped at the seam")
		assert(game.detail_root==detail and game.detail_mode and walker.active,"Walking rebuilt the open detail map")
		await process_frame
	assert(walker.tile==second and neighbors.tiles[second].has_meta("nature_ready"))
	assert(neighbors.tiles.size()<=24)
	var final_x: float=walker.pos.x
	walker.exit_walking()
	assert(not walker.active and game.camera.environment==null)
	assert(game.detail_mode and game.detail_root.tree_cell==second)
	assert(is_equal_approx(walker.pos.x,final_x-450.0))
	print("DETAIL_WALK_STREAM_OK mobile=",Mobile.active," start=",start," end=",second," final_x=",final_x)
	game.queue_free()
	quit()

func find_route(game: Node) -> Vector2i:
	for r in range(2,Grid.ROWS-2):
		for c in range(2,Grid.COLS-4):
			var dry:=true
			for i in 3:
				var cell: Dictionary=game.grid[r*Grid.COLS+c+i]
				if not cell.land or cell.get("mountain",false) or cell.get("river",false) or float(cell.h)<8.0:
					dry=false
					break
			if not dry:continue
			for i in 3:
				var heights:=Terrain.tile_heights(game.grid,c+i,r)
				var visual: PackedVector4Array=game.detail_visual_for(c+i,r)
				for x in range(-112,113,4):
					if Terrain.visual_rendered_height(heights,visual,float(x),0.0)<=0.35:
						dry=false
						break
			if dry:return Vector2i(c,r)
	return Vector2i(-1,-1)

func capture() -> void:
	var output:=OS.get_environment("FPV_TEST_CAPTURE")
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	for frame in 12:await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output)==OK)
