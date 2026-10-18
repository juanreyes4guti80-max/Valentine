"""OMNÍVORA — AGUJERO NEGRO (habilidad que golpea a dos enemigos a la vez en el combate por turnos).

Un agujero negro se materializa frente a la boca de Omnívora, avanza creciendo hacia los enemigos y detona
en medio de ellos: la explosión los cubre a los dos. Misma filosofía y colores que el Pilar cósmico (azul
muy oscuro que se aclara a celeste, destellos blancos y el púrpura de su boca).
  0.0  - 0.55 s FORMACIÓN: la energía y las estrellas se absorben hacia un punto frente a la boca; nace el
                núcleo oscuro con su anillo de luz.
  0.55 - 1.95 s AVANCE: vuela en un arco suave hacia los enemigos y crece. Tiene un núcleo negro, un anillo de
                luz (blanco-celeste y púrpura) y un disco de acreción que gira (de frente y otro inclinado). La
                materia y las estrellas caen hacia él, y deja una estela de nebulosa oscura y estrellas. Emite
                ondas de gravedad y levanta polvo y cubitos del suelo. Una lente de vidrio detrás de él
                distorsiona el fondo.
  1.95 - 2.1 s  COLAPSO: implosiona (la luz cae hacia el centro y se encoge).
  2.1 s         DETONACIÓN: destello, nebulosa que se expande, anillos, rayos, estrellas, ondas y grietas en el
                suelo y la destrucción de cubos (los que el agujero ya levantaba salen despedidos con los demás).

Capas del proyectil (orb = ...):
  sprite  una sola partícula pegada al agujero que vive todo el vuelo (núcleo, anillos, discos).
  shell   salen de una esfera de radio shell × r (o shell_abs studs × escala) y caen hacia el centro.
  trail   estela que se queda atrás. ground: en el suelo, debajo del agujero. burst: ráfagas en su posición.
  grow    los tamaños van en radios del agujero (crecen con él). locked: van pegadas a él (LockedToPart).
La detonación es una zona circular como la del pilar (ring_emit, decals, cubos, luces). hu = "s": alturas en
studs × escala (la del agujero al llegar), sin depender del radio de la zona.
"""
import random

from vfx_omnivora import (CRACKC, DECAL, DUST, FLASH, INWARD, MOUTH, NEBW, RING2, RINGC, SCORCH, SHOCK, STAR,
                          STATIC2x2, STREAK, VOIDC, WHITE, BOLT, CUBES, center, ring, scatter)

FORM = (0.0, 0.55)          # se forma frente a la boca
TRAVEL = (0.55, 1.95)       # avanza hacia los enemigos
COLLAPSE = (1.95, 2.1)      # implosiona
DET = COLLAPSE[1]           # detona
HEIGHT = 8.0                # altura del agujero al llegar (studs × escala)
R0 = 16.0                   # radio de la detonación con el que están pensados los tamaños (rel "r")
C = 2.5 * R0                # om_cracks: las grietas llegan al borde

PURPLE_RING = [(0, (232, 160, 255)), (1, (190, 90, 250))]
VOID = [(0, (4, 6, 20)), (1, (4, 6, 20))]
TWINKLE_S = [(0, 0), (0.1, 1.4), (0.3, 0.6), (0.5, 1.3), (0.75, 0.5), (1, 0)]


def sprite(name, texture, size, color, transparency, z, **kw):
    """Una partícula pegada al agujero que dura todo el vuelo (y se borra al detonar)."""
    return dict(name=name, orb="sprite", locked=True, grow=True, texture=texture, emit=[(0.0, 1)],
                lifetime=(DET, DET), size=[(0, size), (1, size)], color=color, transparency=transparency,
                light_emission=kw.pop("le", 1.0), zoffset=z, clear_at=DET, **kw)


def hole_layers():
    life = [(0, 1), (0.08, 0.3), (0.9, 0.25), (1, 0.6)]
    return [
        # sombra oscura alrededor: el espacio se oscurece cerca del agujero
        sprite("HoleAura", "fx_glow", 5.5, [(0, (10, 14, 40)), (1, (6, 8, 26))], life, -1, le=0.0),
        # disco de acreción que gira: de frente (siempre se ve) e inclinado hacia la cámara
        sprite("DiskSwirl", "fx_swirl_rings", 6.8, [(0, (130, 200, 255)), (0.5, (90, 160, 255)), (1, (120, 190, 255))],
               [(0, 1), (0.1, 0.35), (0.88, 0.3), (0.95, 0.1), (1, 0.5)], 0.5, le=0.7, brightness=1.0,
               rotation=(0, 360), rot_speed=(-260, -260)),
        sprite("DiskWind", "fx_wind_swirl", 8.0, [(0, (175, 70, 250)), (1, (150, 55, 235))],
               [(0, 1), (0.12, 0.3), (0.9, 0.28), (1, 0.6)], 0.4, le=0.6, brightness=1.1, rotation=(0, 360),
               rot_speed=(170, 170)),
        sprite("DiskTilt", "kk_light_03", 7.0, [(0, (150, 210, 255)), (1, (100, 170, 255))],
               [(0, 1), (0.1, 0.45), (0.9, 0.4), (1, 0.65)], 0.6, le=0.7, brightness=1.0, rotation=(0, 360),
               rot_speed=(-200, -200), orientation="VelocityPerpendicular", direction="Top", speed=(0.01, 0.01)),
        sprite("DiskTiltPurple", "fx_swirl_rings", 9.0, [(0, (200, 100, 255)), (1, (150, 60, 235))],
               [(0, 1), (0.12, 0.4), (0.9, 0.38), (1, 0.7)], 0.3, le=0.6, brightness=1.05, rotation=(0, 360),
               rot_speed=(120, 120), orientation="VelocityPerpendicular", direction="Top", speed=(0.01, 0.01)),
        # el núcleo negro y su anillo de luz (se aviva justo antes de colapsar)
        sprite("HoleCore", "om_hole", 2.15, VOID, [(0, 0), (1, 0)], 1.5, le=0.0),
        sprite("PhotonRing", "kk_circle_02", 3.85, [(0, WHITE), (1, (190, 230, 255))],
               [(0, 1), (0.06, 0.15), (0.86, 0.1), (0.93, 0.0), (1, 0.3)], 2.0, brightness=1.45),
        sprite("PhotonPurple", "kk_circle_02", 4.5, PURPLE_RING, [(0, 1), (0.08, 0.4), (0.9, 0.35), (1, 0.6)], 1.9,
               brightness=1.4),
    ]


def inflow_layers():
    W = [(0.15, FORM[1], 20, 45), (TRAVEL[0], TRAVEL[1], 45, 85), (COLLAPSE[0], COLLAPSE[1] - 0.02, 85, 0)]
    half = [(a, b, r0 * 0.5, r1 * 0.5) for a, b, r0, r1 in W]
    return [
        # la materia cae hacia el agujero (se calienta al llegar) y las estrellas se las traga
        dict(name="Inflow", orb="shell", shell=3.4, grow=True, texture="kk_trace_01", orientation="VelocityParallel",
             speed=(8.5, 10.5), lifetime=(0.3, 0.36), size=[(0, 0.25), (0.4, 1.3), (1, 0.5)],
             transparency=[(0, 0.6), (0.25, 0.1), (1, 0.4)], color=INWARD, light_emission=1.0, brightness=1.4,
             stream=W),
        dict(name="InflowPurple", orb="shell", shell=3.8, grow=True, texture="kk_trace_01",
             orientation="VelocityParallel", speed=(8.5, 10.5), lifetime=(0.34, 0.4),
             size=[(0, 0.25), (0.4, 1.3), (1, 0.5)], transparency=[(0, 0.6), (0.25, 0.1), (1, 0.4)], color=MOUTH,
             light_emission=1.0, brightness=1.4, stream=half),
        dict(name="InflowStars", orb="shell", shell=3.0, grow=True, texture="fx_spark002", speed=(6, 8),
             lifetime=(0.38, 0.48), size=[(0, 0), (0.25, 0.32), (1, 0.12)], color=STAR, light_emission=1.0,
             brightness=1.8, rotation=(0, 45), stream=[(0.2, TRAVEL[1], 25, 50)]),
    ]


def form_layers():
    return [
        # la energía se junta frente a la boca
        dict(name="FormGather", orb="shell", shell_abs=10.0, texture="kk_trace_06", orientation="VelocityParallel",
             speed=(26, 30), lifetime=(0.32, 0.38), size=[(0, 1), (0.3, 4.5), (1, 1.5)],
             transparency=[(0, 0.7), (0.2, 0.2), (0.85, 0.3), (1, 1)], color=INWARD, light_emission=1.0,
             brightness=1.2, stream=[(0.0, FORM[1] - 0.05, 90, 60)]),
        dict(name="FormGatherPurple", orb="shell", shell_abs=8.0, texture="kk_trace_06",
             orientation="VelocityParallel", speed=(21, 25), lifetime=(0.32, 0.38), size=[(0, 1), (0.3, 4), (1, 1.5)],
             transparency=[(0, 0.7), (0.2, 0.1), (0.85, 0.25), (1, 1)], color=MOUTH, light_emission=1.0,
             brightness=1.5, stream=[(0.0, FORM[1] - 0.05, 45, 30)]),
        dict(name="FormMotes", orb="shell", shell_abs=7.0, texture="fx_particle02", speed=(16, 20),
             lifetime=(0.38, 0.45), size=[(0, 0), (0.2, 1.0), (1, 0.4)], color=STAR, light_emission=1.0,
             brightness=1.8, stream=[(0.0, FORM[1] - 0.05, 60, 40)]),
        dict(name="FormGlow", orb="sprite", locked=True, texture="fx_glow", emit=[(0.0, 1)], lifetime=(0.65, 0.65),
             size=[(0, 1.5), (0.8, 13), (1, 6)], color=[(0, (150, 60, 240)), (1, (90, 40, 200))],
             transparency=[(0, 0.5), (0.7, 0.35), (1, 1)], light_emission=1.0, brightness=1.3),
        # sale disparado: anillo y destello en la boca
        dict(name="LaunchPop", orb="burst", texture="kk_circle_02", emit=[(TRAVEL[0], 1)], lifetime=(0.35, 0.35),
             size=[(0, 4), (1, 30)], transparency=[(0, 0.15), (0.6, 0.6), (1, 1)], color=RINGC, light_emission=1.0,
             brightness=1.3),
        dict(name="LaunchFlash", orb="burst", texture="fx_halo", emit=[(TRAVEL[0], 1)], lifetime=(0.22, 0.22),
             size=[(0, 6), (1, 22)], transparency=[(0, 0.2), (1, 1)], color=FLASH, light_emission=1.0, brightness=1.3,
             rotation=(0, 360)),
    ]


def travel_layers():
    T = TRAVEL
    return [
        # ondas de gravedad: anillos que se abren alrededor del agujero mientras avanza
        dict(name="Ripples", orb="burst", locked=True, grow=True, texture="kk_circle_02",
             emit=[(t, 1) for t in (0.8, 1.05, 1.3, 1.55, 1.8)], lifetime=(0.5, 0.5), size=[(0, 3.8), (1, 11)],
             transparency=[(0, 0.55), (0.5, 0.75), (1, 1)], color=RING2, light_emission=1.0, brightness=1.1,
             zoffset=-0.5),
        # estela: nebulosa oscura y estrellas que se quedan atrás
        dict(name="Trail", orb="trail", grow=True, texture="om_nebula_2x2", flipbook=STATIC2x2, speed=(0, 1.5),
             spread=(180, 180), drag=1, lifetime=(0.55, 0.85), size=[(0, 1.6), (0.4, 2.4), (1, 2.8)],
             transparency=[(0, 0.55), (0.35, 0.6), (1, 1)], color=NEBW, light_emission=0.15, rotation=(0, 360),
             rot_speed=(-40, 40), zoffset=-2, stream=[(T[0] + 0.05, T[1], 30, 34)]),
        dict(name="TrailDark", orb="trail", grow=True, texture="kk_smoke_04", speed=(0, 1), spread=(180, 180),
             lifetime=(0.6, 0.9), size=[(0, 1.4), (1, 2.6)], transparency=[(0, 0.55), (0.4, 0.62), (1, 1)],
             color=VOIDC, rotation=(0, 360), rot_speed=(-30, 30), zoffset=-2.5, stream=[(T[0] + 0.05, T[1], 16, 20)]),
        dict(name="TrailStars", orb="trail", texture="fx_particle02", speed=(1, 4), spread=(180, 180), drag=1.5,
             lifetime=(0.6, 1.0), size=TWINKLE_S, color=STAR, light_emission=1.0, brightness=1.9,
             stream=[(T[0] + 0.05, T[1], 40, 50)]),
        # arrastra el entorno: polvo y cubitos del suelo suben hacia él
        dict(name="GroundPull", orb="ground", texture="om_cubes_2x2", flipbook=STATIC2x2,
             shape={"type": "Box", "size": (14, 1, 14)}, direction="Top", spread=(20, 20), speed=(12, 26),
             accel=(0, 25, 0), lifetime=(0.55, 0.85), size=[(0, 0.55, 0.3), (1, 0.35, 0.2)],
             color=[(0, (150, 154, 168)), (1, (120, 124, 140))], rotation=(0, 360), rot_speed=(-300, 300),
             stream=[(0.75, T[1], 30, 70)]),
        dict(name="GroundDust", orb="ground", texture="kk_smoke_04", shape={"type": "Box", "size": (16, 1, 16)},
             direction="Top", spread=(25, 25), speed=(4, 10), accel=(0, 6, 0), lifetime=(0.8, 1.2),
             size=[(0, 3, 1), (1, 9, 2)], transparency=[(0, 0.65), (0.3, 0.55), (1, 1)], color=DUST,
             rotation=(0, 360), rot_speed=(-40, 40), stream=[(0.75, T[1], 8, 16)]),
        # colapso: la luz cae hacia el centro y se aviva antes de detonar
        dict(name="Implode", orb="shell", shell_abs=16.0, texture="kk_trace_01", orientation="VelocityParallel",
             emit=[(COLLAPSE[0], 46)], speed=(70, 90), lifetime=(0.15, 0.2), size=[(0, 2), (0.4, 9), (1, 3)],
             color=STREAK, light_emission=1.0, brightness=1.5),
        dict(name="ImplodePurple", orb="shell", shell_abs=14.0, texture="kk_trace_01", orientation="VelocityParallel",
             emit=[(COLLAPSE[0], 26)], speed=(62, 80), lifetime=(0.15, 0.2), size=[(0, 2), (0.4, 8), (1, 3)],
             color=MOUTH, light_emission=1.0, brightness=1.5),
        dict(name="CollapseFlare", orb="burst", locked=True, texture="fx_glow", emit=[(COLLAPSE[0], 1)],
             lifetime=(0.16, 0.16), size=[(0, 6), (1, 18)], transparency=[(0, 0.6), (1, 0)], color=FLASH,
             light_emission=1.0, brightness=1.2),
    ]


def detonation_layers(g):
    Z = dict(rel="r", hu="s")
    at = center(DET, HEIGHT)
    return [
        dict(name="DetFlash", texture="fx_glow", lifetime=(0.26, 0.26), size=[(0, 10), (0.25, 1.8 * R0), (1, 2.0 * R0)],
             transparency=[(0, 0.15), (0.4, 0.5), (1, 1)], color=FLASH, light_emission=1.0, brightness=1.1, zoffset=4,
             ring_emit=at, **Z),
        dict(name="DetStar", texture="kk_star_09", lifetime=(0.32, 0.32), size=[(0, 14), (0.15, 3.0 * R0), (1, 10)],
             color=FLASH, light_emission=1.0, brightness=1.3, rotation=(0, 90), zoffset=5, ring_emit=at, **Z),
        dict(name="DetHalo", texture="fx_halo", lifetime=(0.38, 0.42), size=[(0, 0.5 * R0), (1, 4.2 * R0)],
             transparency=[(0, 0.3), (0.5, 0.6), (1, 1)], color=SHOCK, light_emission=1.0, brightness=1.1,
             rotation=(0, 360), zoffset=3, ring_emit=at + center(DET + 0.05, HEIGHT), **Z),
        # la nebulosa del agujero se libera y se expande
        dict(name="DetNebula", texture="om_nebula_2x2", flipbook=STATIC2x2, direction="Top", spread=(180, 180),
             speed_r=(0.7, 1.6), drag=2, lifetime=(1.0, 1.4), size=[(0, 0.5 * R0), (0.3, 1.25 * R0), (1, 1.7 * R0)],
             transparency=[(0, 1), (0.06, 0.25), (0.6, 0.4), (1, 1)], color=NEBW, light_emission=0.12,
             rotation=(0, 360), rot_speed=(-30, 30), zoffset=-3, ring_emit=center(DET, HEIGHT, 16), **Z),
        dict(name="DetShell", texture="kk_circle_02", lifetime=(0.45, 0.45),
             size=[(0, 3.39 * 0.25 * R0), (1, 3.39 * 1.7 * R0)], transparency=[(0, 0.1), (0.6, 0.45), (1, 1)],
             color=RINGC, light_emission=1.0, brightness=1.2, zoffset=4, ring_emit=at, **Z),
        dict(name="DetShellPurple", texture="kk_circle_02", lifetime=(0.45, 0.45),
             size=[(0, 3.39 * 0.25 * R0), (1, 3.39 * 1.4 * R0)], transparency=[(0, 0.2), (0.6, 0.5), (1, 1)],
             color=MOUTH, light_emission=1.0, brightness=1.2, zoffset=3.8, ring_emit=center(DET + 0.06, HEIGHT), **Z),
        dict(name="DetStreaks", texture="kk_trace_01", orientation="VelocityParallel", direction="Top",
             spread=(180, 180), speed_r=(2.6, 4.2), lifetime=(0.28, 0.42), size=[(0, 4), (0.3, 20), (1, 8)],
             color=STREAK, light_emission=1.0, brightness=1.1, ring_emit=center(DET, HEIGHT, 54), **Z),
        dict(name="DetPurple", texture="kk_trace_01", orientation="VelocityParallel", direction="Top",
             spread=(180, 180), speed_r=(2.4, 3.8), lifetime=(0.28, 0.42), size=[(0, 4), (0.3, 20), (1, 8)],
             color=MOUTH, light_emission=1.0, brightness=1.15, ring_emit=center(DET, HEIGHT, 30), **Z),
        dict(name="DetStars", texture="fx_spark002", direction="Top", spread=(180, 180), speed_r=(0.9, 2.6), drag=2.2,
             lifetime=(0.9, 1.5), size=[(0, 0), (0.08, 2.6), (0.3, 1.2), (0.5, 2.4), (1, 0)], color=STAR,
             light_emission=1.0, brightness=1.8, rotation=(0, 45), ring_emit=center(DET, HEIGHT, 70), **Z),
        dict(name="DetBolts", texture="fx_thunder", lifetime=(0.08, 0.12), size=[(0, 0.9 * R0), (1, 1.1 * R0)],
             color=BOLT, light_emission=1.0, brightness=1.5, rotation=(0, 360),
             ring_emit=scatter(g, 8, (DET, DET + 0.25), (0.0, 0.5), (HEIGHT - 3, HEIGHT + 3)), **Z),
        # el suelo: ondas, grietas de luz, la marca oscura y el polvo que sale corriendo
        dict(name="DetShock", texture="kk_circle_02", rel="r", lifetime=(0.55, 0.55),
             size=[(0, 3.39 * 0.3 * R0), (1, 3.39 * 2.4 * R0)], transparency=[(0, 0.3), (0.5, 0.6), (1, 1)],
             color=SHOCK, light_emission=0.35, ring_emit=center(DET, 0.2), **DECAL),
        dict(name="DetShockSharp", texture="kk_circle_02", rel="r", lifetime=(0.35, 0.35),
             size=[(0, 3.39 * 0.3 * R0), (1, 3.39 * 3.0 * R0)], transparency=[(0, 0.25), (0.6, 0.55), (1, 1)],
             color=SHOCK, light_emission=0.5, ring_emit=center(DET, 0.21), **DECAL),
        dict(name="DetVoid", texture="fx_glow", rel="r", lifetime=(1.8, 1.8),
             size=[(0, 10), (0.15, 2.2 * R0), (1, 2.3 * R0)], transparency=[(0, 1), (0.1, 0.4), (0.8, 0.4), (1, 1)],
             color=VOIDC, light_emission=0, ring_emit=center(DET, 0.1), **DECAL),
        dict(name="DetCracks", texture="om_cracks", rel="r", lifetime=(1.8, 1.8), rotation=(0, 360),
             size=[(0, 0.3 * C), (0.12, 0.95 * C), (1, 1.04 * C)],
             transparency=[(0, 1), (0.05, 0.25), (0.12, 0.02), (0.3, 0.15), (0.8, 0.3), (1, 1)], color=CRACKC,
             light_emission=0.8, ring_emit=center(DET, 0.16), **DECAL),
        dict(name="DetScorch", texture="kz_scorch", rel="r", lifetime=(2.0, 2.0), rotation=(0, 360),
             size=[(0, 0.5 * R0), (0.05, 2.3 * R0), (1, 2.4 * R0)], transparency=[(0, 1), (0.05, 0.35), (0.8, 0.45), (1, 1)],
             color=SCORCH, light_emission=0, zoffset=-1, ring_emit=center(DET, 0.08), **DECAL),
        dict(name="DetDust", texture="kk_smoke_07", rel="r", direction="Front", spread=(15, 8), pitch=8,
             speed_r=(1.6, 2.6), drag=3, accel=(0, 4, 0), lifetime=(0.9, 1.3), size=[(0, 8, 2), (0.3, 18, 3), (1, 26, 4)],
             transparency=[(0, 0.5), (0.2, 0.32), (0.6, 0.5), (1, 1)], color=DUST, rotation=(0, 360),
             rot_speed=(-40, 40), zoffset=-3, ring_emit=ring(DET + 0.02, 14, 0.5, 1.5)),
        dict(name="CubeBits", texture="om_cubes_2x2", flipbook=STATIC2x2, direction="Front", pitch=55,
             spread=(30, 30), speed_r=(1.6, 3.6), accel=(0, -160, 0), lifetime=(0.6, 1.1),
             size=[(0, 0.6, 0.3), (1, 0.5, 0.25)], color=[(0, (150, 154, 168)), (1, (120, 124, 140))],
             rotation=(0, 360), rot_speed=(-400, 400), ring_emit=scatter(g, 50, (DET, DET + 0.04), (0.2, 1.0), 0.6)),
        # queda polvo de estrellas y la nebulosa se disipa
        dict(name="AfterNebula", texture="om_nebula_2x2", flipbook=STATIC2x2, direction="Top", spread=(180, 180),
             speed=(2, 6), drag=1, lifetime=(1.0, 1.4), size=[(0, 1.0 * R0), (1, 1.5 * R0)],
             transparency=[(0, 1), (0.15, 0.55), (0.7, 0.65), (1, 1)], color=NEBW, light_emission=0.1,
             rotation=(0, 360), rot_speed=(-20, 20), zoffset=-4, ring_emit=center(DET + 0.15, HEIGHT, 6), **Z),
        dict(name="AfterStars", texture="kk_star_06", direction="Top", spread=(180, 180), speed=(1, 3),
             lifetime=(0.7, 1.1), size=[(0, 0), (0.1, 3.2), (0.3, 1.4), (0.5, 3.0), (1, 0)], color=STAR,
             light_emission=1.0, brightness=1.8, rotation=(0, 45),
             ring_emit=scatter(g, 26, (DET + 0.1, DET + 0.9), (0.0, 1.1), (1.0, HEIGHT + 8)), **Z),
    ]


# los cubos: el agujero los levanta cuando llega y la detonación los lanza con todos los demás
CUBES_BH = dict(CUBES, groups=[
    {"name": "Pulled", "mode": "lift", "count": 30, "t": (1.25, 1.75), "r": (0.1, 0.95), "size": (0.25, 1.2),
     "skew": 1.8, "lift": (2.5, 8.0), "release": (DET, DET + 0.03), "out": (20, 56), "up": (40, 85), "dissolve": 0.35},
    {"name": "Blast", "mode": "blast", "count": 150, "t": (DET, DET + 0.06), "r": (0.2, 1.05), "size": (0.12, 1.3),
     "skew": 2.8, "out": (20, 66), "up": (30, 85), "dissolve": 0.35, "neon": 0.1},
])


def black_hole_spec():
    g = random.Random(31)
    return {
        "name": "BlackHole",
        "doc": ("OMNÍVORA: un AGUJERO NEGRO se forma frente a su boca, avanza creciendo y distorsionando el entorno, "
                "y detona en medio de los enemigos (la explosión los cubre a todos) con destrucción de cubos. "
                "Para el combate por turnos: golpea a dos enemigos a la vez."),
        "duration": DET + 1.4,
        "zone": {"radius": R0, "height": 40},
        "orb": {"form": FORM, "travel": TRAVEL, "collapse": COLLAPSE, "size": (0.0, 1.3, 5.0, 0.7),
                "height": HEIGHT, "arc": 6, "tilt": 24, "lens": 4.2, "lens_transparency": 0.62,
                "lens_color": (24, 30, 80), "min_radius": 14, "margin": 7, "reach": 70},
        # tiembla poco mientras se acerca, cada vez más, y fuerte al detonar
        "shake_ramp": (0.3, DET, 0.08, 0.5, 1.6),
        "shakes": [(DET, 1.6, 0.9)],
        "lights": [
            {"t": 1.3, "h": HEIGHT, "color": (60, 100, 255), "brightness": 2, "range": 40, "rise": 0.6, "hold": 0.1,
             "fall": 0.1},
            {"t": DET, "h": HEIGHT, "color": (140, 200, 255), "brightness": 10, "range": 60, "rise": 0.02, "hold": 0.06,
             "fall": 0.6},
            {"t": DET, "h": 3, "color": (170, 80, 255), "brightness": 5, "range": 50, "rise": 0.05, "hold": 0.25,
             "fall": 0.9},
        ],
        "cubes": CUBES_BH,
        "layers": hole_layers() + inflow_layers() + form_layers() + travel_layers() + detonation_layers(g),
    }


BLACK_HOLE = black_hole_spec()
