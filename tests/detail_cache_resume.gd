extends SceneTree

const Mobile=preload("res://scripts/mobile_profile.gd")

func _initialize() -> void:call_deferred("run")

func run() -> void:
	Mobile.active=false
	var game: Node=load("res://campaign.tscn").instantiate()
	root.add_child(game)
	game.simulation_paused=true
	await process_frame
	game.game.time=120.0
	game.end_migration()
	assert(game.city_created)

	game.toggle_detail()
	var first: Node=game.detail_root
	var neighbors:=first.get_node("NeighborTiles")
	var city: Dictionary=game.game.cities[game.active_city_index]
	assert(not first.person.visible and first.village_life!=null)
	game.toggle_detail()
	assert(game.parked_city_view==first and first.process_mode==Node.PROCESS_MODE_DISABLED)
	assert(game.parked_neighbors==neighbors and not first.visible)
	game.toggle_detail()
	assert(game.detail_root==first and first.get_node("NeighborTiles")==neighbors and first.visible)

	game.toggle_detail()
	city.economy.buildings[0].buildingRotationV228=0.63
	game.toggle_detail()
	assert(game.detail_root!=first,"A changed settlement must rebuild its local view")
	assert(game.detail_root.get_node("NeighborTiles")==neighbors,"A house change can still reuse nearby terrain")
	await process_frame
	assert(not is_instance_valid(first))

	game.reveal_all=true
	var neighbor_at: Vector2i=game.player+Vector2i.RIGHT
	assert(game.transition_detail_tile(neighbor_at,Vector2i.RIGHT,true))
	game.toggle_detail()
	var neighboring_stream: Node=game.parked_neighbors
	game.toggle_detail()
	var city_stream: Node=game.detail_root.get_node("NeighborTiles")
	assert(city_stream!=neighboring_stream)
	# The old stream stays in the tree until the frame ends. Replacing it
	# and then resuming the city must keep the canonical child name.
	game.toggle_detail()
	game.toggle_detail()
	assert(game.detail_root.get_node_or_null("NeighborTiles")==city_stream)
	neighbors=city_stream

	game.toggle_detail()
	game.parked_at_time-=55.0
	game.update_detail_warmup()
	assert(game.parked_city_view==null and game.parked_neighbors==null,"An expired detail scene must release its nodes")
	await process_frame
	assert(not is_instance_valid(neighbors))
	print("DETAIL_CACHE_RESUME_OK")
	game.queue_free()
	quit()
