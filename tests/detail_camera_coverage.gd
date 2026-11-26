extends SceneTree

const Mobile=preload("res://scripts/mobile_profile.gd")
const Launcher=preload("res://scripts/launcher_updates.gd")
const Version=preload("res://scripts/build_label.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Mobile.active=true
	root.size=Vector2i(1536,691)
	var updates:=root.get_node("GameUpdates")
	var launcher:=Launcher.new();launcher.cache_dir="user://detail_camera_test"
	updates.add_child(launcher);updates.launcher=launcher
	launcher.mounted={"revision":5,"source":"0123456789abcdef"}
	launcher.active={"revision":6}
	var game: Node=load("res://main.tscn").instantiate()
	root.add_child(game);game.paused=true
	await process_frame
	assert(game.game_hud.labels.game_version.text=="Mäng v5")
	assert(Version.detailed_text(self)=="Mäng v5 · 01234567")
	assert(game.game_hud.game_menu.update_label.text.contains("Uuendus v6"))
	game.game_hud.game_menu.close_menu()
	var origin:=Vector2i(81,117)
	game.reveal_all=false
	game.game.explored[0]={key(origin):true}
	game.selected=origin
	game.open_selected_tile()
	var detail: Node3D=game.detail_root
	var neighbors:=detail.get_node("NeighborTiles")
	assert(neighbors.tiles.is_empty() and neighbors.detail_fog.visible)
	assert(detail.terrain_surface.get_instance_shader_parameter("undiscovered_edges")==Vector4.ONE)
	assert(not neighbors.can_enter(origin+Vector2i.RIGHT))
	await capture()

	var first:=origin+Vector2i.RIGHT
	var second:=first+Vector2i.RIGHT
	game.game.explored[0][key(first)]=true
	game.game.explored[0][key(second)]=true
	game.game.visionRevision=int(game.game.get("visionRevision",0))+1
	game.dragging=true
	game.camera_target.x=153.0
	game.update_camera()
	for frame in 240:
		await process_frame
		if neighbors.can_enter(second):break
	assert(game.detail_root==detail and neighbors.can_enter(first) and neighbors.can_enter(second))
	assert(game.detail_mesh_cache.keys().any(func(entry):return entry.begins_with(key(second)+":")))
	game.dragging=false
	game.follow_detail_camera()
	assert(game.detail_root==detail and is_equal_approx(game.camera_target.x,153.0))
	assert(detail.terrain_surface.get_instance_shader_parameter("undiscovered_edges").y==0.0)
	var nearby: WeakRef=weakref(neighbors.tiles[first])
	for column in range(3,10):game.game.explored[0][key(origin+Vector2i(column,0))]=true
	game.game.visionRevision+=1
	for column in range(2,10):
		var at:=origin+Vector2i(column,0)
		game.camera_target=neighbors.tile_offset(at)
		game.update_camera()
		for frame in 240:
			await process_frame
			if neighbors.can_enter(at) and absi(neighbors.anchor.x-at.x)<3:break
		assert(neighbors.can_enter(at),"The camera could not load known tile %s" % str(at))
		assert(game.detail_root.get_node("NeighborTiles")==neighbors)
		assert(neighbors.coords_at(Vector2(game.camera_target.x,game.camera_target.z))==at)
	for frame in 60:await process_frame
	assert(not is_instance_valid(detail) and nearby.get_ref()==null)
	assert(not game.detail_mesh_cache.keys().any(func(entry):return entry.begins_with(key(first)+":")))
	var edge:=origin+Vector2i(9,0)
	game.camera_target=neighbors.tile_offset(edge+Vector2i.RIGHT)
	game.update_camera();game.follow_detail_camera()
	assert(neighbors.coords_at(Vector2(game.camera_target.x,game.camera_target.z))==edge)
	assert(not neighbors.can_enter(edge+Vector2i.RIGHT))
	print("DETAIL_CAMERA_COVERAGE_OK mounted=5 cached=6 traveled=9 released_previous=true")
	game.queue_free();launcher.queue_free();quit()

func key(at: Vector2i) -> String:
	return "%d:%d" % [at.x,at.y]

func capture() -> void:
	var output:=OS.get_environment("DETAIL_MAP_CAPTURE")
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	for frame in 12:await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output)==OK)
