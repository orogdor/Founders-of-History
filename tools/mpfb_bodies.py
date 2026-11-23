"""MPFB2/MakeHumani CC0 andmetest mängukehad ja proovirõivad (glb).

Kehad: base.obj + MakeHumani makro-sihtkujud (sugu, vanus, rass) + game_engine luustik ja kaalud.
Silmad: MakeHumani high-poly silmad (mhclo sobitus).
Proovirõivad: MakeHumani abivõrkudest (helper-tights, helper-skirt, helper-hair) ja kehapinnast.

Käivitus: python3 mpfb_bodies.py <mpfb_data> <makehuman_data> <projekt> [--clothes]
"""
import gzip, json, math, os, struct, sys, zlib
import numpy as np

MPFB, MHDATA, PROJECT = sys.argv[1], sys.argv[2], sys.argv[3]
MAKE_CLOTHES = "--clothes" in sys.argv
SCALE = 0.1  # MakeHumani detsimeetrid -> meetrid

# ---------------------------------------------------------------- base mesh
def load_obj(path):
    V, VT, F, FT, FG = [], [], [], [], []
    grp = None
    for line in open(path):
        if line.startswith("v "):
            V.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("vt "):
            VT.append([float(x) for x in line.split()[1:3]])
        elif line.startswith("g "):
            grp = line.split()[1]
        elif line.startswith("f "):
            parts = [p.split("/") for p in line.split()[1:]]
            F.append([int(p[0]) - 1 for p in parts])
            FT.append([int(p[1]) - 1 if len(p) > 1 and p[1] else -1 for p in parts])
            FG.append(grp)
    return np.array(V), np.array(VT) if VT else np.zeros((0, 2)), F, FT, FG

BASE_V, BASE_VT, BASE_F, BASE_FT, BASE_FG = load_obj(f"{MPFB}/3dobjs/base.obj")
GROUPS = json.load(open(f"{MPFB}/mesh_metadata/basemesh_vertex_groups.json"))

def group_vertices(name):
    out = []
    for a, b in GROUPS[name]:
        out.extend(range(a, b + 1))
    return np.array(out)

def load_target(rel):
    path = f"{MPFB}/targets/{rel}.target.gz"
    idx, d = [], []
    with gzip.open(path, "rt") as fh:
        for line in fh:
            if not line.strip() or line.startswith("#"):
                continue
            p = line.split()
            idx.append(int(p[0])); d.append([float(p[1]), float(p[2]), float(p[3])])
    return np.array(idx), np.array(d)

MACRO = json.load(open(f"{MPFB}/targets/macrodetails/macro.json"))["macrotargets"]

def components(name, value):
    out = []
    for part in MACRO[name]["parts"]:
        lo, hi = part["lowest"], part["highest"]
        if lo < value < hi:
            pos = (value - lo) / (hi - lo)
            if part["low"]:
                out.append([part["low"], round(1 - pos, 4)])
            if part["high"]:
                out.append([part["high"], round(pos, 4)])
    return out

def target_stack(info):
    """MPFB2 TargetService.calculate_target_stack_from_macro_info_dict (sugu, vanus, lihased, kaal, pikkus, rass)."""
    c = {k: components(k, info[k]) for k in ["gender", "age", "muscle", "weight", "height", "proportions"]}
    stack = []
    for race, rw in info["race"].items():
        if rw <= 0.0001:
            continue
        for a in c["age"]:
            for g in c["gender"]:
                w = rw * g[1] * a[1]
                if w > 0.01:
                    stack.append([f"macrodetails/{race}-{g[0]}-{a[0]}", w])
    for g in c["gender"]:
        for a in c["age"]:
            for m in c["muscle"]:
                for wt in c["weight"]:
                    w = g[1] * a[1] * m[1] * wt[1]
                    if w > 0.01:
                        stack.append([f"macrodetails/universal-{g[0]}-{a[0]}-{m[0]}-{wt[0]}", w])
                    for h in c["height"]:
                        hw = w * h[1]
                        if hw > 0.01:
                            stack.append([f"macrodetails/height/{g[0]}-{a[0]}-{m[0]}-{wt[0]}-{h[0]}", hw])
                    for p in c["proportions"]:
                        pw = w * p[1]
                        if pw > 0.01:
                            stack.append([f"macrodetails/proportions/{g[0]}-{a[0]}-{m[0]}-{wt[0]}-{p[0]}", pw])
    return stack

def shaped_vertices(info):
    V = BASE_V.copy()
    for rel, w in target_stack(info):
        if not os.path.exists(f"{MPFB}/targets/{rel}.target.gz"):
            print("  puudub sihtkuju", rel); continue
        idx, d = load_target(rel)
        if len(idx):
            V[idx.astype(int)] += d * w
    return V

# ---------------------------------------------------------------- rig + weights
RIG = json.load(open(f"{MPFB}/rigs/standard/rig.game_engine.json"))
WEIGHTS = json.load(open(f"{MPFB}/rigs/standard/weights.game_engine.json"))["weights"]

def rig_order():
    order, seen = [], set()
    def visit(n):
        if n in seen:
            return
        p = RIG[n]["parent"]
        if p:
            visit(p)
        seen.add(n); order.append(n)
    for n in RIG:
        visit(n)
    return order

BONES = rig_order()
BONE_INDEX = {n: i for i, n in enumerate(BONES)}

def joint_position(V, spec):
    if spec["strategy"] == "CUBE":
        return V[group_vertices(spec["cube_name"])].mean(0)
    if spec["strategy"] == "MEAN":
        return V[np.array(spec["vertex_indices"])].mean(0)
    if spec["strategy"] == "VERTEX":
        return V[spec["vertex_index"]]
    raise ValueError(spec["strategy"])

def quat_from_matrix(m):
    t = np.trace(m)
    if t > 0:
        s = math.sqrt(t + 1.0) * 2; w = 0.25 * s
        x = (m[2, 1] - m[1, 2]) / s; y = (m[0, 2] - m[2, 0]) / s; z = (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w = (m[2, 1] - m[1, 2]) / s; x = 0.25 * s; y = (m[0, 1] + m[1, 0]) / s; z = (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w = (m[0, 2] - m[2, 0]) / s; x = (m[0, 1] + m[1, 0]) / s; y = 0.25 * s; z = (m[1, 2] + m[2, 1]) / s
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w = (m[1, 0] - m[0, 1]) / s; x = (m[0, 2] + m[2, 0]) / s; y = (m[1, 2] + m[2, 1]) / s; z = 0.25 * s
    q = np.array([x, y, z, w]); return q / np.linalg.norm(q)

def bone_basis(head, tail):
    """Luu Y-telg piki luud (nagu Blenderis), Z-telg võimalikult ette (+Z)."""
    y = tail - head; n = np.linalg.norm(y)
    y = y / n if n > 1e-9 else np.array([0, 1.0, 0])
    ref = np.array([0, 0, 1.0]) if abs(y[2]) < 0.9 else np.array([0, 1.0, 0])
    x = np.cross(y, ref); x /= np.linalg.norm(x)
    z = np.cross(x, y)
    return np.stack([x, y, z], 1)

def build_rig(V):
    heads, globals_ = {}, {}
    for n in BONES:
        h = joint_position(V, RIG[n]["head"]) * SCALE
        t = joint_position(V, RIG[n]["tail"]) * SCALE
        m = np.eye(4); m[:3, :3] = bone_basis(h, t); m[:3, 3] = h
        globals_[n] = m; heads[n] = h
    return globals_

def weight_matrix():
    n = len(BASE_V)
    J = np.zeros((n, 4), np.uint16); W = np.zeros((n, 4), np.float32)
    per = [[] for _ in range(n)]
    for bone, lst in WEIGHTS.items():
        bi = BONE_INDEX[bone]
        for vi, w in lst:
            per[vi].append((w, bi))
    for vi, lst in enumerate(per):
        lst.sort(reverse=True); lst = lst[:4]
        s = sum(w for w, _ in lst) or 1.0
        for k, (w, bi) in enumerate(lst):
            J[vi, k] = bi; W[vi, k] = w / s
        if not lst:
            J[vi, 0] = BONE_INDEX["pelvis"]; W[vi, 0] = 1
    return J, W

JOINTS, WTS = weight_matrix()

ZONE_OF_BONE = {}
for b in BONES:
    if b in ("Root", "pelvis"): z = "hips"
    elif b.startswith("spine") or b.startswith("clavicle"): z = "torso"
    elif b.startswith("neck"): z = "neck"
    elif b == "head": z = "head"
    elif b.startswith("upperarm"): z = "upperarms"
    elif b.startswith("lowerarm"): z = "forearms"
    elif b.startswith(("hand", "thumb", "index", "middle", "ring", "pinky")): z = "hands"
    elif b.startswith("thigh"): z = "thighs"
    elif b.startswith("calf"): z = "shins"
    elif b.startswith(("foot", "ball")): z = "feet"
    else: z = "torso"
    ZONE_OF_BONE[BONE_INDEX[b]] = z
VERTEX_ZONE = np.array([ZONE_OF_BONE[int(JOINTS[i, 0])] for i in range(len(BASE_V))])

# ---------------------------------------------------------------- geometry helpers
_FACES = {}
def faces_of(group):
    if group not in _FACES:
        _FACES[group] = [i for i, g in enumerate(BASE_FG) if g == group]
    return _FACES[group]

FACE_PAD = np.array([f + [f[-1]] * (4 - len(f)) for f in BASE_F])

def vertex_normals(V, face_ids):
    N = np.zeros_like(V)
    for fi in face_ids:
        f = BASE_F[fi]
        for k in range(1, len(f) - 1):
            a, b, c = V[f[0]], V[f[k]], V[f[k + 1]]
            n = np.cross(b - a, c - a)
            N[f[0]] += n; N[f[k]] += n; N[f[k + 1]] += n
    l = np.linalg.norm(N, axis=1, keepdims=True); l[l == 0] = 1
    return N / l

def triangulate(face_ids):
    tris = []
    for fi in face_ids:
        f, ft = BASE_F[fi], BASE_FT[fi]
        for k in range(1, len(f) - 1):
            tris.append(((f[0], ft[0]), (f[k], ft[k]), (f[k + 1], ft[k + 1])))
    return tris

def mesh_from_tris(tris, P, N, J, W, uv, uv_scale=1.0, C=None):
    """Unikaalsed (tipp, uv) paarid -> glTF tipud."""
    key_index, pos, nor, joi, wei, tex, idx, col = {}, [], [], [], [], [], [], []
    for tri in tris:
        for vi, ti in tri:
            key = (vi, ti)
            if key not in key_index:
                key_index[key] = len(pos)
                pos.append(P[vi]); nor.append(N[vi]); joi.append(J[vi]); wei.append(W[vi])
                if C is not None: col.append(C[vi])
                tex.append(uv[ti] if ti >= 0 and len(uv) else (0.0, 0.0))
            idx.append(key_index[key])
    tex = np.array(tex, np.float32); tex[:, 1] = 1 - tex[:, 1]; tex *= uv_scale
    out = dict(pos=np.array(pos, np.float32), nor=np.array(nor, np.float32), joi=np.array(joi, np.uint16),
               wei=np.array(wei, np.float32), uv=tex, idx=np.array(idx, np.uint32))
    if C is not None: out["col"] = np.array(col, np.float32)
    return out

# ---------------------------------------------------------------- mhclo proxies (silmad)
def fit_mhclo(path, V):
    lines = open(path).read().splitlines()
    scales, refs, obj = {}, [], None
    in_verts = False
    for line in lines:
        p = line.split()
        if not p or p[0].startswith("#"):
            continue
        if p[0] in ("x_scale", "y_scale", "z_scale"):
            scales[p[0][0]] = (int(p[1]), int(p[2]), float(p[3]))
        elif p[0] == "obj_file":
            obj = p[1]
        elif p[0] == "verts":
            in_verts = True; continue
        elif in_verts:
            if len(p) == 9:
                refs.append(([int(x) for x in p[:3]], [float(x) for x in p[3:6]], [float(x) for x in p[6:9]]))
            elif len(p) == 1 and p[0].lstrip("-").isdigit():
                refs.append(([int(p[0])], [1.0], [0, 0, 0]))
            else:
                in_verts = False
    s = np.ones(3)
    for axis, k in (("x", 0), ("y", 1), ("z", 2)):
        if axis in scales:
            a, b, d = scales[axis]
            s[k] = abs(V[a][k] - V[b][k]) / d
    P, J, W = [], [], []
    for vi, w, off in refs:
        P.append(sum(V[i] * wi for i, wi in zip(vi, w)) + np.array(off) * s)
        acc = {}
        for i, wi in zip(vi, w):
            for k in range(4):
                if WTS[i, k] > 0:
                    acc[int(JOINTS[i, k])] = acc.get(int(JOINTS[i, k]), 0) + WTS[i, k] * wi
        top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(v for _, v in top) or 1
        J.append([b for b, _ in top] + [0] * (4 - len(top))); W.append([v / tot for _, v in top] + [0] * (4 - len(top)))
    pV, pVT, pF, pFT, _ = load_obj(os.path.join(os.path.dirname(path), obj))
    return np.array(P), np.array(J, np.uint16), np.array(W, np.float32), pVT, pF, pFT

def proxy_mesh(P, J, W, VT, F, FT):
    N = np.zeros_like(P)
    for f in F:
        for k in range(1, len(f) - 1):
            n = np.cross(P[f[k]] - P[f[0]], P[f[k + 1]] - P[f[0]])
            for i in (f[0], f[k], f[k + 1]): N[i] += n
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    tris = []
    for f, ft in zip(F, FT):
        for k in range(1, len(f) - 1):
            tris.append(((f[0], ft[0]), (f[k], ft[k]), (f[k + 1], ft[k + 1])))
    return mesh_from_tris(tris, P * SCALE, N, J, W, VT)

# ---------------------------------------------------------------- glTF writer
class Glb:
    def __init__(self):
        self.bin = bytearray(); self.views = []; self.accessors = []
        self.meshes = []; self.materials = []; self.images = []; self.textures = []; self.samplers = [{}]
    def _view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin += b"\0"
        off = len(self.bin); self.bin += data
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target: v["target"] = target
        self.views.append(v); return len(self.views) - 1
    def accessor(self, arr, kind, ctype, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        view = self._view(arr.tobytes(), target)
        a = {"bufferView": view, "componentType": ctype, "count": int(arr.shape[0]), "type": kind}
        if minmax:
            a["min"] = arr.min(0).tolist(); a["max"] = arr.max(0).tolist()
        self.accessors.append(a); return len(self.accessors) - 1
    def image_uri(self, uri):
        self.images.append({"uri": uri})
        self.textures.append({"sampler": 0, "source": len(self.images) - 1})
        return len(self.textures) - 1
    def image(self, png_bytes):
        view = self._view(png_bytes)
        self.images.append({"bufferView": view, "mimeType": "image/png"})
        self.textures.append({"sampler": 0, "source": len(self.images) - 1})
        return len(self.textures) - 1
    def material(self, name, color, rough=0.8, metal=0.0, texture=None, double=False, alpha=None, normal=None, orm=None, normal_scale=1.0):
        lin = [float(c) ** 2.2 for c in color[:3]]
        m = {"name": name, "pbrMetallicRoughness": {"baseColorFactor": lin + [1.0],
             "roughnessFactor": rough, "metallicFactor": metal}}
        if texture is not None: m["pbrMetallicRoughness"]["baseColorTexture"] = {"index": texture}
        if orm is not None: m["pbrMetallicRoughness"]["metallicRoughnessTexture"] = {"index": orm}
        if normal is not None: m["normalTexture"] = {"index": normal, "scale": normal_scale}
        if double: m["doubleSided"] = True
        if alpha: m["alphaMode"] = "MASK"; m["alphaCutoff"] = alpha
        self.materials.append(m); return len(self.materials) - 1
    def mesh(self, name, md, material):
        attrs = {"POSITION": self.accessor(md["pos"], "VEC3", 5126, 34962, True),
                 "NORMAL": self.accessor(md["nor"], "VEC3", 5126, 34962),
                 "TEXCOORD_0": self.accessor(md["uv"], "VEC2", 5126, 34962),
                 "JOINTS_0": self.accessor(md["joi"], "VEC4", 5123, 34962),
                 "WEIGHTS_0": self.accessor(md["wei"], "VEC4", 5126, 34962)}
        if "col" in md:
            attrs["COLOR_0"] = self.accessor(md["col"], "VEC4", 5126, 34962)
        ind = self.accessor(md["idx"], "SCALAR", 5125, 34963)
        self.meshes.append({"name": name, "primitives": [{"attributes": attrs, "indices": ind, "material": material}]})
        return len(self.meshes) - 1
    def write(self, path, globals_, mesh_names, extras=None):
        nodes = []
        for n in BONES:
            g = globals_[n]; p = RIG[n]["parent"]
            local = np.linalg.inv(globals_[p]) @ g if p else g
            nodes.append({"name": n, "translation": local[:3, 3].tolist(), "rotation": quat_from_matrix(local[:3, :3]).tolist(),
                          "children": [BONE_INDEX[c] for c in BONES if RIG[c]["parent"] == n] or None})
        for nd in nodes:
            if nd["children"] is None: del nd["children"]
        ibm = np.stack([np.linalg.inv(globals_[n]).T.reshape(16) for n in BONES]).astype(np.float32)
        skin = {"joints": list(range(len(BONES))), "inverseBindMatrices": self.accessor(ibm, "MAT4", 5126), "skeleton": 0}
        mesh_nodes = []
        for i, nm in enumerate(mesh_names):
            nodes.append({"name": nm, "mesh": i, "skin": 0}); mesh_nodes.append(len(nodes) - 1)
        gl = {"asset": {"version": "2.0", "generator": "founders-of-history mpfb_bodies.py",
                        "extras": extras or {}},
              "scene": 0, "scenes": [{"nodes": [0] + mesh_nodes}], "nodes": nodes, "skins": [skin],
              "meshes": self.meshes, "materials": self.materials, "accessors": self.accessors,
              "bufferViews": self.views, "buffers": [{"byteLength": len(self.bin)}]}
        if self.images:
            gl["images"] = self.images; gl["textures"] = self.textures; gl["samplers"] = self.samplers
        js = json.dumps(gl, separators=(",", ":")).encode()
        js += b" " * ((4 - len(js) % 4) % 4)
        while len(self.bin) % 4: self.bin += b"\0"
        out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(self.bin))
        out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(self.bin), 0x004E4942) + bytes(self.bin)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "wb").write(out)

# ---------------------------------------------------------------- textures (protseduursed, tehtud siin)
from PIL import Image, ImageFilter
import io

def png(img):
    b = io.BytesIO(); img.save(b, "PNG"); return b.getvalue()

def noise_texture(kind, size=256, seed=1):
    rng = np.random.default_rng(seed)
    if kind == "cloth":
        x = np.arange(size)
        warp = (np.sin(x * 2 * np.pi / 4)[None, :] * 0.5 + 0.5)
        weft = (np.sin(x * 2 * np.pi / 4)[:, None] * 0.5 + 0.5)
        base = 0.86 + 0.07 * (warp * weft) + 0.05 * rng.random((size, size))
        slub = np.array(Image.fromarray((rng.random((size // 8, size)) * 255).astype(np.uint8)).resize((size, size))) / 255.0
        base = base - 0.05 * slub
    elif kind == "leather":
        n = np.array(Image.fromarray((rng.random((size // 4, size // 4)) * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)) / 255.0
        base = 0.82 + 0.14 * n + 0.03 * rng.random((size, size))
    elif kind == "fur":
        n = rng.random((size, size)); img = Image.fromarray((n * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(1))
        streak = np.array(img.resize((size, size // 6)).resize((size, size))) / 255.0
        base = 0.62 + 0.38 * streak
    elif kind == "hair":
        n = rng.random((size, 8)); streak = np.array(Image.fromarray((n * 255).astype(np.uint8)).resize((size, size), Image.BILINEAR)) / 255.0
        base = 0.62 + 0.38 * streak
    elif kind == "skin":
        n = np.array(Image.fromarray((rng.random((size // 2, size // 2)) * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)) / 255.0
        base = 0.95 + 0.05 * n
    else:
        base = np.ones((size, size))
    g = (np.clip(base, 0, 1) * 255).astype(np.uint8)
    return png(Image.fromarray(np.stack([g, g, g], -1)))

# ---------------------------------------------------------------- tekstuurid
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import textures as TX
TEXDIR = f"{PROJECT}/assets/people/textures"
FABRIC_SIZE = 1024
FABRICS = ("linen", "straw", "wool", "denim", "jersey", "leather", "hide", "oilcloth", "fur", "hair", "braid", "metal",
           "herringbone", "plaid", "stripe", "brocade", "knit", "twill", "felt", "quilted", "mail", "plate", "camo", "hairlock")

def write_fabrics():
    os.makedirs(TEXDIR, exist_ok=True)
    for i, kind in enumerate(FABRICS):
        a, n, r = TX.fabric(kind, FABRIC_SIZE, 3 + i)
        a.save(f"{TEXDIR}/{kind}_albedo.png"); n.save(f"{TEXDIR}/{kind}_normal.png"); r.save(f"{TEXDIR}/{kind}_orm.png")
    import shutil
    shutil.copy(f"{MHDATA}/eyes/materials/brown_eye.png", f"{TEXDIR}/eye_brown.png")

def uv_meters(V, group):
    """Mitu meetrit pinda vastab ühele UV-ühikule selles rühmas."""
    L3 = L2 = 0.0
    for fi in faces_of(group):
        f, ft = BASE_F[fi], BASE_FT[fi]
        for k in range(len(f)):
            a, b = f[k], f[(k + 1) % len(f)]; ta, tb = ft[k], ft[(k + 1) % len(ft)]
            L3 += np.linalg.norm(V[a] - V[b]) * SCALE; L2 += np.linalg.norm(BASE_VT[ta] - BASE_VT[tb])
    return L3 / max(L2, 1e-9)

TILE_M = {"linen": 0.22, "straw": 0.3, "wool": 0.28, "denim": 0.22, "jersey": 0.16, "leather": 0.35, "hide": 0.45,
          "oilcloth": 0.35, "fur": 0.3, "hair": 0.18, "braid": 0.25, "metal": 0.08, "herringbone": 0.3, "plaid": 0.35, "stripe": 0.45,
          "brocade": 0.16, "knit": 0.2, "twill": 0.22, "felt": 0.3, "quilted": 0.6, "mail": 0.55, "plate": 0.5, "camo": 0.9}

def raster_vertex(size, tris_uv, tri_vals, img=None):
    """Kolmnurgad UV-s, väärtused tippudes; interpoleerib (max olemasolevaga)."""
    out = np.zeros((size, size)) if img is None else img
    for pts, vals in zip(tris_uv, tri_vals):
        if max(vals) <= 0.01:
            continue
        P = np.array(pts) * size
        x0, y0 = np.floor(P.min(0)).astype(int); x1, y1 = np.ceil(P.max(0)).astype(int)
        x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, size - 1); y1 = min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1] + 0.5
        (ax, ay), (bx, by), (cx, cy) = P
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            continue
        w1 = ((by - cy) * (xx - cx) + (cx - bx) * (yy - cy)) / den
        w2 = ((cy - ay) * (xx - cx) + (ax - cx) * (yy - cy)) / den
        w3 = 1 - w1 - w2
        inside = (w1 >= -0.02) & (w2 >= -0.02) & (w3 >= -0.02)
        val = w1 * vals[0] + w2 * vals[1] + w3 * vals[2]
        sub = out[y0:y1 + 1, x0:x1 + 1]
        sub[inside] = np.maximum(sub[inside], val[inside])
    return out

def skin_fields(V, name):
    """Tipupõhised väljad: punetus, kulmud, habe, peanahk (0..1)."""
    eyes = [V[group_vertices(g)] for g in ("helper-l-eye", "helper-r-eye")]
    head_v = np.where(VERTEX_ZONE == "head")[0]
    nose = V[head_v[np.argmax(V[head_v, 2])]]
    jaw = V[group_vertices("joint-jaw")].mean(0); headc = V[group_vertices("joint-head")].mean(0)
    n = len(V); red = np.zeros(n); brow = np.zeros(n); beard = np.zeros(n); scalp = np.zeros(n)
    g = lambda c, s: np.exp(-np.sum((V - c) ** 2, 1) / (2 * s * s))
    for e in eyes:
        c = e.mean(0); top = e[:, 1].max(); half = (e[:, 0].max() - e[:, 0].min())
        red += 0.8 * g(c + np.array([0.12 * np.sign(c[0]), -0.42, -0.05]), 0.2)
        # kulmukaar silma kohal: kõrgeim keskel, langeb välisnurga poole
        dx = (V[:, 0] - c[0]) / (half * 1.15)
        arc_y = top + 0.13 - 0.06 * dx ** 2 + 0.02 * dx * np.sign(c[0])
        thick = 0.06 * (1 - 0.4 * np.clip(dx * np.sign(c[0]), 0, 1))
        b = np.exp(-((V[:, 1] - arc_y) / thick) ** 2) * np.clip(1.2 - np.abs(dx), 0, 1) * (V[:, 2] > c[2] - 0.35)
        brow = np.maximum(brow, b)
    red += 0.7 * g(nose, 0.12)
    for j in ("joint-l-knee", "joint-r-knee", "joint-l-elbow", "joint-r-elbow"):
        red += 0.35 * g(V[group_vertices(j)].mean(0), 0.45)
    red += 0.3 * np.isin(VERTEX_ZONE, ["hands", "feet"])
    eye_y = np.mean([e[:, 1].mean() for e in eyes])
    in_head = np.isin(VERTEX_ZONE, ["head", "neck"])
    front = V[:, 2] > headc[2] - 0.15
    lower = (V[:, 1] < nose[1] - 0.12) & (V[:, 1] > jaw[1] - 0.75)
    beard = in_head * front * lower * np.clip((nose[1] - 0.12 - V[:, 1]) / 0.25, 0, 1)
    beard = beard * np.clip(1 - np.abs(V[:, 0]) / 0.9, 0, 1) ** 0.5
    scalp = (VERTEX_ZONE == "head") * np.clip((V[:, 1] - (eye_y + 0.45)) / 0.3, 0, 1)
    return {"red": np.clip(red, 0, 1), "brow": np.clip(brow, 0, 1), "beard": np.clip(beard, 0, 1), "scalp": scalp}

def bake_skin(V, name, tone):
    S = 2048
    tris_uv, tri_ids = [], []
    for fi in faces_of("body"):
        f, ft = BASE_F[fi], BASE_FT[fi]
        for k in range(1, len(f) - 1):
            ids = (0, k, k + 1)
            tris_uv.append([(BASE_VT[ft[i]][0], 1 - BASE_VT[ft[i]][1]) for i in ids]); tri_ids.append([f[i] for i in ids])
    fields = skin_fields(V, name)
    faces_uv = tris_uv
    from PIL import ImageFilter, Image as _I
    def field(nm, blur):
        a = raster_vertex(S, tris_uv, [[fields[nm][i] for i in t] for t in tri_ids])
        return np.array(_I.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur)), float) / 255
    masks = {k: f"{MPFB}/textures/mpfb_{k}.jpg" for k in ("lips", "eyelids", "ears", "fingernails", "toenails")}
    pre = {"red": field("red", 6), "brow": field("brow", 1.2), "beard": field("beard", 4), "scalp": field("scalp", 6)}
    albedo, normal, rough = TX.skin_baked(S, faces_uv, pre, masks, tone, seed=zlib.crc32(name.encode()) % 97, beard=(name == "man"))
    os.makedirs(TEXDIR, exist_ok=True)
    albedo.save(f"{TEXDIR}/skin_{name}_albedo.png"); normal.save(f"{TEXDIR}/skin_{name}_normal.png"); rough.save(f"{TEXDIR}/skin_{name}_orm.png")

# ---------------------------------------------------------------- bodies
BODIES = {
    "man":   dict(gender=1.0, age=0.5, muscle=0.55, weight=0.5, height=0.55, proportions=0.6),
    "woman": dict(gender=0.0, age=0.5, muscle=0.5, weight=0.5, height=0.5, proportions=0.6),
    "boy":   dict(gender=1.0, age=0.17, muscle=0.5, weight=0.5, height=0.5, proportions=0.5),
    "girl":  dict(gender=0.0, age=0.17, muscle=0.5, weight=0.5, height=0.5, proportions=0.5),
}
SKIN = (0.84, 0.64, 0.52)
SKIN_TONES = {"man": (0.80, 0.60, 0.49), "woman": (0.86, 0.67, 0.56), "boy": (0.86, 0.67, 0.56), "girl": (0.88, 0.70, 0.59)}

def body_info(name):
    info = dict(BODIES[name]); info["race"] = {"caucasian": 0.9, "asian": 0.05, "african": 0.05}
    return info

def build_body(name):
    V = shaped_vertices(body_info(name))
    V[:, 1] -= V[group_vertices("joint-ground")].mean(0)[1]  # jalad maapinnale
    globals_ = build_rig(V)
    body_faces = faces_of("body")
    N = vertex_normals(V, body_faces)
    bake_skin(V, name, SKIN_TONES[name])
    g = Glb()
    skin_mat = g.material("skin", (1, 1, 1), 1.0, 0.0, g.image_uri(f"../textures/skin_{name}_albedo.png"),
                          normal=g.image_uri(f"../textures/skin_{name}_normal.png"), orm=g.image_uri(f"../textures/skin_{name}_orm.png"), normal_scale=0.6)
    names = []
    # kehatsoonid: tahk kuulub tsooni, kuhu kuulub enamik selle tippe
    by_zone = {}
    for fi in body_faces:
        zs = [VERTEX_ZONE[v] for v in BASE_F[fi]]
        z = max(set(zs), key=zs.count); by_zone.setdefault(z, []).append(fi)
    for z, fids in sorted(by_zone.items()):
        md = mesh_from_tris(triangulate(fids), V * SCALE, N, JOINTS, WTS, BASE_VT)
        g.mesh("body_" + z, md, skin_mat); names.append("body_" + z)
    # silmad
    eye_tex = g.image_uri("../textures/eye_brown.png")
    eye_mat = g.material("eyes", (1, 1, 1), 0.15, 0.0, eye_tex, alpha=0.5)
    P, J, W, VT, F, FT = fit_mhclo(f"{MHDATA}/eyes/high-poly/high-poly.mhclo", V)
    g.mesh("eyes", proxy_mesh(P, J, W, VT, F, FT), eye_mat); names.append("eyes")
    # kulmud on nahatekstuuris
    g.write(f"{PROJECT}/assets/people/bodies/{name}.glb", globals_, names,
            {"source": "MPFB2 base.obj, macrodetails targets, game_engine rig/weights; MakeHuman high-poly eyes (CC0)", "body": name})
    return V, N, globals_

def brow_faces(V):
    l, r = V[group_vertices("helper-l-eye")], V[group_vertices("helper-r-eye")]
    out = []
    for eye in (l, r):
        c = eye.mean(0); half = (eye[:, 0].max() - eye[:, 0].min()) * 0.75
        top = eye[:, 1].max()
        front = eye[:, 2].max()
        for fi in faces_of("body"):
            p = V[BASE_F[fi]].mean(0)
            if abs(p[0] - c[0]) < half * 0.85 and top + 0.07 < p[1] < top + 0.16 and p[2] > front - 0.25:
                out.append(fi)
    return out

# ---------------------------------------------------------------- proovirõivad
OUTFITS = json.load(open(f"{PROJECT}/data/human_outfits.json"))
ITEMS = OUTFITS["items"]
SKIRTY = ("skirt", "dress", "kirtle", "gown", "shift", "chemise", "cote", "wrap", "oilskin", "tunic", "kilt", "robe", "peplos", "coat", "surcoat", "hauberk", "gambeson")
CLOAKY = ("cloak", "cape", "mantle")
LEATHERY = ("hide", "leather", "moccasin", "pastlad", "shoes", "turnshoes", "boots", "sneakers", "loincloth")
FURRY = ("fur",)
METAL = ("disc", "ring", "ornament", "spiral", "amber", "necklace")
HAIRY = ("hair_",)

def joint_y(V, cube):
    return V[group_vertices(cube)].mean(0)[1]

def select_faces(group, V, zones=None, ymin=-1e9, ymax=1e9, front=None, back=None, any_vertex=True):
    fids = np.array(faces_of(group))
    pad = FACE_PAD[fids]
    keep = np.ones(len(fids), bool)
    if zones is not None:
        ok = np.isin(VERTEX_ZONE[pad], list(zones))
        keep &= ok.any(1) if any_vertex else ok.all(1)
    ys = V[pad, 1]
    keep &= (ys.max(1) >= ymin) & (ys.min(1) <= ymax)
    z = V[pad, 2].mean(1)
    if front is not None: keep &= z >= front
    if back is not None: keep &= z <= back
    return fids[keep].tolist()

def garment_parts(item_id, item, V, N_body, N_tights, N_skirt, N_hair):
    """Tagastab [(tahud, normaalid, nihe meetrites, rühm)] ühe eseme jaoks."""
    slot, hides = item["slot"], set(item["hides"])
    knee = joint_y(V, "joint-l-knee"); ankle = joint_y(V, "joint-l-ankle"); pelvis = joint_y(V, "joint-pelvis")
    neck = joint_y(V, "joint-neck"); head = joint_y(V, "joint-head"); head2 = joint_y(V, "joint-head-2")
    chest = joint_y(V, "joint-spine-1")
    skirt_mid_z = V[group_vertices("helper-skirt"), 2].mean()
    layer = {"underwear": 0.001, "socks": 0.0015, "shirt": 0.0055, "legs": 0.003, "torso": 0.008, "armor": 0.012, "armarm": 0.012,
             "cuirass": 0.02, "feet": 0.006, "apron": 0.03, "belt": 0.042, "outer": 0.016, "head": 0.01, "jewelry": 0.006}.get(slot, 0.005)
    parts = []
    skirty = any(k in item_id for k in SKIRTY)
    if slot in ("hair", "beard"):
        return parts
    if slot == "head":
        if item_id in HAIR.HATS:
            return [("gen", HAIR.hat(HEADS[CURRENT_BODY], HAIR.HATS[item_id]))]
        if item.get("hides_hair"):
            face_front = V[group_vertices("helper-l-eye"), 2].max() - 0.35
            fs = [fi for fi in select_faces("body", V, zones={"head", "neck"}, ymin=neck - 0.2)
                  if not (V[BASE_F[fi], 2].mean() > face_front and V[BASE_F[fi], 1].mean() < head2 - 0.55)]
            parts.append((fs, N_body, 0.014 if "hood" in item_id else 0.008, "body"))
        elif "headband" in item_id or "hairnet" in item_id:
            parts.append((select_faces("body", V, zones={"head"}, ymin=head2 - 0.75, ymax=head2 - 0.45), N_body, 0.006, "body"))
            if "hairnet" in item_id:
                parts.append((select_faces("helper-hair", V, ymin=head2 - 1.0), N_hair, 0.003, "helper-hair"))
        else:
            parts.append((select_faces("body", V, zones={"head"}, ymin=head2 - 0.6), N_body, 0.016 if "straw" in item_id or "hard" in item_id else 0.01, "body"))
        return parts
    if slot == "jewelry" and "armband" in item_id:
        fs = [fi for fi in select_faces("helper-tights", V, zones={"upperarms"}, ymin=chest - 0.9, ymax=chest - 0.35) if V[BASE_F[fi], 0].mean() > 0]
        parts.append((fs, N_tights, 0.022, "helper-tights"))
        return parts
    if slot == "jewelry":
        parts.append((select_faces("body", V, zones={"neck", "torso"}, ymin=neck - 0.45, ymax=neck - 0.15), N_body, 0.006, "body"))
        return parts
    if slot == "belt":
        if "crossbelts" in item_id:
            # kaks diagonaalrihma õlalt vastasküljele (üle mundri)
            sh = joint_y(V, "joint-l-shoulder"); xs = abs(V[group_vertices("joint-l-shoulder"), 0].mean())
            fs = select_faces("helper-tights", V, zones={"torso"}, ymin=pelvis + 0.2)
            c = V[FACE_PAD[fs]].mean(1)
            k = (sh - (pelvis + 0.4)) / (2 * xs * 0.85)
            ym = (sh + pelvis + 0.4) / 2
            keep = [f for f, (x, y, z) in zip(fs, c) if min(abs((y - ym) - k * x), abs((y - ym) + k * x)) < 0.22 * np.sqrt(1 + k * k)]
            parts.append((keep, N_tights, 0.03, "helper-tights"))
            return parts
        if "disc" in item_id:
            parts.append((select_faces("helper-tights", V, ymin=pelvis + 0.5, ymax=pelvis + 0.62), N_tights, layer, "helper-tights"))
            Pd = DRAPED["helper-tights"][0] if "helper-tights" in DRAPED else V
            ids = group_vertices("helper-tights"); Q = Pd[ids]
            band = Q[(np.abs(Q[:, 1] - (pelvis + 0.56)) < 0.12) & (np.abs(Q[:, 0]) < 0.25)]
            cen = np.array([0.0, pelvis + 0.56, band[:, 2].max() + layer * 10 + 0.04])
            parts.append(("gen", HAIR.disc(HEADS[CURRENT_BODY], cen, 0.42, 0.07)))
            return parts
        k = pelvis / 9.7   # lastel kitsam vöö
        parts.append((select_faces("helper-tights", V, ymin=pelvis + 0.4 * k, ymax=pelvis + 0.72 * k), N_tights, layer, "helper-tights"))
        return parts
    if slot == "apron":
        parts.append((select_faces("helper-skirt", V, ymin=knee + 0.2, front=skirt_mid_z), N_skirt, layer, "helper-skirt"))
        return parts
    if slot == "feet":
        top = ankle + (2.6 if "boots" in item_id else 0.6)
        parts.append((select_faces("helper-tights", V, zones={"feet", "shins"}, ymax=top), N_tights, layer, "helper-tights"))
        return parts
    upper = hides & {"torso", "upperarms", "forearms", "neck"}
    lower = hides & {"hips", "thighs", "shins"}
    if slot == "outer" and any(k in item_id for k in ("soba", "shawl", "fur_cape")):
        parts.append((select_faces("helper-tights", V, zones={"torso", "upperarms"}, ymin=chest - 1.2), N_tights, layer, "helper-tights"))
        return parts
    skirt_top = V[group_vertices("helper-skirt"), 1].max()
    if upper:
        ymin = skirt_top - 0.5 if skirty and lower else pelvis - 0.1
        fs = select_faces("helper-tights", V, zones=upper, ymin=ymin)
        parts.append((fs, N_tights, layer + (0.004 if skirty and lower else 0), "helper-tights"))
    if skirty and lower:
        hem = ankle + 0.4 if "shins" in hides else knee - 0.4 if "thighs" in hides else knee + 1.2
        parts.append((select_faces("helper-skirt", V, ymin=hem), N_skirt, layer + 0.018, "helper-skirt"))
    elif lower:
        parts.append((select_faces("helper-tights", V, zones=lower | ({"hips"} if "thighs" in lower else set()), ymax=pelvis + 0.5 if upper == set() else 1e9),
                      N_tights, layer, "helper-tights"))
    if slot == "outer" and any(k in item_id for k in CLOAKY) and "fur_cape" not in item_id:
        parts.append((select_faces("helper-skirt", V, ymin=knee, back=skirt_mid_z), N_skirt, 0.034, "helper-skirt"))
    return parts

def material_kind(item_id):
    if "mat" in ITEMS.get(item_id, {}): return ITEMS[item_id]["mat"]
    if any(k in item_id for k in HAIRY): return "hair"
    if any(k in item_id for k in FURRY): return "fur"
    if "amber" in item_id: return "metal"
    if any(k in item_id for k in METAL): return "metal"
    if "hide" in item_id or "loincloth" in item_id: return "hide"
    if "oilskin" in item_id: return "oilcloth"
    if any(k in item_id for k in LEATHERY) or "work_leather" in item_id or "belt" in item_id: return "leather"
    if "straw" in item_id: return "straw"
    if any(k in item_id for k in ("jeans", "overall", "work_jacket")): return "denim"
    if any(k in item_id for k in ("tshirt", "hi_vis", "sneakers", "hard_hat", "mod_blouse")): return "jersey"
    if any(k in item_id for k in ("linen", "shirt", "chemise", "shift", "smock", "apron", "headcloth", "coif", "blouse", "cord", "hairnet")): return "linen"
    return "wool"

from scipy import sparse

def taubin(P, fids, iterations=24, lam=0.5, mu=-0.53):
    used = np.unique(FACE_PAD[fids].ravel())
    if len(used) < 4:
        return P
    remap = -np.ones(len(P), int); remap[used] = np.arange(len(used))
    rows, cols = [], []
    for fi in fids:
        f = BASE_F[fi]
        for k in range(len(f)):
            a, b = remap[f[k]], remap[f[(k + 1) % len(f)]]
            rows += [a, b]; cols += [b, a]
    A = sparse.coo_matrix((np.ones(len(rows)), (rows, cols)), shape=(len(used), len(used))).tocsr()
    A.data[:] = 1.0
    deg = np.asarray(A.sum(1)).ravel(); deg[deg == 0] = 1
    M = sparse.diags(1 / deg) @ A
    Q = P[used].copy()
    for _ in range(iterations):
        Q = Q + lam * (M @ Q - Q)
        Q = Q + mu * (M @ Q - Q)
    out = P.copy(); out[used] = Q
    return out

def drape(P0, N, fids, iterations=48, cap=0.22, lam=0.5, interior=True, normal_only=False):
    """Riide langemine: Laplace'i silumine, mis ei lase riidel kehale läheneda (nõgusad kohad täituvad
    kuni `cap` dm, kumerad jäävad alles). Servaahelaid silutakse ainult piki serva, nii kaovad sakid."""
    used = np.unique(FACE_PAD[fids].ravel())
    if len(used) < 4:
        return P0
    remap = -np.ones(len(P0), int); remap[used] = np.arange(len(used))
    count = {}
    for fi in fids:
        f = BASE_F[fi]
        for k in range(len(f)):
            a, b = remap[f[k]], remap[f[(k + 1) % len(f)]]
            if a == b: continue
            e = (a, b) if a < b else (b, a); count[e] = count.get(e, 0) + 1
    edges = np.array(list(count.keys())); border = np.array([count[tuple(e)] == 1 for e in edges])
    n = len(used)
    on_border = np.zeros(n, bool); on_border[edges[border].ravel()] = True
    def rownorm(E):
        r = np.r_[E[:, 0], E[:, 1]]; c = np.r_[E[:, 1], E[:, 0]]
        A = sparse.coo_matrix((np.ones(len(r)), (r, c)), shape=(n, n)).tocsr(); A.data[:] = 1.0
        d = np.asarray(A.sum(1)).ravel(); d[d == 0] = 1
        return sparse.diags(1 / d) @ A
    Mi = rownorm(edges); Mb = rownorm(edges[border])
    sel = sparse.diags(on_border.astype(float))
    M = sel @ Mb + sparse.diags((~on_border).astype(float)) @ (Mi if interior else sparse.identity(n, format="csr"))
    base = P0[used]; Nu = N[used]; Q = base.copy()
    for _ in range(iterations):
        step = lam * (M @ Q - Q)
        if normal_only:   # ainult piki normaali: riie ei libise (varrukad ei lühene)
            step = np.sum(step * Nu, 1)[:, None] * Nu
        Q = Q + step
        d = np.sum((Q - base) * Nu, 1)
        Q = Q + (np.clip(d, 0.0, cap) - d)[:, None] * Nu
    out = P0.copy(); out[used] = Q
    return out

TEX_CACHE = {}
OLD_ERAS = ("stone_", "bronze_", "iron_", "med_")

def garment_shade(V, P, item_id, fids):
    """Tipuvärv (lineaarne halltoon): voldilaadne müra, kaenla-/jalgevahe varjud, vanadel ajastutel äärte mustus."""
    used = np.unique(FACE_PAD[fids].ravel())
    c = np.ones(len(P))
    rng = np.random.default_rng(zlib.crc32(item_id.encode()) % 9973)
    # voldid: mõned siinuslained piki keha, eri suundades
    for _ in range(3):   # pikad püstised voldid (heledatel kangastel ei tohi laike jääda)
        d = rng.normal(size=3); d[1] *= 0.12; d /= np.linalg.norm(d)
        c -= 0.022 * (0.5 + 0.5 * np.sin(P @ d * rng.uniform(7, 12) + rng.uniform(0, 6.3)))
    def near(cube, s):
        q = V[group_vertices(cube)].mean(0)
        return np.exp(-np.sum((P - q) ** 2, 1) / (2 * s * s))
    for cube in ("joint-l-shoulder", "joint-r-shoulder"):
        q = V[group_vertices(cube)].mean(0) + np.array([0, -0.9, 0])   # kaenlaalune
        c -= 0.22 * np.exp(-np.sum((P - q) ** 2, 1) / (2 * 0.45 ** 2))
    crotch = (V[group_vertices("joint-l-upper-leg")].mean(0) + V[group_vertices("joint-r-upper-leg")].mean(0)) / 2 + np.array([0, -0.6, 0])
    c -= 0.2 * np.exp(-np.sum((P - crotch) ** 2, 1) / (2 * 0.5 ** 2))
    if item_id.startswith(OLD_ERAS):
        ymin = P[used, 1].min()
        c -= 0.18 * np.clip(1 - (P[:, 1] - ymin) / 1.6, 0, 1)   # alumise ääre mustus
    c = np.clip(c, 0.55, 1.0) ** 2.2   # glTF värvid on lineaarsed
    return np.stack([c, c, c, np.ones_like(c)], 1)
def build_garment(body, item_id, item, V, globals_, normals):
    N_body, N_tights, N_skirt, N_hair = normals
    parts = [p for p in garment_parts(item_id, item, V, N_body, N_tights, N_skirt, N_hair) if (p[0] == "gen" or len(p[0]))]
    if not parts:
        return False
    g = Glb(); kind = material_kind(item_id)
    t = lambda m: g.image_uri(f"../../textures/{kind}_{m}.png")
    mat = g.material(item_id, (1, 1, 1), 1.0, 1.0 if kind in ("metal", "mail", "plate") else 0.0, t("albedo"), double=True,
                     normal=t("normal"), orm=t("orm"), normal_scale=1.0 if kind != "hair" else 0.7)
    names = []
    for k, prt in enumerate(parts):
        if prt[0] == "gen":
            gp = prt[1]
            md = HAIR.to_md(gp); md["uv"] = (gp.UV * (0.1 / TILE_M[kind]) * 2).astype(np.float32)
            nm = f"{item_id}_{k}"; g.mesh(nm, md, mat); names.append(nm)
            continue
        fids, N, off, grp = prt
        if grp in DRAPED:
            # kõik kihid samal langenud pinnal (nõgusad kohad täidetud), siis kihi nihe ja siledad servad
            Pd, Nd = DRAPED[grp]
            extra = np.full(len(V), 0.012 if grp != "helper-skirt" else 0.0)
            if item["slot"] == "legs" and grp == "helper-tights" and not any(k in item_id for k in ("hose", "leggings", "stockings")):
                # püksisääred lahedamad, värvel jääb särgi alla
                crotch = joint_y(V, "joint-l-upper-leg"); ankle = joint_y(V, "joint-l-ankle")
                top = np.clip((crotch + 0.3 - V[:, 1]) / 1.2, 0, 1)
                low = np.clip((V[:, 1] - (ankle + 2.0)) / 1.0, 0, 1)      # saabaste säärte all kitsam
                extra += 0.1 * top * (0.2 + 0.8 * low)
            P = Pd + Nd * (off * 10 + extra)[:, None]
            P = drape(P, Nd, fids, 30, 0.0, interior=False)
            Nn = vertex_normals(P, fids)
        else:
            P = V + N * off * 10; Nn = N
        C = garment_shade(V, P, item_id, fids) if kind not in ("hair", "metal") else None
        md = mesh_from_tris(triangulate(fids), P * SCALE, Nn, JOINTS, WTS, BASE_VT, UV_M[grp] / TILE_M[kind], C)
        nm = f"{item_id}_{k}"; g.mesh(nm, md, mat); names.append(nm)
    g.write(f"{PROJECT}/assets/people/clothes/{item_id}/{body}.glb", globals_, names,
            {"placeholder": True, "note": "Automaatne proovirõivas MakeHumani abivõrkudest; asenda päris MPFB2 riidega."})
    return True

import hair as HAIR

def hair_items_for(body):
    male = body in ("man", "boy")
    styles = [k for k in HAIR.STYLES if k.startswith("hair_m_" if male else "hair_w_")]
    beards = list(HAIR.BEARDS) if body == "man" else []
    return styles, beards

def write_hair_part(item_id, body, parts, globals_):
    g = Glb()
    t = lambda kind, m: g.image_uri(f"../../textures/{kind}_{m}.png")
    names = []
    for k, (kind, part) in enumerate(parts):
        mat = g.material(item_id + "_" + kind, (1, 1, 1), 1.0, 0.0, t(kind, "albedo"), double=True,
                         normal=t(kind, "normal"), orm=t(kind, "orm"), normal_scale=0.8, alpha=0.5 if kind == "hairlock" else None)
        g.mesh(f"{item_id}_{k}", HAIR.to_md(part), mat); names.append(f"{item_id}_{k}")
    g.write(f"{PROJECT}/assets/people/clothes/{item_id}/{body}.glb", globals_, names,
            {"generated": "tools/hair.py", "note": "Parameetriline soeng/habe MPFB2 kehale."})

def build_hair(body, V, N_body, globals_):
    HAIR.init(sys.modules[__name__])
    h = HAIR.Head(V, N_body)
    styles, beards = hair_items_for(body)
    for sid in styles:
        write_hair_part(sid, body, HAIR.build_style(h, sid, seed=sum(map(ord, sid)) % 997), globals_)
    for bid in beards:
        part = HAIR.build_beard(h, bid)
        if part is not None:
            write_hair_part(bid, body, [("hair", part)], globals_)
    return len(styles) + len(beards)

UV_M = {}
HEADS = {}
DRAPED = {}
CURRENT_BODY = None
if __name__ == "__main__":
    ONLY_BODIES = [b for b in os.environ.get("ONLY_BODIES", "").split(",") if b]
    ONLY_ITEMS = os.environ.get("ONLY_ITEMS", "")
    if not os.environ.get("SKIP_FABRICS"): write_fabrics()
    for name in BODIES:
        if ONLY_BODIES and name not in ONLY_BODIES: continue
        print("keha", name)
        V, N_body, globals_ = build_body(name)
        for grp in ("body", "helper-tights", "helper-skirt", "helper-hair"):
            UV_M[grp] = uv_meters(V, grp)
        HAIR.init(sys.modules[__name__]); HEADS[name] = HAIR.Head(V, N_body); CURRENT_BODY = name
        if MAKE_CLOTHES:
            normals = (N_body, vertex_normals(V, faces_of("helper-tights")), vertex_normals(V, faces_of("helper-skirt")),
                       vertex_normals(V, faces_of("helper-hair")))
            DRAPED.clear()
            for grp, Ng, it_, cap_ in (("helper-tights", normals[1], 600, 0.25), ("helper-skirt", normals[2], 300, 0.35), ("body", N_body, 40, 0.08)):
                fall = faces_of(grp); Pd = drape(V.copy(), Ng, fall, it_, cap_, lam=0.9, normal_only=True)
                DRAPED[grp] = (Pd, vertex_normals(Pd, fall))
            made = sum(build_garment(name, iid, it, V, globals_, normals) for iid, it in ITEMS.items()
                       if it["slot"] not in ("hair", "beard") and (not ONLY_ITEMS or any(iid.startswith(k) for k in ONLY_ITEMS.split(","))))
            if not ONLY_ITEMS or "hair" in ONLY_ITEMS: made += build_hair(name, V, N_body, globals_)
            print("  proovirõivaid", made)
