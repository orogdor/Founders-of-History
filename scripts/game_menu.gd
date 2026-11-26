extends Control

const InterfaceTheme = preload("res://scripts/interface_theme.gd")
const MenuArt = preload("res://scripts/main_menu_art.gd")
const Mobile = preload("res://scripts/mobile_profile.gd")
const BuildLabel = preload("res://scripts/build_label.gd")
const WorldSetup = preload("res://scripts/world_setup.gd")
const MAP_DESCRIPTIONS := {
	"tectonic": "Laamad kujundavad mandrid, mäeahelikud ja kliimavööndid.",
	"continents": "Kaks kuni neli suuremat mandrit ja väiksemad saared.",
	"inland": "Üks suur manner. Maismaal on rohkem ruumi laienemiseks.",
	"archipelago": "Palju eraldi saari. Meresõit ühendab riike.",
}

var host: Node
var hud: Control
var seed: LineEdit
var tempo: OptionButton
var difficulty: OptionButton
var world_type:OptionButton
var world_size: OptionButton
var opponents: OptionButton
var world_fields: GridContainer
var faction_fields: GridContainer
var color_fields: Array[OptionButton] = []
var color_cells: Array[VBoxContainer] = []
var map_description: Label
var new_game_button: Button
var creating_world := false
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
var home: Control
var home_title: VBoxContainer
var home_dock: HBoxContainer
var home_continue: Button
var home_cards: Array[Button] = []
var home_footer: HBoxContainer
var title_top: Label
var title_bottom: Label
var home_status: Label
var back_compact: Button
var current_page := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP;visible=false
	theme=InterfaceTheme.get_theme()
	MenuArt.cover(self, MenuArt.BACKGROUND, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	var shade := MenuArt.vignette()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	build_home()
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(center)
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu_card=PanelContainer.new();center.add_child(menu_card)
	menu_card.add_theme_stylebox_override("panel",MenuArt.panel(36))
	var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",0);menu_card.add_child(columns)
	menu_cover=PanelContainer.new();menu_cover.custom_minimum_size.x=230;columns.add_child(menu_cover)
	var nav_style:=StyleBoxFlat.new();nav_style.bg_color=Color("0a1420bb");nav_style.border_color=Color("9d784b7a");nav_style.border_width_right=1;nav_style.content_margin_left=12;nav_style.content_margin_right=12;nav_style.content_margin_top=10;nav_style.content_margin_bottom=10
	menu_cover.add_theme_stylebox_override("panel",nav_style)
	var nav_scroll:=ScrollContainer.new();nav_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;menu_cover.add_child(nav_scroll)
	sidebar=VBoxContainer.new();sidebar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sidebar.size_flags_vertical=Control.SIZE_EXPAND_FILL;sidebar.add_theme_constant_override("separation",6);nav_scroll.add_child(sidebar)
	var back := add_button(sidebar,"‹  Peamenüü",show_page.bind(""))
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	var panel:=StyleBoxFlat.new();panel.bg_color=Color("101d2bba")
	panel.content_margin_left=14;panel.content_margin_right=14;panel.content_margin_top=12;panel.content_margin_bottom=16
	frame.add_theme_stylebox_override("panel",panel);scroll.add_child(frame)
	var content:=VBoxContainer.new();content.add_theme_constant_override("separation",10);frame.add_child(content)
	back_compact=add_button(content,"‹  Peamenüü",show_page.bind(""))
	back_compact.alignment=HORIZONTAL_ALIGNMENT_LEFT
	var version:=add_label(content,BuildLabel.detailed_text(get_tree()),12,Color("d5bf90"));version.name="GameVersion"
	page_title=add_label(content,"",25,Color("f7e5bc"))
	menu_status=add_label(content,"",12,Color("bfc9b8"));menu_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var updates: Node=get_node_or_null("/root/GameUpdates")
	world_body=VBoxContainer.new();world_body.add_theme_constant_override("separation",6);content.add_child(world_body);pages["new"]=world_body
	build_world_setup()
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
	if not Mobile.active:add_graphics_option("display","Kuvarežiim",[["Aken","windowed"],["Täisekraan","fullscreen"],["Ääristeta täisekraan","borderless"]])
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
	show_page("")
	get_viewport().size_changed.connect(layout_menu)
	layout_menu()

func build_world_setup() -> void:
	add_setup_heading("Maailm", preload("res://assets/ui/ui-art-v263_cmd_map.webp"))
	world_fields = add_field_grid()
	world_type = add_choice(world_fields, "Maailma stiil", [
		["Laamad ja kliimavööndid", "tectonic"], ["Mandrid", "continents"],
		["Suur manner", "inland"], ["Saarestik", "archipelago"],
	])
	var sizes := []
	for entry in [["Väike", "small"], ["Tavaline", "standard"], ["Suur", "large"]]:
		var dimensions: Vector2i = WorldSetup.SIZES[entry[1]]
		sizes.append(["%s · %d × %d" % [entry[0], dimensions.x, dimensions.y], entry[1]])
	world_size = add_choice(world_fields, "Kaardi suurus", sizes)
	map_description = add_label(world_body, "", 12, Color("c5bda7"))
	map_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_type.item_selected.connect(func(_index): refresh_world_setup())
	world_size.item_selected.connect(func(_index): refresh_world_setup())

	add_setup_heading("Riigid", preload("res://assets/ui/ui-art-v263_cmd_army.webp"))
	faction_fields = add_field_grid()
	var rival_options := [["Vastasteta", 0], ["1 vastane", 1], ["2 vastast", 2], ["3 vastast", 3]]
	opponents = add_choice(faction_fields, "Arvutivastased", rival_options)
	opponents.item_selected.connect(func(_index): refresh_world_setup())
	var swatches: Dictionary = {}
	for hex in WorldSetup.PALETTE:
		var image := Image.create(22, 22, false, Image.FORMAT_RGBA8)
		image.fill(Color("c7a568"))
		image.fill_rect(Rect2i(1, 1, 20, 20), Color(hex))
		swatches[hex] = ImageTexture.create_from_image(image)
	for team in WorldSetup.MAX_OPPONENTS + 1:
		var title := "Sinu värv" if team == 0 else "Vastase %d värv" % team
		var selector := add_choice(faction_fields, title, [])
		color_cells.append(selector.get_parent())
		color_fields.append(selector)
		for hex in WorldSetup.PALETTE:
			selector.add_icon_item(swatches[hex], WorldSetup.PALETTE[hex])
			selector.set_item_metadata(selector.item_count - 1, hex)
		selector.item_selected.connect(func(_index): refresh_world_setup())

	add_setup_heading("Mängureeglid", preload("res://assets/ui/ui-art-v263_cmd_research.webp"))
	var rules := add_field_grid()
	rules.name = "RuleFields"
	difficulty = add_choice(rules, "Raskus", [["Lihtne", "easy"], ["Tavaline", "normal"], ["Raske", "hard"]])
	var tempos := []
	for i in host.tempo_select.item_count:
		tempos.append([host.tempo_select.get_item_text(i), host.tempo_select.get_item_metadata(i)])
	tempo = add_choice(rules, "Mängu tempo", tempos)
	add_label(world_body, "Maailma seeme (valikuline)", 13, Color("d9e4d8"))
	seed = LineEdit.new()
	seed.placeholder_text = "Tühi väli annab juhusliku maailma"
	seed.max_length = 40
	seed.custom_minimum_size.y = 32
	world_body.add_child(seed)
	new_game_button = add_button(world_body, "Loo maailm", start_new, true)
	use_campaign_setup(host.game)

func add_setup_heading(caption: String, icon: Texture2D) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	world_body.add_child(row)
	var badge := MenuArt.picture(icon, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	badge.custom_minimum_size = Vector2(26, 26)
	row.add_child(badge)
	add_label(row, caption, 18, MenuArt.GOLD)

func add_field_grid() -> GridContainer:
	var fields := GridContainer.new()
	fields.columns = 2
	fields.add_theme_constant_override("h_separation", 14)
	fields.add_theme_constant_override("v_separation", 7)
	world_body.add_child(fields)
	return fields

func add_choice(parent: Container, caption: String, entries: Array) -> OptionButton:
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 3)
	parent.add_child(field)
	add_label(field, caption, 13, Color("d9e4d8"))
	var option := OptionButton.new()
	option.custom_minimum_size.y = 32
	option.fit_to_longest_item = false
	option.clip_text = true
	option.accessibility_name = caption
	for entry in entries:
		option.add_item(entry[0])
		option.set_item_metadata(option.item_count - 1, entry[1])
	field.add_child(option)
	return option

func use_campaign_setup(state: Dictionary) -> void:
	choose_value(world_type, state.get("type", "tectonic"))
	choose_value(world_size, WorldSetup.size_id(state))
	choose_value(opponents, WorldSetup.opponent_count(state))
	choose_value(difficulty, state.get("difficulty", "normal"))
	choose_value(tempo, state.get("tempo", "normal"))
	var colors := WorldSetup.colors(state)
	for team in color_fields.size():
		choose_value(color_fields[team], colors[team])
	refresh_world_setup()

static func choose_value(option: OptionButton, value: Variant) -> void:
	for index in option.item_count:
		if option.get_item_metadata(index) == value:
			option.select(index)
			return

func refresh_world_setup() -> void:
	var count := int(opponents.get_selected_metadata())
	var width := get_viewport_rect().size.x
	faction_fields.columns = 1 if width < 440.0 else 3 if width >= 1000.0 and count == WorldSetup.MAX_OPPONENTS else 2
	var colors := selected_colors()
	for team in color_fields.size():
		choose_value(color_fields[team], colors[team])
		color_cells[team].visible = team <= count
		for index in color_fields[team].item_count:
			var color: Variant = color_fields[team].get_item_metadata(index)
			color_fields[team].set_item_disabled(index, color != colors[team] and color in colors.slice(0,count+1))
	map_description.text = MAP_DESCRIPTIONS.get(world_type.get_selected_metadata(), "")

func selected_colors() -> Array[String]:
	var selections: Array[String] = []
	for field in color_fields:
		selections.append(str(field.get_selected_metadata()))
	return WorldSetup.colors({"factionColors": selections})

func build_home() -> void:
	home=Control.new()
	home.mouse_filter=Control.MOUSE_FILTER_IGNORE
	home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(home)

	home_title=VBoxContainer.new()
	home_title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	home_title.add_theme_constant_override("separation", -4)
	home.add_child(home_title)
	title_top=add_label(home_title,"F O U N D E R S   O F",25,MenuArt.GOLD)
	title_top.accessibility_name="Founders of"
	title_bottom=add_label(home_title,"HISTORY",82,Color("fff0c7"))
	var display_font := SystemFont.new()
	display_font.font_names=PackedStringArray(["Georgia","Noto Serif","DejaVu Serif"])
	display_font.font_weight=700
	for letter in [title_top,title_bottom]:
		letter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		letter.add_theme_font_override("font",display_font)
		letter.add_theme_color_override("font_shadow_color",Color("070a14bd"))
		letter.add_theme_constant_override("shadow_offset_x",0)
		letter.add_theme_constant_override("shadow_offset_y",3)
	var title_rule := MenuArt.rule()
	home_title.add_child(title_rule)
	home_title.add_theme_constant_override("separation",2)

	var rail := MenuArt.picture(MenuArt.DIVIDER)
	rail.name="DockRail"
	home.add_child(rail)
	home_dock=HBoxContainer.new()
	home_dock.mouse_filter=Control.MOUSE_FILTER_IGNORE
	home_dock.add_theme_constant_override("separation",14)
	home.add_child(home_dock)
	var artwork := [
		["Jätka mängu", preload("res://assets/ui/ui-art-v306_kingdom_portrait.webp"), Rect2(0,0,512,512), close_menu],
		["Uus mäng", preload("res://assets/ui/ui-art-v306_card_build.webp"), Rect2(32,43,383,398), show_page.bind("new")],
		["Salvestused", preload("res://assets/ui/ui-art-v306_card_journal.webp"), Rect2(32,43,383,398), show_page.bind("saves")],
		["Seaded", preload("res://assets/ui/ui-art-v306_card_diplomacy.webp"), Rect2(35,132,379,310), show_page.bind("options")],
	]
	for entry in artwork:
		var button := MenuArt.card(entry[0],entry[1],entry[2],entry[3])
		home_dock.add_child(button)
		home_cards.append(button)
	home_continue=home_cards[0]

	home_status=add_label(home,"",14,MenuArt.GOLD)
	home_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	home_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	home_status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	home_status.add_theme_color_override("font_outline_color",Color("101820"))
	home_status.add_theme_constant_override("outline_size",6)

	home_footer=HBoxContainer.new()
	home_footer.alignment=BoxContainer.ALIGNMENT_CENTER
	home_footer.add_theme_constant_override("separation",12)
	home.add_child(home_footer)
	add_button(home_footer,"Mäng ja uuendused",show_page.bind("extras"))
	add_button(home_footer,"Sulge mäng",func():get_tree().quit())

func layout_home(viewport: Vector2) -> void:
	var gap := 10 if viewport.x < 650.0 else 16
	var card_width := minf(145.0,minf((viewport.x-32.0-gap*3)/4.0,viewport.y*0.21))
	card_width = maxf(42.0,card_width)
	var card_height := roundf(card_width*1.5)
	home_dock.add_theme_constant_override("separation",gap)
	for button in home_cards:
		button.custom_minimum_size=Vector2(card_width,card_height)
		var caption: Label=button.get_meta("caption")
		caption.add_theme_font_size_override("font_size",clampi(int(card_width*0.13),9,19))
	var dock_width := card_width*4.0 + gap*3.0
	var dock_bottom := viewport.y - clampf(viewport.y*0.127,63.0,94.0)
	home_dock.size=Vector2(dock_width,card_height)
	home_dock.position=Vector2(roundf((viewport.x-dock_width)*0.5),roundf(dock_bottom-card_height))
	home_status.size=Vector2(minf(viewport.x-24.0,600.0),36.0)
	home_status.position=Vector2((viewport.x-home_status.size.x)*0.5,home_dock.position.y-42.0)
	var rail: TextureRect=home.get_node("DockRail")
	var rail_width := minf(viewport.x,maxf(dock_width+116.0,viewport.x*0.73))
	rail.size=Vector2(rail_width,clampf(viewport.y*0.035,16.0,30.0))
	rail.position=Vector2((viewport.x-rail_width)*0.5,dock_bottom-rail.size.y*0.62)
	home_footer.size=Vector2(viewport.x,45.0)
	home_footer.position=Vector2(0,dock_bottom+12.0)
	title_top.add_theme_font_size_override("font_size",clampi(roundi(viewport.y*0.035),14,29))
	title_bottom.add_theme_font_size_override("font_size",clampi(roundi(minf(viewport.x*0.115,viewport.y*0.118)),32,90))
	home_title.size=Vector2(viewport.x,0)
	home_title.position=Vector2(0,clampf(viewport.y*0.095,18.0,86.0))

func add_update_controls(parent: VBoxContainer,updates: Node) -> void:
	add_button(parent,"Kontrolli uuendusi",updates.check)
	update_label=add_label(parent,BuildLabel.update_text(updates),12,Color("d9e4d8"))
	update_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	updates.status_changed.connect(func(_value):update_label.text=BuildLabel.update_text(updates))

func layout_menu() -> void:
	var viewport:=get_viewport_rect().size
	layout_home(viewport)
	var width:=maxf(240.0,minf(920.0,viewport.x-32.0));var height:=maxf(180.0,minf(660.0,viewport.y-36.0))
	menu_card.custom_minimum_size=Vector2(width,height);menu_card.size=menu_card.custom_minimum_size
	var compact := viewport.x < 640.0
	menu_cover.visible=not compact
	back_compact.visible=compact
	for fields: GridContainer in [world_fields, world_body.get_node("RuleFields")]:
		fields.columns=1 if viewport.x<440.0 else 2
	refresh_world_setup()
	var frame_style: StyleBox = menu_card.get_theme_stylebox("panel")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		frame_style.set_content_margin(side,16.0 if compact else 36.0)
	menu_cover.custom_minimum_size.x=clampf(width*0.28,132.0,208.0)
	menu_scroll.custom_minimum_size=Vector2.ZERO
	menu_frame.custom_minimum_size.x=0

func add_nav(key: String, caption: String) -> void:
	var button:=add_button(sidebar,caption,show_page.bind(key))
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	var selected:=StyleBoxFlat.new();selected.bg_color=Color("34443c");selected.border_color=Color("d5b475");selected.set_border_width_all(1);selected.set_corner_radius_all(3)
	selected.content_margin_left=12;selected.content_margin_right=12;selected.content_margin_top=8;selected.content_margin_bottom=8
	button.add_theme_stylebox_override("disabled",selected);button.add_theme_color_override("font_disabled_color",Color("f7e5bc"))
	nav_buttons[key]=button

func show_page(key: String) -> void:
	current_page=key
	home.visible=key.is_empty()
	menu_card.visible=not key.is_empty()
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
	seed.text=host.seed_input.text
	use_campaign_setup(host.game)
	menu_status.text="Praegune maailm · seeme "+str(host.game.get("seed",""))
	update_reveal();refresh_slots();show_page("");hud.legacy_panel.visible=false;visible=true;host.menu_open=true
	performance_layer.hide()

func _process(_delta: float) -> void:
	if performance_label!=null and performance_label.visible:
		performance_clock+=_delta
		if performance_clock>=1.0:
			performance_clock=0.0
			performance_label.text="FPS %d · joonistusi %d · kolmnurki %d" % [Engine.get_frames_per_second(),int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))]
	if not visible:return
	var loading: bool=host.generation_thread!=null
	continue_button.disabled=loading
	new_game_button.disabled=loading
	if home_continue.disabled!=loading:
		home_continue.disabled=loading
		var refresh: Callable=home_continue.get_meta("refresh")
		refresh.call()
	if loading:menu_status.text="Salvestatud maailma laadimine käib…" if not host.pending_load.is_empty() else "Maailma loomine käib…"
	elif was_loading and not creating_world and not menu_status.has_meta("generation_error"):
		menu_status.text="Praegune maailm · seeme "+str(host.game.get("seed",""))
		seed.text=host.seed_input.text
		use_campaign_setup(host.game)
	home_status.text=menu_status.text if loading or host.autosave_suspended else ""
	was_loading=loading

func close_menu() -> void:
	visible=false;host.menu_open=false
	performance_layer.show()

func toggle_reveal() -> void:
	host.toggle_fog();update_reveal()

func update_reveal() -> void:
	reveal_button.text="🗺 Kogu kaart: "+("sees" if host.reveal_all else "väljas")

func start_new() -> void:
	if host.generation_thread!=null:menu_status.text="Oota, kuni maailma laadimine lõpeb.";return
	if menu_status.has_meta("generation_error"):
		menu_status.remove_meta("generation_error")
	creating_world=true
	host.seed_input.text=seed.text;host.tempo_select.select(tempo.selected)
	host.pending_difficulty=str(difficulty.get_item_metadata(difficulty.selected))
	host.pending_world_type=str(world_type.get_item_metadata(world_type.selected))
	host.pending_world_settings={
		"worldSize": world_size.get_selected_metadata(),
		"opponentCount": opponents.get_selected_metadata(),
		"factionColors": selected_colors(),
	}
	host.start_generation()

func finish_new_game(error: String) -> void:
	if not creating_world:
		return
	creating_world=false
	if error.is_empty():
		close_menu()
		return
	menu_status.set_meta("generation_error",true)
	menu_status.text=error
	show_page("new")

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
	for key in graphics_controls:
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
	if selected.get("display","windowed")=="fullscreen":mode=DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	elif selected.get("display","windowed")=="borderless":mode=DisplayServer.WINDOW_MODE_FULLSCREEN
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
		if not current_page.is_empty():show_page("")
		elif not continue_button.disabled:close_menu()
		get_viewport().set_input_as_handled()

func create_performance_overlay() -> void:
	performance_layer=CanvasLayer.new();performance_layer.layer=30;host.add_child(performance_layer)
	performance_label=Label.new();performance_label.text="FPS --";performance_label.visible=false;performance_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	performance_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT);performance_label.position=Vector2(8,-110)
	performance_label.add_theme_font_size_override("font_size",14);performance_label.add_theme_color_override("font_color",Color("d7efdd"))
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.03,0.11,0.09,0.88);style.content_margin_left=8;style.content_margin_right=8;style.content_margin_top=5;style.content_margin_bottom=5;style.set_corner_radius_all(5)
	performance_label.add_theme_stylebox_override("normal",style);performance_layer.add_child(performance_label)
