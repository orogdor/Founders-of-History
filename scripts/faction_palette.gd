extends RefCounted

const Setup = preload("res://scripts/world_setup.gd")
static var current: Array[String] = []

static func use_campaign(state: Dictionary) -> bool:
	var next: Array[String] = []
	if state.has("factionColors"):
		next = Setup.colors(state)
	if next == current:
		return false
	current = next
	return true

static func color(team: int, fallback: Color) -> Color:
	return Color(current[team]) if team >= 0 and team < current.size() else fallback
