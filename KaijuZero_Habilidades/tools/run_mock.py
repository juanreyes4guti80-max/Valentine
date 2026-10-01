"""Construye el kit sobre el rig de prueba y renderiza previews.
uso: python run_mock.py <outdir> [nombres de clips...]"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math
import bpy
from mathutils import Vector, Matrix
import mock_rig
import kzanim as K
import kz_kit
import preview

OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/kz_out"
ONLY = sys.argv[2:]
STEP = int(os.environ.get("KZ_STEP", "2"))
RES = int(os.environ.get("KZ_RES", "360"))
os.makedirs(OUT, exist_ok=True)

ob = mock_rig.build_mock()
rig = K.Rig(ob)


def make_sword(rig, side="R", length=1.05):
    import bmesh
    me = bpy.data.meshes.new("sword")
    bm = bmesh.new()
    hl = rig.hand_len(side)
    # mango (centrado en el puño), guarda, hoja hacia +Y
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, -0.05, 0)) @ Matrix.Diagonal((0.035, 0.32, 0.035, 1)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, 0.13, 0)) @ Matrix.Diagonal((0.22, 0.04, 0.06, 1)))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.06, radius2=0.005, depth=length,
                          matrix=Matrix.Translation((0, 0.15 + length / 2, 0)) @ Matrix.Rotation(math.radians(-90), 4, "X") @ Matrix.Diagonal((1, 0.3, 1, 1)))
    bm.to_mesh(me)
    bm.free()
    mat = bpy.data.materials.new("sword_mat")
    mat.diffuse_color = (0.9, 0.35, 0.08, 1)
    me.materials.append(mat)
    so = bpy.data.objects.new("SWORD", me)
    bpy.context.scene.collection.objects.link(so)
    ha = rig.p["arm"][side][2]
    B = ob.data.bones[ha]
    Y = Vector((0, 1, 0))
    n = rig.palm_local[side]
    t = Y.cross(n) if side == "R" else n.cross(Y)
    tilt = rig.p.get("grip_tilt", 20.0) * K.D2R
    a = (t * math.cos(tilt) + Y * math.sin(tilt)).normalized()
    g = Y * 0.42 * hl + n * 0.18 * hl
    Rm = K.rot_from_frames(Vector((1, 0, 0)), Vector((0, 1, 0)), n, a)
    so.parent = ob
    so.parent_type = "BONE"
    so.parent_bone = ha
    so.matrix_parent_inverse = Matrix.Identity(4)
    M = Rm.to_4x4()
    M.translation = g - Y * B.length
    so.matrix_basis = M
    return so


def build(fn):
    spec = fn()
    loop = spec.get("loop", False)
    act = K.build_action(rig, spec["name"], spec["keys"], fps=kz_kit.FPS, loop=loop)
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    groups = K.bone_groups(rig)
    for g, lag in (spec.get("lags") or {}).items():
        for i, bn in enumerate(groups.get(g, [])):
            l = lag[min(i, len(lag) - 1)] if isinstance(lag, (list, tuple)) else lag
            K.shift_keys(act, bn, l, f0, f1, loop=loop)
    K.add_markers(act, spec.get("markers", []), kz_kit.FPS)
    if spec.get("post"):
        spec["post"](rig, act)
    act["kz_sword"] = bool(spec.get("sword"))
    return act


def key_sword(so, act):
    so.animation_data_clear()
    fps = kz_kit.FPS
    mk = {m.name: m.frame for m in act.pose_markers}
    a, b = mk.get("SwordSummon", 30), mk.get("SwordVanish", 130)
    for f, sc in ((0, 0.0), (a, 0.0), (a + 10, 1.08), (a + 14, 1.0), (b, 1.0), (b + 12, 0.0)):
        so.scale = (sc, sc, sc)
        so.keyframe_insert("scale", frame=f)


def tip_report(so, act):
    sc = bpy.context.scene
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    low = []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        Mw = so.matrix_world
        tip = Mw @ Vector((0, 1.2 / max(so.scale[1], 1e-6) * so.scale[1] if False else 1.2, 0))
        tip = so.matrix_world @ Vector((0, 1.2, 0))
        low.append((round(tip.z, 3), f, tuple(round(x, 2) for x in tip)))
    print("TIP z por frame (70-110):", [(f, z) for z, f, _ in low if 70 <= f <= 110])


preview.setup_scene((RES, RES), kz_kit.FPS)
preview.ground()
sword = make_sword(rig)
cams = {
    "side": preview.camera("cam_side", (0, 0.25, 1.0), 4.6, 90, 4),
    "34": preview.camera("cam_34", (0, 0.2, 1.0), 4.8, 40, 12),
}
for fn in kz_kit.KIT:
    if ONLY and fn.__name__ not in ONLY:
        continue
    act = build(fn)
    ob.animation_data.action = act
    sword.hide_render = not act.get("kz_sword")
    if act.get("kz_sword"):
        key_sword(sword, act)
        tip_report(sword, act)
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    vids = []
    for cn, cam in cams.items():
        d = os.path.join(OUT, f"{act.name}_{cn}")
        if os.path.isdir(d):
            for f in os.listdir(d):
                os.remove(os.path.join(d, f))
        preview.render_frames(cam, f0, f1, d, step=STEP)
        vids.append(preview.to_mp4(d, os.path.join(OUT, f"{act.name}_{cn}.mp4"), fps=kz_kit.FPS // STEP, label=f"{act.name} {cn}"))
    preview.hstack(vids, os.path.join(OUT, f"{act.name}.mp4"))
    print("BUILT", act.name, f0, f1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "mock_kit.blend"))
