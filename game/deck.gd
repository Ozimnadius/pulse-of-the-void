extends Node2D

const BACKDROP = preload("res://art/dock.png")
const FERRY = preload("res://art/ferry.png")
const AMBER = Color("#ffcb7f")
const MINT = Color("#89dfce")
var lamp: GradientTexture2D
@onready var game = get_parent()

func _ready() -> void:
	var colors = Gradient.new()
	colors.colors = PackedColorArray([Color(1,1,1,0.85), Color(1,1,1,0.22), Color(1,1,1,0)])
	colors.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
	lamp = GradientTexture2D.new()
	lamp.gradient = colors
	lamp.fill = GradientTexture2D.FILL_RADIAL
	lamp.fill_from = Vector2(0.5,0.5)
	lamp.fill_to = Vector2(1,0.5)
	lamp.width = 128
	lamp.height = 128

func glow(p: Vector2, size: Vector2, tint: Color) -> void:
	draw_texture_rect(lamp, Rect2(p-size/2, size), false, tint)

func _draw() -> void:
	draw_texture_rect(BACKDROP, Rect2(0,0,960,480), false)
	var morning: bool = game.phase >= game.Phase.MORNING
	if morning:
		draw_rect(Rect2(0,0,960,480), Color(0.49,0.65,0.76,0.065))
		if game.route == "home":
			glow(Vector2(150,100), Vector2(275,185), Color(1,0.66,0.30,0.50))
			for x in [77,128,179]:
				blanket(Vector2(x,86), false)
		else:
			glow(Vector2(478,96), Vector2(265,180), Color(0.38,0.96,0.85,0.42))
			draw_line(Vector2(439,68), Vector2(504,68), Color("#ddf5cc"), 2)
			for x in [62,91,151]:
				blanket(Vector2(x,397), true)
	if not morning:
		var leave = game.night_time if game.phase == game.Phase.NIGHT else 0.0
		var origin = Vector2(641,91) + Vector2(115,-40)*leave*leave
		if origin.x < 965:
			draw_texture_rect(FERRY, Rect2(origin,Vector2(180,74)),false)
			glow(origin+Vector2(6,41),Vector2(43,23),Color(0.48,0.96,1,0.42))
	var open: bool = game.route == "home" and game.phase == game.Phase.FINISHED
	hatch(open)
	if game.route == "shop" and game.phase == game.Phase.FINISHED:
		draw_rect(Rect2(747,296,56,30),Color("#735b37"))
		draw_rect(Rect2(751,306,48,20),Color("#50493b"))
		for x in [752,770,788]:
			draw_rect(Rect2(x,311,10,13),Color("#312f2b"))
			draw_line(Vector2(x,312), Vector2(x+8,312),Color("#b39968"),1)
		draw_line(Vector2(749,296), Vector2(801,296), Color("#ffe4a1"),3)
		glow(Vector2(776,323), Vector2(145,136), Color(1,0.73,0.33,0.74))
	if not morning:
		for x in [626,665,711]:
			draw_rect(Rect2(x,199,9,6), Color("#54473e"))
			draw_rect(Rect2(x+2,198,5,2), Color("#b59b78"))
	draw_arc(game.player+Vector2(0,-2),10,0.05,PI-0.05,20,MINT,1.1,true)
	glow(game.player+Vector2(0,-10),Vector2(38,38),Color(0.38,1,0.85,0.12))
	for p in game.points():
		if p[0] == "ship" and game.nearest() != "ship":
			continue
		var done: bool = game.inspected.has(p[0])
		var primary: bool = not done and (p[0] != "switch" or game.inspected.size() == 2)
		var anchor: Vector2 = p[1] + Vector2(0,-46 if p[0] in ["guide","mechanic"] else -8)
		marker(anchor, done, primary)
	if game.phase == game.Phase.MORNING and game.route == "home" and game.progress == 1 and game.guide_index < game.GUIDE_PATH.size():
		marker(game.guide+Vector2(0,-47),false,true)
	if game.repair > 0.0 and game.progress == 1 and game.route == "shop":
		draw_rect(Rect2(game.BENCH+Vector2(-19,-18),Vector2(38,4)),Color("#18252b"))
		draw_rect(Rect2(game.BENCH+Vector2(-19,-18),Vector2(38*game.repair,4)),MINT)

func marker(p: Vector2, done: bool, primary: bool) -> void:
	var c = MINT if done else (AMBER if primary else Color("#a7b5ae"))
	var lift = sin(game.elapsed*2.6)*1.2 if primary else 0.0
	p.y += lift
	var shape = PackedVector2Array([p+Vector2(0,-6),p+Vector2(6,0),p+Vector2(0,6),p+Vector2(-6,0)])
	draw_colored_polygon(shape,Color("#142327"))
	shape.append(shape[0])
	draw_polyline(shape,c,1.2,true)
	if done:
		draw_polyline(PackedVector2Array([p+Vector2(-3,0),p+Vector2(-1,2),p+Vector2(3,-2)]),c,1.2,true)
	else:
		draw_circle(p,1.55,c)

func hatch(open: bool) -> void:
	var r = Rect2(301,372,31,15)
	draw_rect(r,Color("#1a2428"))
	draw_rect(r,Color("#ac9673"),false,1)
	if open:
		draw_arc(Vector2(315,379),7,0,TAU,22,Color("#c68a4b"),2)
		draw_arc(Vector2(315,379),4,0,TAU,18,Color("#94714c"),1)
	else:
		draw_rect(r.grow(-2),Color("#4e5857"))
		for x in range(305,330,4):
			draw_line(Vector2(x,375),Vector2(x-2,382),Color("#2c3a40"),1)
		draw_rect(Rect2(313,376,7,2), Color("#b7a37b"))

func blanket(p: Vector2,roll: bool) -> void:
	var size = Vector2(26,9) if roll else Vector2(19,28)
	var r = Rect2(p-size/2,size)
	draw_rect(r,Color("#383d3e"))
	draw_rect(r.grow(-1),Color("#965f4b") if roll else Color("#af7551"))
	draw_rect(Rect2(r.position+Vector2(2,2),Vector2(size.x-4,3)),Color("#dcc39e"))
	if not roll:
		draw_circle(Vector2(p.x,r.position.y+4),3.7,Color("#684535"))
		draw_line(Vector2(r.position.x+2,p.y+6),Vector2(r.end.x-2,p.y+6),Color("#d49969"),1)
