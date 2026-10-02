"""
Kit de habilidades de KAIJU ZERO — definición de poses y tiempos.

Unidades:
  root.loc  -> fracción de la altura de cadera (H)
  manos     -> fracción del largo del brazo (L), relativo al hombro
  pies      -> fracción de H, relativo a su posición de reposo
  ángulos   -> grados
Lados: "out" positivo = hacia el lado de ese miembro.
"""
import math
import kzanim as K

FPS = 60

# ----------------------------------------------------------------------------
# Pose base (idle de referencia en el rig de prueba). En el rig real el primer y
# último frame de cada clip se reemplaza por el frame 0 de su Idle.
# ----------------------------------------------------------------------------
IDLE = {
    "root": {"loc": (0, 0.0, -0.045), "rot": (4, 0, 0)},
    "hips": (0, 0, 0),
    "spine": (9, 0, 0),
    "neck": (2, 0, 0),
    "gaze": (4, 0, 0),
    "arm": {
        "R": {"hand": (0.14, 0.14, -0.9), "elbow": (0.5, -0.7, -0.3),
              "palm": (-1, 0.1, 0), "fingers": (0.05, 0.25, -1), "clav": (0, 0)},
        "L": {"hand": (0.14, 0.14, -0.9), "elbow": (0.5, -0.7, -0.3),
              "palm": (-1, 0.1, 0), "fingers": (0.05, 0.25, -1), "clav": (0, 0)},
    },
    "fingers": {"R": {"curl": 0.4, "claw": 0.0, "spread": 0, "thumb": 0.3},
                "L": {"curl": 0.4, "claw": 0.0, "spread": 0, "thumb": 0.3}},
    "foot": {"L": {"loc": (0.02, 0.03, 0), "rot": (0, 6, 0)},
             "R": {"loc": (0.02, -0.03, 0), "rot": (0, 6, 0)}},
    "tail": {"pitch": 6, "yaw": 0, "curl": 0},
}

FIST = {"curl": 1.0, "claw": 0.0, "spread": 0, "thumb": 0.9}
CLAW = {"curl": 0.25, "claw": 0.75, "spread": 22, "thumb": 0.35}
OPEN = {"curl": 0.05, "claw": 0.0, "spread": 18, "thumb": 0.0}
KNIFE = {"curl": 0.05, "claw": 0.1, "spread": 4, "thumb": 0.1}


def step_lift(loc, h=0.06):
    """Posición intermedia de un paso: levanta el pie."""
    return (loc[0], loc[1], loc[2] + h)


# ============================================================================
# A1 — TAJO DE LA ESPADA DE FUEGO (estilo Taker's Flames)
# ============================================================================
def A1_FireSlash():
    k = []
    k.append((0.00, IDLE))
    # 1) Anticipación: el peso cae al pie derecho, brazos atrás como péndulo
    k.append((0.22, {
        "root": {"loc": (-0.025, -0.03, -0.09), "rot": (9, -6, -2)},
        "spine": (12, -8, 0),
        "gaze": (6, 0, 0),
        "arm": {"R": {"hand": (0.16, -0.22, -0.86), "elbow": (0.4, -0.9, 0.1),
                      "palm": (-0.6, -0.4, 0.2), "fingers": (0.1, -0.3, -1)},
                "L": {"hand": (0.14, -0.18, -0.87), "elbow": (0.4, -0.9, 0.1),
                      "palm": (-0.6, -0.4, 0.2), "fingers": (0.1, -0.3, -1)}},
        "fingers": {"R": {"curl": 0.55}, "L": {"curl": 0.55}},
        "tail": {"pitch": 0, "yaw": 8},
    }))
    # 2) Barrido hacia arriba: brazos en arco por delante, el derecho lidera
    k.append((0.42, {
        "root": {"loc": (-0.02, -0.015, -0.055), "rot": (2, -2, -1)},
        "spine": (0, -3, 0),
        "gaze": (-6, 0, 0),
        "arm": {"R": {"hand": (-0.12, 0.6, 0.36), "elbow": (0.9, 0.0, -0.6), "clav": (8, 6),
                      "palm": (0.2, -0.3, 1), "fingers": (-0.3, 1, 0.4)},
                "L": {"hand": (-0.14, 0.64, 0.1), "elbow": (0.9, -0.1, -0.6), "clav": (5, 6),
                      "palm": (0.2, -0.4, 1), "fingers": (-0.4, 1, 0.1)}},
        "fingers": {"R": OPEN, "L": OPEN},
        "tail": {"pitch": -4, "yaw": 4},
    }))
    # 3) Sobre la cabeza: ambas manos se cierran en el mango -> la espada aparece.
    OVER = {
        "root": {"loc": (-0.01, -0.03, -0.065), "rot": (-2, 0, 0)},
        "spine": (-9, 0, 0),
        "neck": (-2, 0, 0),
        "gaze": (-6, 0, 0),
        "arm": {"R": {"space": "mid", "hand": (0.03, 0.04, 0.62), "elbow": (1, 0.15, -0.1), "clav": (16, 4),
                      "blade": (0, -0.15, 1)},
                "L": {"space": "grip", "rel": "R", "spacing": 0.95, "elbow": (1, 0.25, -0.1), "clav": (14, 4)}},
        "arm_order": ("R", "L"),
        "fingers": {"R": FIST, "L": FIST},
        "foot": {"L": {"loc": (0.03, 0.03, 0), "rot": (0, 8, 0)},
                 "R": {"loc": (0.03, -0.04, 0), "rot": (0, 8, 0)}},
        "tail": {"pitch": -10, "yaw": 0},
    }
    k.append((0.64, OVER))
    # 4) Hold vivo: acumula (sube, arquea, hombros arriba) mientras arde la hoja
    OVER2 = K.deep_merge(OVER, {
        "root": {"loc": (-0.01, -0.04, -0.06), "rot": (-3, 0, 0)},
        "spine": (-12, 0, 0),
        "arm": {"R": {"hand": (0.03, 0.0, 0.67), "clav": (20, 2), "blade": (0, -0.25, 1)}},
        "gaze": (-3, 0, 0),
    })
    k.append((0.98, OVER2))
    # 5) Carga: la hoja cae detrás de la cabeza; la cadera YA empieza a ir adelante
    k.append((1.10, {
        "root": {"loc": (0.0, -0.005, -0.06), "rot": (-1, 0, 0)},
        "spine": (-16, 0, 0),
        "gaze": (2, 0, 0),
        "arm": {"R": {"space": "mid", "hand": (0.02, -0.06, 0.52), "elbow": (0.8, 0.7, 0.3), "clav": (18, -2),
                      "blade": (0, -0.8, -0.6)}},
        "foot": {"L": {"loc": (0.03, 0.09, 0.05), "rot": (8, 8, 0)}},
        "tail": {"pitch": -6},
    }))
    # 6) Bajada a velocidad máxima: cadera -> pecho -> brazos -> hoja
    k.append((1.20, {
        "root": {"loc": (0.0, 0.09, -0.09), "rot": (8, 0, 0)},
        "spine": (8, 0, 0),
        "gaze": (10, 0, 0),
        "arm": {"R": {"space": "mid", "hand": (0.02, 0.5, 0.42), "elbow": (0.9, 0.1, -0.4), "clav": (10, 8),
                      "blade": (0, 0.34, 0.94)}},
        "foot": {"L": {"loc": (0.03, 0.24, 0.02), "rot": (-8, 8, 0)}},
        "tail": {"pitch": 12},
    }))
    # 7) IMPACTO: la hoja muerde el suelo al frente
    IMPACT = {
        "root": {"loc": (0.0, 0.15, -0.16), "rot": (15, 2, 0)},
        "spine": (34, 2, 0),
        "neck": (-6, 0, 0),
        "gaze": (24, 0, 0),
        "arm": {"R": {"space": "mid", "hand": (0.02, 0.8, -0.55), "elbow": (1, -0.3, -0.4), "clav": (-4, 14),
                      "blade": (0, 0.95, -0.3)}},
        "foot": {"L": {"loc": (0.04, 0.27, 0), "rot": (0, 8, 0)},
                 "R": {"loc": (0.03, -0.05, 0), "rot": (14, 10, 0)}},
        "tail": {"pitch": 30, "curl": -10},
    }
    k.append((1.30, IMPACT, {"interp": "QUAD", "easing": "EASE_IN"}))
    # 8) Absorción del impacto (rodillas) y el peso que se queda abajo
    k.append((1.37, K.deep_merge(IMPACT, {
        "root": {"loc": (0.0, 0.155, -0.185), "rot": (17, 2, 0)},
        "spine": (37, 2, 0),
        "arm": {"R": {"hand": (0.02, 0.8, -0.52)}},
        "tail": {"pitch": 36, "curl": -4},
    })))
    k.append((1.78, K.deep_merge(IMPACT, {
        "root": {"loc": (0.0, 0.145, -0.175), "rot": (16, 1, 0)},
        "spine": (35, 1, 0),
        "arm": {"R": {"hand": (0.02, 0.83, -0.52)}},
        "tail": {"pitch": 28, "curl": 4},
    })))
    # 9) Recuperación: la cabeza sube primero, el peso vuelve atrás, saca la hoja
    k.append((2.06, {
        "root": {"loc": (-0.01, 0.08, -0.12), "rot": (9, 0, 0)},
        "spine": (20, 0, 0),
        "neck": (0, 0, 0),
        "gaze": (6, 0, 0),
        "arm": {"R": {"space": "mid", "hand": (0.02, 0.7, -0.45), "elbow": (1, -0.4, -0.3), "clav": (0, 8),
                      "blade": (0, 0.97, -0.1)}},
        "foot": {"R": {"loc": (0.03, -0.04, 0), "rot": (0, 8, 0)}},
        "tail": {"pitch": 16, "curl": 0},
    }))
    # 10) Paso atrás del pie izquierdo; la espada se disipa, las manos se sueltan
    k.append((2.30, {
        "root": {"loc": (-0.02, 0.02, -0.075), "rot": (6, 0, 0)},
        "spine": (12, 0, 0),
        "arm": {"R": {"space": "chest", "hand": (0.0, 0.3, -0.8), "elbow": (0.6, -0.6, -0.3), "clav": (0, 2),
                      "palm": (-1, 0.2, 0.3), "fingers": (0, 0.4, -1)},
                "L": {"space": "chest", "hand": (0.06, 0.28, -0.8), "elbow": (0.6, -0.6, -0.3), "clav": (0, 2),
                      "palm": (-1, 0.2, 0.3), "fingers": (0, 0.4, -1)}},
        "fingers": {"R": {"curl": 0.5, "claw": 0, "spread": 0, "thumb": 0.3},
                    "L": {"curl": 0.5, "claw": 0, "spread": 0, "thumb": 0.3}},
        "foot": {"L": {"loc": (0.02, 0.12, 0.05), "rot": (8, 6, 0)}},
        "tail": {"pitch": 10},
    }))
    k.append((2.48, {
        "root": {"loc": (0.0, 0.0, -0.065), "rot": (5, 0, 0)},
        "foot": {"L": {"loc": (0.02, 0.03, 0), "rot": (0, 6, 0)}},
    }))
    k.append((2.85, IDLE))
    markers = [("SwordSummon", 0.50), ("SwordIgnite", 0.66), ("Impact", 1.33),
               ("FireWave", 1.35), ("SwordVanish", 2.22)]
    lags = {"spine": 1, "arms": 2, "hands": 3, "head": 3, "fingers": 3, "tail": [2, 3, 4, 5, 6, 7]}
    return dict(name="KZ_A1_FireSlash", keys=k, markers=markers, lags=lags, loop=False, sword=True)


# ============================================================================
# Utilidades de capas (temblor / respiración) para los clips
# ============================================================================
def ramp(f0, f1, a=0.0, b=1.0):
    def env(f):
        if f <= f0:
            return a
        if f >= f1:
            return b
        t = (f - f0) / (f1 - f0)
        t = t * t * (3 - 2 * t)
        return a + (b - a) * t
    return env


def tremble_layer(spec):
    """spec: lista de (grupo|hueso, amp_grados, ciclos, seed, env|None).
    Devuelve post(rig, act) que hornea temblor periódico (loop-safe)."""
    def post(rig, act):
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        length = max(1, f1 - f0)
        groups = K.bone_groups(rig)
        for target, amp, cycles, seed, env in spec:
            bones = groups.get(target, [target])
            for i, bn in enumerate(bones):
                if bn not in rig.pb:
                    continue
                fn = K.tremor(seed + i * 17, amp, cycles, length, env=env)
                K.bake_additive(rig, act, bn, f0, f1, lambda f, fn=fn: fn(f - f0), step=1)
    return post


# ============================================================================
# A2 — CORTE CONTENIDO: CARGA (hold) + LANZAMIENTO (cast)
# ============================================================================
def _a2_hold(level):
    """Pose de hold. level 0 = recién entrado, 1 = carga completa (2 s)."""
    L = level
    return {
        "root": {"loc": (0.0, 0.02 - 0.02 * L, -0.10 - 0.03 * L), "rot": (5 + L, -18 - 2 * L, 0)},
        "hips": (0, 0, 0),
        "spine": (12 + 2 * L, -16 - 3 * L, 0),
        "neck": (0, 4, 0),
        "gaze": (6 + 2 * L, 0, 0),
        "arm": {
            # brazo izquierdo: apunta (mano de canto, la que tiembla)
            "L": {"space": "shoulder_char", "hand": (-0.05, 0.86 + 0.04 * L, 0.02 + 0.01 * L),
                  "elbow": (0.6, 0.0, -1.0), "clav": (4 + 2 * L, 10 + 3 * L),
                  "hand_space": "char", "palm": (-1, 0.0, 0.05), "fingers": (0.02, 1, 0.08)},
            # brazo derecho: antebrazo horizontal cruzando el abdomen, palma arriba, garra
            "R": {"space": "mid", "hand": (-0.12 + 0.02 * L, 0.42 - 0.06 * L, -0.62 + 0.02 * L),
                  "elbow": (1, -0.4, -0.3), "clav": (2 + 4 * L, -2),
                  "palm": (0.0, 0.1, 1), "fingers": (-1, 0.15, 0.05)},
        },
        "fingers": {"L": {"curl": 0.04, "claw": 0.12 + 0.1 * L, "spread": 6 + 4 * L, "thumb": 0.12},
                    "R": {"curl": 0.25 + 0.1 * L, "claw": 0.7 + 0.2 * L, "spread": 20 + 6 * L, "thumb": 0.3}},
        "foot": {"L": {"loc": (0.05, 0.16, 0), "rot": (0, 14, 0)},
                 "R": {"loc": (0.03, -0.06, 0), "rot": (0, 22, 0)}},
        "tail": {"pitch": -4 - 2 * L, "yaw": 12 + 2 * L, "curl": 0},
    }


def A2_Charge():
    H0, H1 = _a2_hold(0.0), _a2_hold(1.0)
    k = [(0.00, IDLE)]
    k.append((0.10, {
        "root": {"loc": (0.0, -0.01, -0.075), "rot": (6, -8, 0)},
        "spine": (11, -10, 0),
        "arm": {"R": {"hand": (0.0, 0.3, -0.8), "elbow": (0.6, -0.6, -0.3), "palm": (-0.8, 0.2, 0.4), "fingers": (-0.3, 0.4, -1)},
                "L": {"hand": (0.1, 0.35, -0.72), "elbow": (0.6, -0.5, -0.4), "palm": (-1, 0.2, 0.2), "fingers": (0, 0.6, -1)}},
        "foot": {"L": {"loc": (0.04, 0.09, 0.045), "rot": (8, 10, 0)}},
    }))
    k.append((0.24, H0))
    k.append((0.34, K.deep_merge(H0, {"root": {"loc": (0.0, 0.025, -0.112)}, "spine": (13, -16.5, 0)})))
    k.append((0.60, H0))
    k.append((1.30, _a2_hold(0.6)))
    k.append((2.00, H1))
    env = ramp(14, 120, 0.25, 1.0)
    post = tremble_layer([
        ("c_hand_fk.l", 2.4, (9, 13, 17), 11, env),
        ("c_forearm_fk.l", 0.7, (9, 13), 12, env),
        ("c_hand_fk.r", 1.0, (11, 15), 13, env),
        ("spine", 0.35, (7, 11), 14, env),
    ])
    return dict(name="KZ_A2_Charge", keys=k, markers=[("ChargeStart", 0.0), ("FullCharge", 2.0)],
                lags={"head": 2, "hands": 1, "fingers": 2, "tail": [2, 3, 4, 5, 6, 7]}, loop=False, post=post)


def A2_HoldMax():
    H1 = _a2_hold(1.0)
    inn = K.deep_merge(H1, {"spine": (14.8, -19, 0), "arm": {"R": {"clav": (7, -2)}, "L": {"clav": (7, 13)}},
                            "root": {"loc": (0.0, 0.0, -0.127)}})
    k = [(0.00, H1), (0.5, inn), (1.0, H1)]
    post = tremble_layer([
        ("c_hand_fk.l", 2.4, (5, 7, 11), 21, None),
        ("c_forearm_fk.l", 0.7, (5, 7), 22, None),
        ("c_hand_fk.r", 1.0, (6, 9), 23, None),
        ("spine", 0.35, (4, 6), 24, None),
        ("head", 0.4, (3, 5), 25, None),
    ])
    return dict(name="KZ_A2_HoldMax", keys=k, markers=[], lags={"tail": [1, 2, 3, 4, 5, 6]}, loop=True, post=post)


def A2_Cast():
    H1 = _a2_hold(1.0)
    k = [(0.00, H1)]
    # anticipación: la mano derecha cae a la cadera, el torso se enrolla más
    k.append((0.09, {
        "root": {"loc": (0.0, -0.01, -0.14), "rot": (5, -26, 0)},
        "spine": (14, -24, 0),
        "arm": {"R": {"space": "chest", "hand": (0.2, -0.06, -0.84), "elbow": (0.4, -0.9, 0.0), "clav": (0, -4),
                      "hand_space": "char", "palm": (-0.6, 0.6, 0.0), "fingers": (0.1, 0.4, -1)},
                "L": {"space": "chest", "hand": (0.02, 0.32, -0.36), "elbow": (1, -0.5, -0.2), "clav": (2, 4),
                      "hand_space": "chest", "palm": (-1, 0, 0), "fingers": (0, 1, 0.1)}},
        "fingers": {"R": KNIFE, "L": {"curl": 0.6, "claw": 0, "spread": 0, "thumb": 0.5}},
    }))
    # mitad del corte: la cadera gira primero (el pie derecho pivota sobre la punta)
    k.append((0.16, {
        "root": {"loc": (0.0, 0.02, -0.11), "rot": (5, -4, 0)},
        "spine": (10, -8, 0),
        "arm": {"R": {"space": "shoulder_char", "hand": (-0.12, 0.66, -0.4), "elbow": (1, -0.2, -0.6), "clav": (2, 8),
                      "hand_space": "char", "palm": (-1, 0.15, 0.1), "fingers": (0.05, 1, 0.25)},
                "L": {"space": "chest", "hand": (0.16, -0.05, -0.78), "elbow": (0.6, -0.8, 0), "clav": (0, -4),
                      "hand_space": "chest", "palm": (-1, 0, 0), "fingers": (0, 0.3, -1)}},
        "foot": {"R": {"loc": (0.03, -0.06, 0.01), "rot": (18, -6, 0)}},
    }))
    # tope del corte: antebrazo vertical frente a la cara, palma al frente
    TOP = {
        "root": {"loc": (0.0, 0.04, -0.075), "rot": (3, 12, 0)},
        "spine": (6, 14, 0),
        "gaze": (2, 0, 0),
        "arm": {"R": {"space": "shoulder_char", "hand": (-0.1, 0.5, 0.42), "elbow": (0.5, 0.2, -1), "clav": (4, 10),
                      "hand_space": "char", "palm": (0, 1, 0.05), "fingers": (0.02, 0.1, 1)},
                "L": {"space": "chest", "hand": (0.2, -0.15, -0.8), "elbow": (0.6, -0.8, 0), "clav": (0, -6),
                      "hand_space": "chest", "palm": (-1, 0.1, 0), "fingers": (0, 0.3, -1)}},
        "fingers": {"L": FIST},
        "foot": {"R": {"loc": (0.03, -0.07, 0.015), "rot": (26, -24, 0)}},
        "tail": {"pitch": 2, "yaw": -14},
    }
    k.append((0.23, TOP, {"interp": "BEZIER"}))
    k.append((0.29, K.deep_merge(TOP, {
        "spine": (5, 17, 0), "root": {"rot": (3, 14, 0)},
        "arm": {"R": {"hand": (-0.1, 0.46, 0.5)}}})))
    k.append((0.55, K.deep_merge(TOP, {"arm": {"R": {"hand": (-0.1, 0.5, 0.44)}}})))
    # recuperación: baja el brazo, el torso se desenrolla, el pie izquierdo vuelve
    k.append((0.82, {
        "root": {"loc": (0.0, 0.02, -0.075), "rot": (5, 2, 0)},
        "spine": (10, 2, 0),
        "arm": {"R": {"space": "chest", "hand": (0.08, 0.3, -0.66), "elbow": (0.6, -0.6, -0.3), "clav": (0, 0),
                      "hand_space": "chest", "palm": (-1, 0.1, 0.2), "fingers": (0, 0.4, -1)},
                "L": {"space": "chest", "hand": (0.14, 0.14, -0.88), "elbow": (0.5, -0.7, -0.3), "clav": (0, 0),
                      "hand_space": "chest", "palm": (-1, 0.1, 0), "fingers": (0.05, 0.25, -1)}},
        "fingers": {"R": {"curl": 0.4, "claw": 0, "spread": 0, "thumb": 0.3}, "L": {"curl": 0.4, "claw": 0, "spread": 0, "thumb": 0.3}},
        "foot": {"R": {"loc": (0.02, -0.04, 0), "rot": (0, 8, 0)},
                 "L": {"loc": (0.04, 0.1, 0.045), "rot": (6, 10, 0)}},
        "tail": {"pitch": 4, "yaw": 0},
    }))
    k.append((0.98, {"foot": {"L": {"loc": (0.02, 0.03, 0), "rot": (0, 6, 0)}},
                     "root": {"loc": (0.0, 0.0, -0.06)}}))
    k.append((1.25, IDLE))
    return dict(name="KZ_A2_Cast", keys=k, markers=[("Release", 0.21)],
                lags={"spine": 1, "arms": 1, "hands": 2, "head": 3, "fingers": 2, "tail": [2, 3, 4, 5, 6, 7]},
                loop=False)


# ============================================================================
# A3 — IGNITION: activación + idle de ignición (loop)
# ============================================================================
IGN = {
    "root": {"loc": (0, 0, -0.10), "rot": (7, 0, 0)},
    "hips": (0, 0, 0),
    "spine": (12, 0, 0),
    "neck": (-3, 0, 0),
    "gaze": (2, 0, 0),
    "arm": {s: {"space": "chest", "hand": (0.42, 0.3, -0.58), "elbow": (1, -0.6, -0.2), "clav": (9, 4),
                "hand_space": "chest", "palm": (-0.55, 0.25, -0.8), "fingers": (0.15, 1, -0.45)} for s in ("L", "R")},
    "fingers": {s: {"curl": 0.3, "claw": 0.85, "spread": 30, "thumb": 0.4} for s in ("L", "R")},
    "foot": {"L": {"loc": (0.09, 0.03, 0), "rot": (0, 12, 0)},
             "R": {"loc": (0.09, -0.03, 0), "rot": (0, 12, 0)}},
    "tail": {"pitch": 12, "yaw": 0, "curl": 8},
}


def A3_Activate():
    k = [(0.00, IDLE)]
    # contener: manos frente al abdomen, rodillas cediendo, cabeza abajo
    k.append((0.22, {
        "root": {"loc": (0, 0, -0.085), "rot": (8, 0, 0)},
        "spine": (16, 0, 0),
        "gaze": (14, 0, 0),
        "arm": {s: {"space": "mid", "hand": (0.12, 0.44, -0.74), "elbow": (1, -0.5, -0.3), "clav": (8, 4),
                    "hand_space": "chest", "palm": (-0.5, 0.0, 1), "fingers": (-0.5, 1, 0)} for s in ("L", "R")},
        "fingers": {s: {"curl": 0.35, "claw": 0.8, "spread": 22, "thumb": 0.4} for s in ("L", "R")},
    }))
    # contracción: brazos cruzados al pecho, puños, todo el cuerpo se encoge
    CON = {
        "root": {"loc": (0, -0.01, -0.13), "rot": (10, 0, 0)},
        "spine": (28, 0, 0),
        "gaze": (24, 0, 0),
        "arm": {"R": {"space": "mid", "hand": (-0.2, 0.36, -0.3), "elbow": (1, -0.2, -0.6), "clav": (12, 12),
                      "hand_space": "chest", "palm": (0.2, -1, 0), "fingers": (-1, 0, 0.2)},
                "L": {"space": "mid", "hand": (-0.2, 0.31, -0.4), "elbow": (1, -0.2, -0.6), "clav": (12, 12),
                      "hand_space": "chest", "palm": (0.2, -1, 0), "fingers": (-1, 0, 0.1)}},
        "fingers": {"R": FIST, "L": FIST},
        "foot": {"R": {"loc": (0.06, -0.02, 0.06), "rot": (8, 10, 0)}},
        "tail": {"pitch": -12, "curl": -15},
    }
    k.append((0.42, CON))
    k.append((0.52, K.deep_merge(CON, {"root": {"loc": (0, -0.01, -0.145)}, "spine": (31, 0, 0),
                                        "foot": {"R": {"loc": (0.07, -0.02, 0.1), "rot": (6, 12, 0)}}})))
    # EXPLOSIÓN: pisotón, pecho afuera, brazos lanzados abajo-afuera, cabeza arriba
    BURST = {
        "root": {"loc": (0, 0.0, -0.06), "rot": (-4, 0, 0)},
        "spine": (-12, 0, 0),
        "gaze": (-18, 0, 0),
        "arm": {s: {"space": "chest", "hand": (0.56, 0.18, -0.6), "elbow": (1, -0.5, 0), "clav": (6, -4),
                    "hand_space": "chest", "palm": (-0.2, 0.7, -0.7), "fingers": (0.6, 0.3, -1)} for s in ("L", "R")},
        "fingers": {s: {"curl": 0.0, "claw": 0.35, "spread": 36, "thumb": 0.0} for s in ("L", "R")},
        "foot": {"R": {"loc": (0.1, -0.03, 0), "rot": (0, 12, 0)},
                 "L": {"loc": (0.09, 0.03, 0), "rot": (0, 12, 0)}},
        "tail": {"pitch": 30, "curl": 6},
    }
    k.append((0.60, BURST, {"interp": "QUAD", "easing": "EASE_IN"}))
    k.append((0.70, K.deep_merge(BURST, {"root": {"loc": (0, 0, -0.12)}, "spine": (-6, 0, 0),
                                         "arm": {s: {"hand": (0.6, 0.24, -0.54)} for s in ("L", "R")},
                                         "tail": {"pitch": 36}})))
    k.append((0.95, K.deep_merge(IGN, {"spine": (8, 0, 0), "gaze": (-2, 0, 0), "root": {"loc": (0, 0, -0.105)}})))
    k.append((1.40, IGN))
    post = tremble_layer([
        ("hands", 1.4, (5, 9, 13), 31, ramp(6, 30, 0.2, 1.0)),
        ("fore", 0.5, (5, 9), 32, ramp(6, 30, 0.2, 1.0)),
    ])
    return dict(name="KZ_A3_Activate", keys=k, markers=[("IgnitionBurst", 0.60)],
                lags={"spine": 1, "arms": 1, "hands": 2, "head": 3, "fingers": 2, "tail": [2, 3, 4, 5, 6, 7]},
                loop=False, post=post)


def Idle_Ignition():
    def breath(spine, clav, rx=0.0, roll=0.0, hand_out=0.0):
        return {"spine": (spine, 0, roll), "root": {"loc": (rx, 0, -0.10), "rot": (7, 0, -roll * 0.5)},
                "arm": {"R": {"clav": (clav, 4), "hand": (0.42 + hand_out, 0.3, -0.58)},
                        "L": {"clav": (clav, 4), "hand": (0.42 - hand_out, 0.3, -0.58)}}}
    clench = {"curl": 0.65, "claw": 0.9, "spread": 12, "thumb": 0.6}
    k = [(0.00, IGN)]
    k.append((0.33, K.deep_merge(IGN, breath(10, 11, 0.008, 1.0, 0.02))))
    k.append((0.66, K.deep_merge(IGN, K.deep_merge(breath(14, 8, 0.012, 1.5, 0.0), {"fingers": {"R": clench}}))))
    k.append((1.00, K.deep_merge(IGN, breath(10, 11, 0.0, 0.0, -0.02))))
    k.append((1.33, K.deep_merge(IGN, K.deep_merge(breath(14, 8, -0.012, -1.5, 0.0), {"fingers": {"L": clench}}))))
    k.append((1.66, K.deep_merge(IGN, breath(10, 11, -0.008, -1.0, 0.01))))
    k.append((2.00, IGN))
    post = tremble_layer([
        ("hands", 1.6, (11, 17, 23), 41, None),
        ("fore", 0.6, (9, 13), 42, None),
        ("spine", 0.45, (7, 12), 43, None),
        ("head", 0.7, (5, 8), 44, None),
    ])
    return dict(name="KZ_Idle_Ignition", keys=k, markers=[],
                lags={"head": 3, "fingers": 2, "tail": [3, 5, 7, 9, 11, 13]}, loop=True, post=post)


# ============================================================================
# A4 — KAMEHAMEHA: carga, disparo, rayo (loop), final
# ============================================================================
def _a4_charge(level):
    L = level
    return {
        "root": {"loc": (0, -0.06 - 0.01 * L, -0.14 - 0.025 * L), "rot": (8, -28 - 4 * L, 0)},
        "spine": (14, -24 - 4 * L, 0),
        "neck": (0, 6, 0),
        "gaze": (8, 0, 0),
        "arm": {"R": {"space": "root", "hand": (0.46, -0.1 - 0.06 * L, 0.14), "elbow": (0.6, -1, 0.2), "clav": (4, -6),
                      "hand_space": "char", "palm": (0.1, 0.1, 1)},
                "L": {"space": "root", "hand": (-0.4, -0.1 - 0.06 * L, 0.36), "elbow": (0.4, -0.2, -1), "clav": (4, 8),
                      "hand_space": "char", "palm": (0.1, -0.1, -1)}},
        "fingers": {s: {"curl": 0.45, "claw": 0.35, "spread": 12, "thumb": 0.3} for s in ("L", "R")},
        "foot": {"L": {"loc": (0.04, 0.05, 0), "rot": (0, 4, 0)},
                 "R": {"loc": (0.07, -0.24, 0), "rot": (0, 32, 0)}},
        "tail": {"pitch": 4, "yaw": 18, "curl": 0},
    }


BEAM = {
    "root": {"loc": (0, 0.04, -0.13), "rot": (12, 0, 0)},
    "spine": (17, 3, 0),
    "neck": (-4, 0, 0),
    "gaze": (12, 0, 0),
    "arm": {"R": {"space": "mid", "hand": (0.0, 0.9, -0.12), "elbow": (1, -0.2, -0.6), "clav": (4, 14),
                  "hand_space": "char", "palm": (0.1, 0.83, 0.55), "fingers": (0.15, 0.55, -0.83)},
            "L": {"space": "mid", "hand": (0.0, 0.9, 0.03), "elbow": (1, -0.2, -0.6), "clav": (4, 14),
                  "hand_space": "char", "palm": (0.1, 0.83, -0.55), "fingers": (0.15, 0.55, 0.83)}},
    "fingers": {s: {"curl": 0.15, "claw": 0.6, "spread": 26, "thumb": 0.2} for s in ("L", "R")},
    "foot": {"L": {"loc": (0.04, 0.05, 0), "rot": (0, 4, 0)},
             "R": {"loc": (0.07, -0.24, 0), "rot": (10, 32, 0)}},
    "tail": {"pitch": -6, "yaw": 0, "curl": -4},
}


def A4_Charge():
    k = [(0.00, IDLE)]
    k.append((0.22, {
        "root": {"loc": (0, 0, -0.08), "rot": (8, 0, 0)},
        "spine": (14, 0, 0),
        "gaze": (16, 0, 0),
        "arm": {"R": {"space": "mid", "hand": (0.0, 0.46, -0.72), "elbow": (1, -0.5, -0.3),
                      "hand_space": "char", "palm": (0, 0, 1), "fingers": (-0.6, 1, 0)},
                "L": {"space": "mid", "hand": (0.0, 0.46, -0.5), "elbow": (1, -0.5, -0.3),
                      "hand_space": "char", "palm": (0, 0, -1), "fingers": (-0.6, 1, 0)}},
        "fingers": {s: {"curl": 0.45, "claw": 0.3, "spread": 10, "thumb": 0.3} for s in ("L", "R")},
        "foot": {"R": {"loc": (0.04, -0.12, 0.05), "rot": (8, 14, 0)}},
    }))
    k.append((0.45, _a4_charge(0.0)))
    k.append((0.60, K.deep_merge(_a4_charge(0.0), {"root": {"loc": (0, -0.06, -0.152)}})))
    k.append((1.40, _a4_charge(0.8)))
    k.append((1.60, _a4_charge(1.0)))
    post = tremble_layer([
        ("hands", 1.2, (7, 11, 15), 51, ramp(30, 96, 0.1, 1.0)),
        ("fore", 0.5, (7, 11), 52, ramp(30, 96, 0.1, 1.0)),
        ("spine", 0.3, (5, 9), 53, ramp(30, 96, 0.0, 1.0)),
    ])
    return dict(name="KZ_A4_Charge", keys=k, markers=[("OrbStart", 0.45)],
                lags={"spine": 1, "arms": 1, "hands": 2, "head": 3, "fingers": 2, "tail": [2, 3, 4, 5, 6, 7]},
                loop=False, post=post)


def A4_Fire():
    k = [(0.00, _a4_charge(1.0))]
    PEAK = K.deep_merge(BEAM, {"root": {"loc": (0, 0.07, -0.12), "rot": (9, 2, 0)}, "spine": (14, 5, 0),
                               "arm": {"R": {"hand": (0.0, 0.96, -0.12)}, "L": {"hand": (0.0, 0.96, 0.03)}},
                               "foot": {"R": {"rot": (16, 32, 0)}}})
    k.append((0.07, PEAK, {"interp": "BEZIER"}))
    k.append((0.15, K.deep_merge(BEAM, {"root": {"loc": (0, 0.02, -0.14), "rot": (14, 0, 0)}, "spine": (20, 2, 0),
                                        "gaze": (16, 0, 0),
                                        "arm": {"R": {"hand": (0.0, 0.8, -0.1)}, "L": {"hand": (0.0, 0.8, 0.04)}}})))
    k.append((0.30, K.deep_merge(BEAM, {"arm": {"R": {"hand": (0.0, 0.92, -0.12)}, "L": {"hand": (0.0, 0.92, 0.03)}}})))
    k.append((0.50, BEAM))
    return dict(name="KZ_A4_Fire", keys=k, markers=[("BeamStart", 0.06)],
                lags={"spine": 1, "head": 2, "fingers": 1, "tail": [2, 3, 4, 5, 6, 7]}, loop=False)


def A4_BeamLoop():
    push = K.deep_merge(BEAM, {"root": {"loc": (0, 0.025, -0.135), "rot": (13, 0, 0)}, "spine": (18.5, 3, 0),
                               "arm": {"R": {"hand": (0.0, 0.85, -0.11)}, "L": {"hand": (0.0, 0.85, 0.04)}}})
    k = [(0.00, BEAM), (0.12, push), (0.5, BEAM), (0.62, push), (1.0, BEAM)]
    post = tremble_layer([
        ("hands", 1.6, (8, 13, 19), 61, None),
        ("fore", 0.7, (8, 13), 62, None),
        ("arms", 0.35, (6, 10), 63, None),
        ("spine", 0.4, (6, 11), 64, None),
        ("head", 0.5, (5, 9), 65, None),
    ])
    return dict(name="KZ_A4_BeamLoop", keys=k, markers=[],
                lags={"tail": [1, 2, 3, 4, 5, 6]}, loop=True, post=post)


def A4_End():
    k = [(0.00, BEAM)]
    k.append((0.13, {
        "root": {"loc": (0, 0.02, -0.08), "rot": (2, 0, 0)},
        "spine": (0, 0, 0),
        "gaze": (-10, 0, 0),
        "arm": {s: {"space": "mid", "hand": (0.36, 0.5, 0.72), "elbow": (1, 0, -0.6), "clav": (12, 4),
                    "hand_space": "char", "palm": (0, 0.8, 0.6), "fingers": (0.3, 0.2, 1)} for s in ("L", "R")},
        "fingers": {s: OPEN for s in ("L", "R")},
        "foot": {"R": {"rot": (0, 32, 0)}},
        "tail": {"pitch": 10},
    }))
    k.append((0.34, {
        "root": {"loc": (0, -0.02, -0.13), "rot": (8, -4, 0)},
        "spine": (12, -2, 0),
        "gaze": (6, 0, 0),
        "arm": {s: {"space": "chest", "hand": (0.2, 0.18, -0.85), "elbow": (0.6, -0.7, -0.3), "clav": (0, 0),
                    "hand_space": "chest", "palm": (-1, 0.1, 0), "fingers": (0.05, 0.3, -1)} for s in ("L", "R")},
        "fingers": {s: {"curl": 0.35, "claw": 0, "spread": 4, "thumb": 0.3} for s in ("L", "R")},
        "tail": {"pitch": 2},
    }))
    k.append((0.50, {"foot": {"R": {"loc": (0.05, -0.12, 0.05), "rot": (8, 16, 0)}},
                     "root": {"loc": (0, -0.01, -0.1), "rot": (6, -2, 0)}}))
    k.append((0.66, {"foot": {"R": {"loc": (0.02, -0.03, 0), "rot": (0, 6, 0)}},
                     "root": {"loc": (0, 0.0, -0.075), "rot": (5, 0, 0)}}))
    k.append((1.10, IDLE))
    return dict(name="KZ_A4_End", keys=k, markers=[("BeamEnd", 0.0)],
                lags={"spine": 1, "arms": 1, "hands": 2, "head": 3, "fingers": 2, "tail": [2, 3, 4, 5, 6, 7]},
                loop=False)


KIT = [A1_FireSlash, A2_Charge, A2_HoldMax, A2_Cast, A3_Activate, Idle_Ignition,
       A4_Charge, A4_Fire, A4_BeamLoop, A4_End]
