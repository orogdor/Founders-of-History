extends VBoxContainer

const Flows = preload("res://scripts/city_resource_flows.gd")
const Economy = preload("res://data/economy.json")
const InterfaceTheme = preload("res://scripts/interface_theme.gd")
const ESSENTIALS = ["bread","water","wood","stone","gold"]
const PRECISION := 0.01

var summary: Label
var show_all: CheckButton
var rows := {}
var current_realm: Dictionary = {}
var current_time := 0.0

func _ready() -> void:
	add_theme_constant_override("separation",5)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color",InterfaceTheme.MUTED)
	add_child(summary)

	var header_margin := MarginContainer.new()
	add_child(header_margin)
	var header := HBoxContainer.new()
	header_margin.add_child(header)
	var headings := make_columns(header,["Ressurss","Varu","Lisandub","Tarbimine","Jätkub"])
	headings[3].tooltip_text = "Töökodade ja majapidamiste jooksev tarbimine ühislaost."
	add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 52
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	add_child(scroll)
	header_margin.add_theme_constant_override("margin_right",ceili(scroll.get_v_scroll_bar().get_combined_minimum_size().x))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",0)
	scroll.add_child(list)
	for key in Economy.data.resource_names:
		var row := HBoxContainer.new()
		list.add_child(row)
		var cells := make_columns(row,[str(Economy.data.resource_names[key]),"","","",""])
		rows[key] = {"row":row, "cells":cells}

	show_all = CheckButton.new()
	show_all.text = "Kõik ressursid"
	show_all.toggled.connect(func(_enabled): refresh(current_realm,current_time))
	add_child(show_all)

	var notes := Label.new()
	notes.text = "Kohalik toodang, maksutulu ja kogutud vesi. Kaubandus ja ühekordsed kulud kajastuvad varus. Kestus senise tempo põhjal."
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.add_theme_color_override("font_color",InterfaceTheme.MUTED)
	notes.add_theme_font_size_override("font_size",12)
	add_child(notes)

func make_columns(row: HBoxContainer, values: Array) -> Array[Label]:
	var cells: Array[Label] = []
	row.custom_minimum_size.y = 26
	row.add_theme_constant_override("separation",8)
	var widths := [90,54,60,65,78]
	for index in values.size():
		var cell := Label.new()
		cell.text = values[index]
		cell.custom_minimum_size.x = widths[index]
		if index == 0:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cell.tooltip_text = values[index]
		else:
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(cell)
		cells.append(cell)
	return cells

func refresh(realm: Dictionary, seconds: float) -> void:
	if not is_node_ready():
		return
	current_realm = realm
	current_time = seconds
	var measurement := Flows.recent(realm,seconds)
	var minutes: int = measurement.minutes
	var stock: Dictionary = realm.get("resources",{})
	var rates: Dictionary = measurement.rates
	if minutes == 0:
		summary.text = "Esimene hinnang ilmub pärast täit mänguminutit."
	else:
		summary.text = "Lisandub ja tarbitakse mänguminuti kohta · %d min keskmine" % minutes
	for key in rows:
		var amount := float(stock.get(key,0))
		var rate: Vector2 = rates.get(key,Vector2.ZERO)
		var entry: Dictionary = rows[key]
		entry.row.visible = show_all.button_pressed or key in ESSENTIALS or amount >= PRECISION or rate.length_squared() >= PRECISION*PRECISION
		if not entry.row.visible:
			continue
		var cells: Array[Label] = entry.cells
		cells[1].text = quantity(amount)
		cells[2].text = quantity(rate.x) if minutes > 0 else "—"
		cells[3].text = quantity(rate.y) if minutes > 0 else "—"
		cells[4].text = remaining_time(amount,rate,minutes)
		var color: Color = InterfaceTheme.TEXT
		if minutes > 0 and rate.y-rate.x >= PRECISION:
			color = Color("ffd08a")
		elif minutes > 0 and rate.x-rate.y >= PRECISION:
			color = Color("b1d597")
		cells[4].add_theme_color_override("font_color",color)

static func quantity(amount: float) -> String:
	return "%.2f" % amount if absf(amount) < 1.0 else "%.1f" % amount

static func remaining_time(amount: float, rate: Vector2, minutes: int) -> String:
	if minutes == 0:
		return "—"
	var depletion := rate.y-rate.x
	if depletion < -PRECISION:
		return "Kasvab"
	if amount < PRECISION:
		return "Otsas"
	if depletion < PRECISION:
		return "Püsib"
	var duration := amount/depletion
	if duration < 1.0:
		return "< 1 min"
	if duration >= 60.0:
		return "%.1f h" % (duration/60.0)
	return "%.1f min" % duration
