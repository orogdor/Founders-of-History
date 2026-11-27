extends RefCounted
## Tiling swatches in local metres. Shared materials keep nearby sites consistent.
const SCALES := {"lime":0.48, "tile":1.1, "stone":0.54, "brick":0.56}
const COLORS := {"lime":Color("e9e1d5"), "tile":Color("a0b3b6"), "stone":Color("dfd9d0"), "brick":Color("a9bec0")}
const ART := "res://assets/iron_age/"
static var cache: Dictionary = {}

static func get_finish(kind: String, variation := 0) -> StandardMaterial3D:
	var index := posmod(variation, 8)
	var key := "%s_%d" % [kind,index]
	if cache.has(key):
		return cache[key]
	var finish := StandardMaterial3D.new()
	finish.albedo_color = COLORS[kind]
	finish.albedo_texture = load(ART + kind + ".webp")
	finish.normal_texture = load(ART + kind + "_normal.png")
	finish.normal_enabled = true
	finish.normal_scale = 0.64 if kind == "stone" else 0.44
	finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	finish.uv1_triplanar = true
	finish.uv1_scale = Vector3.ONE * float(SCALES[kind])
	finish.uv1_offset = Vector3(0.37,0.16,0.59) * index
	finish.roughness = 0.94
	finish.metallic_specular = 0.16
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	cache[key] = finish
	return finish
