"""glTF animatsioonide lugemine (Quaternius UAL) ja kaadrite arvutamine."""
import json, struct, numpy as np

COMP = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32, 5122: np.int16, 5120: np.int8}
NUM = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

def load_glb(path):
    b = open(path, "rb").read()
    jl = struct.unpack("<I", b[12:16])[0]; g = json.loads(b[20:20 + jl])
    off = 20 + jl; bl = struct.unpack("<I", b[off:off + 4])[0]
    return g, b[off + 8: off + 8 + bl]

def accessor(g, binb, i):
    a = g["accessors"][i]; v = g["bufferViews"][a["bufferView"]]
    dt = COMP[a["componentType"]]; n = NUM[a["type"]]
    start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = v.get("byteStride", 0)
    item = np.dtype(dt).itemsize * n
    if stride and stride != item:
        raw = np.frombuffer(binb, np.uint8, count=stride * a["count"], offset=start).reshape(a["count"], stride)[:, :item]
        arr = np.frombuffer(raw.tobytes(), dt).reshape(a["count"], n)
    else:
        arr = np.frombuffer(binb, dt, count=a["count"] * n, offset=start).reshape(a["count"], n)
    arr = arr.astype(np.float64)
    if a.get("normalized"):
        arr = arr / float(np.iinfo(dt).max)
    return arr

def q_to_m(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])

def q_to_m_batch(Q):
    x, y, z, w = Q[:, 0], Q[:, 1], Q[:, 2], Q[:, 3]
    M = np.empty((len(Q), 3, 3))
    M[:, 0, 0] = 1 - 2 * (y * y + z * z); M[:, 0, 1] = 2 * (x * y - z * w); M[:, 0, 2] = 2 * (x * z + y * w)
    M[:, 1, 0] = 2 * (x * y + z * w); M[:, 1, 1] = 1 - 2 * (x * x + z * z); M[:, 1, 2] = 2 * (y * z - x * w)
    M[:, 2, 0] = 2 * (x * z - y * w); M[:, 2, 1] = 2 * (y * z + x * w); M[:, 2, 2] = 1 - 2 * (x * x + y * y)
    return M

def m_to_q_batch(M):
    out = np.empty((len(M), 4))
    for i, m in enumerate(M):
        t = np.trace(m)
        if t > 0:
            s = np.sqrt(t + 1.0) * 2; out[i] = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s]
        elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
            s = np.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2; out[i] = [0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s]
        elif m[1, 1] > m[2, 2]:
            s = np.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2; out[i] = [(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s]
        else:
            s = np.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2; out[i] = [(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s]
    out /= np.linalg.norm(out, axis=1, keepdims=True)
    # järjepidev märk (interpolatsiooni jaoks)
    for i in range(1, len(out)):
        if np.dot(out[i], out[i - 1]) < 0: out[i] = -out[i]
    return out

def slerp_batch(q0, q1, t):
    d = np.sum(q0 * q1, 1); q1 = np.where(d[:, None] < 0, -q1, q1); d = np.abs(d)
    t = t[:, None]
    lin = d > 0.9995
    th = np.arccos(np.clip(d, -1, 1))[:, None]; s = np.sin(th); s[s == 0] = 1
    a = np.where(lin[:, None], 1 - t, np.sin((1 - t) * th) / s); b = np.where(lin[:, None], t, np.sin(t * th) / s)
    q = a * q0 + b * q1
    return q / np.linalg.norm(q, axis=1, keepdims=True)

class Source:
    def __init__(self, path):
        self.g, self.bin = load_glb(path)
        g = self.g
        self.parent = {}
        for i, n in enumerate(g["nodes"]):
            for c in n.get("children", []): self.parent[c] = i
        self.names = [n.get("name", str(i)) for i, n in enumerate(g["nodes"])]
        self.index = {n: i for i, n in enumerate(self.names)}
        order, seen = [], set()
        def visit(i):
            if i in seen: return
            if i in self.parent: visit(self.parent[i])
            seen.add(i); order.append(i)
        for i in range(len(g["nodes"])): visit(i)
        self.order = order
        self.rest_t = np.array([n.get("translation", [0, 0, 0]) for n in g["nodes"]], float)
        self.rest_r = np.array([n.get("rotation", [0, 0, 0, 1]) for n in g["nodes"]], float)
        self.rest_s = np.array([n.get("scale", [1, 1, 1]) for n in g["nodes"]], float)
        self.anims = {a["name"]: a for a in g["animations"]}

    def duration(self, name):
        a = self.anims[name]
        return max(accessor(self.g, self.bin, s["input"]).max() for s in a["samplers"])

    def sample(self, name, fps=30):
        """Tagastab (ajad, T[n_frames, nodes, 3], R[n_frames, nodes, 4] kohalikud)."""
        a = self.anims[name]; dur = self.duration(name)
        n = max(2, int(round(dur * fps)) + 1); times = np.linspace(0, dur, n)
        T = np.repeat(self.rest_t[None], n, 0); R = np.repeat(self.rest_r[None], n, 0)
        for ch in a["channels"]:
            node = ch["target"]["node"]; path = ch["target"]["path"]; s = a["samplers"][ch["sampler"]]
            inp = accessor(self.g, self.bin, s["input"])[:, 0]; out = accessor(self.g, self.bin, s["output"])
            interp = s.get("interpolation", "LINEAR")
            if interp == "CUBICSPLINE": out = out[1::3]
            k = np.clip(np.searchsorted(inp, times, side="right") - 1, 0, len(inp) - 1)
            k2 = np.clip(k + 1, 0, len(inp) - 1)
            span = np.where(inp[k2] > inp[k], inp[k2] - inp[k], 1.0)
            f = np.clip((times - inp[k]) / span, 0, 1)
            if interp == "STEP": f = np.zeros_like(f)
            if path == "rotation":
                R[:, node] = slerp_batch(out[k], out[k2], f)
            elif path == "translation":
                T[:, node] = out[k] + (out[k2] - out[k]) * f[:, None]
        return times, T, R

    def globals(self, T, R):
        """Kaadrite maailmamaatriksid: (rot[n_frames,nodes,3,3], pos[n_frames,nodes,3])."""
        nf, nn = T.shape[0], T.shape[1]
        Gr = np.zeros((nf, nn, 3, 3)); Gp = np.zeros((nf, nn, 3))
        S = self.rest_s
        for i in self.order:
            Lr = q_to_m_batch(R[:, i]) * S[i][None, None, :]
            if i in self.parent:
                p = self.parent[i]
                Gr[:, i] = Gr[:, p] @ Lr
                Gp[:, i] = Gp[:, p] + np.einsum("fij,fj->fi", Gr[:, p], T[:, i])
            else:
                Gr[:, i] = Lr; Gp[:, i] = T[:, i]
        return Gr, Gp
