"""Render de previews (Workbench, sin GPU) y armado de MP4 con ffmpeg."""
import bpy
import math
import os
import subprocess
from mathutils import Vector


def setup_scene(res=(480, 480), fps=60):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.fps = fps
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    sh.cavity_type = "WORLD"
    sh.show_shadows = True
    sh.shadow_intensity = 0.6
    sh.show_object_outline = True
    sh.object_outline_color = (0.05, 0.05, 0.05)
    sc.display.shadow_focus = 0.2
    sc.render.film_transparent = False
    sc.world = sc.world or bpy.data.worlds.new("W")
    sc.world.color = (0.55, 0.57, 0.6)
    sc.render.image_settings.file_format = "PNG"
    return sc


def ground(size=20.0, z=0.0):
    if "preview_ground" in bpy.data.objects:
        return bpy.data.objects["preview_ground"]
    import bmesh
    me = bpy.data.meshes.new("preview_ground")
    bm = bmesh.new()
    n = 20
    step = size / n
    mats = []
    for i in range(n):
        for j in range(n):
            x0, y0 = -size / 2 + i * step, -size / 2 + j * step
            vs = [bm.verts.new((x0, y0, z)), bm.verts.new((x0 + step, y0, z)),
                  bm.verts.new((x0 + step, y0 + step, z)), bm.verts.new((x0, y0 + step, z))]
            f = bm.faces.new(vs)
            f.material_index = (i + j) % 2
    bm.to_mesh(me)
    bm.free()
    for k, c in enumerate(((0.42, 0.44, 0.47, 1), (0.36, 0.38, 0.41, 1))):
        m = bpy.data.materials.new(f"ground{k}")
        m.diffuse_color = c
        me.materials.append(m)
    ob = bpy.data.objects.new("preview_ground", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def camera(name, target, dist, azim_deg, elev_deg, lens=50.0, ortho=None):
    """azim 0 = cámara al frente del personaje (que mira -Y); 90 = a su derecha."""
    cam = bpy.data.objects.get(name)
    if cam is None:
        cd = bpy.data.cameras.new(name)
        cam = bpy.data.objects.new(name, cd)
        bpy.context.scene.collection.objects.link(cam)
    cam.data.lens = lens
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    a = math.radians(azim_deg)
    e = math.radians(elev_deg)
    # frente del personaje = -Y. Derecha del personaje = -X.
    d = Vector((-math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    target = Vector(target)
    cam.location = target + d * dist
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_end = 1000
    return cam


def render_frames(cam, f0, f1, outdir, step=1):
    sc = bpy.context.scene
    sc.camera = cam
    os.makedirs(outdir, exist_ok=True)
    paths = []
    for i, f in enumerate(range(f0, f1 + 1, step)):
        sc.frame_set(f)
        p = os.path.join(outdir, f"{i:04d}.png")
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        paths.append(p)
    return paths


def to_mp4(pattern_dir, out, fps=60, label=None):
    vf = []
    if label:
        vf.append(f"drawtext=text='{label}':x=8:y=8:fontsize=18:fontcolor=white:box=1:boxcolor=black@0.5")
    cmd = ["ffmpeg", "-v", "error", "-y", "-framerate", str(fps), "-i", os.path.join(pattern_dir, "%04d.png")]
    if vf:
        cmd += ["-vf", ",".join(vf)]
    cmd += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", out]
    subprocess.run(cmd, check=True)
    return out


def hstack(videos, out):
    cmd = ["ffmpeg", "-v", "error", "-y"]
    for v in videos:
        cmd += ["-i", v]
    cmd += ["-filter_complex", f"hstack=inputs={len(videos)}", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", out]
    subprocess.run(cmd, check=True)
    return out


def contact_sheet(frame_dir, out, every=6, cols=8, width=160):
    files = sorted(f for f in os.listdir(frame_dir) if f.endswith(".png"))[::every]
    if not files:
        return None
    lst = os.path.join(frame_dir, "_list.txt")
    rows = math.ceil(len(files) / cols)
    cmd = ["ffmpeg", "-v", "error", "-y", "-framerate", "1", "-start_number", "0",
           "-pattern_type", "glob", "-i", os.path.join(frame_dir, "*.png"),
           "-vf", f"select='not(mod(n\\,{every}))',scale={width}:-1,"
                  f"drawtext=text='%{{n}}':x=2:y=2:fontsize=12:fontcolor=yellow,tile={cols}x{rows}",
           "-frames:v", "1", out]
    subprocess.run(cmd, check=True)
    return out
