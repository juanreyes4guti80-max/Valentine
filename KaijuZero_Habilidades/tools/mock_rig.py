"""Rig de prueba con nombres estilo Auto-Rig Pro (solo para validar el pipeline
mientras llega el .blend real). Personaje mirando a -Y, arriba +Z, izquierda +X."""
import bpy, math
from mathutils import Vector, Matrix

def _bone(eb, name, head, tail, parent=None, roll=0.0, connect=False, deform=False):
    b = eb.new(name)
    b.head = Vector(head); b.tail = Vector(tail); b.roll = roll
    if parent:
        b.parent = eb[parent]; b.use_connect = connect
    b.use_deform = deform
    return b

def build_mock(scale=1.0):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    arm = bpy.data.armatures.new("rig_mock")
    ob = bpy.data.objects.new("rig", arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.edit_bones
    s = scale
    V = lambda x, y, z: (x * s, y * s, z * s)
    _bone(eb, "c_traj", V(0, 0, 0), V(0, -0.4, 0))
    _bone(eb, "c_root_master.x", V(0, 0.02, 1.05), V(0, 0.02, 1.25), "c_traj")
    _bone(eb, "c_root.x", V(0, 0.02, 1.05), V(0, 0.02, 0.9), "c_root_master.x")
    _bone(eb, "c_spine_01.x", V(0, 0.02, 1.05), V(0, 0.03, 1.25), "c_root_master.x")
    _bone(eb, "c_spine_02.x", V(0, 0.03, 1.25), V(0, 0.04, 1.45), "c_spine_01.x", connect=True)
    _bone(eb, "c_spine_03.x", V(0, 0.04, 1.45), V(0, 0.04, 1.62), "c_spine_02.x", connect=True)
    _bone(eb, "c_neck.x", V(0, 0.04, 1.62), V(0, 0.02, 1.76), "c_spine_03.x", connect=True)
    _bone(eb, "c_head.x", V(0, 0.02, 1.76), V(0, 0.02, 2.0), "c_neck.x", connect=True)
    for side, sx in (("l", 1), ("r", -1)):
        _bone(eb, f"c_shoulder.{side}", V(0.04 * sx, 0.02, 1.58), V(0.2 * sx, 0.05, 1.6), "c_spine_03.x")
        # A-pose ~40 grados, codo con ligera flexion hacia atras
        sh = Vector(V(0.2 * sx, 0.05, 1.6))
        el = sh + Vector((0.27 * sx, 0.03, -0.22)) * s
        wr = el + Vector((0.25 * sx, -0.03, -0.2)) * s
        hd = wr + Vector((0.09 * sx, -0.0, -0.075)) * s
        _bone(eb, f"c_arm_fk.{side}", sh, el, f"c_shoulder.{side}")
        _bone(eb, f"c_forearm_fk.{side}", el, wr, f"c_arm_fk.{side}", connect=True)
        _bone(eb, f"c_hand_fk.{side}", wr, hd, f"c_forearm_fk.{side}", connect=True)
        # dedos simplificados
        hdir = (hd - wr).normalized()
        for i, fname in enumerate(("index", "middle", "ring", "pinky")):
            off = Vector((0, -0.02 + 0.013 * i, 0)) * s
            p0 = hd + off
            p1 = p0 + hdir * 0.04 * s
            p2 = p1 + hdir * 0.03 * s
            p3 = p2 + hdir * 0.025 * s
            _bone(eb, f"c_{fname}1.{side}", p0, p1, f"c_hand_fk.{side}")
            _bone(eb, f"c_{fname}2.{side}", p1, p2, f"c_{fname}1.{side}", connect=True)
            _bone(eb, f"c_{fname}3.{side}", p2, p3, f"c_{fname}2.{side}", connect=True)
        t0 = wr + Vector((0.01 * sx, -0.035, -0.01)) * s
        t1 = t0 + Vector((0.025 * sx, -0.025, -0.02)) * s
        t2 = t1 + Vector((0.02 * sx, -0.02, -0.015)) * s
        _bone(eb, f"c_thumb1.{side}", t0, t1, f"c_hand_fk.{side}")
        _bone(eb, f"c_thumb2.{side}", t1, t2, f"c_thumb1.{side}", connect=True)
        # piernas: cadena IK
        hip = Vector(V(0.11 * sx, 0.02, 1.0))
        knee = Vector(V(0.12 * sx, -0.03, 0.55))
        ank = Vector(V(0.13 * sx, 0.03, 0.09))
        toe = Vector(V(0.13 * sx, -0.14, 0.02))
        _bone(eb, f"thigh_ik.{side}", hip, knee, "c_root.x")
        _bone(eb, f"leg_ik.{side}", knee, ank, f"thigh_ik.{side}", connect=True)
        _bone(eb, f"foot.{side}", ank, toe, f"leg_ik.{side}", connect=True)
        _bone(eb, f"c_foot_ik.{side}", ank, ank + Vector((0, -0.15, 0)) * s, "c_traj")
        _bone(eb, f"c_leg_pole.{side}", knee + Vector((0, -0.5, 0)) * s, knee + Vector((0, -0.6, 0)) * s, "c_traj")
    # cola (kaiju)
    prev = None
    p = Vector(V(0, 0.12, 1.0))
    for i in range(6):
        q = p + Vector((0, 0.17, -0.07 + 0.012 * i)) * s
        _bone(eb, f"c_tail_{i:02d}.x", p, q, prev if prev else "c_root.x", connect=bool(prev))
        prev = f"c_tail_{i:02d}.x"; p = q
    bpy.ops.object.mode_set(mode='POSE')
    for side in ("l", "r"):
        leg = ob.pose.bones[f"leg_ik.{side}"]
        c = leg.constraints.new('IK')
        c.target = ob; c.subtarget = f"c_foot_ik.{side}"
        c.pole_target = ob; c.pole_subtarget = f"c_leg_pole.{side}"
        c.pole_angle = -math.pi / 2; c.chain_count = 2
        ft = ob.pose.bones[f"foot.{side}"]
        c2 = ft.constraints.new('COPY_ROTATION'); c2.target = ob; c2.subtarget = f"c_foot_ik.{side}"
    for pb in ob.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    bpy.ops.object.mode_set(mode='OBJECT')
    _skin_boxes(ob, s)
    return ob

def _skin_boxes(ob, s):
    """Geometria de bloques rigidos pegada a cada hueso (silueta para previews)."""
    import bmesh
    radii = {"c_spine_01.x": 0.2, "c_spine_02.x": 0.21, "c_spine_03.x": 0.2, "c_neck.x": 0.08,
             "c_head.x": 0.11, "c_root.x": 0.19}
    mat = bpy.data.materials.new("skin"); mat.diffuse_color = (0.35, 0.3, 0.28, 1)
    for b in ob.data.bones:
        n = b.name
        if n.startswith("c_traj") or "pole" in n or n.startswith("c_foot_ik") or n == "c_root_master.x":
            continue
        if n.startswith("c_arm_fk"): r = 0.07
        elif n.startswith("c_forearm_fk"): r = 0.06
        elif n.startswith("c_hand_fk"): r = 0.045
        elif n.startswith("thigh_ik"): r = 0.1
        elif n.startswith("leg_ik"): r = 0.075
        elif n.startswith("foot"): r = 0.05
        elif n.startswith("c_tail"):
            i = int(n[7:9]); r = 0.12 * (1 - i / 7.0)
        elif n.startswith("c_shoulder"): r = 0.07
        elif n.startswith(("c_index", "c_middle", "c_ring", "c_pinky", "c_thumb")): r = 0.012
        else: r = radii.get(n, 0.05)
        L = b.length
        me = bpy.data.meshes.new("m_" + n)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=r * s if r < 0.5 else r, radius2=r * s * 0.85,
                              depth=L, matrix=Matrix.Translation((0, L / 2, 0)) @ Matrix.Rotation(math.radians(-90), 4, 'X'))
        bm.to_mesh(me); bm.free()
        me.materials.append(mat)
        mo = bpy.data.objects.new("geo_" + n, me)
        bpy.context.scene.collection.objects.link(mo)
        mo.parent = ob; mo.parent_type = 'BONE'; mo.parent_bone = n
        mo.matrix_parent_inverse = Matrix.Identity(4)
        # parent_type BONE coloca el origen en la COLA del hueso: compensar
        mo.location = (0, -L, 0)
