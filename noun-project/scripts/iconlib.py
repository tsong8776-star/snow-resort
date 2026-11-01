"""Shared helpers for building single-colour glyph SVG icons (100x100).
Shapes are built with shapely and flattened into one compound path per icon
(no strokes, no masks, no text) so they are ready for icon marketplaces."""
import math, os, sys
from shapely.geometry import Polygon, Point, LineString, box
from shapely.ops import unary_union
from shapely import affinity


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

def save(name, geom, out):
    geom = geom.buffer(0).simplify(0.05)
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
           f'<path fill="#000" fill-rule="evenodd" d="{to_path(geom)}"/></svg>\n')
    open(os.path.join(out, name + ".svg"), "w").write(svg)


