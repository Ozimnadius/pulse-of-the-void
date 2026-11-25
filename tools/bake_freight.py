"""Подготовка игровых атласов в Blender 4.2 с Pillow. Запуск из корня проекта."""
from pathlib import Path
from math import pi, sin, cos, radians, asin
import os
import bpy
from mathutils import Vector
from PIL import Image

ROOT = Path.cwd() / "game/art"
WORK = Path(os.environ["TEMP"]) / "stavr-freight-render"
WORK.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = False
scene.cycles.transparent_max_bounces = 2
scene.cycles.max_bounces = 3
scene.render.film_transparent = True
scene.render.image_settings.color_mode = 'RGBA'
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
scene.world = bpy.data.worlds.new("Рассеянный свет цеха")
scene.world.use_nodes = True
scene.world.node_tree.nodes.get('Background').inputs[0].default_value = (.38,.43,.47,1)
scene.world.node_tree.nodes.get('Background').inputs[1].default_value = .8

def lamp(name, pos, power, tint):
    light = bpy.data.lights.new(name, 'SUN')
    light.energy = power
    light.color = tint
    light.angle = .22
    obj = bpy.data.objects.new(name,light)
    scene.collection.objects.link(obj)
    obj.rotation_euler = (-Vector(pos)).to_track_quat('-Z','Y').to_euler()

lamp("Рабочие лампы слева",(-4,-4,8),3.2,(1,.81,.58))
lamp("Холодный свет борта",(3,2,5),1.6,(.68,.83,1))
elevation = asin(.68)
cam = bpy.data.cameras.new("Ортографическая камера причала")
camera = bpy.data.objects.new("Камера",cam)
scene.collection.objects.link(camera)
camera.location = (0,-1500*cos(elevation),1500*sin(elevation))
camera.rotation_euler = (-camera.location).to_track_quat('-Z','Y').to_euler()
cam.type = 'ORTHO'
cam.clip_end = 4000
scene.camera = camera

def material(name, dark, light, metal=0, grain=False):
    m=bpy.data.materials.new(name)
    m.use_nodes=True
    nodes=m.node_tree.nodes
    links=m.node_tree.links
    bs=nodes.get('Principled BSDF')
    bs.inputs['Metallic'].default_value=metal
    bs.inputs['Roughness'].default_value=.58 if metal else .76
    noise=nodes.new('ShaderNodeTexNoise')
    coord=nodes.new('ShaderNodeTexCoord')
    scale=nodes.new('ShaderNodeVectorMath')
    scale.operation='MULTIPLY'
    scale.inputs[1].default_value=(.18,1.8,2.8) if grain else (.85,.85,.85)
    links.new(coord.outputs['Object'],scale.inputs[0])
    links.new(scale.outputs[0],noise.inputs[0])
    noise.inputs['Scale'].default_value=1.3
    noise.inputs['Detail'].default_value=3.0
    ramp=nodes.new('ShaderNodeValToRGB')
    for el, v, p in zip(ramp.color_ramp.elements,(dark,light),(.26,.74)):
        el.color=(*v,1)
        el.position=p
    links.new(noise.outputs['Fac'],ramp.inputs[0])
    links.new(ramp.outputs[0],bs.inputs['Base Color'])
    bump=nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value=.19
    bump.inputs['Distance'].default_value=.12
    links.new(noise.outputs['Fac'],bump.inputs['Height'])
    links.new(bump.outputs[0],bs.inputs['Normal'])
    return m

wood=material("Доски с продольными волокнами",(.076,.033,.012),(.39,.21,.077),grain=True)
pale=material("Потёртый торец",(.14,.068,.025),(.50,.32,.15),grain=True)
steel=material("Протёртая сталь",(.071,.082,.08),(.38,.43,.40),.66)
dark=material("Чернёное железо",(.013,.019,.018),(.07,.078,.068),.60)
brass=material("Латунь",(.17,.08,.022),(.55,.34,.095),.65)
rubber=material("Резина",(.008,.011,.013),(.044,.047,.044))
paint=material("Транспортная охра",(.19,.076,.022),(.57,.32,.071),.35)
enamel=material("Бирюзовая эмаль",(.016,.076,.069),(.081,.26,.21),.44)
red=material("Красная фибра",(.20,.034,.016),(.48,.085,.032))
foil=material("Обёртка из фольги",(.20,.19,.14),(.65,.63,.50),.62)
kraft=material("Промасленная бумага",(.21,.12,.055),(.62,.47,.25))
canvas=material("Брезент",(.074,.08,.033),(.24,.27,.104))
cream=material("Бумажная этикетка",(.41,.35,.22),(.72,.66,.45))

def box(n,loc,dim,m,r=.23):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object
    o.name=n
    o.dimensions=dim
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if r:
        b=o.modifiers.new("Сколотые кромки",'BEVEL')
        b.width=r
        b.segments=2
        o.modifiers.new("Нормали",'WEIGHTED_NORMAL')
    o.data.materials.append(m)
    return o

def rod(n,a,b,r,m,seg=16):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=seg,radius=r,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object
    o.name=n
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    o.data.materials.append(m)
    for face in o.data.polygons:
        face.use_smooth=len(face.vertices)==4
    return o

def batch(name,fn):
    before=set(scene.objects)
    fn()
    parts=set(scene.objects)-before
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active=next(iter(parts))
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    o=bpy.context.object
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    o.name=name
    data=o.data
    data.name=name
    bpy.data.objects.remove(o,do_unlink=True)
    return data

def pallet():
    for y in (-9,0,9):
        box("Полоз",(0,y,1.2),(31,3.0,2.4),wood)
    for i in range(5):
        y=(i-2)*4.8
        box("Настил",(0,y,3),(32,4.25,1.7),pale if i%3==0 else wood)
        for x in (-12,12):
            rod("Шляпка",(x,y,3.84),(x,y,3.96),.48,dark,8)

def food():
    box("Дно",(0,0,1.0),(19.8,16.4,2),wood)
    for z in (3.6,7.1,10.5):
        for side in (-1,1):
            box("Стенка ящика",(0,side*7.9,z),(20.2,1.05,3.18),wood if z<9 else pale)
            box("Торец",(side*9.5,0,z),(1.1,15,3.18),pale)
    for x in (-7.6,7.6):
        for y in (-8.55,8.55):
            box("Лента на ящике",(x,y,6.6),(1.65,.5,11.8),dark)
            for z in (2.1,10.9):
                rod("Заклёпка",(x,y,z),(x,y*1.04,z),.44,steel,8)
    for x,y,z,m in [(-4,3,11,kraft),(3.9,3.3,11.3,canvas),(4.5,-3.6,11,foil)]:
        box("Пакет пайка",(x,y,z),(7.8,5.2,4.8),m,.75)
        box("Бандероль",(x,y,z+2.45),(2.3,5.3,.25),cream,.03)
    for x in (-6.1,-1.45):
        rod("Консервы",(x,-3.4,8.7),(x,-3.4,14.2),2.14,foil,24)
        rod("Крышка",(x,-3.4,14.15),(x,-3.4,14.45),2.18,steel,24)
        rod("Кольцо",(x-.45,-3.4,14.45),(x+.4,-3.4,14.45),.3,dark,8)
    box("Маркировка пайков",(0,-8.52,6.8),(7.1,.28,3.7),cream,.05)
    for x in (-2,-1,1,2.1):
        box("Штамп",(x,-8.69,6.7),(.4,.15,1.8),dark,0)

def heater():
    for x in (-6,6):
        for y in (-5.5,5.5): box("Ножка",(x,y,1.1),(3,3,2.2),rubber)
    box("Корпус горелки",(0,0,8.4),(16.8,14.3,13.4),enamel,1.0)
    box("Передняя панель",(0,-7.25,8.5),(14.0,.65,9.1),dark)
    for z in (5.8,7.65,9.5,11.35):
        box("Жалюзи",(0,-7.74,z),(11.1,.8,.72),steel)
    for x in (-8.65,8.65):
        for y in (-4,0,4):
            box("Боковая вентиляция",(x,y,8),(.26,1.05,6),dark)
    box("Верх варочной плиты",(0,0,15.1),(17,14.7,1.5),steel)
    rod("Чугунный диск",(0,0,15.7),(0,0,16.7),6.1,dark,40)
    for rad in (2.6,4.6):
        bpy.ops.mesh.primitive_torus_add(major_segments=40,minor_segments=8,location=(0,0,16.8),major_radius=rad,minor_radius=.45)
        bpy.context.object.data.materials.append(steel)
    for x in (-6,6):
        rod("Дужка",(x,6.7,12.5),(x,7.4,19.8),.7,brass)
    rod("Ручка",(-6,7.4,19.8),(6,7.4,19.8),.96,dark)
    rod("Регулятор",(4.9,-7.4,3.8),(4.9,-8.6,3.8),1.38,red)
    rod("Лампа",(-5.6,-7.4,4.0),(-5.6,-7.8,4.0),.73,brass)

def cart():
    for y in (-10.3,10.3):
        box("Швеллер",(0,y,5.9),(42,1.35,2.8),paint)
        for x in (-18,18): box("Косынка",(x,y,6),(4,1.7,3.1),steel)
    for x in (-20,20): box("Торец тележки",(x,0,6),(1.6,21.3,2.8),steel)
    for i in range(5):
        box("Продольная доска",(0,(i-2)*4.0,7.25),(39.5,3.75,1.6),wood if i%2 else pale)
    for y in (-9.4,9.4):
        rod("Стойка рукояти",(-16.6,y,6),(-21.8,y,23.8),.93,steel)
        rod("Раскос",(-10,y,6),(-18.9,y,16),.54,paint)
    rod("Поперечная рукоять",(-21.8,-9.5,23.8),(-21.8,9.5,23.8),1.03,steel)
    rod("Резиновый хват",(-21.8,-7,23.8),(-21.8,7,23.8),1.2,rubber)

def wheels(phase):
    for x in (-14.8,14.8):
        for y in (-8.6,8.6):
            rod("Шина",(x,y-1.15,3.35),(x,y+1.15,3.35),3.32,rubber,28)
            sign=1 if y>0 else -1
            sy=y+sign*1.16
            rod("Ступица",(x,sy,3.35),(x,sy+sign*.38,3.35),2.12,steel,20)
            for i in range(3):
                a=i*2*pi/3+phase*pi/3
                dx,dz=cos(a)*1.24,sin(a)*1.24
                rod("Отверстие",(x+dx,sy+sign*.39,3.35+dz),(x+dx,sy+sign*.47,3.35+dz),.49,dark,8)
            rod("Вилка колеса",(x,sy+sign*.66,3.35),(x+1,sy+sign*.66,5.85),.54,brass)

shapes={n:batch(n,fn) for n,fn in [('Ящик пайков',food),('Нагреватель',heater),('Поддон',pallet),('Тележка',cart),('Колёса А',lambda:wheels(0)),('Колёса Б',lambda:wheels(1))]}
def instance(key,center,angle=0,offset=(0,0,0)):
    ob=bpy.data.objects.new(key,shapes[key])
    scene.collection.objects.link(ob)
    x,y,z=offset
    ob.location=(center[0]+x*cos(angle)-y*sin(angle),center[1]+x*sin(angle)+y*cos(angle),z)
    ob.rotation_euler.z=angle

def sheet(path,columns,rows,draw):
    generated=set(scene.objects)
    for i in range(columns*rows):
        center=((i%columns-(columns-1)*.5)*72,((rows-1)*.5-i//columns)*72/.68)
        draw(i,center)
    cam.ortho_scale=columns*72
    scene.render.resolution_x=columns*180
    scene.render.resolution_y=rows*180
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    for o in set(scene.objects)-generated: bpy.data.objects.remove(o,do_unlink=True)

def items(i,c):
    a=radians(-9)
    if i in (2,3,4): instance('Поддон',c,a)
    if i in (0,1,2,3):
        instance('Ящик пайков' if i%2==0 else 'Нагреватель',c,a,(0,0,3.9 if i>=2 else 0))

sheet(ROOT/'freight_items.png',5,1,items)
atlas=Image.new('RGBA',(16*180,16*180))
for mask in range(4):
    for phase in range(2):
        def pose(i,c):
            a=-i*2*pi/32
            instance('Тележка',c,a)
            instance('Колёса Б' if phase else 'Колёса А',c,a)
            if mask&1: instance('Ящик пайков',c,a,(8.7 if mask==3 else 0,0,8.1))
            if mask&2: instance('Нагреватель',c,a,(-10.5 if mask==3 else 0,0,8.1))
        path=WORK/f'cart-{mask}-{phase}.png'
        sheet(path,16,2,pose)
        with Image.open(path) as part: atlas.paste(part,(0,(mask*2+phase)*360))
atlas.save(ROOT/'freight_cart.png',optimize=True)
