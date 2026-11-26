extends SceneTree

const Mobile=preload("res://scripts/mobile_profile.gd")
const ForestFill=preload("res://scripts/detail_forest_fill.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	verify_legacy_forest()
	Mobile.active=OS.get_environment("FOH_VISUAL_DESKTOP").is_empty()
	root.size=Vector2i(1536,691)
	var game: Node=load("res://campaign.tscn").instantiate()
	root.add_child(game);game.paused=true
	await process_frame
	game.game_hud.game_menu.close_menu()
	game.graphics_daylight="day"
	game.toggle_detail()
	game.camera_target=Vector3.ZERO
	game.zoom=64.0;game.update_camera()
	assert(game.sunlight.shadow_enabled and game.sunlight.shadow_opacity<1.0)
	if Mobile.active:
		assert(game.sunlight.directional_shadow_mode==DirectionalLight3D.SHADOW_ORTHOGONAL)
		game.zoom=191.7;game.update_camera()
		assert(not game.sunlight.shadow_enabled)
	game.zoom=64.0;game.update_camera()
	var capture:=OS.get_environment("FOH_DETAIL_CAPTURE")
	if not capture.is_empty() and DisplayServer.get_name()!="headless":
		for frame in 260:
			await process_frame
			if frame>50 and not game.detail_loading_overlay.visible and game.detail_root.forest_fill==null:break
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(capture)==OK)
	game.graphics_shadows=false;game.update_daylight()
	assert(not game.sunlight.shadow_enabled)
	print("DETAIL_SURFACE_APPEARANCE_OK mobile=",Mobile.active)
	game.queue_free();quit()

func verify_legacy_forest() -> void:
	var resources: Array=[]
	for z in [-79,-58,-37,-20,20,37,58,79]:
		for x in range(-103,104,12):
			resources.append({"id":resources.size(),"kind":"tree","x":x,"z":z,"amount":24})
	var heights: Array=[]
	heights.resize(81);heights.fill(2.0)
	var fill:=ForestFill.new()
	fill.setup(Vector2i(82,116),12345,true,resources,heights,[],PackedVector4Array(),true)
	while not fill.done:fill.step(96)
	var middle:=0
	var borders:=Vector2i.ZERO
	for row in fill.rows:
		if absf(row.z)<12.0:middle+=1
		if row.x < -101.0:borders.x+=1
		if row.x > 101.0:borders.y+=1
		assert(absf(row.x)<112.5 and absf(row.z)<97.5 and row.owner.kind=="tree")
	assert(middle>=10 and borders.x>2 and borders.y>2)
	assert(fill.rows.size()<220,"The mobile fill should remain sparse.")
	print("LEGACY_FOREST_FILLED middle=",middle," borders=",borders," total=",fill.rows.size())
