extends RefCounted
## Shared masonry finishes for the house editor and imported town buildings.

const STONE=preload("res://scripts/stone_surface.gdshader")
const SurfaceDetail=preload("res://scripts/surface_detail.gd")
const FIELDSTONE=preload("res://assets/house_designer/atlas-stone.webp")
const CUTSTONE=preload("res://assets/house_designer/proc-cutstone.webp")
const LIMESTONE=preload("res://assets/house_designer/proc-limestone.webp")
const CYCLOPEAN=preload("res://assets/house_designer/proc-cyclopean.webp")
const FINISHES:={
	"stone":[FIELDSTONE,0,Color("e0ddd2"),1.0],
	"medievalRubble":[FIELDSTONE,2,Color("d9d9ce"),1.0],
	"cutstone":[CUTSTONE,-1,Color("cec9bc"),0.72],
	"renaissanceAshlar":[CUTSTONE,-1,Color("ded5c3"),0.78],
	"limestone":[LIMESTONE,-1,Color("e0d7c0"),0.83],
	"cyclopean":[CYCLOPEAN,-1,Color("c9c2ad"),0.68],
}
# The asset build deduplicates these embedded GLB images under content hashes.
# The original names cover editor imports of the same surfaces.
const IMPORTED_FINISHES:={
	"ee2dd07efe25e411aeec":"stone",
	"62d19299-0307-4af5-96dc-6d0d3d197d9c":"stone",
	"98efe880-0df5-4f52-9fca-cc66a0513bcb":"stone",
	"a0bac30dcfa6d49d51f6":"cutstone",
	"49de14e6-300d-4259-a979-9090e6e5967f":"cutstone",
}
static var materials: Dictionary={}

static func is_masonry(style: String) -> bool:
	return FINISHES.has(style)

static func uses_atlas(style: String) -> bool:
	return FINISHES.has(style) and int(FINISHES[style][1])>=0

static func source_style(original: Material) -> String:
	if not original is StandardMaterial3D or original.albedo_texture==null:return ""
	var name: String=original.albedo_texture.resource_path.get_file().get_basename()
	if IMPORTED_FINISHES.has(name):return IMPORTED_FINISHES[name]
	var suffix:=name.trim_suffix("_crop").rsplit("_",true,1)
	return IMPORTED_FINISHES.get(suffix[suffix.size()-1],"") if not suffix.is_empty() else ""

static func material(style: String,mapped: bool,relief: bool) -> ShaderMaterial:
	var key:=[style,mapped,relief]
	if materials.has(key):return materials[key]
	var source: Array=FINISHES[style]
	var surface:=ShaderMaterial.new()
	surface.shader=STONE
	surface.set_shader_parameter("stone_texture",source[0])
	surface.set_shader_parameter("atlas_tile",source[1])
	surface.set_shader_parameter("stone_tint",source[2])
	surface.set_shader_parameter("tiling",source[3])
	surface.set_shader_parameter("mesh_uv",mapped)
	if relief:
		var height:=SurfaceDetail.matching_height(source[0])
		if height!=null:
			surface.set_shader_parameter("stone_height",height)
			surface.set_shader_parameter("has_height_map",true)
		surface.set_shader_parameter("relief_amount",0.018 if height!=null else 0.007)
	materials[key]=surface
	return surface

