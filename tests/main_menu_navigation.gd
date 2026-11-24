extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,720)
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var menu=game.game_hud.game_menu
	menu.open_menu()
	await process_frame
	for key in ["new","saves","options","extras"]:
		menu.nav_buttons[key].pressed.emit()
		await process_frame
		for page in menu.pages:
			assert(menu.pages[page].visible == (page == key))
		assert(menu.nav_buttons[key].disabled)
	assert(menu.world_type.item_count >= 3 and menu.difficulty.item_count >= 3)
	assert(menu.graphics_controls.has("fps") and menu.slots.get_child_count() == 3)
	menu.nav_buttons["new"].pressed.emit()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png("/tmp/founders-menu.png")
	menu.close_menu()
	assert(not menu.visible and not game.menu_open)
	print("MAIN_MENU_NAVIGATION_OK")
	game.queue_free()
	quit()
