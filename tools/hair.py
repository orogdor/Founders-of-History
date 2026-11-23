"""Parameetrilised soengud ja habemed MPFB2 kehale.

Soeng = peanahast tehtud "müts" (oma juustejoonega) + vajadusel kardin (pikad juuksed),
torud (hobusesaba, patsid, krooni pats) ja kerad (kukal- ja pealael nutsud, suebi sõlm).
Habe = näo alaosast tehtud kiht (huuled jäävad vabaks MPFB2 huulemaski järgi).
Kõik mõõdud detsimeetrites (MakeHumani ühikud); eksport korrutab SCALE-iga.
"""
import numpy as np
from scipy.spatial import cKDTree
from PIL import Image

M = None   # mpfb_bodies moodul (seatakse init-iga)

def init(module):
    global M
    M = module

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)

def noise3(P, freq, seed=0):
    rng = np.random.default_rng(seed)
    out = np.zeros(len(P))
    for _ in range(6):
        d = rng.normal(size=3); d /= np.linalg.norm(d)
        out += np.sin(P @ d * freq * rng.uniform(0.7, 1.4) + rng.uniform(0, 6.28))
    return out / 6

# ---------------------------------------------------------------- pea mõõdistus
class Head:
    def __init__(self, V, N_body):
        self.V, self.N = V, N_body
        Z = M.VERTEX_ZONE
        body = np.unique(M.FACE_PAD[M.faces_of("body")].ravel())
        self.body = body
        head = body[Z[body] == "head"]
        eyes = [V[M.group_vertices(g)] for g in ("helper-l-eye", "helper-r-eye")]
        self.eye_y = float(np.mean([e[:, 1].mean() for e in eyes]))
        self.eye_z = float(max(e[:, 2].max() for e in eyes))
        H = V[head]
        self.top = float(H[:, 1].max())
        self.neck_y = float(V[M.group_vertices("joint-neck")].mean(0)[1])
        self.shoulder_y = float(V[M.group_vertices("joint-l-shoulder")].mean(0)[1])
        self.chest_y = float(V[M.group_vertices("joint-spine-1")].mean(0)[1])
        self.pelvis_y = float(V[M.group_vertices("joint-pelvis")].mean(0)[1])
        upper = H[H[:, 1] > self.eye_y - 0.3]
        self.c = np.array([0.0, (upper[:, 1].min() + self.top) / 2, (upper[:, 2].min() + upper[:, 2].max()) / 2])
        self.half_w = float(upper[:, 0].max())
        self.nose = V[head[np.argmax(V[head, 2])]]
        # maskid tippudele (kõrvad, huuled)
        uv = np.zeros((len(V), 2))
        for f, ft in zip(M.BASE_F, M.BASE_FT):
            for vi, ti in zip(f, ft):
                if ti >= 0: uv[vi] = M.BASE_VT[ti]
        def mask(name):
            a = np.array(Image.open(f"{M.MPFB}/textures/mpfb_{name}.jpg").convert("L"), float) / 255
            h, w = a.shape
            return a[np.clip(((1 - uv[:, 1]) * (h - 1)).astype(int), 0, h - 1), np.clip((uv[:, 0] * (w - 1)).astype(int), 0, w - 1)]
        self.ears = mask("ears") > 0.2
        self.lips = mask("lips") > 0.2
        lipv = head[self.lips[head]]
        self.mouth_y = float(V[lipv, 1].mean()) if len(lipv) else self.eye_y - 0.75
        self.mouth_w = float(np.abs(V[lipv, 0]).max()) if len(lipv) else 0.25
        front = head[(V[head, 2] > self.c[2]) & (np.abs(V[head, 0]) < 0.3)]
        self.chin_y = float(V[front, 1].min())
        # keha raadius suundade ja kõrguste kaupa (kardina jaoks), käed välja
        sel = body[np.isin(Z[body], ["head", "neck", "torso", "hips"])]
        self.kd = cKDTree(V[sel]); self.kd_idx = sel
        P = V[sel]
        th = np.arctan2(P[:, 0] - self.c[0], P[:, 2] - self.c[2]); r = np.hypot(P[:, 0] - self.c[0], P[:, 2] - self.c[2])
        self.th_bins = 96; self.y0 = 0.0; self.dy = 0.1; ny = int(self.top / self.dy) + 2
        R = np.zeros((ny, self.th_bins))
        ti = ((th + np.pi) / (2 * np.pi) * self.th_bins).astype(int) % self.th_bins
        yi = np.clip((P[:, 1] / self.dy).astype(int), 0, ny - 1)
        np.maximum.at(R, (yi, ti), r)
        for _ in range(3):   # täida tühjad lahtrid naabritest
            R = np.maximum(R, np.maximum(np.roll(R, 1, 1), np.roll(R, -1, 1)) * (R == 0))
        self.R = R

    def theta(self, P):
        return np.arctan2(P[..., 0] - self.c[0], P[..., 2] - self.c[2])

    def body_r(self, y, th):
        yi = np.clip((np.asarray(y) / self.dy).astype(int), 0, self.R.shape[0] - 1)
        ti = ((np.asarray(th) + np.pi) / (2 * np.pi) * self.th_bins).astype(int) % self.th_bins
        r = self.R[yi, ti]
        r2 = self.R[np.clip(yi + 1, 0, self.R.shape[0] - 1), ti]; r3 = self.R[np.clip(yi - 1, 0, self.R.shape[0] - 1), ti]
        return np.maximum(r, np.maximum(r2, r3))

    def push_out(self, P, clear):
        """Lükkab punktid kehast eemale vähemalt 'clear' kaugusele."""
        P = P.copy()
        for _ in range(3):
            d, i = self.kd.query(P)
            q = self.V[self.kd_idx[i]]
            bad = d < clear
            if not bad.any(): break
            v = P[bad] - q[bad]; n = np.linalg.norm(v, axis=1, keepdims=True); n[n == 0] = 1
            P[bad] = q[bad] + v / n * clear
        return P

    def weights(self, P, head_until=None):
        """Nahakaalud: lähima kehatipu kaalud, ainult pea/kael/selg; ülal ainult pea."""
        d, i = self.kd.query(P)
        src = self.kd_idx[i]
        allowed = {M.BONE_INDEX[b] for b in ("head", "neck_01", "spine_03", "spine_02", "spine_01", "pelvis")}
        clav = {M.BONE_INDEX["clavicle_l"], M.BONE_INDEX["clavicle_r"]}
        J = np.zeros((len(P), 4), np.uint16); W = np.zeros((len(P), 4), np.float32)
        head = M.BONE_INDEX["head"]
        hy = self.neck_y + 0.6 if head_until is None else head_until
        for k, s in enumerate(src):
            acc = {}
            for j in range(4):
                b, w = int(M.JOINTS[s, j]), float(M.WTS[s, j])
                if w <= 0: continue
                if b in clav: b = M.BONE_INDEX["spine_03"]
                if b not in allowed: b = M.BONE_INDEX["spine_03"]
                acc[b] = acc.get(b, 0) + w
            t = float(smoothstep(hy - 0.4, hy + 0.2, P[k, 1]))
            acc = {b: w * (1 - t) for b, w in acc.items()}
            acc[head] = acc.get(head, 0) + t
            top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]; tot = sum(w for _, w in top) or 1
            for j, (b, w) in enumerate(top):
                J[k, j] = b; W[k, j] = w / tot
        return J, W

# ---------------------------------------------------------------- võrgu abid
def grid_mesh(P, rows, cols, closed=False):
    """P: (rows*cols,3) ridade kaupa. Tagastab kolmnurgad."""
    tris = []
    cc = cols if closed else cols - 1
    for r in range(rows - 1):
        for c in range(cc):
            a = r * cols + c; b = r * cols + (c + 1) % cols; d = (r + 1) * cols + c; e = (r + 1) * cols + (c + 1) % cols
            tris += [(a, d, b), (b, d, e)]
    return np.array(tris, np.int64)

def normals(P, T):
    N = np.zeros_like(P)
    fn = np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]])
    for k in range(3): np.add.at(N, T[:, k], fn)
    n = np.linalg.norm(N, axis=1, keepdims=True); n[n == 0] = 1
    return N / n

class Part:
    def __init__(self, P, T, UV, J, W, C=None):
        self.P, self.T, self.UV, self.J, self.W = P, T, UV, J, W
        self.C = np.ones(len(P)) if C is None else C

def merge(parts):
    P, T, UV, J, W, C = [], [], [], [], [], []
    off = 0
    for p in parts:
        P.append(p.P); T.append(p.T + off); UV.append(p.UV); J.append(p.J); W.append(p.W); C.append(p.C); off += len(p.P)
    return Part(np.concatenate(P), np.concatenate(T), np.concatenate(UV), np.concatenate(J), np.concatenate(W), np.concatenate(C))

def to_md(part, flip=False):
    P = part.P; T = part.T[:, ::-1] if flip else part.T
    N = normals(P, T)
    c = np.clip(part.C, 0, 1) ** 2.2
    return dict(pos=(P * M.SCALE).astype(np.float32), nor=N.astype(np.float32), joi=part.J.astype(np.uint16),
                wei=part.W.astype(np.float32), uv=part.UV.astype(np.float32), idx=T.astype(np.uint32).ravel(),
                col=np.stack([c, c, c, np.ones_like(c)], 1).astype(np.float32))

# ---------------------------------------------------------------- soengu osad
def hairline(h, s, th):
    """Juustejoone kõrgus suuna th järgi. s: front, side (silmade suhtes), back (kaela suhtes)."""
    a = np.abs(th)
    fy = h.eye_y + s["front"] - 0.12; sy = h.eye_y + s["side"] - 0.16; by = h.neck_y + s["back"] - 0.05
    tp = s.get("temple", 0.0) * 0.5
    return np.interp(a, [0, 0.6, 1.0, 1.57, 2.3, np.pi], [fy, fy + tp, fy - (fy - sy) * 0.6 + tp * 0.5, sy, (sy + by) / 2, by])

def cap(h, s, seed):
    V, N = h.V, h.N
    fids = np.array(M.faces_of("body"))
    pad = M.FACE_PAD[fids]
    Z = M.VERTEX_ZONE
    th = h.theta(V)
    yl = hairline(h, s, th)
    zone_ok = np.isin(Z, ["head", "neck"]) & ~h.ears
    inside = V[:, 1] >= yl
    near = V[:, 1] >= yl - 0.3
    keep = inside[pad].any(1) & near[pad].all(1) & zone_ok[pad].all(1)
    fids = fids[keep]
    used = np.unique(M.FACE_PAD[fids].ravel())
    T0 = s["thick"]
    above = V[:, 1] - yl
    t = 0.015 + T0 * smoothstep(0, s.get("ramp", 0.25), above)
    t *= 1 + s.get("vol", 0.3) * smoothstep(h.eye_y + 0.5, h.top, V[:, 1])
    if s.get("curly"):
        t += s["curly"] * 0.5 * smoothstep(0, 0.2, above)
    P = V + N * t[:, None]
    low = ~inside
    P[low, 1] = yl[low]                      # sile juustejoon: välimised tipud joonele
    P[low] += N[low] * 0.015
    P = M.taubin(P, fids.tolist(), 6, 0.5, -0.53)
    if s.get("curly"):                       # lokid silumise järel, muidu silutakse ära
        c = s["curly"]
        bump = c * (0.6 * noise3(V, 16.0, seed) + 0.4 * noise3(V, 31.0, seed + 7))
        P += N * (np.abs(bump) * smoothstep(0, 0.15, above))[:, None]
    remap = -np.ones(len(V), int); remap[used] = np.arange(len(used))
    Pc = P[used]
    tris = []
    for fi in fids:
        f = M.BASE_F[fi]
        for k in range(1, len(f) - 1):
            tris.append((remap[f[0]], remap[f[k]], remap[f[k + 1]]))
    T = np.array(tris)
    rel = Pc - h.c
    phi = np.arccos(np.clip(rel[:, 1] / np.linalg.norm(rel, axis=1), -1, 1))
    thc = h.theta(Pc)
    UV = np.stack([thc * 0.55, phi * 0.9], 1)
    J = np.zeros((len(Pc), 4), np.uint16); J[:, 0] = M.BONE_INDEX["head"]; W = np.zeros((len(Pc), 4), np.float32); W[:, 0] = 1
    C = 0.82 + 0.18 * smoothstep(0, 0.3, np.maximum(above[used], 0))    # juured tumedamad
    part = Part(Pc, T, UV, J, W, C)
    # piiritipud kardina jaoks (alumine äär küljel ja taga)
    edges = {}
    for a, b, c in T:
        for e in ((a, b), (b, c), (c, a)):
            k = tuple(sorted(e)); edges[k] = edges.get(k, 0) + 1
    bverts = np.unique([v for e, n in edges.items() if n == 1 for v in e])
    return part, Pc, bverts, t[used]

def curtain(h, s, cap_P, bverts, seed):
    rng = np.random.default_rng(seed)
    th = h.theta(cap_P[bverts])
    lower = (np.abs(th) >= s["curtain_from"]) & (cap_P[bverts, 1] < h.eye_y + s["side"] + 0.45)
    pts = cap_P[bverts[lower]]; th = th[lower]
    if len(pts) < 6:
        return None
    order = np.argsort(np.where(th < 0, th + 2 * np.pi, th))
    pts = pts[order]
    # serv on sakiline (tipud vahelduvad): silu nurga järjekorras
    k = 7; pad = np.vstack([pts[:1].repeat(k // 2, 0), pts, pts[-1:].repeat(k // 2, 0)])
    pts = np.stack([np.convolve(pad[:, j], np.ones(k) / k, mode="valid") for j in range(3)], 1)
    # ühtlane jaotus kaare pikkuse järgi
    seg = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    n = max(16, int(seg[-1] / 0.12))
    st = np.stack([np.interp(np.linspace(0, seg[-1], n), seg, pts[:, k]) for k in range(3)], 1)
    rows = 18
    y_end = s["length_y"](h)
    jitter = rng.uniform(-1, 1, n) * s.get("jag", 0.12)
    P = np.zeros((rows, n, 3))
    st = st + np.array([0, 0.3, 0])
    th0 = h.theta(st)
    r_prev = h.body_r(st[:, 1], th0) + 0.01
    R_in = np.zeros((rows, n))
    clear = s.get("clear", 0.18)
    for r in range(rows):
        f = r / (rows - 1)
        y = st[:, 1] + (y_end + jitter - st[:, 1]) * f
        # õlgadest allpool lähevad juuksed selja taha
        back = np.sign(th0) * np.maximum(np.abs(th0), s.get("behind", 2.05))
        tt = th0 + (back - th0) * smoothstep(h.shoulder_y + 0.6, h.shoulder_y - 0.4, y)
        body = h.body_r(y, tt)
        rb = body + clear
        rad = np.maximum(rb, r_prev * 0.985) if r else r_prev
        rad = r_prev + (rad - r_prev) * min(1.0, 0.35 + f * 2.5) if r else rad      # tuleb mütsi alt sujuvalt välja
        if r and f > 0.35:   # õlgadel ei hakka juuksed külgedele turritama: otsad jäävad õlale
            rad = np.minimum(rad, r_prev + 0.025)
        if s.get("tuck"):   # polkpea ots keerab sisse
            rad = rad - s["tuck"] * smoothstep(0.7, 1.0, f)
        rad = rad + s.get("wave", 0.0) * np.sin(y * 6 + np.arange(n) * 0.7)
        P[r, :, 0] = h.c[0] + np.sin(tt) * rad
        P[r, :, 2] = h.c[2] + np.cos(tt) * rad
        P[r, :, 1] = y
        R_in[r] = np.maximum(body + 0.025, rad - (0.035 + 0.09 * (1 - f)))   # sisemine kiht: juuste paksus
        r_prev = rad
    # sisemine kiht samade nurkade ja kõrgustega
    Pi = P.copy()
    th_all = np.arctan2(P[:, :, 0] - h.c[0], P[:, :, 2] - h.c[2])
    Pi[:, :, 0] = h.c[0] + np.sin(th_all) * R_in; Pi[:, :, 2] = h.c[2] + np.cos(th_all) * R_in
    P = P.reshape(-1, 3); Pi = Pi.reshape(-1, 3)
    T = grid_mesh(P, rows, n)
    Ti = grid_mesh(Pi, rows, n)[:, ::-1] + len(P)
    # külgservad: välimine ja sisemine kiht kokku (paksus näha)
    side = []
    for c in (0, n - 1):
        for r in range(rows - 1):
            a, b = r * n + c, (r + 1) * n + c
            q = (a, b, b + len(P), a + len(P))
            side += [(q[0], q[1], q[2]), (q[0], q[2], q[3])] if c == 0 else [(q[0], q[2], q[1]), (q[0], q[3], q[2])]
    # UV: u = kaare pikkus (salgud ~1,5 cm), v = 0 juur ... 0.97 ots
    arc = np.r_[0, np.cumsum(np.linalg.norm(np.diff(st, axis=0), axis=1))]
    u = np.tile(arc / 2.0, rows); v = np.repeat(np.arange(rows), n) / (rows - 1) * 0.97
    UV = np.stack([u, v], 1)
    Pall = np.vstack([P, Pi]); UVall = np.vstack([UV, UV + [0.37, 0]])
    J, W = h.weights(Pall)
    C = 0.82 + 0.18 * np.repeat(np.arange(rows) / (rows - 1), n)
    Call = np.r_[C, C * 0.8]
    return Part(Pall, np.vstack([T, Ti, np.array(side)]), UVall, J, W, Call)

def tube(h, path, radius, sides=10, uv_scale=0.9, head_until=None, dense_in=False):
    path = np.asarray(path, float)
    # sile tee (Catmull-Rom tihendus)
    dense = [] if not dense_in else list(path[:-1])
    for i in (range(len(path) - 1) if not dense_in else []):
        p0 = path[max(i - 1, 0)]; p1 = path[i]; p2 = path[i + 1]; p3 = path[min(i + 2, len(path) - 1)]
        for t in np.linspace(0, 1, 6, endpoint=False):
            t2, t3 = t * t, t * t * t
            dense.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    dense.append(path[-1]); dense = np.array(dense)
    rr = np.interp(np.linspace(0, 1, len(dense)), np.linspace(0, 1, len(radius)), radius)
    dense = h.push_out(dense, 0.0) if False else dense
    rings, tang = [], None
    nrm = None
    for i, p in enumerate(dense):
        t = dense[min(i + 1, len(dense) - 1)] - dense[max(i - 1, 0)]; t /= np.linalg.norm(t) + 1e-9
        if nrm is None:
            nrm = np.cross(t, [1, 0, 0]); nrm /= np.linalg.norm(nrm) + 1e-9
        else:
            nrm = nrm - t * (nrm @ t); nrm /= np.linalg.norm(nrm) + 1e-9
        bn = np.cross(t, nrm)
        a = np.linspace(0, 2 * np.pi, sides, endpoint=False)
        rings.append(p + (np.outer(np.cos(a), nrm) + np.outer(np.sin(a), bn)) * rr[i])
    P = np.concatenate(rings)
    T = grid_mesh(P, len(dense), sides, closed=True)
    # otsakork lõppu
    tip = len(P); P = np.vstack([P, dense[-1] + (dense[-1] - dense[-2]) * 0.3])
    last = (len(dense) - 1) * sides
    T = np.vstack([T, [(last + k, tip, last + (k + 1) % sides) for k in range(sides)]])
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(dense, axis=0), axis=1))]
    UV = np.stack([np.tile(np.arange(sides) / sides, len(dense)), np.repeat(L, sides) * uv_scale], 1)
    UV = np.vstack([UV, [0.5, L[-1] * uv_scale]])
    J, W = h.weights(P, head_until)
    return Part(P, T, UV, J, W)

def braid3(h, path, radius, head_until=None, clear=0.05):
    """Kolmeharuline punutis: kolm salku keerduvad ümber keskjoone (vaheldumisi üle ja alt)."""
    path = np.asarray(path, float)
    dense = []
    for i in range(len(path) - 1):
        p0 = path[max(i - 1, 0)]; p1 = path[i]; p2 = path[i + 1]; p3 = path[min(i + 2, len(path) - 1)]
        for t in np.linspace(0, 1, 10, endpoint=False):
            t2, t3 = t * t, t * t * t
            dense.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    dense.append(path[-1]); dense = np.array(dense)
    rr = np.interp(np.linspace(0, 1, len(dense)), np.linspace(0, 1, len(radius)), radius)
    dense = h.push_out(dense, float(np.max(radius)) + clear)
    for _ in range(3):   # silu pärast väljalükkamist
        dense[1:-1] = (dense[:-2] + dense[1:-1] * 2 + dense[2:]) / 4
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(dense, axis=0), axis=1))]
    # paralleelne raam
    frames = []; nrm = None
    for i in range(len(dense)):
        t = dense[min(i + 1, len(dense) - 1)] - dense[max(i - 1, 0)]; t /= np.linalg.norm(t) + 1e-9
        if nrm is None:
            nrm = np.cross(t, [0, 0, 1.0]); nrm = nrm if np.linalg.norm(nrm) > 0.1 else np.cross(t, [1.0, 0, 0])
        nrm = nrm - t * (nrm @ t); nrm /= np.linalg.norm(nrm) + 1e-9
        frames.append((nrm.copy(), np.cross(t, nrm)))
    parts = []
    period = float(np.mean(radius)) * 3.2
    for k in range(3):
        ph = 2 * np.pi * (L / period + k / 3.0)
        strand = np.array([dense[i] + frames[i][0] * np.sin(ph[i]) * rr[i] * 0.55 + frames[i][1] * np.sin(2 * ph[i]) * rr[i] * 0.28
                           for i in range(len(dense))])
        # ots: salgud koonduvad sõlmeks
        conv = smoothstep(L[-1] - 0.35, L[-1] - 0.1, L)
        strand = strand + (dense - strand) * conv[:, None]
        sr = rr * 0.55 * (1 - 0.35 * conv)
        parts.append(tube(h, strand[::2], sr[::2], 7, uv_scale=0.9, head_until=head_until, dense_in=True))
    # sõlmest allpool väike tutt
    end = dense[-1]; dirv = dense[-1] - dense[-4]; dirv /= np.linalg.norm(dirv) + 1e-9
    tuft = [end - dirv * 0.05, end + dirv * 0.15, end + dirv * 0.35]
    parts.append(tube(h, tuft, [rr[-1] * 0.7, rr[-1] * 0.9, rr[-1] * 0.25], 8, head_until=head_until))
    return merge(parts)

def disc(h, center, R, thick, segs=28):
    """Ümar ehteketas (nt pronksist vööketas): kumer esipind keskmise nupuga, lame tagakülg."""
    rings = [(0.0, thick * 1.6), (0.12 * R, thick * 1.5), (0.2 * R, thick * 0.9), (0.55 * R, thick * 0.75), (0.85 * R, thick * 0.55),
             (R, thick * 0.3), (R, 0.0), (0.0, 0.0)]
    P = []
    for r, z in rings:
        for j in range(segs):
            a = 2 * np.pi * j / segs
            P.append(center + np.array([np.cos(a) * r, np.sin(a) * r, z]))
    P = np.array(P)
    T = grid_mesh(P, len(rings), segs, closed=True)
    UV = np.stack([P[:, 0] - center[0], P[:, 1] - center[1]], 1) * 1.5 + 0.5
    J, W = h.weights(P)
    C = np.ones(len(P)); C[: segs * 2] = 1.0; C[segs * 2: segs * 3] = 0.75   # soon nupu ümber
    return Part(P, T, UV, J, W, C)

def ellipsoid(h, center, radii, rings=10, segs=14):
    P = []
    for i in range(rings + 1):
        v = np.pi * i / rings
        for j in range(segs):
            u = 2 * np.pi * j / segs
            P.append(center + np.array([np.sin(v) * np.cos(u) * radii[0], np.cos(v) * radii[1], np.sin(v) * np.sin(u) * radii[2]]))
    P = np.array(P)
    T = grid_mesh(P, rings + 1, segs, closed=True)
    UV = np.stack([np.tile(np.arange(segs) / segs, rings + 1) * 1.5, np.repeat(np.arange(rings + 1) / rings, segs) * 1.2], 1)
    J = np.zeros((len(P), 4), np.uint16); J[:, 0] = M.BONE_INDEX["head"]; W = np.zeros((len(P), 4), np.float32); W[:, 0] = 1
    return Part(P, T, UV, J, W, np.full(len(P), 0.92))

def head_point(h, th, y, out=0.0):
    r = h.body_r(np.array([y]), np.array([th]))[0] + out
    return np.array([h.c[0] + np.sin(th) * r, y, h.c[2] + np.cos(th) * r])

# ---------------------------------------------------------------- stiilid
def base(front=0.6, side=0.35, back=0.55, thick=0.06, vol=0.3, ramp=0.25, **kw):
    d = dict(front=front, side=side, back=back, thick=thick, vol=vol, ramp=ramp); d.update(kw); return d

L_SHOULDER = lambda h: h.shoulder_y - 0.2
L_UPPERBACK = lambda h: h.chest_y - 0.3
L_MIDBACK = lambda h: h.chest_y - 1.6
L_CHIN = lambda h: h.chin_y + 0.1
L_NECK = lambda h: h.neck_y + 0.1

STYLES = {
    # mehed
    "hair_m_buzz":      dict(name="Siilisoeng", cap=base(temple=0.1, front=0.62, side=0.4, back=0.5, thick=0.02, vol=0.1)),
    "hair_m_crop":      dict(name="Lühike lõikus", cap=base(temple=0.1, front=0.58, side=0.35, back=0.45, thick=0.055, vol=0.35)),
    "hair_m_sidepart":  dict(name="Külgkammiga lühike", cap=base(temple=0.1, front=0.55, side=0.33, back=0.45, thick=0.075, vol=0.7)),
    "hair_m_slicked":   dict(name="Tahapoole kammitud", cap=base(temple=0.1, front=0.6, side=0.38, back=0.4, thick=0.045, vol=0.2, ramp=0.15)),
    "hair_m_bowl":      dict(name="Potisoeng", cap=base(front=0.25, side=0.15, back=0.55, thick=0.11, vol=0.15, ramp=0.06)),
    "hair_m_bob":       dict(name="Lõuani polkpea", cap=base(front=0.3, side=0.45, back=0.35, thick=0.09, vol=0.2, ramp=0.1),
                             curtain=dict(curtain_from=0.75, length_y=L_CHIN, clear=0.14, jag=0.05, behind=1.0, tuck=0.05)),
    "hair_m_shoulder":  dict(name="Õlgadeni juuksed", cap=base(front=0.55, side=0.45, back=0.3, thick=0.07, vol=0.3),
                             curtain=dict(curtain_from=1.2, length_y=L_SHOULDER, clear=0.17, jag=0.1)),
    "hair_m_wild":      dict(name="Pikk sasitud", cap=base(front=0.5, side=0.45, back=0.3, thick=0.11, vol=0.5, curly=0.05),
                             curtain=dict(curtain_from=1.15, length_y=L_UPPERBACK, clear=0.2, jag=0.25, wave=0.04)),
    "hair_m_ponytail":  dict(name="Kuklas hobusesaba", cap=base(temple=0.1, front=0.6, side=0.4, back=0.35, thick=0.045, vol=0.15),
                             tail=dict(kind="ponytail", y="low", length=2.2, r=0.22)),
    "hair_m_braid":     dict(name="Pats seljal", cap=base(temple=0.1, front=0.58, side=0.4, back=0.35, thick=0.05, vol=0.15),
                             tail=dict(kind="braid", y="low", length=3.0, r=0.2)),
    "hair_m_suebian":   dict(name="Suebi sõlm", cap=base(temple=0.1, front=0.6, side=0.42, back=0.4, thick=0.05, vol=0.2),
                             buns=[dict(th=2.05, y=0.25, r=(0.42, 0.36, 0.36))]),
    "hair_m_topknot":   dict(name="Pealae nuts", cap=base(temple=0.1, front=0.6, side=0.4, back=0.4, thick=0.04, vol=0.1),
                             buns=[dict(th=np.pi, y=0.85, r=(0.32, 0.3, 0.32))]),
    "hair_m_curly":     dict(name="Lokkis lühike", cap=base(temple=0.1, front=0.52, side=0.35, back=0.45, thick=0.08, vol=0.4, curly=0.07)),
    # naised
    "hair_w_long":      dict(name="Pikad lahtised", cap=base(front=0.62, side=0.5, back=0.25, thick=0.06, vol=0.2),
                             curtain=dict(curtain_from=1.15, length_y=L_MIDBACK, clear=0.16, jag=0.12)),
    "hair_w_braids2":   dict(name="Kaks patsi ees", cap=base(front=0.62, side=0.45, back=0.3, thick=0.05, vol=0.15),
                             tail=dict(kind="braids2", length=3.4, r=0.17)),
    "hair_w_braid":     dict(name="Pats seljal", cap=base(front=0.62, side=0.45, back=0.3, thick=0.05, vol=0.15),
                             tail=dict(kind="braid", y="low", length=4.2, r=0.21)),
    "hair_w_bun_low":   dict(name="Kuklanuts", cap=base(front=0.62, side=0.45, back=0.35, thick=0.05, vol=0.15),
                             buns=[dict(th=np.pi, y=-0.1, r=(0.48, 0.38, 0.36))]),
    "hair_w_bun_high":  dict(name="Kõrge nuts", cap=base(front=0.62, side=0.45, back=0.38, thick=0.05, vol=0.2),
                             buns=[dict(th=np.pi, y=0.75, r=(0.46, 0.42, 0.44))]),
    "hair_w_ponytail":  dict(name="Kõrge hobusesaba", cap=base(front=0.62, side=0.45, back=0.38, thick=0.045, vol=0.15),
                             tail=dict(kind="ponytail", y="high", length=3.0, r=0.24)),
    "hair_w_crown":     dict(name="Pärjapats", cap=base(front=0.62, side=0.45, back=0.35, thick=0.05, vol=0.1),
                             tail=dict(kind="crown", r=0.2)),
    "hair_w_bob":       dict(name="Polkpea tukaga", cap=base(front=0.28, side=0.45, back=0.3, thick=0.09, vol=0.25, ramp=0.1),
                             curtain=dict(curtain_from=0.7, length_y=L_CHIN, clear=0.13, jag=0.04, behind=1.0, tuck=0.05)),
    "hair_w_pixie":     dict(name="Lühike poisipea", cap=base(front=0.45, side=0.32, back=0.45, thick=0.07, vol=0.5)),
    "hair_w_curly":     dict(name="Lokkis õlgadeni", cap=base(front=0.55, side=0.45, back=0.3, thick=0.1, vol=0.4, curly=0.08),
                             curtain=dict(curtain_from=0.95, length_y=L_SHOULDER, clear=0.2, jag=0.15, wave=0.06)),
    "hair_w_shoulder":  dict(name="Õlgadeni juuksed", cap=base(front=0.6, side=0.48, back=0.28, thick=0.065, vol=0.25),
                             curtain=dict(curtain_from=1.1, length_y=L_SHOULDER, clear=0.16, jag=0.08)),
}

BEARDS = {
    "beard_short":     dict(name="Lühike habe", thick=0.045, drop=0.08, moustache=True, cheek=0.5),
    "beard_full":      dict(name="Täishabe", thick=0.1, drop=0.45, moustache=True, cheek=0.55, under=True),
    "beard_long":      dict(name="Pikk habe", thick=0.12, drop=1.3, moustache=True, cheek=0.58, under=True),
    "beard_moustache": dict(name="Vuntsid", thick=0.05, drop=0.0, only_moustache=True),
    "beard_goatee":    dict(name="Kitsehabe", thick=0.07, drop=0.35, moustache=True, goatee=True),
}

def build_style(h, sid, seed=7):
    s = STYLES[sid]
    parts = []; braids = []
    c, cap_P, bverts, t = cap(h, s["cap"], seed)
    parts.append(c)
    locks = []
    if "curtain" in s:
        cur = curtain(h, {**s["cap"], **s["curtain"]}, cap_P, bverts, seed)
        if cur is not None: locks.append(cur)
    tl = s.get("tail")
    if tl:
        if tl["kind"] in ("ponytail", "braid"):
            y0 = h.eye_y + (0.05 if tl["y"] == "low" else 0.7)
            p0 = head_point(h, np.pi, y0, 0.05)
            back = np.array([0, 0, -1.0])
            if tl["kind"] == "ponytail":
                path = [p0, p0 + back * 0.35 + [0, -0.1, 0], p0 + back * 0.55 + [0, -0.6, 0], p0 + back * 0.6 + [0, -tl["length"] * 0.6, 0], p0 + back * 0.55 + [0, -tl["length"], 0]]
                rad = [tl["r"] * 0.7, tl["r"], tl["r"] * 1.15, tl["r"] * 0.9, tl["r"] * 0.35]
            else:
                path = [p0, p0 + back * 0.25 + [0, -0.4, 0], p0 + back * 0.32 + [0, -1.2, 0], p0 + back * 0.32 + [0, -tl["length"], 0]]
                rad = [tl["r"] * 1.1, tl["r"], tl["r"] * 0.95, tl["r"] * 0.6]
            path = [h.push_out(np.array([p]), tl["r"] + 0.12)[0] if i else p for i, p in enumerate(path)]
            if tl["kind"] == "braid":
                braids.append(braid3(h, path, rad, head_until=y0 - 0.2))
            else:
                parts.append(tube(h, path, rad, 10, head_until=y0 - 0.2))
        elif tl["kind"] == "braids2":
            for sgn in (1, -1):
                p0 = head_point(h, sgn * 1.85, h.eye_y - 0.15, 0.05)
                sx = sgn * (h.half_w + 0.35)
                path = [p0, np.array([sgn * (h.half_w + 0.1), h.neck_y + 0.3, h.c[2] - 0.25]), np.array([sx * 0.9, h.shoulder_y + 0.45, h.c[2] + 0.1]),
                        np.array([sgn * 1.0, h.shoulder_y - 0.3, h.c[2] + 0.9]), np.array([sgn * 0.85, h.shoulder_y - tl["length"] * 0.55, h.c[2] + 1.1])]
                path = [p if i == 0 else h.push_out(np.array([p]), tl["r"] + 0.15)[0] for i, p in enumerate(path)]
                braids.append(braid3(h, path, [tl["r"] * 1.1, tl["r"], tl["r"], tl["r"] * 0.9, tl["r"] * 0.6], head_until=h.neck_y + 0.2, clear=0.12))
        elif tl["kind"] == "crown":
            ring = []
            for a in np.linspace(0, 2 * np.pi, 24, endpoint=False):
                y = h.eye_y + 0.78 + 0.25 * (1 - np.cos(a)) / 2
                ring.append(head_point(h, a - np.pi, y, s["cap"]["thick"] + tl["r"] * 0.85))
            ring.append(ring[0]); ring.append(ring[1])
            t2 = tube(h, ring, [tl["r"]] * len(ring), 9)
            t2.J[:] = 0; t2.J[:, 0] = M.BONE_INDEX["head"]; t2.W[:] = 0; t2.W[:, 0] = 1
            braids.append(t2)
    for b in s.get("buns", []):
        cen = head_point(h, b["th"], h.eye_y + b["y"], s["cap"]["thick"] + b["r"][2] * 0.7)
        parts.append(ellipsoid(h, cen, b["r"]))
    out = [("hair", merge(parts))]
    if locks: out.append(("hairlock", merge(locks)))
    if braids: out.append(("hair", merge(braids)))
    return out

def build_beard(h, bid, seed=3):
    b = BEARDS[bid]
    V, N = h.V, h.N
    Z = M.VERTEX_ZONE
    fids = np.array(M.faces_of("body")); pad = M.FACE_PAD[fids]
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    ax = np.abs(x)
    front = z > h.c[2] - 0.2
    nose_b = h.nose[1] - 0.18
    in_head = np.isin(Z, ["head", "neck"])
    must = np.zeros(len(V), bool)
    moust = in_head & front & (y < h.nose[1] - 0.02) & (y > h.mouth_y + 0.04) & (ax < h.mouth_w + 0.2) & (z > h.c[2] + 0.3)
    if b.get("only_moustache"):
        region = moust
    else:
        cheek = h.mouth_y + b.get("cheek", 0.5) * (0.55 + 0.6 * np.clip(ax / h.half_w, 0, 1))
        region = in_head & front & (y < np.minimum(cheek, nose_b + 0.25 * np.clip(ax / h.half_w, 0, 1))) & (y > h.chin_y - (0.7 if b.get("under") else 0.25))
        if b.get("goatee"):
            region &= ax < h.mouth_w + 0.12
        if not b.get("moustache"):
            region &= ~moust
        else:
            region |= moust
    region &= ~h.lips & ~h.ears
    keep = region[pad].all(1)
    fids = fids[keep]
    if len(fids) == 0:
        return None
    used = np.unique(M.FACE_PAD[fids].ravel())
    # kaugus piirkonna servast (servast sissepoole õheneb)
    edge_cnt = {}
    for fi in fids:
        f = M.BASE_F[fi]
        for k in range(len(f)):
            e = tuple(sorted((f[k], f[(k + 1) % len(f)]))); edge_cnt[e] = edge_cnt.get(e, 0) + 1
    border = {v for e, n in edge_cnt.items() if n == 1 for v in e}
    nb = {}
    for e in edge_cnt:
        nb.setdefault(e[0], []).append(e[1]); nb.setdefault(e[1], []).append(e[0])
    hop = {v: 0 for v in border}; frontier = list(border)
    while frontier:
        nxt = []
        for v in frontier:
            for w in nb.get(v, []):
                if w not in hop: hop[w] = hop[v] + 1; nxt.append(w)
        frontier = nxt
    fade = np.ones(len(V))
    for v, d in hop.items(): fade[v] = min(1.0, 0.15 + d / 3.0)
    t = 0.015 + np.full(len(V), b["thick"]) * fade
    t *= 0.6 + 0.4 * smoothstep(h.mouth_y + 0.6, h.mouth_y - 0.2, y)
    P = V + N * t[:, None]
    drop = b["drop"] * smoothstep(h.mouth_y - 0.1, h.chin_y - 0.1, y) * np.clip(1 - ax / (h.half_w * 0.9), 0, 1) ** 1.5
    P[:, 1] -= drop; P[:, 2] += drop * 0.35
    if bid == "beard_moustache":
        P[:, 1] -= 0.12 * smoothstep(0.1, h.mouth_w + 0.1, ax) * moust
    P = M.taubin(P, fids.tolist(), 4, 0.5, -0.53)
    P = M.drape(P, N, fids.tolist(), 30, 0.0, interior=False)   # sile habemeserv
    remap = -np.ones(len(V), int); remap[used] = np.arange(len(used))
    tris = []
    for fi in fids:
        f = M.BASE_F[fi]
        for k in range(1, len(f) - 1):
            tris.append((remap[f[0]], remap[f[k]], remap[f[k + 1]]))
    Pc = P[used]
    UV = np.stack([Pc[:, 0] * 1.6, -Pc[:, 1] * 1.6], 1)
    J, W = h.weights(Pc, head_until=h.neck_y - 0.5)
    C = 0.8 + 0.2 * np.clip((h.mouth_y + 0.6 - Pc[:, 1]) / 1.0, 0, 1)
    return Part(Pc, np.array(tris), UV, J, W, C)


# ---------------------------------------------------------------- mütsid, kübarad, kiivrid
def hat_params(front=0.5, side=0.32, back=0.5, thick=0.08, crown=0.0, flat=None, point=0.0, crest=0.0, brim=0.0, visor=0.0, tilt=0.0, updown=0.0, closed=False):
    return dict(front=front, side=side, back=back, thick=thick, crown=crown, flat=flat, point=point, crest=crest, brim=brim, visor=visor, tilt=tilt, updown=updown, closed=closed)

HATS = {
    "bronze_felt_cap":   hat_params(0.55, 0.35, 0.5, 0.07, crown=0.15),
    "iron_wool_cap":     hat_params(0.55, 0.3, 0.45, 0.08, crown=0.25, point=0.1),
    "ren_flat_cap":      hat_params(0.62, 0.45, 0.55, 0.06, crown=0.08, brim=0.28, tilt=-0.12),
    "ind_flat_cap":      hat_params(0.5, 0.4, 0.55, 0.06, crown=0.05, flat=0.2, visor=0.55, tilt=-0.15),
    "mod_cap":           hat_params(0.5, 0.35, 0.5, 0.06, crown=0.12, visor=0.7, tilt=-0.06),
    "ind_bowler":        hat_params(0.55, 0.4, 0.55, 0.07, crown=0.38, brim=0.32, tilt=0.12),
    "work_straw_hat":    hat_params(0.55, 0.4, 0.55, 0.07, crown=0.45, flat=0.35, brim=1.25, tilt=-0.08),
    "work_hard_hat":     hat_params(0.5, 0.35, 0.5, 0.18, crown=0.2, brim=0.2, visor=0.35, tilt=-0.05),
    "mil_combat_helmet": hat_params(0.5, 0.15, 0.45, 0.17, crown=0.1, brim=0.08, tilt=-0.2),
    "mil_bronze_helmet": hat_params(0.5, 0.2, 0.4, 0.12, point=0.25),
    "mil_spangenhelm":   hat_params(0.5, 0.25, 0.45, 0.12, point=0.55),
    "mil_kettle_hat":    hat_params(0.6, 0.35, 0.5, 0.12, crown=0.1, brim=0.9, tilt=-0.3),
    "mil_morion":        hat_params(0.55, 0.35, 0.5, 0.1, crest=0.55, brim=0.65, tilt=0.15, updown=0.35),
    "mil_felt_hat":      hat_params(0.55, 0.4, 0.55, 0.07, crown=0.6, flat=0.5, brim=1.25, tilt=0.12, updown=0.2),
    "mil_shako":         hat_params(0.55, 0.4, 0.55, 0.06, crown=1.5, flat=1.3, visor=0.5, tilt=-0.2),
    "mil_kepi":          hat_params(0.55, 0.4, 0.55, 0.06, crown=0.7, flat=0.55, visor=0.5, tilt=-0.15),
    "mil_great_helm":    hat_params(-1.6, -1.6, 0.25, 0.16, flat=0.25, closed=True),
    "bronze_hairnet":    hat_params(0.58, 0.42, 0.25, 0.12, crown=0.15),
}

def hat(h, p, seed=1):
    cp = dict(front=p["front"], side=p["side"], back=p["back"], thick=p["thick"], vol=0.0, ramp=0.04)
    V = h.V
    if p["closed"]:
        ears = h.ears.copy(); h.ears[:] = False
        part, Pc, bverts, t = cap(h, cp, seed)
        h.ears = ears
        part.P = h.c + (part.P - h.c) * np.array([1.06, 1.0, 1.04])
    else:
        part, Pc, bverts, t = cap(h, cp, seed)
    P = part.P
    band = P[bverts, 1].mean() if len(bverts) else P[:, 1].min()
    top = P[:, 1].max()
    up = smoothstep(band, top, P[:, 1])
    if p["crown"]: P[:, 1] += p["crown"] * up
    if p["flat"] is not None:
        lim = top + p["crown"] - p["flat"] * 0.3
        P[:, 1] = np.minimum(P[:, 1], lim)
    rxz = np.hypot(P[:, 0] - h.c[0], P[:, 2] - h.c[2])
    if p["point"]: P[:, 1] += p["point"] * smoothstep(top - 0.7, top, P[:, 1]) * np.clip(1 - rxz / 0.7, 0, 1)
    if p["crest"]: P[:, 1] += p["crest"] * np.exp(-(P[:, 0] / 0.12) ** 2) * smoothstep(top - 0.9, top, P[:, 1])
    parts = [part]
    if (p["brim"] or p["visor"]) and len(bverts) > 6:
        th = h.theta(P[bverts]); order = np.argsort(th)
        ring = P[bverts][order]; th = th[order]
        n = len(ring)
        width = p["brim"] + p["visor"] * smoothstep(1.3, 0.2, np.abs(th))
        tilt = p["tilt"] + p["updown"] * np.abs(np.cos(th))
        d = np.stack([np.sin(th), np.zeros(n), np.cos(th)], 1)
        mid = ring + d * width[:, None] * 0.5 + np.array([0, 1, 0]) * (tilt * width * 0.4)[:, None]
        out = ring + d * width[:, None] + np.array([0, 1, 0]) * (tilt * width)[:, None]
        B = np.concatenate([ring, mid, out])
        T = grid_mesh(B, 3, n, closed=True)
        UV = np.stack([np.tile(th * 0.5, 3), np.repeat([0, 0.5, 1.0], n) * (width.mean() + 0.1)], 1)
        J = np.zeros((len(B), 4), np.uint16); J[:, 0] = M.BONE_INDEX["head"]; W = np.zeros((len(B), 4), np.float32); W[:, 0] = 1
        parts.append(Part(B, T, UV, J, W, np.full(len(B), 0.95)))
    if p["closed"]:
        # silmapilu ja hingamisaugud: tume riba silmade kõrgusel ees
        slit = (np.abs(P[:, 1] - h.eye_y) < 0.09) & (P[:, 2] > h.c[2] + 0.4)
        part.C = np.where(slit, 0.08, part.C)
    part.C = np.minimum(part.C, 1.0)
    return merge(parts)
