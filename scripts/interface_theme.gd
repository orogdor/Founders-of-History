extends RefCounted

const INK := Color("101e2b")
const BORDER := Color("a0824b")
const TEXT := Color("f0e1bf")
const MUTED := Color("c3b391")

static var shared: Theme

static func get_theme() -> Theme:
	if shared != null:
		return shared
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif", "serif"])
	shared = Theme.new()
	shared.default_font = serif
	shared.default_font_size = 14

	var quiet := box(INK, BORDER)
	var hover := box(Color("263e54"), Color("e8c781"))
	var pressed := box(Color("3f3b2d"), Color("d6b36f"))
	var disabled := box(Color("172430"), Color("655842"))
	var focus := box(Color.TRANSPARENT, Color("ffdc91"))
	focus.draw_center = false
	for control in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		shared.set_stylebox("normal", control, quiet)
		shared.set_stylebox("hover", control, hover)
		shared.set_stylebox("pressed", control, pressed)
		shared.set_stylebox("disabled", control, disabled)
		shared.set_stylebox("focus", control, focus)
		shared.set_color("font_color", control, TEXT)
		shared.set_color("font_hover_color", control, Color("fff2d0"))
		shared.set_color("font_pressed_color", control, Color("fff2d0"))
		shared.set_color("font_disabled_color", control, MUTED)
	for control in ["TextEdit", "LineEdit"]:
		shared.set_stylebox("normal", control, quiet)
		shared.set_stylebox("focus", control, focus)
		shared.set_stylebox("read_only", control, disabled)
		shared.set_color("font_color", control, TEXT)
		shared.set_color("font_placeholder_color", control, MUTED)
		shared.set_color("selection_color", control, Color("53637b"))
	shared.set_color("font_color", "Label", TEXT)
	shared.set_color("default_color", "RichTextLabel", TEXT)
	shared.set_color("font_color", "PopupMenu", TEXT)
	shared.set_color("font_hover_color", "PopupMenu", Color("fff2d0"))
	shared.set_color("font_disabled_color", "PopupMenu", MUTED)
	shared.set_stylebox("panel", "PopupMenu", box(Color("152636"), BORDER, 5, 6))
	shared.set_stylebox("hover", "PopupMenu", hover)
	shared.set_constant("v_separation", "PopupMenu", 9)
	shared.set_stylebox("panel", "AcceptDialog", panel(18))
	shared.set_stylebox("panel", "FileDialog", panel(18))
	for control in ["HScrollBar", "VScrollBar"]:
		shared.set_stylebox("scroll", control, box(INK, Color("364453"), 3, 3))
		shared.set_stylebox("grabber", control, box(Color("766341"), BORDER, 4, 4))
		shared.set_stylebox("grabber_highlight", control, box(Color("9e8151"), BORDER, 4, 4))
		shared.set_stylebox("grabber_pressed", control, box(BORDER, Color("e8c781"), 4, 4))
	return shared

static func box(background: Color, border: Color, horizontal := 10, vertical := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style

static func panel(padding: int) -> StyleBoxFlat:
	var style := box(Color("112130f8"), BORDER, padding, padding)
	style.set_corner_radius_all(7)
	style.shadow_color = Color("040a13a6")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style
