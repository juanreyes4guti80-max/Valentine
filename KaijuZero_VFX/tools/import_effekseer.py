"""Importa texturas CC0 de las muestras oficiales de Effekseer (github.com/effekseer/Effekseer,
Release/Sample: "All the licenses of these effects are CC-0") y las normaliza para Roblox:
escala de grises (Roblox tiñe con ColorSequence) + canal alfa real (las que venían sobre negro
para mezcla aditiva usan su luminancia como alfa).
uso: python -I import_effekseer.py <carpeta Release/Sample> <outdir>"""
import os
import sys
import numpy as np
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
PICK = {
    "fx_burst_a": "01_NextSoft01/Texture/Burst01.png",
    "fx_burst_b": "01_Suzuki01/003_snowstorm_effect/Texture/Burst01_2.png",
    "fx_burst_soft": "01_Pierre02/Texture/Burst_1.png",
    "fx_burst_fan": "01_Pierre02/Texture/Burst_2.png",
    "fx_burst_curtain": "01_Pierre02/Texture/Burst_3.png",
    "fx_feather_4x4": "01_Pierre02/Texture/Feather.png",
    "fx_fire_2x2": "01_Pierre02/Texture/Fire.png",
    "fx_fire_blur_2x2": "01_Pierre02/Texture/Fire_Blur.png",
    "fx_fire_single": "01_Pierre02/Texture/Fire_Single.png",
    "fx_halo": "01_Pierre02/Texture/Halo.png",
    "fx_shock_spiky": "01_NextSoft01/Texture/Shock_wave002.png",
    "fx_shock_spiky2": "01_NextSoft01/Texture/Shock_wave003.png",
    "fx_shock_soft": "01_Pierre02/Texture/Shockwave.png",
    "fx_shock_double": "01_AndrewFM01/Texture/double-shockwave.png",
    "fx_smoke_2x2": "01_Pierre02/Texture/Smoke.png",
    "fx_smoke_lit_2x2": "01_Pierre02/Texture/Smoke_Lighting.png",
    "fx_smoke_round": "01_AndrewFM01/Texture/smoke_tex.png",
    "fx_spark4": "01_NextSoft01/Texture/Spark001.png",
    "fx_star": "01_Pierre02/Texture/Star.png",
    "fx_line": "01_NextSoft01/Texture/Line01.png",
    "fx_line_curve": "01_Pierre02/Texture/Line1.png",
    "fx_splash_2x2": "01_Pierre02/Texture/Splash.png",
    "fx_wind_swirl": "01_Pierre02/Texture/Wind.png",
    "fx_wind_lines": "01_AndrewFM01/Texture/Wind01.png",
    "fx_dot_soft": "01_Pierre02/Texture/Particle_Soft.png",
    "fx_glow": "01_AndrewFM01/Texture/glow.png",
}
for name, rel in PICK.items():
    im = Image.open(os.path.join(SRC, rel))
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    lum = a[..., :3].max(-1)
    if a[..., 3].min() >= 250:          # sin alfa: venía sobre negro (aditiva)
        alpha = lum
        val = np.full_like(lum, 255.0)
    else:
        alpha = a[..., 3]
        m = alpha > 8
        hi = np.percentile(lum[m], 99) if m.any() else 255
        val = np.clip(lum / max(hi, 1) * 255, 0, 255)
    out = np.stack([val, val, val, alpha], -1).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    if max(img.size) > 1024:
        img.thumbnail((1024, 1024), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"))
    print("OK", name, img.size)
