extends RefCounted
const Bronze = preload("res://scripts/bronze_river_bridge.gd")
const Iron = preload("res://scripts/iron_river_bridge.gd")

static func set_period(crossing: Node3D, age: int) -> void:
	var period := age if age in [1,2] else 0
	if crossing.get_meta("crossing_visual_period",0) == period:
		return
	var span: Node3D
	if period > 0:
		span = crossing.get_node_or_null("BronzeTimberBridge" if period == 1 else "IronArchBridge")
		if span == null:
			var stretch := crossing.transform.basis.get_scale().abs()
			var length_m := stretch.x * 2.55
			if period == 1:
				span = Bronze.create_span(length_m,minf(stretch.z,4.8),0.82,2)
			else:
				span = Iron.create_span(length_m,minf(stretch.z,5.4),1.25,2)
			span.scale = Vector3.ONE / stretch
			crossing.add_child(span)
	for child: Node in crossing.get_children():
		if child is Node3D:
			if child.name in ["BronzeTimberBridge","IronArchBridge"]:
				child.visible = child == span
			else:
				child.visible = period == 0
	crossing.set_meta("crossing_visual_period",period)

