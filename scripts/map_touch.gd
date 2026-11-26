extends RefCounted

var fingers: Dictionary = {}
var primary := -1
var pinching := false

func press(event: InputEventScreenTouch, host: Node) -> void:
	fingers[event.index] = event.position
	if fingers.size() == 1:
		primary = event.index
		send_button(host,event.position,true,event.double_tap)
	elif not pinching:
		pinching = true
		host.cancel_map_pointer()

func track(event: InputEvent, host: Node) -> bool:
	if event is InputEventScreenDrag and fingers.has(event.index):
		var previous: Vector2 = fingers[event.index]
		fingers[event.index] = event.position
		if pinching and fingers.size() == 2:
			var keys := fingers.keys()
			var other: Vector2 = fingers[keys[1] if keys[0] == event.index else keys[0]]
			var before := previous.distance_to(other)
			var after: float = event.position.distance_to(other)
			if before > 4.0 and after > 4.0:
				host.zoom_map_gesture((previous+other)*0.5,(event.position+other)*0.5,before/after)
		elif not pinching and event.index == primary:
			var motion := InputEventMouseMotion.new()
			motion.position = event.position
			motion.relative = event.position-previous
			host.handle_map_input(motion)
		return true
	if event is InputEventScreenTouch and not event.pressed and fingers.has(event.index):
		fingers.erase(event.index)
		if not pinching and event.index == primary:
			if event.canceled:host.cancel_map_pointer()
			else:send_button(host,event.position,false,false)
		if fingers.is_empty():
			primary = -1
			pinching = false
		return true
	return false

func send_button(host: Node, position: Vector2, pressed: bool, double_tap: bool) -> void:
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.position = position
	pointer.pressed = pressed
	pointer.double_click = double_tap
	host.handle_map_input(pointer)
