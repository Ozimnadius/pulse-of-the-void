extends Control

signal start_requested
signal menu_requested
signal sound_requested
signal exit_requested

const DOCK = preload("res://art/dock.png")
const CREAM = Color("#f1efdf")
const AMBER = Color("#f2bc71")
const MINT = Color("#9edacb")
const MUTED = Color("#abbab6")
var title_font = SystemFont.new()
var text_font = SystemFont.new()
var code_font = SystemFont.new()
var sound_button: Button
var start_button: Button
var leave_button: Button
var ending_route = ""

func _ready() -> void:
	title_font.font_names = PackedStringArray(["Segoe UI", "DejaVu Sans"])
	title_font.font_weight = 700
	text_font.font_names = title_font.font_names
	code_font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono"])
	start_button = add_button("Начать игру", 416, start_requested.emit)
	sound_button = add_button("", 483, sound_requested.emit)
	leave_button = add_button("Выход", 550, _leave_screen)
	set_sound_enabled(true)
	show_title()

func show_title() -> void:
	ending_route = ""
	show()
	start_button.text = "Начать игру"
	start_button.position = Vector2(85, 416)
	sound_button.show()
	leave_button.text = "Выход"
	leave_button.position = Vector2(85, 550)
	set_navigation([start_button, sound_button, leave_button])
	queue_redraw()

func show_ending(route: String) -> void:
	ending_route = route
	show()
	var x = 729 if route == "home" else 85
	start_button.text = "Сыграть заново"
	start_button.position = Vector2(x, 466)
	sound_button.hide()
	leave_button.text = "В главное меню"
	leave_button.position = Vector2(x, 533)
	set_navigation([start_button, leave_button])
	queue_redraw()

func _leave_screen() -> void:
	if ending_route.is_empty():
		exit_requested.emit()
	else:
		menu_requested.emit()

func set_navigation(buttons: Array) -> void:
	for i in buttons.size():
		var button: Button = buttons[i]
		button.focus_neighbor_top = button.get_path_to(buttons[posmod(i-1, buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(buttons[(i+1) % buttons.size()])
	start_button.grab_focus()

func set_sound_enabled(enabled: bool) -> void:
	sound_button.text = "Звук включён" if enabled else "Звук выключен"

func box(fill: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 24
	return style

func add_button(caption: String, y: float, action: Callable) -> Button:
	var button = Button.new()
	button.text = caption
	button.position = Vector2(85, y)
	button.size = Vector2(292, 53)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", text_font)
	button.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed"]:
		var fill = Color("#152629") if state == "normal" else Color("#334342")
		button.add_theme_stylebox_override(state, box(fill, Color("#475750")))
	var focus = box(Color.TRANSPARENT, AMBER)
	focus.draw_center = false
	focus.border_width_left = 4
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_focus_color", AMBER)
	button.pressed.connect(action)
	button.mouse_entered.connect(button.grab_focus)
	add_child(button)
	return button

func _draw() -> void:
	if not ending_route.is_empty():
		draw_ending()
		return
	draw_texture_rect(DOCK, Rect2(-330, -4, 1616, 808), false)
	draw_rect(Rect2(0,0,1280,800), Color(0.015,0.035,0.045,0.16))
	var dark = Color(0.027,0.065,0.077,0.98)
	var shade = Color(0.027,0.065,0.077,0.94)
	draw_rect(Rect2(0,0,360,800),dark)
	draw_polygon(PackedVector2Array([Vector2(360,0),Vector2(947,0),Vector2(858,800),Vector2(360,800)]),
		PackedColorArray([dark,Color(shade,0),Color(shade,0),dark]))
	draw_polyline(PackedVector2Array([Vector2(85,122),Vector2(98,122),Vector2(104,106),Vector2(112,137),Vector2(119,119),Vector2(133,119)]), AMBER, 2.5, true)
	draw_string(code_font, Vector2(150,128), "ОРИОН   /   3801", HORIZONTAL_ALIGNMENT_LEFT,-1,18,MINT)
	draw_string(title_font, Vector2(80,242), "Пульс", HORIZONTAL_ALIGNMENT_LEFT,-1,87,CREAM)
	draw_string(title_font, Vector2(80,326), "Пустоты", HORIZONTAL_ALIGNMENT_LEFT,-1,87,CREAM)
	draw_string(text_font, Vector2(86,376), "Первая ночь на Дальнем причале", HORIZONTAL_ALIGNMENT_LEFT,-1,24,MUTED)
	draw_string(code_font, Vector2(85,727), "↑ ↓  Выбор      Enter  Подтвердить", HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)

func draw_ending() -> void:
	var home = ending_route == "home"
	var x = 729 if home else 85
	var solid = Color("#101e23")
	var clear = Color(solid, 0)
	var fade_start = 697 if home else 510
	var fade_end = 357 if home else 850
	draw_rect(Rect2(0,0,1280,800), Color(0.02,0.04,0.05,0.16))
	if home:
		draw_rect(Rect2(fade_start,0,1280-fade_start,800),solid)
	else:
		draw_rect(Rect2(0,0,fade_start,800),solid)
	draw_polygon(PackedVector2Array([Vector2(fade_start,0),Vector2(fade_end,0),
		Vector2(fade_end,800),Vector2(fade_start,800)]),PackedColorArray([solid,clear,clear,solid]))
	var accent = MINT if home else AMBER
	draw_line(Vector2(x,163),Vector2(x+46,163),accent,3)
	draw_string(code_font,Vector2(x,200),"ПРОХОЖДЕНИЕ ЗАВЕРШЕНО",HORIZONTAL_ALIGNMENT_LEFT,-1,19,accent)
	var heading = ["Кабель для", "второй линии"] if home else ["Первый свет", "на борту"]
	for i in heading.size():
		draw_string(title_font,Vector2(x-3,274+i*60),heading[i],HORIZONTAL_ALIGNMENT_LEFT,-1,59,CREAM)
	var lines = ["Люди провели ночь в тепле. Нина помогла", "вам достать кабель из служебного люка."] if home else ["Вы починили разъём. Из столовой вышли", "посмотреть, как зажёгся свет в грузовом отсеке."]
	for i in lines.size():
		draw_string(text_font,Vector2(x,386+i*31),lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,22,MUTED)
	draw_string(code_font,Vector2(x,697),"↑ ↓  Выбор      Enter  Подтвердить",HORIZONTAL_ALIGNMENT_LEFT,-1,16,MUTED)
