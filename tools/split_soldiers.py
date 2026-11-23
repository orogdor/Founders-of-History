"""Jagab sõdurimudelid kaheks: SoldierBody (inimese keha + rõivad + kiiver) ja SoldierGear (relvad, kilbid, hobune).

Animatsioonid, luustik ja materjalid jäävad samaks; ainult ühe võrgu kolmnurgad jaotatakse kahte võrku.
Mäng näitab lähedal uut inimest + SoldierGear ja kaugel vana SoldierBody (LOD).
Kasutus: python3 split_soldiers.py <projekt>
"""
import json, os, struct, sys
import numpy as np

PROJECT = sys.argv[1]
COMP = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32}
NUM = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

def load(path):
    f = open(path, "rb").read()
    jl = struct.unpack("<I", f[12:16])[0]; j = json.loads(f[20:20 + jl])
    off = 20 + jl; bl = struct.unpack("<I", f[off:off + 4])[0]; b = bytearray(f[off + 8:off + 8 + bl])
    return j, b

def acc(j, b, i):
    a = j["accessors"][i]; v = j["bufferViews"][a["bufferView"]]
    dt = np.dtype(COMP[a["componentType"]]); n = NUM[a["type"]]; cnt = a["count"]
    start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = v.get("byteStride", 0) or dt.itemsize * n
    buf = np.frombuffer(bytes(b[start:start + stride * (cnt - 1) + dt.itemsize * n]), np.uint8)
    if stride == dt.itemsize * n:
        out = buf.view(dt).reshape(cnt, n)
    else:
        out = np.stack([buf[k * stride:k * stride + dt.itemsize * n].view(dt) for k in range(cnt)])
    out = np.array(out)
    if a.get("normalized") and dt != np.float32:
        out = out.astype(np.float32) / np.iinfo(dt).max
    return out

def add_indices(j, b, idx):
    while len(b) % 4: b += b"\0"
    off = len(b); data = idx.astype(np.uint32).tobytes(); b += data
    j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": 34963})
    j["accessors"].append({"bufferView": len(j["bufferViews"]) - 1, "componentType": 5125, "count": int(len(idx)), "type": "SCALAR"})
    return len(j["accessors"]) - 1

def node_globals(j):
    nodes = j["nodes"]; parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []): parent[c] = i
    def local(n):
        m = np.eye(4)
        if "matrix" in n: return np.array(n["matrix"]).reshape(4, 4).T
        t = n.get("translation", [0, 0, 0]); r = n.get("rotation", [0, 0, 0, 1]); s = n.get("scale", [1, 1, 1])
        x, y, z, w = r
        R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        m[:3, :3] = R * np.array(s)[None, :]; m[:3, 3] = t; return m
    G = {}
    def g(i):
        if i not in G: G[i] = (g(parent[i]) @ local(nodes[i])) if i in parent else local(nodes[i])
        return G[i]
    for i in range(len(nodes)): g(i)
    return G

def seg_dist(P, a, b):
    ab = b - a; t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)

HUMAN_CHAINS = [("body", "chest"), ("chest", "head"), ("upperArm_L", "forearm_L"), ("forearm_L", "hand_L"), ("upperArm_R", "forearm_R"), ("forearm_R", "hand_R"),
                ("thigh_L", "shin_L"), ("thigh_R", "shin_R"), ("hips", "spine"), ("spine", "chest"), ("chest", "neck"), ("neck", "head"),
                ("shin_L", "foot_L"), ("shin_R", "foot_R")]

def split(path, out, threshold=0.2):
    j, b = load(path)
    G = node_globals(j)
    names = {n.get("name"): i for i, n in enumerate(j["nodes"])}
    skin = j["skins"][0]; joints = skin["joints"]; jname = [j["nodes"][i].get("name") for i in joints]
    pos_of = {nm: G[names[nm]][:3, 3] for nm in jname}
    rot_of = {nm: G[names[nm]][:3, :3] for nm in jname}
    # skaala: vanad inimpõhised sõdalased on ~1 ühik pikad, uued sõdurid meetrites
    tall = max(p[1] for p in pos_of.values()) - min(p[1] for p in pos_of.values())
    unit = tall / 1.0 if "hips" in pos_of else 1.0
    th = threshold * (1.0 / 1.66 if "hips" in pos_of else 1.0)
    segs = []
    for a, c in HUMAN_CHAINS:
        if a in pos_of and c in pos_of: segs.append((pos_of[a], pos_of[c]))
    if "head" in pos_of:
        hp = pos_of["head"]; segs.append((hp, hp + np.array([0, 0.28 if "hips" not in pos_of else 0.17, 0])))
    for side in ("L", "R"):
        for hand in ("hand_" + side,):
            if hand in pos_of: segs.append((pos_of[hand], pos_of[hand] + np.array([0, -0.12, 0]) * (1 / 1.66 if "hips" in pos_of else 1)))
        foot = "foot_" + side if "foot_" + side in pos_of else "shin_" + side
        if foot in pos_of: segs.append((pos_of[foot], pos_of[foot] + np.array([0, -0.45, 0.12]) * (1 / 1.66 if "hips" in pos_of else 1)))
    stats = {}
    body_mesh_node = None
    for ni, n in enumerate(j["nodes"]):
        if "mesh" in n and "skin" in n and n.get("name") in ("body", "model"):
            body_mesh_node = ni; break
    if body_mesh_node is None:
        for ni, n in enumerate(j["nodes"]):
            if "mesh" in n and "skin" in n: body_mesh_node = ni; break
    if body_mesh_node is None:
        return None
    mesh = j["meshes"][j["nodes"][body_mesh_node]["mesh"]]
    body_prims, gear_prims = [], []
    for prim in mesh["primitives"]:
        P = acc(j, b, prim["attributes"]["POSITION"])
        Jt = acc(j, b, prim["attributes"]["JOINTS_0"]).astype(int); Wt = acc(j, b, prim["attributes"]["WEIGHTS_0"])
        idx = acc(j, b, prim["indices"]).ravel().astype(np.int64) if "indices" in prim else np.arange(len(P))
        tris = idx.reshape(-1, 3)
        # ühendatud osad (ühised tipud + samas kohas olevad tipud)
        key = np.round(P / 1e-4).astype(np.int64)
        _, canon = np.unique(key, axis=0, return_inverse=True); canon = canon.ravel()
        parent = np.arange(canon.max() + 1)
        def find(x):
            while parent[x] != x:
                parent[x] = parent[parent[x]]; x = parent[x]
            return x
        for t in canon[tris]:
            r0 = find(t[0])
            for v in t[1:]:
                r = find(v)
                if r != r0: parent[r] = r0
        comp_of_vert = np.array([find(c) for c in canon])
        comp_tri = comp_of_vert[tris[:, 0]]
        dom = jname_arr = np.array(jname)[Jt[np.arange(len(P)), np.argmax(Wt, 1)]]
        dmin = np.min(np.stack([seg_dist(P, a, c) for a, c in segs]), 0)
        mat = j["materials"][prim["material"]].get("name", "") if "material" in prim else ""
        team_mat = mat == "team_color"
        sc = 1 / 1.66 if "hips" in pos_of else 1.0
        def arm_dist(Pv, side):
            ch = [n for n in ("upperArm_" + side, "forearm_" + side, "hand_" + side) if n in pos_of]
            pts = [pos_of[n] for n in ch] + [pos_of[ch[-1]] + rot_of[ch[-1]] @ np.array([0, -0.12 * sc, 0])]
            return np.min(np.stack([seg_dist(Pv, pts[k], pts[k + 1]) for k in range(len(pts) - 1)]), 0)
        def classify(vs, tri_count):
            bones, counts = np.unique(dom[vs], return_counts=True); bone = bones[np.argmax(counts)]
            if bone.startswith("horse"): return True
            if bone == "head": return False
            if bone.startswith(("hand_", "forearm_")):
                ext = np.linalg.norm(P[vs].max(0) - P[vs].min(0))
                return arm_dist(P[vs], bone[-1]).max() > 0.13 * sc and ext > (0.4 if team_mat else 0.22) * sc
            if bone in ("body", "chest", "hips", "spine", "root") and not team_mat and dmin[vs].max() > th:
                Q = P[vs] - P[vs].mean(0)
                ev = np.sort(np.linalg.svd(Q, compute_uv=False)) if len(vs) > 3 else np.array([1, 1, 1])
                return ev[-1] / max(ev[-2], 1e-6) > 3.0
            return False
        gmask = np.zeros(len(tris), bool)
        cids, cnt = np.unique(comp_tri, return_counts=True)
        for cid, c in zip(cids, cnt):
            sel = comp_tri == cid
            if c > 0.5 * len(tris):
                # kokkukeevitatud suur tükk: kolmnurga kaupa, ainult käte küljes olev kaugel asuv osa
                for side in ("L", "R"):
                    tb = np.array([str(x) for x in dom[tris[:, 0]]])
                    onarm = sel & np.char.startswith(tb, ("hand_" + side)) | sel & np.char.startswith(tb, ("forearm_" + side))
                    if onarm.any():
                        far = arm_dist(P[tris[onarm].ravel()], side).reshape(-1, 3).max(1) > 0.13 * sc
                        idx_on = np.where(onarm)[0]; gmask[idx_on[far]] = True
                    if "horse" in " ".join(jname):
                        gmask |= sel & np.char.startswith(tb, "horse")
            else:
                vs = np.unique(tris[sel].ravel())
                if classify(vs, c): gmask |= sel
        stats[len(stats)] = (int(gmask.sum()), int((~gmask).sum()))
        bp = dict(prim); gp = dict(prim)
        bp["indices"] = add_indices(j, b, tris[~gmask].ravel()); gp["indices"] = add_indices(j, b, tris[gmask].ravel())
        if (~gmask).any(): body_prims.append(bp)
        if gmask.any(): gear_prims.append(gp)
    mesh["primitives"] = body_prims or mesh["primitives"][:0]
    mesh["name"] = "SoldierBody"
    j["nodes"][body_mesh_node]["name"] = "SoldierBody"
    if gear_prims:
        j["meshes"].append({"name": "SoldierGear", "primitives": gear_prims})
        node = {"name": "SoldierGear", "mesh": len(j["meshes"]) - 1, "skin": j["nodes"][body_mesh_node]["skin"]}
        j["nodes"].append(node)
        scene = j["scenes"][j.get("scene", 0)]
        # sama vanem mis kehal
        parent = None
        for i, n in enumerate(j["nodes"]):
            if body_mesh_node in n.get("children", []): parent = i
        if parent is None: scene["nodes"].append(len(j["nodes"]) - 1)
        else: j["nodes"][parent]["children"].append(len(j["nodes"]) - 1)
    if not body_prims:
        del j["nodes"][body_mesh_node]["mesh"]
    j["buffers"][0]["byteLength"] = len(b)
    js = json.dumps(j, separators=(",", ":")).encode(); js += b" " * ((4 - len(js) % 4) % 4)
    while len(b) % 4: b += b"\0"
    data = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(b)) + struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(b), 0x004E4942) + bytes(b)
    os.makedirs(os.path.dirname(out), exist_ok=True); open(out, "wb").write(data)
    return stats

if __name__ == "__main__":
    SOLD = f"{PROJECT}/assets/soldiers"
    done = {}
    for fn in sorted(os.listdir(SOLD)):
        if not fn.endswith(".glb") or "_team" in fn: continue
        kind = fn[:-4]
        st = split(f"{SOLD}/{fn}", f"{SOLD}/split/{fn}")
        done[kind] = st
        print(kind, st)
    for kind in ("spearman", "axeman", "slinger"):
        st = split(f"{PROJECT}/assets/people/{kind}_v262.glb", f"{SOLD}/split/{kind}_v262.glb")
        print(kind + "_v262", st)
