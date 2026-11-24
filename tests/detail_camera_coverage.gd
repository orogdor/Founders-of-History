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
	assert(neighbors.tiles.is_empty() and detail.get_node("DetailMapFog").visible)
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
	assert(game.detail_root.tree_cell==first and is_equal_approx(game.camera_target.x,-72.0))
	print("DETAIL_CAMERA_COVERAGE_OK mounted=5 cached=6 loaded_tiles=2")
	game.queue_free();launcher.queue_free();quit()

func key(at: Vector2i) -> String:
	return "%d:%d" % [at.x,at.y]

func capture() -> void:
	var output:=OS.get_environment("DETAIL_MAP_CAPTURE")
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	for frame in 12:await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output)==OK)
