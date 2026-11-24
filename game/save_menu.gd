extends ColorRect

signal resumed
signal title_requested
signal load_requested(entry: Dictionary)
signal save_requested(id: String, caption: String)

var store = preload("res://save_store.gd").new()
var page := ""
var from_title := false
var suggested := ""
var column := VBoxContainer.new()
var buttons: Array[Control] = []

func _ready() -> void:
	size = Vector2(1280, 800)
	color = Color(0.02, 0.05, 0.06, 0.84)
	var panel := Panel.new()
	panel.position = Vector2(235, 93)
	panel.size = Vector2(810, 614)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#102127")
	style.border_color = Color("#50605b")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	theme = Theme.new()
	theme.default_font = get_parent().get_node("TitleMenu").text_font
	for state in ["normal", "hover", "pressed"]:
		var surface := StyleBoxFlat.new()
		surface.bg_color = Color("#192e32") if state == "normal" else Color("#334342")
		surface.content_margin_left = 15
		surface.content_margin_right = 15
		surface.content_margin_top = 7
		surface.content_margin_bottom = 7
		theme.set_stylebox(state, "Button", surface)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("#f2bc71")
	focus.set_border_width_all(1)
	focus.border_width_left = 4
	theme.set_stylebox("focus", "Button", focus)
	column.position = Vector2(38, 30)
	column.size = Vector2(734, 552)
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	hide()

func _page(key: String, heading: String) -> void:
	page = key
	buttons.clear()
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var title := _label(heading, 32)
	title.modulate = Color("#f2bc71")
	show()

func _label(caption: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	column.add_child(label)
	return label

func _button(caption: String, action: Callable, parent: Container = null) -> Button:
	var button := Button.new()
	button.text = caption
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = caption
	button.custom_minimum_size.y = 49
	button.add_theme_font_size_override("font_size", 20)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	(parent if parent != null else column).add_child(button)
	buttons.append(button)
	return button

func _focus() -> void:
	for i in buttons.size():
		var control := buttons[i]
		var previous := control.get_path_to(buttons[posmod(i - 1, buttons.size())])
		var next := control.get_path_to(buttons[(i + 1) % buttons.size()])
		control.focus_neighbor_top = previous
		control.focus_previous = previous
		control.focus_neighbor_bottom = next
		control.focus_next = next
	buttons[0].grab_focus()

func pause_game(default_name: String, message: String = "") -> void:
	from_title = false
	suggested = default_name
	_page("pause", "Пауза")
	if not message.is_empty():
		_label(message, 19)
	_button("Вернуться в игру", resumed.emit)
	_button("Сохранить игру", list_slots.bind(true))
	_button("Загрузить игру", list_slots.bind(false))
	_button("В главное меню", title_requested.emit)
	_focus()

func load_from_title() -> void:
	from_title = true
	list_slots(false)

func list_slots(saving: bool) -> void:
	_page("save" if saving else "load", "Сохранить игру" if saving else "Загрузить игру")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 403
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 7)
	scroll.add_child(rows)
	if saving:
		_button("Создать новое", _name_slot, rows)
	for record in store.entries():
		if saving and record.id == store.AUTO:
			continue
		var caption := "%s    ·    %s\n%s" % [record.name, record.time, record.objective]
		var action := _confirm.bind(record) if saving else load_requested.emit.bind(record)
		_button(caption, action, rows)
	_button("Назад", _back)
	_focus()

func _name_slot() -> void:
	_page("name", "Новое сохранение")
	_label("Название сохранения", 20)
	var field := LineEdit.new()
	field.max_length = 48
	field.text = suggested
	field.select_all_on_focus = true
	field.custom_minimum_size.y = 49
	field.add_theme_font_size_override("font_size", 22)
	column.add_child(field)
	buttons.append(field)
	var submit := func():
		var caption := field.text.strip_edges()
		if not caption.is_empty():
			save_requested.emit(store.new_id(), caption)
	var save := _button("Сохранить", submit)
	field.text_changed.connect(func(value): save.disabled = value.strip_edges().is_empty())
	field.text_submitted.connect(func(_value): submit.call())
	_button("Отмена", _back)
	_focus()
	field.select_all()

func _confirm(record: Dictionary) -> void:
	_page("confirm", "Перезаписать сохранение?")
	_label("«%s»\n%s\n%s" % [record.name, record.objective, record.time], 22)
	_button("Отмена", _back)
	_button("Перезаписать", save_requested.emit.bind(record.id, record.name))
	_focus()

func _back() -> void:
	match page:
		"pause":
			resumed.emit()
		"load", "save":
			if from_title:
				title_requested.emit()
			else:
				pause_game(suggested)
		"name", "confirm":
			list_slots(true)

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()
