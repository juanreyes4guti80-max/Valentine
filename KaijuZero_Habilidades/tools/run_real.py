"""Construye el kit de KAIJU ZERO sobre el rig Auto-Rig Pro real.
uso: python run_real.py entrada.blend outdir [clips...]
Variables de entorno: KZ_STEP (frames entre renders), KZ_RES, KZ_IDLE (nombre de la acción idle),
KZ_NORENDER=1 para solo construir."""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
import bpy
from mathutils import Vector, Matrix
import kzanim as K
import kz_kit
import kz_retarget
import preview

SRC = sys.argv[1]
OUT = sys.argv[2]
ONLY = sys.argv[3:]
STEP = int(os.environ.get("KZ_STEP", "2"))
RES = int(os.environ.get("KZ_RES", "420"))
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=SRC)
sc = bpy.context.scene
FPS = kz_kit.FPS

# ---------------------------------------------------------------- rig
rigs = [o for o in bpy.data.objects if o.type == "ARMATURE" and "c_root_master.x" in o.pose.bones]
assert rigs, "No encontré un armature Auto-Rig Pro (c_root_master.x)"
ob = rigs[0]
print("RIG:", ob.name)
bpy.context.view_layer.objects.active = ob
pbn = ob.pose.bones


def chain(prefix, side, n=4):
    out = []
    for i in range(1, n + 1):
        nm = f"c_{prefix}{i}.{side}"
        if nm in pbn:
            out.append(nm)
    return out


prof = {
    "spine": [b for b in ("c_spine_01.x", "c_spine_02.x", "c_spine_03.x", "c_spine_04.x") if b in pbn],
    "tail": sorted([b.name for b in pbn if b.name.startswith("c_tail_") and b.name.endswith(".x")
                    and b.name[7:9].isdigit()], key=lambda n: int(n[7:9])),
    "fingers": {S: {f: chain(f, S.lower()) for f in ("thumb", "index", "middle", "ring", "pinky")} for S in ("L", "R")},
}
w = {1: [1.0], 2: [0.5, 0.5], 3: [0.34, 0.33, 0.33], 4: [0.25, 0.25, 0.25, 0.25]}[len(prof["spine"])]
prof["spine_w"] = w
for k, v in kz_kit.PROFILE_OVERRIDES.items() if hasattr(kz_kit, "PROFILE_OVERRIDES") else []:
    prof[k] = v
rig = K.Rig(ob, prof)
print("spine:", rig.p["spine"], "tail:", len(rig.p["tail"]),
      "fingers:", {s: list(rig.p["fingers"][s].keys()) for s in ("L", "R")})

# ---------------------------------------------------------------- IK/FK
def switch(bone, prop):
    return pbn[bone][prop] if bone in pbn and prop in pbn[bone] else None


ARM_SW = {"L": ("c_hand_ik.l", "ik_fk_switch"), "R": ("c_hand_ik.r", "ik_fk_switch")}
LEG_SW = {"L": ("c_foot_ik.l", "ik_fk_switch"), "R": ("c_foot_ik.r", "ik_fk_switch")}


def snap_arm_fk_to_visible(side):
    """Si el brazo está en IK, copia la pose IK a los controles FK (como el snap de ARP)."""
    s = side.lower()
    pairs = [(f"c_arm_fk.{s}", f"arm_ik.{s}"), (f"c_forearm_fk.{s}", f"forearm_ik.{s}"), (f"c_hand_fk.{s}", f"c_hand_ik.{s}")]
    mats = {}
    for fk, ik in pairs:
        if ik in pbn:
            mats[fk] = pbn[ik].matrix.copy()
    for fk, _ in pairs:
        if fk in mats:
            M = mats[fk].copy()
            M.translation = pbn[fk].matrix.translation
            pbn[fk].matrix = M
            K.upd()


def snap_leg_ik_to_visible(side):
    s = side.lower()
    if f"c_foot_fk.{s}" in pbn and f"c_foot_ik.{s}" in pbn:
        M = pbn[f"c_foot_fk.{s}"].matrix.copy()
        pbn[f"c_foot_ik.{s}"].matrix = M
        K.upd()


# ---------------------------------------------------------------- idle
idle_name = os.environ.get("KZ_IDLE")
acts = list(bpy.data.actions)
if not idle_name:
    cands = [a for a in acts if "idle" in a.name.lower() and "ign" not in a.name.lower()]
    cands.sort(key=lambda a: (len(a.name), a.name))
    idle_name = cands[0].name if cands else None
print("IDLE:", idle_name)
if ob.animation_data is None:
    ob.animation_data_create()
if idle_name:
    ob.animation_data.action = bpy.data.actions[idle_name]
    sc.frame_set(int(bpy.data.actions[idle_name].frame_range[0]))
K.upd()
for side in ("L", "R"):
    v = switch(*ARM_SW[side])
    print(f"brazo {side} ik_fk_switch en idle =", v)
    if v is not None and v < 0.5:
        snap_arm_fk_to_visible(side)
    v = switch(*LEG_SW[side])
    print(f"pierna {side} ik_fk_switch en idle =", v)
    if v is not None and v > 0.5:
        snap_leg_ik_to_visible(side)
# congelar la pose evaluada del idle y capturarla
CAP = K.capture(rig)
ob.animation_data.action = None
rig.reset()

# ---------------------------------------------------------------- construir
def key_switches(act, f0):
    for side in ("L", "R"):
        for (bone, prop), val in ((ARM_SW[side], 1.0), (LEG_SW[side], 0.0)):
            if bone in pbn and prop in pbn[bone]:
                pbn[bone][prop] = val
                pbn[bone].keyframe_insert(f'["{prop}"]', frame=f0, group=bone)


def build(fn):
    spec = fn()
    loop = spec.get("loop", False)
    keys = kz_retarget.retarget(spec["keys"], kz_kit.IDLE, CAP, rig)
    act = K.build_action(rig, spec["name"], keys, fps=FPS, loop=loop)
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    groups = K.bone_groups(rig)
    for g, lag in (spec.get("lags") or {}).items():
        bones = groups.get(g, [])
        for i, bn in enumerate(bones):
            l = lag[min(i, len(lag) - 1)] if isinstance(lag, (list, tuple)) else lag
            if g == "tail" and isinstance(lag, (list, tuple)) and len(bones) != len(lag):
                l = round(lag[0] + (lag[-1] - lag[0]) * i / max(1, len(bones) - 1))
            K.shift_keys(act, bn, l, f0, f1, loop=loop)
    K.add_markers(act, spec.get("markers", []), FPS)
    if spec.get("post"):
        spec["post"](rig, act)
    key_switches(act, f0)
    act["kz_sword"] = bool(spec.get("sword"))
    return act


built = []
for fn in kz_kit.KIT:
    if ONLY and fn.__name__ not in ONLY:
        continue
    act = build(fn)
    built.append(act)
    print("BUILT", act.name, tuple(act.frame_range))

# ---------------------------------------------------------------- QA
def qa(act):
    ob.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    rep = {"pen": 0.0, "slide": 0.0, "wrist": 0.0}
    prev = {}
    gz = min((ob.matrix_world @ rig.foot_base[s].translation).z for s in rig.foot_base)
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        for s in ("L", "R"):
            fk = rig.p["foot_ik"][s]
            if fk not in pbn:
                continue
            p = ob.matrix_world @ pbn[fk].matrix.translation
            if s in prev:
                v = (p - prev[s]).length
                if p.z - gz < 0.01 * rig.root_h:
                    rep["slide"] = max(rep["slide"], v / rig.root_h)
            prev[s] = p
            up, fo, ha = rig.p["arm"][s]
            a = pbn[fo].matrix.to_3x3().col[1].normalized()
            b = pbn[ha].matrix.to_3x3().col[1].normalized()
            rep["wrist"] = max(rep["wrist"], math.degrees(a.angle(b)))
    return rep


for act in built:
    print("QA", act.name, {k: round(v, 3) for k, v in qa(act).items()})

# ---------------------------------------------------------------- previews
if not os.environ.get("KZ_NORENDER"):
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and (o.parent == ob or any(m.type == "ARMATURE" and m.object == ob for m in o.modifiers))]
    zs = []
    for m in meshes:
        for c in m.bound_box:
            zs.append((m.matrix_world @ Vector(c)).z)
    hmin, hmax = (min(zs), max(zs)) if zs else (0, 2)
    Hc = hmax - hmin
    preview.setup_scene((RES, RES), FPS)
    gr = preview.ground(size=Hc * 8, z=hmin)
    for o in bpy.data.objects:
        if o.type == "MESH" and o not in meshes and o != gr and not o.name.lower().startswith(("sword", "espada")):
            o.hide_render = True
    ctr = (0, Hc * 0.12, hmin + Hc * 0.5)
    cams = {
        "side": preview.camera("kz_cam_side", ctr, Hc * 2.4, 90, 4),
        "34": preview.camera("kz_cam_34", ctr, Hc * 2.5, 40, 12),
    }
    for act in built:
        ob.animation_data.action = act
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        vids = []
        for cn, cam in cams.items():
            d = os.path.join(OUT, f"{act.name}_{cn}")
            os.makedirs(d, exist_ok=True)
            for f in os.listdir(d):
                os.remove(os.path.join(d, f))
            preview.render_frames(cam, f0, f1, d, step=STEP)
            vids.append(preview.to_mp4(d, os.path.join(OUT, f"{act.name}_{cn}.mp4"), fps=FPS // STEP, label=f"{act.name} {cn}"))
        preview.hstack(vids, os.path.join(OUT, f"{act.name}.mp4"))
        print("RENDER", act.name)

ob.animation_data.action = None
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "KaijuZero_Habilidades.blend"))
print("SAVED")
