#!/usr/bin/env python3
"""Trasforma le sagome delle Stelle e dei promotori (PNG con trasparenza) in modellini 3D estrusi,
come fa Tabletop Simulator con i segnalini spessi della versione deluxe. Scrive assets/modelli/<nome>.obj
con le coordinate UV per applicare l'immagine sulle due facce.
Uso: python3 tools/estrudi_sagome.py [cartella del progetto]"""
import os, sys
import numpy as np
from PIL import Image
from skimage import measure
import trimesh
from shapely.geometry import Polygon
from shapely.ops import unary_union

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(OUT, "assets")
SPESSORE = 0.2


def sagoma(png, nome):
    im = np.array(Image.open(png).convert("RGBA"))
    h, w = im.shape[:2]
    alpha = np.pad(im[..., 3] > 110, 2)
    polys = []
    for c in measure.find_contours(alpha.astype(float), 0.5):
        pts = [(x - 2, h - (y - 2)) for y, x in c]
        if len(pts) < 8:
            continue
        p = Polygon(pts).buffer(0)
        if p.area > 40:
            polys.append(p)
    shape = unary_union(polys).simplify(0.6)
    geoms = list(shape.geoms) if hasattr(shape, "geoms") else [shape]
    meshes = []
    for g in geoms:
        if g.area < 40:
            continue
        m = trimesh.creation.extrude_polygon(g, SPESSORE * h)
        meshes.append(m)
    m = trimesh.util.concatenate(meshes)
    # colore pieno per i fianchi, come le sagome di legno: il colore più comune fra i pixel opachi
    rgb = im[..., :3][im[..., 3] > 200].astype(int)
    q = (rgb // 24) * 24
    vals, cnt = np.unique(q, axis=0, return_counts=True)
    dom = vals[cnt.argmax()]
    ys, xs = np.nonzero((im[..., 3] > 200) & (np.abs((im[..., :3] // 24) * 24 - dom).sum(axis=2) == 0))
    k = len(ys) // 2
    side_uv = ((xs[k] + 0.5) / w, 1.0 - (ys[k] + 0.5) / h)
    m.unmerge_vertices()
    v = m.vertices.copy()
    uv = np.stack([v[:, 0] / w, v[:, 1] / h], axis=1)
    fn = m.face_normals
    for fi, f in enumerate(m.faces):
        if abs(fn[fi][2]) < 0.5:
            uv[f] = side_uv
    v = v / h
    v[:, 0] -= (w / h) * 0.5
    v[:, 2] -= SPESSORE * 0.5
    mesh = trimesh.Trimesh(v, m.faces, process=False, visual=trimesh.visual.TextureVisuals(uv=uv))
    dest = os.path.join(A, "modelli", nome + ".obj")
    txt = trimesh.exchange.obj.export_obj(mesh, include_normals=True, include_texture=True, write_texture=False, mtl_name=None)
    if isinstance(txt, tuple):
        txt = txt[0]
    lines = [l for l in txt.splitlines() if not l.startswith("mtllib") and not l.startswith("usemtl")]
    open(dest, "w").write("\n".join(lines) + "\n")
    return len(mesh.faces)


os.makedirs(os.path.join(A, "modelli"), exist_ok=True)
for f in sorted(os.listdir(os.path.join(A, "stelle"))):
    if f.endswith(".png"):
        print(f, sagoma(os.path.join(A, "stelle", f), "stella_" + f[:-4]))
for k in (1, 2, 3):
    print(k, sagoma(os.path.join(A, "segnalini", "promotore%d.png" % k), "promotore%d" % k))
