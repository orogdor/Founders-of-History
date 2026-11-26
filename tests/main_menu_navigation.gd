extends SceneTree

const Setup = preload("res://scripts/world_setup.gd")
const Grid = preload("res://scripts/campaign_grid.gd")
const Palette = preload("res://scripts/faction_palette.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,720)
	var game=load("res://campaign.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var legacy := {"schema":1, "source":"2d9ff3999235ba8c95afa57d0cc0a245090ffc9d", "game":game.game}
	assert(game.game.research.size() == 4 and game.valid_partial_save(legacy))
	var menu=game.game_hud.game_menu
	menu.open_menu()
	await process_frame
	assert(menu.home.visible and not menu.menu_card.visible)
	var home_pages := ["new", "saves", "options"]
	for index in home_pages.size():
		menu.home_cards[index + 1].pressed.emit()
		await process_frame
		assert(menu.pages[home_pages[index]].visible and not menu.home.visible)
		menu.show_page("")
	for key in ["new","saves","options","extras"]:
		menu.nav_buttons[key].pressed.emit()
		await process_frame
		for page in menu.pages:
			assert(menu.pages[page].visible == (page == key))
		assert(menu.nav_buttons[key].disabled)
	assert(menu.world_type.item_count == 4 and menu.world_size.item_count == 3)
	assert(menu.opponents.item_count == 6 and menu.color_fields.size() == 6)
	assert(menu.difficulty.item_count >= 3)
	assert(menu.graphics_controls.has("fps") and menu.slots.get_child_count() == 3)
	menu.nav_buttons["new"].pressed.emit()
	await process_frame
	await process_frame
	menu.show_page("")
	menu.home_cards[0].pressed.emit()
	assert(not menu.visible and not game.menu_open)
	menu.open_menu()
	menu.show_page("new")
	menu.choose_value(menu.world_type, "archipelago")
	menu.choose_value(menu.world_size, "small")
	menu.choose_value(menu.opponents, 5)
	menu.choose_value(menu.color_fields[0], "b5bdcf")
	menu.choose_value(menu.color_fields[5], "d075a5")
	menu.refresh_world_setup()
	assert(menu.color_cells[5].visible)
	assert(menu.color_fields[2].is_item_disabled(7))
	menu.seed.text = "saared-163"
	var screenshot := OS.get_environment("FOH_SETUP_CAPTURE")
	if not screenshot.is_empty() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(screenshot) == OK)
	menu.start_new()
	if not await wait_for_world(game):
		return
	assert(Grid.active_size == Setup.SIZES.small)
	assert(game.grid.size() == 120 * 90 and game.fog_image.get_size() == Vector2i(120, 90))
	assert(game.game.type == "archipelago" and game.game.worldSize == "small")
	assert(game.game.settlers.size() == 6 and game.game.armies.size() == 6)
	assert(game.game.research.size() == 6 and game.game.coastalStartPositions.size() == 6)
	assert(game.game.factionColors[0] == "b5bdcf" and game.game.factionColors[5] == "d075a5")
	assert(Palette.color(5, Color.WHITE).to_html(false) == "d075a5")
	var saved_path := "user://main-menu-test-" + str(OS.get_process_id()) + ".json"
	assert(game.save_partial(false, saved_path))
	var first_seed: int = game.game.seed
	menu.import_game(saved_path)
	if not await wait_for_world(game):
		return
	assert(game.game.seed == first_seed and game.game.worldSize == "small" and game.game.opponentCount == 5)
	assert(Palette.color(0, Color.WHITE).to_html(false) == "b5bdcf")
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path)) == OK)
	print("MAIN_MENU_NAVIGATION_OK")
	game.queue_free()
	quit()

func wait_for_world(game: Node) -> bool:
	var deadline := Time.get_ticks_msec() + 65000
	while game.generation_thread != null and Time.get_ticks_msec() < deadline:
		await process_frame
	if game.generation_thread != null:
		push_error("World generation timed out")
		quit(1)
		return false
	return true
