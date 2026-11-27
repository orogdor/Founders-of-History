class_name WorldTerritory
extends RefCounted

const Grid=preload("res://scripts/campaign_grid.gd")
const Palette=preload("res://scripts/faction_palette.gd")
const Terrain=preload("res://scripts/world_terrain.gd")
const TEAM_COLORS=["69d4c3","e77e64","ac87e2","ead06b","35a082","e07839"]
const COUNTY_COLORS=["b6ce75","dba082","bca3d6","dfcc87","89bfab","e1a583"]

static func smooth(x: float) -> float:
	var t:=clampf(x,0,1)
	return t*t*(3.0-2.0*t)

static func sample_corners(cells: Dictionary,at: Vector2i) -> Vector4:
	return Vector4(float(cells.has(at)),float(cells.has(at+Vector2i.RIGHT)),
		float(cells.has(at+Vector2i.DOWN)),float(cells.has(at+Vector2i.ONE)))

static func interpolate(corners: Vector4,x: float,z: float) -> float:
	return lerpf(lerpf(corners.x,corners.y,x),lerpf(corners.z,corners.w,x),z)

static func field(cells: Dictionary,x: float,z: float) -> float:
	var u:=x-0.5;var v:=z-0.5
	var at:=Vector2i(floori(u),floori(v))
	return interpolate(sample_corners(cells,at),smooth(u-at.x),smooth(v-at.y))

static func point(heights: PackedFloat32Array,x: float,z: float,lift: float,mesh_samples: Variant) -> Vector3:
	var world_x: float=Grid.ORIGIN_X+x*50.0
	var world_z: float=Grid.ORIGIN_Z+z*50.0
	var height:=Terrain.mesh_elevation(mesh_samples,world_x,world_z) if mesh_samples!=null else Terrain.elevation(heights,world_x,world_z)
	return Vector3((x-Grid.COLS/2.0)*2.0,height+lift,(z-Grid.ROWS/2.0)*2.0)

static func snapshot(owned: Dictionary,urban: Dictionary,explored: Dictionary,reveal_all: bool) -> Dictionary:
	var groups: Dictionary={}
	var teams: Dictionary={}
	for key in owned:
		if not reveal_all and not explored.has(key):continue
		var city: Dictionary=owned[key]
		var team:=clampi(int(city.team),0,TEAM_COLORS.size()-1)
		var components:=str(key).split(":")
		var at:=Vector2i(int(components[0]),int(components[1]))
		if not teams.has(team):teams[team]={}
		teams[team][at]=true
		var rural: bool=not urban.get(str(int(city.id)),{}).has(key)
		var name:=Vector3i(team,int(rural),int(city.id))
		if not groups.has(name):groups[name]={}
		groups[name][at]=true
	return {"groups":groups,"teams":teams}

static func prepare(snapshot_data: Dictionary,heights: PackedFloat32Array,mesh_samples: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var groups: Dictionary=snapshot_data.groups
	for name: Vector3i in groups:
		var fill:=prepare_fill(groups[name],heights,mesh_samples)
		if not fill.is_empty():result.append({"arrays":fill,"team":name.x,"rural":bool(name.y),"fill":true})
	var teams: Dictionary=snapshot_data.teams
	for team in teams:
		var outlines:=prepare_border(teams[team],heights,mesh_samples)
		if not outlines.is_empty():
			result.append({"arrays":outlines[0],"team":team,"edge":true})
			result.append({"arrays":outlines[1],"team":team})
	return result

static func attach(parent: Node3D,surfaces: Array[Dictionary]) -> void:
	for src in surfaces:
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,src.arrays)
		var mat:=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		var team: int=src.team
		var rural: bool=src.get("rural",false)
		if src.get("edge",false):mat.albedo_color=Color("f2e3b6")
		else:mat.albedo_color=Palette.color(team,Color(COUNTY_COLORS[team] if rural else TEAM_COLORS[team]))
		if src.get("fill",false):
			mat.albedo_color.a=0.07 if rural else 0.11
			mat.vertex_color_use_as_albedo=true
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		var layer:=MeshInstance3D.new()
		layer.mesh=mesh;layer.material_override=mat
		parent.add_child(layer)

static func prepare_fill(cells: Dictionary,heights: PackedFloat32Array,mesh_samples: Variant) -> Array:
	var min_cell:=Vector2i(Grid.COLS,Grid.ROWS)
	var max_cell:=Vector2i.ZERO
	for at: Vector2i in cells:
		min_cell=min_cell.min(at)
		max_cell=max_cell.max(at)
	var start:=Vector2(min_cell-Vector2i.ONE)
	var size:=(max_cell-min_cell+Vector2i(3,3))*5+Vector2i.ONE
	var vertices:=PackedVector3Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	var used:=PackedInt32Array()
	used.resize(size.x*size.y);used.fill(-1)
	var fields:=PackedFloat32Array()
	fields.resize(size.x*size.y)
	for z in size.y:
		for x in size.x:
			fields[z*size.x+x]=field(cells,start.x+x*0.2,start.y+z*0.2)
	for z in size.y-1:
		for x in size.x-1:
			var a:=z*size.x+x
			var b:=a+1
			var c:=a+size.x
			var d:=c+1
			if maxf(maxf(fields[a],fields[b]),maxf(fields[c],fields[d]))<0.42:continue
			for index in [a,c,b,b,c,d]:
				if used[index]<0:
					used[index]=vertices.size()
					var at:=start+Vector2(index%size.x,floori(float(index)/size.x))*0.2
					vertices.append(point(heights,at.x,at.y,0.055,mesh_samples))
					colors.append(Color(1,1,1,smooth((fields[index]-0.40)/0.20)))
				indices.append(used[index])
	if indices.is_empty():return []
	var arrays:=vertex_only(vertices)
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	return arrays

static func prepare_border(cells: Dictionary,heights: PackedFloat32Array,mesh_samples: Variant) -> Array:
	var patches: Dictionary={}
	for at: Vector2i in cells:
		for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.UP,Vector2i(-1,-1)]:
			patches[at+offset]=true
	var outer:=PackedVector3Array()
	var inner:=PackedVector3Array()
	var values:=PackedFloat32Array()
	values.resize(121)
	for at: Vector2i in patches:
		var corners:=sample_corners(cells,at)
		var owners:=corners.x+corners.y+corners.z+corners.w
		if owners<=0.0 or owners>=4.0:continue
		var min_x:=5 if at.x<0 else 0
		var max_x:=5 if at.x>=Grid.COLS-1 else 10
		var min_z:=5 if at.y<0 else 0
		var max_z:=5 if at.y>=Grid.ROWS-1 else 10
		var origin:=Vector2(at)+Vector2(0.5,0.5)
		for z in range(min_z,max_z+1):
			for x in range(min_x,max_x+1):values[z*11+x]=interpolate(corners,smooth(x*0.1),smooth(z*0.1))-0.5
		for z in range(min_z,max_z):
			for x in range(min_x,max_x):
				var i:=z*11+x
				var a:=values[i];var b:=values[i+1]
				var c:=values[i+12];var d:=values[i+11]
				if (a>0)==(b>0) and (b>0)==(c>0) and (c>0)==(d>0):continue
				var p:=origin+Vector2(x,z)*0.1
				var points: Array[Vector2]=[]
				contour_edge(points,p,p+Vector2(0.1,0),a,b)
				contour_edge(points,p+Vector2(0.1,0),p+Vector2(0.1,0.1),b,c)
				contour_edge(points,p+Vector2(0.1,0.1),p+Vector2(0,0.1),c,d)
				contour_edge(points,p+Vector2(0,0.1),p,d,a)
				for j in range(0,points.size()-1,2):
					var start:=points[j];var end:=points[j+1]
					var mid: Vector2=(start+end)*0.5
					if Terrain.height_at(heights,Grid.ORIGIN_X+mid.x*50,Grid.ORIGIN_Z+mid.y*50)<0.6:continue
					line_quad(outer,heights,start.lerp(end,0.2),start.lerp(end,0.8),0.046,0.13,mesh_samples)
					line_quad(inner,heights,start.lerp(end,0.2),start.lerp(end,0.8),0.027,0.14,mesh_samples)
	return [] if outer.is_empty() else [vertex_only(outer),vertex_only(inner)]

static func vertex_only(vertices: PackedVector3Array) -> Array:
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	return arrays

static func contour_edge(points: Array[Vector2],a: Vector2,b: Vector2,va: float,vb: float) -> void:
	if (va>0.0)==(vb>0.0):return
	points.append(a.lerp(b,va/(va-vb)))

static func line_quad(vertices: PackedVector3Array,heights: PackedFloat32Array,a: Vector2,b: Vector2,half_width: float,lift: float,mesh_samples: Variant) -> void:
	var direction: Vector2=(b-a).normalized();var normal:=Vector2(-direction.y,direction.x)*half_width
	for p in [a-normal,b-normal,a+normal,a+normal,b-normal,b+normal]:
		vertices.append(point(heights,p.x,p.y,lift,mesh_samples))
