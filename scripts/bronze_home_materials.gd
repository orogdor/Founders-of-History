extends RefCounted
## Local triplanar sampling keeps the grain scale consistent across editable walls.
const SWATCHES := {
	"plaster": 0.46,
	"earth": 0.39,
	"rubble": 0.95,
	"wood": 0.74,
	"matting": 0.82,
	"linen": 0.80,
	"kiln": 0.72,
	"bronze": 0.9,
}
const ART := "res://assets/bronze_home/"
static var finishes: Dictionary = {}

static func get_finish(surface: String, variation: int = 0) -> StandardMaterial3D:
	var index := posmod(variation, 8)
	var key := "%s_%d" % [surface, index]
	if finishes.has(key):
		return finishes[key]
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(ART + surface + ".webp")
	material.normal_texture = load(ART + surface + "_normal.png")
	material.normal_enabled = true
	material.normal_scale = 0.62
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.96
	material.metallic_specular = 0.16
	if surface == "bronze":
		material.metallic = 0.62
		material.roughness = 0.57
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * float(SWATCHES[surface])
	material.uv1_offset = Vector3(0.37, 0.21, 0.63) * float(index)
	finishes[key] = material
	return material

