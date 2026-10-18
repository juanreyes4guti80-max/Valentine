"""Texturas CC0 para los VFX cósmicos de ASTRAL COLOSSUS (Kenney Particle Pack + muestras de Effekseer),
normalizadas igual que las de Kaiju Zero: escala de grises (Roblox tiñe con ColorSequence) + alfa real.
uso: python -I import_astral.py <carpeta_kenney> <carpeta Effekseer Release/Sample> <outdir>"""
import os
import shutil
import sys
import numpy as np
from PIL import Image

KENNEY = ["star_06", "star_08", "star_09", "spark_02", "spark_05", "spark_06", "trace_01", "trace_07",
          "circle_03", "smoke_07", "smoke_04"]
EFFEKSEER = {
    "fx_fog3001": "01_NextSoft01/Texture/Fog3001.png",
    "fx_fog2001": "01_NextSoft01/Texture/Fog2001.png",
    "fx_particle02": "01_NextSoft01/Texture/Particle02.png",
    "fx_spark002": "01_NextSoft01/Texture/Spark002.png",
    "fx_shock_wave003": "01_NextSoft01/Texture/Shock_wave003.png",
    "fx_wind_swirl": "01_Pierre02/Texture/Wind.png",
    "fx_glow": "01_AndrewFM01/Texture/glow.png",
    "fx_shock_soft": "01_Pierre02/Texture/Shockwave.png",
}
# generadas para Kaiju Zero (son tuyas): esquirlas de roca y marca de suelo
OWN = ["kz_debris_2x2", "kz_scorch"]


def kenney(src, dst):
    """El brillo máximo dentro de la forma pasa a blanco (mismo criterio que import_kenney.py)."""
    a = np.asarray(Image.open(src).convert("RGBA")).astype(np.float32)
    m = a[..., 3] > 10
    lum = a[..., 0]
    hi = np.percentile(lum[m], 98) if m.any() else 255
    v = np.clip((lum - 20.0) / max(hi - 20.0, 1), 0, 1)
    v = 0.25 + 0.75 * v ** 0.85
    rgb = (v * 255)[..., None].repeat(3, -1)
    Image.fromarray(np.concatenate([rgb, a[..., 3:4]], -1).astype(np.uint8), "RGBA").save(dst)


def effekseer(src, dst):
    """Las que vienen sobre negro (para mezcla aditiva) usan su luminancia como alfa."""
    a = np.asarray(Image.open(src).convert("RGBA")).astype(np.float32)
    lum = a[..., :3].max(-1)
    if a[..., 3].min() >= 250:
        alpha, val = lum, np.full_like(lum, 255.0)
    else:
        alpha = a[..., 3]
        m = alpha > 8
        hi = np.percentile(lum[m], 99) if m.any() else 255
        val = np.clip(lum / max(hi, 1) * 255, 0, 255)
    img = Image.fromarray(np.stack([val, val, val, alpha], -1).astype(np.uint8), "RGBA")
    if max(img.size) > 1024:
        img.thumbnail((1024, 1024), Image.LANCZOS)
    img.save(dst)


def main(KEN, EFF, OUT):
    os.makedirs(OUT, exist_ok=True)
    for n in KENNEY:
        kenney(os.path.join(KEN, n + ".png"), os.path.join(OUT, "kk_" + n + ".png"))
        print("OK kk_" + n)
    for name, rel in EFFEKSEER.items():
        effekseer(os.path.join(EFF, rel), os.path.join(OUT, name + ".png"))
        print("OK", name)
    for name in OWN:
        shutil.copy(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "textures", name + ".png"),
                    os.path.join(OUT, name + ".png"))
        print("OK", name)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
