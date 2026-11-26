extends RefCounted

const SIZES := {
	"small": Vector2i(120, 90),
	"standard": Vector2i(220, 165),
	"large": Vector2i(280, 210),
}
const MAX_OPPONENTS := 3
const PALETTE := {
	"276bd1": "Sinine",
	"c43d43": "Punane",
	"9271ce": "Lilla",
	"d2a12e": "Kuldne",
	"35a082": "Smaragdroheline",
	"e07839": "Oranž",
	"d075a5": "Roosa",
	"b5bdcf": "Hõbedane",
}
const DEFAULT_COLORS := ["276bd1", "c43d43", "9271ce", "d2a12e"]

static func size_id(state: Dictionary) -> String:
	var value := str(state.get("worldSize", "standard"))
	return value if SIZES.has(value) else "standard"

static func dimensions(state: Dictionary) -> Vector2i:
	return SIZES[size_id(state)]

static func opponent_count(state: Dictionary) -> int:
	var count: Variant = state.get("opponentCount", MAX_OPPONENTS)
	if (count is int or count is float) and is_finite(float(count)):
		return clampi(int(count), 0, MAX_OPPONENTS)
	return MAX_OPPONENTS

static func colors(state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var saved: Variant = state.get("factionColors", [])
	for team in MAX_OPPONENTS + 1:
		var color := str(saved[team]) if saved is Array and team < saved.size() else str(DEFAULT_COLORS[team])
		if not PALETTE.has(color) or color in result:
			for candidate in PALETTE:
				if candidate not in result:
					color = candidate
					break
		result.append(color)
	return result
