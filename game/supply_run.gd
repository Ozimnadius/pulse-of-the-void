extends RefCounted

enum Place { DOCK, PASSAGE, STORE }
const RATIONS := 1
const HEATER := 2
const BOTH := RATIONS | HEATER
const SERVICE_PANEL := Vector2(695, 228)
const GALLERY_ENTRY := Vector2(52, 268)
const SERVICE_DOOR := Vector2(752, 225)
const CART_STAND := Vector2(362, 157)
const DOCK_EXIT := Vector2(102, 144)
const STORE_GATE := Vector2(839, 134)
const SERVICE_EXIT := Vector2(51, 126)
const LOADING_EXIT := Vector2(840, 126)
const FOOD_PALLET := Vector2(210, 345)
const HEATER_PALLET := Vector2(743, 345)
const DELIVERY := Vector2(250, 328)
const CART_BAY := Vector2(256,352)
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

func snapshot() -> Dictionary:
	return {"place": place, "layout": 2, "access_ready": access_ready, "carried": carried, "delivered": delivered}

func restore(state: Dictionary) -> void:
	place = state.get("place", Place.DOCK)
	access_ready = state.get("access_ready", false)
	carried = state.get("carried", 0)
	delivered = state.get("delivered", 0)

func stock() -> int:
	return BOTH & ~(carried | delivered)

func cart_parked() -> bool:
	return place == Place.DOCK and access_ready and carried == 0

func cart_offset(foot: Vector2) -> Vector2:
	var handle_offset := Vector2(-17,2)
	if place != Place.DOCK:
		return handle_offset
	# У порога герой оставляет тележку снаружи. Забранный груз остаётся на ней.
	var kitchen := foot.clamp(Vector2(0,321), Vector2(231,406))
	var follow := clampf(foot.distance_to(kitchen)/50.0, 0.0, 1.0)
	return CART_BAY.lerp(foot + handle_offset, follow) - foot

func passage_entry(home: bool) -> Vector2:
	return GALLERY_ENTRY if home else DOCK_EXIT

func passage_gate(home: bool) -> Vector2:
	return SERVICE_DOOR if home else STORE_GATE

func floor_position(pos: Vector2, home: bool) -> Vector2:
	var areas := STORE_FLOOR if place == Place.STORE else (GALLERY_FLOOR if home else LOADING_FLOOR)
	var left := 39 if not home and access_ready else 6
	var best := Vector2.INF
	for area: Rect2 in areas:
		var candidate := pos.clamp(area.position + Vector2(left,0), area.end - Vector2(6,1))
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
		Place.PASSAGE:
			result.append(["dock", passage_entry(home), "На причал"])
			if not access_ready:
				result.append(["prepare", SERVICE_PANEL if home else CART_STAND,
					"Подключить кабель" if home else "Взять тележку"])
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
		Place.DOCK:
			if carried:
				return "Отнесите груз ко входу в столовую"
			if delivered == BOTH:
				return "Оба груза доставлены. Смена окончена"
			if delivered:
				return "На складе остался " + load_name(stock())
			return "Войдите в люк вслед за Ниной" if home else "Поднимитесь в освещённый трюм"
		Place.PASSAGE:
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

func enter(game, where: Place, spawn: Vector2) -> void:
	place = where
	game.player = spawn if where == Place.DOCK else floor_position(spawn, game.route == "home")
	game.held.clear()
	game.running = false
	game.populate_supply_scene()
	game._autosave()

func interact(game, target: String) -> void:
	var home: bool = game.route == "home"
	match target:
		"passage":
			enter(game, Place.PASSAGE, passage_entry(home) + Vector2(30, 0))
		"dock":
			enter(game, Place.DOCK, game.HATCH if home else game.RAMP)
		"prepare":
			access_ready = true
			game.populate_supply_scene()
			game._autosave()
			if home:
				game.show_note("Вторая линия под током", ["Нина придерживает крышку щита. Кабель встаёт на место.",
					"Справа щёлкает замок. «Пойдём, теперь дверь откроется»."])
			else:
				game.show_note("Тележка на ходу", ["Вы снимаете колёса с тормоза и выкатываете тележку на площадку.",
					"На платформе хватает места для двух грузов."])
		"store":
			if access_ready:
				var exit_pos := SERVICE_EXIT if home else LOADING_EXIT
				enter(game, Place.STORE, exit_pos + Vector2(0, 19))
			else:
				game.show_note("Замок обесточен" if home else "Тележка осталась в трюме",
					["Сначала подключите кабель к щиту в галерее." if home else "Снимите тележку с тормоза у левого рельса."])
		"return":
			enter(game, Place.PASSAGE, passage_gate(home) + Vector2(-20, 10))
		"food", "heater":
			if home and carried:
				game.show_note("Руки заняты", ["Отнесите первый груз на причал.", "За оставшимся можно прийти ещё раз."])
				return
			var item := RATIONS if target == "food" else HEATER
			carried |= item
			game._autosave()
		"deliver":
			delivered |= carried
			carried = 0
			game.populate_supply_scene()
			game._autosave()
