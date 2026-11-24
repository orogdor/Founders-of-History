"""Protseduursed tekstuurid inimestele: korduvad kangad (albedo, normaal, karedus) ja küpsetatud nahk.

Kõik kangatekstuurid on heledad hallid, sest mäng värvib riided (tints) albedo korrutamisega.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
from scipy.spatial import cKDTree

# ---------------------------------------------------------------- abifunktsioonid
def fnoise(size, beta=2.0, seed=0, aniso=(1.0, 1.0), shape=None):
    """Korduv (perioodiline) värviline müra FFT kaudu. beta: spektri kalle. aniso: (x, y) sageduse skaala."""
    rng = np.random.default_rng(seed)
    h, w = shape or (size, size)
    white = rng.normal(size=(h, w))
    fy = np.fft.fftfreq(h)[:, None] * h * aniso[1]
    fx = np.fft.fftfreq(w)[None, :] * w * aniso[0]
    f = np.sqrt(fx * fx + fy * fy); f[0, 0] = 1
    out = np.real(np.fft.ifft2(np.fft.fft2(white) / f ** (beta / 2)))
    out -= out.min(); out /= max(out.max(), 1e-9)
    return out

def worley(size, count, seed=0):
    """Korduv rakumüra: tagastab (F1, F2) kaugused."""
    rng = np.random.default_rng(seed)
    pts = rng.random((count, 2)) * size
    tiled = np.concatenate([pts + np.array([dx, dy]) * size for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    yy, xx = np.mgrid[0:size, 0:size]
    d, _ = cKDTree(tiled).query(np.stack([xx.ravel(), yy.ravel()], 1), k=2)
    return d[:, 0].reshape(size, size), d[:, 1].reshape(size, size)

def normal_from_height(h, strength, wrap=True):
    if wrap:
        dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
        dy = (np.roll(h, 1, 0) - np.roll(h, -1, 0)) * 0.5   # +Y = pildis üles
    else:
        dx = np.gradient(h, axis=1); dy = -np.gradient(h, axis=0)
    n = np.stack([-dx * strength, -dy * strength, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8))

def gray(a):
    g = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(np.stack([g, g, g], -1))

def orm(rough, metal=None):
    """glTF metallicRoughness: G = karedus, B = metallilisus."""
    r = np.clip(rough, 0, 1); m = np.zeros_like(r) if metal is None else np.clip(metal, 0, 1)
    return Image.fromarray((np.stack([np.ones_like(r), r, m], -1) * 255).astype(np.uint8))

# ---------------------------------------------------------------- kangad
def weave(size, p, twill=False, seed=0):
    """Kudumuster: tagastab (kõrgus, lõime pealmine mask). p = lõnga laius pikslites."""
    yy, xx = np.mgrid[0:size, 0:size]
    i, j = xx // p, yy // p
    over = ((i - j) % 4 < 2) if twill else ((i + j) % 2 == 0)
    fx, fy = (xx % p + 0.5) / p, (yy % p + 0.5) / p
    warp = np.sin(np.pi * fx) ** 0.7; weft = np.sin(np.pi * fy) ** 0.7
    # lõngade jämeduse kõikumine piki lõnga
    rng = np.random.default_rng(seed)
    slub_x = np.repeat(fnoise(size, 2.2, seed + 1, shape=(size, size // p))[:, :, None], p, 2).reshape(size, size)
    slub_y = np.repeat(fnoise(size, 2.2, seed + 2, shape=(size // p, size))[:, None, :], p, 1).reshape(size, size)
    h = np.where(over, 0.55 + 0.45 * warp * (0.75 + 0.5 * slub_x), 0.55 + 0.45 * weft * (0.75 + 0.5 * slub_y))
    return h, over

def fabric(kind, size=512, seed=3):
    """Tagastab (albedo, normaal, orm) PIL-pildid."""
    low = fnoise(size, 2.6, seed + 10)          # suured laigud
    mid = fnoise(size, 1.6, seed + 11)
    fine = fnoise(size, 0.6, seed + 12)
    if kind in ("linen", "straw"):
        p = 4 if kind == "linen" else 8
        h, over = weave(size, p, False, seed)
        thread = np.where(over, fnoise(size, 2.0, seed + 5, aniso=(0.05, 1)), fnoise(size, 2.0, seed + 6, aniso=(1, 0.05)))
        alb = 0.86 + 0.07 * (h - 0.75) + 0.06 * (thread - 0.5) - 0.025 * (low - 0.5) + 0.03 * (fine - 0.5)
        if kind == "straw":
            alb = 0.8 + 0.18 * (h - 0.6) + 0.1 * (thread - 0.5)
        rough = 0.9 - 0.08 * (h - 0.7)
        return gray(alb), normal_from_height(h, 2.2), orm(rough)
    if kind in ("wool", "denim"):
        h, over = weave(size, 4, True, seed)
        fuzz = fnoise(size, 0.9, seed + 7)
        h = h * (0.55 if kind == "wool" else 1.0) + (0.45 * fuzz if kind == "wool" else 0)
        if kind == "denim":
            alb = np.where(over, 0.74, 0.97) + 0.05 * (fnoise(size, 2.0, seed + 8, aniso=(0.05, 1)) - 0.5) - 0.08 * (low - 0.5)
        else:
            alb = 0.88 + 0.06 * (h - 0.6) - 0.035 * (low - 0.5) + 0.05 * (fuzz - 0.5)
        rough = np.full_like(h, 0.97 if kind == "wool" else 0.85)
        return gray(alb), normal_from_height(h, 1.6 if kind == "wool" else 2.4), orm(rough)
    if kind == "jersey":
        yy, xx = np.mgrid[0:size, 0:size]; p = 4
        col = np.abs(np.sin(np.pi * (xx % p + 0.5) / p))
        v = np.abs(((yy + np.abs((xx % p) - p / 2)) % p) / p - 0.5) * 2
        h = 0.6 * col + 0.4 * v
        alb = 0.9 + 0.04 * (h - 0.6) - 0.05 * (low - 0.5)
        return gray(alb), normal_from_height(h, 1.4), orm(np.full_like(h, 0.9))
    if kind in ("leather", "hide", "oilcloth"):
        f1, f2 = worley(size, 2200, seed)
        grain = np.clip((f2 - f1) / 6.0, 0, 1)
        crease = fnoise(size, 1.8, seed + 20, aniso=(1, 0.35))
        crease = np.clip(1 - np.abs(crease - 0.5) * 12, 0, 1)
        h = 0.5 + 0.25 * grain - 0.35 * crease + 0.15 * mid
        alb = 0.8 + 0.12 * (low - 0.5) * (2 if kind == "hide" else 1) + 0.05 * grain - 0.12 * crease
        rough = (0.72 if kind != "oilcloth" else 0.45) + 0.12 * (low - 0.5) + 0.1 * crease
        return gray(alb), normal_from_height(h, 3.0), orm(rough)
    if kind == "fur":
        strands = fnoise(size, 1.2, seed + 30, aniso=(0.12, 1.0))
        wave = fnoise(size, 3.0, seed + 31)
        h = strands
        alb = 0.55 + 0.45 * strands - 0.08 * (wave - 0.5)
        return gray(alb), normal_from_height(h, 5.0), orm(np.full_like(h, 0.95))
    if kind == "hair":
        fine = fnoise(size, 1.0, seed + 30, aniso=(0.03, 1.0))
        clump = fnoise(size, 2.2, seed + 32, aniso=(0.08, 1.0))
        wave = fnoise(size, 3.2, seed + 31)
        h = 0.55 * fine + 0.45 * clump
        alb = 0.58 + 0.30 * fine + 0.18 * (clump - 0.5) - 0.06 * (wave - 0.5)
        rough = 0.5 + 0.12 * (1 - fine)
        return gray(alb), normal_from_height(h, 4.0), orm(rough)
    if kind == "hairlock":
        # juuksesalgud: v = 0 juur, v = 1 ots; otsad teravnevad ja on läbipaistvad (alfa)
        yy, xx = np.mgrid[0:size, 0:size] / size
        rng = np.random.default_rng(seed + 40)
        locks = 16
        wid = rng.uniform(0.6, 1.5, locks); edges = np.r_[0, np.cumsum(wid)] / wid.sum()
        xs = (xx + 0.012 * np.sin(2 * np.pi * yy * 1.3) + 0.006 * np.sin(2 * np.pi * (yy * 3.1 + xx * 2))) % 1.0
        li = np.clip(np.searchsorted(edges, xs, side="right") - 1, 0, locks - 1)
        xl = (xs - edges[li]) / (edges[li + 1] - edges[li]) * 2 - 1                   # -1..1 salgu sees
        ends = rng.uniform(0.70, 0.95, locks); taper = rng.uniform(0.08, 0.22, locks)
        fine = fnoise(size, 1.0, seed + 41, aniso=(0.03, 1.0))
        clump = fnoise(size, 2.0, seed + 42, aniso=(0.08, 1.0))
        wisp = (fnoise(size, 1.0, seed + 43, aniso=(0.02, 1.0)) - 0.5) * 0.10        # üksikud juuksekarvad otsas
        tip = ends[li] - taper[li] * np.abs(xl) ** 1.4 + wisp
        alpha = (yy < tip) & (yy < 0.985)
        prof = np.sqrt(np.clip(1 - xl * xl, 0, 1))                                  # salgu ümarus
        h = 0.25 * prof + 0.5 * fine + 0.25 * clump
        alb = 0.52 + 0.30 * fine + 0.14 * (clump - 0.5) + 0.06 * prof - 0.08 * np.clip(yy - 0.6, 0, 1)
        rough = 0.48 + 0.14 * (1 - fine)
        g = (np.clip(alb, 0, 1) * 255).astype(np.uint8)
        rgba = Image.fromarray(np.stack([g, g, g, (alpha * 255).astype(np.uint8)], -1), "RGBA")
        return rgba, normal_from_height(h, 4.0), orm(rough)
    if kind == "braid":
        yy, xx = np.mgrid[0:size, 0:size] / size
        phase = yy * 8 + np.where(xx < 0.5, 0.0, 0.5) + np.abs(xx - 0.5) * 1.2
        lobe = np.sin(np.pi * (phase % 1.0)) ** 0.6
        fine = fnoise(size, 1.0, seed + 33, aniso=(0.15, 1.0))
        h = 0.7 * lobe + 0.3 * fine
        alb = 0.55 + 0.35 * lobe + 0.12 * (fine - 0.5)
        return gray(alb), normal_from_height(h, 5.0), orm(0.5 + 0.1 * (1 - lobe))
    if kind in ("twill", "herringbone"):
        yy, xx = np.mgrid[0:size, 0:size]; p = 4; i, j = xx // p, yy // p
        if kind == "herringbone":
            band = 6
            d = np.where((i // band) % 2 == 0, 1, -1)
            over = ((i + d * j) % 4) < 2
        else:
            over = ((i - j) % 4) < 2
        fx, fy = (xx % p + 0.5) / p, (yy % p + 0.5) / p
        h = np.where(over, np.sin(np.pi * fx) ** 0.7, np.sin(np.pi * fy) ** 0.7) * 0.6 + 0.4 * fnoise(size, 0.9, seed + 7) * (kind == "herringbone")
        alb = 0.88 + 0.05 * np.where(over, 1, -1) * (kind == "herringbone") - 0.06 * (low - 0.5) + 0.03 * (fine - 0.5)
        return gray(alb), normal_from_height(h, 2.2), orm(np.full_like(h, 0.9))
    if kind in ("plaid", "stripe"):
        h, over = weave(size, 4, True, seed)
        rng = np.random.default_rng(seed + 50)
        def bands(n):
            widths = rng.choice([8, 16, 24, 48, 64], n); widths = (widths * size / widths.sum()).astype(int)
            widths[-1] += size - widths.sum()
            levels = rng.choice([0.55, 0.7, 0.85, 1.0], n)
            return np.repeat(levels, widths)[:size]
        warp = bands(9)
        if kind == "plaid":
            weft = warp.copy()
            alb = np.where(over, warp[None, :], weft[:, None])
            alb = (alb + np.sqrt(warp[None, :] * weft[:, None])) / 2
        else:
            alb = np.repeat(warp[None, :], size, 0)
        alb = alb * (0.92 + 0.08 * h) - 0.05 * (low - 0.5)
        return gray(alb), normal_from_height(h, 1.8), orm(np.full_like(h, 0.92))
    if kind == "brocade":
        yy, xx = np.mgrid[0:size, 0:size] / size * 2 * np.pi * 4
        motif = np.sin(xx) * np.sin(yy) + 0.5 * np.sin(2 * xx + np.sin(yy) * 1.5) * np.cos(2 * yy) + 0.4 * np.cos(xx + yy) * np.sin(xx - yy)
        motif = (motif - motif.min()) / (motif.max() - motif.min())
        m = motif > 0.55
        h, over = weave(size, 2, False, seed)
        alb = np.where(m, 1.0, 0.72) * (0.94 + 0.06 * h) - 0.03 * (low - 0.5)
        rough = np.where(m, 0.45, 0.85)
        return gray(alb), normal_from_height(h * 0.5 + m * 0.5, 2.0), orm(rough)
    if kind == "knit":
        yy, xx = np.mgrid[0:size, 0:size]; p = 8
        u = (xx % p + 0.5) / p; v = (yy % p + 0.5) / p
        d1 = np.abs(u - 0.5 * (1 - v)); d2 = np.abs(u - (1 - 0.5 * (1 - v)))
        h = np.exp(-(np.minimum(d1, d2) / 0.2) ** 2) + 0.3 * fnoise(size, 0.8, seed + 8)
        alb = 0.84 + 0.12 * (h - 0.5) - 0.05 * (low - 0.5)
        return gray(alb), normal_from_height(h, 3.0), orm(np.full_like(h, 0.97))
    if kind == "felt":
        fuzz = fnoise(size, 0.7, seed + 9); h = 0.5 * fuzz + 0.5 * mid
        alb = 0.86 + 0.08 * (fuzz - 0.5) - 0.06 * (low - 0.5)
        return gray(alb), normal_from_height(h, 1.2), orm(np.full_like(h, 0.98))
    if kind == "quilted":
        yy, xx = np.mgrid[0:size, 0:size] / size; s = 1 / 10
        a = ((xx + yy) / s) % 1.0; b = ((xx - yy) / s) % 1.0
        puff = np.sin(np.pi * a) * np.sin(np.pi * b)
        h0, _ = weave(size, 4, False, seed)
        h = 0.8 * puff ** 0.5 + 0.2 * h0
        alb = 0.82 + 0.14 * puff ** 0.5 - 0.05 * (low - 0.5)
        return gray(alb), normal_from_height(h, 6.0), orm(np.full_like(h, 0.92))
    if kind == "mail":
        yy, xx = np.mgrid[0:size, 0:size].astype(float); p = 16
        row = (yy // (p / 2)); xo = xx + (row % 2) * p / 2
        cx = (np.floor(xo / p) + 0.5) * p - (row % 2) * p / 2; cy = (row + 0.5) * p / 2
        d = np.hypot(xx - cx, (yy - cy) * 1.4)
        ring = np.exp(-((d - p * 0.36) / (p * 0.11)) ** 2)
        h = ring
        alb = 0.35 + 0.6 * ring - 0.08 * (low - 0.5)
        rough = 0.35 + 0.4 * (1 - ring)
        return gray(alb), normal_from_height(h, 4.0), orm(rough, 0.95 * ring + 0.3)
    if kind == "plate":
        brushed = fnoise(size, 0.8, seed + 60, aniso=(1.0, 0.05))
        dent = fnoise(size, 3.0, seed + 61)
        h = 0.2 * brushed + 0.8 * dent
        alb = 0.88 + 0.06 * (brushed - 0.5) - 0.08 * (low - 0.5)
        rough = 0.22 + 0.08 * brushed + 0.1 * (low - 0.5)
        return gray(alb), normal_from_height(h, 1.0), orm(rough, np.full_like(h, 0.95))
    if kind == "camo":
        a = fnoise(size, 3.4, seed + 70); b = fnoise(size, 3.4, seed + 71); c = fnoise(size, 2.8, seed + 72)
        cols = np.array([[0.36, 0.37, 0.23], [0.24, 0.29, 0.18], [0.42, 0.35, 0.24], [0.64, 0.60, 0.46]])
        idx = np.where(a > 0.6, 1, np.where(b > 0.62, 2, np.where(c > 0.68, 3, 0)))
        rgb = cols[idx] * (0.92 + 0.08 * fine[..., None])
        h, _ = weave(size, 4, False, seed)
        return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)), normal_from_height(h, 1.6), orm(np.full_like(h, 0.88))
    if kind == "metal":
        f1, _ = worley(size, 160, seed + 40)
        dent = 1 - np.clip(f1 / 26.0, 0, 1) ** 2
        h = dent + 0.1 * fine
        alb = 0.82 + 0.1 * (low - 0.5) - 0.06 * dent
        rough = 0.32 + 0.15 * (low - 0.5) + 0.1 * fine
        return gray(alb), normal_from_height(h, 2.0), orm(rough, np.full_like(h, 0.9))
    raise ValueError(kind)

# ---------------------------------------------------------------- nahk
def rasterize_faces(size, faces_uv, values, blur=3.0):
    """faces_uv: list of [(u,v),...] (glTF suunaga, v allapoole); values: 0..1 iga tahu kohta."""
    img = Image.new("L", (size, size), 0); d = ImageDraw.Draw(img)
    for pts, val in zip(faces_uv, values):
        if val <= 0:
            continue
        d.polygon([(u * size, v * size) for u, v in pts], fill=int(np.clip(val, 0, 1) * 255))
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return np.array(img, float) / 255.0

def coverage(size, faces_uv):
    img = Image.new("L", (size, size), 0); d = ImageDraw.Draw(img)
    for pts in faces_uv:
        d.polygon([(u * size, v * size) for u, v in pts], fill=255)
    return np.array(img) > 0

def dilate(rgb, mask):
    """Täidab UV-saarte välise ala lähima saare värviga (ei teki mipmap-servi)."""
    _, idx = ndimage.distance_transform_edt(~mask, return_indices=True)
    return rgb[idx[0], idx[1]]

def skin_baked(S, faces_uv, f, masks, tone, seed=1, beard=False):
    """f: valmis väljad (S x S, 0..1): red, brow, beard, scalp. masks: MPFB2 maskide failid."""
    cov = coverage(S, faces_uv)
    m = {k: np.array(Image.open(v).convert("L").resize((S, S), Image.BILINEAR), float) / 255.0 for k, v in masks.items()}
    low = fnoise(S, 3.0, seed + 1); mid = fnoise(S, 1.8, seed + 2); fine = fnoise(S, 0.4, seed + 3)
    tone = np.array(tone, float)
    base = tone[None, None, :] * np.ones((S, S, 3))
    base *= (1 + 0.06 * (low[..., None] - 0.5) + 0.03 * (mid[..., None] - 0.5))
    base[..., 0] *= 1 + 0.03 * (mid - 0.5); base[..., 2] *= 1 - 0.05 * (low - 0.5)
    # punetus: põsed, nina, kõrvad, põlved, küünarnukid, käed
    rosy = np.array([1.04, 0.90, 0.89])
    r = np.clip(0.6 * f["red"] + 0.3 * m["ears"], 0, 1)[..., None]
    base = base * (1 + (rosy - 1) * r)
    # huuled, silmalaud, küüned
    lip_col = tone * np.array([0.93, 0.74, 0.74])
    a = (m["lips"] * 0.6)[..., None]; base = base * (1 - a) + lip_col * a
    base *= (1 - 0.12 * m["eyelids"])[..., None]
    nails = np.clip(m["fingernails"] + m["toenails"], 0, 1)[..., None] * 0.7
    base = base * (1 - nails) + np.array([0.94, 0.82, 0.78]) * nails
    # kulmud: karvatõmbed piki kulmu
    hairs = fnoise(S, 0.5, seed + 9, aniso=(0.22, 1.0))
    ba = np.clip(f["brow"] * (0.7 + 0.6 * hairs), 0, 1)[..., None] * 0.35   # päris kulmud on eraldi võrk
    base = base * (1 - ba) + np.array([0.22, 0.16, 0.11]) * ba
    if beard:
        st = np.clip(f["beard"] * (0.35 + 0.9 * fine), 0, 1)[..., None] * 0.28
        base = base * (1 - st) + np.array([0.30, 0.27, 0.26]) * st
    base *= (1 - 0.07 * f["scalp"])[..., None]
    base = np.clip(base + 0.02 * (fine[..., None] - 0.5), 0, 1)
    base = dilate(base, cov)
    albedo = Image.fromarray((base * 255).astype(np.uint8))
    pores = fnoise(S, 0.15, seed + 4)
    h = 0.55 * pores + 0.25 * fnoise(S, 1.0, seed + 5) + 0.5 * f["brow"] * hairs + (0.2 * f["beard"] * fine if beard else 0)
    normal = normal_from_height(h, 1.5, wrap=False).resize((S // 2, S // 2), Image.LANCZOS)
    rough = 0.6 + 0.06 * (mid - 0.5) - 0.22 * m["lips"] - 0.3 * np.clip(m["fingernails"] + m["toenails"], 0, 1) + 0.15 * f["brow"]
    return albedo, normal, orm(rough).resize((S // 2, S // 2), Image.BILINEAR)
