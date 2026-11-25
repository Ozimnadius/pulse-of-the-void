extends Node2D

const Walker = preload("res://walker.gd")
const Freight = preload("res://freight.gd")
const COLORS = [Color.WHITE, Color("#59a9b1"), Color("#b17f94"), Color("#7b91b3"),
	Color("#77a06e"), Color("#c5ab6c"), Color("#9e83b4"), Color("#c0c6ca")]
# Каждая пара точек задаёт короткий проход по свободному полу в пределах одного отсека.
const ARRIVAL = {
	2: [Vector2(602,205), Vector2(618,199)], 3: [Vector2(652,180), Vector2(652,191)],
	4: [Vector2(631,197), Vector2(635,189)], 5: [Vector2(722,182), Vector2(747,182)],
	6: [Vector2(612,190), Vector2(600,190)], 7: [Vector2(694,172), Vector2(705,172)]
}
const HOME = {
	1: [Vector2(173,142)], 4: [Vector2(102,146), Vector2(121,146)],
	6: [Vector2(195,133), Vector2(161,138)], 7: [Vector2(91,325), Vector2(111,325)]
}
const SHOP = {
	5: [Vector2(515,130)], 3: [Vector2(421,143), Vector2(451,143)],
	4: [Vector2(137,326), Vector2(153,326)], 6: [Vector2(181,383), Vector2(197,383)],
	2: [Vector2(55,373), Vector2(70,374)], 1: [Vector2(105,344), Vector2(123,346)]
}
# Два коротких обмена репликами для каждой обстановки, по очереди.
const LINES = {
	"arrival": [[2,4,"Это всё, что унесли?","Ещё плед. Держи край."],
		[5,7,"Долго здесь стоим?","Пока горят огни у трапа."]],
	"home": [[4,6,"Можно у окна?","Ложись. Тут уже тепло."],
		[6,4,"Слышишь? Уснул.","Тише. Пусть поспит."]],
	"shop": [[2,1,"Здесь оставим одеяла?","Сверни. Скоро завтрак."],
		[1,2,"Ночь на лавке — та ещё.","Зато чай ещё горячий."]]
}
@onready var game = get_parent().get_parent()
var people: Dictionary = {}
var paths: Dictionary
var scene_key := ""
var targets: Dictionary = {}
var waits: Dictionary = {}
var time := 0.0
var speaker := -1
var line := ""

func populate(key: String) -> void:
	for actor in people.values():
		remove_child(actor)
		actor.queue_free()
	people.clear()
	targets.clear()
	waits.clear()
	scene_key = key
	time = 0.0
	speaker = -1
	line = ""
	if key == "supply":
		paths = supply_paths()
	else:
		paths = {"arrival": ARRIVAL, "home": HOME, "shop": SHOP}[key]
	add_walker(0, game.player)
	for id in paths:
		add_walker(id, paths[id][0])
		targets[id] = 1
		waits[id] = fmod(id * 0.71, 3.0)

func supply_paths() -> Dictionary:
	var trip = game.supply
	match trip.place:
		trip.Place.PASSAGE:
			if game.route == "home":
				return {1: [trip.STORE_GATE + Vector2(-18, -3)]} if trip.access_ready else {1: [trip.SERVICE_PANEL + Vector2(22, -4)]}
		trip.Place.STORE:
			if game.route == "home":
				return {1: [trip.SERVICE_EXIT + Vector2(-15, -2)]}
		trip.Place.DOCK:
			var result := {5: [Vector2(515,130)], 6: [Vector2(160,143),Vector2(185,137)]}
			if game.route == "home" and not trip.access_ready:
				result[1] = [game.HATCH + Vector2(-18, -2)]
			if trip.delivered & trip.RATIONS:
				result[2] = [Vector2(270,327), Vector2(294,350)]
				result[4] = [Vector2(284,334), Vector2(310,308)]
			if trip.delivered & trip.HEATER:
				result[7] = [Vector2(139,310), Vector2(149,310)]
			return result
	return {}

func add_walker(id: int, start: Vector2) -> void:
	var actor := Walker.new()
	add_child(actor)
	actor.setup(start, COLORS[id], id == 0)
	if scene_key == "supply" and id in [0,2,4]:
		var freight := Freight.new()
		freight.trip = game.supply
		freight.cart = id == 0 and game.route == "shop" and game.supply.access_ready
		freight.ration_worker = id != 0
		actor.add_child(freight)
		actor.set_meta("freight", freight)
	people[id] = actor

func stop_sounds() -> void:
	for actor in people.values():
		actor.footstep.stop()

func finish_scene() -> void:
	stop_sounds()
	if scene_key == "shop":
		people[2].position = Vector2(705,383)
		people[1].position = Vector2(724,377)
	for actor in people.values():
		actor.pose(12, false)

func advance(delta: float) -> void:
	people[0].follow(game.player, game.running)
	if scene_key == "supply":
		for id in [0,2,4]:
			if people.has(id):
				people[id].get_meta("freight").queue_redraw()
	speaker = -1
	line = ""
	var pair: Array = []
	if game.modal == "" and game.phase != game.Phase.NIGHT:
		time += delta
		var beat := fmod(time, 16.0)
		if LINES.has(scene_key) and beat >= 2.0 and beat < 8.5:
			pair = LINES[scene_key][floori(time / 16.0) % 2]
			if beat < 5.0 or beat >= 5.4:
				var turn := int(beat >= 5.4)
				speaker = pair[turn]
				line = pair[turn + 2]
	for id in paths:
		var actor: Walker = people[id]
		var dest := actor.position
		if game.modal == "" and game.phase != game.Phase.NIGHT:
			if scene_key == "home" and id == 1:
				dest = game.guide
			elif not pair.is_empty() and (id == pair[0] or id == pair[1]):
				var other: Walker = people[pair[1] if id == pair[0] else pair[0]]
				actor.heading = (other.position - dest).normalized()
			elif paths[id].size() > 1:
				waits[id] -= delta
				if waits[id] <= 0:
					var end: Vector2 = paths[id][targets[id]]
					dest = dest.move_toward(end, delta * (24.0 + id))
					if dest == end:
						targets[id] = 1 - targets[id]
						waits[id] = 3.5 + id * 0.4
		actor.follow(dest)
