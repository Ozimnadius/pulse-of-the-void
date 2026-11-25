extends RefCounted

enum Place { DOCK, PASSAGE, STORE, HOLD }
const Handcart = preload("res://handcart.gd")
const RATIONS := 1
const HEATER := 2
const BOTH := RATIONS | HEATER
const SERVICE_PANEL := Vector2(695, 228)
const GALLERY_ENTRY := Vector2(52, 268)
const SERVICE_DOOR := Vector2(752, 225)
const CART_STAND := Vector2(313, 225)
const HOLD_RAMP := Vector2(108, 243)
const HOLD_DOOR := Vector2(818, 246)
const HOLD_FLOOR := [Rect2(86,191,750,102)]
const DOCK_EXIT := Vector2(102, 144)
const STORE_GATE := Vector2(839, 134)
const SERVICE_EXIT := Vector2(51, 126)
const LOADING_EXIT := Vector2(840, 126)
const FOOD_PALLET := Vector2(210, 345)
const HEATER_PALLET := Vector2(743, 345)
const DELIVERY := Vector2(250, 328)
const CART_BAY := Vector2(256,352)
const DOCK_APPROACH := Rect2(232,183,404,32)
const DOCK_BRIDGE := Rect2(629,168,387,48)
const PLATFORM_BRIDGE := Rect2(-60,199,181,48)
const GALLERY_FLOOR := [
	Rect2(29,262,903,32), Rect2(74,222,858,69), Rect2(734,216,36,60)
]
# Перекрывающиеся проходы задают обходы трёх стеллажей и подходы к воротам.
const STORE_FLOOR := [
	Rect2(30,135,901,56), Rect2(30,355,901,83),
	Rect2(30,122,62,316), Rect2(284,135,86,303),
	Rect2(591,135,85,303), Rect2(870,135,61,303),
	Rect2(763,122,152,69)
]
const LOADING_FLOOR := [
	Rect2(23,146,913,171), Rect2(81,128,59,39), Rect2(771,115,142,69)
]

var place := Place.DOCK
var access_ready := false
var carried := 0
var delivered := 0
var cart := Handcart.new()

func snapshot() -> Dictionary:
	return {"place": place, "layout": 3, "access_ready": access_ready, "carried": carried, "delivered": delivered,
		"cart_angle": cart.angle, "parked": cart.parked, "parking_spot": cart.parking_spot}

func restore(state: Dictionary) -> void:
	place = state.get("place", Place.DOCK)
	access_ready = state.get("access_ready", false)
	carried = state.get("carried", 0)
	delivered = state.get("delivered", 0)
	cart.angle = state.get("cart_angle", PI)
	cart.rolled = 0.0
	cart.parked = state.get("parked", place == Place.DOCK and access_ready and not carried)
	cart.parking_spot = state.get("parking_spot", CART_BAY)

func stock() -> int:
	return BOTH & ~(carried | delivered)

func pushing(route: String) -> bool:
	return route == "shop" and access_ready and not cart.parked

func passage_entry(home: bool) -> Vector2:
	return GALLERY_ENTRY if home else DOCK_EXIT

func passage_gate(home: bool) -> Vector2:
	return SERVICE_DOOR if home else STORE_GATE

func floor_position(pos: Vector2, home: bool) -> Vector2:
	var areas := STORE_FLOOR
	if place == Place.HOLD:
		areas = HOLD_FLOOR
	elif place == Place.PASSAGE:
		areas = GALLERY_FLOOR if home else LOADING_FLOOR
		if not home and PLATFORM_BRIDGE.has_point(pos):
			return pos
	var best := Vector2.INF
	for area: Rect2 in areas:
		var candidate := pos.clamp(area.position + Vector2(3,0), area.end - Vector2(3,1))
		if candidate == pos:
			return pos
		if pos.distance_squared_to(candidate) < pos.distance_squared_to(best):
			best = candidate
	return best

func restore_position(pos: Vector2, home: bool, old_layout: bool) -> Vector2:
	if place == Place.DOCK:
		return pos
	if old_layout:
		var landmarks := {
			Vector2(78,190): SERVICE_EXIT, Vector2(848,190): LOADING_EXIT,
			Vector2(359,325): FOOD_PALLET, Vector2(612,357): HEATER_PALLET
		} if place == Place.STORE else {
			Vector2(98,317): passage_entry(home), Vector2(870,277): passage_gate(home),
			Vector2(710,281) if home else Vector2(316,337): SERVICE_PANEL if home else CART_STAND
		}
		for old: Vector2 in landmarks:
			if old.distance_to(pos) < 48:
				pos += Vector2(landmarks[old]) - old
				break
	return floor_position(pos, home)

func load_name(load_mask: int) -> String:
	return ["пусто", "ящик пайков", "нагреватель", "пайки и нагреватель"][load_mask]

func location_name(home: bool) -> String:
	match place:
		Place.HOLD:
			return "Освещённый трюм"
		Place.PASSAGE:
			return "Служебная галерея" if home else "Погрузочная площадка"
		Place.STORE:
			return "Старый грузовой склад"
	return "Дальний причал"

func points(game) -> Array:
	var home: bool = game.route == "home"
	var result := []
	match place:
		Place.DOCK:
			result.append(["passage", game.HATCH if home else game.RAMP,
				"В служебную галерею" if home else "В освещённый трюм"])
			if carried:
				result.append(["deliver", DELIVERY, "Передать груз жителям"])
			if not home and cart.parked:
				result.append(["hitch", cart.grip_position(), "Взяться за рукоять"])
		Place.HOLD:
			result.append(["ramp", HOLD_RAMP, "Выйти на трап"])
			result.append(["platform", HOLD_DOOR, "На погрузочную площадку"])
			if not access_ready:
				result.append(["prepare", CART_STAND, "Взять тележку"])
		Place.PASSAGE:
			result.append(["dock" if home else "hold", passage_entry(home), "На причал" if home else "В грузовой трюм"])
			if home and not access_ready:
				result.append(["prepare", SERVICE_PANEL, "Подключить кабель"])
			result.append(["store", passage_gate(home), "С Ниной на склад" if home else "На склад через ворота"])
		Place.STORE:
			result.append(["return", SERVICE_EXIT if home else LOADING_EXIT,
				"В служебную галерею" if home else "На погрузочную площадку"])
			if stock() & RATIONS:
				result.append(["food", FOOD_PALLET, "Взять ящик пайков"])
			if stock() & HEATER:
				result.append(["heater", HEATER_PALLET, "Взять нагреватель"])
	return result

func objective(home: bool) -> String:
	match place:
		Place.HOLD:
			return "Пройдите к боковому шлюзу" if access_ready else "Заберите тележку из трюма"
		Place.DOCK:
			if carried:
				return "Отнесите груз ко входу в столовую"
			if delivered == BOTH:
				return "Оба груза доставлены. Смена окончена"
			if delivered:
				return "На складе остался " + load_name(stock())
			if not home and access_ready:
				return "Идите по настилу на площадку"
			return "Войдите в люк вслед за Ниной" if home else "Поднимитесь в освещённый трюм"
		Place.PASSAGE:
			if not home and cart.parked:
				return "Заберите тележку у столовой"
			if carried or delivered == BOTH:
				return "Вернитесь на причал через левый выход"
			if not access_ready:
				return "Подключите кабель к щиту" if home else "Заберите тележку из трюма"
			return "Откройте с Ниной служебную дверь" if home else "Провезите тележку через ворота"
		Place.STORE:
			if not stock() or (home and carried):
				return "Вернитесь к Нине у двери" if home else "Вернитесь к погрузочным воротам"
			if carried:
				return "Возьмите второй груз или возвращайтесь"
			return "Заберите " + load_name(stock()) if delivered else "Выберите груз для причала"
	return ""

func enter(game, where: Place, spawn: Vector2, walking := false, facing := NAN) -> void:
	place = where
	game.player = spawn if where == Place.DOCK else floor_position(spawn, game.route == "home")
	if pushing(game.route):
		if is_finite(facing):
			cart.angle = facing
		cart.align_at_entry(game)
	if not walking:
		game.held.clear()
	game.running = false
	game.populate_supply_scene()
	game._autosave()

func interact(game, target: String) -> void:
	var home: bool = game.route == "home"
	match target:
		"passage":
			if home:
				enter(game, Place.PASSAGE, GALLERY_ENTRY + Vector2(30, 0))
			else:
				enter(game, Place.HOLD, HOLD_RAMP + Vector2(30, 0))
		"hold":
			enter(game, Place.HOLD, HOLD_DOOR - Vector2(25,0), false, PI)
		"platform":
			enter(game, Place.PASSAGE, DOCK_EXIT + Vector2(20,16), false, 0.0)
		"ramp":
			enter(game, Place.DOCK, game.RAMP, false, PI)
		"hitch":
			game.player = cart.grip_position()
			cart.parked = false
			cart.align_at_entry(game)
			game._autosave()
		"dock":
			enter(game, Place.DOCK, game.HATCH if home else game.RAMP)
		"prepare":
			access_ready = true
			if not home:
				cart.angle = 0
				game.player = CART_STAND - Vector2(Handcart.HANDLE_DISTANCE,0)
			game.populate_supply_scene()
			game._autosave()
			if home:
				game.show_note("Вторая линия под током", ["Нина придерживает крышку щита. Кабель встаёт на место.",
					"Справа щёлкает замок. «Пойдём, теперь дверь откроется»."])
			else:
				game.show_note("Тележка на ходу", ["Вы снимаете тележку с тормоза. На настил помещаются оба груза.",
					"Голубой шлюз справа ведёт на погрузочную площадку."])
		"store":
			if access_ready and (home or not cart.parked):
				var exit_pos := SERVICE_EXIT if home else LOADING_EXIT
				enter(game, Place.STORE, exit_pos + Vector2(0, 19), false, PI/2)
			elif not home and cart.parked:
				game.show_note("Тележка у столовой", ["Вернитесь по настилу и возьмитесь за рукоять."])
			else:
				game.show_note("Замок обесточен" if home else "Тележка осталась в трюме",
					["Сначала подключите кабель к щиту в галерее." if home else "Зайдите в трюм через левый шлюз и возьмите тележку."])
		"return":
			enter(game, Place.PASSAGE, passage_gate(home) + Vector2(-20, 10), false, PI/2)
		"food", "heater":
			if home and carried:
				game.show_note("Руки заняты", ["Отнесите первый груз на причал.", "За оставшимся можно прийти ещё раз."])
				return
			var item := RATIONS if target == "food" else HEATER
			carried |= item
			game._autosave()
		"deliver":
			if not home:
				cart.park(game.player)
			delivered |= carried
			carried = 0
			game.populate_supply_scene()
			game._autosave()
