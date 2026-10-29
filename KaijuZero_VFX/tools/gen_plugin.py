"""Genera el plugin de Studio "Subir texturas VFX" (Plugin_Studio/SubirTexturasVFX.rbxmx).

Lleva dentro las texturas de los módulos (KaijuFireVFX, OmnivoraVFX, AstralColossusVFX, MoonfangVFX, PebledonVFX) como PNG RGBA en
base64, el decodificador (plugin_studio/Png.luau) y el script del plugin (plugin_studio/main.server.luau).
uso: python gen_plugin.py   (después de gen_luau.py, que escribe las listas texturas_necesarias.txt)"""
import base64
import hashlib
import io
import os
import re
from xml.sax.saxutils import escape

from PIL import Image

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(TOOLS))
FOLDERS = ["KaijuZero_VFX", "Omnivora_VFX", "AstralColossus_VFX", "Moonfang_VFX", "Pebledon_VFX"]
OUT = os.path.join(REPO, "Plugin_Studio")


def textures():
    """nombre -> ruta del PNG, de todas las texturas que usan los módulos (las mismas en las tres carpetas)."""
    out = {}
    for folder in FOLDERS:
        lst = open(os.path.join(REPO, folder, "roblox", "texturas_necesarias.txt")).read()
        for name in re.findall(r"([a-z0-9_]+)\.png", lst):
            out.setdefault(name, os.path.join(REPO, folder, "textures", name + ".png"))
    return dict(sorted(out.items()))


def item(cls, name, source=None, children=(), ref=[0]):
    ref[0] += 1
    props = f'\t\t<string name="Name">{escape(name)}</string>\n'
    if source is not None:
        props += '\t\t<ProtectedString name="Source"><![CDATA[' + source + ']]></ProtectedString>\n'
    return (f'<Item class="{cls}" referent="RBX{ref[0]}">\n\t<Properties>\n{props}\t</Properties>\n'
            + "".join(children) + '</Item>\n')


def main():
    tex = textures()
    index = []
    data = []
    total = 0
    for name, path in tex.items():
        im = Image.open(path).convert("RGBA")
        if max(im.size) > 1024:   # el máximo de un EditableImage
            im.thumbnail((1024, 1024), Image.LANCZOS)
        buf = io.BytesIO()
        im.save(buf, "PNG", optimize=True)
        png = buf.getvalue()
        total += len(png)
        h = hashlib.sha1(png).hexdigest()[:12]
        index.append(f'\t{name} = {{ w = {im.size[0]}, h = {im.size[1]}, hash = "{h}" }},')
        data.append(item("ModuleScript", name, "return [[" + base64.b64encode(png).decode() + "]]\n"))
    index_src = ("-- generado por gen_plugin.py: las texturas que trae el plugin (ancho, alto y huella del PNG)\nreturn {\n"
                 + "\n".join(index) + "\n}\n")
    plugin_dir = os.path.join(TOOLS, "plugin_studio")
    main_src = open(os.path.join(plugin_dir, "main.server.luau")).read()
    png_src = open(os.path.join(plugin_dir, "Png.luau")).read()
    root = item("Script", "SubirTexturasVFX", main_src, [
        item("ModuleScript", "Png", png_src),
        item("ModuleScript", "Indice", index_src),
        item("Folder", "Texturas", None, data),
    ])
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n' + root + '</roblox>\n')
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "SubirTexturasVFX.rbxmx")
    with open(path, "w") as f:
        f.write(xml)
    print(f"OK plugin: {len(tex)} texturas ({total / 1e6:.1f} MB de PNG) -> {os.path.relpath(path, REPO)} "
          f"({os.path.getsize(path) / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
