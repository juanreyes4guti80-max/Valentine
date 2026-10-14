"""Copia texturas CC0 del Kenney Particle Pack (kenney.nl) y las normaliza para Roblox:
el brillo máximo dentro de la forma pasa a blanco (para que el ColorSequence tiña limpio).
uso: python -I import_kenney.py <carpeta_kenney> <outdir>"""
import sys, os
import numpy as np
from PIL import Image
SRC, OUT = sys.argv[1], sys.argv[2]
NAMES = ["fire_01", "fire_02", "muzzle_01", "muzzle_03", "muzzle_04", "muzzle_05", "smoke_04", "smoke_07",
         "smoke_08", "smoke_10", "scorch_02", "star_06", "flare_01", "twirl_01", "twirl_02", "trace_01",
         "circle_03", "spark_01", "spark_02"]
os.makedirs(OUT, exist_ok=True)
for n in NAMES:
    a = np.asarray(Image.open(os.path.join(SRC, n + ".png")).convert("RGBA")).astype(np.float32)
    m = a[..., 3] > 10
    lum = a[..., 0]
    hi = np.percentile(lum[m], 98) if m.any() else 255
    lo = 20.0
    v = np.clip((lum - lo) / max(hi - lo, 1) , 0, 1)
    v = 0.25 + 0.75 * v ** 0.85          # conserva el detalle interior sin quedar oscuro
    rgb = (v * 255)[..., None].repeat(3, -1)
    out = np.concatenate([rgb, a[..., 3:4]], -1).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(os.path.join(OUT, "kk_" + n + ".png"))
    print("OK kk_" + n)
