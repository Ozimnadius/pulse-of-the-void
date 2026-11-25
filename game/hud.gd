extends Node2D

const INK = Color("#0e1b21")
const PANEL = Color("#15252a")
const LINE = Color("#34464a")
const WHITE = Color("#f2efdf")
const QUIET = Color("#a7b8b5")
const GOLD = Color("#f4bf78")
const MINT = Color("#9adfcd")
var normal = SystemFont.new()
var heavy = SystemFont.new()
var mono = SystemFont.new()
@onready var game = get_parent()

func _ready() -> void:
	normal.font_names = PackedStringArray(["Segoe UI", "DejaVu Sans"])
	heavy.font_names = normal.font_names
	heavy.font_weight = 650
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono"])

func word(p: Vector2, value: String, size: int, color: Color = WHITE, font: Font = null) -> void:
	draw_string(normal if font == null else font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func rule(a: Vector2,b: Vector2) -> void:
	draw_line(a,b,LINE,1)

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,72),INK)
	draw_rect(Rect2(0,71,1280,1), LINE)
	draw_polyline(PackedVector2Array([Vector2(27,37),Vector2(36,37),Vector2(42,24),Vector2(48,50),Vector2(54,33),Vector2(61,33)]),GOLD,2.5,true)
	word(Vector2(79,32),"ПУЛЬС ПУСТОТЫ",21,WHITE,heavy)
	word(Vector2(80,53),"ОРИОН  /  3801",13,QUIET,mono)
	rule(Vector2(304,16),Vector2(304,56))
	var second_day: bool = game.phase == game.Phase.SUPPLY
	var supply = game.supply
	var home: bool = game.route == "home"
	word(Vector2(329,43),supply.location_name(home) if second_day else "Дальний причал",22,WHITE,heavy)
	var morning: bool = game.phase >= game.Phase.MORNING
	var moment = "06:12   УТРО" if morning else ("23:40   НОЧЬ" if game.phase == game.Phase.NIGHT else "19:46   ВЕЧЕР")
	if second_day:
		moment = "10:20   ДЕНЬ"
	word(Vector2(885,43),moment,16,MINT if morning else GOLD,mono)
	rule(Vector2(1036,20),Vector2(1036,52))
	var day = "ДЕНЬ 02" if morning else "ДЕНЬ 01"
	word(Vector2(1062,43),day,16,QUIET,mono)
	draw_arc(Vector2(1231,35),13,-PI*0.8,PI*0.8,30,LINE,1.3,true)
	draw_arc(Vector2(1231,35),7,0,TAU,22,MINT,1.2,true)
	draw_circle(Vector2(1231,35),2,MINT)
	if game.modal == "" and game.phase != game.Phase.NIGHT:
		draw_conversation()
		if not second_day or supply.place == supply.Place.DOCK:
			tag(Vector2(72,319),"ЖИЛАЯ СЕКЦИЯ")
			tag(Vector2(502,318),"МАСТЕРСКАЯ")
			tag(Vector2(47,636),"СТОЛОВАЯ")
			tag(Vector2(995,601),"ГРУЗОВОЙ ОТСЕК")
			if second_day and not home:
				tag(Vector2(1106,287),"ПЛОЩАДКА →",MINT)
			if second_day and supply.delivered & supply.RATIONS:
				tag(Vector2(326,563),"РАЗДАЧА ПАЙКОВ",GOLD)
			if second_day and supply.delivered & supply.HEATER:
				tag(Vector2(75,463),"ГОТОВЯТ ОБЕД",MINT)
		elif supply.place == supply.Place.STORE:
			if supply.stock() & supply.RATIONS:
				landmark(supply.FOOD_PALLET,"ЯЩИК ПАЙКОВ",GOLD)
			if supply.stock() & supply.HEATER:
				landmark(supply.HEATER_PALLET,"НАГРЕВАТЕЛЬ",MINT)
			landmark(supply.SERVICE_EXIT if home else supply.LOADING_EXIT,"К ГАЛЕРЕЕ" if home else "К ПЛОЩАДКЕ")
		elif supply.place == supply.Place.HOLD:
			landmark(supply.HOLD_RAMP,"К ТРАПУ")
			landmark(supply.HOLD_DOOR,"НА ПЛОЩАДКУ")
		else:
			if not home:
				tag(Vector2(12,333),"← ПРИЧАЛ",MINT)
			landmark(supply.passage_entry(home),"К ПРИЧАЛУ" if home else "В ТРЮМ")
			landmark(supply.passage_gate(home),"СЛУЖЕБНАЯ ДВЕРЬ" if home else "ВОРОТА СКЛАДА")
		if game.phase == game.Phase.ARRIVAL:
			tag(Vector2(890,169),"ЭВАКУАЦИОННЫЙ РЕЙС",GOLD)
			if game.player.distance_to(Vector2(682,191)) < 40 and game.inspected.is_empty():
				tag(game.player*4.0/3.0+Vector2(-16,27),"ВЫ", MINT)
		var target: String = game.nearest()
		for point in game.points():
			if point[0] == target:
				var caption = "F  " + point[2]
				if target == "repair":
					caption = "Удерживайте F"
				var width = normal.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+24
				var anchor: Vector2 = game.player * 4.0/3.0 + Vector2(0,72)
				var off_room: bool = second_day and supply.place != supply.Place.DOCK
				tag(Vector2(clampf(anchor.x-width/2,8,1265-width),anchor.y + (63 if off_room else -52)),caption,WHITE,16)
	draw_rect(Rect2(0,712,1280,88),INK)
	draw_rect(Rect2(0,712,1280,1), LINE)
	draw_rect(Rect2(26,732,3,47),GOLD if not morning else MINT)
	var kicker = "ПРИБЫТИЕ  /  ВЫ В СПИСКЕ ПАССАЖИРОВ"
	if game.phase == game.Phase.ARRIVAL and game.inspected.size() != 0:
		kicker = "ОСМОТР ТЕРМИНАЛА  /  %d ИЗ 2" % game.inspected.size()
	if morning:
		kicker = "УТРО  /  " + ("ТЁПЛЫЕ КОЙКИ" if game.route == "home" else "НОЧЛЕГ В СТОЛОВОЙ")
	if game.phase == game.Phase.FINISHED:
		kicker = "ПЕРВАЯ СМЕНА ЗАВЕРШЕНА"
	if second_day:
		var vehicle = "ТЕЛЕЖКА" if supply.pushing(game.route) else "В РУКАХ"
		if not home and supply.cart.parked:
			vehicle = "ТЕЛЕЖКА У КУХНИ"
		kicker = "СНАБЖЕНИЕ  /  %s · %s" % [vehicle, supply.load_name(supply.carried).to_upper()]
	word(Vector2(44,748),kicker,13,MINT if morning else GOLD,mono)
	word(Vector2(44,778),game.objective(),24,WHITE,heavy)
	rule(Vector2(700,730),Vector2(700,782))
	word(Vector2(724,748),"WASD / стрелки — ходьба     F — действие",16,WHITE)
	word(Vector2(724,775),"Esc — пауза     R — заново     M — звук " + ("выкл." if game.muted else "вкл."),15,QUIET)
	if game.phase == game.Phase.NIGHT:
		var a = minf(0.93,game.night_time*0.64)
		draw_rect(Rect2(0,72,1280,640), Color(0.025,0.062,0.077,a))
		if game.night_time > 0.8:
			word(Vector2(410,344),"ДАЛЬНИЙ ПРИЧАЛ    /    23:40",17,GOLD,mono)
			word(Vector2(410,397),"Транспорт уходит",42,WHITE,heavy)
			word(Vector2(410,441),"Ночью ток пойдёт в " + ("жилую секцию." if game.route == "home" else "мастерскую."),22,QUIET)
	match game.modal:
		"choice":
			draw_choice()
		"note":
			draw_note()
		"restart":
			draw_restart()

func draw_conversation() -> void:
	var residents = game.residents
	if residents.speaker < 0:
		return
	var speaker_pos: Vector2 = residents.people[residents.speaker].position
	if game.player.distance_to(speaker_pos) > 205.0:
		return
	var tip: Vector2 = game.get_node("Deck").to_global(speaker_pos + Vector2(0, -43))
	var width := normal.get_string_size(residents.line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18
	var box := Rect2(clampf(tip.x - width / 2, 6, 1274 - width), tip.y - 34, width, 27)
	draw_rect(box, PANEL)
	draw_rect(box, LINE, false, 1)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-5,-8), tip + Vector2(5,-8)]), PANEL)
	word(box.position + Vector2(9,19), residents.line, 15)

func tag(p: Vector2, caption: String, color: Color = QUIET, size: int = 12) -> void:
	var font = mono if size == 12 else normal
	var width = ceilf(font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x) + 16
	draw_rect(Rect2(p+Vector2(0,-size-4),Vector2(width,size+10)),Color(0.045,0.083,0.098,0.91))
	word(p+Vector2(8,0),caption,size,color,font)

func landmark(point: Vector2, caption: String, color: Color = QUIET) -> void:
	var foot: Vector2 = game.get_node("Deck").to_global(point)
	var width := mono.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x + 16
	tag(Vector2(clampf(foot.x-width/2,8,1272-width),foot.y+31),caption,color)

func frame(r: Rect2) -> void:
	draw_rect(r,INK)
	draw_rect(r,LINE,false,1)
	draw_line(r.position,r.position+Vector2(64,0),GOLD,3)

func option_rect(index: int) -> Rect2:
	return Rect2(250+index*402,366,378,119)

func draw_choice() -> void:
	draw_rect(Rect2(0,72,1280,640),Color(0.018,0.044,0.052,0.70))
	frame(Rect2(220,211,840,347))
	word(Vector2(250,252),"РАСПРЕДЕЛИТЕЛЬ  /  РЕЗЕРВНЫЙ КОНТУР",15,GOLD,mono)
	word(Vector2(250,305),"Куда подать питание на ночь?",35,WHITE,heavy)
	word(Vector2(250,339),"После отстыковки транспорта останется ток для одной линии.",19,QUIET)
	for i in 2:
		var r = option_rect(i)
		var active: bool = i == game.selection
		draw_rect(r,Color("#243832") if active else PANEL)
		draw_rect(r,GOLD if active else LINE,false,2 if active else 1)
		word(r.position+Vector2(18,28),("01" if i==0 else "02")+"  /  ЛИНИЯ",14,GOLD if active else QUIET,mono)
		word(r.position+Vector2(18,63),"Жилая секция" if i==0 else "Мастерская",26,WHITE,heavy)
		word(r.position+Vector2(18,95),"Люди уснут в тепле." if i==0 else "Утром заработает верстак.",18,QUIET)
	word(Vector2(250,527),"← →  Выбор      Enter  Подать питание      Esc  Отойти",16,QUIET,mono)

func note_rect() -> Rect2:
	return Rect2(188,489,904,202)

func draw_note() -> void:
	var r = note_rect()
	frame(r)
	word(r.position+Vector2(26,30),"ЖУРНАЛ ПРИЧАЛА",13,GOLD,mono)
	word(r.position+Vector2(26,69),game.note_title,29,WHITE,heavy)
	for i in game.note_body.size():
		word(r.position+Vector2(26,106+i*27),game.note_body[i],20,QUIET)
	rule(r.position+Vector2(26,153), r.position+Vector2(878,153))
	word(r.position+Vector2(26,182),"F  Дальше",16,MINT,mono)

func draw_restart() -> void:
	draw_rect(Rect2(0,72,1280,640),Color(0.018,0.044,0.052,0.67))
	frame(Rect2(339,282,602,182))
	word(Vector2(370,327),"ПОВТОРНОЕ ПРОХОЖДЕНИЕ",14,GOLD,mono)
	word(Vector2(370,376),"Вернуться к прибытию?",30,WHITE,heavy)
	word(Vector2(370,428),"Enter  Сначала       Esc  Продолжить",17,MINT,mono)
