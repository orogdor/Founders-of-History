extends RefCounted

const WINDOW_MINUTES := 3
const HISTORY := "resourceFlows"

static func observe(realm: Dictionary, seconds: float) -> void:
	if not realm.has(HISTORY):
		realm[HISTORY] = {"start": seconds, "lastMinute": -1, "minutes": {}}

static func record(realm: Dictionary, seconds: float, key: String, change: float) -> void:
	if not realm.has(HISTORY) or change == 0.0:
		return
	var history: Dictionary = realm[HISTORY]
	# Production and household use at the end of a minute belong to that minute.
	var minute := floori(maxf(0.0,seconds-0.000001)/60.0)
	var periods: Dictionary = history.minutes
	if minute > int(history.lastMinute):
		for old in periods.keys():
			if int(old) < minute-WINDOW_MINUTES:
				periods.erase(old)
		history.lastMinute = minute
	var id := str(minute)
	if not periods.has(id):
		periods[id] = {}
	var bucket: Dictionary = periods[id]
	if not bucket.has(key):
		bucket[key] = [0.0,0.0]
	var entry: Array = bucket[key]
	var direction := 0 if change > 0.0 else 1
	entry[direction] = float(entry[direction])+absf(change)

static func consumption(realm: Dictionary, seconds: float) -> Callable:
	if not realm.has(HISTORY):
		return Callable()
	return _record_consumption.bind(realm,seconds)

static func _record_consumption(key: String, units: float, realm: Dictionary, seconds: float) -> void:
	record(realm,seconds,key,-units)

static func recent(realm: Dictionary, seconds: float) -> Dictionary:
	if not realm.has(HISTORY):
		return {"minutes":0,"rates":{}}
	var history: Dictionary = realm[HISTORY]
	var end := floori(seconds/60.0)
	var start := maxi(end-WINDOW_MINUTES,ceili(float(history.start)/60.0))
	var count := maxi(0,end-start)
	var rates := {}
	for minute in range(start,end):
		var bucket: Dictionary = history.minutes.get(str(minute),{})
		for key in bucket:
			var entry: Array = bucket[key]
			var rate: Vector2 = rates.get(key,Vector2.ZERO)
			rates[key] = rate+Vector2(float(entry[0]),float(entry[1]))/float(count)
	return {"minutes":count,"rates":rates}
