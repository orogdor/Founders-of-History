extends SceneTree

const Builders = preload("res://scripts/district_builders.gd")
const Research = preload("res://scripts/research_rules.gd")
const AIResearch = preload("res://scripts/ai_research.gd")
const Housing = preload("res://scripts/ai_housing.gd")
const Mobile = preload("res://scripts/mobile_profile.gd")
const GameScene = preload("res://campaign.tscn")
const FIXTURES = "res://tests/fixtures/iron/"
const RESEARCH_GOALS = ["fire_use","woodworking","agriculture","hunting","fishing","forestry","stone_crafts","learning","storage","milling","commerce","civics"]
const PAUSED_WORKPLACES = ["lumber","quarry","saw","study","scriptorium","coal","forester"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Mobile.active = true
	Engine.max_fps = 0
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var scenario: String = args[0] if not args.is_empty() else "all"
	if args.size() > 1 or scenario not in ["all","delivery","transition"]:
		printerr("Usage: iron_age_replay.gd -- [delivery|transition]")
		quit(2)
		return
	if scenario in ["all","delivery"]:
		var host: Node = await resume_fixture("resume-090.json.gz",5400)
		if host == null:
			quit(1)
			return
		var delivered := check_delivery(host)
		host.queue_free()
		await process_frame
		if not delivered:
			quit(1)
			return
	if scenario in ["all","transition"]:
		var host: Node = await resume_fixture("resume-135.json.gz",8100)
		if host == null:
			quit(1)
			return
		var advanced: bool = await check_transition(host)
		host.queue_free()
		await process_frame
		if not advanced:
			quit(1)
			return
	quit()

func resume_fixture(filename: String, expected_seconds: float) -> Node:
	var archive := FileAccess.get_file_as_bytes(FIXTURES.path_join(filename))
	var payload := archive.decompress_dynamic(20_000_000,FileAccess.COMPRESSION_GZIP)
	if payload.is_empty():
		printerr("Could not decompress ",filename)
		return null
	var fixture := FileAccess.create_temp(FileAccess.WRITE,"iron-age",".json",true)
	if fixture == null:
		printerr("Could not create temporary save file")
		return null
	var path := fixture.get_path_absolute()
	fixture.store_buffer(payload)
	fixture.close()
	var host := GameScene.instantiate()
	root.add_child(host)
	host.set_process(false)
	await process_frame
	host.load_partial(path)
	while host.generation_thread != null:
		await process_frame
	DirAccess.remove_absolute(path)
	host.autosave_suspended = true
	if not host.city_created or not is_equal_approx(float(host.game.time),expected_seconds) or int(host.game.ages[0]) != 2:
		printerr("Failed to resume Iron Age fixture ",filename," at ",expected_seconds," seconds")
		host.queue_free()
		return null
	return host

func check_delivery(host: Node) -> bool:
	var city: Dictionary = host.game.cities[0]
	var workers: Array = city.get("builderAgents",[])
	var district: Dictionary = city.get("districts",{}).get("82:109",{})
	var buildings: Array = district.get("economy",{}).get("buildings",[])
	if workers.is_empty() or buildings.size() < 2:
		printerr("Delivery fixture is missing the builder or farm")
		return false
	var worker: Dictionary = workers[0]
	var farm: Dictionary = buildings[1]
	var load_amount := float(worker.get("materialLoad",0))
	var needed := float(farm.get("materialsRemaining",0))
	if not is_equal_approx(load_amount,24.0) or not is_equal_approx(needed,30.0):
		printerr("Unexpected initial materials. Builder ",load_amount,", farm ",needed)
		return false
	city.buildersAssigned = 1
	# Old JSON saves used decimal tile coordinates in some job IDs.
	worker.job = "82.0:109.0:1"
	worker.materialJob = worker.job
	var context_at := func(tile): return host.district_context_at(city,tile,true)
	var path_for := func(from,to,team): return host.district_builder_path(city,from,to,team)
	for step in 90:
		host.game.time += 2.0
		Builders.tick(host.game,city,2.0,context_at,host.district_nav_for,path_for)
		if step == 0 and (worker.job != "82:109:1" or not is_equal_approx(float(worker.get("materialLoad",0)),load_amount)):
			printerr("Restored builder lost its job or cargo")
			return false
		var remaining := float(farm.materialsRemaining)
		if remaining < needed:
			if not is_equal_approx(needed-remaining,load_amount) or not is_zero_approx(float(worker.get("materialLoad",0))):
				printerr("Incorrect material delivery. Remaining ",remaining,", builder ",worker.get("materialLoad",0))
				return false
			print("PASS district delivery: ",load_amount," materials in ",(step+1)*2," game seconds")
			return true
	printerr("Builder failed to deliver to the farm in 180 game seconds")
	return false

func check_transition(host: Node) -> bool:
	var state: Dictionary = host.game
	var city: Dictionary = state.cities[host.active_city_index]
	host.change_builder_limit(0.0)
	for building in city.economy.buildings:
		if building.type in PAUSED_WORKPLACES:
			host.change_workplace_labor(0.0,building)
	host.game_hud.game_menu.close_menu()
	host.paused = false
	host.simulation_paused = false
	host.menu_open = false
	host.graphics_daylight = "day"
	host.update_daylight()
	host.zoom = 25.0
	host.update_camera()

	var deadline := float(state.time)+900.0
	var last_plan := -INF
	var last_housing := -INF
	var progress: Dictionary = state.research[0]
	while float(state.time) < deadline:
		var now := float(state.time)
		if now-last_plan >= 12.0:
			last_plan = now
			if progress.active == null:
				var goal: Variant = AIResearch.next_for_goals(progress,RESEARCH_GOALS)
				if goal != null:
					Research.start_research(state,0,goal)
			if now-last_housing >= 36.0:
				last_housing = now
				Housing.plan(state,city)
			var runtime: Dictionary = host.ensure_city_runtime(city)
			host.tick_ai_build(city,runtime)
			host.tick_ai_field(city,runtime,city)
			host.plan_ai_rural(city)
		host._process(6.0)
		if float(state.time) <= now:
			printerr("Simulation stopped at ",now," game seconds")
			return false
		if int(state.ages[0]) != 2:
			if int(state.ages[0]) != 3 or not progress.known.has("civics"):
				printerr("Unexpected transition at ",state.time,". Age ",state.ages[0],", known ",progress.known)
				return false
			print("PASS Iron Age to Middle Ages at ",state.time," game seconds")
			return true
		if int(state.time) % 60 == 0:
			await process_frame
	printerr("Age transition timed out. Research ",progress.active,", wait ",progress.get("ageWait"),", supplies ",city.economy.realms[0].resources)
	return false
