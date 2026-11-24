extends RefCounted

const FOLDER := "res://assets/surface_detail/"
static var sources: Dictionary = {}
static var read_sources := false

static func apply(material: StandardMaterial3D, use_height: bool) -> void:
	if material.albedo_texture == null or material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return
	if not read_sources:
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "materials.json")) if FileAccess.file_exists(FOLDER + "materials.json") else null
		if manifest is Dictionary:
			sources = manifest
		read_sources = true
	var key: String = sources.get(material.albedo_texture.resource_path.trim_prefix("res://"), "")
	if key.is_empty():
		return
	var normal_path := FOLDER + key + "-normal.png"
	if material.normal_texture == null and ResourceLoader.exists(normal_path):
		material.normal_texture = load(normal_path)
		material.normal_enabled = true
		material.normal_scale = 0.45
	# Cutout leaves and transparent effects retain their original UV coverage.
	var height_path := FOLDER + key + "-height.png"
	if use_height and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and ResourceLoader.exists(height_path):
		material.heightmap_texture = load(height_path)
		material.heightmap_enabled = true
		material.heightmap_scale = 1.2
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
