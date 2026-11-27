extends RefCounted

const ShaderSource=preload("res://scripts/detail_period_sky.gdshader")
const ZENITH:=["","447ba6","5a80a7","536f97","486b8c","5d728b","4d80a8"]
const HORIZON:=["","bbccc1","d3c7b8","aabec1","bdc9ca","c6babc","c2d5d5"]
const CLOUD_FLOOR:=[0.0,0.61,0.55,0.50,0.52,0.56,0.57]
var material: ShaderMaterial
var age_previous:=0
var time_previous:=-1

func apply(environment: Environment,age: int,hour: float,daylight: float,elevation: float,sun_vector: Vector3) -> void:
	if age==0:
		if age_previous>0:
			environment.background_mode=Environment.BG_COLOR
			environment.reflected_light_source=Environment.REFLECTION_SOURCE_BG
			age_previous=0
		return
	if material==null:
		configure(environment)
	var time:=roundi(hour*30.0)
	if time==time_previous and age==age_previous:
		return
	if age_previous==0:
		environment.background_mode=Environment.BG_SKY
		environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	age_previous=age
	time_previous=time
	var dusk:=clampf(1.0-absf(elevation)*4.2,0.0,1.0)*clampf(daylight+0.26,0.0,1.0)
	var horizon:=Color("1e2b43").lerp(Color(HORIZON[age]),daylight)
	material.set_shader_parameter("upper_sky",Color("0c1930").lerp(Color(ZENITH[age]),daylight))
	material.set_shader_parameter("horizon_sky",horizon.lerp(Color("e0ab83"),dusk*0.62))
	material.set_shader_parameter("soft_cloud",Color("26364c").lerp(Color("8d9eaa"),daylight))
	material.set_shader_parameter("bright_cloud",Color("4a5266").lerp(Color("f1e9d9"),daylight).lerp(Color("e8ba9e"),dusk*0.57))
	material.set_shader_parameter("sunlight",Color("fff1ce").lerp(Color("ffc79c"),dusk))
	material.set_shader_parameter("sun_direction",sun_vector.normalized())
	material.set_shader_parameter("daylight",daylight)
	material.set_shader_parameter("cloud_floor",CLOUD_FLOOR[age])
	material.set_shader_parameter("drift",float(age)*0.131+hour*0.008)

func configure(environment: Environment) -> void:
	var noise:=FastNoiseLite.new()
	noise.seed=21961
	noise.frequency=0.037
	noise.fractal_octaves=4
	var shape:=NoiseTexture2D.new()
	shape.width=384
	shape.height=384
	shape.seamless=true
	shape.seamless_blend_skirt=0.24
	shape.noise=noise
	material=ShaderMaterial.new()
	material.shader=ShaderSource
	material.set_shader_parameter("cloud_shape",shape)
	var sky:=Sky.new()
	sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size=Sky.RADIANCE_SIZE_32
	sky.sky_material=material
	environment.sky=sky
