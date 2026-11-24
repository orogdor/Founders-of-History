extends Control

const InterfaceTheme = preload("res://scripts/interface_theme.gd")

const Mobile = preload("res://scripts/mobile_profile.gd")
const BuildLabel = preload("res://scripts/build_label.gd")

var host: Node
var hud: Control
var seed: LineEdit
var tempo: OptionButton
var difficulty: OptionButton
var world_type:OptionButton
var reveal_button: Button
var world_body: VBoxContainer
var saves_body: VBoxContainer
var menu_status: Label
var menu_scroll: ScrollContainer
var menu_frame: PanelContainer
var menu_card: PanelContainer
var menu_cover: Control
var slots: VBoxContainer
var export_dialog: FileDialog
var import_dialog: FileDialog
var options_body: VBoxContainer
var scale_select: OptionButton
var continue_button: Button
var graphics_controls: Dictionary={}
var performance_layer: CanvasLayer
var performance_label: Label
var performance_clock:=0.0
var update_label: Label
const SETTINGS_PATH:="user://kuningriigid_godot_settings.cfg"
var was_loading:=false
var pages: Dictionary={}
var nav_buttons: Dictionary={}
var page_title: Label
var sidebar: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP;visible=false
	var background:=TextureRect.new();background.texture=load("res://assets/ui/ui-art-v304_chronicle.webp")
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	var shade:=ColorRect.new();shade.color=Color("06101b");shade.color.a=0.82
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(center)
	menu_card=PanelContainer.new();center.add_child(menu_card)
	menu_card.add_theme_stylebox_override("panel",InterfaceTheme.panel(10))
	var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",0);menu_card.add_child(columns)
	menu_cover=PanelContainer.new();menu_cover.custom_minimum_size.x=230;columns.add_child(menu_cover)
	var nav_style:=StyleBoxFlat.new();nav_style.bg_color=Color("0d1925");nav_style.border_color=Color("4f483a");nav_style.border_width_right=1;nav_style.content_margin_left=18;nav_style.content_margin_right=18;nav_style.content_margin_top=22;nav_style.content_margin_bottom=16
	menu_cover.add_theme_stylebox_override("panel",nav_style)
	var nav_scroll:=ScrollContainer.new();nav_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;menu_cover.add_child(nav_scroll)
	sidebar=VBoxContainer.new();sidebar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sidebar.size_flags_vertical=Control.SIZE_EXPAND_FILL;sidebar.add_theme_constant_override("separation",6);nav_scroll.add_child(sidebar)
	var brand:=add_label(sidebar,"FOUNDERS OF\nHISTORY",23,Color("f5dfab"));brand.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var spacer:=Control.new();spacer.custom_minimum_size.y=8;sidebar.add_child(spacer)
	continue_button=add_button(sidebar,"▶  Jätka mängu",close_menu,true)
	add_nav("new","Uus mäng")
	add_nav("saves","Salvestused")
	add_nav("options","Seaded")
	add_nav("extras","Mäng ja uuendused")
	var nav_space:=Control.new();nav_space.size_flags_vertical=Control.SIZE_EXPAND_FILL;sidebar.add_child(nav_space)
	add_button(sidebar,"⏻  Sulge mäng",func():get_tree().quit())
	var scroll:=ScrollContainer.new();menu_scroll=scroll;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;columns.add_child(scroll)
	var frame:=PanelContainer.new();menu_frame=frame;frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var panel:=StyleBoxFlat.new();panel.bg_color=Color(0.02,0.06,0.10,0.1)
	panel.content_margin_left=18;panel.content_margin_right=28;panel.content_margin_top=24;panel.content_margin_bottom=20
	frame.add_theme_stylebox_override("panel",panel);scroll.add_child(frame)
	var content:=VBoxContainer.new();content.add_theme_constant_override("separation",10);frame.add_child(content)
	var version:=add_label(content,BuildLabel.detailed_text(get_tree()),12,Color("d5bf90"));version.name="GameVersion"
	page_title=add_label(content,"",25,Color("f7e5bc"))
	menu_status=add_label(content,"",12,Color("bfc9b8"));menu_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var updates: Node=get_node_or_null("/root/GameUpdates")
	world_body=VBoxContainer.new();world_body.add_theme_constant_override("separation",6);content.add_child(world_body);pages["new"]=world_body
	add_label(world_body,"Maailma tüüp",13,Color("d9e4d8"))
	world_type=OptionButton.new();world_type.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for entry in [["Loogiline maailm: laamad ja kliima","tectonic"],["Juhuslikud 2–4 kontinenti","continents"],["Suur manner rannikutega","inland"]]:
		world_type.add_item(entry[0]);world_type.set_item_metadata(world_type.item_count-1,entry[1])
	world_body.add_child(world_type)
	add_label(world_body,"Raskus",13,Color("d9e4d8"))
	difficulty=OptionButton.new();difficulty.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for entry in [["Lihtne","easy"],["Tavaline","normal"],["Raske","hard"]]:
		difficulty.add_item(entry[0]);difficulty.set_item_metadata(difficulty.item_count-1,entry[1])
	difficulty.select(1);world_body.add_child(difficulty)
	add_label(world_body,"Mängu tempo",13,Color("d9e4d8"))
	tempo=OptionButton.new();tempo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for i in host.tempo_select.item_count:
		tempo.add_item(host.tempo_select.get_item_text(i));tempo.set_item_metadata(i,host.tempo_select.get_item_metadata(i))
	tempo.select(host.tempo_select.selected);world_body.add_child(tempo)
	add_label(world_body,"Maailma seeme (soovi korral)",13,Color("d9e4d8"))
	seed=LineEdit.new();seed.placeholder_text="Jäta tühjaks juhusliku maailma jaoks";seed.max_length=40;world_body.add_child(seed)
	var note:=add_label(world_body,"Alustad asuniku ja kolme töölisega. Eelmisest salvestusest tehakse võimalusel varukoopia.",12,Color("adbfaf"));note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_button(world_body,"Loo maailm",start_new,true)
	var extras:=VBoxContainer.new();extras.add_theme_constant_override("separation",8);content.add_child(extras);pages["extras"]=extras
	var extras_note:=add_label(extras,"Kaardi nähtavus, mängu juhtpaneel ja uuendused.",13,Color("adbfaf"));extras_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var utilities:=VBoxContainer.new();utilities.add_theme_constant_override("separation",7);extras.add_child(utilities)
	reveal_button=add_button(utilities,"",toggle_reveal);reveal_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var controls:=add_button(utilities,"⚙ Mängu juhtpaneel",open_controls);controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	options_body=VBoxContainer.new();options_body.add_theme_constant_override("separation",6);content.add_child(options_body);pages["options"]=options_body
	add_label(options_body,"Kasutajaliidese suurus",13,Color("d9e4d8"))
	scale_select=OptionButton.new();scale_select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for percent in [70,80,90,100,110,125,150]:
		scale_select.add_item(str(percent)+"%");scale_select.set_item_metadata(scale_select.item_count-1,percent)
		if absf(float(percent)/100.0-hud.user_ui_scale)<0.001:scale_select.select(scale_select.item_count-1)
	scale_select.item_selected.connect(change_ui_scale);options_body.add_child(scale_select)
	add_graphics_option("display","Kuvarežiim",[["Aken","windowed"],["Täisekraan","fullscreen"],["Ääristeta täisekraan","borderless"]])
	add_graphics_option("resolution","Resolutsiooniskaala",[["50%",50],["70%",70],["75%",75],["85%",85],["100%",100],["125%",125],["150%",150]])
	add_graphics_option("antialias","Servade silumine",[["Väljas",0],["MSAA 2×",2],["MSAA 4×",4]])
	add_graphics_option("fps","FPS piirang",[["30 FPS",30],["60 FPS",60],["120 FPS",120],["Piiramata",0]])
	add_graphics_option("shadows","Varjud",[["Sees",true],["Väljas",false]])
	add_graphics_option("names","Sõdurite nimed",[["Sees",true],["Väljas",false]])
	add_graphics_option("daylight","Päevaaeg",[["24 h tsükkel","dynamic"],["Keskpäev","day"],["Õhtu","evening"],["Öö","night"]])
	add_graphics_option("ambient","Üldvalguse heledus",[["Tumedam","low"],["Tavaline","normal"],["Heledam","bright"]])
	add_graphics_option("performance","Jõudlusnäidik",[["Väljas",false],["Sees",true]])
	create_performance_overlay()
	load_graphics_settings()
	saves_body=VBoxContainer.new();saves_body.add_theme_constant_override("separation",6);content.add_child(saves_body);pages["saves"]=saves_body
	add_button(saves_body,"Salvesta mäng",save_game)
	add_button(saves_body,"Laadi automaatsalvestus",load_game)
	slots=VBoxContainer.new();saves_body.add_child(slots)
	add_button(saves_body,"↓ Ekspordi Godoti salvestus (.json)",func():export_dialog.popup_centered_ratio(0.8))
	add_button(saves_body,"↑ Impordi veebi või Godoti salvestus (.json)",func():import_dialog.popup_centered_ratio(0.8))
	export_dialog=FileDialog.new();export_dialog.access=FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE;export_dialog.add_filter("*.json ; JSON-fail")
	export_dialog.current_file="Kuningriigid_Godot.json";export_dialog.file_selected.connect(export_game);add_child(export_dialog)
	import_dialog=FileDialog.new();import_dialog.access=FileDialog.ACCESS_FILESYSTEM
	import_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;import_dialog.add_filter("*.json ; JSON-fail")
	import_dialog.file_selected.connect(import_game);add_child(import_dialog)
	if updates!=null:add_update_controls(extras,updates)
	var footer:=add_label(content,"60 mängusekundit = 1 käik. Menüü ja pausi ajal mäng seisab.",11,Color("aabeb1"));footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	menu_card.theme=InterfaceTheme.get_theme()
	show_page("new")
	get_viewport().size_changed.connect(layout_menu)
	layout_menu()

func add_update_controls(parent: VBoxContainer,updates: Node) -> void:
	add_button(parent,"Kontrolli uuendusi",updates.check)
	update_label=add_label(parent,BuildLabel.update_text(updates),12,Color("d9e4d8"))
	update_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	updates.status_changed.connect(func(_value):update_label.text=BuildLabel.update_text(updates))

func layout_menu() -> void:
	var viewport:=get_viewport_rect().size
	var width:=maxf(240.0,minf(1060.0,viewport.x-32.0));var height:=maxf(180.0,viewport.y-48.0)
	menu_card.custom_minimum_size=Vector2(width,height);menu_card.size=menu_card.custom_minimum_size
	menu_cover.custom_minimum_size.x=clampf(width*0.28,150.0,230.0)
	menu_scroll.custom_minimum_size=Vector2.ZERO
	menu_frame.custom_minimum_size.x=maxf(160.0,width-menu_cover.custom_minimum_size.x-30.0)

func add_nav(key: String, caption: String) -> void:
	var button:=add_button(sidebar,caption,show_page.bind(key))
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	var selected:=StyleBoxFlat.new();selected.bg_color=Color("34443c");selected.border_color=Color("d5b475");selected.set_border_width_all(1);selected.set_corner_radius_all(3)
	selected.content_margin_left=12;selected.content_margin_right=12;selected.content_margin_top=8;selected.content_margin_bottom=8
	button.add_theme_stylebox_override("disabled",selected);button.add_theme_color_override("font_disabled_color",Color("f7e5bc"))
	nav_buttons[key]=button

func show_page(key: String) -> void:
	for page in pages:pages[page].visible=page==key
	for page in nav_buttons:nav_buttons[page].disabled=page==key
	var titles={"new":"Uus mäng","saves":"Salvestused","options":"Seaded","extras":"Mäng ja uuendused"}
	page_title.text=titles.get(key,"")
	if menu_scroll!=null:menu_scroll.scroll_vertical=0

func add_label(parent: Node,text: String,font_size: int,color: Color) -> Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color);parent.add_child(label);return label

func add_button(parent: Node,text: String,action: Callable,primary:=false) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=45;button.pressed.connect(action);parent.add_child(button)
	if primary:
		var gold:=StyleBoxFlat.new();gold.bg_color=Color("d7b571");gold.border_color=Color("f7df9c");gold.set_border_width_all(1);gold.set_corner_radius_all(3)
		for state in ["normal","hover","pressed"]:button.add_theme_stylebox_override(state,gold)
		button.add_theme_color_override("font_color",Color("21180c"));button.add_theme_color_override("font_hover_color",Color("21180c"))
	return button

func add_section(parent: Node,text: String,action: Callable) -> Button:
	var button:=add_button(parent,text,action);button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	var box:=StyleBoxFlat.new();box.bg_color=Color(0,0,0,0);box.border_color=Color(0.67,0.52,0.29,0.42);box.border_width_top=1
	box.content_margin_left=0;box.content_margin_right=0;box.content_margin_top=10;box.content_margin_bottom=10
	for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,box)
	return button

func open_menu() -> void:
	seed.text=host.seed_input.text;tempo.select(host.tempo_select.selected)
	for i in world_type.item_count:
		if world_type.get_item_metadata(i)==host.game.get("type","tectonic"):world_type.select(i);break
	for i in difficulty.item_count:
		if difficulty.get_item_metadata(i)==host.game.get("difficulty","normal"):difficulty.select(i);break
	menu_status.text="Praegune maailm · seeme "+str(host.game.get("seed",""))
	update_reveal();refresh_slots();show_page("new");hud.legacy_panel.visible=false;visible=true;host.menu_open=true

func _process(_delta: float) -> void:
	if performance_label!=null and performance_label.visible:
		performance_clock+=_delta
		if performance_clock>=1.0:
			performance_clock=0.0
			performance_label.text="FPS %d · joonistusi %d · kolmnurki %d" % [Engine.get_frames_per_second(),int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))]
	if not visible:return
	var loading: bool=host.generation_thread!=null
	continue_button.disabled=loading
	if loading:menu_status.text="Salvestatud maailma laadimine käib…" if not host.pending_load.is_empty() else "Maailma loomine käib…"
	elif was_loading:menu_status.text="Praegune maailm · seeme "+str(host.game.get("seed",""));seed.text=host.seed_input.text
	was_loading=loading

func close_menu() -> void:
	visible=false;host.menu_open=false

func toggle_reveal() -> void:
	host.toggle_fog();update_reveal()

func update_reveal() -> void:
	reveal_button.text="🗺 Kogu kaart: "+("sees" if host.reveal_all else "väljas")

func start_new() -> void:
	if host.generation_thread!=null:menu_status.text="Oota, kuni maailma laadimine lõpeb.";return
	host.seed_input.text=seed.text;host.tempo_select.select(tempo.selected)
	host.pending_difficulty=str(difficulty.get_item_metadata(difficulty.selected))
	host.pending_world_type=str(world_type.get_item_metadata(world_type.selected))
	close_menu();host.start_generation()

func save_game() -> void:
	menu_status.text="Mäng salvestatud." if host.save_partial() else "Salvestamine ebaõnnestus."

func load_game() -> void:
	close_menu();host.load_partial()

func change_ui_scale(index: int) -> void:
	hud.set_user_ui_scale(float(scale_select.get_item_metadata(index))/100.0)

func add_graphics_option(key: String,label_text: String,choices: Array) -> void:
	add_label(options_body,label_text,13,Color("d9e4d8"))
	var option:=OptionButton.new();option.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for choice in choices:
		option.add_item(choice[0]);option.set_item_metadata(option.item_count-1,choice[1])
	option.item_selected.connect(func(_index):apply_graphics_settings(true))
	options_body.add_child(option);graphics_controls[key]=option

func load_graphics_settings() -> void:
	var config:=ConfigFile.new();config.load(SETTINGS_PATH)
	var defaults={"display":"windowed","resolution":70 if Mobile.active else 100,"antialias":0,"fps":60,"shadows":true,"names":not Mobile.active,"daylight":"dynamic","ambient":"normal","performance":false}
	for key in defaults:
		var option:OptionButton=graphics_controls[key];var value:Variant=config.get_value("mobile_graphics" if Mobile.active else "graphics",key,defaults[key]);var found:=false
		for i in option.item_count:
			if option.get_item_metadata(i)==value:option.select(i);found=true;break
		if not found:
			for i in option.item_count:
				if option.get_item_metadata(i)==defaults[key]:option.select(i);break
	apply_graphics_settings(false)

func apply_graphics_settings(save: bool) -> void:
	var selected={}
	for key in graphics_controls:
		var option:OptionButton=graphics_controls[key];selected[key]=option.get_item_metadata(option.selected)
	Engine.max_fps=int(selected.fps);host.graphics_shadows=bool(selected.shadows);host.graphics_soldier_names=bool(selected.names)
	get_viewport().scaling_3d_scale=float(selected.resolution)/100.0
	get_viewport().msaa_3d=Viewport.MSAA_4X if int(selected.antialias)==4 else Viewport.MSAA_2X if int(selected.antialias)==2 else Viewport.MSAA_DISABLED
	var mode:=DisplayServer.WINDOW_MODE_WINDOWED
	if selected.display=="fullscreen":mode=DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	elif selected.display=="borderless":mode=DisplayServer.WINDOW_MODE_FULLSCREEN
	if not Mobile.active and DisplayServer.window_get_mode()!=mode:DisplayServer.window_set_mode(mode)
	host.graphics_daylight=str(selected.daylight);host.graphics_ambient=str(selected.ambient);host.update_daylight()
	if performance_label!=null:performance_label.visible=bool(selected.performance)
	if save:
		var config:=ConfigFile.new();config.load(SETTINGS_PATH)
		for key in selected:config.set_value("mobile_graphics" if Mobile.active else "graphics",key,selected[key])
		config.save(SETTINGS_PATH)

func set_graphics_value(key: String,value: Variant) -> void:
	if not graphics_controls.has(key):return
	var option:OptionButton=graphics_controls[key]
	for i in option.item_count:
		if option.get_item_metadata(i)==value:option.select(i);apply_graphics_settings(true);return

func slot_path(index: int) -> String:
	return "user://kuningriigid_godot_slot_%d.json" % index

func refresh_slots() -> void:
	for child in slots.get_children():slots.remove_child(child);child.queue_free()
	for index in range(1,4):
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",6);slots.add_child(row)
		var path:=slot_path(index);var data: Variant=host.read_partial_json(path) if FileAccess.file_exists(path) else null
		var valid: bool=host.valid_partial_save(data)
		var caption: String="%d. %s" % [index,"Käik %d" % (floori(float(data.game.time)/60.0)+1) if valid else "Vigane" if data!=null else "Tühi"]
		var label:=add_label(row,caption,13,Color("dde6dc"));label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		add_button(row,"Salvesta",save_slot.bind(index))
		var load_button:=add_button(row,"Laadi",load_slot.bind(index));load_button.disabled=not valid

func save_slot(index: int) -> void:
	if host.save_partial(false,slot_path(index)):menu_status.text="Salvestatud kohta %d." % index
	else:menu_status.text="Salvestamine ebaõnnestus."
	refresh_slots()

func load_slot(index: int) -> void:
	close_menu();host.load_partial(slot_path(index))

func export_game(path: String) -> void:
	menu_status.text="Salvestus eksporditud." if host.save_partial(false,path) else "Eksport ebaõnnestus."

func import_game(path: String) -> void:
	var data: Variant=host.normalize_saved_game(host.read_partial_json(path))
	if not host.valid_partial_save(data):
		menu_status.text="Salvestus ei sobi, kaasatud maailm puudub või lahing on pooleli.";return
	close_menu();host.load_partial(path)

func open_controls() -> void:
	close_menu();hud.legacy_panel.visible=true

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		close_menu();get_viewport().set_input_as_handled()

func create_performance_overlay() -> void:
	performance_layer=CanvasLayer.new();performance_layer.layer=30;host.add_child(performance_layer)
	performance_label=Label.new();performance_label.text="FPS --";performance_label.visible=false;performance_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	performance_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT);performance_label.position=Vector2(8,-110)
	performance_label.add_theme_font_size_override("font_size",14);performance_label.add_theme_color_override("font_color",Color("d7efdd"))
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.03,0.11,0.09,0.88);style.content_margin_left=8;style.content_margin_right=8;style.content_margin_top=5;style.content_margin_bottom=5;style.set_corner_radius_all(5)
	performance_label.add_theme_stylebox_override("normal",style);performance_layer.add_child(performance_label)
