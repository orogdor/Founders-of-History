extends Node

const Menu = preload("res://scripts/game_menu.gd")
const Loading = preload("res://scripts/loading_screen.gd")
const CAMPAIGN_SCENE = "res://campaign.tscn"
var layer: CanvasLayer
var menu: Control
var loading: Control
var request: Dictionary = {}
var campaign: Node
var requesting_scene := false

func _ready() -> void:
	layer=CanvasLayer.new()
	layer.layer=90
	add_child(layer)
	menu=Menu.new()
	layer.add_child(menu)
	menu.campaign_requested.connect(start_campaign)
	loading=Loading.new()
	layer.add_child(loading)
	menu.open_menu()

func start_campaign(options: Dictionary) -> void:
	if not request.is_empty() or is_instance_valid(campaign):return
	request=options.duplicate(true)
	menu.hide()
	loading.begin("Salvestuse laadimine" if request.has("path") else "Uue maailma loomine","Mänguandmete ettevalmistamine")
	# Present the loading screen before the game's dependency graph is requested.
	await get_tree().process_frame
	await get_tree().process_frame
	var result:=ResourceLoader.load_threaded_request(CAMPAIGN_SCENE,"PackedScene",false)
	if result!=OK:campaign_failed("Mänguandmeid ei saanud avada.")
	else:requesting_scene=true

func _process(_delta: float) -> void:
	if not requesting_scene:return
	var progress: Array=[]
	var status:=ResourceLoader.load_threaded_get_status(CAMPAIGN_SCENE,progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():loading.set_stage("Mänguandmete laadimine",0.25*float(progress[0]))
		ResourceLoader.THREAD_LOAD_LOADED:
			requesting_scene=false
			var scene:=ResourceLoader.load_threaded_get(CAMPAIGN_SCENE) as PackedScene
			if scene==null:campaign_failed("Mänguvaadet ei saanud avada.");return
			campaign=scene.instantiate()
			if not campaign.has_signal("launch_finished"):
				campaign_failed("Mänguvaade ei käivitunud.")
				return
			campaign.launch_request=request
			campaign.loading_progress.connect(loading.set_stage)
			campaign.launch_finished.connect(finish_campaign,CONNECT_DEFERRED)
			loading.set_stage("Maailma ettevalmistamine",0.27)
			get_tree().root.add_child(campaign)
		_:
			campaign_failed("Mänguandmete laadimine ebaõnnestus.")

func finish_campaign(error: String) -> void:
	if not error.is_empty():campaign_failed(error);return
	loading.set_stage("Maailm on valmis",1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var tree:=get_tree()
	tree.current_scene=campaign
	campaign.finish_launch()
	queue_free()

func campaign_failed(message: String) -> void:
	requesting_scene=false
	if is_instance_valid(campaign):campaign.queue_free()
	campaign=null
	if loading!=null:loading.hide()
	menu.open_menu()
	menu.show_page("saves" if request.has("path") else "new")
	menu.menu_status.text=message
	request={}
