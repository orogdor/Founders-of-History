extends RefCounted

const UI := "res://assets/ui/"
const FRAME := preload("res://assets/ui/ui-art-v310_card_frame.webp")
const PANEL := preload("res://assets/ui/ui-art-v304_panel.webp")
const DIVIDER := preload("res://assets/ui/ui-art-v291_footer_wood.webp")
const BACKGROUND := preload("res://assets/ui/ui-art-v304_chronicle.webp")
const GOLD := Color("f7df9f")
const PAPER_INK := Color("321f10")

static func picture(asset: Texture2D, mode := TextureRect.STRETCH_SCALE) -> TextureRect:
	var node := TextureRect.new()
	node.texture = asset
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = mode
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func cover(parent: Control, asset: Texture2D, mode := TextureRect.STRETCH_SCALE) -> TextureRect:
	var node := picture(asset, mode)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(node)
	return node

static func atlas(asset: Texture2D, region: Rect2) -> AtlasTexture:
	var cropped := AtlasTexture.new()
	cropped.atlas = asset
	cropped.region = region
	cropped.filter_clip = true
	return cropped

static func panel(padding: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PANEL
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 74)
		style.set_content_margin(side, padding)
	return style

static func vignette() -> TextureRect:
	var shade := Gradient.new()
	shade.offsets = PackedFloat32Array([0.0, 0.29, 0.57, 0.84, 1.0])
	shade.colors = PackedColorArray([
		Color("070c15b8"), Color("070c1547"), Color("070c151a"),
		Color("070c1575"), Color("070c15eb"),
	])
	var gradient := GradientTexture2D.new()
	gradient.gradient = shade
	gradient.width = 8
	gradient.height = 256
	gradient.fill_from = Vector2(0.5, 0.0)
	gradient.fill_to = Vector2(0.5, 1.0)
	return picture(gradient)

static func rule() -> TextureRect:
	var shades := Gradient.new()
	shades.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	shades.colors = PackedColorArray([Color("b1874500"), Color("edc378"), Color("b1874500")])
	var texture := GradientTexture2D.new()
	texture.gradient = shades
	texture.width = 256
	texture.height = 2
	var line := picture(texture)
	line.custom_minimum_size = Vector2(238, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return line

static func card(caption: String, illustration: Texture2D, crop: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.pressed.connect(action)
	button.tooltip_text = caption
	button.accessibility_name = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var art := cover(button, atlas(illustration, crop), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	art.set_anchor(SIDE_LEFT, 0.049)
	art.set_anchor(SIDE_TOP, 0.066)
	art.set_anchor(SIDE_RIGHT, 0.951)
	art.set_anchor(SIDE_BOTTOM, 0.693)
	var frame := cover(button, FRAME)
	var title := Label.new()
	title.text = caption
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", PAPER_INK)
	title.set_anchor(SIDE_LEFT, 0.07)
	title.set_anchor(SIDE_RIGHT, 0.93)
	title.set_anchor(SIDE_TOP, 0.692)
	title.set_anchor(SIDE_BOTTOM, 0.912)
	button.add_child(title)
	button.set_meta("caption", title)

	var refresh := func() -> void:
		if button.disabled:
			art.modulate = Color("a0a099")
			frame.modulate = Color("c1b492")
		elif button.is_hovered() or button.has_focus():
			art.modulate = Color(1.14, 1.11, 1.04)
			frame.modulate = Color(1.23, 1.13, 0.87)
		else:
			art.modulate = Color.WHITE
			frame.modulate = Color.WHITE
		button.queue_redraw()
	button.mouse_entered.connect(refresh)
	button.mouse_exited.connect(refresh)
	button.focus_entered.connect(refresh)
	button.focus_exited.connect(refresh)
	button.set_meta("refresh", refresh)
	return button
