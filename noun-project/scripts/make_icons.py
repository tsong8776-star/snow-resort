"""Generate a 'Houseplant Care' glyph icon set as single-colour SVGs (100x100).
Shapes are built with shapely and flattened into one compound path per icon
(no strokes, no masks, no text) so they are ready for icon marketplaces."""
import math, os, sys
from shapely.geometry import Polygon, Point, LineString, box
from shapely.ops import unary_union
from shapely import affinity

OUT = sys.argv[1] if len(sys.argv) > 1 else "icons"
os.makedirs(OUT, exist_ok=True)

def qbez(p0, p1, p2, n=24):
    return [((1-t)**2*p0[0]+2*(1-t)*t*p1[0]+t*t*p2[0],
             (1-t)**2*p0[1]+2*(1-t)*t*p1[1]+t*t*p2[1]) for t in (i/n for i in range(n+1))]

def leaf(base, tip, width, bulge=0.45, vein=0.0):
    """Pointed leaf from base to tip. vein>0 cuts a midrib gap of that width."""
    bx, by = base; tx, ty = tip
    dx, dy = tx-bx, ty-by; L = math.hypot(dx, dy); nx, ny = -dy/L, dx/L
    mx, my = bx+dx*bulge, by+dy*bulge
    c1 = (mx+nx*width, my+ny*width); c2 = (mx-nx*width, my-ny*width)
    pts = qbez(base, c1, tip) + qbez(tip, c2, base)[1:]
    g = Polygon(pts).buffer(0)
    if vein:
        g = g.difference(LineString([(bx+dx*0.12, by+dy*0.12), (bx+dx*0.85, by+dy*0.85)]).buffer(vein/2, cap_style=1))
    return g

def stem(pts, w):
    return LineString(pts).buffer(w/2, cap_style=1, join_style=1)

def pot(cx=50, top=66, bottom=92, wtop=34, wbot=24, rim=7):
    r = box(cx-wtop/2-2, top, cx+wtop/2+2, top+rim).buffer(1.2, join_style=1)
    b = Polygon([(cx-wtop/2, top+rim), (cx+wtop/2, top+rim), (cx+wbot/2, bottom), (cx-wbot/2, bottom)])
    gap = box(0, top+rim, 100, top+rim+1.6)      # thin white line between rim and body
    return unary_union([r, b]).difference(gap)


def layer(shapes, gap=1.4):
    """Stack shapes back-to-front, leaving a white gap around each front shape."""
    g = shapes[0]
    for p in shapes[1:]:
        g = g.difference(p.buffer(gap)).union(p)
    return g

def to_path(geom):
    polys = [geom] if geom.geom_type == "Polygon" else list(geom.geoms)
    d = []
    for p in polys:
        for ring in [p.exterior, *p.interiors]:
            c = list(ring.coords)
            d.append("M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in c[:-1]) + " Z")
    return " ".join(d)

def save(name, geom):
    geom = geom.buffer(0).simplify(0.05)
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
           f'<path fill="#000" fill-rule="evenodd" d="{to_path(geom)}"/></svg>\n')
    open(os.path.join(OUT, name + ".svg"), "w").write(svg)

# ---------- 1. Monstera leaf ----------
def monstera_leaf(cx, cy, s=1.0, rot=0):
    body = Point(0, 0).buffer(30)
    body = affinity.scale(body, 1.0, 1.1)
    notch = Polygon([(0, 30), (-6, 40), (6, 40)])
    body = body.difference(notch)
    tip = Polygon([(-14, -26), (0, -40), (14, -26)])
    body = unary_union([body, tip])
    cuts = []
    for side in (-1, 1):
        for a in (-55, -20, 15, 50):
            ang = math.radians(a)
            ex, ey = side*math.cos(ang)*40, math.sin(ang)*40
            sx, sy = side*math.cos(ang)*12, math.sin(ang)*12+3
            cuts.append(LineString([(sx, sy), (ex, ey)]).buffer(2.2, cap_style=1))
        for a, r in ((-35, 18), (30, 17)):
            ang = math.radians(a)
            cuts.append(Point(side*math.cos(ang)*r, math.sin(ang)*r+2).buffer(2.6))
    body = body.difference(unary_union(cuts))
    body = body.difference(LineString([(0, -30), (0, 28)]).buffer(1.1))
    g = unary_union([body, stem([(0, 28), (0, 46)], 3.4)])
    g = affinity.scale(g, s, s, origin=(0, 0))
    g = affinity.rotate(g, rot, origin=(0, 0))
    return affinity.translate(g, cx, cy)

save("01_monstera_leaf", monstera_leaf(50, 44, 1.0, -12))

# ---------- 2. Monstera in pot ----------
g = layer([stem([(50, 66), (40, 50), (34, 40)], 2.6), stem([(50, 66), (60, 46), (64, 34)], 2.6),
           monstera_leaf(34, 34, 0.52, -28), monstera_leaf(65, 25, 0.56, 24), pot()])
save("02_monstera_pot", g)

# ---------- 3. Snake plant ----------
blades = []
for bx, tx, ty, w in ((40, 26, 18, 8), (60, 75, 22, 8), (45, 40, 6, 9), (55, 62, 10, 9), (50, 50, 26, 7)):
    b = leaf((bx, 68), (tx, ty), w, bulge=0.4)
    stripes = unary_union([LineString([(0, y), (100, y-4)]).buffer(0.8) for y in range(30, 64, 9)])
    blades.append(b.difference(stripes.intersection(leaf((bx, 68), (tx, ty), w*0.6, bulge=0.4))))
save("03_snake_plant", layer(blades + [pot(wtop=36, wbot=26)]))

# ---------- 4. Echeveria succulent ----------
pet = []
for r, n, w in ((26, 7, 9), (18, 6, 8), (10, 5, 6)):
    for i in range(n):
        a = math.radians(-172 + (164/(n-1))*i)
        pet.append(leaf((50, 63), (50+math.cos(a)*r*1.25, 61+math.sin(a)*r), w, bulge=0.55))
pet.append(leaf((50, 63), (50, 46), 5, bulge=0.5))
save("04_echeveria", layer(pet + [pot(top=60, bottom=90, wtop=48, wbot=34)]))

# ---------- 5. Hanging pothos ----------
hp = Polygon(qbez((28, 40), (50, 74), (72, 40)) ).buffer(0)
hp = unary_union([box(25, 36, 75, 42).buffer(1), hp])
ropes = unary_union([stem([(50, 4), (28, 37)], 1.6), stem([(50, 4), (72, 37)], 1.6), stem([(50, 4), (50, 37)], 1.6), Point(50, 4).buffer(3).difference(Point(50, 4).buffer(1.6))])
vines = []
for x0, side, n in ((30, -1, 4), (70, 1, 4), (44, -1, 3)):
    pts = [(x0, 42)] + [(x0+side*(3+ (i%2)*3), 48+i*11) for i in range(n)]
    vines.append(stem(pts, 1.4))
    for i, (px, py) in enumerate(pts[1:]):
        s = side if i % 2 else -side
        vines.append(affinity.rotate(leaf((px, py), (px+s*9, py+5), 4.6, bulge=0.4), 0, origin=(px, py)))
save("05_hanging_pothos", unary_union([hp, ropes] + vines).difference(box(0, 42, 100, 43.4)).union(box(25, 36, 75, 42).buffer(1)))

# ---------- 6. Bonsai ----------
trunk = unary_union([stem([(50, 78), (46, 66), (54, 56), (48, 44), (52, 34)], 5),
                     stem([(52, 58), (66, 50), (72, 46)], 3), stem([(48, 47), (34, 42), (28, 38)], 3)])
canopy = unary_union([Point(x, y).buffer(r) for x, y, r in
                      ((52, 26, 11), (44, 28, 8), (60, 28, 8), (73, 40, 9), (80, 42, 6), (66, 42, 6),
                       (27, 33, 9), (20, 36, 6), (36, 34, 6))])
canopy = affinity.scale(canopy, 1, 0.75, origin=(50, 35))
tray = unary_union([box(18, 78, 82, 84).buffer(1.5), Polygon([(24, 85.5), (76, 85.5), (72, 92), (28, 92)])])
save("06_bonsai", unary_union([trunk, canopy, tray]).difference(box(0, 84.2, 100, 85.5)))

# ---------- 7. Watering can ----------
body = Polygon([(30, 44), (66, 44), (70, 84), (26, 84)]).buffer(2, join_style=1)
handle = Point(48, 40).buffer(17).difference(Point(48, 40).buffer(11.5)).intersection(box(0, 0, 100, 44))
spout = stem([(66, 74), (88, 42)], 6)
rose = affinity.rotate(box(84, 34, 96, 40).buffer(1), 35, origin=(90, 38))
drops = unary_union([affinity.scale(Point(x, y).buffer(1.8), 1, 1.5) for x, y in ((92, 52), (97, 58), (88, 60))])
save("07_watering_can", unary_union([body, handle, spout, rose, drops]).difference(box(26, 56, 72, 58)))

# ---------- 8. Plant mister ----------
bottle = unary_union([box(36, 46, 64, 92).buffer(4, join_style=1), Polygon([(40, 46), (60, 46), (56, 38), (44, 38)])])
cap = box(42, 28, 58, 38).buffer(1)
trig = Polygon([(42, 30), (34, 30), (34, 34), (36, 44), (40, 44), (42, 36)])
nozzle = box(56, 26, 68, 32).buffer(0.8)
mist = unary_union([Point(74+i*5, 29+j).buffer(1.3) for i, j in ((0, 0), (1, -5), (1, 5), (2, 0), (2, -9), (2, 9))])
lf = leaf((50, 82), (50, 58), 7, vein=1.4)
save("08_plant_mister", unary_union([bottle, cap, trig, nozzle, mist]).difference(lf.buffer(1.5)).union(lf).difference(box(36, 37.2, 64, 38.4)))

# ---------- 9. Sprout in hands ----------
bowl = Point(50, 62).buffer(34).intersection(box(0, 62, 100, 100))
bowl = affinity.scale(bowl, 1, 0.7, origin=(50, 62))
thumbs = unary_union([affinity.rotate(affinity.scale(Point(x, 60).buffer(5), 1.5, 0.8), a, origin=(x, 60)) for x, a in ((19, 25), (81, -25))])
hands = unary_union([bowl, thumbs])
cuts = unary_union([LineString([(50, 60), (50, 90)]).buffer(0.9)] +
                   [LineString([(x0, 70), (x1, 82)]).buffer(0.8) for x0, x1 in ((28, 34), (36, 40), (72, 66), (64, 60))])
hands = hands.difference(cuts)
soil = affinity.scale(Point(50, 60).buffer(18), 1, 0.35, origin=(50, 60))
sprout = unary_union([stem([(50, 58), (50, 34)], 3), leaf((50, 40), (28, 28), 9, vein=1.3), leaf((50, 34), (72, 18), 10, vein=1.3)])
save("09_sprout_in_hands", layer([sprout, soil, hands], 1.6))

# ---------- 10. Fiddle leaf fig ----------
trunk = stem([(50, 66), (49, 40), (51, 16)], 3)
leaves = [trunk]
for y, s in ((58, -1), (50, 1), (42, -1), (34, 1), (26, -1)):
    leaves.append(leaf((50, y), (50+s*17, y-12), 9.5, bulge=0.68, vein=1.3))
leaves.append(leaf((51, 20), (52, 3), 8.5, bulge=0.68, vein=1.3))
save("10_fiddle_leaf_fig", layer(leaves + [pot(wtop=30, wbot=22)]))

# ---------- 11. Terrarium ----------
jar = Point(50, 58).buffer(30).difference(Point(50, 58).buffer(26)).difference(box(36, 0, 64, 32))
neck = unary_union([box(36, 22, 40, 34), box(60, 22, 64, 34), box(33, 18, 67, 23).buffer(1)])
ground = Point(50, 58).buffer(26).intersection(box(0, 70, 100, 100))
ground = ground.difference(unary_union([Point(40, 76).buffer(2), Point(58, 80).buffer(1.6), Point(48, 82).buffer(1.2)]))
plants = unary_union([leaf((44, 70), (36, 50), 5), leaf((44, 70), (46, 46), 5), leaf((46, 70), (54, 54), 4),
                      leaf((60, 70), (66, 56), 4), leaf((60, 70), (58, 52), 4), Point(30, 68).buffer(4)])
save("11_terrarium", unary_union([jar, neck, ground, plants]))

# ---------- 12. Garden trowel ----------
blade = leaf((50, 48), (50, 92), 20, bulge=0.3)
blade = affinity.rotate(unary_union([blade, box(46, 46, 54, 54)]), 0)
neck = stem([(50, 48), (50, 38)], 4)
handle = box(44, 8, 56, 38).buffer(3, join_style=1).difference(Point(50, 14).buffer(2.6))
g = unary_union([blade.difference(LineString([(50, 58), (50, 82)]).buffer(0.9)), neck, handle]).difference(box(40, 37.6, 60, 39))
save("12_garden_trowel", affinity.rotate(g, -35, origin=(50, 50)))
print("ok")
