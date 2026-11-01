"""Generate the 'Camping & Outdoor' glyph icon set (12 SVGs)."""
import math, os, sys
from iconlib import *
OUT = sys.argv[1] if len(sys.argv) > 1 else "icons"
os.makedirs(OUT, exist_ok=True)
S = lambda n, g: save(n, g, OUT)

def flame(cx, base, h, w):
    pts = qbez((cx, base), (cx - w*1.4, base - h*0.35), (cx - w*0.2, base - h)) + \
          qbez((cx - w*0.2, base - h), (cx + w*1.6, base - h*0.45), (cx, base))[1:]
    return Polygon(pts).buffer(0)

def pine(cx, base, h, w):
    tiers = []
    for k in range(3):
        top = base - h + k*h*0.25; bot = base - h*0.2 - (2-k)*h*0.18
        ww = w*(0.55 + k*0.22)
        tiers.append(Polygon([(cx, top), (cx - ww, bot), (cx + ww, bot)]))
    return unary_union(tiers + [box(cx - w*0.12, base - h*0.22, cx + w*0.12, base)])

# 1 Tent
tent = Polygon([(50, 16), (12, 82), (88, 82)])
door = Polygon([(50, 44), (36, 82), (64, 82)])
flap = Polygon([(50, 44), (64, 82), (72, 82)])
poles = unary_union([stem([(50, 16), (44, 8)], 2.4), stem([(50, 16), (56, 8)], 2.4)])
ground = box(6, 84, 94, 88).buffer(1)
S("01_tent", unary_union([tent.difference(door.buffer(0)).union(flap.difference(box(0, 0, 100, 46))), poles, ground]))

# 2 Campfire
f = flame(50, 70, 52, 15)
inner = flame(50, 70, 26, 7)
logs = unary_union([affinity.rotate(box(20, 72, 80, 81).buffer(2, join_style=1), a, origin=(50, 77)) for a in (14, -14)])
S("02_campfire", layer([f.difference(inner.buffer(0)), logs], 1.8))

# 3 Backpack
bodyb = box(28, 26, 72, 90).buffer(8, join_style=1)
flapb = Point(50, 34).buffer(22).intersection(box(20, 18, 80, 44))
pocket = box(36, 60, 64, 82).buffer(3, join_style=1)
handle = Point(50, 18).buffer(8).difference(Point(50, 18).buffer(4.5)).intersection(box(0, 0, 100, 20))
straps = unary_union([box(40, 44, 44, 54), box(56, 44, 60, 54)])
pack = layer([bodyb, flapb, pocket], 1.8)
S("03_backpack", unary_union([pack.difference(box(36, 66, 64, 67.6)), handle, straps.difference(box(0, 0, 100, 44))]))

# 4 Lantern
ring = Point(50, 14).buffer(8).difference(Point(50, 14).buffer(5)).difference(box(0, 14, 100, 30))
cap = Polygon([(36, 30), (64, 30), (58, 20), (42, 20)]).buffer(1)
glass = box(34, 32, 66, 74).buffer(3, join_style=1)
frame_cut = unary_union([box(38, 36, 47, 70), box(53, 36, 62, 70)])
fl = flame(50, 64, 22, 6)
basel = box(30, 76, 70, 86).buffer(2, join_style=1)
S("04_lantern", unary_union([ring, cap, glass.difference(frame_cut).union(fl), basel]).difference(box(0, 30, 100, 32)).difference(box(0, 74, 100, 76)))

# 5 Compass
outer = Point(50, 54).buffer(36).difference(Point(50, 54).buffer(29))
top = box(44, 10, 56, 19).buffer(2).difference(Point(50, 14).buffer(2.2))
needle_n = Polygon([(50, 30), (57, 54), (43, 54)])
needle_s = Polygon([(50, 78), (57, 54), (43, 54)]).difference(Polygon([(50, 73), (54, 56), (46, 56)]))
ticks = unary_union([affinity.rotate(box(49, 26, 51, 31), a, origin=(50, 54)) for a in (0, 90, 180, 270)])
S("05_compass", unary_union([outer, top, needle_n, needle_s, ticks, Point(50, 54).buffer(3)]).difference(Point(50, 54).buffer(1.4)))

# 6 Mountains
big = Polygon([(40, 24), (8, 86), (72, 86)])
small = Polygon([(68, 40), (44, 86), (94, 86)])
snow_cut = LineString([(30, 44), (35, 48), (40, 42), (45, 48), (50, 44)]).buffer(1.4)
snow_cut2 = LineString([(61, 54), (65, 57), (68, 53), (71, 57), (75, 54)]).buffer(1.2)
mtn = layer([big.difference(snow_cut), small.difference(snow_cut2)], 1.8)
S("06_mountains", unary_union([mtn, Point(80, 22).buffer(8)]))

# 7 Canoe & paddle
hull = Polygon(qbez((6, 54), (50, 104), (94, 54)) + qbez((94, 54), (50, 66), (6, 54))[1:]).buffer(0)
blade = affinity.rotate(affinity.scale(Point(26, 22).buffer(7), 0.75, 1.7), -40, origin=(26, 22))
paddle = unary_union([stem([(26, 22), (70, 74)], 3.2), blade])
S("07_canoe", layer([paddle, hull], 1.8))

# 8 Axe in stump
stump = unary_union([box(22, 60, 78, 90).buffer(2, join_style=1), affinity.scale(Point(50, 60).buffer(28), 1, 0.3, origin=(50, 60))])
rings = unary_union([affinity.scale(Point(50, 60).buffer(r).difference(Point(50, 60).buffer(r - 1.4)), 1, 0.3, origin=(50, 60)) for r in (12, 20)])
stump = stump.difference(rings).difference(LineString([(22, 62), (36, 66), (50, 68), (64, 66), (78, 62)]).buffer(1.2))
handle_a = stem([(70, 12), (50, 56)], 5)
head = Polygon([(54, 50), (36, 44), (30, 60), (50, 62)]).buffer(1.5, join_style=1)
S("08_axe_stump", layer([stump, unary_union([handle_a, head])], 1.8))

# 9 Pine forest
S("09_pine_trees", layer([pine(30, 86, 56, 16), pine(72, 86, 60, 17), pine(50, 90, 76, 20)], 1.8))

# 10 Camp mug
mug = box(24, 40, 66, 88).buffer(4, join_style=1)
handle_m = Point(68, 62).buffer(14).difference(Point(68, 62).buffer(8)).difference(box(0, 0, 66, 100))
rim = box(24, 46, 70, 48)
steam = unary_union([LineString([(x, 32), (x - 4, 26), (x, 20), (x - 4, 14)]).buffer(2.2, cap_style=1) for x in (36, 48, 60)])
S("10_camp_mug", unary_union([mug, handle_m, steam]).difference(rim))

# 11 Binoculars
def barrel(cx):
    return unary_union([box(cx - 12, 44, cx + 12, 84).buffer(3, join_style=1), box(cx - 8, 26, cx + 8, 46).buffer(2, join_style=1)])
lens = unary_union([Point(30, 76).buffer(6), Point(70, 76).buffer(6)])
bridge = box(40, 40, 60, 56).buffer(2)
S("11_binoculars", layer([bridge, barrel(30), barrel(70)], 1.8).difference(lens).difference(box(0, 46, 100, 47.8)))

# 12 Flashlight with beam
light = unary_union([box(12, 44, 46, 58).buffer(3, join_style=1), Polygon([(46, 40), (58, 34), (58, 68), (46, 62)])])
light = light.difference(box(26, 47, 32, 55).buffer(1))
beam = unary_union([affinity.rotate(stem([(64, 51), (90, 51)], 3), a, origin=(62, 51)) for a in (-28, 0, 28)])
S("12_flashlight", unary_union([light, beam]))
print("ok")
