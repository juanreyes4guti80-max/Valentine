"""OMNÍVORA — VFX cósmicos con los colores de su modelo: azul muy oscuro que se aclara a azul y celeste,
destellos blancos, y el púrpura intenso de su boca acompañando (sin dominar).

Habilidad "Pilar cósmico": Omnívora elige una zona circular y de ella brota un PILAR DE ENERGÍA (un
cilindro de energía que sube, no un pilar sólido).
  0.0 - 0.5 s  CARGA: se marca el círculo en el suelo, el suelo se agrieta con luz, la energía y el polvo
               se absorben hacia el centro, un orbe eléctrico crece y los cubos del suelo levitan temblando.
  0.5 s        ERUPCIÓN: destello, ondas en el suelo, anillos que suben disparados, rayos y la explosión
               de cubos (muchos pequeños y algunos grandes: unos se desintegran en el aire, otros caen).
  0.5 - 2.5 s  PILAR (2 s): un cuerpo DENSO de azul muy oscuro (casi no se ve a través) que se aclara
               hacia los bordes, con estelas celestes y púrpura que suben, anillos que trepan, relámpagos,
               destellos blancos y púrpura que giran en espiral y cubos que el pilar se traga.
  2.5 s        COLAPSO: la energía sale disparada hacia arriba, un último destello y quedan estrellas.
Omnívora va un escalón por encima de Astral Colossus: más denso, más oscuro, más destrucción. La cámara
tiembla sin parar y cada vez más fuerte hasta que el pilar colapsa.

Emisiones en la zona:
  ring_emit (t, n, a, r, alto): a = fracción de vuelta (0..1), r = fracción del radio, alto en studs
            (o fracción de la altura del pilar si la capa tiene hu = "H"). El portador mira hacia afuera.
  zstream   ventanas (t0, t1, tasa0, tasa1) con puntos al azar según zdist = {"r", "h", "area"}.
  spin      grados/s: la capa va pegada a una pieza que gira (las partículas suben en espiral).
  rel       "r": los tamaños crecen con el radio; "h": con la altura (si no, con la escala).
  speed_h / speed_r: velocidad en fracciones de la altura / del radio por segundo.
  clear_at  segundo en que se borran de golpe las partículas que quedan (Emitter:Clear()).
  fade_at   (inicio, duración): las partículas que quedan se desvanecen (y luego Clear()).
"""
import random

R0, H0 = 18.0, 120.0       # radio y altura por defecto (escala 1)
TC, TE = 0.5, 2.5          # fin de la carga (erupción) y fin del pilar (colapso)
SURGES = (0.95, 1.45, 1.95)  # oleadas de energía durante el pilar

# ----------------------------------------------------------------------------- colores
# Como el modelo de Omnívora: domina el azul MUY oscuro, que se aclara a azul y celeste, con destellos
# blancos. El púrpura intenso de su boca acompaña en estelas, destellos y anillos (sin dominar).
WHITE, CELESTE, BLUE, NAVY = (240, 248, 255), (110, 185, 255), (40, 90, 220), (14, 28, 90)
PINK = (190, 80, 235)
BODY = [(0, (22, 44, 125)), (0.5, (16, 32, 100)), (1, (10, 20, 70))]                # cuerpo denso del pilar
DEEPB = [(0, (40, 80, 210)), (0.5, (25, 50, 160)), (1, (12, 25, 100))]              # azul profundo
CORE = [(0, WHITE), (0.35, CELESTE), (1, BLUE)]                                     # lo más caliente
ENERGY = [(0, (200, 235, 255)), (0.4, (110, 180, 255)), (1, (40, 90, 220))]         # celeste -> azul
STREAK = [(0, (215, 240, 255)), (0.5, (120, 190, 255)), (1, (45, 100, 230))]        # estelas
RINGC = [(0, (170, 220, 255)), (0.5, (90, 160, 255)), (1, (30, 70, 200))]
RING2 = [(0, (90, 150, 255)), (0.5, (50, 100, 230)), (1, (25, 50, 170))]
FLASH = [(0, (235, 245, 255)), (0.25, (140, 200, 255)), (1, (40, 90, 220))]
SHOCK = [(0, (180, 225, 255)), (0.5, (90, 150, 255)), (1, (30, 70, 200))]
BOLT = [(0, (240, 248, 255)), (0.5, (150, 210, 255)), (1, (60, 120, 235))]
STAR = [(0, (255, 255, 255)), (0.5, (220, 238, 255)), (1, (140, 190, 255))]
PINKS = [(0, (230, 150, 255)), (0.5, PINK), (1, (110, 40, 190))]                     # acento de la boca
MOUTH = [(0, (225, 140, 255)), (0.4, (190, 70, 250)), (1, (115, 30, 200))]           # estelas púrpura (boca)
MOUTHG = [(0, (120, 40, 210)), (0.5, (100, 30, 190)), (1, (70, 20, 150))]             # brillo púrpura suave
VOIDC = [(0, (10, 16, 52)), (0.5, (6, 10, 40)), (1, (4, 6, 26))]                    # suelo que se abre
DUST = [(0, (150, 154, 168)), (0.5, (128, 132, 146)), (1, (110, 114, 128))]           # polvo del suelo (claro)
SCORCH = [(0, (8, 12, 36)), (1, (14, 20, 50))]
INWARD = [(0, (40, 90, 230)), (0.6, (120, 190, 255)), (1, WHITE)]                    # se calienta al llegar
NEBW = [(0, (255, 255, 255)), (1, (225, 225, 240))]                                 # la textura ya trae el color
CRACKC = [(0, (90, 160, 255)), (0.15, (190, 230, 255)), (0.3, (80, 150, 255)), (1, (30, 60, 180))]
CUBE_GRAY = (112, 106, 112)    # color de los cubos en la vista previa (en el juego: el del suelo)

TWINKLE = [(0, 0), (0.08, 3.2), (0.22, 1.4), (0.38, 3.4), (0.55, 1.2), (0.72, 2.8), (1, 0)]
STATIC2x2 = ("Grid2x2", "Random", 0, True)
DECAL = dict(decal=True, orientation="VelocityPerpendicular", direction="Top", speed=(0.01, 0.01))


def W(rate, start=0.35, rin=0.08, rout=0.12):
    """Tasa del pilar: sube en la erupción, se mantiene y se apaga en el colapso."""
    return [(TC, TC + rin, rate * start, rate), (TC + rin, TE - rout, rate, rate), (TE - rout, TE, rate, 0.0)]


def center(t, h, n=1):
    return [(round(t, 3), n, 0.0, 0.0, h)]


def ring(t, count, r, h, n=1, a0=0.0):
    return [(round(t, 3), n, round((a0 + i / count) % 1.0, 4), r, h) for i in range(count)]


def scatter(g, count, t, r, h, n=1, area=True):
    """Puntos al azar en un anillo/disco (t, r y h pueden ser rangos)."""
    out = []
    for _ in range(count):
        rr = (g.uniform(r[0] ** 2, r[1] ** 2) ** 0.5 if area else g.uniform(*r)) if isinstance(r, tuple) else r
        tt = g.uniform(*t) if isinstance(t, tuple) else t
        hh = g.uniform(*h) if isinstance(h, tuple) else h
        out.append((round(tt, 3), n, round(g.random(), 4), round(rr, 3), round(hh, 3)))
    return sorted(out)


# ----------------------------------------------------------------------------- carga
def charge_layers(g):
    D = 3.39 * R0          # kk_circle_02: el anillo queda en el radio
    C = 2.5 * R0           # om_cracks: las grietas llegan al borde
    L = [
        dict(name="ZoneRing", texture="kk_circle_02", rel="r", lifetime=(0.6, 0.6),
             size=[(0, 1.25 * D), (0.2, D), (1, D)], transparency=[(0, 1), (0.15, 0.12), (0.8, 0.08), (1, 1)],
             color=ENERGY, light_emission=0.8, ring_emit=center(0.0, 0.14), **DECAL),
        dict(name="ZoneRingInner", texture="kk_circle_01", rel="r", lifetime=(0.6, 0.6),
             size=[(0, 1.2 * 2.82 * 0.9 * R0), (0.25, 2.82 * 0.9 * R0), (1, 2.82 * 0.9 * R0)],
             transparency=[(0, 1), (0.3, 0.5), (0.8, 0.4), (1, 1)], color=RING2, light_emission=0.6,
             ring_emit=center(0.03, 0.13), **DECAL),
        dict(name="ZoneVoid", texture="fx_glow", rel="r", lifetime=(3.0, 3.0),
             size=[(0, 10), (0.2, 2.2 * R0), (1, 2.3 * R0)], transparency=[(0, 1), (0.12, 0.45), (0.8, 0.4), (1, 1)],
             color=VOIDC, light_emission=0, ring_emit=center(0.02, 0.1), **DECAL),
        dict(name="ZoneCracks", texture="om_cracks", rel="r", lifetime=(3.0, 3.0), rotation=(0, 360),
             size=[(0, 0.3 * C), (0.15, 0.9 * C), (0.25, C), (1, 1.04 * C)],
             transparency=[(0, 1), (0.05, 0.35), (0.14, 0.2), (0.16, 0.02), (0.3, 0.15), (0.8, 0.25), (1, 1)],
             color=CRACKC, light_emission=0.8, ring_emit=center(0.06, 0.16), **DECAL),
        dict(name="ZoneSwirl", texture="fx_wind_swirl", rel="r", lifetime=(2.6, 2.6), rotation=(0, 360),
             rot_speed=(-200, -200), size=[(0, 1.6 * R0), (0.15, 2.2 * R0), (1, 2.3 * R0)],
             transparency=[(0, 1), (0.12, 0.55), (0.2, 0.35), (0.85, 0.45), (1, 1)], color=DEEPB,
             light_emission=0.7, ring_emit=center(0.1, 0.18), **DECAL),
    ]
    # energía que se absorbe hacia el centro
    ins = []
    for w in range(7):
        ins += ring(0.02 + 0.055 * w, 12, 1.08, 0.0, a0=g.random())
    ins = [(t, n, a, r, round(g.uniform(0.5, 5.0), 2)) for (t, n, a, r, _) in ins]
    L.append(dict(name="ChargeIn", texture="kk_trace_06", rel="r", orientation="VelocityParallel", direction="Back",
                  speed_r=(2.6, 3.0), lifetime=(0.33, 0.38), size=[(0, 2), (0.3, 8), (1, 3)],
                  transparency=[(0, 0.7), (0.2, 0.1), (0.85, 0.25), (1, 1)], color=INWARD, light_emission=1.0,
                  brightness=1.6, ring_emit=sorted(ins)))
    L.append(dict(name="ChargeMotes", texture="fx_particle02", rel="r", direction="Back", speed_r=(1.7, 2.4),
                  lifetime=(0.42, 0.5), size=[(0, 0), (0.2, 1.1, 0.3), (0.8, 0.8), (1, 0)], color=STAR,
                  light_emission=1.0, brightness=1.8,
                  ring_emit=scatter(g, 70, (0.0, 0.4), (1.0, 1.3), (0.3, 7.0), area=False)))
    L.append(dict(name="ChargeDust", texture="kk_smoke_04", rel="r", direction="Back", speed_r=(0.7, 1.0), drag=0.5,
                  lifetime=(0.45, 0.55), size=[(0, 3), (1, 8)], transparency=[(0, 1), (0.3, 0.55), (0.8, 0.7), (1, 1)],
                  color=DUST, light_emission=0.05, rotation=(0, 360), rot_speed=(-60, 60),
                  ring_emit=scatter(g, 16, (0.05, 0.2), 1.0, 1.0)))
    # orbe eléctrico que crece en el centro
    L.append(dict(name="ChargeOrb", texture="fx_electric_ball", rel="r", lifetime=(0.46, 0.46),
                  size=[(0, 2), (0.6, 9), (0.9, 12), (1, 15)], transparency=[(0, 0.6), (0.3, 0.15), (0.9, 0.05), (1, 0.6)],
                  color=CORE, light_emission=1.0, brightness=1.7, rotation=(0, 360), rot_speed=(120, 200),
                  ring_emit=center(0.04, 3.0)))
    L.append(dict(name="ChargeCore", texture="fx_glow", rel="r", lifetime=(0.48, 0.48), size=[(0, 4), (1, 20)],
                  transparency=[(0, 0.9), (0.7, 0.35), (1, 0.2)], color=DEEPB, light_emission=1.0, brightness=1.4,
                  ring_emit=center(0.02, 3.0)))
    for k, tex in enumerate(("kk_spark_03", "kk_spark_04")):
        L.append(dict(name=f"ChargeSparks{k}", texture=tex, rel="r", lifetime=(0.07, 0.1),
                      size=[(0, 9, 2), (1, 12, 2)], color=BOLT, light_emission=1.0, brightness=1.5, rotation=(0, 360),
                      ring_emit=scatter(g, 7, (0.12, 0.48), (0.15, 0.95), 0.8)))
    # una línea de luz marca el camino del pilar justo antes de la erupción
    guide = [(round(0.4 + 0.08 * (i + 0.5) / 6, 3), 1, 0.0, 0.0, round((i + 0.5) / 6, 3)) for i in range(6)]
    L.append(dict(name="GuideLine", texture="fx_laser_thin", rel="h", hu="H", orientation="FacingCameraWorldUp",
                  lifetime=(0.16, 0.16), size=[(0, 0.21 * H0), (1, 0.21 * H0)],
                  transparency=[(0, 1), (0.3, 0.1), (1, 0.5)], color=CORE, light_emission=1.0, brightness=1.7,
                  ring_emit=guide))
    return L


# ----------------------------------------------------------------------------- erupción
def eruption_layers(g):
    L = [
        dict(name="EruptFlash", texture="fx_glow", rel="r", lifetime=(0.2, 0.2),
             size=[(0, 8), (0.25, 1.5 * R0), (1, 1.7 * R0)], transparency=[(0, 0.3), (0.4, 0.55), (1, 1)],
             color=FLASH, light_emission=1.0, brightness=1.15, zoffset=3, ring_emit=center(TC, 4.0)),
        dict(name="EruptHalo", texture="fx_halo", rel="r", lifetime=(0.3, 0.34),
             size=[(0, 0.5 * R0), (1, 4.2 * R0)], transparency=[(0, 0.35), (0.5, 0.6), (1, 1)], color=SHOCK,
             light_emission=0.9, brightness=1.1, rotation=(0, 360), zoffset=2,
             ring_emit=center(TC, 6.0) + center(TC + 0.04, 6.0)),
        dict(name="EruptStar", texture="kk_star_09", rel="r", lifetime=(0.3, 0.3),
             size=[(0, 20), (0.15, 2.8 * R0), (1, 12)], color=FLASH, light_emission=1.0, brightness=1.2,
             rotation=(0, 90), zoffset=4, ring_emit=center(TC, 8.0)),
        dict(name="EruptGlint", texture="kk_star_08", rel="r", lifetime=(0.24, 0.24),
             size=[(0, 4.5 * R0), (1, 1.2 * R0)], transparency=[(0, 0.2), (0.5, 0.45), (1, 1)], color=SHOCK,
             light_emission=1.0, brightness=1.3, rotation=(0, 360), zoffset=4, ring_emit=center(TC + 0.02, 10.0)),
        dict(name="ShockRing", texture="kk_circle_02", rel="r", lifetime=(0.5, 0.5),
             size=[(0, 3.39 * R0), (1, 3.39 * 3.8 * R0)], transparency=[(0, 0.2), (0.5, 0.5), (1, 1)], color=SHOCK,
             light_emission=0.5, ring_emit=center(TC, 0.2), **DECAL),
        dict(name="ShockRingSharp", texture="kk_circle_02", rel="r", lifetime=(0.32, 0.32),
             size=[(0, 3.39 * R0), (1, 3.39 * 5.0 * R0)], transparency=[(0, 0.1), (0.6, 0.45), (1, 1)], color=SHOCK,
             light_emission=0.7, ring_emit=center(TC, 0.21), **DECAL),
        dict(name="ShockRing2", texture="kk_circle_02", rel="r", lifetime=(0.4, 0.4),
             size=[(0, 3.39 * R0), (1, 3.39 * 2.5 * R0)], transparency=[(0, 0.3), (0.6, 0.6), (1, 1)], color=RING2,
             light_emission=0.5, ring_emit=center(TC + 0.06, 0.22), **DECAL),
        # el pilar sale disparado: anillos, cabeza de luz, núcleo y estelas
        dict(name="LaunchRings", texture="kk_light_03", rel="r", orientation="VelocityPerpendicular", direction="Top",
             speed_h=(1.9, 2.1), lifetime=(0.5, 0.5), size=[(0, 2.6 * R0), (0.5, 2.9 * R0), (1, 3.1 * R0)],
             transparency=[(0, 0.2), (0.7, 0.5), (1, 1)], color=RINGC, light_emission=0.9, brightness=1.3,
             ring_emit=center(TC, 1.0) + center(TC + 0.05, 1.0) + center(TC + 0.1, 1.0)),
        dict(name="LaunchHead", texture="fx_glow", rel="r", direction="Top", speed_h=(5.0, 5.2), lifetime=(0.2, 0.2),
             size=[(0, 1.0 * R0), (1, 1.4 * R0)], transparency=[(0, 0.2), (0.8, 0.4), (1, 1)], color=FLASH,
             light_emission=1.0, brightness=1.2, ring_emit=center(TC, 2.0)),
        dict(name="LaunchBeam", texture="fx_beam", rel="h", hu="H", orientation="FacingCameraWorldUp",
             lifetime=(0.32, 0.36), size=[(0, 0.28 * H0), (1, 0.3 * H0)],
             transparency=[(0, 0.6), (0.15, 0.2), (0.6, 0.35), (1, 1)], color=FLASH, light_emission=1.0, brightness=1.2,
             ring_emit=[(round(TC + 0.2 * h, 3), 1, 0.0, 0.0, h) for h in (0.08, 0.22, 0.36, 0.5, 0.64, 0.78, 0.92)]),
        dict(name="LaunchBody", texture="om_nebula_2x2", flipbook=STATIC2x2, rel="r", hu="H",
             orientation="FacingCameraWorldUp", lifetime=(0.55, 0.65), size=[(0, 2.2 * R0), (0.3, 2.45 * R0), (1, 2.5 * R0)],
             transparency=[(0, 1), (0.12, 0.25), (0.8, 0.3), (1, 1)], color=NEBW, light_emission=0.1,
             zoffset=-4, ring_emit=[(round(TC + 0.18 * h, 3), 1, 0.0, 0.0, h)
                                    for h in (0.06, 0.18, 0.3, 0.42, 0.54, 0.66, 0.78)]),
        dict(name="LaunchStreaks", texture="kk_trace_01", rel="r", orientation="VelocityParallel", direction="Top",
             speed_h=(1.6, 2.4), lifetime=(0.25, 0.4), size=[(0, 6), (0.3, 26), (1, 16)], color=STREAK,
             light_emission=1.0, brightness=1.05, ring_emit=scatter(g, 40, (TC, TC + 0.06), (0.3, 1.0), (0.0, 4.0))),
        dict(name="LaunchPurple", texture="kk_trace_01", rel="r", orientation="VelocityParallel", direction="Top",
             speed_h=(1.5, 2.2), lifetime=(0.25, 0.4), size=[(0, 6), (0.3, 26), (1, 16)], color=MOUTH,
             light_emission=1.0, brightness=1.15, ring_emit=scatter(g, 24, (TC, TC + 0.06), (0.3, 1.0), (0.0, 4.0))),
        dict(name="EruptSpikes", texture="fx_spikes", rel="r", orientation="FacingCameraWorldUp",
             lifetime=(0.32, 0.4), size=[(0, 0.5 * R0), (0.3, 1.0 * R0), (1, 1.15 * R0)],
             transparency=[(0, 0.5), (0.3, 0.35), (1, 1)], color=RINGC, light_emission=0.7, brightness=1.0,
             ring_emit=ring(TC, 18, 1.0, 0.32 * R0, a0=g.random())),
        dict(name="EruptThunder", texture="fx_thunder", rel="h", hu="H", orientation="FacingCameraWorldUp",
             lifetime=(0.08, 0.12), size=[(0, 0.28 * H0), (1, 0.3 * H0)], color=BOLT, light_emission=1.0,
             brightness=1.2, rotation=(-10, 10), ring_emit=scatter(g, 6, (TC, TC + 0.15), (0.95, 1.05), (0.15, 0.6), area=False)),
        dict(name="EruptDust", texture="kk_smoke_07", rel="r", direction="Front", spread=(15, 8), pitch=8,
             speed=(30, 55), drag=2.5, accel=(0, 3, 0), lifetime=(0.9, 1.3),
             size=[(0, 6, 1), (0.3, 14, 2), (1, 18, 2)], transparency=[(0, 0.5), (0.3, 0.5), (0.7, 0.75), (1, 1)],
             color=DUST, light_emission=0.05, rotation=(0, 360), rot_speed=(-50, 50), zoffset=-1,
             ring_emit=ring(TC, 24, 1.0, 1.5, n=2, a0=g.random())),
        # las esquirlas más pequeñas (cubitos como partículas, del color del suelo en el juego)
        dict(name="CubeBits", texture="om_cubes_2x2", flipbook=STATIC2x2, direction="Front", pitch=55,
             spread=(25, 25), speed=(25, 70), accel=(0, -160, 0), drag=0.4, lifetime=(0.8, 1.2),
             size=[(0, 0.3, 0.12), (1, 0.24, 0.1)], rotation=(0, 360), rot_speed=(-500, 500),
             color=[(0, CUBE_GRAY), (1, CUBE_GRAY)], ground_mix=1.0, lit=True,
             ring_emit=scatter(g, 80, TC, (0.25, 1.0), 0.6, n=3)),
    ]
    for k, tex in enumerate(("kk_spark_05", "kk_spark_06")):
        L.append(dict(name=f"EruptBolts{k}", texture=tex, rel="r", lifetime=(0.08, 0.12),
                      size=[(0, 16, 4), (1, 22, 4)], color=BOLT, light_emission=1.0, brightness=1.5, rotation=(0, 360),
                      zoffset=2, ring_emit=scatter(g, 5, (TC, TC + 0.2), (0.7, 1.1), (2.0, 14.0), area=False)))
    return L


# ----------------------------------------------------------------------------- pilar (2 s)
FADE = (TE - 0.02, 0.25)     # lo que queda del cuerpo se desvanece en el colapso


def pillar_layers(g):
    H = "H"
    S = 2.45 * R0            # om_nebula_2x2: el cuerpo ocupa el diámetro del pilar
    L = [
        # el CUERPO: franjas anchas casi opacas de azul muy oscuro, más claras hacia los bordes, que suben
        # despacio. Varias apiladas no dejan ver a través del pilar.
        dict(name="Body", texture="om_nebula_2x2", flipbook=STATIC2x2, rel="r", hu=H, orientation="FacingCameraWorldUp",
             direction="Top", speed_h=(0.1, 0.18), lifetime=(0.9, 1.2), size=[(0, 0.95 * S, 0.05 * S), (0.5, 1.0 * S, 0.05 * S), (1, 1.04 * S, 0.05 * S)],
             transparency=[(0, 1), (0.15, 0.25), (0.8, 0.3), (1, 1)], color=NEBW, light_emission=0.1,
             zoffset=-4, zstream=W(12, start=1.0), zdist={"r": (0.0, 0.08), "h": (0.04, 0.7)}, radial=False,
             cover=True, fade_at=FADE),
        # luz azul que sube por los bordes del cuerpo (el azul oscuro se aclara hacia afuera)
        dict(name="BodyRim", texture="om_nebula_2x2", flipbook=STATIC2x2, rel="r", hu=H, orientation="FacingCameraWorldUp",
             direction="Top", speed_h=(0.12, 0.2), lifetime=(0.8, 1.1), size=[(0, 0.98 * S), (1, 1.06 * S)],
             transparency=[(0, 1), (0.2, 0.7), (0.8, 0.72), (1, 1)], color=DEEPB, light_emission=1.0,
             brightness=1.0, zoffset=-3, zstream=W(8, start=1.0), zdist={"r": (0.0, 0.08), "h": (0.05, 0.75)},
             radial=False, cover=True, fade_at=FADE),
        dict(name="BodyPurple", texture="om_nebula_2x2", flipbook=STATIC2x2, rel="r", hu=H,
             orientation="FacingCameraWorldUp", direction="Top", speed_h=(0.12, 0.2), lifetime=(0.7, 1.0),
             size=[(0, 0.9 * S), (1, 1.0 * S)], transparency=[(0, 1), (0.3, 0.6), (0.7, 0.64), (1, 1)], color=MOUTH,
             light_emission=1.0, brightness=1.0, zoffset=-3, zstream=W(7, start=1.0), zdist={"r": (0.0, 0.08), "h": (0.1, 0.7)},
             radial=False, cover=True, fade_at=FADE),
        dict(name="WavyFlow", texture="fx_beam_wavy", rel="r", hu=H, orientation="FacingCameraWorldUp", direction="Top",
             speed_h=(0.4, 0.55), lifetime=(0.7, 0.9), size=[(0, 30), (0.5, 40), (1, 44)],
             transparency=[(0, 1), (0.25, 0.6), (0.75, 0.66), (1, 1)], color=DEEPB, light_emission=0.6,
             brightness=1.0, zoffset=-2, zstream=W(26), zdist={"r": (0.25, 0.85), "h": (0.0, 0.45)}, radial=False,
             cover=True, fade_at=FADE),
        # bordes y estelas de energía celeste encima del cuerpo
        dict(name="WallBeams", texture="fx_beam_wavy", rel="r", hu=H, orientation="FacingCameraWorldUp", direction="Top",
             speed_h=(0.55, 0.75), lifetime=(0.55, 0.7), size=[(0, 30), (0.5, 36), (1, 38)],
             transparency=[(0, 1), (0.2, 0.6), (0.7, 0.66), (1, 1)], color=ENERGY, light_emission=0.8,
             brightness=0.9, zoffset=1, zstream=W(40), zdist={"r": (0.88, 1.0), "h": (0.0, 0.5)}, radial=False,
             cover=True, fade_at=FADE),
        dict(name="CoreStreaks", texture="kk_trace_03", rel="r", hu=H, orientation="VelocityParallel", direction="Top",
             speed_h=(1.2, 1.8), lifetime=(0.25, 0.35), size=[(0, 4), (0.3, 22), (1, 12)], color=STREAK,
             light_emission=1.0, brightness=1.2, zoffset=2, zstream=W(25),
             zdist={"r": (0.1, 0.7), "h": (0.0, 0.4), "area": True}, radial=False, cover=True),
        dict(name="WallStreaks", texture="kk_trace_04", rel="r", hu=H, orientation="VelocityParallel", direction="Top",
             speed_h=(1.0, 1.4), lifetime=(0.35, 0.5), size=[(0, 8), (0.3, 34), (1, 22)], color=STREAK,
             transparency=[(0, 0.3), (0.7, 0.5), (1, 1)], light_emission=0.9, brightness=1.1, zoffset=2,
             zstream=W(70), zdist={"r": (0.85, 1.0), "h": (0.0, 0.4)}, radial=False, cover=True),
        # estelas púrpura (como la boca de Omnívora) que suben entre las celestes
        dict(name="PurpleStreaks", texture="kk_trace_03", rel="r", hu=H, orientation="VelocityParallel",
             direction="Top", speed_h=(0.9, 1.3), lifetime=(0.4, 0.55), size=[(0, 8), (0.3, 34), (1, 22)],
             color=MOUTH, transparency=[(0, 0.2), (0.7, 0.4), (1, 1)], light_emission=1.0, brightness=1.3,
             zoffset=2, zstream=W(95), zdist={"r": (0.78, 1.0), "h": (0.0, 0.45)}, radial=False, cover=True),
        # auroras: velos de plasma azul y púrpura que suben pegados al pilar (lo hacen orgánico, cósmico)
        dict(name="AuroraBlue", texture="fx_aurora", rel="r", hu=H, orientation="FacingCameraWorldUp", direction="Top",
             speed_h=(0.3, 0.45), lifetime=(0.6, 0.9), size=[(0, 22), (0.5, 30), (1, 34)],
             transparency=[(0, 1), (0.25, 0.55), (0.75, 0.6), (1, 1)], color=ENERGY, light_emission=0.9,
             brightness=1.0, zoffset=1, zstream=W(16), zdist={"r": (0.55, 1.0), "h": (0.0, 0.6)}, radial=False,
             cover=True, fade_at=FADE),
        dict(name="AuroraPurple", texture="fx_aurora", rel="r", hu=H, orientation="FacingCameraWorldUp", direction="Top",
             speed_h=(0.3, 0.45), lifetime=(0.6, 0.9), size=[(0, 22), (0.5, 30), (1, 34)],
             transparency=[(0, 1), (0.25, 0.5), (0.75, 0.55), (1, 1)], color=MOUTH, light_emission=0.9,
             brightness=1.05, zoffset=1, zstream=W(18), zdist={"r": (0.55, 1.0), "h": (0.0, 0.6)}, radial=False,
             cover=True, fade_at=FADE),
        dict(name="PurpleCore", texture="kk_trace_04", rel="r", hu=H, orientation="VelocityParallel", direction="Top",
             speed_h=(1.1, 1.6), lifetime=(0.25, 0.35), size=[(0, 4), (0.3, 20), (1, 10)], color=MOUTH,
             light_emission=1.0, brightness=1.3, zoffset=2, zstream=W(35),
             zdist={"r": (0.2, 0.75), "h": (0.0, 0.4), "area": True}, radial=False, cover=True),
        # destellos blancos sobre el cuerpo (como los puntitos de sus placas)
        dict(name="BodySparkles", texture="fx_particle02", rel="r", hu=H, direction="Top", speed_h=(0.02, 0.06),
             lifetime=(0.3, 0.6), size=[(0, 0), (0.3, 0.8, 0.2), (1, 0)], color=[(0, WHITE), (1, (190, 225, 255))],
             light_emission=1.0, brightness=1.8, zoffset=3, zstream=W(90),
             zdist={"r": (0.5, 1.0), "h": (0.0, 0.95)}, radial=False, cover=True),
        # anillos que trepan por el pilar (los de remolino, con el púrpura de la boca)
        dict(name="Rings", texture="kk_light_03", rel="r", hu=H, orientation="VelocityPerpendicular", direction="Top",
             speed_h=(0.8, 0.95), lifetime=(1.0, 1.1), size=[(0, 2.75 * R0), (1, 2.95 * R0)],
             transparency=[(0, 1), (0.08, 0.3), (0.75, 0.5), (1, 1)], color=RINGC, light_emission=0.9,
             brightness=1.1, zoffset=2, zstream=W(5, start=1.0), zdist={"r": (0.0, 0.0), "h": (0.01, 0.01)},
             radial=False, clear_at=TE + 0.02),
        dict(name="SwirlRings", texture="fx_swirl_rings", rel="r", hu=H, orientation="VelocityPerpendicular",
             direction="Top", speed_h=(0.55, 0.7), lifetime=(1.2, 1.4), rotation=(0, 360), rot_speed=(-260, -200),
             size=[(0, 2.4 * R0), (1, 2.7 * R0)], transparency=[(0, 1), (0.1, 0.45), (0.75, 0.55), (1, 1)],
             color=PINKS, light_emission=0.8, brightness=1.0, zoffset=2, zstream=W(3, start=1.0),
             zdist={"r": (0.0, 0.0), "h": (0.02, 0.02)}, radial=False, clear_at=TE + 0.02),
        # relámpagos que recorren la superficie
        dict(name="Lightning", texture="fx_thunder", rel="h", hu=H, orientation="FacingCameraWorldUp",
             lifetime=(0.07, 0.12), size=[(0, 0.26 * H0, 0.04 * H0), (1, 0.28 * H0, 0.04 * H0)], color=BOLT,
             light_emission=1.0, brightness=1.4, rotation=(-12, 12), zoffset=3, zstream=W(10),
             zdist={"r": (0.92, 1.05), "h": (0.05, 0.8)}, radial=False),
        # estrellas que suben en espiral (pegadas a una pieza que gira)
        dict(name="VortexStars", texture="fx_spark002", rel="r", hu=H, direction="Top", speed_h=(0.25, 0.42),
             lifetime=(1.4, 1.9), size=[(0, 0), (0.15, 2.2, 0.6), (0.85, 1.6), (1, 0)], color=STAR,
             light_emission=1.0, brightness=1.7, rotation=(0, 45), zoffset=3, zstream=W(40),
             zdist={"r": (0.6, 1.05), "h": (0.0, 0.08)}, radial=False, clear_at=TE + 0.02, spin=210, slots=8),
        dict(name="VortexPurple", texture="fx_spark002", rel="r", hu=H, direction="Top", speed_h=(0.25, 0.4),
             lifetime=(1.2, 1.7), size=[(0, 0), (0.15, 2.0, 0.5), (0.85, 1.4), (1, 0)], color=MOUTH,
             light_emission=1.0, brightness=1.6, rotation=(0, 45), zoffset=3, zstream=W(26),
             zdist={"r": (0.6, 1.05), "h": (0.0, 0.08)}, radial=False, clear_at=TE + 0.02, spin=210, slots=6),
        dict(name="VortexTwinkle", texture="kk_star_06", rel="r", hu=H, direction="Top", speed_h=(0.15, 0.3),
             lifetime=(1.2, 1.8), size=TWINKLE, color=STAR, light_emission=1.0, brightness=1.7, rotation=(0, 30),
             zoffset=3, zstream=W(18), zdist={"r": (0.6, 1.0), "h": (0.0, 0.1)}, radial=False, clear_at=TE + 0.02,
             spin=210, slots=8),
        dict(name="VortexMotes", texture="fx_particle02", rel="r", hu=H, direction="Top", speed_h=(0.2, 0.4),
             lifetime=(1.2, 1.8), size=[(0, 0), (0.1, 0.9, 0.3), (0.8, 0.7), (1, 0)],
             color=[(0, WHITE), (1, (150, 200, 255))], light_emission=1.0, brightness=1.6, zoffset=3,
             zstream=W(60), zdist={"r": (0.5, 1.05), "h": (0.0, 0.1), "area": True}, radial=False,
             clear_at=TE + 0.02, spin=210, slots=8),
        # el pie del pilar: púas de energía, salpicaduras y brillo en el suelo
        dict(name="BaseSpikes", texture="fx_spikes", rel="r", orientation="FacingCameraWorldUp", lifetime=(0.22, 0.32),
             size=[(0, 0.5 * R0), (0.5, 0.8 * R0), (1, 0.9 * R0)], transparency=[(0, 0.7), (0.3, 0.45), (1, 1)],
             color=RINGC, light_emission=0.7, brightness=1.0, zoffset=1, zstream=W(22),
             zdist={"r": (0.92, 1.02), "h": (0.28 * R0, 0.28 * R0)}, radial=False),
        dict(name="BaseSplash", texture="kk_trace_01", rel="r", orientation="VelocityParallel", direction="Front",
             spread=(8, 8), pitch=12, speed=(35, 60), drag=2, lifetime=(0.18, 0.28), size=[(0, 3), (0.3, 10), (1, 6)],
             color=ENERGY, light_emission=1.0, brightness=1.4, zoffset=1, zstream=W(34),
             zdist={"r": (0.95, 1.0), "h": (0.5, 1.5)}),
        dict(name="BaseGlow", texture="fx_glow", rel="r", lifetime=(2.05, 2.05),
             size=[(0, 2.0 * R0), (0.05, 2.6 * R0), (1, 2.7 * R0)], transparency=[(0, 1), (0.04, 0.45), (0.9, 0.55), (1, 1)],
             color=DEEPB, light_emission=0.4, ring_emit=center(TC, 0.24), **DECAL),
        # la punta se deshace en destellos
        dict(name="TopStars", texture="fx_spark002", rel="r", hu=H, direction="Top", spread=(70, 70), speed=(6, 16),
             lifetime=(0.6, 1.0), size=[(0, 0), (0.2, 2.0), (1, 0)], color=STAR, light_emission=1.0, brightness=1.7,
             rotation=(0, 45), zoffset=3, zstream=W(16), zdist={"r": (0.0, 1.0), "h": (0.8, 1.0), "area": True},
             radial=False),
        # halo de luz azul alrededor del pilar (detrás de todo)
        dict(name="ColumnAura", texture="fx_glow", rel="r", hu=H, direction="Top", speed_h=(0.05, 0.1),
             lifetime=(0.5, 0.7), size=[(0, 2.0 * R0), (0.5, 2.6 * R0), (1, 2.8 * R0)],
             transparency=[(0, 1), (0.3, 0.84), (0.7, 0.87), (1, 1)], color=DEEPB, light_emission=1.0,
             brightness=1.0, zoffset=-6, zstream=W(14), zdist={"r": (0.0, 0.2), "h": (0.05, 0.85)}, radial=False),
    ]
    # oleadas: el pilar late (anillo rápido, estelas, destello en el pie y rayos)
    sr, ss, sf, sb, sp = [], [], [], [], []
    for ts in SURGES:
        sr += center(ts, 1.0)
        ss += scatter(g, 18, (ts, ts + 0.04), (0.5, 1.0), (0.0, 4.0))
        sp += scatter(g, 10, (ts, ts + 0.04), (0.5, 1.0), (0.0, 4.0))
        sf += center(ts, 3.0)
        sb += scatter(g, 3, (ts, ts + 0.08), (0.95, 1.05), (0.1, 0.7), area=False)
    L += [
        dict(name="SurgeRing", texture="kk_light_03", rel="r", orientation="VelocityPerpendicular", direction="Top",
             speed_h=(1.5, 1.5), lifetime=(0.65, 0.65), size=[(0, 2.8 * R0), (1, 3.0 * R0)],
             transparency=[(0, 0.2), (0.7, 0.5), (1, 1)], color=RINGC, light_emission=0.9, brightness=1.3,
             zoffset=2, ring_emit=sr),
        dict(name="SurgeStreaks", texture="kk_trace_01", rel="r", orientation="VelocityParallel", direction="Top",
             speed_h=(1.4, 2.0), lifetime=(0.3, 0.4), size=[(0, 6), (0.3, 24), (1, 14)], color=STREAK,
             light_emission=1.0, brightness=1.2, zoffset=2, ring_emit=ss),
        dict(name="SurgePurple", texture="kk_trace_01", rel="r", orientation="VelocityParallel", direction="Top",
             speed_h=(1.4, 2.0), lifetime=(0.3, 0.4), size=[(0, 6), (0.3, 24), (1, 14)], color=MOUTH,
             light_emission=1.0, brightness=1.2, zoffset=2, ring_emit=sp),
        dict(name="SurgeFlash", texture="fx_glow", rel="r", lifetime=(0.18, 0.18), size=[(0, 1.0 * R0), (1, 1.4 * R0)],
             transparency=[(0, 0.4), (1, 1)], color=FLASH, light_emission=1.0, brightness=1.1, zoffset=3, ring_emit=sf),
        dict(name="SurgeThunder", texture="fx_thunder", rel="h", hu=H, orientation="FacingCameraWorldUp",
             lifetime=(0.08, 0.12), size=[(0, 0.28 * H0), (1, 0.3 * H0)], color=BOLT, light_emission=1.0,
             brightness=1.4, rotation=(-10, 10), zoffset=3, ring_emit=sb),
    ]
    for k, tex in enumerate(("kk_spark_05", "kk_spark_06")):
        L.append(dict(name=f"Bolts{k}", texture=tex, rel="r", hu=H, lifetime=(0.08, 0.12),
                      size=[(0, 14, 4), (1, 20, 4)], color=BOLT, light_emission=1.0, brightness=1.5,
                      rotation=(0, 360), zoffset=3, zstream=W(6), zdist={"r": (0.8, 1.05), "h": (0.0, 0.8)},
                      radial=False))
    for k, (tex, col) in enumerate((("kk_twirl_01", ENERGY), ("kk_twirl_02", PINKS))):
        L.append(dict(name=f"Arcs{k}", texture=tex, rel="r", hu=H, direction="Top", speed_h=(0.1, 0.2),
                      lifetime=(0.4, 0.6), size=[(0, 10), (0.5, 22), (1, 26)], transparency=[(0, 1), (0.3, 0.35), (1, 1)],
                      color=col, light_emission=1.0, brightness=1.3, rotation=(0, 360), rot_speed=(-320, -220),
                      zoffset=2, zstream=W(7), zdist={"r": (0.7, 1.0), "h": (0.05, 0.7)}, radial=False,
                      clear_at=TE + 0.02, spin=260, slots=6))
    return L


# ----------------------------------------------------------------------------- colapso
def collapse_layers(g):
    H = "H"
    return [
        dict(name="CollapseRush", texture="kk_trace_01", rel="r", hu=H, orientation="VelocityParallel", direction="Top",
             speed_h=(3.0, 4.2), lifetime=(0.25, 0.35), size=[(0, 8), (0.3, 36), (1, 20)], color=CORE,
             light_emission=1.0, brightness=1.4, zoffset=3,
             ring_emit=scatter(g, 50, (TE - 0.04, TE + 0.02), (0.0, 0.8), (0.0, 0.3))),
        dict(name="CollapseFlash", texture="fx_glow", rel="r", lifetime=(0.22, 0.22),
             size=[(0, 8), (0.3, 1.8 * R0), (1, 2.2 * R0)], transparency=[(0, 0.1), (0.5, 0.4), (1, 1)], color=CORE,
             light_emission=1.0, brightness=1.5, zoffset=4, ring_emit=center(TE, 4.0)),
        dict(name="CollapseRing", texture="kk_circle_02", rel="r", lifetime=(0.4, 0.4),
             size=[(0, 3.39 * R0 * 0.9), (1, 3.39 * R0 * 2.6)], transparency=[(0, 0.1), (0.6, 0.5), (1, 1)],
             color=ENERGY, light_emission=0.9, ring_emit=center(TE, 0.26), **DECAL),
        dict(name="CollapseStars", texture="fx_spark002", rel="r", hu=H, direction="Front", spread=(35, 35), pitch=10,
             speed=(6, 18), drag=1.5, lifetime=(0.8, 1.2), size=[(0, 0), (0.15, 2.6), (1, 0)], color=STAR,
             light_emission=1.0, brightness=1.7, rotation=(0, 45), zoffset=3,
             ring_emit=scatter(g, 46, (TE, TE + 0.05), (0.0, 0.9), (0.02, 0.8))),
        dict(name="CollapseTwinkle", texture="kk_star_06", rel="r", hu=H, direction="Front", spread=(35, 35),
             speed=(3, 10), drag=1.5, lifetime=(0.9, 1.3), size=TWINKLE, color=STAR, light_emission=1.0,
             brightness=1.7, rotation=(0, 30), zoffset=3,
             ring_emit=scatter(g, 24, (TE, TE + 0.05), (0.0, 0.9), (0.02, 0.8))),
        dict(name="GroundScar", texture="kz_scorch", rel="r", lifetime=(3.1, 3.1), rotation=(0, 360),
             size=[(0, 2.2 * R0), (0.1, 2.65 * R0), (1, 2.75 * R0)], transparency=[(0, 1), (0.06, 0.5), (0.75, 0.6), (1, 1)],
             color=SCORCH, light_emission=0, zoffset=-1, ring_emit=center(TC, 0.08), **DECAL),
    ]


# ----------------------------------------------------------------------------- cubos de destrucción
# La habilidad es enorme: los cubos son escombros pequeños (muchos), no bloques del tamaño de un edificio.
CUBES = {
    "gravity": 160, "bounce": 0.32, "friction": 0.55, "spin": (240, 820),
    "rest": (0.5, 1.3), "fade": 0.35, "settle": 0.12, "shrink": (0.16, 0.26), "dissolve_time": (0.18, 0.6),
    "color_var": (0.72, 1.08), "dark": 0.15,
    "neon_colors": [(110, 185, 255), (50, 110, 255), (170, 220, 255), (190, 80, 235)],
    "preview_color": CUBE_GRAY,
    # destello cuando un cubo se desintegra
    "fx": dict(name="CubeDissolve", texture="fx_spark002", direction="Top", spread=(180, 180), speed=(4, 12),
               lifetime=(0.25, 0.4), size=[(0, 0), (0.2, 1.8), (1, 0)], color=STAR, light_emission=1.0,
               brightness=1.7, rotation=(0, 45), emit_n=2),
    "groups": [
        # levitan temblando durante la carga y salen disparados en la erupción
        {"name": "Lift", "mode": "lift", "count": 26, "t": (0.02, 0.2), "r": (0.12, 0.9), "size": (0.25, 1.1),
         "skew": 1.8, "lift": (0.8, 4.0), "release": (0.5, 0.53), "out": (18, 48), "up": (45, 90), "dissolve": 0.3},
        # la explosión: muchísimos pequeños y algunos medianos; unos se desintegran en el aire, los demás caen
        {"name": "Blast", "mode": "blast", "count": 150, "t": (0.5, 0.56), "r": (0.25, 1.05), "size": (0.12, 1.3),
         "skew": 2.8, "out": (18, 62), "up": (26, 80), "dissolve": 0.35, "neon": 0.1},
        # el pilar se los traga: giran alrededor del pilar, suben y se deshacen
        {"name": "Vortex", "mode": "vortex", "count": 44, "t": (0.6, 2.25), "r": (0.95, 1.25), "size": (0.15, 0.8),
         "skew": 2.2, "rise": (0.14, 0.26), "orbit": (2.4, 3.8), "top": (0.4, 0.85), "release": TE},
    ],
}


def cosmic_pillar_spec():
    g = random.Random(23)
    L = charge_layers(g) + eruption_layers(g) + pillar_layers(g) + collapse_layers(g)
    return {
        "name": "CosmicPillar",
        "doc": ("OMNÍVORA: elige una zona circular y brota un PILAR DE ENERGÍA cósmica (0.5 s de carga, 2 s de pilar) "
                "con destrucción de cubos. OmnivoraVFX.CosmicPillar(cf, radio, altura, escala, sacudida): "
                "cf = centro de la zona en el suelo."),
        "duration": 3.0,
        "zone": {"radius": R0, "height": H0, "charge": TC, "collapse": TE},
        # sacudida continua que crece desde la carga hasta el colapso y ahí se detiene: (t0, t1, k0, k1, curva)
        "shake_ramp": (0.0, TE, 0.12, 1.3, 1.4),
        "lights": [
            {"t": 0.0, "h": 4, "color": (60, 110, 255), "brightness": 3, "range": 40, "rise": 0.5, "hold": 0.0, "fall": 0.25},
            {"t": TC, "h": 6, "color": (120, 190, 255), "brightness": 9, "range": 60, "rise": 0.03, "hold": 0.05, "fall": 0.6},
            {"t": TC, "h": 0.3, "hu": "H", "color": (50, 100, 255), "brightness": 5, "range": 60, "rise": 0.1,
             "hold": 1.8, "fall": 0.4},
            {"t": TE, "h": 4, "color": (120, 190, 255), "brightness": 5, "range": 50, "rise": 0.02, "hold": 0.03, "fall": 0.5},
        ] + [{"t": ts, "h": 4, "color": (90, 160, 255), "brightness": 3, "range": 45, "rise": 0.02, "hold": 0.03,
              "fall": 0.3} for ts in SURGES],
        "cubes": CUBES,
        "layers": L,
    }


COSMIC_PILLAR = cosmic_pillar_spec()
SPECS = {"CosmicPillar": COSMIC_PILLAR}

# el agujero negro usa los colores de este archivo: se importa al final
import vfx_blackhole as _BH  # noqa: E402
SPECS["BlackHole"] = _BH.BLACK_HOLE
