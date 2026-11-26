extends SceneTree

const Mobile=preload("res://scripts/mobile_profile.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Mobile.active=OS.get_environment("FOH_VISUAL_DESKTOP").is_empty()
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.paused=true
	await process_frame
	game.graphics_daylight="day";game.graphics_ambient="normal";game.update_daylight()
	var daylight_energy: float=game.sunlight.light_energy
	var daylight_ambient: float=game.world_environment.environment.ambient_light_energy
	assert(daylight_energy>game.fill_light.light_energy*5.0)
	game.graphics_daylight="night";game.update_daylight()
	assert(game.sunlight.light_energy<daylight_energy*0.3)
	assert(game.world_environment.environment.ambient_light_energy<daylight_ambient*0.5)
	game.graphics_daylight="evening";game.update_daylight()
	assert(game.sunlight.light_color.r>game.sunlight.light_color.b)
	game.graphics_daylight="day";game.toggle_detail();game.zoom=64.0;game.update_camera();game.update_daylight()
	assert(game.sunlight.shadow_enabled and game.sunlight.shadow_opacity<1.0)
	var walker=game.fpv_walker
	walker.active=true;walker.start_sky()
	game.graphics_ambient="low";game.update_daylight()
	assert(is_equal_approx(walker.walking_environment.ambient_light_energy,game.world_environment.environment.ambient_light_energy))
	game.graphics_ambient="bright";game.update_daylight()
	assert(is_equal_approx(walker.walking_environment.ambient_light_energy,game.world_environment.environment.ambient_light_energy))
	walker.active=false
	game.graphics_shadows=false;game.update_daylight();assert(not game.sunlight.shadow_enabled)
	print("LIGHTING_BALANCE_OK mobile=",Mobile.active)
	game.queue_free();quit()
