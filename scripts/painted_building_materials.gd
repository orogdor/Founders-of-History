extends RefCounted

const VARIANTS := 8
const MEADOW := "meadow"
const FOREST := "forest"
const SOIL := "soil"
const REED := "reed"
const WOOD := "wood"
const STONE := "stone"
const PLASTER := "plaster"
const TILE := "tile"
const ROOT := "res://assets/painted/variants/"
const STOCK_SOURCES = preload("res://data/painted_stock_sources.json")
const WORLD_SHADER = preload("res://scripts/painted_world_building.gdshader")

const FINISHES := {
	"reed": REED, "thatch": REED, "wood": WOOD, "stave": WOOD,
	"stone": STONE, "cyclopean": STONE, "plaster": PLASTER,
	"prestigePlaster": PLASTER, "halftimber": PLASTER, "tile": TILE,
}

# Stock GLBs share texture families. Match the imported texture's stable ID,
# since the same surface material has a different name in each GLB.
const STOCK_FINISHES := {
	"5eab4ae1": REED, "40e4e7d9": REED, "a1c0e2f1": REED, "07db34ab": REED,
	"465e1fa0": WOOD, "7f58f9d4": WOOD, "a7ee85b4": WOOD, "10263ad7": WOOD,
	"98efe880": STONE, "62d19299": STONE, "a5aa04bc": STONE, "af9e91d4": STONE, "9825e2c4": STONE,
	"995cbde2": PLASTER, "01d22606": PLASTER, "9f2e6892": PLASTER,
	"8317a31e": TILE,
}

static var stock_materials: Dictionary = {}
static var textures: Dictionary = {}
static var procedural_materials: Dictionary = {}
static var distant_material: ShaderMaterial


static func variant_at(tile: Vector2i, site: Vector2, kind: String) -> int:
	var cell_x := tile.x * 1800 + roundi(site.x * 8.0)
	var cell_z := tile.y * 1560 + roundi(site.y * 8.0)
	return posmod(hash(Vector3i(cell_x, cell_z, kind.hash())), VARIANTS)


static func texture(family: String, variant: int, height := false) -> Texture2D:
	var name := "%s_%d%s" % [family, posmod(variant, VARIANTS), "_height" if height else ""]
	if not textures.has(name):
		textures[name] = load(ROOT + name + ".png")
	return textures[name]


static func atlas(family: String) -> Texture2D:
	var name := family + "_atlas"
	if not textures.has(name):
		textures[name] = load(ROOT + name + ".png")
	return textures[name]


static func apply_height(material: BaseMaterial3D, family: String, variant: int) -> void:
	material.heightmap_texture = texture(family, variant, true)
	material.heightmap_enabled = material.heightmap_texture != null
	material.heightmap_scale = 1.6 if family in [STONE, TILE, REED] else 0.85
	material.heightmap_deep_parallax = false
	if family.begins_with("period_") or family.begins_with("designer_") or family.begins_with("stock_") or family in [WOOD,STONE,PLASTER,REED,TILE,SOIL]:
		var name := "%s_%d_normal" % [family,posmod(variant,VARIANTS)]
		if not textures.has(name):
			textures[name]=load(ROOT+name+".png")
		material.normal_texture=textures[name]
		material.normal_enabled=material.normal_texture!=null
		material.normal_scale=0.9 if family in [REED,STONE,TILE] else 0.74
		material.roughness=0.74 if family==TILE else 0.84 if family==WOOD else 0.91
		material.metallic_specular=0.30 if family in [WOOD,TILE] else 0.23


static func apply_stock(node: Node, variant := 0) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var source := node.get_active_material(surface) as BaseMaterial3D
			if source == null or source.albedo_texture == null:
				continue
			var filename := source.albedo_texture.resource_path.get_file().get_basename()
			var name := filename.trim_suffix("_crop")
			var asset_id := name.get_slice("_", name.get_slice_count("_") - 1).left(8)
			var painted: String = STOCK_FINISHES.get(asset_id, "")
			var stock_key := asset_id + ("_crop" if filename.ends_with("_crop") else "")
			if painted.is_empty() and STOCK_SOURCES.data.has(stock_key):
				painted = "stock_" + stock_key
			if painted.is_empty() or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			if not stock_materials.has(source):
				stock_materials[source] = {}
			var choices: Dictionary = stock_materials[source]
			if not choices.has(variant):
				var material := source.duplicate() as BaseMaterial3D
				material.albedo_texture = texture(painted, variant)
				if painted == REED:
					var reed_tint := Color(0.91, 0.94, 1.0)
					material.albedo_color = source.albedo_color.lerp(reed_tint, 0.48) if asset_id == "07db34ab" else reed_tint
				elif not painted.begins_with("stock_"):
					material.albedo_color = source.albedo_color.lerp(Color.WHITE, 0.32 if painted == WOOD else 0.60)
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				apply_height(material, painted, variant)
				choices[variant] = material
			node.set_surface_override_material(surface, choices[variant])
	for child in node.get_children():
		apply_stock(child, variant)


static func town_material(shader: Shader, variant: int) -> ShaderMaterial:
	if not procedural_materials.has(variant):
		var material := ShaderMaterial.new()
		material.shader = shader
		for family in [WOOD, STONE, PLASTER, REED, TILE]:
			material.set_shader_parameter("painted_" + family, texture(family, variant))
		procedural_materials[variant] = material
	return procedural_materials[variant]


static func world_material() -> ShaderMaterial:
	if distant_material == null:
		distant_material = ShaderMaterial.new()
		distant_material.shader = WORLD_SHADER
		distant_material.set_shader_parameter("painted_grain", atlas(REED))
	return distant_material
