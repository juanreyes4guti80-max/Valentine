"""Texturas para los VFX cósmicos de OMNÍVORA: Kenney Particle Pack + muestras de Effekseer (CC0),
normalizadas igual que las de Astral Colossus (escala de grises + alfa real), y dos propias:
  om_cubes_2x2  cubitos sombreados (4 orientaciones) para las esquirlas más pequeñas
  om_cracks     grietas que salen del centro de la zona (para un Decal del suelo)
Las que vienen alargadas (rayos de 64x256, 64x512) se centran en un cuadrado: Roblox dibuja las
partículas cuadradas y así el rayo queda fino.
uso: python -I import_omnivora.py <carpeta_kenney> <carpeta Effekseer Release/Sample> <outdir>"""
import os
import shutil
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_astral import kenney, effekseer

KENNEY = ["circle_01", "circle_02", "light_03", "twirl_01", "twirl_02", "spark_03", "spark_04", "spark_05",
          "spark_06", "star_06", "star_08", "star_09", "trace_01", "trace_06", "trace_07", "smoke_04", "smoke_07"]
EFFEKSEER = {
    "fx_beam": "01_AndrewFM01/Texture/LaserMain02.png",
    "fx_beam_wavy": "01_NextSoft01/Texture/LazerMain01.png",
    "fx_laser_thin": "01_NextSoft01/Texture/LazerMain02.png",
    "fx_thunder": "01_NextSoft01/Texture/Thunder01.png",
    "fx_halo": "01_Pierre02/Texture/Halo.png",
    "fx_spikes": "01_NextSoft01/Texture/Shock_wave_ring002.png",
    "fx_swirl_rings": "01_AndrewFM01/Texture/Wind01.png",
    "fx_electric_ball": "01_NextSoft01/Texture/ElectricBall.png",
    "fx_glow": "01_AndrewFM01/Texture/glow.png",
    "fx_spark002": "01_NextSoft01/Texture/Spark002.png",
    "fx_particle02": "01_NextSoft01/Texture/Particle02.png",
    "fx_fog3001": "01_NextSoft01/Texture/Fog3001.png",
    "fx_fog2001": "01_NextSoft01/Texture/Fog2001.png",
    "fx_wind_swirl": "01_Pierre02/Texture/Wind.png",
}
OWN = ["kz_scorch"]      # generada para Kaiju Zero (marca oscura del suelo)


def square(path):
    """Centra la imagen en un cuadrado transparente del tamaño de su lado mayor."""
    im = Image.open(path)
    w, h = im.size
    if w == h:
        return
    n = max(w, h)
    sq = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    sq.paste(im, ((n - w) // 2, (n - h) // 2))
    sq.save(path)


def cubes_2x2(dst, cell=256):
    """4 cubitos sombreados en distintas orientaciones: solo las caras que miran a la cámara, con luz
    desde arriba (cara superior clara, laterales más oscuros)."""
    ss = 4
    big = Image.new("RGBA", (cell * 2 * ss, cell * 2 * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    light = np.array([-0.35, 0.85, 0.4])
    light /= np.linalg.norm(light)
    corners = np.array([(x, y, z) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)], float)
    faces = [(0, 1, 3, 2, (-1, 0, 0)), (4, 6, 7, 5, (1, 0, 0)), (0, 4, 5, 1, (0, -1, 0)),
             (2, 3, 7, 6, (0, 1, 0)), (0, 2, 6, 4, (0, 0, -1)), (1, 5, 7, 3, (0, 0, 1))]
    for k, (yaw, tilt, roll) in enumerate(((0.62, 0.52, 0.1), (1.2, 0.38, -0.25), (0.3, 0.8, 0.35), (1.45, 0.25, 0.0))):
        cy_, sy_ = np.cos(yaw), np.sin(yaw)
        ct, st = np.cos(tilt), np.sin(tilt)
        cr, sr = np.cos(roll), np.sin(roll)
        Ry = np.array([[cy_, 0, sy_], [0, 1, 0], [-sy_, 0, cy_]])
        Rx = np.array([[1, 0, 0], [0, ct, -st], [0, st, ct]])
        Rz = np.array([[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]])
        R = Rx @ Rz @ Ry          # vista: la cámara mira hacia -Z (de frente) y un poco desde arriba
        cx, cyy = ((k % 2) * cell + cell / 2) * ss, ((k // 2) * cell + cell / 2) * ss
        r = cell * 0.25 * ss
        P = (R @ corners.T).T
        for i0, i1, i2, i3, nrm in faces:
            n = R @ np.array(nrm, float)
            if n[2] <= 0.02:         # de espaldas a la cámara
                continue
            sh = 0.35 + 0.65 * max(0.0, float(n @ light))
            v = int(70 + 185 * sh)
            pts = [(cx + P[i][0] * r, cyy - P[i][1] * r) for i in (i0, i1, i2, i3)]
            d.polygon(pts, fill=(v, v, v, 255), outline=(60, 60, 60, 255))
    big.resize((cell * 2, cell * 2), Image.LANCZOS).save(dst)


def spikes_window(path):
    """Las púas de Effekseer son para envolver un cilindro: se suavizan los bordes del cuadro."""
    im = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
    h, w = im.shape[:2]
    x = (np.arange(w) + 0.5) / w
    wx = np.clip(np.minimum(x, 1 - x) / 0.3, 0, 1) ** 1.2
    y = (np.arange(h) + 0.5) / h
    wy = np.clip((1 - y) / 0.12, 0, 1)
    im[..., 3] *= wy[:, None] * wx[None, :]
    Image.fromarray(im.astype(np.uint8), "RGBA").save(path)


def cracks(dst, size=512, seed=5):
    """Grietas que salen del centro (como un impacto) con ramas y tramos de telaraña, borde suave."""
    rng = np.random.default_rng(seed)
    S = size * 2
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    c = S / 2

    def crack(x, y, ang, length, width, depth):
        steps = int(length / (S * 0.018)) + 1
        pts = [(x, y)]
        for i in range(steps):
            ang += rng.normal(0, 0.22)
            x += np.cos(ang) * S * 0.018
            y += np.sin(ang) * S * 0.018
            pts.append((x, y))
            if depth < 2 and rng.random() < 0.13:
                crack(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.0), length * rng.uniform(0.25, 0.45),
                      max(1.5, width * 0.55), depth + 1)
        for i in range(len(pts) - 1):
            w = width * (1 - 0.75 * i / len(pts))
            d.line([pts[i], pts[i + 1]], fill=255, width=max(1, int(round(w))))
        return pts

    n = 11
    mains = []
    for k in range(n):
        ang = 2 * np.pi * (k + rng.uniform(-0.3, 0.3)) / n
        mains.append(crack(c + np.cos(ang) * S * 0.02, c + np.sin(ang) * S * 0.02, ang,
                           S * rng.uniform(0.36, 0.47), 9, 0))
    # tramos de telaraña entre grietas vecinas
    for rf in (0.12, 0.22, 0.33):
        for k in range(n):
            if rng.random() < 0.55:
                p1, p2 = mains[k], mains[(k + 1) % n]
                i1 = min(len(p1) - 1, int(len(p1) * rf / 0.45))
                i2 = min(len(p2) - 1, int(len(p2) * rf / 0.45))
                mx, my = (p1[i1][0] + p2[i2][0]) / 2, (p1[i1][1] + p2[i2][1]) / 2
                mx += (mx - c) * 0.06
                my += (my - c) * 0.06
                d.line([p1[i1], (mx, my), p2[i2]], fill=210, width=3)
    a = np.asarray(img.filter(ImageFilter.GaussianBlur(1.2)).resize((size, size), Image.LANCZOS)).astype(np.float32) / 255
    glow = np.asarray(img.filter(ImageFilter.GaussianBlur(9)).resize((size, size), Image.LANCZOS)).astype(np.float32) / 255
    v = np.clip(a * 1.25 + glow * 0.9, 0, 1)
    yy, xx = np.mgrid[0:size, 0:size]
    r = np.hypot(xx - size / 2 + 0.5, yy - size / 2 + 0.5) / (size / 2)
    v *= np.clip((0.98 - r) / 0.25, 0, 1)
    img2 = np.stack([np.full_like(v, 255)] * 3 + [v * 255], -1).astype(np.uint8)
    Image.fromarray(img2, "RGBA").save(dst)


def main(KEN, EFF, OUT):
    os.makedirs(OUT, exist_ok=True)
    for n in KENNEY:
        kenney(os.path.join(KEN, n + ".png"), os.path.join(OUT, "kk_" + n + ".png"))
        print("OK kk_" + n)
    for name, rel in EFFEKSEER.items():
        dst = os.path.join(OUT, name + ".png")
        effekseer(os.path.join(EFF, rel), dst)
        square(dst)
        if name == "fx_spikes":
            spikes_window(dst)
        print("OK", name)
    for name in OWN:
        shutil.copy(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "textures", name + ".png"),
                    os.path.join(OUT, name + ".png"))
        print("OK", name)
    cubes_2x2(os.path.join(OUT, "om_cubes_2x2.png"))
    cracks(os.path.join(OUT, "om_cracks.png"))
    print("OK om_cubes_2x2, om_cracks")
    here = os.path.dirname(os.path.abspath(__file__))
    for lic in ("KENNEY_LICENSE.txt", "EFFEKSEER_SAMPLES_LICENSE_CC0.txt"):
        shutil.copy(os.path.join(here, "..", "textures", lic), os.path.join(OUT, lic))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
