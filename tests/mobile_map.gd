extends SceneTree

const Mobile = preload("res://scripts/mobile_profile.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Mobile.active=true
	root.size=Vector2i(1440,810)
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.paused=true
	await process_frame
	game.game_hud.game_menu.close_menu()
	await process_frame
	assert(game.world_mesh_samples.subdivisions==2)
	assert(not game.sunlight.shadow_enabled and is_equal_approx(root.scaling_3d_scale,0.7))
	var center:=root.get_visible_rect().get_center()
	var first:=center-Vector2(90,0)
	var second:=center+Vector2(90,0)
	var initial_zoom: float=game.zoom
	var initial_selection: Vector2i=game.selected
	touch(0,first,true)
	touch(1,second,true)
	assert(game.map_touch.pinching,"Both map fingers should start a pinch")
	var drag:=InputEventScreenDrag.new()
	drag.index=0
	drag.position=first-Vector2(70,0)
	drag.relative=Vector2(-70,0)
	root.push_input(drag)
	touch(0,drag.position,false)
	touch(1,second,false)
	assert(game.zoom<initial_zoom and game.selected==initial_selection)
	assert(game.map_touch.fingers.is_empty() and not game.dragging)
	for i in 90:
		if game.terrain.get_surface_override_material(0).get_shader_parameter("surface_textures_ready"):break
		await process_frame
	assert(game.terrain.get_surface_override_material(0).get_shader_parameter("surface_textures_ready"))
	await capture("world")
	var dock=game.game_hud.dock_menu
	dock.open_menu("build")
	assert(game.detail_mode and not game.city_created)
	await process_frame
	await process_frame
	assert(game.game_hud.elements.settle_touch.visible)
	game.game.time=120.0
	game.end_migration()
	assert(game.city_created)
	if not game.detail_mode:game.toggle_detail()
	assert(game.can_build_on_detail())
	var city: Dictionary=game.current_build_context()
	city.economy.realms[0].resources.merge({"wood":500,"stone":500,"gold":500},true)
	dock.open_menu("build")
	var house_index := -1
	for i in game.build_select.item_count:
		if game.build_select.get_item_metadata(i)=="house":
			house_index=i
			break
	assert(house_index>=0 and dock.visible)
	dock.choose_building(house_index)
	assert(game.build_placement_mode and not dock.visible)
	await process_frame
	await process_frame
	assert(game.game_hud.elements.cancel_build_touch.visible)
	var hall: Dictionary=city.economy.buildings[0]
	var site: Variant=null
	for distance in range(14,65,6):
		for angle in 12:
			var offset:=Vector2.from_angle(angle*TAU/12.0)*distance
			var pos:=((Vector2(hall.x,hall.z)+offset)/2.0).round()*2.0
			var screen: Vector2=game.camera.unproject_position(Vector3(pos.x,game.detail_root.display_height(pos.x,pos.y),pos.y))
			if not root.get_visible_rect().grow(-125.0).has_point(screen):continue
			if not game.building_site_check(city,"house",pos).has("error"):
				site=screen
				break
		if site!=null:break
	assert(site!=null)
	var count: int=city.economy.buildings.size()
	touch(0,site,true)
	assert(game.map_touch.fingers.has(0),"The construction tap should reach the map at "+str(site))
	touch(0,site,false)
	assert(city.economy.buildings.size()==count+1,"A map tap should queue a house. "+game.status.text)
	assert(city.economy.buildings.back().type=="house" and not game.build_placement_mode)
	await capture("detail")
	print("MOBILE_MAP_OK world_zoom=",game.world_zoom," house=",city.economy.buildings.back().type)
	game.queue_free()
	quit()

func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=index
	event.position=point
	event.pressed=pressed
	root.push_input(event)

func capture(view: String) -> void:
	var output:=OS.get_environment("MOBILE_MAP_TEST_CAPTURE")
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output+"-"+view+".png")==OK)
