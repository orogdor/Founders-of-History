"""Päris soengud, habemed, kulmud ja ripsmed MakeHumani CC0 varadest (juuksekaardid alfa-tekstuuriga).

Allikad (Makehuman-2/MH2_Asset_Repository_CCO, väljalase "CC0"):
  hm08-mh_system_CC0.zip               -> sys/   (MakeHumani süsteemi soengud, kulmud, ripsmed)
  legacy-community_hair_pack1_CC0.zip  -> comm/  (kogukonna CC0 soengud)
  hm08-RP_Viking_set_CC0.zip           -> vik/   (viikingi soeng, habe, vuntsid)
Need lahti pakitud kaustas <mh_dir>; mpfb_bodies.py --clothes --mh-hair <mh_dir> kutsub build() iga keha jaoks.
Sobitus kehale käib mhclo failiga (nagu silmadel). Tekstuur muudetakse halliks (alfa jääb), mäng värvib juuksevärviga.
"""
import glob, os
import numpy as np
from PIL import Image

M = None
def init(module):
    global M; M = module

# id: (pakk, kaust, nimi, kohev)  kohev = suure mahuga soeng (mütsi all asendatakse "under_hat" soenguga)
HAIRS = {
    "mh_short01": ("sys", "assets/hair/short01", "Lühike", False),
    "mh_short02": ("sys", "assets/hair/short02", "Lühike siledaks kammitud", False),
    "mh_short03": ("sys", "assets/hair/short03", "Lühike sasitud", False),
    "mh_short04": ("sys", "assets/hair/short04", "Väga lühike", False),
    "mh_bob01": ("sys", "assets/hair/bob01", "Polkpea", True),
    "mh_braid": ("sys", "assets/hair/braid01", "Pats", False),
    "mh_long": ("sys", "assets/hair/long01", "Pikad lahtised juuksed", True),
    "mh_ponytail": ("sys", "assets/hair/ponytail01", "Hobusesaba", False),
    "mh_bob_blunt_bangs": ("comm", "blunt_bob_with_bangs", "Sirge polkpea tukaga", True),
    "mh_bob_page": ("comm", "bob02alternative", "Potisoeng", True),
    "mh_bob_curled": ("comm", "curled_under_bob", "Sissekeeratud polkpea", True),
    "mh_messy": ("comm", "hair_05", "Sasitud", False),
    "mh_pixie": ("comm", "hair_06", "Poisipea", False),
    "mh_bun_messy": ("comm", "messy_bun", "Sasitud nutsu", False),
    "mh_bun_braid": ("comm", "reverse_french_braid_bun_01_variation", "Patsinutsu", False),   # tekstuur: TEX_OVERRIDE
    "mh_shaggy": ("comm", "shaggy_green_hair", "Pikk narmendav", True),
    "mh_short_messy": ("comm", "short_messy_hair", "Lühike narmendav", False),
    "mh_long_bangs": ("comm", "straight_bangs", "Pikad juuksed tukaga", True),
    "mh_curly_long": ("comm", "strawberry_cloud_hair", "Pikad lokid", True),
    "mh_braid_french": ("comm", "unkempt_french_braid_01_variation", "Prantsuse pats", False),
    "mh_viking": ("vik", "assets/hair/scalp_viking", "Viikingi pats", False),
}
# Värvitud (lilla/punane) tekstuuri asemel sama UV-ga loomulik tekstuur
TEX_OVERRIDE = {"mh_bun_braid": ("sys", "assets/hair/braid01/braid01_diffuse.png"),
                "mh_braid_french": ("sys", "assets/hair/braid01/braid01_diffuse.png")}
# habemed: id -> (nimi, [(pakk, kaust), ...])
BEARDS = {
    "mh_beard_long": ("Pikk habe vuntsidega", [("vik", "assets/clothes/beard_viking"), ("vik", "assets/clothes/moustache_viking")]),
    "mh_beard_goatee": ("Pikk lõuahabe", [("vik", "assets/clothes/beard_viking")]),
    "mh_moustache": ("Vuntsid", [("vik", "assets/clothes/moustache_viking")]),
}
BROWS = {"man": "eyebrow001", "woman": "eyebrow010", "boy": "eyebrow010", "girl": "eyebrow010"}
LASHES = "eyelashes01"
TEX_SIZE = 1024
ALPHA_CUTOFF = 0.4

def _files(root, rel):
    d = os.path.join(root, rel)
    clo = sorted(glob.glob(os.path.join(d, "*.mhclo")))[0]
    mats = sorted(glob.glob(os.path.join(d, "*.mhmat")))
    tex = None
    for m in mats:
        for line in open(m, errors="ignore"):
            p = line.split()
            if len(p) >= 2 and p[0] == "diffuseTexture":
                t = os.path.join(d, os.path.basename(p[1]))
                if os.path.exists(t): tex = t; break
        if tex: break
    if tex is None:
        pngs = [p for p in glob.glob(os.path.join(d, "*.png")) if "normal" not in p.lower()]
        tex = max(pngs, key=os.path.getsize)
    return clo, tex

def gray_texture(src, dst, keep_color=False):
    """Juuksetekstuur halliks (värvi annab mäng), alfa alles; suurim külg TEX_SIZE."""
    if os.path.exists(dst): return
    im = Image.open(src).convert("RGBA")
    if max(im.size) > TEX_SIZE:
        s = TEX_SIZE / max(im.size); im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255
    rgb, alpha = a[..., :3], a[..., 3]
    if not keep_color:
        lum = rgb @ np.array([0.2126, 0.7152, 0.0722])
        vis = lum[alpha > 0.5]
        hi = np.percentile(vis, 92) if len(vis) else 1.0
        lum = np.clip(lum / max(hi, 1e-3) * 0.92, 0, 1)
        rgb = np.repeat(lum[..., None], 3, -1)
    out = np.concatenate([rgb, alpha[..., None]], -1)
    Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(dst, optimize=True)

def fit(root, rel, V):
    clo, tex = _files(root, rel)
    P, J, W, VT, F, FT = M.fit_mhclo(clo, V)
    return M.proxy_mesh(P, J, W, VT, F, FT), tex

def write_item(item_id, body, pieces, globals_, rough=0.55):
    g = M.Glb(); names = []
    for k, (md, texname) in enumerate(pieces):
        tex = g.image_uri(f"../../textures/{texname}")
        mat = g.material(f"{item_id}_{k}", (1, 1, 1), rough, 0.0, tex, double=True, alpha=ALPHA_CUTOFF)
        g.mesh(f"{item_id}_{k}", md, mat); names.append(f"{item_id}_{k}")
    os.makedirs(f"{M.PROJECT}/assets/people/clothes/{item_id}", exist_ok=True)
    g.write(f"{M.PROJECT}/assets/people/clothes/{item_id}/{body}.glb", globals_, names,
            {"generated": "tools/mh_hair.py", "source": "MakeHuman CC0 hair assets (Makehuman-2/MH2_Asset_Repository_CCO)"})

def build(mh_dir, body, V, globals_):
    """Kirjutab kõik soengud ja habemed selle keha jaoks. Tagastab tehtud esemete arvu."""
    texdir = f"{M.PROJECT}/assets/people/textures"
    made = 0
    for hid, (pack, rel, _, _) in HAIRS.items():
        md, tex = fit(os.path.join(mh_dir, pack), rel, V)
        if hid in TEX_OVERRIDE: tex = os.path.join(mh_dir, *TEX_OVERRIDE[hid])
        gray_texture(tex, f"{texdir}/{hid}_albedo.png")
        write_item(hid, body, [(md, f"{hid}_albedo.png")], globals_); made += 1
    if body == "man":
        for bid, (_, parts) in BEARDS.items():
            pieces = []
            for pack, rel in parts:
                md, tex = fit(os.path.join(mh_dir, pack), rel, V)
                name = "mh_" + os.path.basename(rel) + "_albedo.png"
                gray_texture(tex, f"{texdir}/{name}")
                pieces.append((md, name))
            write_item(bid, body, pieces, globals_, rough=0.7); made += 1
    return made

def face_parts(mh_dir, body, V):
    """Kulmud ja ripsmed keha glb-faili jaoks: [(nimi, mesh_data, tekstuurifail)]."""
    texdir = f"{M.PROJECT}/assets/people/textures"
    out = []
    for kind, rel in (("brows", f"assets/eyebrows/{BROWS[body]}"), ("lashes", f"assets/eyelashes/{LASHES}")):
        md, tex = fit(os.path.join(mh_dir, "sys"), rel, V)
        name = f"mh_{kind}_{os.path.basename(rel)}_albedo.png"
        gray_texture(tex, f"{texdir}/{name}", keep_color=True)   # kulmud ja ripsmed jäävad oma (tumedat) värvi
        out.append((kind, md, name))
    return out
