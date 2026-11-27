extends RefCounted
const SHADE=preload("res://scripts/period_vapor.gdshader")
static var finishes: Dictionary={}

static func add(parent: Node3D,at: Vector3,size: Vector2,style: String,variant: int) -> void:
	var key:=style+str(variant)
	if not finishes.has(key):
		var material:=ShaderMaterial.new()
		material.shader=SHADE
		material.set_shader_parameter("vapor_tint",Color("b9bbc480") if style=="steam" else Color("85746b69"))
		material.set_shader_parameter("phase",float(variant)*2.7)
		finishes[key]=material
	var quad:=QuadMesh.new()
	quad.size=size
	var plume:=MeshInstance3D.new()
	plume.name="PeriodVapor"
	plume.mesh=quad
	plume.material_override=finishes[key]
	plume.position=at+Vector3.UP*(size.y/2.0)
	plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plume.visibility_range_end=90.0
	plume.visibility_range_end_margin=8.0
	parent.add_child(plume)

