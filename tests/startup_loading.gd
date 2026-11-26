extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var title=load("res://main.tscn").instantiate()
	root.add_child(title)
	current_scene=title
	await process_frame
	assert(title.menu.visible and title.campaign==null)
	assert(not ResourceLoader.has_cached(title.CAMPAIGN_SCENE),"Opening the title must leave the campaign unloaded")
	title.menu.show_page("saves")
	title.menu.show_page("options")
	title.menu.show_page("new")
	await process_frame
	assert(title.campaign==null and not ResourceLoader.has_cached(title.CAMPAIGN_SCENE))
	title.menu.choose_value(title.menu.world_type,"archipelago")
	title.menu.choose_value(title.menu.world_size,"small")
	title.menu.choose_value(title.menu.opponents,5)
	title.menu.seed.text="saared-163"
	title.menu.start_new()
	assert(title.loading.visible and title.campaign==null)
	var deadline:=Time.get_ticks_msec()+70000
	while is_instance_valid(title) and Time.get_ticks_msec()<deadline:
		await process_frame
	if is_instance_valid(title):
		push_error("Startup did not enter the campaign: "+title.menu.menu_status.text)
		quit(1);return
	var game:=current_scene
	assert(game.grid.size()==120*90 and game.game.opponentCount==5)
	assert(game.terrain!=null and game.fog!=null and game.launch_request.is_empty())
	game.paused=true
	game.request_detail_view()
	assert(game.requested_detail)
	var detail_deadline:=Time.get_ticks_msec()+8000
	while game.requested_detail and Time.get_ticks_msec()<detail_deadline:await process_frame
	assert(game.detail_mode and not game.requested_detail)
	var stream: Node=game.detail_root.get_node("NeighborTiles")
	game.toggle_detail()
	assert(game.parked_neighbors==stream and stream.process_mode==Node.PROCESS_MODE_DISABLED)
	game.request_detail_view()
	assert(game.detail_mode and game.detail_root.get_node("NeighborTiles")==stream)
	print("STARTUP_LOADING_OK")
	quit()

