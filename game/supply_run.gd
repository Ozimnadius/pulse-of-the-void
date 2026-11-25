extends RefCounted

enum Place { DOCK, PASSAGE, STORE }
const RATIONS := 1
const HEATER := 2
const BOTH := RATIONS | HEATER
const SERVICE_PANEL := Vector2(710, 281)
const CART_STAND := Vector2(316, 337)
const DOCK_EXIT := Vector2(98, 317)
const STORE_GATE := Vector2(870, 277)
const SERVICE_EXIT := Vector2(78, 190)
const LOADING_EXIT := Vector2(848, 190)
const FOOD_PALLET := Vector2(359, 325)
const HEATER_PALLET := Vector2(612, 357)
const DELIVERY := Vector2(250, 328)

var place := Place.DOCK
var access_ready := false
var carried := 0
var delivered := 0

func snapshot() -> Dictionary:
	return {"place": place, "access_ready": access_ready, "carried": carried, "delivered": delivered}

func restore(state: Dictionary) -> void:
	place = state.get("place", Place.DOCK)
	access_ready = state.get("access_ready", false)
	carried = state.get("carried", 0)
	delivered = state.get("delivered", 0)

func stock() -> int:
	return BOTH & ~(carried | delivered)

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
			result.append(["dock", DOCK_EXIT, "На причал"])
			if not access_ready:
				result.append(["prepare", SERVICE_PANEL if home else CART_STAND,
					"Подключить кабель" if home else "Взять тележку"])
			result.append(["store", STORE_GATE, "С Ниной на склад" if home else "На склад через ворота"])
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
	game.player = spawn
	game.held.clear()
	game.running = false
	game.populate_supply_scene()
	game._autosave()

func interact(game, target: String) -> void:
	var home: bool = game.route == "home"
	match target:
		"passage":
			enter(game, Place.PASSAGE, DOCK_EXIT + Vector2(30, 0))
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
			enter(game, Place.PASSAGE, STORE_GATE + Vector2(-30, 0))
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
