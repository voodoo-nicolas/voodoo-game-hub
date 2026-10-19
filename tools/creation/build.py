import json, sys, itertools
from collections import deque

ITEMS = """
earth|Earth|Tierra|🌍
fire|Fire|Fuego|🔥
wind|Wind|Viento|💨
water|Water|Agua|💧
puddle|Puddle|Charco|💦
mountain|Mountain|Montaña|⛰️
blaze|Blaze|Llamarada|🔥
gale|Gale|Vendaval|🌬️
mud|Mud|Barro|🟫
lava|Lava|Lava|🌋
dust|Dust|Polvo|🌫️
steam|Steam|Vapor|♨️
smoke|Smoke|Humo|💭
wave|Wave|Ola|🌊
stone|Stone|Piedra|🪨
sand|Sand|Arena|🏖️
glass|Glass|Vidrio|🥃
beach|Beach|Playa|🏝️
desert|Desert|Desierto|🏜️
cloud|Cloud|Nube|☁️
rain|Rain|Lluvia|🌧️
storm|Storm|Tormenta|⛈️
lightning|Lightning|Rayo|⚡
swamp|Swamp|Pantano|🐊
river|River|Río|🏞️
lake|Lake|Lago|🛶
ocean|Ocean|Océano|🌐
snow|Snow|Nieve|❄️
ice|Ice|Hielo|🧊
glacier|Glacier|Glaciar|🏔️
iceberg|Iceberg|Iceberg|🧊
snowman|Snowman|Muñeco de nieve|⛄
sky|Sky|Cielo|🌤️
star|Star|Estrella|⭐
sun|Sun|Sol|☀️
moon|Moon|Luna|🌙
day|Day|Día|🌅
night|Night|Noche|🌃
rainbow|Rainbow|Arcoíris|🌈
eclipse|Eclipse|Eclipse|🌑
volcano|Volcano|Volcán|🌋
hill|Hill|Colina|🏞️
earthquake|Earthquake|Terremoto|📳
tsunami|Tsunami|Tsunami|🌊
island|Island|Isla|🏝️
continent|Continent|Continente|🗺️
planet|Planet|Planeta|🪐
constellation|Constellation|Constelación|✨
galaxy|Galaxy|Galaxia|🌌
universe|Universe|Universo|🌠
comet|Comet|Cometa|☄️
meteor|Meteor|Meteoro|🌠
fog|Fog|Niebla|🌁
hurricane|Hurricane|Huracán|🌀
tornado|Tornado|Tornado|🌪️
gravel|Gravel|Grava|⚪
life|Life|Vida|🧬
algae|Algae|Alga|🌿
plant|Plant|Planta|🌱
grass|Grass|Pasto|🌾
tree|Tree|Árbol|🌳
forest|Forest|Bosque|🌲
flower|Flower|Flor|🌸
seed|Seed|Semilla|🫘
leaf|Leaf|Hoja|🍃
fruit|Fruit|Fruta|🍎
stick|Stick|Palo|🪵
insect|Insect|Insecto|🐛
bee|Bee|Abeja|🐝
honey|Honey|Miel|🍯
fish|Fish|Pez|🐟
frog|Frog|Rana|🐸
lizard|Lizard|Lagarto|🦎
bird|Bird|Pájaro|🐦
egg|Egg|Huevo|🥚
chicken|Chicken|Gallina|🐔
dinosaur|Dinosaur|Dinosaurio|🦖
fossil|Fossil|Fósil|🦴
oil|Oil|Petróleo|🛢️
coal|Coal|Carbón|⚫
mammal|Mammal|Mamífero|🐾
bear|Bear|Oso|🐻
wolf|Wolf|Lobo|🐺
monkey|Monkey|Mono|🐒
human|Human|Humano|🧍
dog|Dog|Perro|🐕
cat|Cat|Gato|🐈
horse|Horse|Caballo|🐎
cow|Cow|Vaca|🐄
sheep|Sheep|Oveja|🐑
pig|Pig|Cerdo|🐖
whale|Whale|Ballena|🐋
bat|Bat|Murciélago|🦇
meadow|Meadow|Pradera|🌼
field|Field|Campo|🚜
wheat|Wheat|Trigo|🌾
butterfly|Butterfly|Mariposa|🦋
tool|Tool|Herramienta|🔨
wood|Wood|Madera|🪵
plank|Plank|Tablón|📏
campfire|Campfire|Fogata|🏕️
torch|Torch|Antorcha|🔦
ash|Ash|Ceniza|🌫️
charcoal|Charcoal|Leña quemada|◼️
ore|Ore|Mineral|⛏️
cave|Cave|Cueva|🕳️
metal|Metal|Metal|🔩
blade|Blade|Filo|🔪
knife|Knife|Cuchillo|🔪
steel|Steel|Acero|⚙️
gold|Gold|Oro|🥇
silver|Silver|Plata|🥈
gem|Gem|Gema|💎
diamond|Diamond|Diamante|💠
ring|Ring|Anillo|💍
necklace|Necklace|Collar|📿
mirror|Mirror|Espejo|🪞
coin|Coin|Moneda|🪙
salt|Salt|Sal|🧂
soap|Soap|Jabón|🧼
clay|Clay|Arcilla|🧱
pot|Pot|Olla|🍲
vase|Vase|Jarrón|🏺
brick|Brick|Ladrillo|🧱
wall|Wall|Muro|🧱
house|House|Casa|🏠
door|Door|Puerta|🚪
window|Window|Ventana|🪟
table|Table|Mesa|🍽️
chair|Chair|Silla|🪑
bench|Bench|Banco|🛋️
bed|Bed|Cama|🛏️
wool|Wool|Lana|🧶
meat|Meat|Carne|🥩
leather|Leather|Cuero|👜
steak|Steak|Bife|🥩
boots|Boots|Botas|🥾
thread|Thread|Hilo|🧵
cloth|Cloth|Tela|🧣
shirt|Shirt|Camisa|👕
hat|Hat|Sombrero|👒
sail|Sail|Vela de barco|⛵
wax|Wax|Cera|🟡
candle|Candle|Vela|🕯️
paper|Paper|Papel|📄
book|Book|Libro|📖
ink|Ink|Tinta|🖋️
pen|Pen|Lapicera|🖊️
library|Library|Biblioteca|📚
school|School|Escuela|🏫
paint|Paint|Pintura|🎨
painting|Painting|Cuadro|🖼️
statue|Statue|Estatua|🗿
fountain|Fountain|Fuente|⛲
bank|Bank|Banco (dinero)|🏦
flour|Flour|Harina|🥣
dough|Dough|Masa|🫓
bread|Bread|Pan|🍞
cake|Cake|Torta|🎂
milk|Milk|Leche|🥛
cheese|Cheese|Queso|🧀
butter|Butter|Manteca|🧈
pizza|Pizza|Pizza|🍕
sandwich|Sandwich|Sándwich|🥪
soup|Soup|Sopa|🍜
omelet|Omelet|Tortilla|🍳
juice|Juice|Jugo|🧃
tea|Tea|Té|🍵
coffee|Coffee|Café|☕
icecream|Ice Cream|Helado|🍨
burger|Burger|Hamburguesa|🍔
wheel|Wheel|Rueda|🛞
cart|Cart|Carro|🛒
boat|Boat|Bote|🚣
ship|Ship|Barco|🚢
sailboat|Sailboat|Velero|⛵
bike|Bike|Bicicleta|🚲
gear|Gear|Engranaje|⚙️
clock|Clock|Reloj|🕰️
watch|Watch|Reloj de pulsera|⌚
windmill|Windmill|Molino de viento|🌬️
watermill|Watermill|Molino de agua|💧
dam|Dam|Represa|🚧
bridge|Bridge|Puente|🌉
road|Road|Camino|🛣️
village|Village|Aldea|🏘️
town|Town|Pueblo|🏙️
city|City|Ciudad|🌆
farm|Farm|Granja|🐓
garden|Garden|Jardín|🌷
park|Park|Parque|🏞️
tower|Tower|Torre|🗼
castle|Castle|Castillo|🏰
lighthouse|Lighthouse|Faro|🗼
pyramid|Pyramid|Pirámide|🔺
skyscraper|Skyscraper|Rascacielos|🏢
engine|Engine|Motor|🏭
car|Car|Auto|🚗
motorcycle|Motorcycle|Moto|🏍️
rail|Rail|Riel|🛤️
train|Train|Tren|🚆
plane|Plane|Avión|✈️
rocket|Rocket|Cohete|🚀
satellite|Satellite|Satélite|🛰️
astronaut|Astronaut|Astronauta|👨‍🚀
alien|Alien|Alienígena|👽
spaceship|Spaceship|Nave espacial|🛸
electricity|Electricity|Electricidad|🔌
wire|Wire|Cable|🪢
bulb|Light Bulb|Lamparita|💡
battery|Battery|Batería|🔋
generator|Generator|Generador|🔆
powerplant|Power Plant|Central eléctrica|🏭
chip|Chip|Chip|🔲
circuit|Circuit|Circuito|🧩
computer|Computer|Computadora|💻
internet|Internet|Internet|🌐
radio|Radio|Radio|📻
tv|TV|Televisor|📺
phone|Phone|Celular|📱
robot|Robot|Robot|🤖
lens|Lens|Lente|🔍
camera|Camera|Cámara|📷
telescope|Telescope|Telescopio|🔭
microscope|Microscope|Microscopio|🔬
glasses|Glasses|Anteojos|👓
drum|Drum|Tambor|🥁
flute|Flute|Flauta|🪈
guitar|Guitar|Guitarra|🎸
music|Music|Música|🎵
dance|Dance|Baile|💃
party|Party|Fiesta|🎉
medicine|Medicine|Medicina|💊
hospital|Hospital|Hospital|🏥
fireworks|Fireworks|Fuegos artificiales|🎆
crown|Crown|Corona|👑
king|King|Rey|🤴
photo|Photo|Foto|🖼️
letter|Letter|Carta|✉️
app|App|App|📲
ai|AI|Inteligencia artificial|🧠
highway|Highway|Autopista|🛣️
station|Station|Estación|🚉
airport|Airport|Aeropuerto|🛫
port|Port|Puerto|⚓
kitten|Kitten|Gatito|🐱
puppy|Puppy|Cachorro|🐶
carriage|Carriage|Carruaje|🐴
latte|Latte|Café con leche|🥛
birthdaycake|Birthday Cake|Torta de cumpleaños|🎂
gps|GPS|GPS|📍
map|Map|Mapa|🗺️
treasure|Treasure|Tesoro|💰
museum|Museum|Museo|🏛️
solarsystem|Solar System|Sistema solar|☀️
crater|Crater|Cráter|🕳️
shipwreck|Shipwreck|Naufragio|🏴
plastic|Plastic|Plástico|🧴
bottle|Bottle|Botella|🍼
vacation|Vacation|Vacaciones|🏖️
movie|Movie|Película|🎬
videogame|Video Game|Videojuego|🎮
bacon|Bacon|Panceta|🥓
"""

RECIPES = """
earth+fire=lava
earth+water=mud
earth+wind=dust
earth+earth=mountain
fire+fire=blaze
fire+water=steam
fire+wind=smoke
water+wind=wave
water+water=puddle
wind+wind=gale
lava+water=stone
stone+wave=sand
sand+fire=glass
sand+wave=beach
sand+sand=desert
steam+wind=cloud
cloud+water=rain
cloud+cloud=storm
storm+fire=lightning
mud+rain=swamp
puddle+puddle=lake
lake+lake=ocean
rain+mountain=river
cloud+mountain=snow
snow+water=ice
ice+mountain=glacier
ice+ocean=iceberg
snow+snow=snowman
cloud+wind=sky
sky+fire=star
star+fire=sun
sky+stone=moon
sun+sky=day
moon+sky=night
rain+sun=rainbow
sun+moon=eclipse
mountain+lava=volcano
earth+mountain=hill
mountain+mountain=earthquake
earthquake+ocean=tsunami
ocean+earth=island
island+island=continent
continent+sky=planet
star+star=constellation
constellation+constellation=galaxy
galaxy+galaxy=universe
ice+star=comet
stone+star=meteor
cloud+lake=fog
storm+ocean=hurricane
gale+storm=tornado
stone+stone=gravel
swamp+lightning=life
life+water=algae
life+earth=plant
plant+earth=grass
plant+plant=tree
tree+tree=forest
plant+sun=flower
flower+wind=seed
plant+wind=leaf
tree+rain=fruit
tree+wind=stick
life+plant=insect
insect+flower=bee
bee+tree=honey
life+ocean=fish
fish+swamp=frog
frog+desert=lizard
lizard+sky=bird
chicken+chicken=egg
bird+seed=chicken
lizard+lizard=dinosaur
dinosaur+stone=fossil
fossil+earth=oil
forest+stone=coal
lizard+forest=mammal
mammal+forest=bear
mammal+moon=wolf
mammal+tree=monkey
monkey+tool=human
wolf+human=dog
mammal+house=cat
mammal+meadow=horse
mammal+field=cow
mammal+mountain=sheep
mammal+mud=pig
mammal+ocean=whale
mammal+night=bat
grass+flower=meadow
grass+tool=field
seed+field=wheat
insect+rainbow=butterfly
stone+stick=tool
tree+tool=wood
wood+tool=plank
wood+fire=campfire
stick+fire=torch
campfire+wind=ash
tree+fire=charcoal
mountain+tool=cave,ore
ore+fire=metal
metal+fire=blade
blade+stick=knife
metal+charcoal=steel
metal+sun=gold
metal+moon=silver
stone+volcano=gem
coal+volcano=diamond
gold+gem=ring
gold+silver=necklace
glass+silver=mirror
gold+stone=coin
ocean+sun=salt
ash+water=soap
mud+sand=clay
clay+fire=pot
pot+flower=vase
mud+fire=brick
brick+brick=wall
wall+wall=house
plank+wall=door
glass+wall=window
plank+plank=table
plank+stick=chair
chair+chair=bench
plank+wool=bed
sheep+knife=wool,meat
cow+knife=meat,leather
meat+fire=steak
leather+leather=boots
wool+stick=thread
thread+thread=cloth
cloth+knife=shirt
cloth+sun=hat
cloth+stick=sail
honey+fire=wax
wax+stick=candle
wood+water=paper
paper+paper=book
charcoal+water=ink
ink+stick=pen
book+house=library
book+human=school
flower+water=paint
paint+paper=painting
stone+knife=statue
statue+water=fountain
coin+house=bank
wheat+stone=flour
flour+water=dough
dough+fire=bread
bread+honey=cake
cow+grass=milk
milk+cave=cheese
milk+stick=butter
bread+cheese=pizza
bread+meat=sandwich
meat+water=soup
egg+fire=omelet
fruit+water=juice
leaf+steam=tea
seed+steam=coffee
milk+ice=icecream
bread+steak=burger
plank+tool=wheel
wheel+plank=cart
plank+water=boat
boat+ocean=ship
boat+sail=sailboat
wheel+wheel=bike
metal+wheel=gear
gear+glass=clock
clock+leather=watch
wheel+wind=windmill
wheel+river=watermill
river+wall=dam
river+plank=bridge
gravel+gravel=road
house+house=village
village+village=town
town+town=city
field+house=farm
flower+wall=garden
tree+bench=park
brick+sky=tower
tower+wall=castle
tower+ocean=lighthouse
desert+brick=pyramid
tower+steel=skyscraper
steam+metal=engine
engine+cart=car
bike+engine=motorcycle
metal+plank=rail
engine+rail=train
engine+sky=plane
engine+star=rocket
rocket+sky=satellite
human+rocket=astronaut
life+star=alien
rocket+moon=spaceship
lightning+metal=electricity
metal+metal=wire
electricity+glass=bulb
electricity+wire=battery
electricity+wheel=generator
generator+house=powerplant
sand+electricity=chip
chip+wire=circuit
circuit+glass=computer
computer+computer=internet
wire+sky=radio
radio+glass=tv
radio+computer=phone
computer+steel=robot
glass+glass=lens
lens+circuit=camera
lens+sky=telescope
lens+life=microscope
lens+wire=glasses
leather+wood=drum
wood+wind=flute
wood+thread=guitar
flute+drum=music
human+music=dance
dance+dance=party
plant+human=medicine
medicine+house=hospital
blaze+night=fireworks
gold+ring=crown
crown+human=king
camera+paper=photo
pen+paper=letter
phone+internet=app
robot+internet=ai
road+car=highway
train+house=station
plane+road=airport
ship+city=port
cat+cat=kitten
dog+dog=puppy
horse+cart=carriage
coffee+milk=latte
cake+candle=birthdaycake
satellite+phone=gps
paper+road=map
map+gold=treasure
painting+house=museum
planet+star=solarsystem
meteor+earth=crater
iceberg+ship=shipwreck
oil+blaze=plastic
plastic+water=bottle
beach+sun=vacation
camera+tv=movie
computer+tv=videogame
pig+fire=bacon
# --- early-game stall fix (2026-10-19) ---------------------------------------
# Tool (stone+stick, depth 9) gated 128 of 263 items (Wood, Human, Metal, ...).
# Two extra, guessable routes so one hard-to-find recipe cannot stall a player:
earthquake+mountain=ore
stone+tree=tool
"""

def key(a, b): return "+".join(sorted([a, b]))

items = {}
for line in ITEMS.strip().splitlines():
    if not line.strip() or line.lstrip().startswith("#"): continue
    i, en, es, em = line.split("|")
    assert i not in items, f"dup item {i}"
    items[i] = {"id": i, "name": {"en": en, "es": es}, "emoji": em}

recipes = {}
errors = []
for line in RECIPES.strip().splitlines():
    if not line.strip() or line.lstrip().startswith("#"): continue
    lhs, rhs = line.split("=")
    a, b = lhs.split("+")
    res = rhs.split(",")
    for x in [a, b] + res:
        if x not in items: errors.append(f"undefined item '{x}' in: {line}")
    k = key(a, b)
    if k in recipes: errors.append(f"duplicate recipe {k}")
    recipes[k] = res

# reachability + depth
starters = ["earth", "fire", "wind", "water"]
depth = {s: 0 for s in starters}
known = set(starters)
changed = True
rounds = 0
while changed:
    changed = False
    rounds += 1
    new = {}
    for k, res in recipes.items():
        a, b = k.split("+")
        if a in known and b in known:
            d = max(depth[a], depth[b]) + 1
            for r in res:
                if r not in known and (r not in new or new[r] > d):
                    new[r] = d
    for r, d in new.items():
        known.add(r); depth[r] = d; changed = True

unreachable = [i for i in items if i not in known]
produced = {r for res in recipes.values() for r in res}
no_source = [i for i in items if i not in starters and i not in produced]
used = {x for k in recipes for x in k.split("+")}
dead_ends = [i for i in items if i not in used]

def tier(d):
    return 1 if d <= 3 else 2 if d <= 6 else 3 if d <= 10 else 4 if d <= 14 else 5

# Themed tiers. `tier` in game_data.json is THEMED (what the player sees and
# what the paywall gates); the old depth-based number is kept as `depth_band`.
TIER_NAMES = {
    1: ("Nature", "Naturaleza"),
    2: ("Life", "Vida"),
    3: ("Early Civilization", "Primeras civilizaciones"),
    4: ("Industry & Modern Life", "Industria y vida moderna"),
    5: ("Space & Future", "Espacio y futuro"),
}
FREE_TIERS = (1, 2, 3)   # the free part of the game (SPEC section 7)
TIERS = """
1|earth fire wind water puddle mountain blaze gale mud lava dust steam smoke wave stone sand glass beach desert cloud rain storm lightning swamp river lake ocean snow ice glacier iceberg snowman sky star sun moon day night rainbow eclipse volcano hill earthquake tsunami island continent fog hurricane tornado gravel gem diamond salt
2|life algae plant grass tree forest flower seed leaf fruit stick insect bee honey fish frog lizard bird egg chicken dinosaur fossil oil coal mammal bear wolf monkey human dog cat horse cow sheep pig whale bat meadow field wheat butterfly kitten puppy
3|tool wood plank campfire torch ash charcoal ore cave metal blade knife gold silver ring necklace mirror coin soap clay pot vase brick wall house door window table chair bench bed wool meat leather steak boots thread cloth shirt hat sail wax candle paper book ink pen paint painting statue flour dough bread cake milk cheese butter soup omelet juice tea wheel cart boat bridge road village town farm garden tower castle pyramid drum flute guitar music dance party crown king treasure map letter bacon

4|gear clock watch engine car motorcycle rail train plane electricity wire bulb battery generator powerplant lens camera microscope glasses photo movie tv radio highway station airport port skyscraper hospital medicine fireworks plastic bottle city park library school bank museum vacation shipwreck pizza sandwich burger icecream coffee latte birthdaycake chip circuit computer phone bike carriage dam fountain lighthouse sailboat ship steel watermill windmill

5|planet constellation galaxy universe comet meteor solarsystem crater rocket satellite astronaut alien spaceship telescope gps robot ai internet app videogame
"""
theme = {}
for line in TIERS.strip().splitlines():
    if not line.strip(): continue
    t, ids = line.split("|")
    for i in ids.split():
        if i in theme: errors.append(f"item '{i}' in two tiers")
        theme[i] = int(t)
for i in items:
    if i not in theme: errors.append(f"item '{i}' has no tier")
for i in theme:
    if i not in items: errors.append(f"tier list names unknown item '{i}'")
for st in starters:
    if theme.get(st) != 1: errors.append(f"starter '{st}' must be tier 1")

# The free tiers must be completable on their own: every free-tier item has to
# be makeable using only free-tier items (else a free player is stuck).
free_known = set(starters)
changed = True
while changed:
    changed = False
    for k, res in recipes.items():
        a, b = k.split("+")
        if a in free_known and b in free_known:
            for r in res:
                if theme.get(r, 99) in FREE_TIERS and r not in free_known:
                    free_known.add(r); changed = True
free_stuck = [i for i in items if theme.get(i, 99) in FREE_TIERS and i not in free_known]
if free_stuck: errors.append(f"free-tier items that need a paid-tier ingredient: {free_stuck}")

out_items = []
for i, it in items.items():
    it = dict(it)
    it["starter"] = i in starters
    it["depth"] = depth.get(i, -1)
    it["depth_band"] = tier(depth.get(i, 99))
    it["tier"] = theme.get(i, 0)
    it["finale"] = i in dead_ends
    out_items.append(it)

out_recipes = [{"a": k.split("+")[0], "b": k.split("+")[1], "results": r} for k, r in sorted(recipes.items())]

tiers_out = [{"id": t, "name": {"en": n[0], "es": n[1]}, "free": t in FREE_TIERS} for t, n in TIER_NAMES.items()]
json.dump({"version": 1, "starters": starters, "tiers": tiers_out, "items": out_items, "recipes": out_recipes},
          open("game_data.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

# The game loads this copy (hub pack: scripts/games/creation/). Never edit it by hand.
import os, shutil
if not errors:
    _here = os.path.dirname(os.path.abspath(__file__))
    shutil.copyfile("game_data.json", os.path.join(_here, "..", "..", "scripts", "games", "creation", "creation_data.json"))

print("items:", len(items), "| recipes:", len(recipes), "| max depth:", max(depth.values()))
print("errors:", errors)
print("unreachable:", unreachable)
print("no_source:", no_source)
print("dead ends (finales):", len(dead_ends))
print(sorted(dead_ends))
from collections import Counter
print("depth-band counts:", sorted(Counter(i["depth_band"] for i in out_items).items()))
print("themed tier counts:", sorted(Counter(i["tier"] for i in out_items).items()))
# stall check: how much of the game is gated behind one item? (2026-10-19)
for gate in ("tool", "life"):
    k2 = set(starters)
    ch = True
    while ch:
        ch = False
        for k, res in recipes.items():
            a, b = k.split("+")
            if a in k2 and b in k2:
                for r in res:
                    if r != gate and r not in k2: k2.add(r); ch = True
    print(f"gate '{gate}': depth {depth[gate]}, items unreachable without it: {len(items) - len(k2)}")
if errors or unreachable or no_source:
    sys.exit(1)
