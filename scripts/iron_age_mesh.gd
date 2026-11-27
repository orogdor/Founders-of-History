extends "res://scripts/bronze_worksite_visuals.gd"
## Batched architectural members and fittings. Rectangular tegulae and their
## overlapping half-round cover tiles share a single tinted ceramic surface.
const IronFinish = preload("res://scripts/iron_age_materials.gd")
const SOURCES := {"lime":"lime","brick":"brick","tile":"tile","ashlar":"stone","redpaint":"lime","ochre":"lime","iron":"stone","water":"lime","racewater":"lime","leaf":"lime","fruit":"lime","blackwood":"wood","sand":"stone"}
static var finishes: Dictionary = {}

func builder(finish: String) -> SurfaceTool:
	if not SOURCES.has(finish):
		return super.builder(finish)
	var group: Dictionary = pieces[int(cover)]
	if group.has(finish):
		return group[finish]
	var key := finish + str(variation)
	if not finishes.has(key):
		var base: StandardMaterial3D = Finishes.get_finish("wood",variation) if SOURCES[finish]=="wood" else IronFinish.get_finish(SOURCES[finish],variation)
		var mat := base.duplicate() as StandardMaterial3D
		var color := {"redpaint":"a24d39","ochre":"ddaa59","iron":"524c48","water":"689f9a","leaf":"63804b","fruit":"ba7244","blackwood":"746454","sand":"bca775"}
		if color.has(finish): mat.albedo_color=Color(color[finish])
		if finish=="iron":
			mat.metallic=0.68
			mat.roughness=0.74
		if finish in ["water","racewater"]:
			mat.normal_enabled=false
			mat.roughness=0.24
			mat.uv1_scale=Vector3.ONE*.21
		if finish=="racewater":
			mat.albedo_texture=null
			mat.albedo_color=Color("64776b")
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.vertex_color_use_as_albedo=true
		mat.vertex_color_is_srgb=true
		finishes[key]=mat
	var surface:=Masonry.surface(finishes[key])
	surface.set_color(Color.WHITE)
	group[finish]=surface
	return surface

func member(a:Vector3,b:Vector3,height:float,depth:float,finish:String) -> void:
	var axis:=(b-a).normalized()
	if axis.length_squared()<.99:return
	var outward:=axis.cross(Vector3.UP).normalized()
	Masonry.bar(builder(finish),(a+b)*.5,axis,outward,a.distance_to(b),height,depth)

func barrel(a:Vector3,b:Vector3,radius:float,finish:String="tile") -> void:
	var axis:=(b-a).normalized()
	if axis.length_squared()<.9:return
	var side:=axis.cross(Vector3.UP).normalized()
	var up:=side.cross(axis).normalized()
	var part:=builder(finish)
	for i in 5:
		var t0:=PI*i/5.0
		var t1:=PI*(i+1)/5.0
		var n0:=side*cos(t0)+up*sin(t0)
		var n1:=side*cos(t1)+up*sin(t1)
		Masonry.quad(part,a+n0*radius,a+n1*radius,b+n1*radius*.91,b+n0*radius*.91,(n0+n1)*.5)
		Masonry.quad(part,a+n0*radius,a+n1*radius,a+n1*(radius*.75),a+n0*(radius*.75),-axis)

func tiled_plane(a:Vector3,b:Vector3,c:Vector3,d:Vector3) -> void:
	var axis:=(b-a).normalized()
	var base:=(a+b)*.5
	var peak:=(c+d)*.5
	var run:=base.distance_to(peak)
	var base_half:=a.distance_to(b)*.5
	var peak_half:=c.distance_to(d)*.5
	if run<.02 or base_half<.02:return
	var normal:=axis.cross(peak-base).normalized()
	if normal.y<0:normal=-normal
	var surface:=builder("tile")
	surface.set_color(Color("d7c1b1"))
	Masonry.quad(surface,a,b,c,d,normal)
	var segments:=maxi(1,roundi(base_half*2/.31))
	var courses:=maxi(1,roundi(run/.46))
	var step:=base_half*2/segments
	for row in courses:
		var lo:=maxf(0,float(row)/courses-.009/run)
		var hi:=minf(1,float(row+1)/courses+.008/run)
		var foot:=base.lerp(peak,lo)+normal*.027
		var head:=base.lerp(peak,hi)+normal*.012
		var w0:=lerpf(base_half,peak_half,lo)
		var w1:=lerpf(base_half,peak_half,hi)
		for col in segments:
			var u:float=-base_half+col*step
			if u>=w0 or u+step<=-w0:continue
			var r0:=foot+axis*clampf(u+.005,-w0,w0)
			var r1:=foot+axis*clampf(u+step-.005,-w0,w0)
			var s0:=head+axis*clampf(u+.005,-w1,w1)
			var s1:=head+axis*clampf(u+step-.005,-w1,w1)
			var shade:=absf(sin(col*57.21+row*14.3+variation*1.66))
			surface.set_color(Color("e8cbbb").lerp(Color("fff5e4"),shade))
			Masonry.quad(surface,r0,r1,s1,s0,normal)
			Masonry.quad(surface,r0-normal*.025,r1-normal*.025,r1,r0,base-peak)
			if col>0 and absf(u)<w0 and absf(u)<w1+.015:
				barrel(foot+axis*u,head+axis*u,.041)
	surface.set_color(Color.WHITE)

func ridge(a:Vector3,b:Vector3,size:=.10) -> void:
	var n:=maxi(1,ceili(a.distance_to(b)/.48))
	for i in n:
		barrel(a.lerp(b,float(i)/n),a.lerp(b,float(i+1)/n),size)

func pillar(at:Vector3,height:float,style:String) -> void:
	if style=="post":
		block(at+Vector3.UP*.09,Vector3(.35,.18,.35),"ashlar")
		beam(at+Vector3.UP*.15,at+Vector3.UP*height,.109,"wood",.095,8)
		return
	var radius:=clampf(height*.062,.095,.19)
	var plinth:=radius*2.9
	block(at+Vector3.UP*.064,Vector3(plinth,.127,plinth),"ashlar")
	vessel(at,[Vector2(radius*1.30,.127),Vector2(radius*1.27,.17),Vector2(radius*1.06,.23),Vector2(radius*.95,height*.53),Vector2(radius*.81,height-.27),Vector2(radius*1.04,height-.235),Vector2(radius*1.09,height-.19),Vector2(radius*.98,height-.17),Vector2(radius*1.37,height-.09)],"lime",0,14)
	block(at+Vector3.UP*(height-.055),Vector3(plinth,.11,plinth),"ashlar")
	if style=="ionic":
		for side:float in [-1,1]:
			var volute:=at+Vector3(side*radius,height-.16,0)
			beam(volute+Vector3.FORWARD*radius,volute+Vector3.BACK*radius,.084,"lime",.084,12)

func arch(center:Vector3,axis:Vector3,out:Vector3,radius:float,rise:float,border:float,depth:float,finish:String="brick",count:=13) -> void:
	var part:=builder(finish)
	for i in count:
		var p:=PI*(float(i)+.03)/count
		var q:=PI*(float(i+1)-.03)/count
		var start:=axis*cos(p)*radius+Vector3.UP*sin(p)*rise
		var end:=axis*cos(q)*radius+Vector3.UP*sin(q)*rise
		var outer0:=start+axis*cos(p)*border+Vector3.UP*sin(p)*border
		var outer1:=end+axis*cos(q)*border+Vector3.UP*sin(q)*border
		var front:=center+out*depth*.5
		var back:=center-out*depth*.5
		Masonry.quad(part,front+start,front+end,front+outer1,front+outer0,out)
		Masonry.quad(part,back+start,back+end,back+outer1,back+outer0,-out)
		Masonry.quad(part,back+start,back+end,front+end,front+start,-(start+end).normalized())
		Masonry.quad(part,back+outer0,back+outer1,front+outer1,front+outer0,(start+end).normalized())
		Masonry.quad(part,back+start,back+outer0,front+outer0,front+start,axis*sin(p)-Vector3.UP*cos(p))
		Masonry.quad(part,back+end,back+outer1,front+outer1,front+end,-axis*sin(q)+Vector3.UP*cos(q))
