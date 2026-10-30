#!/usr/bin/env python3
"""Estrae dal modulo Tabletop Simulator di Colosseum: The Grand Spectacle (file .ttsmod) le immagini
usate dalla versione digitale e calcola le posizioni del tabellone dai punti di aggancio del modulo.

Uso: python3 tools/estrai_materiale.py "<file .ttsmod>" [cartella del progetto]
"""
import io, json, math, os, re, sys, zipfile
from PIL import Image

MOD = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(OUT, "assets")
z = zipfile.ZipFile(MOD)
names = {n.split("/")[-1].rsplit(".", 1)[0]: n for n in z.namelist() if n.startswith("Mods/Images/")}
mod = json.loads(z.read([n for n in z.namelist() if n.startswith("Mods/Workshop/") and n.endswith(".json")][0]))


def key(url):
    return re.sub(r"[^A-Za-z0-9]", "", url)


def img_by(suffix):
    for k, n in names.items():
        if k.endswith(suffix):
            return Image.open(io.BytesIO(z.read(n)))
    raise KeyError(suffix)


def img_url(url):
    return Image.open(io.BytesIO(z.read(names[key(url)])))


def save(im, path, maxw=None, maxh=None, quality=86):
    path = os.path.join(A, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im = im.convert("RGBA") if path.endswith(".png") else im.convert("RGB")
    if maxw or maxh:
        im.thumbnail((maxw or 99999, maxh or 99999), Image.LANCZOS)
    if path.endswith(".png"):
        im.save(path, optimize=True)
    else:
        im.save(path, quality=quality)


# ---------------------------------------------------------------- tabellone e plance
board = img_by("2EE9A3552392BDCAF3DB")
save(board, "tabellone/tabellone.jpg", 2400, quality=88)
for col, suf in {"nero": "8C872DABCAB7DA2E9650", "rosso": "1A5F518377756F963221", "bianco": "8C3474832E3F0D499385",
                 "azzurro": "441CBE0719F935B4CE17", "sabbia": "7F7C047086D21A31218F"}.items():
    save(img_by(suf), "plance/%s.jpg" % col, 1800)

# ---------------------------------------------------------------- tessere Performer (artisti)
PERF = {"gladiatore": "97FDA0BC02FFD35B81DE", "comico": "EF4E961956033743E4EA", "musico": "AABF961AD6951AC15EC2",
        "cavallo": "BFFE3CBD4F049DAB776E", "mangiafuoco": "1617828299A4902F35DA", "sacerdote": "151D1EAB1FFA675EC96B",
        "nave": "B316F850580CDD7498E4", "leone": "8BA0E83B2C9794046FA4", "scenografo": "532107F47A68809A0A08",
        "decoratore": "192D369235D9173BE474", "auriga": "9B59D5B8C35498CE385E", "elefante": "1490C1E9B8E63C3FBDBD",
        "balatro": "1A3D18E1ED81A5BD7DF0", "aquila": "16A0B4A8C9AFE883D8B6", "retro": "61B178EDD4F7DA53",
        "retro_iniziale": "F572839AC23679BE"}
for k, suf in PERF.items():
    save(img_by(suf), "artisti/%s.png" % k, 192)

# ---------------------------------------------------------------- stelle, segnalini, monete
TOK = {"stelle/elefante": "C5A5525892E1E68A3302", "stelle/auriga": "608B3228F7838972643E",
       "stelle/leone": "82CCB67CAD835397E269", "stelle/decoratore": "888A502BCD7787832F4C",
       "stelle/scenografo": "9A67B93D374281423652", "stelle/mangiafuoco": "2B500FE5CF3993CBC670",
       "stelle/nave": "A87269C12D6B171303CB", "stelle/cavallo": "9EB2B027A93D457AAA86",
       "stelle/gladiatore": "82F685E208F4925731DA", "stelle/comico": "9886ED900FF156D01BF2",
       "stelle/musico": "DB8652EF09C79DFD7FD4", "stelle/sacerdote": "4972A0A3F071D1962463",
       "segnalini/promotore1": "3DD85244FF006D8B61DA", "segnalini/promotore2": "007D233EFDE6E58F695F",
       "segnalini/promotore3": "41196B910144CCFD11DF", "segnalini/aquila": "C3F7CF0DFFD2BA29FAA6",
       "segnalini/pilastro": "42DB61631917C85ADFF8", "segnalini/cancello": "5AD1B0D9D1EABE4E6E7B",
       "segnalini/tempio": "313F87B0D11FE9684688", "segnalini/corona_nero": "6C427F99DF4D5CD82AF9",
       "segnalini/corona_azzurro": "47338BE0DFD12AE0941B", "segnalini/corona_rosso": "0CB41489A598F81CF61E",
       "segnalini/corona_bianco": "89AB23E2BEF4367CC7E2", "segnalini/corona_sabbia": "F7F40DB24D36F6935A88",
       "segnalini/dono1": "88344CDAE900C2660BA3", "segnalini/dono2": "91F31CC2870063CDD618",
       "segnalini/dono3": "BEDE985B7A08BF419EC2", "segnalini/dono4": "DC4530306EF256FE7F92",
       "segnalini/primo_giocatore": "B57F77F6DAC0C9DA3F14", "monete/m1": "74A5F0E8E4B304CBBEB0",
       "monete/m3": "1B8F838D88DC24360D88", "monete/m5": "B23C0595874A99AC7AE2",
       "monete/m10": "5BF661F63BF0C715BF8D", "monete/m20": "F4121F154033BEED7988"}
for k, suf in TOK.items():
    save(img_by(suf), k + ".png", 220, 220)

# ---------------------------------------------------------------- tessere Spettacolo (fronte = da pianificare, retro = illustrata)
tiles = []
for o in mod["ObjectStates"]:
    if o["Name"] == "Custom_Tile":
        cc = o["CustomImage"]
        if key(cc["ImageURL"]) in names and names[key(cc["ImageURL"])].endswith(".jpg"):
            tiles.append(cc)
by_front = {key(t["ImageURL"])[-20:]: t for t in tiles}
SPECT = json.load(open(os.path.join(OUT, "tools", "spettacoli_file.json")))
for sid, front in SPECT.items():
    t = by_front[front]
    save(img_url(t["ImageURL"]), "spettacoli/%s_piano.jpg" % sid, 640)
    save(img_url(t["ImageSecondaryURL"]), "spettacoli/%s_arte.jpg" % sid, 640)

# ---------------------------------------------------------------- posizioni sul tabellone
snaps = None
for o in mod["ObjectStates"]:
    if o["Name"] == "Custom_Token" and o["Transform"]["scaleX"] > 7:
        snaps = o["AttachedSnapPoints"]
W, H = board.size
SX = 2.06
SZ = SX * H / W
P = {}
for i, p in enumerate(snaps):
    x, zz = p["Position"]["x"], p["Position"]["z"]
    P[i] = ((0.5 + x / (2 * SX)) * W, (0.5 - zz / (2 * SZ)) * H)


def ang(p, cx=1500, cy=1100):
    return (math.degrees(math.atan2(p[1] - cy, p[0] - cx)) + 90) % 360


noble = sorted(list(range(1, 36)) + [208], key=lambda i: ang(P[i]))
gates = []
for i in list(range(154, 208)) + list(range(209, 227)):
    if i == 184:
        continue
    u, v = P[i]
    if all(math.hypot(u - g[1], v - g[2]) > 25 for g in gates):
        gates.append((i, u, v))
gates.sort(key=lambda g: ang((g[1], g[2])))
# mercati: le 15 posizioni dello script del modulo (coordinate del tavolo), a gruppi di tre fra i corridoi
MK = [(-6.19, 1.5, 105.33), (-5.11, 3.58, 136.98), (-3.42, 4.62, 150), (-1.44, 5.02, 172.59), (1.24, 5.19, 190.2),
      (3.3, 4.64, 209.99), (4.97, 3.62, 225), (6.11, 1.49, 254.99), (5.69, -0.55, 300.02), (4.38, -2.03, 315.02),
      (1.87, -3.18, 344.99), (-0.02, -3.38, 359.99), (-2.03, -3.17, 14.99), (-4.58, -2.05, 44.99), (-5.94, -0.6, 59.99)]
BS = 7.48096132
MKP = [((0.5 + x / BS / (2 * SX)) * W, (0.5 - zz / BS / (2 * SZ)) * H, r) for x, zz, r in MK]
GROUPS = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12], [13, 14, 0]]


def mrot(r):
    a = (r - 180 + 540) % 360 - 180
    if a > 90:
        a -= 180
    if a < -90:
        a += 180
    return round(a, 1)
acc = sorted(range(51, 149), key=lambda i: ang(P[i], 1500, 1172))
s0 = acc.index(105)
acc = acc[s0:] + acc[:s0]
track = []
for k, i in enumerate(acc):
    track.append(P[i])
    if i in (73, 80):                     # due caselle senza punto di aggancio nel modulo
        q = P[acc[(k + 1) % len(acc)]]
        track.append(((P[i][0] + q[0]) / 2, (P[i][1] + q[1]) / 2))
assert len(track) == 100, len(track)


def n(p):
    return [round(p[0] / W, 5), round(p[1] / H, 5)]


AQ = {1, 2, 3, 4, 5, 208}
layout = {
    "board_size": [W, H],
    "noble": [n(P[i]) for i in noble],
    "noble_aquila": [k for k, i in enumerate(noble) if i in AQ],
    "gates": [n((g[1], g[2])) for g in gates],
    "gate_angle": [round(ang((g[1], g[2])), 1) for g in gates],
    "markets": [[n(MKP[i]) for i in g] for g in GROUPS],
    "market_rot": [[mrot(MKP[i][2]) for i in g] for g in GROUPS],
    "acclaim": [n(p) for p in track],
    # spazi del Tempio di Fortuna (le cinque piazzole con l'icona del tempio)
    "temples": [n(p) for p in [(400, 360), (2470, 430), (2745, 1170), (2600, 1995), (485, 2005)]],
    "center": n((1500, 1100)),
}
os.makedirs(os.path.join(OUT, "data"), exist_ok=True)
json.dump(layout, open(os.path.join(OUT, "data", "layout.json"), "w"), indent=1)

# copertina
cov = Image.open(io.BytesIO(z.read([n for n in z.namelist() if n.startswith("Mods/Workshop/") and n.endswith(".png")][0])))
cov = cov.convert("RGB").resize((512, 512), Image.LANCZOS)
os.makedirs(os.path.join(OUT, "ludoteca"), exist_ok=True)
cov.save(os.path.join(OUT, "ludoteca", "copertina.webp"), quality=90)
save(cov, "misc/copertina.jpg")
print("fatto:", len(SPECT), "spettacoli,", len(noble), "caselle dei nobili,", len(gates), "cancelli")
