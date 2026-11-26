extends Control

const Art = preload("res://scripts/main_menu_art.gd")
const ThemeArt = preload("res://scripts/interface_theme.gd")
var heading: Label
var stage_label: Label
var progress: ProgressBar

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	theme=ThemeArt.get_theme()
	Art.cover(self,Art.BACKGROUND,TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	var shade:=Art.vignette()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel:=PanelContainer.new()
	panel.custom_minimum_size.x=minf(480.0,get_viewport_rect().size.x*0.88)
	panel.add_theme_stylebox_override("panel",Art.panel(26))
	center.add_child(panel)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	panel.add_child(column)
	heading=Label.new()
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color",Art.GOLD)
	heading.add_theme_font_size_override("font_size",29)
	column.add_child(heading)
	column.add_child(Art.rule())
	stage_label=Label.new()
	stage_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stage_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	stage_label.custom_minimum_size.y=30.0
	column.add_child(stage_label)
	progress=ProgressBar.new()
	progress.max_value=1.0
	progress.step=0.0
	progress.show_percentage=false
	progress.custom_minimum_size.y=8.0
	progress.add_theme_stylebox_override("background",ThemeArt.box(Color("111e2a"),Color("756042"),0,0))
	progress.add_theme_stylebox_override("fill",ThemeArt.box(Color("d0a75c"),Color("edd29a"),0,0))
	column.add_child(progress)
	hide()

func begin(title: String,stage: String) -> void:
	heading.text=title
	progress.value=0.0
	set_stage(stage,0.0)
	show()

func set_stage(stage: String,amount: float) -> void:
	stage_label.text=stage
	progress.value=maxf(progress.value,clampf(amount,0.0,1.0))
