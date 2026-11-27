extends SceneTree
## Run with Godot --headless --path . -s tools/build_painted_variants.gd,
## then import the generated images with the editor.

const STOCK_SOURCES = preload("res://data/painted_stock_sources.json")
const SIZE := 384
const COUNT := 8
const GUTTER := 16
const EDGE_BLEND := 17
const OUTPUT := "res://assets/painted/variants/"
const FAMILIES := {
	"meadow": Vector2(0.18, 2.3), "reed": Vector2(0.24, 2.1),
	"wood": Vector2(0.24, 1.8), "stone": Vector2(0.30, 2.4),
	"plaster": Vector2(0.52, 1.2), "tile": Vector2(0.25, 2.1),
	"forest": Vector2(0.19, 2.5), "soil": Vector2(0.28, 1.9),
}
const DESIGNER_SOURCES := [
	"land-hide", "atlas-clay", "atlas-weave", "atlas-wood", "proc-mudbrick",
	"proc-cutstone", "proc-plank", "proc-brick", "proc-fresco", "proc-limestone",
	"land-earth", "proc-marble", "proc-reticulatum", "proc-romanbrick",
	"land-dirt", "proc-sod", "proc-bark", "proc-shingle", "proc-clayroof",
	"proc-roofplank", "proc-flags",
]
const NORMAL_DEPTH := {"reed":9.2,"wood":6.0,"stone":11.5,"plaster":3.8,"tile":8.8,"soil":5.0}
const ATLAS_FAMILIES := ["meadow","reed","forest","soil","stone"]


func _initialize() -> void:
	var status := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	if status != OK:
		quit(status)
		return
	var families := FAMILIES.keys()
	for source: String in DESIGNER_SOURCES:
		families.append("designer_" + source)
	for key: String in STOCK_SOURCES.data:
		families.append("stock_" + key)
	var requested := OS.get_cmdline_user_args()
	for family: String in families:
		if not requested.is_empty() and family not in requested:
			continue
		status = build_family(family)
		if status != OK:
			push_error("Cannot build painted textures for " + family)
			quit(status)
			return
	print("PAINTED_VARIANTS_BUILT ", (families.size() if requested.is_empty() else requested.size()) * COUNT)
	quit()


func build_family(family: String) -> Error:
	var designer := family.begins_with("designer_")
	var directory := "res://assets/house_designer/" if designer else "res://assets/painted/"
	var file := directory + family.trim_prefix("designer_") + ".webp"
	var stock := family.begins_with("stock_")
	if stock:
		file = "res://assets/buildings/" + str(STOCK_SOURCES.data[family.trim_prefix("stock_")])
	var source := Image.load_from_file(ProjectSettings.globalize_path(file))
	if source == null or source.is_empty():
		return ERR_CANT_OPEN
	source.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	source.convert(Image.FORMAT_RGB8)
	var pixels := source.get_data() if stock else seamless_source(source.get_data())
	var atlas: Image
	if family in ATLAS_FAMILIES:
		var block := SIZE + GUTTER * 2
		atlas = Image.create_empty(block * 4, block * 2, false, Image.FORMAT_RGBA8)
	for index in COUNT:
		var maps := paint_variant(pixels, family, index)
		var name := "%s_%d" % [family, index]
		if stock or designer:
			maps[0].convert(Image.FORMAT_RGB8)
		if stock:
			maps[0].resize(256, 256, Image.INTERPOLATE_LANCZOS)
			maps[1].resize(256, 256, Image.INTERPOLATE_LANCZOS)
		var status := save_texture(maps[0], name)
		if status != OK:
			return status
		status = save_texture(maps[1], name + "_height")
		if status != OK:
			return status
		if designer or stock or NORMAL_DEPTH.has(family):
			status = save_texture(make_normal(maps[1],float(NORMAL_DEPTH.get(family, 5.0))),name+"_normal",true)
			if status != OK:
				return status
		if atlas != null:
			insert_tile(atlas, maps[0], index)
	if atlas != null:
		return save_texture(atlas, family + "_atlas")
	return OK


func seamless_source(input: PackedByteArray) -> PackedByteArray:
	var pixels := input.duplicate()
	for y in SIZE:
		for x in SIZE:
			var edge_x := mini(x, SIZE - 1 - x)
			var edge_y := mini(y, SIZE - 1 - y)
			if edge_x >= EDGE_BLEND and edge_y >= EDGE_BLEND:
				continue
			var across_x := 0.5 * (1.0 - smoothstep(0.0, EDGE_BLEND, edge_x))
			var across_y := 0.5 * (1.0 - smoothstep(0.0, EDGE_BLEND, edge_y))
			var here := (y * SIZE + x) * 3
			var left := (y * SIZE + SIZE - 1 - x) * 3
			var above := ((SIZE - 1 - y) * SIZE + x) * 3
			var opposite := ((SIZE - 1 - y) * SIZE + SIZE - 1 - x) * 3
			for channel in 3:
				var a := lerpf(input[here + channel], input[left + channel], across_x)
				var b := lerpf(input[above + channel], input[opposite + channel], across_x)
				pixels[here + channel] = roundi(lerpf(a, b, across_y))
	return pixels


func paint_variant(source: PackedByteArray, family: String, index: int) -> Array[Image]:
	var random := RandomNumberGenerator.new()
	random.seed = family.hash() + index * 17059
	var offset := Vector2i(random.randi_range(0, SIZE - 1), random.randi_range(0, SIZE - 1)) if index > 0 else Vector2i.ZERO
	var phase := random.randf() * TAU
	var amount := random.randf_range(6.0, 19.0) if index > 0 else 0.0
	var tone := random.randf_range(0.91, 1.08) if index > 0 else 1.0
	var warmth := random.randf_range(-0.09, 0.09) if index > 0 else 0.0
	var stock := family.begins_with("stock_")
	var relief: Vector2 = FAMILIES.get(family, Vector2(0.4, 1.5))
	var is_designer := family.begins_with("designer_")
	var rgba := PackedByteArray()
	var heights := PackedByteArray()
	rgba.resize(SIZE * SIZE * 4)
	heights.resize(SIZE * SIZE)
	for y in SIZE:
		var wave_y := float(y) * TAU / SIZE
		var shift_x := sin(wave_y + phase) * amount
		for x in SIZE:
			var wave_x := float(x) * TAU / SIZE
			var mirrored_x := SIZE - 1 - x if index % 2 == 1 else x
			var source_x := posmod(mirrored_x + offset.x + roundi(shift_x + sin(wave_x * 2.0 + wave_y + phase) * amount * 0.33), SIZE)
			var source_y := posmod(y + offset.y + roundi(sin(wave_x + phase) * amount * 0.5), SIZE)
			# Stock models can use specific parts of a texture for trim or doors.
			# Vary the finish while keeping their original UV layout.
			var read := (y * SIZE + x) * 3 if stock else (source_y * SIZE + source_x) * 3
			var r := float(source[read])
			var g := float(source[read + 1])
			var b := float(source[read + 2])
			var brush := tone + sin(wave_x + wave_y * 2.0 + phase) * amount * 0.002
			var raised := (r * 0.25 + g * 0.64 + b * 0.11) / 255.0
			if family == "meadow":
				raised += (g - r) / 255.0 * 0.65
			if is_designer or stock:
				raised += sin(wave_x * 3.0 + phase) * sin(wave_y * 2.0 - phase) * amount * 0.002
			var height := roundi(clampf(0.5 + (raised - relief.x) * relief.y * 0.64, 0.03, 0.97) * 255.0)
			var pixel := y * SIZE + x
			var write := pixel * 4
			rgba[write] = clampi(roundi(r * (brush + warmth)), 0, 255)
			rgba[write + 1] = clampi(roundi(g * brush), 0, 255)
			rgba[write + 2] = clampi(roundi(b * (brush - warmth)), 0, 255)
			rgba[write + 3] = height
			heights[pixel] = height
	return [
		Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, rgba),
		Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_L8, heights),
	]


func insert_tile(atlas: Image, tile: Image, index: int) -> void:
	var block := SIZE + GUTTER * 2
	var at := Vector2i(index % 4, index / 4) * block + Vector2i.ONE * GUTTER
	for y in [-SIZE, 0, SIZE]:
		for x in [-SIZE, 0, SIZE]:
			var region := Rect2i(at + Vector2i(x, y), tile.get_size())
			var clipped := region.intersection(Rect2i(at - Vector2i.ONE * GUTTER, Vector2i.ONE * block))
			atlas.blit_rect(tile, Rect2i(clipped.position - region.position, clipped.size), clipped.position)


func make_normal(height_map: Image, strength: float) -> Image:
	const NORMAL_SIZE := 256
	var height := height_map.duplicate() as Image
	height.resize(NORMAL_SIZE,NORMAL_SIZE,Image.INTERPOLATE_LANCZOS)
	var grey := height.get_data()
	var rgb := PackedByteArray()
	rgb.resize(NORMAL_SIZE*NORMAL_SIZE*3)
	const MASK := NORMAL_SIZE-1
	for y in NORMAL_SIZE:
		for x in NORMAL_SIZE:
			var dx := (float(grey[y*NORMAL_SIZE+((x-1)&MASK)])-float(grey[y*NORMAL_SIZE+((x+1)&MASK)]))*strength/255.0
			var dy := (float(grey[((y+1)&MASK)*NORMAL_SIZE+x])-float(grey[((y-1)&MASK)*NORMAL_SIZE+x]))*strength/255.0
			var n := Vector3(dx,dy,1.0).normalized()
			var pixel := (y*NORMAL_SIZE+x)*3
			rgb[pixel]=roundi((n.x*0.5+0.5)*255.0)
			rgb[pixel+1]=roundi((n.y*0.5+0.5)*255.0)
			rgb[pixel+2]=roundi((n.z*0.5+0.5)*255.0)
	return Image.create_from_data(NORMAL_SIZE,NORMAL_SIZE,false,Image.FORMAT_RGB8,rgb)


func save_texture(image: Image, name: String, normal_map:=false) -> Error:
	var path := OUTPUT + name + ".png"
	var status := image.save_png(path)
	if status != OK:
		return status
	var settings := ConfigFile.new()
	settings.load(path + ".import")
	settings.set_value("remap", "importer", "texture")
	settings.set_value("remap", "type", "CompressedTexture2D")
	settings.set_value("deps", "source_file", path)
	settings.set_value("params", "compress/mode", 0)
	settings.set_value("params", "compress/normal_map", 1 if normal_map else 0)
	settings.set_value("params", "detect_3d/compress_to", 0)
	settings.set_value("params", "mipmaps/generate", true)
	return settings.save(path + ".import")
