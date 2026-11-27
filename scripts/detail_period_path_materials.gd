extends RefCounted
const Painted=preload("res://scripts/painted_building_materials.gd")
static var materials: Dictionary={}

static func variant_at(tile: Vector2i) -> int:
	return posmod((tile.x*73)^(tile.y*157)^(tile.x*tile.y*11),Painted.VARIANTS)

static func finish(age: int,rank: int,fallback: String,variant: int=-1) -> StandardMaterial3D:
	var texture_variant:=rank if variant<0 else variant
	var key:="%d:%d:%s:%d" % [age,rank,fallback,texture_variant]
	if materials.has(key):
		return materials[key]
	var result:=StandardMaterial3D.new()
	result.albedo_color=Color(fallback)
	result.cull_mode=BaseMaterial3D.CULL_DISABLED
	result.roughness=1.0
	var family: String=Painted.SOIL
	if age>=1 and rank>=2:
		match age:
			1: family="period_aegeanGravel"
			2: family="period_romanBasalt"
			3: family="period_pavingSetts" if rank>=3 else Painted.SOIL
			4: family="period_pavingSetts"
			5: family="period_pavingSetts" if rank>=3 else Painted.SOIL
			6: family="period_asphalt" if rank>=3 else "period_pavingSetts"
	if age>0:
		result.albedo_texture=Painted.texture(family,texture_variant)
		result.albedo_color=Color("eee2cc") if family==Painted.SOIL else Color.WHITE
		result.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		Painted.apply_height(result,family,texture_variant)
		result.normal_scale=0.55
		if age==1:
			# Pale packed soil blends into the dwelling courts; ranked roads
			# keep their visible gravel, especially in raking sunlight.
			result.albedo_color=Color("e4cba2") if rank<2 else Color("ddc5a5")
			result.normal_scale=0.38 if rank<2 else 0.60
			result.metallic_specular=0.14
			result.vertex_color_use_as_albedo=true
			result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
		elif age==2:
			result.albedo_color=Color("e0d4bc") if rank<2 else Color(1.09,1.10,1.07)
			result.normal_scale=.63 if rank>=2 else .39
			result.metallic_specular=.14
			result.vertex_color_use_as_albedo=true
			result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	materials[key]=result
	return result

