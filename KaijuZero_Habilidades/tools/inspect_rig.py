"""Inspecciona un .blend con rig Auto-Rig Pro: huesos de control, modos de rotación,
interruptores IK/FK, acciones existentes y escala. uso:
  python inspect_rig.py archivo.blend [outdir]"""
import sys
import os
import bpy
from mathutils import Vector

path = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(path)
bpy.ops.wm.open_mainfile(filepath=path)
sc = bpy.context.scene
print("BLENDER file version:", bpy.data.version, "| scene fps:", sc.render.fps, "/", sc.render.fps_base,
      "| frames:", sc.frame_start, sc.frame_end, "| unit scale:", sc.unit_settings.scale_length)
print("\n== OBJETOS ==")
for o in bpy.data.objects:
    extra = ""
    if o.type == "MESH":
        extra = f"verts={len(o.data.vertices)} mods={[m.type for m in o.modifiers]}"
        arm_mods = [m.object.name for m in o.modifiers if m.type == 'ARMATURE' and m.object]
        if arm_mods:
            extra += f" armature={arm_mods}"
    if o.type == "ARMATURE":
        extra = f"bones={len(o.data.bones)} action={o.animation_data.action.name if o.animation_data and o.animation_data.action else None}"
    print(f"  {o.type:9s} {o.name:30s} parent={o.parent.name if o.parent else '-':12s} "
          f"pb={o.parent_bone or '-':14s} scale={tuple(round(x, 3) for x in o.scale)} loc={tuple(round(x, 3) for x in o.location)} "
          f"hide={o.hide_viewport or o.hide_get()} {extra}")

arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
for ob in arms:
    print(f"\n== ARMATURE {ob.name} ==  matrix_world scale={tuple(round(x,4) for x in ob.matrix_world.to_scale())}")
    ctrl = [pb for pb in ob.pose.bones if pb.name.startswith("c_")]
    print(f"  controles c_*: {len(ctrl)}")
    for pb in ctrl:
        b = pb.bone
        h = b.head_local
        cons = [c.type for c in pb.constraints]
        props = {k: (round(v, 3) if isinstance(v, float) else v) for k, v in pb.items()
                 if not k.startswith("_") and isinstance(v, (int, float, str))}
        print(f"  {pb.name:28s} par={b.parent.name if b.parent else '-':24s} rot={pb.rotation_mode:10s} "
              f"head=({h.x:.3f},{h.y:.3f},{h.z:.3f}) len={b.length:.3f} lockL={tuple(pb.lock_location)} "
              f"cons={cons} props={props}")
    # dimensiones
    zs = [ (ob.matrix_world @ b.head_local).z for b in ob.data.bones ] + [ (ob.matrix_world @ b.tail_local).z for b in ob.data.bones ]
    print(f"  altura huesos (mundo): {min(zs):.3f} .. {max(zs):.3f}")
    deform = [b.name for b in ob.data.bones if b.use_deform]
    print(f"  huesos deform: {len(deform)} -> {deform[:80]}")

print("\n== ACCIONES ==")
for a in bpy.data.actions:
    fr = tuple(round(x, 1) for x in a.frame_range)
    try:
        fcs = list(a.fcurves)
    except Exception:
        fcs = []
        for layer in a.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    fcs += list(cb.fcurves)
    bones = sorted({fc.data_path.split('"')[1] for fc in fcs if '"' in fc.data_path})
    nk = sum(len(fc.keyframe_points) for fc in fcs)
    ikfk = [fc for fc in fcs if "ik_fk_switch" in fc.data_path]
    ikv = {fc.data_path.split('"')[1]: round(fc.evaluate(fr[0]), 2) for fc in ikfk}
    print(f"  {a.name:32s} rango={fr} fcurves={len(fcs)} keys={nk} fake_user={a.use_fake_user} "
          f"huesos={len(bones)} ik_fk={ikv}")
    print(f"      {bones[:60]}")

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "_inspect_copy.blend"), copy=True)
