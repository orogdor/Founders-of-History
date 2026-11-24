extends Node

var message: Label
var progress: ProgressBar
var retry: Button
var offline: Button

func _ready() -> void:
	if GameUpdates.launcher == null:
		call_deferred("_open_game")
		return
	var screen := ColorRect.new()
	screen.color = Color("13201c")
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,24)
	screen.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = minf(480,get_viewport().get_visible_rect().size.x-48)
	panel.add_theme_constant_override("separation",15)
	center.add_child(panel)
	var title := Label.new()
	title.text = "Founders of History"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",32)
	panel.add_child(title)
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(message)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 22
	progress.show_percentage = true
	panel.add_child(progress)
	retry = Button.new()
	retry.text = "Proovi uuesti"
	retry.custom_minimum_size.y = 48
	retry.pressed.connect(GameUpdates.check)
	panel.add_child(retry)
	offline = Button.new()
	offline.text = "Mängi salvestatud versiooni"
	offline.custom_minimum_size.y = 48
	offline.pressed.connect(GameUpdates.launcher.play_offline)
	panel.add_child(offline)
	GameUpdates.status_changed.connect(func(value: String):message.text=value)
	GameUpdates.launcher.ready_to_play.connect(_open_game,CONNECT_DEFERRED)
	GameUpdates.check()

func _process(_delta: float) -> void:
	if message == null:return
	var updater:=GameUpdates.launcher
	retry.visible = not updater.busy and updater.starting
	offline.visible = updater.starting and updater.verification==null and not updater.active.is_empty()
	progress.visible = updater.download_size>0
	if progress.visible:
		progress.max_value = updater.download_size
		progress.value = updater.request.get_downloaded_bytes()

func _open_game() -> void:
	var result := get_tree().change_scene_to_file("res://main.tscn")
	if result != OK:
		if message != null:message.text="Mängu ei saanud avada."
		push_error("Mängu põhivaadet ei saanud avada: " + str(result))
