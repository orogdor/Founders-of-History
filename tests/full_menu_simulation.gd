extends RefCounted

static func run(tree: SceneTree, game: Node, capture: String = "") -> void:
	await tree.process_frame
	var hud: Control = game.game_hud
	var menu: Control = hud.game_menu
	while game.generation_thread != null:
		await tree.process_frame
	game.set_process(false)
	menu.open_menu()
	if not verify(tree, menu.home.visible, "menu.home.visible"):
		return
	for entry in [[1,"new"], [2,"saves"], [3,"options"]]:
		menu.home_cards[entry[0]].pressed.emit()
		if not verify(tree, menu.pages[entry[1]].visible, "menu.pages[entry[1]].visible"):
			return
		menu.show_page("")
	menu.show_page("options")
	menu.set_graphics_value("fps", 30)
	menu.set_graphics_value("resolution", 85)
	if not verify(tree, Engine.max_fps == 30 and is_equal_approx(tree.root.scaling_3d_scale, 0.85), "Engine.max_fps == 30 and is_equal_approx(tree.root.scaling_3d_scale, 0.85)"):
		return
	menu.set_graphics_value("fps", 60)
	menu.set_graphics_value("resolution", 100)
	menu.show_page("")
	menu.home_footer.get_child(0).pressed.emit()
	if not verify(tree, menu.pages["extras"].visible, "Home opens game and updates"):
		return
	var initial_reveal: bool = game.reveal_all
	menu.toggle_reveal()
	if not verify(tree, game.reveal_all != initial_reveal, "game.reveal_all != initial_reveal"):
		return
	menu.toggle_reveal()
	var updates := tree.root.get_node_or_null("GameUpdates")
	if updates != null:
		updates.announce("Uuenduse oleku test")
		if not verify(tree, "Uuenduse oleku test" in menu.update_label.text, "\"Uuenduse oleku test\" in menu.update_label.text"):
			return
	menu.open_controls()
	if not verify(tree, hud.legacy_panel.visible and not menu.visible, "hud.legacy_panel.visible and not menu.visible"):
		return
	hud.legacy_panel.hide()
	menu.open_menu()
	menu.show_page("new")
	var original_window_size := tree.root.size
	tree.root.size = Vector2i(480,720)
	await tree.process_frame
	await tree.process_frame
	if not verify(tree, menu.back_compact.visible and not menu.menu_cover.visible, "menu.back_compact.visible and not menu.menu_cover.visible"):
		return
	tree.root.size = original_window_size
	await tree.process_frame
	await tree.process_frame

	menu.choose_value(menu.opponents,0)
	menu.refresh_world_setup()
	if not verify(tree, not menu.color_cells[1].visible, "not menu.color_cells[1].visible"):
		return
	menu.choose_value(menu.opponents,5)
	menu.choose_value(menu.world_type,"archipelago")
	menu.choose_value(menu.world_size,"small")
	menu.choose_value(menu.color_fields[0],"b5bdcf")
	menu.choose_value(menu.color_fields[5],"d075a5")
	menu.refresh_world_setup()
	if not verify(tree, menu.color_cells[5].visible and menu.color_fields[4].is_item_disabled(7), "menu.color_cells[5].visible and menu.color_fields[4].is_item_disabled(7)"):
		return
	menu.seed.text = "saared-163"
	await tree.process_frame
	await tree.process_frame
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not verify(tree, tree.root.get_texture().get_image().save_png(capture) == OK, "tree.root.get_texture().get_image().save_png(capture) == OK"):
			return
	menu.new_game_button.pressed.emit()
	await wait_for_generation(tree,game)
	if not verify(tree, not menu.visible and game.grid.size() == 10800 and game.game.opponentCount == 5, "not menu.visible and game.grid.size() == 10800 and game.game.opponentCount == 5"):
		return
	if not verify(tree, game.game.settlers.size() == 6 and game.game.armies.size() == 6 and game.game.nextSettler == 6, "game.game.settlers.size() == 6 and game.game.armies.size() == 6 and game.game.nextSettler == 6"):
		return
	if not verify(tree, game.game.coastalStartPositions.size() == 6, "game.game.coastalStartPositions.size() == 6"):
		return
	if not verify(tree, game.game.factionColors[0] == "b5bdcf" and game.game.factionColors[5] == "d075a5", "game.game.factionColors[0] == \"b5bdcf\" and game.game.factionColors[5] == \"d075a5\""):
		return
	print("MENU_SETUP_AND_OPTIONS_OK")

	for mode in ["cities","armies","trade","diplomacy","journal"]:
		await check_dock(tree,hud,mode)
	hud.open_research()
	if not verify(tree, hud.research_screen.visible, "hud.research_screen.visible"):
		return
	hud.research_screen.close_screen()
	hud.diplomacy_screen.open_screen()
	if not verify(tree, hud.diplomacy_screen.visible, "hud.diplomacy_screen.visible"):
		return
	hud.diplomacy_screen.change_relation(5,"friendly")
	if not verify(tree, game.game.relations["0:5"].status == "friendly", "game.game.relations[\"0:5\"].status == \"friendly\""):
		return
	hud.diplomacy_screen.hide()
	hud.open_stores("food")
	if not verify(tree, hud.stores_panel.visible, "hud.stores_panel.visible"):
		return
	hud.open_stores("food")
	if not verify(tree, not hud.stores_panel.visible, "not hud.stores_panel.visible"):
		return
	hud.show_journal()
	if not verify(tree, hud.journal_dialog.visible, "hud.journal_dialog.visible"):
		return
	hud.journal_dialog.hide()
	print("MENU_MAP_DOCK_OK")

	for second in range(1,181):
		game._process(1.0)
		if second % 12 == 0:
			await tree.process_frame
		if second in [60,120,180]:
			print("CAMPAIGN_SIMULATION second=",second," cities=",game.game.cities.size()," armies=",game.game.armies.size())
	if not verify(tree, game.city_created, "game.city_created"):
		return
	var founded := {}
	for city in game.game.cities:
		founded[int(city.team)] = city
	if not verify(tree, founded.size() == 6, "founded.size() == 6"):
		return
	for team in 6:
		if not verify(tree, founded[team].economy.realms.size() == 6, "founded[team].economy.realms.size() == 6"):
			return
	if not verify(tree, game.game.lastAIResearchPlan >= 168.0, "game.game.lastAIResearchPlan >= 168.0"):
		return
	print("CAMPAIGN_SIX_FACTIONS_OK")

	for mode in ["build","city","labor"]:
		await check_dock(tree,hud,mode)
	hud.open_city_overview()
	if not verify(tree, hud.city_overview.visible and hud.city_overview.merchant_buttons[4].visible, "hud.city_overview.visible and hud.city_overview.merchant_buttons[4].visible"):
		return
	hud.city_overview.hide()
	menu.open_menu()
	menu.show_page("saves")
	var save_path: String = menu.slot_path(1)
	if not verify(tree, not FileAccess.file_exists(save_path), "not FileAccess.file_exists(save_path)"):
		return
	menu.save_slot(1)
	if not verify(tree, FileAccess.file_exists(save_path), "FileAccess.file_exists(save_path)"):
		return
	if not verify(tree, not menu.slots.get_child(0).get_child(2).disabled, "not menu.slots.get_child(0).get_child(2).disabled"):
		return
	menu.load_slot(1)
	await wait_for_generation(tree,game)
	if not verify(tree, game.game.opponentCount == 5 and game.game.cities.size() >= 6 and game.game.factionColors[5] == "d075a5", "game.game.opponentCount == 5 and game.game.cities.size() >= 6 and game.game.factionColors[5] == \"d075a5\""):
		return
	if not verify(tree, DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path)) == OK, "DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path)) == OK"):
		return
	var exported := "user://menu-simulation-export-%d.json" % OS.get_process_id()
	menu.export_game(exported)
	if not verify(tree, game.valid_partial_save(game.read_partial_json(exported)), "game.valid_partial_save(game.read_partial_json(exported))"):
		return
	menu.import_game("user://missing-menu-simulation-file.json")
	if not verify(tree, "ei sobi" in menu.menu_status.text, "\"ei sobi\" in menu.menu_status.text"):
		return
	if not verify(tree, DirAccess.remove_absolute(ProjectSettings.globalize_path(exported)) == OK, "DirAccess.remove_absolute(ProjectSettings.globalize_path(exported)) == OK"):
		return
	print("MENU_CITY_SAVE_LOAD_EXPORT_OK")
	print("FULL_MENU_SIMULATION_OK")
	menu.open_menu()
	menu.home_footer.get_child(1).pressed.emit()

static func check_dock(tree: SceneTree, hud: Control, mode: String) -> void:
	if hud.elements.has("card_"+mode):
		hud.elements["card_"+mode].pressed.emit()
	else:
		hud.open_card(mode)
	await tree.process_frame
	if not verify(tree, hud.dock_menu.visible and hud.dock_menu.kind == mode, "hud.dock_menu.visible and hud.dock_menu.kind == mode"):
		return
	hud.dock_menu.close_menu()
	if not verify(tree, not hud.dock_menu.visible and hud.elements["card_cities"].visible, "not hud.dock_menu.visible and hud.elements[\"card_cities\"].visible"):
		return

static func wait_for_generation(tree: SceneTree, game: Node) -> void:
	var expires := Time.get_ticks_msec() + 70000
	while game.generation_thread != null and Time.get_ticks_msec() < expires:
		await tree.process_frame
	if not verify(tree, game.generation_thread == null, "game.generation_thread == null"):
		return

static func verify(tree: SceneTree, passed: bool, description: String) -> bool:
	if passed:
		return true
	push_error("Menu simulation failed: " + description)
	tree.quit(1)
	return false
