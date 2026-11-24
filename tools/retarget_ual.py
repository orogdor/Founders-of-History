"""Kannab Quaternius Universal Animation Library (CC0) liigutused MPFB2 kehadele.

Kasutus: python3 tools/retarget_ual.py <mpfb2>/src/mpfb/data <makehuman>/makehuman/data <projekt> <UAL1_Standard.glb> <UAL2_Standard.glb>
Tulemus: assets/people/animations/<keha>.glb (luustik + animatsioonid, iga keha jaoks eraldi, sest puhkeasendid erinevad).

Ülekanne: iga luu maailmapöörde muutus algse luustiku puhkeasendi suhtes (D) kantakse MPFB luule, mille puhkeasend
on enne pööratud samasse suunda kui allika puhkeasend (C, kahe telje järgi: luu suund + teine telg, nt peopesa põiki).
G_uus = D * C * G_puhke. Puusa nihe skaleeritakse puusa kõrguste suhtega.
"""
import os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
UAL1, UAL2 = sys.argv[4], sys.argv[5]
sys.argv = sys.argv[:4]
import mpfb_bodies as M
from ual_lib import Source, q_to_m_batch, m_to_q_batch

# (allikas, klipp, uus nimi, kordub)
CLIPS = [
    ("UAL1", "Idle_Loop", "idle", True),
    ("UAL2", "Idle_FoldArms_Loop", "idle_arms", True),
    ("UAL1", "Idle_Talking_Loop", "talk", True),
    ("UAL1", "Idle_Torch_Loop", "hold_up", True),
    ("UAL2", "Idle_Lantern_Loop", "hold_down", True),
    ("UAL2", "Idle_Rail_Loop", "lean", True),
    ("UAL2", "Idle_No_Loop", "idle_no", True),
    ("UAL2", "Yes", "yes", False),
    ("UAL1", "Walk_Loop", "walk", True),
    ("UAL1", "Walk_Formal_Loop", "walk_formal", True),
    ("UAL2", "Walk_Carry_Loop", "walk_carry", True),
    ("UAL1", "Jog_Fwd_Loop", "jog", True),
    ("UAL1", "Sprint_Loop", "sprint", True),
    ("UAL1", "Crouch_Fwd_Loop", "sneak", True),
    ("UAL1", "Crouch_Idle_Loop", "crouch", True),
    ("UAL1", "Sitting_Enter", "sit_down", False),
    ("UAL1", "Sitting_Idle_Loop", "sit", True),
    ("UAL1", "Sitting_Talking_Loop", "sit_talk", True),
    ("UAL1", "Sitting_Exit", "sit_up", False),
    ("UAL2", "Consume", "eat", False),
    ("UAL1", "Dance_Loop", "dance", True),
    ("UAL1", "Push_Loop", "push", True),
    ("UAL1", "Interact", "interact", False),
    ("UAL1", "PickUp_Table", "pick_up", False),
    ("UAL1", "Fixing_Kneeling", "fix_kneel", True),
    ("UAL2", "TreeChopping_Loop", "chop", True),
    ("UAL2", "Farm_Harvest", "harvest", False),
    ("UAL2", "Farm_PlantSeed", "plant", False),
    ("UAL2", "Farm_Watering", "water", False),
    ("UAL2", "Chest_Open", "open", False),
    ("UAL2", "OverhandThrow", "throw", False),
    ("UAL1", "Sword_Idle", "sword_idle", True),
    ("UAL1", "Sword_Attack", "sword_attack", False),
    ("UAL2", "Sword_Regular_A", "sword_a", False),
    ("UAL2", "Sword_Regular_B", "sword_b", False),
    ("UAL2", "Sword_Regular_C", "sword_c", False),
    ("UAL2", "Sword_Block", "sword_block", False),
    ("UAL2", "Idle_Shield_Loop", "shield_idle", True),
    ("UAL2", "Shield_OneShot", "shield_bash", False),
    ("UAL1", "Pistol_Idle_Loop", "gun_idle", True),
    ("UAL1", "Pistol_Aim_Neutral", "gun_aim", False),
    ("UAL1", "Pistol_Shoot", "gun_shoot", False),
    ("UAL1", "Pistol_Reload", "gun_reload", False),
    ("UAL1", "Punch_Jab", "punch", False),
    ("UAL1", "Hit_Chest", "hit", False),
    ("UAL2", "Hit_Knockback", "hit_back", False),
    ("UAL1", "Death01", "death", False),
    ("UAL2", "LayToIdle", "get_up", False),
    ("UAL1", "Driving_Loop", "ride", True),
]

UAL_NAME = {"Root": "root", "head": "Head"}
FINGERS = ("index", "middle", "ring", "pinky", "thumb")

def primary_child(b):
    """Luu, mille suunas luu osutab (mõlemas luustikus sama nimega)."""
    chain = {"pelvis": "spine_01", "spine_01": "spine_02", "spine_02": "spine_03", "spine_03": "neck_01", "neck_01": "head"}
    if b in chain: return chain[b]
    side = b[-2:]
    if b.startswith("clavicle"): return "upperarm" + side
    if b.startswith("upperarm"): return "lowerarm" + side
    if b.startswith("lowerarm"): return "hand" + side
    if b.startswith("hand"): return "middle_01" + side
    if b.startswith("thigh"): return "calf" + side
    if b.startswith("calf"): return "foot" + side
    if b.startswith("foot"): return "ball" + side
    if b.startswith("ball"): return "ball_leaf" + side
    for f in FINGERS:
        if b.startswith(f + "_"):
            k = int(b.split("_")[1]); return f"{f}_{k + 1:02d}" + side
    return None

def secondary_kind(b):
    if any(b.startswith(f + "_") for f in FINGERS) or b.startswith("hand"): return "palm"
    if b.startswith(("clavicle", "upperarm", "lowerarm", "thigh", "calf")): return "fwd"
    return "side"

def frame(p, s):
    p = p / np.linalg.norm(p)
    s = s - p * np.dot(s, p); n = np.linalg.norm(s)
    if n < 1e-6:
        s = np.array([0, 0, 1.0]) - p * p[2]; n = np.linalg.norm(s)
    s = s / n
    return np.stack([p, s, np.cross(p, s)], 1)

def src_rest(src):
    Gr, Gp = src.globals(src.rest_t[None], src.rest_r[None])
    return Gr[0], Gp[0]

def dir_src(src, Gp0, b):
    c = primary_child(b)
    if b in ("Root", "head") or c is None: return np.array([0, 1.0, 0])
    name = UAL_NAME.get(c, c)
    if name not in src.index:
        parts = c.split("_")          # index_04_l -> index_04_leaf_l
        name = f"{parts[0]}_{parts[1]}_leaf_{parts[2]}" if len(parts) == 3 else name
    if name not in src.index: return None
    return Gp0[src.index[name]] - Gp0[src.index[UAL_NAME.get(b, b)]]

def dir_dst(gl, b):
    c = primary_child(b)
    if b in ("Root", "head"): return np.array([0, 1.0, 0])
    if c is not None and c in gl: return gl[c][:3, 3] - gl[b][:3, 3]
    return gl[b][:3, 1]

def palm_axis(pos, side):
    return pos("index_01" + side) - pos("pinky_01" + side)

def calibration(src, Gr0, Gp0, gl):
    spos = lambda n: Gp0[src.index[UAL_NAME.get(n, n)]]
    dpos = lambda n: gl[n][:3, 3]
    C = {}
    for b in M.BONES:
        ds = dir_src(src, Gp0, b); dd = dir_dst(gl, b)
        if ds is None: C[b] = np.eye(3); continue
        kind = secondary_kind(b)
        if kind == "palm":
            side = b[-2:]; ss = palm_axis(spos, side); sd = palm_axis(dpos, side)
        elif kind == "fwd":
            ss = sd = np.array([0, 0, 1.0])
        else:
            ss = sd = np.array([1.0, 0, 0])
        C[b] = frame(ds, ss) @ frame(dd, sd).T
    return C

def decimate(times, vals, tol, rot):
    """Jätab ainult vajalikud võtmekaadrid (lineaarne vahepealne viga < tol)."""
    n = len(times); keep = [0]; k = 0
    def err(a, b):
        t = (times[a + 1:b] - times[a]) / (times[b] - times[a])
        mid = vals[a][None] * (1 - t[:, None]) + vals[b][None] * t[:, None]
        if rot:
            mid /= np.linalg.norm(mid, axis=1, keepdims=True)
            d = np.abs(np.sum(mid * vals[a + 1:b], 1)); return np.max(2 * np.arccos(np.clip(d, -1, 1))) if len(d) else 0
        return np.max(np.linalg.norm(mid - vals[a + 1:b], axis=1)) if b - a > 1 else 0
    j = 2
    while j < n:
        if err(k, j) > tol:
            keep.append(j - 1); k = j - 1
        j += 1
    keep.append(n - 1)
    keep = sorted(set(keep))
    return times[keep], vals[keep]

# Seisuasendid, kus allika jalad on laiali ("valmis" asend): jalad lähemale
NARROW = {"idle": 0.45, "idle_arms": 0.45, "talk": 0.45, "hold_up": 0.5, "hold_down": 0.45, "idle_no": 0.45, "yes": 0.45,
          "lean": 0.6, "interact": 0.6, "eat": 0.5, "gun_idle": 0.7, "sword_idle": 0.75, "shield_idle": 0.75}

def slerp_m(Dm, k):
    """Pöördemaatriksite osaline pööre (k=0 -> ühik, k=1 -> D)."""
    q = m_to_q_batch(Dm); w = np.clip(q[:, 3], -1, 1)
    ang = 2 * np.arccos(np.abs(w)); axis = q[:, :3] * np.sign(w)[:, None]
    n = np.linalg.norm(axis, axis=1, keepdims=True); n[n < 1e-9] = 1; axis /= n
    a = ang * k; qq = np.concatenate([axis * np.sin(a / 2)[:, None], np.cos(a / 2)[:, None]], 1)
    return q_to_m_batch(qq)

def leg_points(G, gl, pos):
    """Jala punktid (pahkluu, päkk) puusa asendist ja luude maailmapööretest."""
    out = {}
    for side in ("_l", "_r"):
        p = pos.copy(); prev = "pelvis"
        for b in ("thigh", "calf", "foot", "ball"):
            nb = b + side
            off = gl[nb][:3, 3] - gl[prev][:3, 3]
            rest_prev = gl[prev][:3, :3]
            p = p + np.einsum("fij,j->fi", G[prev] @ rest_prev.T[None], off)
            out[nb] = p.copy(); prev = nb
    return out

def retarget(src, clip, gl, C, Gr0, Gp0, fps=30, name=""):
    times, T, R = src.sample(clip, fps)
    Gr, Gp = src.globals(T, R)
    nf = len(times)
    G = {}
    for b in M.BONES:
        if b == "Root":
            G[b] = np.repeat(gl[b][None, :3, :3], nf, 0); continue
        i = src.index[UAL_NAME.get(b, b)]
        D = Gr[:, i] @ Gr0[i].T
        if name in NARROW and b.startswith(("thigh", "calf", "foot")):
            # jalad loomulikumalt koos: ainult osa allika reie/sääre pöördest puhkeasendi suhtes
            Dp = Gr[:, src.index["pelvis"]] @ Gr0[src.index["pelvis"]].T
            rel = np.transpose(Dp, (0, 2, 1)) @ D
            D = Dp @ slerp_m(rel, NARROW[name])
        G[b] = D @ (C[b] @ gl[b][:3, :3])[None]
    # puus
    ip = src.index["pelvis"]
    ratio = gl["pelvis"][1, 3] / Gp0[ip][1]
    pos = gl["pelvis"][:3, 3][None] + (Gp[:, ip] - Gp0[ip][None]) * ratio
    if name in NARROW:
        # jalad maapinnale: madalaim jalapunkt samale kõrgusele kui puhkeasendis
        pts = leg_points(G, gl, pos)
        low = np.minimum.reduce([pts[k][:, 1] for k in pts])
        ground = min(gl["ball_l"][1, 3], gl["foot_l"][1, 3])
        pos[:, 1] += ground - low
    out = {}
    for b in M.BONES:
        p = M.RIG[b]["parent"]
        if p:
            L = np.transpose(G[p], (0, 2, 1)) @ G[b]
        else:
            L = G[b]
        out[b] = m_to_q_batch(L)
    pr = M.RIG["pelvis"]["parent"]
    if pr:
        Pr = gl[pr]
        ptrans = (np.linalg.inv(Pr[:3, :3]) @ (pos - Pr[:3, 3][None]).T).T
    else:
        ptrans = pos
    return times, out, ptrans

def write_anim_glb(body, gl, clips, path):
    g = M.Glb()
    # väike nähtamatu kolmnurk, et Godot teeks luustiku (Skeleton3D)
    md = dict(pos=np.array([[0, 0, 0], [0.001, 0, 0], [0, 0.001, 0]], np.float32), nor=np.array([[0, 0, 1]] * 3, np.float32),
              uv=np.zeros((3, 2), np.float32), joi=np.zeros((3, 4), np.uint16),
              wei=np.array([[1, 0, 0, 0]] * 3, np.float32), idx=np.array([0, 1, 2], np.uint32))
    mat = g.material("none", (1, 1, 1))
    g.mesh("anim_proxy", md, mat)
    anims = []
    for name, (times, rots, ptrans) in clips.items():
        samplers, channels = [], []
        for b in M.BONES:
            if b == "Root": continue
            t, v = decimate(times, rots[b], 0.004, True)
            ti = g.accessor(t.astype(np.float32)[:, None], "SCALAR", 5126, minmax=True)
            vi = g.accessor(v.astype(np.float32), "VEC4", 5126)
            samplers.append({"input": ti, "output": vi, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": M.BONE_INDEX[b], "path": "rotation"}})
        t, v = decimate(times, ptrans, 0.001, False)
        ti = g.accessor(t.astype(np.float32)[:, None], "SCALAR", 5126, minmax=True)
        vi = g.accessor(v.astype(np.float32), "VEC3", 5126)
        samplers.append({"input": ti, "output": vi, "interpolation": "LINEAR"})
        channels.append({"sampler": len(samplers) - 1, "target": {"node": M.BONE_INDEX["pelvis"], "path": "translation"}})
        anims.append({"name": name, "samplers": samplers, "channels": channels})
    # Glb.write ei tea animatsioonidest: lisa need JSON-i kirjutamise ajal
    orig_dumps = M.json.dumps
    def dumps(obj, **kw):
        if isinstance(obj, dict) and "skins" in obj: obj["animations"] = anims
        return orig_dumps(obj, **kw)
    M.json.dumps = dumps
    try:
        g.write(path, gl, ["anim_proxy"], {"generated": "tools/retarget_ual.py",
                                           "source": "Quaternius Universal Animation Library 1 & 2 (CC0)"})
    finally:
        M.json.dumps = orig_dumps

def main():
    srcs = {"UAL1": Source(UAL1), "UAL2": Source(UAL2)}
    rest = {k: src_rest(s) for k, s in srcs.items()}
    outdir = f"{M.PROJECT}/assets/people/animations"
    os.makedirs(outdir, exist_ok=True)
    only = [b for b in os.environ.get("ONLY_BODIES", "").split(",") if b]
    for body in M.BODIES:
        if only and body not in only: continue
        V = M.shaped_vertices(M.body_info(body)); V[:, 1] -= V[M.group_vertices("joint-ground")].mean(0)[1]
        gl = M.build_rig(V)
        cal = {k: calibration(s, rest[k][0], rest[k][1], gl) for k, s in srcs.items()}
        clips = {}
        for sk, clip, name, loop in CLIPS:
            s = srcs[sk]
            if clip not in s.anims: print("  puudub", clip); continue
            clips[name] = retarget(s, clip, gl, cal[sk], rest[sk][0], rest[sk][1], name=name)
        path = f"{outdir}/{body}.glb"
        write_anim_glb(body, gl, clips, path)
        print(body, len(clips), "klippi", os.path.getsize(path) // 1024, "kB")

if __name__ == "__main__":
    main()
