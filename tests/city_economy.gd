extends SceneTree

const Economy = preload("res://scripts/economy_rules.gd")
const Flows = preload("res://scripts/city_resource_flows.gd")
const Needs = preload("res://scripts/city_needs.gd")
const GameScene = preload("res://campaign.tscn")
const Mobile = preload("res://scripts/mobile_profile.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var realm := {"pop":4.0,"resources":{"wood":30.0,"grain":20.0,"pottery":3.0},"log":[]}
	var economy := {"realms":[realm],"time":90.0}
	var city := {"team":0,"economy":economy}
	var failures: Array[String] = []
	if Flows.recent(realm,90.0).minutes != 0:
		failures.append("An existing save should start without a rate estimate")
	Flows.observe(realm,90.0)
	Flows.record(realm,119.0,"wood",100.0)
	if Flows.recent(realm,120.0).minutes != 0:
		failures.append("An incomplete starting minute should be excluded")

	# Local deliveries, recurring recipe costs and household withdrawals.
	economy.time = 179.0
	Needs.consume_luxuries(city,0,1.0)
	economy.time = 180.0
	Economy.demographics_turn(city,economy,[],true)
	Economy.spend_resources(realm.resources,{"wood":7.0},Flows.consumption(realm,180.0))
	Economy.spend_resources(realm.resources,{"wood":1.0})
	realm.resources.wood += 2.0
	Flows.record(realm,180.0,"wood",2.0)
	Flows.record(realm,181.0,"wood",8.0)
	var first := Flows.recent(realm,180.0)
	if first.minutes != 1 or first.rates.get("wood",Vector2.ZERO) != Vector2(2.0,7.0):
		failures.append("Wood should show one complete minute of deliveries and recipe use")
	check_rate(first,"grain",Vector2(0.0,2.4/0.7),failures)
	check_rate(first,"gold",Vector2(4.0,0.0),failures)
	check_rate(first,"water",Vector2(1.8,1.8),failures)
	if not is_equal_approx(first.rates.get("pottery",Vector2.ZERO).y,4.0*0.02/60.0):
		failures.append("Luxury goods taken by households should count toward use")

	# Save files round-trip through JSON. Old minutes must expire after quiet periods.
	var restored: Dictionary = JSON.parse_string(JSON.stringify(realm))
	check_rate(Flows.recent(restored,240.0),"wood",Vector2(5.0,3.5),failures)
	Flows.record(restored,421.0,"stone",4.0)
	if Flows.recent(restored,420.0).rates.has("wood") or restored.resourceFlows.minutes.has("2"):
		failures.append("The three-minute average should forget older activity")
	if not failures.is_empty():
		report_failures(failures)
		return

	root.size = Vector2i(640,360)
	Mobile.active = true
	var host := GameScene.instantiate()
	root.add_child(host)
	host.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	host.game_hud.game_menu.close_menu()
	city.merge({"id":0,"c":host.player.x,"r":host.player.y,"radius":1,"name":"Katselinn"})
	host.game.cities = [city]
	host.city_created = true
	host.resources_button.pressed.emit()
	for frame in 4:
		await process_frame
	var dialog: AcceptDialog = host.resources_dialog
	var table: VBoxContainer = host.resources_detail
	var available := Vector2i(host.get_viewport().get_visible_rect().size)-Vector2i(20,58)
	if not dialog.visible or dialog.size.x > available.x or dialog.size.y > available.y:
		failures.append("The resources dialog size %s should fit %s (min %s, child %s)" % [dialog.size,available,dialog.min_size,table.get_combined_minimum_size()])
	if not table.rows.wood.row.visible or table.rows.wood.cells[4].text != "4.8 min":
		failures.append("The resources dialog should show 24 wood lasting 4.8 minutes")
	if table.rows.iron.row.visible:
		failures.append("Inactive resources should be collapsed initially")
	table.show_all.button_pressed = true
	if not table.rows.iron.row.visible:
		failures.append("The full list should show inactive resources")
	host.queue_free()
	await process_frame
	if not failures.is_empty():
		report_failures(failures)
		return
	print("PASS city resource flows, save compatibility and economy dialog at ",available+Vector2i(20,58))
	quit()

func check_rate(measurement: Dictionary, key: String, expected: Vector2, failures: Array[String]) -> void:
	var actual: Vector2 = measurement.rates.get(key,Vector2.ZERO)
	if not actual.is_equal_approx(expected):
		failures.append("%s expected %s, got %s" % [key,expected,actual])

func report_failures(failures: Array[String]) -> void:
	for message in failures:
		printerr(message)
	quit(1)
