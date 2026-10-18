"""Especificación de los VFX (fuente única: la usan el simulador y el generador Luau).

Cada capa = un ParticleEmitter. Tiempos en segundos desde el impacto.
Tamaños/velocidades en studs a escala 1 (bola de fuego ~22 studs). El módulo
Luau multiplica por `scale`.
flipbook = (layout, mode, framerate, start_random)
"""

import math

CREAM = (255, 244, 205)
WHITE = (255, 255, 255)

EXPLOSION_TOON = {
    "name": "ExplosionToon",
    "doc": "Explosión de fuego anime (impacto de la H1 / H3). Dura 1.3 s y cierra limpio.",
    "duration": 1.3,          # limpieza garantizada: nada vive después de esto
    "light": {"color": (255, 150, 60), "brightness": 4, "range": 30, "time": 0.35},
    "layers": [
        # --- 0.00 s: destello de impacto (dura 2-3 frames de animación) ---
        {"name": "FlashCore", "texture": "kz_star", "emit": [(0.0, 2)],
         "lifetime": (0.12, 0.15), "speed": (0, 0),
         "size": [(0, 10), (0.25, 28), (1, 32)],
         "transparency": [(0, 0), (0.5, 0.35), (1, 1)],
         "color": [(0, (255, 236, 170)), (1, (255, 200, 110))],
         "light_emission": 1.0, "brightness": 1.3, "rotation": (0, 360), "zoffset": 4},
        {"name": "FlashPow", "texture": "kz_flash_2x2", "flipbook": ("Grid2x2", "Random", 0, True),
         "emit": [(0.0, 2), (0.035, 1)], "lifetime": (0.09, 0.13), "speed": (0, 0),
         "size": [(0, 9), (0.35, 22), (1, 25)],
         "transparency": [(0, 0), (0.65, 0), (1, 1)],
         "light_emission": 0.35, "rotation": (0, 360), "rot_speed": (-90, 90), "zoffset": 3},
        # --- onda expansiva: anillo en el suelo + anillo en el aire ---
        {"name": "GroundRing", "texture": "kz_ring", "emit": [(0.0, 1)], "offset": (0, -1.9, 0),
         "orientation": "VelocityPerpendicular", "direction": "Top", "speed": (0.01, 0.01),
         "lifetime": (0.34, 0.34),
         "size": [(0, 4), (0.18, 26), (0.5, 38), (1, 46)],
         "transparency": [(0, 0.0), (0.5, 0.35), (1, 1)],
         "color": [(0, (255, 214, 140)), (1, (255, 150, 70))],
         "light_emission": 0.5},
        {"name": "AirRing", "texture": "kz_ring", "emit": [(0.015, 1)],
         "lifetime": (0.22, 0.22), "speed": (0, 0),
         "size": [(0, 6), (0.3, 30), (1, 40)],
         "transparency": [(0, 0.1), (0.6, 0.55), (1, 1)],
         "color": [(0, (255, 238, 200)), (1, (255, 190, 120))],
         "light_emission": 0.6, "zoffset": 2},
        # --- viento: arcos y rayas rapidísimas en abanico horizontal ---
        {"name": "WindArcs", "texture": "kz_wind_arcs", "emit": [(0.02, 4)],
         "lifetime": (0.22, 0.28), "speed": (0, 0),
         "size": [(0, 12), (0.4, 30), (1, 38)],
         "transparency": [(0, 0.05), (0.55, 0.35), (1, 1)],
         "light_emission": 0.45, "rotation": (0, 360), "rot_speed": (-120, 120), "zoffset": 1.5},
        {"name": "WindStreaks", "texture": "kz_streak", "orientation": "VelocityParallel",
         "emit": [(0.0, 14)], "direction": "Front", "spread": (180, 8),
         "speed": (130, 190), "drag": 9, "lifetime": (0.16, 0.24),
         "size": [(0, 9, 2), (1, 15, 3)],
         "transparency": [(0, 0.15), (0.5, 0.4), (1, 1)],
         "color": [(0, (255, 248, 225)), (1, (255, 225, 170))],
         "light_emission": 0.6},
        # --- cuerpo: bola de fuego que revienta en lóbulos y se erosiona ---
        {"name": "Fireball", "texture": "kz_fire_burst_4x4", "flipbook": ("Grid4x4", "OneShot", 0, False),
         "emit": [(0.0, 9), (0.04, 5)], "shape": {"type": "Sphere", "radius": 2.5},
         "direction": "Top", "spread": (180, 180), "speed": (20, 38), "drag": 4.2, "accel": (0, 10, 0),
         "lifetime": (0.62, 0.85),
         "size": [(0, 8, 2), (0.15, 17, 3), (0.6, 20, 3), (1, 19, 3)],
         "transparency": [(0, 0), (0.9, 0), (1, 1)],
         "color": [(0, WHITE), (0.7, (255, 238, 225)), (1, (225, 170, 150))],
         "light_emission": 0.12, "rotation": (0, 360), "rot_speed": (-45, 45)},
        {"name": "FireTongues", "texture": "kz_fire_tongue_4x4", "flipbook": ("Grid4x4", "OneShot", 0, False),
         "orientation": "VelocityParallel",
         "emit": [(0.01, 16), (0.07, 6)], "direction": "Top", "spread": (110, 110), "speed": (50, 90),
         "drag": 6.5, "accel": (0, -10, 0), "lifetime": (0.42, 0.6),
         "size": [(0, 5, 1), (0.2, 13, 2), (1, 10, 2)],
         "transparency": [(0, 0), (0.88, 0), (1, 1)],
         "light_emission": 0.15},
        {"name": "Pops", "texture": "kz_fire_burst_4x4", "flipbook": ("Grid4x4", "OneShot", 0, False),
         "emit": [(0.1, 3), (0.17, 2)], "shape": {"type": "Sphere", "radius": 7.0, "style": "Surface"},
         "direction": "Top", "spread": (180, 180), "speed": (4, 10), "drag": 4,
         "lifetime": (0.36, 0.46),
         "size": [(0, 3.5, 1), (0.2, 7, 1.5), (1, 6, 1)],
         "transparency": [(0, 0), (0.9, 0), (1, 1)],
         "light_emission": 0.1, "rotation": (0, 360)},
        # --- polvo que sale disparado a ras del suelo (anillo de polvo) ---
        {"name": "GroundDust", "texture": "kz_smoke_4x4", "flipbook": ("Grid4x4", "OneShot", 0, False),
         "emit": [(0.02, 16)], "offset": (0, -1.2, 0), "direction": "Front", "spread": (180, 4),
         "speed": (55, 95), "drag": 5.5, "accel": (0, 5, 0), "lifetime": (0.5, 0.7),
         "size": [(0, 4, 1), (0.4, 9, 2), (1, 11, 2)],
         "transparency": [(0, 0.2), (0.85, 0.3), (1, 1)],
         "color": [(0, (255, 240, 220)), (1, (235, 225, 215))],
         "rotation": (0, 360), "rot_speed": (-60, 60), "zoffset": -0.5},
        # --- columna de fuego hacia arriba (le da verticalidad) ---
        {"name": "Column", "texture": "kz_fire_tongue_4x4", "flipbook": ("Grid4x4", "OneShot", 0, False),
         "orientation": "VelocityParallel", "emit": [(0.03, 5)], "direction": "Top", "spread": (14, 14),
         "speed": (60, 95), "drag": 5, "lifetime": (0.4, 0.55),
         "size": [(0, 8, 2), (0.25, 17, 3), (1, 14, 2)],
         "transparency": [(0, 0), (0.88, 0), (1, 1)],
         "light_emission": 0.15},
        # --- chispas con gravedad ---
        {"name": "Sparks", "texture": "kz_streak", "orientation": "VelocityParallel",
         "emit": [(0.0, 30), (0.06, 16)], "direction": "Top", "spread": (180, 180),
         "speed": (70, 140), "drag": 4, "accel": (0, -60, 0), "lifetime": (0.25, 0.5),
         "size": [(0, 10, 3), (1, 3)],
         "color": [(0, (255, 240, 180)), (0.5, (255, 170, 60)), (1, (230, 80, 20))],
         "light_emission": 0.8, "brightness": 1.2},
        # --- escombros ---
        {"name": "Debris", "texture": "kz_debris_2x2", "flipbook": ("Grid2x2", "Random", 0, True),
         "emit": [(0.02, 14)], "direction": "Top", "spread": (70, 70), "speed": (40, 75),
         "drag": 1.2, "accel": (0, -110, 0), "lifetime": (0.7, 0.95),
         "size": [(0, 1.6, 0.7), (1, 1.4, 0.6)],
         "transparency": [(0, 0), (0.85, 0), (1, 1)],
         "rotation": (0, 360), "rot_speed": (-420, 420), "zoffset": -0.5},
        # --- humo toon que sube mientras el fuego muere, y se rompe en pedazos ---
        {"name": "Smoke", "texture": "kz_smoke_4x4", "flipbook": ("Grid4x4", "OneShot", 0, False),
         "emit": [(0.26, 5), (0.34, 3)], "shape": {"type": "Sphere", "radius": 4.0},
         "direction": "Top", "spread": (60, 60), "speed": (16, 28), "drag": 1.6, "accel": (0, 18, 0),
         "lifetime": (0.75, 0.92),
         "size": [(0, 16, 3), (0.5, 27, 4), (1, 32, 4)],
         "transparency": [(0, 0.25), (0.85, 0.35), (1, 1)],
         "color": [(0, (255, 238, 222)), (1, (220, 212, 206))],
         "rotation": (0, 360), "rot_speed": (-25, 25), "zoffset": -7},
        # --- brasas que suben y se apagan (no quedan flotando) ---
        {"name": "Embers", "texture": "kz_ember", "emit": [(0.12, 18)],
         "shape": {"type": "Sphere", "radius": 4.0}, "direction": "Top", "spread": (120, 120),
         "speed": (10, 30), "drag": 2, "accel": (0, 14, 0), "lifetime": (0.45, 0.7),
         "size": [(0, 0.9, 0.3), (1, 0)],
         "transparency": [(0, 0), (0.7, 0.2), (1, 1)],
         "color": [(0, (255, 220, 140)), (1, (255, 110, 40))],
         "light_emission": 0.9},
    ],
}


# ============================================================================
# LÍNEA DE FUEGO (H3): grieta que corre -> erupción en cadena -> muro -> humo
# ============================================================================
import random as _r


def along(t0, sweep, points, per, u0=0.0, u1=1.0, side=0.0, up=0.0, jitter_u=0.0, jitter_side=0.0,
          seed=1, every=1):
    """Eventos (t, n, u, lado, alto) repartidos a lo largo de la línea.
    t = t0 + sweep*u (el efecto 'corre' del origen al final)."""
    g = _r.Random(seed)
    out = []
    for i in range(0, points, every):
        u = u0 + (u1 - u0) * (i / max(1, points - 1))
        u = min(1.0, max(0.0, u + g.uniform(-jitter_u, jitter_u)))
        out.append((round(t0 + sweep * (u - u0) / max(1e-6, (u1 - u0)), 3), per, round(u, 3),
                    round(side + g.uniform(-jitter_side, jitter_side), 2), up))
    return out


NPTS = 14            # puntos a lo largo de la línea
FUSE_T, FUSE_SWEEP = 0.05, 0.7      # la grieta recorre la línea en 0.7 s
ERUPT_T, ERUPT_SWEEP = 0.95, 0.2    # la erupción encadenada en 0.2 s

FIRELINE_TOON = {
    "name": "FireLineToon",
    "doc": "Línea de fuego (H3): KaijuFireVFX.FireLine(CFrame.lookAt(origen, origen + direccion), largo, escala).",
    "duration": 2.5,
    "line": 90,          # largo por defecto (studs a escala 1)
    "light": {"color": (255, 140, 50), "brightness": 3, "range": 40, "time": 0.6},
    "layers": [
        # ---- FASE A: la grieta incandescente corre por el suelo ----
        {"name": "Crack", "texture": "kz_crack", "orientation": "VelocityPerpendicular",
         "direction": "Top", "speed": (0.01, 0.01),
         "emit": along(FUSE_T, FUSE_SWEEP, NPTS, 1, up=0.15, jitter_side=0.8, seed=2),
         "lifetime": (2.05, 2.15),
         "size": [(0, 2), (0.04, 12, 2), (0.75, 12, 2), (1, 9)],
         "transparency": [(0, 0), (0.7, 0.1), (1, 1)],
         "light_emission": 0.6, "rotation": (0, 360)},
        {"name": "FuseHead", "texture": "kz_star", "emit": along(FUSE_T, FUSE_SWEEP, NPTS, 1, up=1.0, seed=3),
         "lifetime": (0.12, 0.15), "size": [(0, 5), (0.3, 9), (1, 6)],
         "transparency": [(0, 0), (0.6, 0.3), (1, 1)],
         "color": [(0, (255, 230, 160)), (1, (255, 170, 80))],
         "light_emission": 1.0, "brightness": 1.2, "rotation": (0, 360), "zoffset": 2},
        {"name": "FuseSparks", "texture": "kz_streak", "orientation": "VelocityParallel",
         "emit": along(FUSE_T, FUSE_SWEEP, NPTS, 6, up=0.5, seed=4),
         "direction": "Top", "spread": (55, 55), "speed": (30, 60), "drag": 3, "accel": (0, -70, 0),
         "lifetime": (0.25, 0.4), "size": [(0, 5, 1), (1, 1.5)],
         "color": [(0, (255, 240, 180)), (1, (240, 110, 30))], "light_emission": 0.8},
        {"name": "FuseFlames", "texture": "kz_fire_tongue_4x4", "flipbook": ("Grid4x4", "OneShot", 0, False),
         "orientation": "VelocityParallel", "emit": along(FUSE_T, FUSE_SWEEP, NPTS, 2, up=0.3, seed=5),
         "direction": "Top", "spread": (25, 25), "speed": (18, 30), "drag": 3,
         "lifetime": (0.32, 0.45), "size": [(0, 3, 1), (0.3, 8, 2), (1, 6, 1.5)],
         "transparency": [(0, 0), (0.88, 0), (1, 1)], "light_emission": 0.15},
        # ---- FASE B: erupción encadenada a lo largo de toda la línea ----
        {"name": "EruptFlash", "texture": "kz_flash_2x2", "flipbook": ("Grid2x2", "Random", 0, True),
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 1, up=3, every=2, seed=6),
         "lifetime": (0.09, 0.12), "size": [(0, 8), (0.35, 18), (1, 20)],
         "transparency": [(0, 0), (0.65, 0), (1, 1)],
         "light_emission": 0.35, "rotation": (0, 360), "zoffset": 3},
        {"name": "EruptRing", "texture": "kz_ring", "orientation": "VelocityPerpendicular",
         "direction": "Top", "speed": (0.01, 0.01),
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 1, up=0.2, every=3, seed=7),
         "lifetime": (0.3, 0.3), "size": [(0, 3), (0.2, 18), (0.5, 26), (1, 30)],
         "transparency": [(0, 0), (0.5, 0.35), (1, 1)],
         "color": [(0, (255, 214, 140)), (1, (255, 150, 70))], "light_emission": 0.5},
        {"name": "EruptColumn", "texture": "kz_fire_tongue_4x4", "flipbook": ("Grid4x4", "OneShot", 0, False),
         "orientation": "VelocityParallel", "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 4, up=0.5,
                                                          jitter_side=2.0, seed=8),
         "direction": "Top", "spread": (14, 14), "speed": (70, 115), "drag": 4.5,
         "lifetime": (0.45, 0.62), "size": [(0, 7, 3), (0.25, 19, 7), (1, 15, 5)],
         "transparency": [(0, 0), (0.88, 0), (1, 1)], "light_emission": 0.15},
        {"name": "EruptBurst", "texture": "kz_fire_burst_4x4", "flipbook": ("Grid4x4", "OneShot", 0, False),
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 2, up=3, jitter_side=2.5, seed=9),
         "direction": "Top", "spread": (180, 180), "speed": (10, 24), "drag": 4, "accel": (0, 12, 0),
         "lifetime": (0.6, 0.8), "size": [(0, 7, 2), (0.15, 14, 2), (0.6, 17, 3), (1, 16, 3)],
         "transparency": [(0, 0), (0.9, 0), (1, 1)],
         "color": [(0, WHITE), (0.7, (255, 238, 225)), (1, (225, 170, 150))],
         "light_emission": 0.12, "rotation": (0, 360), "rot_speed": (-40, 40)},
        {"name": "EruptDebris", "texture": "kz_debris_2x2", "flipbook": ("Grid2x2", "Random", 0, True),
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 3, up=1, seed=10),
         "direction": "Top", "spread": (45, 45), "speed": (40, 72), "drag": 1.2, "accel": (0, -110, 0),
         "lifetime": (0.7, 0.9), "size": [(0, 1.5, 0.6), (1, 1.3, 0.5)],
         "transparency": [(0, 0), (0.85, 0), (1, 1)],
         "rotation": (0, 360), "rot_speed": (-420, 420), "zoffset": -0.5},
        {"name": "EruptSparks", "texture": "kz_streak", "orientation": "VelocityParallel",
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 5, up=2, seed=11),
         "direction": "Top", "spread": (75, 75), "speed": (70, 130), "drag": 4, "accel": (0, -60, 0),
         "lifetime": (0.25, 0.45), "size": [(0, 9, 2), (1, 2.5)],
         "color": [(0, (255, 240, 180)), (0.5, (255, 170, 60)), (1, (230, 80, 20))],
         "light_emission": 0.8, "brightness": 1.2},
        {"name": "EruptWindR", "texture": "kz_streak", "orientation": "VelocityParallel",
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 1, up=2, every=2, seed=12),
         "direction": "Right", "spread": (20, 10), "speed": (120, 170), "drag": 9,
         "lifetime": (0.16, 0.22), "size": [(0, 9, 2), (1, 14, 2)],
         "transparency": [(0, 0.15), (0.5, 0.4), (1, 1)],
         "color": [(0, (255, 248, 225)), (1, (255, 225, 170))], "light_emission": 0.6},
        {"name": "EruptWindL", "texture": "kz_streak", "orientation": "VelocityParallel",
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 1, up=2, every=2, seed=13),
         "direction": "Left", "spread": (20, 10), "speed": (120, 170), "drag": 9,
         "lifetime": (0.16, 0.22), "size": [(0, 9, 2), (1, 14, 2)],
         "transparency": [(0, 0.15), (0.5, 0.4), (1, 1)],
         "color": [(0, (255, 248, 225)), (1, (255, 225, 170))], "light_emission": 0.6},
        {"name": "Scorch", "texture": "kz_scorch", "orientation": "VelocityPerpendicular",
         "direction": "Top", "speed": (0.01, 0.01),
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 1, up=0.1, jitter_side=1.0, seed=14),
         "lifetime": (1.3, 1.4), "size": [(0, 8, 1), (0.1, 14, 2), (1, 15, 2)],
         "transparency": [(0, 0.2), (0.6, 0.35), (1, 1)], "rotation": (0, 360), "zoffset": -0.2},
        # ---- FASE C: segunda oleada (muro) + humo + brasas; todo se apaga ----
        {"name": "Wall", "texture": "kz_fire_tongue_4x4", "flipbook": ("Grid4x4", "OneShot", 0, False),
         "orientation": "VelocityParallel", "emit": along(ERUPT_T + 0.14, ERUPT_SWEEP, NPTS, 3, up=0.5,
                                                          jitter_side=3.0, seed=15),
         "direction": "Top", "spread": (20, 20), "speed": (40, 70), "drag": 4,
         "lifetime": (0.42, 0.55), "size": [(0, 6, 3), (0.25, 15, 6), (1, 12, 4)],
         "transparency": [(0, 0), (0.88, 0), (1, 1)], "light_emission": 0.15},
        {"name": "Smoke", "texture": "kz_smoke_4x4", "flipbook": ("Grid4x4", "OneShot", 0, False),
         "emit": along(ERUPT_T + 0.3, ERUPT_SWEEP, NPTS, 2, up=6, jitter_side=3.0, seed=16),
         "direction": "Top", "spread": (40, 40), "speed": (14, 26), "drag": 1.6, "accel": (0, 16, 0),
         "lifetime": (0.75, 0.92), "size": [(0, 12, 3), (0.5, 22, 4), (1, 26, 4)],
         "transparency": [(0, 0.25), (0.85, 0.35), (1, 1)],
         "color": [(0, (255, 238, 222)), (1, (220, 212, 206))],
         "rotation": (0, 360), "rot_speed": (-25, 25), "zoffset": -7},
        {"name": "Embers", "texture": "kz_ember", "emit": along(ERUPT_T + 0.2, ERUPT_SWEEP, NPTS, 3, up=4, seed=17),
         "direction": "Top", "spread": (110, 110), "speed": (10, 28), "drag": 2, "accel": (0, 14, 0),
         "lifetime": (0.45, 0.7), "size": [(0, 0.9, 0.3), (1, 0)],
         "transparency": [(0, 0), (0.7, 0.2), (1, 1)],
         "color": [(0, (255, 220, 140)), (1, (255, 110, 40))], "light_emission": 0.9},
    ],
}


# ============================================================================
# VERSIÓN CON TEXTURAS DE INTERNET (Kenney Particle Pack, CC0) — la coreografía es la misma
# ============================================================================
FIRE_CS = [(0, (255, 246, 205)), (0.12, (255, 214, 92)), (0.35, (255, 150, 42)),
           (0.65, (226, 82, 22)), (1, (112, 36, 16))]
JET_CS = [(0, (255, 240, 180)), (0.25, (255, 190, 70)), (0.6, (250, 120, 30)), (1, (180, 50, 18))]
SMOKE_CS = [(0, (112, 98, 90)), (0.5, (128, 118, 112)), (1, (150, 144, 140))]
DUST_CS = [(0, (226, 206, 178)), (1, (205, 192, 176))]


def fire_body(name, tex, emit, lifetime=(0.5, 0.75), speed=(18, 34), sizes=(6, 16, 22, 24), le=0.3,
              bright=1.6, shape_r=2.5, accel_up=10, drag=4.2):
    a, b, c, d = sizes
    return {"name": name, "texture": tex, "emit": emit, "shape": {"type": "Sphere", "radius": shape_r},
            "direction": "Top", "spread": (180, 180), "speed": speed, "drag": drag, "accel": (0, accel_up, 0),
            "lifetime": lifetime,
            "size": [(0, a, a * 0.3), (0.15, b, b * 0.2), (0.6, c, c * 0.15), (1, d, d * 0.15)],
            "transparency": [(0, 0), (0.45, 0.05), (0.8, 0.45), (1, 1)],
            "color": FIRE_CS, "light_emission": le, "brightness": bright,
            "rotation": (0, 360), "rot_speed": (-60, 60)}


def jets(name, tex, emit, speed, spread, lifetime, sizes, drag=6.5, accel=(0, -10, 0), le=0.3, bright=1.7):
    a, b, c = sizes
    return {"name": name, "texture": tex, "orientation": "VelocityParallel", "emit": emit,
            "direction": "Top", "spread": spread, "speed": speed, "drag": drag, "accel": accel,
            "lifetime": lifetime, "size": [(0, a, a * 0.3), (0.2, b, b * 0.25), (1, c, c * 0.25)],
            "transparency": [(0, 0), (0.6, 0.1), (1, 1)], "color": JET_CS,
            "light_emission": le, "brightness": bright}


EXPLOSION = {
    "name": "Explosion",
    "doc": "Explosión de fuego estilo anime (impacto de la H1). Dura 1.3 s y cierra limpio.",
    "duration": 1.3,
    "light": {"color": (255, 150, 60), "brightness": 4, "range": 30, "time": 0.35},
    "layers": [
        {"name": "FlashCore", "texture": "kk_star_06", "emit": [(0.0, 2)],
         "lifetime": (0.1, 0.13), "size": [(0, 10), (0.25, 28), (1, 32)],
         "transparency": [(0, 0), (0.5, 0.35), (1, 1)],
         "color": [(0, (255, 228, 150)), (1, (255, 180, 90))],
         "light_emission": 1.0, "brightness": 1.5, "rotation": (0, 360), "zoffset": 4},
        {"name": "FlashBurst", "texture": "kk_scorch_02", "emit": [(0.0, 2), (0.035, 1)],
         "lifetime": (0.1, 0.14), "size": [(0, 10), (0.35, 26), (1, 30)],
         "transparency": [(0, 0), (0.6, 0.1), (1, 1)],
         "color": [(0, (255, 244, 190)), (1, (255, 170, 60))],
         "light_emission": 0.6, "brightness": 1.8, "rotation": (0, 360), "zoffset": 3},
        {"name": "GroundRing", "texture": "kk_circle_03", "emit": [(0.0, 1)], "offset": (0, -1.9, 0),
         "orientation": "VelocityPerpendicular", "direction": "Top", "speed": (0.01, 0.01),
         "lifetime": (0.34, 0.34), "size": [(0, 4), (0.18, 26), (0.5, 38), (1, 46)],
         "transparency": [(0, 0.0), (0.5, 0.35), (1, 1)],
         "color": [(0, (255, 214, 140)), (1, (255, 150, 70))], "light_emission": 0.5, "brightness": 1.3},
        {"name": "AirRing", "texture": "kk_smoke_10", "emit": [(0.015, 1)],
         "lifetime": (0.26, 0.26), "size": [(0, 8), (0.3, 30), (1, 38)],
         "transparency": [(0, 0.4), (0.5, 0.65), (1, 1)],
         "color": [(0, (255, 214, 160)), (1, (230, 196, 160))], "light_emission": 0.1, "zoffset": 2},
        {"name": "WindArcs", "texture": "kk_twirl_02", "emit": [(0.02, 3)],
         "lifetime": (0.22, 0.28), "size": [(0, 12), (0.4, 32), (1, 40)],
         "transparency": [(0, 0.0), (0.55, 0.3), (1, 1)], "color": [(0, (255, 248, 230)), (1, (255, 230, 190))],
         "light_emission": 0.5, "brightness": 1.4, "rotation": (0, 360), "rot_speed": (-160, 160), "zoffset": 1.5},
        {"name": "WindArcs2", "texture": "kk_twirl_01", "emit": [(0.05, 2)],
         "lifetime": (0.2, 0.26), "size": [(0, 14), (0.4, 36), (1, 44)],
         "transparency": [(0, 0.05), (0.55, 0.35), (1, 1)], "color": [(0, (255, 248, 230)), (1, (255, 230, 190))],
         "light_emission": 0.5, "brightness": 1.4, "rotation": (0, 360), "rot_speed": (-160, 160), "zoffset": 1.5},
        {"name": "WindStreaks", "texture": "kk_trace_01", "orientation": "VelocityParallel",
         "emit": [(0.0, 16)], "direction": "Front", "spread": (180, 8),
         "speed": (130, 190), "drag": 9, "lifetime": (0.16, 0.24), "size": [(0, 12, 3), (1, 18, 3)],
         "transparency": [(0, 0.05), (0.5, 0.35), (1, 1)],
         "color": [(0, (255, 248, 225)), (1, (255, 225, 170))], "light_emission": 0.6, "brightness": 1.5},
        fire_body("FireballA", "kk_fire_01", [(0.0, 7), (0.04, 3)]),
        fire_body("FireballB", "kk_fire_02", [(0.0, 6), (0.05, 3)], sizes=(5, 14, 20, 22)),
        {"name": "FireCore", "texture": "kk_fire_02", "emit": [(0.0, 3)], "lifetime": (0.28, 0.34),
         "speed": (0, 4), "size": [(0, 8, 2), (0.3, 18, 3), (1, 20, 3)],
         "transparency": [(0, 0), (0.6, 0.2), (1, 1)],
         "color": [(0, (255, 250, 220)), (0.4, (255, 220, 110)), (1, (255, 150, 50))],
         "light_emission": 0.5, "brightness": 2.0, "rotation": (0, 360), "rot_speed": (-90, 90), "zoffset": 1},
        jets("FireTongues", "kk_muzzle_04", [(0.01, 10), (0.07, 4)], (50, 90), (110, 110), (0.36, 0.52), (6, 16, 13)),
        jets("FireTongues2", "kk_muzzle_05", [(0.02, 8)], (45, 85), (110, 110), (0.34, 0.5), (5, 14, 11)),
        jets("Column", "kk_muzzle_01", [(0.03, 5)], (60, 95), (14, 14), (0.4, 0.55), (10, 22, 18), drag=5, accel=(0, 0, 0)),
        fire_body("Pops", "kk_fire_01", [(0.1, 3), (0.17, 2)], lifetime=(0.34, 0.44), speed=(4, 10),
                  sizes=(4, 8, 10, 10), shape_r=7.0, accel_up=4, drag=4),
        {"name": "Sparks", "texture": "kk_trace_01", "orientation": "VelocityParallel",
         "emit": [(0.0, 30), (0.06, 16)], "direction": "Top", "spread": (180, 180),
         "speed": (70, 140), "drag": 4, "accel": (0, -60, 0), "lifetime": (0.25, 0.5),
         "size": [(0, 9, 3), (1, 3)],
         "color": [(0, (255, 240, 180)), (0.5, (255, 170, 60)), (1, (230, 80, 20))],
         "light_emission": 0.8, "brightness": 1.8},
        {"name": "Debris", "texture": "kz_debris_2x2", "flipbook": ("Grid2x2", "Random", 0, True),
         "emit": [(0.02, 14)], "direction": "Top", "spread": (70, 70), "speed": (40, 75),
         "drag": 1.2, "accel": (0, -110, 0), "lifetime": (0.7, 0.95),
         "size": [(0, 1.6, 0.7), (1, 1.4, 0.6)], "transparency": [(0, 0), (0.85, 0), (1, 1)],
         "rotation": (0, 360), "rot_speed": (-420, 420), "zoffset": -0.5},
        {"name": "GroundDust", "texture": "kk_smoke_04", "emit": [(0.02, 14)], "offset": (0, -1.2, 0),
         "direction": "Front", "spread": (180, 4), "speed": (55, 95), "drag": 5.5, "accel": (0, 5, 0),
         "lifetime": (0.5, 0.7), "size": [(0, 5, 1), (0.4, 11, 2), (1, 14, 2)],
         "transparency": [(0, 0.3), (0.5, 0.4), (1, 1)], "color": DUST_CS,
         "rotation": (0, 360), "rot_speed": (-60, 60), "zoffset": -0.5},
        {"name": "Smoke", "texture": "kk_smoke_07", "emit": [(0.24, 4), (0.32, 2)],
         "shape": {"type": "Sphere", "radius": 4.0}, "direction": "Top", "spread": (60, 60),
         "speed": (16, 28), "drag": 1.6, "accel": (0, 18, 0), "lifetime": (0.75, 0.92),
         "size": [(0, 14, 3), (0.5, 28, 4), (1, 34, 4)],
         "transparency": [(0, 0.45), (0.25, 0.2), (0.75, 0.45), (1, 1)], "color": SMOKE_CS,
         "rotation": (0, 360), "rot_speed": (-25, 25), "zoffset": -7},
        {"name": "Smoke2", "texture": "kk_smoke_08", "emit": [(0.28, 4)],
         "shape": {"type": "Sphere", "radius": 4.0}, "direction": "Top", "spread": (60, 60),
         "speed": (14, 24), "drag": 1.6, "accel": (0, 16, 0), "lifetime": (0.72, 0.9),
         "size": [(0, 12, 3), (0.5, 26, 4), (1, 32, 4)],
         "transparency": [(0, 0.45), (0.25, 0.2), (0.75, 0.45), (1, 1)], "color": SMOKE_CS,
         "rotation": (0, 360), "rot_speed": (-25, 25), "zoffset": -7},
        {"name": "Embers", "texture": "kk_flare_01", "emit": [(0.12, 18)],
         "shape": {"type": "Sphere", "radius": 4.0}, "direction": "Top", "spread": (120, 120),
         "speed": (10, 30), "drag": 2, "accel": (0, 14, 0), "lifetime": (0.45, 0.7),
         "size": [(0, 2.2, 0.6), (1, 0)], "transparency": [(0, 0), (0.7, 0.2), (1, 1)],
         "color": [(0, (255, 220, 140)), (1, (255, 110, 40))], "light_emission": 1.0, "brightness": 2},
    ],
}

FIRELINE = {
    "name": "FireLine",
    "doc": "Línea de fuego (H3): KaijuFireVFX.FireLine(CFrame.lookAt(origen, origen + direccion), largo, escala).",
    "duration": 2.5,
    "line": 90,
    "light": {"color": (255, 140, 50), "brightness": 3, "range": 40, "time": 0.6},
    "layers": [
        # FASE A: grieta incandescente que corre
        {"name": "CrackA", "texture": "kk_spark_01", "orientation": "VelocityPerpendicular",
         "direction": "Top", "speed": (0.01, 0.01),
         "emit": along(FUSE_T, FUSE_SWEEP, NPTS, 1, up=0.15, jitter_side=0.8, seed=2),
         "lifetime": (2.05, 2.15), "size": [(0, 3), (0.04, 14, 2), (0.75, 14, 2), (1, 11)],
         "transparency": [(0, 0), (0.7, 0.1), (1, 1)],
         "color": [(0, (255, 236, 160)), (0.3, (255, 170, 60)), (1, (220, 70, 20))],
         "light_emission": 0.8, "brightness": 1.8, "rotation": (0, 360)},
        {"name": "CrackB", "texture": "kk_spark_02", "orientation": "VelocityPerpendicular",
         "direction": "Top", "speed": (0.01, 0.01),
         "emit": along(FUSE_T + 0.03, FUSE_SWEEP, NPTS, 1, up=0.12, jitter_side=1.2, jitter_u=0.02, seed=22),
         "lifetime": (2.0, 2.1), "size": [(0, 3), (0.04, 12, 2), (0.75, 12, 2), (1, 9)],
         "transparency": [(0, 0.1), (0.7, 0.2), (1, 1)],
         "color": [(0, (255, 236, 160)), (0.3, (255, 170, 60)), (1, (220, 70, 20))],
         "light_emission": 0.8, "brightness": 1.6, "rotation": (0, 360)},
        {"name": "FuseHead", "texture": "kk_star_06", "emit": along(FUSE_T, FUSE_SWEEP, NPTS, 1, up=1.0, seed=3),
         "lifetime": (0.12, 0.15), "size": [(0, 6), (0.3, 11), (1, 7)],
         "transparency": [(0, 0), (0.6, 0.3), (1, 1)],
         "color": [(0, (255, 230, 160)), (1, (255, 170, 80))],
         "light_emission": 1.0, "brightness": 1.6, "rotation": (0, 360), "zoffset": 2},
        {"name": "FuseSparks", "texture": "kk_trace_01", "orientation": "VelocityParallel",
         "emit": along(FUSE_T, FUSE_SWEEP, NPTS, 6, up=0.5, seed=4),
         "direction": "Top", "spread": (55, 55), "speed": (30, 60), "drag": 3, "accel": (0, -70, 0),
         "lifetime": (0.25, 0.4), "size": [(0, 6, 1.5), (1, 2)],
         "color": [(0, (255, 240, 180)), (1, (240, 110, 30))], "light_emission": 0.8, "brightness": 1.8},
        jets("FuseFlames", "kk_muzzle_05", along(FUSE_T, FUSE_SWEEP, NPTS, 2, up=0.3, seed=5),
             (18, 30), (25, 25), (0.32, 0.45), (3, 8, 6), drag=3, accel=(0, 0, 0)),
        # FASE B: erupción encadenada
        {"name": "EruptFlash", "texture": "kk_scorch_02", "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 1, up=3, every=2, seed=6),
         "lifetime": (0.09, 0.12), "size": [(0, 8), (0.35, 20), (1, 22)],
         "transparency": [(0, 0), (0.6, 0.15), (1, 1)],
         "color": [(0, (255, 240, 180)), (1, (255, 160, 60))],
         "light_emission": 0.6, "brightness": 1.7, "rotation": (0, 360), "zoffset": 3},
        {"name": "EruptRing", "texture": "kk_circle_03", "orientation": "VelocityPerpendicular",
         "direction": "Top", "speed": (0.01, 0.01),
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 1, up=0.2, every=3, seed=7),
         "lifetime": (0.3, 0.3), "size": [(0, 3), (0.2, 18), (0.5, 26), (1, 30)],
         "transparency": [(0, 0), (0.5, 0.35), (1, 1)],
         "color": [(0, (255, 214, 140)), (1, (255, 150, 70))], "light_emission": 0.5, "brightness": 1.3},
        jets("EruptColumn", "kk_muzzle_01", along(ERUPT_T, ERUPT_SWEEP, NPTS, 3, up=0.5, jitter_side=2.0, seed=8),
             (70, 115), (14, 14), (0.45, 0.62), (8, 21, 17), drag=4.5, accel=(0, 0, 0)),
        jets("EruptColumn2", "kk_muzzle_04", along(ERUPT_T + 0.02, ERUPT_SWEEP, NPTS, 2, up=0.5, jitter_side=2.5, seed=18),
             (60, 100), (18, 18), (0.42, 0.58), (7, 18, 15), drag=4.5, accel=(0, 0, 0)),
        fire_body("EruptBurst", "kk_fire_01", along(ERUPT_T, ERUPT_SWEEP, NPTS, 2, up=3, jitter_side=2.5, seed=9),
                  lifetime=(0.55, 0.75), speed=(8, 20), sizes=(7, 15, 19, 20), shape_r=1.5, accel_up=12, drag=4),
        {"name": "EruptDebris", "texture": "kz_debris_2x2", "flipbook": ("Grid2x2", "Random", 0, True),
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 3, up=1, seed=10),
         "direction": "Top", "spread": (45, 45), "speed": (40, 72), "drag": 1.2, "accel": (0, -110, 0),
         "lifetime": (0.7, 0.9), "size": [(0, 1.5, 0.6), (1, 1.3, 0.5)],
         "transparency": [(0, 0), (0.85, 0), (1, 1)],
         "rotation": (0, 360), "rot_speed": (-420, 420), "zoffset": -0.5},
        {"name": "EruptSparks", "texture": "kk_trace_01", "orientation": "VelocityParallel",
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 5, up=2, seed=11),
         "direction": "Top", "spread": (75, 75), "speed": (70, 130), "drag": 4, "accel": (0, -60, 0),
         "lifetime": (0.25, 0.45), "size": [(0, 10, 2), (1, 3)],
         "color": [(0, (255, 240, 180)), (0.5, (255, 170, 60)), (1, (230, 80, 20))],
         "light_emission": 0.8, "brightness": 1.8},
        {"name": "EruptWindR", "texture": "kk_trace_01", "orientation": "VelocityParallel",
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 1, up=2, every=2, seed=12),
         "direction": "Right", "spread": (20, 10), "speed": (120, 170), "drag": 9,
         "lifetime": (0.16, 0.22), "size": [(0, 12, 2), (1, 18, 2)],
         "transparency": [(0, 0.05), (0.5, 0.35), (1, 1)],
         "color": [(0, (255, 248, 225)), (1, (255, 225, 170))], "light_emission": 0.6, "brightness": 1.5},
        {"name": "EruptWindL", "texture": "kk_trace_01", "orientation": "VelocityParallel",
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 1, up=2, every=2, seed=13),
         "direction": "Left", "spread": (20, 10), "speed": (120, 170), "drag": 9,
         "lifetime": (0.16, 0.22), "size": [(0, 12, 2), (1, 18, 2)],
         "transparency": [(0, 0.05), (0.5, 0.35), (1, 1)],
         "color": [(0, (255, 248, 225)), (1, (255, 225, 170))], "light_emission": 0.6, "brightness": 1.5},
        {"name": "Scorch", "texture": "kz_scorch", "orientation": "VelocityPerpendicular",
         "direction": "Top", "speed": (0.01, 0.01),
         "emit": along(ERUPT_T, ERUPT_SWEEP, NPTS, 1, up=0.1, jitter_side=1.0, seed=14),
         "lifetime": (1.3, 1.4), "size": [(0, 8, 1), (0.1, 14, 2), (1, 15, 2)],
         "transparency": [(0, 0.2), (0.6, 0.35), (1, 1)], "rotation": (0, 360), "zoffset": -0.2},
        # FASE C: muro + humo + brasas; todo se apaga
        jets("Wall", "kk_muzzle_03", along(ERUPT_T + 0.14, ERUPT_SWEEP, NPTS, 3, up=0.5, jitter_side=3.0, seed=15),
             (40, 70), (20, 20), (0.42, 0.55), (7, 16, 13), drag=4, accel=(0, 0, 0)),
        {"name": "Smoke", "texture": "kk_smoke_07", "emit": along(ERUPT_T + 0.3, ERUPT_SWEEP, NPTS, 1, up=6, jitter_side=3.0, seed=16),
         "direction": "Top", "spread": (40, 40), "speed": (14, 26), "drag": 1.6, "accel": (0, 16, 0),
         "lifetime": (0.75, 0.92), "size": [(0, 12, 3), (0.5, 24, 4), (1, 30, 4)],
         "transparency": [(0, 0.45), (0.25, 0.2), (0.75, 0.45), (1, 1)], "color": SMOKE_CS,
         "rotation": (0, 360), "rot_speed": (-25, 25), "zoffset": -7},
        {"name": "Smoke2", "texture": "kk_smoke_08", "emit": along(ERUPT_T + 0.36, ERUPT_SWEEP, NPTS, 1, up=6, jitter_side=3.0, seed=19),
         "direction": "Top", "spread": (40, 40), "speed": (12, 22), "drag": 1.6, "accel": (0, 14, 0),
         "lifetime": (0.72, 0.9), "size": [(0, 11, 3), (0.5, 22, 4), (1, 28, 4)],
         "transparency": [(0, 0.45), (0.25, 0.2), (0.75, 0.45), (1, 1)], "color": SMOKE_CS,
         "rotation": (0, 360), "rot_speed": (-25, 25), "zoffset": -7},
        {"name": "Embers", "texture": "kk_flare_01", "emit": along(ERUPT_T + 0.2, ERUPT_SWEEP, NPTS, 3, up=4, seed=17),
         "direction": "Top", "spread": (110, 110), "speed": (10, 28), "drag": 2, "accel": (0, 14, 0),
         "lifetime": (0.45, 0.7), "size": [(0, 2.2, 0.6), (1, 0)],
         "transparency": [(0, 0), (0.7, 0.2), (1, 1)],
         "color": [(0, (255, 220, 140)), (1, (255, 110, 40))], "light_emission": 1.0, "brightness": 2},
    ],
}


# ============================================================================
# VERSIÓN ANIME (duplicado): misma coreografía, texturas cel-shaded con esquirlas
# ============================================================================
import copy as _copy

ANIME_FIRE = [(0, (255, 240, 160)), (0.2, (255, 200, 70)), (0.5, (255, 132, 34)),
              (0.8, (232, 72, 22)), (1, (150, 42, 16))]
ANIME_JET = [(0, (255, 236, 150)), (0.3, (255, 180, 60)), (0.7, (248, 110, 30)), (1, (190, 52, 18))]
ANIME_SMOKE = [(0, (120, 106, 98)), (0.5, (140, 128, 120)), (1, (165, 156, 150))]
OS4 = ("Grid4x4", "OneShot", 0, False)


def animeify(spec, name, overrides, drop=()):
    sp = _copy.deepcopy(spec)
    sp["name"] = name
    sp["doc"] = spec["doc"].replace("estilo anime", "estilo ANIME (cel-shaded)") + " Versión anime."
    layers = []
    for L in sp["layers"]:
        if L["name"] in drop:
            continue
        o = overrides.get(L["name"])
        if o:
            L.update(_copy.deepcopy(o))
            if o.get("flipbook") is None and "flipbook" in o:
                L.pop("flipbook", None)
        layers.append(L)
    sp["layers"] = layers
    return sp


def _fire(tex, le=0.12, bright=1.25, cs=ANIME_FIRE):
    return {"texture": tex, "flipbook": OS4, "color": cs, "light_emission": le, "brightness": bright,
            "transparency": [(0, 0), (0.9, 0), (1, 1)]}


GLOW_FIRE = [(0, (255, 192, 66)), (0.22, (255, 146, 38)), (0.6, (236, 94, 22)), (1, (180, 46, 12))]
BODY_FIRE = [(0, (255, 140, 46)), (0.3, (236, 100, 30)), (0.7, (200, 60, 20)), (1, (120, 32, 12))]


def glow(tex, emit, size, lifetime, le=0.9, bright=1.8, cs=GLOW_FIRE, **kw):
    L = {"texture": tex, "flipbook": OS4, "emit": emit, "size": size, "lifetime": lifetime,
         "color": cs, "light_emission": le, "brightness": bright,
         "transparency": [(0, 0), (0.85, 0.1), (1, 1)], "rotation": (0, 360), "rot_speed": (-90, 90)}
    L.update(kw)
    return L


# Paletas
FX_HOT = [(0, (255, 236, 150)), (0.3, (255, 196, 80)), (0.7, (255, 138, 40)), (1, (220, 74, 20))]
FX_FIRE = [(0, (255, 186, 70)), (0.35, (255, 132, 38)), (0.75, (226, 78, 22)), (1, (150, 40, 14))]
FX_ARC = [(0, (255, 222, 120)), (0.5, (255, 160, 56)), (1, (240, 96, 28))]
FX_SMOKE = [(0, (92, 78, 74)), (0.5, (110, 98, 94)), (1, (132, 124, 120))]
STATIC4x4 = ("Grid4x4", "Random", 0, True)   # frame aleatorio fijo por partícula
STATIC2x2 = ("Grid2x2", "Random", 0, True)

EXPLOSION_ANIME = {
    "name": "ExplosionAnime",
    "doc": "Explosión de fuego estilo ANIME (texturas Effekseer CC0: medias lunas, remolinos, estallido). 1.3 s, cierra limpio.",
    "duration": 1.3,
    "light": {"color": (255, 160, 60), "brightness": 5, "range": 36, "time": 0.45},
    "layers": [
        # ---- 0.00: destello (estrella de picos + cruz + resplandor) ----
        {"name": "FlashBurst", "texture": "fx_burst_a", "emit": [(0.0, 2)], "offset": (0, 4, 0),
         "lifetime": (0.12, 0.15), "size": [(0, 10), (0.3, 34), (1, 40)],
         "transparency": [(0, 0), (0.55, 0.2), (1, 1)], "color": [(0, (255, 240, 170)), (1, (255, 180, 80))],
         "light_emission": 1.0, "brightness": 1.6, "rotation": (0, 360), "zoffset": 6},
        {"name": "FlashStar", "texture": "fx_star", "emit": [(0.0, 1)], "offset": (0, 4, 0),
         "lifetime": (0.16, 0.16), "size": [(0, 20), (0.25, 52), (1, 30)],
         "transparency": [(0, 0), (0.6, 0.3), (1, 1)], "color": [(0, (255, 246, 200)), (1, (255, 200, 110))],
         "light_emission": 1.0, "brightness": 1.5, "rotation": (0, 0), "zoffset": 7},
        {"name": "Glow", "texture": "fx_glow", "emit": [(0.0, 1)], "offset": (0, 5, 0),
         "lifetime": (0.4, 0.4), "size": [(0, 18), (0.15, 40), (1, 46)],
         "transparency": [(0, 0.15), (0.5, 0.55), (1, 1)], "color": [(0, (255, 214, 110)), (1, (255, 130, 40))],
         "light_emission": 1.0, "brightness": 1.0, "zoffset": -2},
        # ---- anillos de choque ----
        {"name": "GroundRing", "texture": "fx_shock_spiky", "emit": [(0.0, 1)], "offset": (0, -1.9, 0),
         "orientation": "VelocityPerpendicular", "direction": "Top", "speed": (0.01, 0.01),
         "lifetime": (0.36, 0.36), "size": [(0, 6), (0.25, 40), (1, 60)],
         "transparency": [(0, 0.05), (0.5, 0.4), (1, 1)], "color": [(0, (255, 214, 120)), (1, (255, 140, 50))],
         "light_emission": 0.7, "brightness": 1.2, "rotation": (0, 360)},
        {"name": "AirRing", "texture": "fx_shock_soft", "emit": [(0.02, 1)], "offset": (0, 5, 0),
         "lifetime": (0.24, 0.24), "size": [(0, 10), (0.4, 44), (1, 54)],
         "transparency": [(0, 0.2), (0.6, 0.6), (1, 1)], "color": [(0, (255, 236, 190)), (1, (255, 190, 110))],
         "light_emission": 0.8, "brightness": 1.0, "zoffset": 3},
        # ---- remolino de viento en la base (giran en sentidos opuestos) ----
        {"name": "WindSwirl", "texture": "fx_wind_lines", "emit": [(0.0, 2), (0.06, 1)], "offset": (0, -1.2, 0),
         "orientation": "VelocityPerpendicular", "direction": "Top", "speed": (0.01, 0.01),
         "lifetime": (0.4, 0.48), "size": [(0, 12, 2), (0.3, 40, 4), (1, 58, 4)],
         "transparency": [(0, 0), (0.6, 0.25), (1, 1)], "color": FX_ARC,
         "light_emission": 0.8, "brightness": 1.3, "rotation": (0, 360), "rot_speed": (-640, -460)},
        {"name": "WindSwirl2", "texture": "fx_wind_swirl", "emit": [(0.03, 2)], "offset": (0, 0.5, 0),
         "orientation": "VelocityPerpendicular", "direction": "Top", "spread": (14, 14), "speed": (0.01, 0.01),
         "lifetime": (0.38, 0.44), "size": [(0, 14, 2), (0.3, 36, 3), (1, 50, 3)],
         "transparency": [(0, 0.05), (0.6, 0.3), (1, 1)], "color": FX_ARC,
         "light_emission": 0.8, "brightness": 1.2, "rotation": (0, 360), "rot_speed": (420, 600)},
        # ---- medias lunas: vórtice plano + medias lunas que salen girando en todas direcciones ----
        {"name": "ArcsFlat", "texture": "fx_feather_4x4", "flipbook": STATIC4x4, "emit": [(0.0, 6), (0.05, 4)],
         "offset": (0, -0.8, 0), "orientation": "VelocityPerpendicular", "direction": "Top", "spread": (18, 18),
         "speed": (0.01, 0.01), "lifetime": (0.36, 0.48), "size": [(0, 12, 3), (0.3, 30, 5), (1, 42, 5)],
         "transparency": [(0, 0), (0.65, 0.1), (1, 1)], "color": FX_ARC,
         "light_emission": 0.7, "brightness": 1.3, "rotation": (0, 360), "rot_speed": (-520, -320)},
        {"name": "ArcsOut", "texture": "fx_feather_4x4", "flipbook": STATIC4x4, "emit": [(0.0, 10), (0.05, 6)],
         "offset": (0, 4, 0), "shape": {"type": "Sphere", "radius": 4.0, "style": "Surface"},
         "direction": "Top", "spread": (180, 180), "speed": (30, 60), "drag": 6,
         "lifetime": (0.3, 0.42), "size": [(0, 8, 2), (0.3, 18, 3), (1, 22, 3)],
         "transparency": [(0, 0), (0.6, 0.1), (1, 1)], "color": FX_ARC,
         "light_emission": 0.6, "brightness": 1.3, "rotation": (0, 360), "rot_speed": (-480, 480), "zoffset": 2},
        # ---- fuego: abanico hacia arriba + llamas que revientan hacia afuera + núcleo esponjoso ----
        {"name": "FireFan", "texture": "fx_burst_fan", "emit": [(0.02, 2)], "offset": (0, 6, 0),
         "lifetime": (0.36, 0.42), "size": [(0, 14), (0.25, 40), (1, 46)],
         "transparency": [(0, 0), (0.6, 0.2), (1, 1)], "color": FX_HOT,
         "light_emission": 0.55, "brightness": 1.3, "rotation": (-12, 12), "zoffset": 0.5},
        {"name": "FlamesOut", "texture": "fx_fire_2x2", "flipbook": STATIC2x2, "orientation": "VelocityParallel",
         "emit": [(0.01, 10), (0.06, 6)], "offset": (0, 3, 0), "shape": {"type": "Sphere", "radius": 3.0, "style": "Surface"},
         "direction": "Top", "spread": (180, 180), "speed": (40, 80), "drag": 6, "accel": (0, 12, 0),
         "lifetime": (0.4, 0.58), "size": [(0, 6, 2), (0.25, 17, 3), (1, 14, 3)],
         "transparency": [(0, 0), (0.6, 0.15), (1, 1)], "color": FX_FIRE,
         "light_emission": 0.35, "brightness": 1.4},
        {"name": "Core", "texture": "fx_smoke_round", "emit": [(0.0, 3)], "offset": (0, 5, 0),
         "shape": {"type": "Sphere", "radius": 2.0}, "direction": "Top", "spread": (180, 180),
         "speed": (2, 6), "drag": 3, "accel": (0, 6, 0), "lifetime": (0.42, 0.52),
         "size": [(0, 10, 2), (0.2, 26, 3), (1, 30, 3)],
         "transparency": [(0, 0), (0.55, 0.15), (1, 1)],
         "color": [(0, (255, 226, 120)), (0.35, (255, 170, 60)), (1, (220, 80, 24))],
         "light_emission": 0.55, "brightness": 1.4, "rotation": (0, 360), "rot_speed": (-60, 60), "zoffset": 1},
        # ---- chispas y rayas ----
        {"name": "Streaks", "texture": "fx_line", "orientation": "VelocityParallel", "offset": (0, 4, 0),
         "emit": [(0.0, 28), (0.05, 14)], "direction": "Top", "spread": (180, 180),
         "speed": (90, 170), "drag": 4.5, "accel": (0, -40, 0), "lifetime": (0.22, 0.4),
         "size": [(0, 14, 4), (1, 5)], "color": [(0, (255, 238, 150)), (0.5, (255, 184, 60)), (1, (255, 110, 24))],
         "light_emission": 1.0, "brightness": 1.5},
        {"name": "CurveStreaks", "texture": "fx_line_curve", "emit": [(0.02, 8)], "offset": (0, 4, 0),
         "shape": {"type": "Sphere", "radius": 6.0, "style": "Surface"}, "direction": "Top", "spread": (180, 180),
         "speed": (20, 40), "drag": 5, "lifetime": (0.2, 0.3), "size": [(0, 10, 2), (1, 16, 2)],
         "transparency": [(0, 0), (0.5, 0.3), (1, 1)], "color": FX_ARC,
         "light_emission": 0.9, "brightness": 1.4, "rotation": (0, 360), "rot_speed": (-300, 300)},
        {"name": "Twinkles", "texture": "fx_spark4", "emit": [(0.08, 14)], "offset": (0, 6, 0),
         "shape": {"type": "Sphere", "radius": 9.0}, "direction": "Top", "spread": (180, 180),
         "speed": (8, 22), "drag": 2, "accel": (0, 8, 0), "lifetime": (0.3, 0.55),
         "size": [(0, 0), (0.15, 3.5, 1), (1, 0)], "color": [(0, (255, 236, 160)), (1, (255, 150, 50))],
         "light_emission": 1.0, "brightness": 1.6, "rotation": (0, 360)},
        {"name": "Debris", "texture": "kz_debris_2x2", "flipbook": ("Grid2x2", "Random", 0, True),
         "emit": [(0.02, 10)], "direction": "Top", "spread": (70, 70), "speed": (40, 75),
         "drag": 1.2, "accel": (0, -110, 0), "lifetime": (0.7, 0.95),
         "size": [(0, 1.6, 0.7), (1, 1.4, 0.6)], "transparency": [(0, 0), (0.85, 0), (1, 1)],
         "rotation": (0, 360), "rot_speed": (-420, 420), "zoffset": -0.5},
        # ---- humo que sube mientras el fuego muere; se desvanece antes de 1.3 s ----
        {"name": "Smoke", "texture": "fx_smoke_2x2", "flipbook": STATIC2x2, "emit": [(0.2, 5), (0.28, 3)],
         "offset": (0, 7, 0), "shape": {"type": "Sphere", "radius": 5.0}, "direction": "Top", "spread": (60, 60),
         "speed": (10, 20), "drag": 1.6, "accel": (0, 14, 0), "lifetime": (0.75, 0.9),
         "size": [(0, 14, 3), (0.5, 26, 4), (1, 32, 4)],
         "transparency": [(0, 0.6), (0.2, 0.15), (0.7, 0.35), (1, 1)], "color": FX_SMOKE,
         "rotation": (0, 360), "rot_speed": (-30, 30), "zoffset": -9},
    ],
}

# ============================================================================
# EXPLOSIÓN GIGANTE (estilo libre: lo mejor de Kenney CC0 + Effekseer CC0)
# Origen = punto del SUELO bajo la explosión. Escala 1 ≈ bola de fuego de ~45 studs.
# ============================================================================
G_FIRE = [(0, (255, 246, 210)), (0.1, (255, 218, 110)), (0.3, (255, 160, 50)),
          (0.55, (240, 104, 30)), (0.8, (190, 60, 22)), (1, (96, 32, 16))]
G_DUST = [(0, (222, 200, 172)), (0.5, (200, 186, 170)), (1, (186, 178, 170))]
G_SMOKE = [(0, (255, 156, 76)), (0.08, (170, 112, 84)), (0.25, (126, 114, 108)),
           (0.65, (150, 144, 140)), (1, (172, 168, 164))]
G_WISP = [(0, (120, 104, 96)), (1, (150, 144, 140))]
G_LICK = [(0, (255, 236, 150)), (0.3, (255, 176, 60)), (0.7, (245, 108, 30)), (1, (180, 50, 18))]


def _with(d, **kw):
    d = dict(d)
    d.update(kw)
    return d


def _fireball(name, tex, emit, life, speed, sizes, offset, shape_r=5.0, accel_up=14, drag=3.6, spread=(180, 180)):
    a, b, c, d = sizes
    return {"name": name, "texture": tex, "emit": emit, "offset": offset,
            "shape": {"type": "Sphere", "radius": shape_r}, "direction": "Top", "spread": spread,
            "speed": speed, "drag": drag, "accel": (0, accel_up, 0), "lifetime": life,
            "size": [(0, a, a * 0.25), (0.15, b, b * 0.18), (0.6, c, c * 0.14), (1, d, d * 0.14)],
            "transparency": [(0, 0), (0.55, 0.05), (0.85, 0.45), (1, 1)], "color": G_FIRE,
            "light_emission": 0.25, "brightness": 1.5, "rotation": (0, 360), "rot_speed": (-50, 50)}


def ground_fire_clusters(n=10, seed=31, t0=0.15, t_end=5.1):
    """Focos de fuego que quedan ardiendo en el suelo y se apagan poco a poco."""
    import random as _rr
    g = _rr.Random(seed)
    layers = []
    for k in range(n):
        if k == 0:          # el cráter: el foco más grande, en el centro
            x, z, sc = 0.0, 0.0, 2.2
        else:
            r = 9 + 24 * g.random() ** 0.5
            a = g.random() * 2 * math.pi
            x, z = math.cos(a) * r, math.sin(a) * r
            sc = 1.1 + 0.8 * g.random()
        tex = "kk_muzzle_04" if k % 2 == 0 else "kk_muzzle_05"
        box = {"type": "Box", "size": (6 * sc, 0.2, 6 * sc)}
        layers += [
            {"name": f"GroundGlow{k}", "decal": True, "texture": "fx_glow", "orientation": "VelocityPerpendicular",
             "emit": [(t0, 1)], "offset": (x, 0.3, z), "direction": "Top", "speed": (0.01, 0.01),
             "lifetime": (t_end - t0 + 0.3, t_end - t0 + 0.3),
             "size": [(0, 0), (0.04, 13 * sc), (0.75, 10 * sc), (1, 0)],
             "transparency": [(0, 0.35), (0.8, 0.55), (1, 1)],
             "color": [(0, (255, 150, 60)), (1, (220, 80, 30))], "light_emission": 0.8, "brightness": 1.2},
            {"name": f"GroundFlames{k}", "texture": "fx_fire_2x2", "flipbook": STATIC2x2,
             "orientation": "VelocityParallel", "offset": (x, 0.6, z), "shape": box, "direction": "Top",
             "spread": (8, 8), "speed": (7 * sc, 13 * sc), "drag": 2, "lifetime": (0.4, 0.62),
             "size": [(0, 4 * sc, sc), (0.3, 11 * sc, 3 * sc), (1, 7 * sc, 2 * sc)],
             "transparency": [(0, 0.05), (0.6, 0.15), (1, 1)], "color": G_LICK,
             "light_emission": 0.35, "brightness": 1.6, "stream": [(t0, 3.2, 14, 5)]},
            {"name": f"GroundFireBase{k}", "texture": "kk_fire_01", "offset": (x, 1.2, z), "shape": box,
             "direction": "Top", "spread": (20, 20), "speed": (2, 5), "drag": 2, "lifetime": (0.35, 0.55),
             "size": [(0, 3 * sc, sc), (0.4, 6 * sc, 1.5 * sc), (1, 4 * sc, sc)],
             "transparency": [(0, 0.1), (0.6, 0.3), (1, 1)], "color": G_FIRE,
             "light_emission": 0.45, "brightness": 1.5, "rotation": (0, 360), "rot_speed": (-60, 60),
             "stream": [(t0, t_end, 9, 0)]},
            {"name": f"GroundFlamesSmall{k}", "texture": tex, "orientation": "VelocityParallel",
             "offset": (x, 0.5, z), "shape": box, "direction": "Top", "spread": (12, 12),
             "speed": (4 * sc, 8 * sc), "drag": 2, "lifetime": (0.35, 0.55),
             "size": [(0, 2 * sc, 0.6 * sc), (0.3, 6 * sc, 1.5 * sc), (1, 4 * sc, sc)],
             "transparency": [(0, 0), (0.6, 0.12), (1, 1)], "color": G_LICK,
             "light_emission": 0.35, "brightness": 1.5, "stream": [(t0, t_end, 6, 0)]},
            {"name": f"GroundSmoke{k}", "texture": "kk_smoke_04", "offset": (x, 3, z), "direction": "Top",
             "spread": (15, 15), "speed": (6, 12), "drag": 1.2, "accel": (0, 6, 0), "lifetime": (1.2, 1.7),
             "size": [(0, 3 * sc, sc), (1, 13 * sc, 3 * sc)], "transparency": [(0, 0.6), (0.3, 0.45), (1, 1)],
             "color": G_WISP, "rotation": (0, 360), "rot_speed": (-30, 30), "zoffset": -2,
             "stream": [(0.3, t_end + 0.1, 3, 1)]},
            {"name": f"GroundEmbers{k}", "texture": "kk_flare_01", "offset": (x, 3, z),
             "shape": {"type": "Box", "size": (6 * sc, 2, 6 * sc)}, "direction": "Top", "spread": (30, 30),
             "speed": (6, 14), "drag": 1.5, "accel": (0, 10, 0), "lifetime": (0.6, 1.0),
             "size": [(0, 0), (0.1, 1.5, 0.4), (1, 0)], "color": [(0, (255, 220, 120)), (1, (255, 110, 30))],
             "light_emission": 1.0, "brightness": 1.6, "stream": [(0.3, t_end - 0.1, 5, 0)]},
        ]
    return layers


GIANT = {
    "name": "GiantExplosion",
    "doc": "Explosión GIGANTE: destello, onda de choque, ola de polvo, bola de fuego, rocas en llamas, hongo de humo y fuego en el suelo 5 s. Cierra limpio a los 5.8 s.",
    "duration": 5.8,
    "light": {"color": (255, 150, 60), "brightness": 6, "range": 60, "time": 1.0},
    "layers": [
        # ---------------- destello ----------------
        {"name": "FlashBurst", "texture": "fx_burst_a", "emit": [(0.0, 2)], "offset": (0, 8, 0),
         "lifetime": (0.1, 0.13), "size": [(0, 16), (0.3, 62), (1, 72)],
         "transparency": [(0, 0), (0.5, 0.25), (1, 1)], "color": [(0, (255, 240, 170)), (1, (255, 170, 70))],
         "light_emission": 1.0, "brightness": 1.4, "rotation": (0, 360), "zoffset": 12},
        {"name": "FlashStar", "texture": "fx_star", "emit": [(0.0, 1)], "offset": (0, 8, 0),
         "lifetime": (0.15, 0.15), "size": [(0, 40), (0.25, 120), (1, 60)],
         "transparency": [(0, 0), (0.6, 0.35), (1, 1)], "color": [(0, (255, 246, 200)), (1, (255, 196, 110))],
         "light_emission": 1.0, "brightness": 1.3, "zoffset": 13},
        {"name": "Glow", "texture": "fx_glow", "emit": [(0.0, 1)], "offset": (0, 12, 0),
         "lifetime": (0.8, 0.8), "size": [(0, 30), (0.12, 84), (1, 100)],
         "transparency": [(0, 0.35), (0.4, 0.65), (1, 1)], "color": [(0, (255, 170, 70)), (1, (230, 90, 30))],
         "light_emission": 0.45, "brightness": 1.0, "zoffset": -12},
        # ---------------- onda de choque ----------------
        {"name": "GroundRing", "decal": True, "texture": "fx_shock_spiky", "emit": [(0.0, 1)], "offset": (0, 0.3, 0),
         "orientation": "VelocityPerpendicular", "direction": "Top", "speed": (0.01, 0.01),
         "lifetime": (0.55, 0.55), "size": [(0, 34), (0.2, 84), (0.6, 142), (1, 160)],
         # en Roblox es un Decal (mezcla normal, no aditiva): más transparente para que se vea como
         # un anillo de luz y no como un plato naranja
         "transparency": [(0, 0.55), (0.35, 0.72), (1, 1)], "color": [(0, (255, 176, 90)), (1, (255, 120, 50))],
         "light_emission": 0.35, "brightness": 1.0, "rotation": (0, 360)},
        {"name": "GroundRing2", "decal": True, "texture": "kk_circle_03", "emit": [(0.06, 1)], "offset": (0, 0.25, 0),
         "orientation": "VelocityPerpendicular", "direction": "Top", "speed": (0.01, 0.01),
         "lifetime": (0.5, 0.5), "size": [(0, 26), (0.25, 70), (1, 126)],
         "transparency": [(0, 0.4), (0.5, 0.7), (1, 1)], "color": [(0, (255, 210, 150)), (1, (255, 180, 120))],
         "light_emission": 0.3, "brightness": 1.0},
        {"name": "DustWave", "texture": "kk_smoke_07", "emit": [(0.02, 38)], "offset": (0, 2.5, 0),
         "direction": "Front", "spread": (180, 3), "speed": (110, 170), "drag": 3.6, "accel": (0, 6, 0),
         "lifetime": (1.1, 1.5), "size": [(0, 9, 2), (0.3, 22, 4), (1, 32, 5)],
         "transparency": [(0, 0.45), (0.15, 0.18), (0.6, 0.4), (1, 1)], "color": G_DUST,
         "rotation": (0, 360), "rot_speed": (-40, 40), "zoffset": -3},
        {"name": "DustWave2", "texture": "kk_smoke_04", "emit": [(0.07, 24)], "offset": (0, 3, 0),
         "direction": "Front", "spread": (180, 5), "speed": (70, 115), "drag": 3, "accel": (0, 8, 0),
         "lifetime": (1.1, 1.45), "size": [(0, 10, 2), (0.35, 24, 4), (1, 34, 5)],
         "transparency": [(0, 0.45), (0.15, 0.22), (0.6, 0.45), (1, 1)], "color": G_DUST,
         "rotation": (0, 360), "rot_speed": (-40, 40), "zoffset": -3},
        {"name": "FireWaveGround", "texture": "kk_muzzle_04", "orientation": "VelocityParallel",
         "emit": [(0.03, 22)], "offset": (0, 2.5, 0), "direction": "Front", "spread": (180, 4),
         "speed": (70, 105), "drag": 4.5, "accel": (0, 10, 0), "lifetime": (0.45, 0.62),
         "size": [(0, 8, 2), (0.3, 18, 3), (1, 12, 2)], "transparency": [(0, 0), (0.6, 0.15), (1, 1)],
         "color": G_LICK, "light_emission": 0.3, "brightness": 1.5},
        {"name": "GroundStreaks", "texture": "fx_line", "orientation": "VelocityParallel",
         "emit": [(0.0, 18)], "offset": (0, 1.5, 0), "direction": "Front", "spread": (180, 2),
         "speed": (190, 270), "drag": 7, "lifetime": (0.18, 0.26), "size": [(0, 18, 4), (1, 28, 4)],
         "transparency": [(0, 0), (0.5, 0.3), (1, 1)], "color": [(0, (255, 240, 200)), (1, (255, 190, 100))],
         "light_emission": 0.8, "brightness": 1.3},
        # ---------------- bola de fuego (más larga y densa) ----------------
        {"name": "FireCore", "texture": "kk_fire_02", "emit": [(0.0, 4), (0.06, 2)], "offset": (0, 9, 0),
         "speed": (0, 6), "direction": "Top", "spread": (180, 180), "lifetime": (0.5, 0.6),
         "size": [(0, 14, 3), (0.3, 38, 4), (1, 42, 4)], "transparency": [(0, 0), (0.6, 0.2), (1, 1)],
         "color": [(0, (255, 248, 214)), (0.3, (255, 214, 110)), (1, (255, 140, 50))],
         "light_emission": 0.5, "brightness": 1.6, "rotation": (0, 360), "rot_speed": (-90, 90), "zoffset": 3},
        _fireball("FireballA", "kk_fire_01", [(0.0, 10), (0.05, 6), (0.1, 4)], (0.85, 1.15), (26, 46),
                  (14, 34, 42, 46), (0, 10, 0)),
        _fireball("FireballB", "kk_fire_02", [(0.0, 8), (0.06, 5), (0.12, 3)], (0.8, 1.1), (22, 42),
                  (13, 32, 40, 44), (0, 10, 0)),
        _fireball("FireRoll", "kk_fire_01", [(0.14, 6), (0.24, 5), (0.34, 4)], (0.8, 1.05), (18, 34),
                  (16, 30, 36, 36), (0, 22, 0), shape_r=10, accel_up=14, drag=2, spread=(30, 30)),
        _with(jets("Jets", "kk_muzzle_04", [(0.01, 14), (0.07, 6)], (70, 120), (110, 110), (0.45, 0.65),
                   (10, 26, 22)), offset=(0, 8, 0)),
        _with(jets("Jets2", "kk_muzzle_05", [(0.02, 10)], (60, 110), (110, 110), (0.42, 0.6), (9, 22, 18)),
              offset=(0, 8, 0)),
        _with(jets("Column", "kk_muzzle_01", [(0.03, 6), (0.12, 3)], (90, 140), (12, 12), (0.5, 0.65),
                   (14, 36, 30), drag=4.5, accel=(0, 0, 0)), offset=(0, 6, 0)),
        {"name": "FlamesOut", "texture": "fx_fire_2x2", "flipbook": STATIC2x2, "orientation": "VelocityParallel",
         "emit": [(0.01, 12), (0.08, 6)], "offset": (0, 8, 0),
         "shape": {"type": "Sphere", "radius": 6.0, "style": "Surface"},
         "direction": "Top", "spread": (180, 180), "speed": (50, 90), "drag": 6, "accel": (0, 14, 0),
         "lifetime": (0.5, 0.7), "size": [(0, 8, 2), (0.25, 22, 4), (1, 18, 3)],
         "transparency": [(0, 0), (0.6, 0.15), (1, 1)], "color": G_FIRE, "light_emission": 0.3, "brightness": 1.4},
        _with(_fireball("Pops", "kk_fire_01", [(0.12, 4), (0.22, 4), (0.32, 3), (0.45, 2)], (0.36, 0.5),
                        (4, 12), (6, 13, 16, 16), (0, 14, 0), shape_r=17, accel_up=6, drag=4),
              shape={"type": "Sphere", "radius": 17.0, "style": "Surface"}),
        # ---------------- hongo de humo (iluminado por el fuego al nacer) ----------------
        {"name": "SmokeCap", "texture": "kk_smoke_07", "emit": [(0.5, 6), (0.62, 5), (0.75, 4)],
         "offset": (0, 40, 0), "shape": {"type": "Sphere", "radius": 13.0}, "direction": "Top", "spread": (70, 70),
         "speed": (10, 22), "drag": 1.2, "accel": (0, 8, 0), "lifetime": (1.8, 2.3),
         "size": [(0, 24, 4), (0.4, 44, 6), (1, 58, 6)],
         "transparency": [(0, 0.55), (0.1, 0.3), (0.55, 0.48), (1, 1)], "color": G_SMOKE,
         "rotation": (0, 360), "rot_speed": (-20, 20), "zoffset": -12},
        {"name": "SmokeCap2", "texture": "kk_smoke_08", "emit": [(0.56, 5), (0.7, 4)],
         "offset": (0, 36, 0), "shape": {"type": "Sphere", "radius": 13.0}, "direction": "Top", "spread": (70, 70),
         "speed": (10, 20), "drag": 1.2, "accel": (0, 8, 0), "lifetime": (1.7, 2.2),
         "size": [(0, 22, 4), (0.4, 42, 6), (1, 54, 6)],
         "transparency": [(0, 0.55), (0.1, 0.32), (0.55, 0.5), (1, 1)], "color": G_SMOKE,
         "rotation": (0, 360), "rot_speed": (-20, 20), "zoffset": -12},
        {"name": "CapRing", "texture": "kk_smoke_07", "emit": [(0.6, 10), (0.72, 6)], "offset": (0, 46, 0),
         "direction": "Front", "spread": (180, 12), "speed": (26, 42), "drag": 1.5, "accel": (0, 7, 0),
         "lifetime": (1.6, 2.0), "size": [(0, 18, 4), (0.4, 34, 5), (1, 44, 5)],
         "transparency": [(0, 0.6), (0.12, 0.35), (0.55, 0.5), (1, 1)], "color": G_SMOKE,
         "rotation": (0, 360), "rot_speed": (-25, 25), "zoffset": -13},
        {"name": "SmokeStem", "texture": "kk_smoke_04", "emit": [(0.5, 4), (0.62, 4)], "offset": (0, 14, 0),
         "shape": {"type": "Box", "size": (10, 24, 10)}, "direction": "Top", "spread": (20, 20),
         "speed": (10, 20), "drag": 1.2, "accel": (0, 8, 0), "lifetime": (1.4, 1.8),
         "size": [(0, 14, 3), (0.5, 24, 4), (1, 30, 4)],
         "transparency": [(0, 0.55), (0.2, 0.28), (0.7, 0.45), (1, 1)], "color": G_SMOKE,
         "rotation": (0, 360), "rot_speed": (-25, 25), "zoffset": -11},
        # ---------------- rocas en llamas: estela + fuego residual al caer ----------------
        {"name": "Meteors", "type": "meteor", "emit": [(0.02, 10)], "offset": (0, 4, 0),
         "direction": "Top", "spread": (62, 62), "speed": (70, 115), "accel": (0, -120, 0), "drag": 0.2,
         "lifetime": (1.4, 1.8),
         "sprite": {"texture": "kz_debris_2x2", "layout": "Grid2x2", "size": (2.4, 3.6), "rot_speed": (-500, 500),
                    "color": (95, 78, 70)},
         "trails": [
             {"name": "MeteorSmoke", "rate": 40, "texture": "kk_smoke_04", "speed": (1, 4), "direction": "Top",
              "spread": (180, 180), "drag": 2, "accel": (0, 6, 0), "lifetime": (0.55, 0.85),
              "size": [(0, 3, 0.8), (1, 9, 2)], "transparency": [(0, 0.3), (0.6, 0.5), (1, 1)],
              "color": [(0, (255, 170, 80)), (0.2, (100, 88, 82)), (1, (140, 134, 130))], "rotation": (0, 360)},
             {"name": "MeteorFire", "rate": 55, "texture": "kk_fire_01", "speed": (0, 2), "direction": "Top",
              "spread": (180, 180), "lifetime": (0.16, 0.26), "size": [(0, 6, 1.2), (1, 1.5)],
              "color": G_FIRE, "light_emission": 0.5, "brightness": 1.6, "rotation": (0, 360)},
         ],
         "land": [
             {"name": "MeteorDust", "emit": [(0, 5)], "texture": "kk_smoke_04", "direction": "Top",
              "spread": (75, 75), "speed": (8, 18), "drag": 3, "accel": (0, 4, 0), "lifetime": (0.6, 0.9),
              "size": [(0, 3, 1), (0.4, 8, 1.5), (1, 10, 1.5)], "transparency": [(0, 0.35), (0.6, 0.5), (1, 1)],
              "color": G_DUST, "rotation": (0, 360)},
             {"name": "MeteorBurn", "texture": "kk_muzzle_05", "orientation": "VelocityParallel",
              "direction": "Top", "spread": (10, 10), "speed": (4, 9), "drag": 2, "lifetime": (0.35, 0.55),
              "size": [(0, 1.5, 0.5), (0.3, 5, 1), (1, 3, 0.8)], "transparency": [(0, 0), (0.6, 0.12), (1, 1)],
              "color": G_LICK, "light_emission": 0.35, "brightness": 1.5, "stream": [(0, 2.6, 12, 0)]},
             {"name": "MeteorWisp", "texture": "kk_smoke_04", "direction": "Top", "spread": (15, 15),
              "speed": (5, 10), "drag": 1.2, "accel": (0, 5, 0), "lifetime": (1.0, 1.4),
              "size": [(0, 2, 0.6), (1, 8, 2)], "transparency": [(0, 0.6), (0.3, 0.5), (1, 1)],
              "color": G_WISP, "rotation": (0, 360), "stream": [(0.1, 2.8, 3, 0.5)]},
         ]},
        # ---------------- chispas, brasas, destellos ----------------
        {"name": "Streaks", "texture": "fx_line", "orientation": "VelocityParallel", "offset": (0, 8, 0),
         "emit": [(0.0, 36), (0.06, 18)], "direction": "Top", "spread": (180, 180),
         "speed": (120, 220), "drag": 4, "accel": (0, -50, 0), "lifetime": (0.3, 0.55),
         "size": [(0, 20, 5), (1, 6)], "color": [(0, (255, 238, 150)), (0.5, (255, 184, 60)), (1, (255, 110, 24))],
         "light_emission": 1.0, "brightness": 1.5},
        {"name": "Embers", "texture": "kk_flare_01", "emit": [(0.15, 22), (0.35, 14), (0.6, 10)],
         "offset": (0, 14, 0), "shape": {"type": "Sphere", "radius": 14.0}, "direction": "Top",
         "spread": (120, 120), "speed": (10, 30), "drag": 1.6, "accel": (0, 16, 0), "lifetime": (0.8, 1.2),
         "size": [(0, 0), (0.1, 2.8, 0.8), (1, 0)], "color": [(0, (255, 220, 120)), (1, (255, 110, 30))],
         "light_emission": 1.0, "brightness": 1.6},
        {"name": "Twinkles", "texture": "fx_spark4", "emit": [(0.1, 14)], "offset": (0, 12, 0),
         "shape": {"type": "Sphere", "radius": 18.0}, "direction": "Top", "spread": (180, 180),
         "speed": (6, 18), "drag": 2, "accel": (0, 8, 0), "lifetime": (0.35, 0.6),
         "size": [(0, 0), (0.15, 5, 1.5), (1, 0)], "color": [(0, (255, 236, 160)), (1, (255, 150, 50))],
         "light_emission": 1.0, "brightness": 1.6, "rotation": (0, 360)},
        # ---------------- suelo: quemadura que dura lo mismo que el fuego ----------------
        {"name": "Scorch", "decal": True, "texture": "kz_scorch", "orientation": "VelocityPerpendicular",
         "emit": [(0.02, 1)], "offset": (0, 0.15, 0), "direction": "Top", "speed": (0.01, 0.01), "lifetime": (5.6, 5.6),
         "size": [(0, 10), (0.03, 52), (1, 54)], "transparency": [(0, 0.12), (0.8, 0.25), (1, 1)],
         "rotation": (0, 360), "zoffset": -1},
    ] + ground_fire_clusters(),
}

# ============================================================================
# H1 IGNITION: la misma explosión gigante, 1.5 veces más grande, 1.5 veces más intensa y carmesí
# ============================================================================
_G_MAP = [(0, 0), (32, 8), (60, 12), (104, 24), (160, 60), (218, 136), (246, 236), (255, 250)]
_NEUTRAL = ("Dust", "Smoke", "Wisp", "Stem", "CapRing", "Scorch", "Ash")     # humo y polvo: no son fuego
_TRAILS = {   # las rocas que salen volando también arden en carmesí (igual que en la H3 Ignition)
    "MeteorFire": [(0, (255, 236, 236)), (0.3, (255, 92, 104)), (1, (190, 24, 40))],
    "MeteorSmoke": [(0, (210, 44, 56)), (0.2, (78, 58, 62)), (1, (118, 110, 114))],
}


def _interp(x, table):
    for (x0, y0), (x1, y1) in zip(table, table[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / max(x1 - x0, 1e-6)
    return table[-1][1]


def crimson(c, neutral=False, g_map=None):
    """Color de fuego naranja -> carmesí (lo más claro queda blanco-rosado). En humo y polvo
    (neutral) solo oscurece con un toque rojizo, salvo el brillo de fuego al nacer.
    g_map: curva del verde (por defecto _G_MAP); una que sube antes deja más blancos los tonos calientes."""
    r, g, b = c
    if neutral and (max(c) - min(c)) / max(max(c), 1) < 0.4:
        return (min(255, round(r * 0.72 + 4)), round(g * 0.68), round(b * 0.70))
    g2 = _interp(g, g_map or _G_MAP)
    b2 = min(255.0, g2 + 20 * (1 - g2 / 255))
    return (round(r * (0.6 + 0.4 * r / 255)), round(g2), round(b2))


def ignitionize(spec, name, size_k=1.5, k=1.5, doc="", le_k=1.0, decal_le_k=1.0, g_map=None, bright_k=1.0,
                overrides=None):
    """Versión Ignition de una explosión: colores carmesí, tamaño ×size_k (vía escala interna) e
    intensidad ×k: más partículas en cada ráfaga, emisión continua más densa, más rocas, luz y
    sacudida más fuertes. Los tiempos no cambian.
    le_k: multiplica el LightEmission de las partículas semi-aditivas (0 < LE < 1): el rojo de la lava
    no se lava a rosa sobre un cielo claro. decal_le_k: lo mismo en los Decals (su brillo en el suelo).
    g_map: curva del verde para el carmesí (ver crimson). bright_k: multiplica el Brightness de las partículas.
    overrides: {nombre de capa: secuencia de color} para capas que llevan su propio color en la Ignition."""
    out = _copy.deepcopy(spec)
    out["name"] = name
    out["doc"] = doc or out.get("doc", "")
    out["scale_mult"] = size_k

    def fix(L):
        nm = L["name"]
        le = L.get("light_emission", 0.0)
        if L.get("decal") and le > 0:
            L["light_emission"] = round(le * decal_le_k, 3)
        elif 0 < le < 1:
            L["light_emission"] = round(le * le_k, 3)
        if not L.get("decal") and bright_k != 1 and "brightness" in L:
            L["brightness"] = round(L["brightness"] * bright_k, 3)
        if overrides and nm in overrides:
            L["color"] = overrides[nm]
        elif nm in _TRAILS:
            L["color"] = _TRAILS[nm]
        elif "color" in L:
            neutral = any(w in nm for w in _NEUTRAL)
            L["color"] = [(t, crimson(c, neutral, g_map)) for t, c in L["color"]]
            if L.get("decal") and not neutral:      # en el suelo: rojo profundo y algo más sutil (no un plato rosado)
                L["color"] = [(t, (round(r * 0.85), round(g * 0.5), round(b * 0.55))) for t, (r, g, b) in L["color"]]
                L["transparency"] = [(t, v if v >= 1 else min(0.95, round(v + 0.1, 3))) + tuple(e)
                                     for (t, v, *e) in L.get("transparency", [(0, 0), (1, 0)])]
        # más partículas por ráfaga; el destello y el resplandor no se duplican (se quemarían a blanco)
        if not L.get("decal") and not nm.startswith(("Flash", "Glow")):
            L["emit"] = [(e[0], e[1] if e[1] == 1 else round(e[1] * k)) + tuple(e[2:]) for e in L.get("emit", [])]
            if L.get("points"):
                L["points"] = [(e[0], e[1] if e[1] == 1 else round(e[1] * k)) + tuple(e[2:]) for e in L["points"]]
        sp = L.get("sprite")
        if sp:      # rocas fundidas: costra más roja y resplandor carmesí (vista previa)
            sp["color"] = crimson(sp["color"], neutral=True)
            if sp.get("glow"):
                sp["glow"] = dict(sp["glow"], color=crimson(sp["glow"]["color"], g_map=g_map))
        if L.get("stream"):
            L["stream"] = [(a, b, round(r0 * k, 2), round(r1 * k, 2)) for a, b, r0, r1 in L["stream"]]
        for sub in L.get("trails", []) + L.get("land", []):
            fix(sub)

    for L in out["layers"]:
        fix(L)
        # con 1.5 veces más chispas, las rayas gruesas parecen pétalos: aquí van rayas finas
        if L["name"] in ("Streaks", "GroundStreaks") and L["texture"] == "fx_line":
            L["texture"] = "kk_trace_01"
            L["size"] = [(t, round(v * 1.6, 2)) + tuple(round(x * 1.6, 2) for x in e) for (t, v, *e) in L["size"]]
    out["light"] = dict(out["light"], color=(255, 60, 90), brightness=round(out["light"]["brightness"] * k, 2))
    out["shakes"] = [(0.0, k, 1.1)]
    return out


# la H1 ahora es la explosión de LAVA (vfx_lava.py); la anterior se conserva como GiantExplosionClassic
import vfx_lava as _VL

GIANT_CLASSIC = dict(GIANT, name="GiantExplosionClassic",
                     doc="La explosión gigante anterior (fuego, estilo detonación), por si quieres volver a ella. " + GIANT["doc"])
# misma iluminación que la normal (el naranja pasa a rojo, no se apaga): los tonos más calientes se van a
# blanco, el brillo sube un poco y el núcleo de magma nace blanco
_G_MAP_HOT = [(0, 0), (32, 8), (60, 12), (104, 30), (150, 70), (180, 120), (205, 175), (225, 215), (255, 250)]
GIANT_IGNITION = ignitionize(
    _VL.LAVA_EXPLOSION, "GiantExplosionIgnition", g_map=_G_MAP_HOT, bright_k=1.3, overrides=_VL.IGNITION_CORE,
    doc="H1 IGNITION: la explosión de lava en carmesí, 1.5 veces más grande y más intensa (más magma, "
        "más rocas fundidas, luz y sacudida más fuertes); la lava carmesí queda viva en el suelo 5 s.")

import vfx_pillars as _VP

SPECS = {"GiantExplosion": _VL.LAVA_EXPLOSION, "GiantExplosionIgnition": GIANT_IGNITION,
         "GiantExplosionClassic": GIANT_CLASSIC,
         "H3_Detonation": _VP.H3_N, "H3_DetonationIgnition": _VP.H3_I,
         "Explosion": EXPLOSION, "ExplosionAnime": EXPLOSION_ANIME, "FireLine": FIRELINE}

# la ULTIMATE: el rayo carmesí (vfx_beam.py)
import vfx_beam as _VB

SPECS["UltimateBeam"] = _VB.ULTIMATE_BEAM
