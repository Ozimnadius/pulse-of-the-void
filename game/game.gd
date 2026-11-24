extends Node2D

enum Phase { ARRIVAL, NIGHT, MORNING, FINISHED }
const BUNK = Vector2(145, 132)
const BENCH = Vector2(476, 116)
const SWITCH = Vector2(455, 371)
const HATCH = Vector2(316, 379)
const RAMP = Vector2(781, 382)
const GUIDE_START = Vector2(173, 142)
const MECHANIC = Vector2(515, 130)
const GUIDE_PATH = [Vector2(138, 144), Vector2(136, 202), Vector2(316, 216), Vector2(316, 357)]
const FLOOR = [
	Rect2(42, 186, 547, 43), Rect2(232, 213, 344, 185),
	Rect2(112, 137, 48, 59), Rect2(54, 115, 174, 41),
	Rect2(449, 133, 45, 62), Rect2(387, 105, 152, 51),
	Rect2(564, 186, 362, 19), Rect2(640, 153, 196, 43),
	Rect2(579, 191, 74, 26), Rect2(553, 352, 47, 43),
	Rect2(589, 371, 270, 18), Rect2(755, 334, 51, 50)
]

var phase = Phase.ARRIVAL
var route = ""
var inspected: Dictionary = {}
var modal = ""
var selection = 0
var note_title = ""
var note_body: Array = []
var player = Vector2(682, 191)
var guide = GUIDE_START
var guide_index = 0
var progress = 0
var repair = 0.0
var elapsed = 0.0
var night_time = 0.0
var running = false
var held := {}
var sound: AudioStreamPlayer
var tone: AudioStreamPlayer
var muted = false
var music: AudioStreamPlayer
var music_fade: Tween
const Walker = preload("res://walker.gd")
@onready var residents = $Deck/Residents

func _ready() -> void:
	$Departure.stream = preload("res://audio/departure.wav")
	$Departure.volume_db = -4.0
	$HUD.hide()
	$Deck.hide()
	$TitleMenu.start_requested.connect(_start_from_menu)
	$TitleMenu.menu_requested.connect(_return_to_menu)
	$TitleMenu.sound_requested.connect(_toggle_sound)
	$TitleMenu.exit_requested.connect(_close)
	music = AudioStreamPlayer.new()
	music.stream = preload("res://audio/dock_theme.ogg")
	music.volume_db = -48.0
	add_child(music)
	music.play()
	_fade_music(-3.0)
	sound = AudioStreamPlayer.new()
	sound.stream = preload("res://audio/terminal.wav")
	add_child(sound)
	tone = AudioStreamPlayer.new()
	tone.volume_db = -20
	add_child(tone)
	get_window().focus_exited.connect(_clear_keys)
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_close)

func _fade_music(volume: float) -> void:
	if music_fade:
		music_fade.kill()
	music_fade = create_tween()
	music_fade.tween_property(music, "volume_db", volume, 1.25)

func _start_from_menu() -> void:
	reset_game()
	$TitleMenu.hide()
	$HUD.show()
	$Deck.show()
	if not sound.playing:
		sound.play()
	_fade_music(-12.0)

func _return_to_menu() -> void:
	residents.stop_sounds()
	$Departure.stop()
	$Deck.hide()
	sound.stop()
	_fade_music(-3.0)
	$TitleMenu.show_title()

func _finish_route() -> void:
	phase = Phase.FINISHED
	held.clear()
	residents.finish_scene()
	$Deck.queue_redraw()
	$HUD.hide()
	$TitleMenu.show_ending(route)

func _toggle_sound() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	$TitleMenu.set_sound_enabled(not muted)

func _close() -> void:
	residents.stop_sounds()
	$Departure.stop()
	music.stop()
	sound.stop()
	tone.stop()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _clear_keys() -> void:
	held.clear()

func _unhandled_input(event: InputEvent) -> void:
	if $TitleMenu.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
			_toggle_sound()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos = get_local_mouse_position()
		if modal == "choice":
			for i in 2:
				if $HUD.option_rect(i).has_point(pos):
					selection = i
					choose_route()
		elif modal == "note" and $HUD.note_rect().has_point(pos):
			modal = ""
		return
	if not event is InputEventKey:
		return
	var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	held[key] = event.pressed
	if not event.pressed or event.echo:
		return
	if key == KEY_M:
		_toggle_sound()
		return
	if modal == "restart":
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_R]:
			reset_game()
		elif key in [KEY_ESCAPE, KEY_F, KEY_E]:
			modal = ""
		return
	if key == KEY_R and phase != Phase.NIGHT:
		modal = "restart"
		return
	if modal == "note":
		if key in [KEY_E, KEY_F, KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			modal = ""
		return
	if modal == "choice":
		if key in [KEY_LEFT, KEY_A, KEY_UP, KEY_W, KEY_1]:
			selection = 0
		elif key in [KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S, KEY_2]:
			selection = 1
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_F, KEY_E]:
			choose_route()
		elif key == KEY_ESCAPE:
			modal = ""
		return
	if key in [KEY_F, KEY_E, KEY_ENTER]:
		interact()

func reset_game() -> void:
	phase = Phase.ARRIVAL
	route = ""
	inspected.clear()
	modal = ""
	selection = 0
	player = Vector2(682, 191)
	guide = GUIDE_START
	guide_index = 0
	progress = 0
	repair = 0.0
	night_time = 0.0
	running = false
	$Departure.stop()
	residents.populate("arrival")
	held.clear()

func is_held(keys: Array) -> bool:
	for k in keys:
		if held.get(k, false):
			return true
	return false

func can_walk(pos: Vector2) -> bool:
	if Rect2(437, 357, 37, 50).has_point(pos) or Rect2(403, 385, 34, 18).has_point(pos):
		return false
	for area in FLOOR:
		if area.has_point(pos):
			return true
	return false

func _physics_process(delta: float) -> void:
	if $TitleMenu.visible:
		return
	elapsed += delta
	if phase == Phase.NIGHT:
		night_time += delta
		if night_time >= 3.6:
			phase = Phase.MORNING
			player = Vector2(340, 213)
			residents.populate(route)
	elif modal == "":
		var direction = Vector2(
			int(is_held([KEY_RIGHT, KEY_D])) - int(is_held([KEY_LEFT, KEY_A])),
			int(is_held([KEY_DOWN, KEY_S])) - int(is_held([KEY_UP, KEY_W])))
		running = is_held([KEY_SHIFT])
		var travel = direction.normalized() * (104.0 if running else 62.0) * delta
		travel.y *= Walker.DEPTH
		if can_walk(player + Vector2(travel.x, 0)):
			player.x += travel.x
		if can_walk(player + Vector2(0, travel.y)):
			player.y += travel.y
		if route == "home" and progress == 1 and guide_index < GUIDE_PATH.size():
			var destination: Vector2 = GUIDE_PATH[guide_index]
			if player.distance_to(guide) < 120:
				guide = guide.move_toward(destination, delta * 62)
				if guide == destination:
					guide_index += 1
		if route == "shop" and progress == 1:
			if player.distance_to(BENCH) < 34 and is_held([KEY_F, KEY_E]):
				repair = minf(1.0, repair + delta / 1.15)
				if repair >= 1.0:
					progress = 2
					chirp(610)
					show_note("Разъём обжат", ["Контакт держит. Механик протягивает вам разъём.", "Отнесите его к открытой аппарели грузовика."])
			else:
				repair = 0.0
	residents.advance(delta)
	$Deck.queue_redraw()
	$HUD.queue_redraw()

func points() -> Array:
	if phase == Phase.ARRIVAL:
		return [["home", BUNK, "Жилая секция"], ["shop", BENCH, "Мастерская"], ["switch", SWITCH, "Распределитель"], ["ship", RAMP, "Сломанный корабль"]]
	if phase == Phase.MORNING:
		if route == "home":
			if progress == 0:
				return [["guide", guide, "Нина · работница терминала"]]
			if guide_index == GUIDE_PATH.size():
				return [["hatch", HATCH, "Служебный люк"]]
			return []
		if progress == 0:
			return [["mechanic", MECHANIC, "Мирон · механик"]]
		if progress == 1:
			return [["repair", BENCH, "Обжать разъём"]]
		return [["light", RAMP, "Щит грузового отсека"]]
	return []

func nearest() -> String:
	var closest = ""
	var distance = 33.0
	for p in points():
		var d = player.distance_to(p[1])
		if d < distance:
			closest = p[0]
			distance = d
	return closest

func show_note(title: String, lines: Array) -> void:
	note_title = title
	note_body = lines
	modal = "note"

func interact() -> void:
	var target = nearest()
	if target.is_empty():
		return
	chirp(370)
	match target:
		"home":
			inspected["home"] = true
			show_note("В жилой секции холодно", ["Четыре койки. На первой кто-то оставил детскую куртку.", "Если подать питание, к ночи прогреются матрасы."])
		"shop":
			inspected["shop"] = true
			show_note("Верстак обесточен", ["В тисках зажат разъём с обгоревшим контактом.", "Механик перебирает инструменты. Ему нужен ток."])
		"switch":
			if inspected.size() == 2:
				modal = "choice"
			else:
				show_note("Один резервный контур", ["Пока причал получает ток с эвакуационного рейса.", "Осмотрите койки и верстак. Ночью придётся выбирать."])
		"ship":
			show_note("У соседнего шлюза", ["Старая грузовая машина. За аппарелью темно.", "Этот корабль останется здесь, когда эвакуационный рейс уйдёт."])
		"guide":
			progress = 1
			show_note("Нина, дежурная причала", ["«Малой впервые за трое суток проспал до утра.", "Пойдём. Я знаю, где оставили кабель для второй линии»."])
		"hatch":
			progress = 2
			_finish_route()
		"mechanic":
			progress = 1
			show_note("Мирон, механик", ["«Кто спал на скамейке, тот уже на ногах. Давай попробуем.", "Обожми контакт на верстаке. Я подержу провод»."])
		"light":
			progress = 3
			_finish_route()

func choose_route() -> void:
	route = "home" if selection == 0 else "shop"
	phase = Phase.NIGHT
	night_time = 0
	modal = ""
	held.clear()
	$Departure.play()

func chirp(hz: float) -> void:
	var wave = AudioStreamWAV.new()
	wave.mix_rate = 16000
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	var bytes = PackedByteArray()
	bytes.resize(2560)
	for i in 1280:
		var sample = sin(TAU * hz * i / 16000) * sin(PI * i / 1280)
		bytes.encode_s16(i * 2, int(sample * 13000))
	wave.data = bytes
	tone.stream = wave
	tone.play()

func objective() -> String:
	if phase == Phase.ARRIVAL:
		return "Осмотрите койки и верстак" if inspected.size() < 2 else "Выберите ночную линию у распределителя"
	if phase == Phase.NIGHT:
		return "Эвакуационный рейс отстыковался"
	if phase == Phase.FINISHED:
		return "Кабель для второй линии найден" if route == "home" else "В грузовом отсеке горит свет"
	if route == "home":
		if progress == 0:
			return "Поговорите с Ниной в жилой секции"
		return "Заберите кабель из люка" if guide_index == GUIDE_PATH.size() else "Идите за Ниной к служебному люку"
	return ["Найдите механика у верстака", "Удерживайте F у верстака", "Установите разъём у аппарели"][progress]
