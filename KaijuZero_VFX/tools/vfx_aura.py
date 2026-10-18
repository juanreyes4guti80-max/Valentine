"""AURAS que se adaptan a cualquier modelo: Omnívora (cósmica) y Kaiju Zero (carmesí). Las dos salen de la misma
receta (la de Omnívora): un delineado de todo el cuerpo que respira y lenguas de energía que emanan de toda la
silueta y suben, con estrellas, chispas y anillos a los pies. La de Kaiju Zero cambia los colores (rojo carmesí,
naranja intenso, blanco y un poco de negro) y suma detallitos de fuego: llamitas, brasas y algo de humo oscuro.
Capas: aura = "surface" (sale de cada parte del cuerpo, repartida según su área), "body" (caja del tamaño del modelo:
box = proporción de esa caja) o "feet" (disco en el suelo bajo sus pies: radius_k = radio / ancho del modelo).
rate = partículas por segundo para todo el modelo; surge = partículas de golpe en cada oleada. Los tamaños son para
un modelo de `ref` studs de alto (crecen con el alto real)."""
from vfx_omnivora import (BOLT, DEEPB, ENERGY, MOUTH, NEBW, RINGC, STAR, STATIC2x2, STREAK)

DECAL_FLAT = dict(orientation="VelocityPerpendicular", direction="Top", speed=(0.01, 0.01))
UP = "FacingCameraWorldUp"


def twinkle(k):
    return [(t, round(v * k, 3)) for t, v in [(0, 0), (0.08, 3.2), (0.22, 1.4), (0.38, 3.4), (0.55, 1.2),
                                              (0.72, 2.8), (1, 0)]]


def layers(P, fire=False):
    """La receta del aura con la paleta P. fire = los detallitos de fuego de Kaiju Zero."""
    L = [
        # ---------------- lo que emana de toda la silueta ----------------
        # lenguas de nebulosa (la textura trae su color): el cuerpo del aura
        dict(name="AuraWisps", aura="surface", texture=P["wisp"], flipbook=STATIC2x2, orientation=UP,
             direction="Top", spread=(35, 35), speed=(2, 5), drag=1, accel=(0, 9, 0), lifetime=(0.8, 1.3),
             size=[(0, 2.5, 0.6), (0.3, 6, 1.2), (1, 8, 1.5)], transparency=[(0, 1), (0.2, 0.35), (0.7, 0.5), (1, 1)],
             color=NEBW, light_emission=P["wisp_le"], brightness=1.1, rotation=(-10, 10), rate=60, surge=25),
        # lenguas grandes y más transparentes: sobresalen de la silueta
        dict(name="AuraWispsOut", aura="surface", texture=P["wisp"], flipbook=STATIC2x2,
             orientation=UP, direction="Top", spread=(20, 20), speed=(2, 5), drag=1, accel=(0, 9, 0),
             lifetime=(0.8, 1.3), size=[(0, 4, 1), (0.3, 9, 2), (1, 12, 2)],
             transparency=[(0, 1), (0.25, 0.5), (0.7, 0.62), (1, 1)], color=NEBW, light_emission=P["wisp_le"],
             brightness=1.1, rotation=(-10, 10), zoffset=-2, rate=16, surge=8),
        # lenguas finas de energía que suben
        dict(name="AuraTongues", aura="surface", texture="fx_aura_tongue_2x2", flipbook=STATIC2x2, orientation=UP,
             direction="Top", spread=(20, 20), speed=(2, 4), drag=1, accel=(0, 10, 0), lifetime=(0.45, 0.7),
             size=[(0, 3, 0.6), (0.4, 6, 1.2), (1, 7, 1.4)], transparency=[(0, 1), (0.15, 0.3), (0.7, 0.45), (1, 1)],
             color=P["tongue"], light_emission=1.0, brightness=1.3, rotation=(-10, 10), rate=45, surge=20),
        dict(name="AuraTongues2", aura="surface", texture="fx_aura_tongue_2x2", flipbook=STATIC2x2, orientation=UP,
             direction="Top", spread=(20, 20), speed=(2, 4), drag=1, accel=(0, 10, 0), lifetime=(0.45, 0.7),
             size=[(0, 2.6, 0.5), (0.4, 5.0, 1.0), (1, 6.0, 1.2)], transparency=[(0, 1), (0.15, 0.35), (0.7, 0.5), (1, 1)],
             color=P["tongue2"], light_emission=1.0, brightness=1.35, rotation=(-10, 10), rate=20, surge=10),
        # estrellas (en Kaiju Zero, brasas) y motas de luz
        dict(name="AuraStars", aura="surface", texture="fx_spark002", direction="Top", spread=(60, 60),
             speed=(1, 3), drag=1, accel=(0, P["star_up"], 0), lifetime=(0.8, 1.4), size=twinkle(0.3),
             color=P["star"], light_emission=1.0, brightness=1.8, rotation=(0, 45), rate=40, surge=25),
        dict(name="AuraMotes", aura="surface", texture="fx_particle02", direction="Top", spread=(60, 60),
             speed=(1, 4), drag=1.5, accel=(0, 6, 0), lifetime=(0.5, 0.9),
             size=[(0, 0), (0.15, 0.32, 0.1), (0.8, 0.24), (1, 0)], color=P["mote"], light_emission=1.0,
             brightness=1.6, rate=30),
        # chispas eléctricas cortas sobre el cuerpo
        dict(name="AuraBolts", aura="surface", texture="kk_spark_05", lifetime=(0.07, 0.1),
             size=[(0, 2.0, 0.6), (1, 2.6, 0.6)], color=P["bolt"], light_emission=1.0, brightness=1.4,
             rotation=(0, 360), rate=6, surge=8),
        # ---------------- alrededor de todo el cuerpo ----------------
        # resplandor suave detrás de la silueta
        dict(name="AuraHalo", aura="body", box=(0.8, 0.8, 0.8), texture="fx_glow", lifetime=(0.6, 0.9),
             size=[(0, 15, 2), (1, 18, 2)], transparency=[(0, 1), (0.3, 0.8), (0.7, 0.84), (1, 1)],
             color=P["halo"], light_emission=1.0, brightness=1.0, zoffset=-3, rate=6),
        # estelas que salen disparadas hacia arriba
        dict(name="AuraStreaks", aura="body", box=(1.05, 0.8, 1.05), texture="kk_trace_03",
             orientation="VelocityParallel", direction="Top", spread=(5, 5), speed=(18, 28), lifetime=(0.25, 0.4),
             size=[(0, 0.5), (0.3, 3.0), (1, 0.6)], color=P["streak"], light_emission=1.0, brightness=1.2,
             rate=14, surge=16),
        # ---------------- a los pies ----------------
        dict(name="FeetRings", aura="feet", radius_k=0.05, texture="kk_circle_02", offset=(0, 0.25, 0),
             lifetime=(1.0, 1.2), size=[(0, 8), (1, 20)], transparency=[(0, 0.45), (0.6, 0.7), (1, 1)],
             color=P["ring"], light_emission=1.0, brightness=1.1, rate=1.6, surge=1, **DECAL_FLAT),
        dict(name="FeetGlow", aura="feet", radius_k=0.05, texture="fx_glow", offset=(0, 0.15, 0),
             lifetime=(0.6, 0.8), size=[(0, 22), (1, 25)], transparency=[(0, 1), (0.3, 0.65), (0.7, 0.7), (1, 1)],
             color=P["halo"], light_emission=1.0, brightness=1.0, rate=4, **DECAL_FLAT),
        dict(name="FeetRise", aura="feet", radius_k=0.6, texture="fx_spark002", offset=(0, 0.3, 0),
             direction="Top", spread=(10, 10), speed=(6, 12), drag=0.5, lifetime=(0.6, 1.0), size=twinkle(0.25),
             color=P["star"], light_emission=1.0, brightness=1.7, rotation=(0, 45), rate=25, surge=15),
        dict(name="FeetTongues", aura="feet", radius_k=0.55, texture="fx_aura_tongue_2x2", flipbook=STATIC2x2,
             orientation=UP, offset=(0, 0.5, 0), direction="Top", speed=(2, 4), accel=(0, 8, 0), lifetime=(0.4, 0.6),
             size=[(0, 3), (0.4, 6), (1, 7)], transparency=[(0, 1), (0.2, 0.35), (0.7, 0.5), (1, 1)],
             color=P["tongue"], light_emission=1.0, brightness=1.3, rotation=(-8, 8), rate=18, surge=8),
    ]
    if fire:
        L += [
            # llamitas sobre el cuerpo
            dict(name="AuraFlames", aura="surface", texture="kk_fire_01", orientation=UP, direction="Top",
                 spread=(15, 15), speed=(2, 4), drag=1, accel=(0, 9, 0), lifetime=(0.35, 0.55),
                 size=[(0, 1.0, 0.3), (0.3, 2.2, 0.5), (1, 0.6)], transparency=[(0, 0.6), (0.2, 0.2), (0.7, 0.4), (1, 1)],
                 color=[(0, (255, 240, 200)), (0.25, (255, 160, 50)), (0.6, (230, 40, 30)), (1, (90, 0, 10))],
                 light_emission=1.0, brightness=1.4, rotation=(-15, 15), rate=30, surge=12),
            # un poco de humo oscuro que sube (el negro)
            dict(name="AuraSmoke", aura="surface", texture="kk_smoke_07", direction="Top", spread=(25, 25),
                 speed=(1, 3), drag=1, accel=(0, 6, 0), lifetime=(0.8, 1.2), size=[(0, 1.5, 0.4), (1, 4.5, 1)],
                 transparency=[(0, 1), (0.25, 0.7), (0.7, 0.8), (1, 1)],
                 color=[(0, (40, 6, 8)), (1, (14, 6, 8))], light_emission=0, rotation=(0, 360), rot_speed=(-30, 30),
                 zoffset=-1, rate=10),
        ]
    return L


COSMIC = {"wisp": "om_aura_wisp_2x2", "wisp_le": 0.5, "tongue": ENERGY, "tongue2": MOUTH, "star": STAR,
          "star_up": 4, "mote": [(0, (255, 255, 255)), (1, (150, 200, 255))], "bolt": BOLT, "halo": DEEPB,
          "streak": STREAK, "ring": RINGC}
CRIMSON = {"wisp": "kz_aura_wisp_2x2", "wisp_le": 0.68,
           "tongue": [(0, (255, 210, 120)), (0.35, (255, 130, 35)), (1, (220, 25, 35))],
           "tongue2": [(0, (255, 90, 80)), (0.4, (220, 20, 40)), (1, (110, 0, 15))],
           "star": [(0, (255, 255, 240)), (0.4, (255, 190, 90)), (1, (240, 60, 30))], "star_up": 9,
           "mote": [(0, (255, 240, 210)), (1, (255, 120, 40))],
           "bolt": [(0, (255, 245, 230)), (0.5, (255, 140, 60)), (1, (230, 30, 30))],
           "halo": [(0, (220, 30, 30)), (0.5, (150, 10, 20)), (1, (70, 0, 10))],
           "streak": [(0, (255, 235, 200)), (0.5, (255, 120, 40)), (1, (210, 20, 30))],
           "ring": [(0, (255, 190, 110)), (0.5, (255, 70, 40)), (1, (170, 10, 20))]}


def aura_cfg(outline, fill, light):
    return {"ref": 22, "fade_in": 0.6, "fade_out": 0.7, "surge": 2.2, "pulse_hz": 0.8, "max_parts": 30,
            "outline": outline, "outline_t": (0.0, 0.35), "fill": fill, "fill_t": (0.74, 0.88),
            "light_color": light, "light_brightness": 2.5, "light_range": 26}


COSMIC_AURA = {
    "name": "CosmicAura",
    "doc": ("OMNÍVORA: AURA CÓSMICA que se adapta a cualquier modelo. Delinea todo su cuerpo (celeste que respira hacia "
            "el púrpura) y de toda su silueta emanan lenguas de nebulosa azul muy oscura con venas celestes, energía "
            "celeste y púrpura, estrellas y chispas; a los pies, anillos que se abren y destellos que suben. Cada "
            "2.2 s, una oleada."),
    "duration": 0,
    "aura": aura_cfg([(90, 170, 255), (200, 120, 255)], (20, 40, 140), (90, 150, 255)),
    "layers": layers(COSMIC),
}

CRIMSON_AURA = {
    "name": "CrimsonAura",
    "doc": ("KAIJU ZERO: AURA CARMESÍ que se adapta a cualquier modelo (la misma receta que el aura de Omnívora). "
            "Delinea todo su cuerpo (carmesí que respira hacia el naranja) y de toda su silueta emanan lenguas de "
            "energía carmesí y naranja con chispas al rojo blanco, llamitas, brasas y algo de humo oscuro; a los pies, "
            "anillos y brasas que suben. Cada 2.2 s, una oleada."),
    "duration": 0,
    "aura": aura_cfg([(255, 40, 50), (255, 150, 40)], (120, 0, 12), (255, 60, 40)),
    "layers": layers(CRIMSON, fire=True),
}
