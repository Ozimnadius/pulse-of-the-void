extends Node2D

const STAR_PERIOD := 150.0
const ASTEROID_PERIOD := 37.5
const FERRY = preload("res://art/ferry.png")
const SERVICE = preload("res://art/service_gallery.png")
const LOADING = preload("res://art/loading_deck.png")
const HOLD = preload("res://art/cargo_hold.png")
const WAREHOUSE = preload("res://art/warehouse.png")
const Freight = preload("res://freight.gd")
const AMBER = Color("#ffcb7f")
const MINT = Color("#89dfce")
var lamp: GradientTexture2D
@onready var game = get_parent()
@onready var sky_material: ShaderMaterial = $Backdrop.material

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
	var trip = game.supply
	if game.phase == game.Phase.SUPPLY and trip.place != trip.Place.DOCK:
		draw_supply_room(trip)
	else:
		draw_dock()
	draw_markers()

func draw_dock() -> void:
	var drift := Vector2(fposmod(game.elapsed, STAR_PERIOD) / STAR_PERIOD,
		fposmod(game.elapsed, ASTEROID_PERIOD) / ASTEROID_PERIOD)
	sky_material.set_shader_parameter("drift", drift)
	draw_kitchen_threshold()
	draw_bridge(844,168,116,game.phase == game.Phase.SUPPLY and game.route == "shop")
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
	var open: bool = game.route == "home" and game.phase >= game.Phase.FINISHED
	hatch(open)
	if game.route == "shop" and game.phase >= game.Phase.FINISHED:
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
	if game.phase == game.Phase.SUPPLY:
		draw_settlement(game.supply)

func draw_kitchen_threshold() -> void:
	var texture: Texture2D = $Backdrop.texture
	var units := texture.get_size() / Vector2(960,480)
	var floor_patch := Rect2(Vector2(241,329)*units, Vector2(19,34)*units)
	draw_texture_rect_region(texture, Rect2(214,320,19,34), floor_patch)
	for y in [319,354]:
		draw_line(Vector2(214,y),Vector2(231,y),Color("#334249"),3)
		draw_line(Vector2(215,y-1),Vector2(222,y-1),AMBER,2)
	for x in [217,221]:
		draw_line(Vector2(x,321),Vector2(x,352),Color("#7a7c70"),1)

func draw_bridge(x: int, y: int, width: int, open: bool) -> void:
	var floor_units := LOADING.get_size() / Vector2(960,480)
	draw_rect(Rect2(x,y+7,width,49),Color("#1b2629"))
	for beam in range(x+4,x+width-12,22):
		draw_line(Vector2(beam,y+53),Vector2(beam+13,y+44),Color("#686353"),2)
	# Плиты, заклёпки и рельсы взяты с самой погрузочной площадки.
	var plating := Rect2(Vector2(180,180)*floor_units,Vector2(width,44)*floor_units)
	draw_texture_rect_region(LOADING,Rect2(x,y,width,44),plating)
	for rail_y in [y,y+44]:
		var rail := Rect2(Vector2(220,292)*floor_units,Vector2(width,8)*floor_units)
		draw_texture_rect_region(LOADING,Rect2(x,rail_y-4,width,8),rail)
		for post in range(x+6,x+width,32):
			draw_rect(Rect2(post-1,rail_y-11,5,12),Color("#3e4140"))
			draw_line(Vector2(post,rail_y-10),Vector2(post,rail_y),Color("#9d8d6d"),1)
			draw_rect(Rect2(post,rail_y-12,3,2),MINT if open else AMBER)
		draw_line(Vector2(x+5,rail_y-8),Vector2(x+width,rail_y-8),Color("#7c7968"),1.6)
		draw_line(Vector2(x+5,rail_y-5),Vector2(x+width,rail_y-5),Color("#393e3d"),1)
	for stripe in range(y+5,y+41,7):
		draw_line(Vector2(x+11,stripe-2),Vector2(x+7,stripe+2),Color("#b89453"),2)
	if not open:
		draw_rect(Rect2(x+67,y+1,6,42),Color("#2c3739"))
		for bar_y in range(y+4,y+39,8):
			draw_line(Vector2(x+68,bar_y+4),Vector2(x+72,bar_y),AMBER,2)

func draw_supply_room(trip) -> void:
	var home: bool = game.route == "home"
	var bounds := Rect2(0,0,960,480)
	if trip.place == trip.Place.HOLD:
		draw_texture_rect(HOLD, bounds, false)
		if not trip.access_ready:
			Freight.draw_cart(self, trip.CART_STAND, 0)
	elif trip.place == trip.Place.STORE:
		draw_texture_rect(WAREHOUSE, bounds, false)
		if trip.stock() & trip.RATIONS:
			glow(trip.FOOD_PALLET,Vector2(74,38),Color(1,0.72,0.32,0.48))
			Freight.pallet(self, trip.FOOD_PALLET, trip.RATIONS)
		if trip.stock() & trip.HEATER:
			glow(trip.HEATER_PALLET,Vector2(74,38),Color(0.45,0.95,0.82,0.48))
			Freight.pallet(self, trip.HEATER_PALLET, trip.HEATER)
	else:
		draw_texture_rect(SERVICE if home else LOADING, bounds, false)
		if home:
			draw_service_door(trip.access_ready)
		else:
			draw_bridge(0,199,104,true)

func draw_service_door(powered: bool) -> void:
	var indicator := MINT if powered else AMBER
	draw_rect(Rect2(687,190,13,16),Color("#242c2c"))
	draw_rect(Rect2(688,191,11,14),Color("#687268"),false,1)
	draw_line(Vector2(690,194),Vector2(696,194),indicator,2)
	for x in [690,693,696]:
		draw_line(Vector2(x,199),Vector2(x,202),Color("#a99d7e"),1)
	if powered:
		draw_polyline(PackedVector2Array([Vector2(693,204),Vector2(693,211),Vector2(698,214),
			Vector2(724,214),Vector2(729,210),Vector2(735,210)]),Color("#b77b48"),2)
		draw_rect(Rect2(740,165,23,46),Color("#101a1b"))
		draw_line(Vector2(742,167),Vector2(742,207),Color("#48534b"),2)
		draw_line(Vector2(741,209),Vector2(761,209),Color("#7f795b"),2)
		draw_line(Vector2(741,163),Vector2(762,163),MINT,2)
		glow(Vector2(752,215),Vector2(57,24),Color(0.53,0.86,0.74,0.3))

func draw_settlement(trip) -> void:
	if game.route == "shop" and trip.cart.parked:
		Freight.draw_cart(self, trip.cart.parking_spot, trip.carried, trip.cart.angle)
	if trip.delivered & trip.RATIONS:
		var box := Vector2(275,330)
		Freight.pallet(self, box, trip.RATIONS)
	if trip.delivered & trip.HEATER:
		var stove := Vector2(149,306)
		Freight.draw_item(self,stove,trip.HEATER)
		glow(stove+Vector2(0,-18),Vector2(70,38),Color(1,0.60,0.19,0.62))
		draw_rect(Rect2(stove+Vector2(-8,-22),Vector2(16,9)),Color("#a7aa98"))
		draw_line(stove+Vector2(-11,-22),stove+Vector2(11,-22),Color("#515b55"),2)
		for i in 5:
			var t := fposmod(float(game.elapsed)*0.45 + i*0.21,1.0)
			var vapor := stove + Vector2(sin(t*7+i)*4,-23-t*24)
			draw_circle(vapor,2+t*2,Color(0.92,0.91,0.80,0.78*(1-t)))
		var cook = game.residents.people[7]
		var spoon := stove + Vector2(sin(game.elapsed * 3.0) * 5, -22)
		draw_line(cook.position + Vector2(-4,-15), spoon, Color("#b6a27c"), 2)

func draw_markers() -> void:
	draw_arc(game.player+Vector2(0,-2),10,0.05,PI-0.05,20,MINT,1.1,true)
	glow(game.player+Vector2(0,-10),Vector2(38,38),Color(0.38,1,0.85,0.12))
	for p in game.points():
		if p[0] == "ship" and game.nearest() != "ship":
			continue
		var done: bool = game.inspected.has(p[0])
		var primary: bool = not done and (p[0] != "switch" or game.inspected.size() == 2)
		var anchor: Vector2 = p[1] + Vector2(0,-46 if p[0] in ["guide","mechanic"] else -8)
		if p[0] in ["food","heater"]:
			anchor.y -= 23
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
